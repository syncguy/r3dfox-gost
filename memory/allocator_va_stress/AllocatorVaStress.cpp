#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN 1
#endif
#include <windows.h>

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef ALLOCATOR_MOZJEMALLOC
#  include "mozmemory.h"

extern "C" {
void* je_malloc(size_t);
void* je_realloc(void*, size_t);
void je_free(void*) noexcept;
size_t je_malloc_usable_size(usable_ptr_t) noexcept;
}
#endif

#ifdef ALLOCATOR_MIMALLOC
#  include "mimalloc.h"
#endif

#ifdef ALLOCATOR_RPMALLOC
#  include "rpmalloc.h"
#endif

namespace {

constexpr size_t kMiB = 1024u * 1024u;
constexpr size_t kPageTouch = 4096u;
constexpr size_t kMaxBlocks = 65536u;
constexpr size_t kMaxGcBlocks = 4096u;
constexpr size_t kGcChunk = 1u * kMiB;
constexpr size_t kGcAlignment = 1u * kMiB;
constexpr unsigned kSurvivorGenerations = 3u;
constexpr unsigned kMaxAlignAttempts = 32u;

struct Block {
  void* ptr;
  size_t size;
};

struct BlockList {
  Block blocks[kMaxBlocks];
  size_t count;
};

struct Config {
  size_t liveMiB;
  size_t burstMiB;
  size_t survivorMiB;
  unsigned cycles;
  unsigned gcHoldPerCycle;
  unsigned sleepMs;
  unsigned maxMs;
  size_t stopFreeMiB;
  size_t stopAlignedMiB;
  bool crossThread;
  const char* label;
};

struct VaSnapshot {
  uint64_t freeBytes;
  uint64_t reservedBytes;
  uint64_t committedBytes;
  uint64_t privateBytes;
  uint64_t imageBytes;
  uint64_t mappedBytes;
  uint64_t largestFree;
  uint64_t top5Free;
  uint64_t top10Free;
  uint64_t freeGe4;
  uint64_t freeGe16;
  uint64_t freeGe64;
  uint64_t largestAligned1MiB;
  uint64_t aligned1MiBSlots;
  uint32_t freeRegions;
  uint32_t regionsGe4;
  uint32_t regionsGe16;
  uint32_t regionsGe64;
  uint32_t queriedRegions;
  bool complete;
};

struct AllocFailure {
  const char* stage;
  size_t requested;
  size_t completed;
  int crtErrno;
  DWORD win32Error;
  DWORD elapsedMs;
};

struct ThreadContext {
  BlockList* list;
  size_t targetBytes;
  uint32_t seed;
  bool result;
};

struct GcAllocResult {
  void* ptr;
  const char* path;
  DWORD win32Error;
  unsigned attempts;
  DWORD elapsedMs;
};

BlockList gLive = {};
BlockList gBurst = {};
BlockList gToFree = {};
BlockList gSurvivors[kSurvivorGenerations] = {};
void* gGcBlocks[kMaxGcBlocks] = {};
size_t gGcBlockCount = 0;
AllocFailure gAllocFailure = {};

DWORD ElapsedMs(DWORD start) { return GetTickCount() - start; }

double MiB(uint64_t bytes) {
  return static_cast<double>(bytes) / static_cast<double>(kMiB);
}

void* TestAlloc(size_t size) {
#ifdef ALLOCATOR_RPMALLOC
  return rpmalloc(size);
#elif defined(ALLOCATOR_MIMALLOC)
  return mi_malloc(size);
#else
  return je_malloc(size);
#endif
}

void* TestRealloc(void* ptr, size_t size) {
#ifdef ALLOCATOR_RPMALLOC
  return rprealloc(ptr, size);
#elif defined(ALLOCATOR_MIMALLOC)
  return mi_realloc(ptr, size);
#else
  return je_realloc(ptr, size);
#endif
}

size_t TestUsableSize(void* ptr) {
#ifdef ALLOCATOR_RPMALLOC
  return rpmalloc_usable_size(ptr);
#elif defined(ALLOCATOR_MIMALLOC)
  return mi_malloc_usable_size(ptr);
#else
  return je_malloc_usable_size(ptr);
#endif
}

void TestFree(void* ptr) {
#ifdef ALLOCATOR_RPMALLOC
  rpfree(ptr);
#elif defined(ALLOCATOR_MIMALLOC)
  mi_free(ptr);
#else
  je_free(ptr);
#endif
}

void Touch(void* ptr, size_t size) {
  volatile unsigned char* bytes =
      static_cast<volatile unsigned char*>(ptr);
  for (size_t offset = 0; offset < size; offset += kPageTouch) {
    bytes[offset] = static_cast<unsigned char>(offset >> 12);
  }
  if (size) {
    bytes[size - 1] ^= 0x5a;
  }
}

uint32_t NextRand(uint32_t& state) {
  state = state * 1664525u + 1013904223u;
  return state;
}

uint64_t BlockListBytes(const BlockList& list) {
  uint64_t result = 0;
  for (size_t i = 0; i < list.count; ++i) {
    result += list.blocks[i].size;
  }
  return result;
}

uint64_t TrackedUserBytes() {
  uint64_t result = BlockListBytes(gLive) + BlockListBytes(gBurst) +
                    BlockListBytes(gToFree);
  for (unsigned i = 0; i < kSurvivorGenerations; ++i) {
    result += BlockListBytes(gSurvivors[i]);
  }
  return result;
}

bool AllocatePattern(BlockList* list, size_t targetBytes, uint32_t seed,
                     const char* stage) {
  static const size_t kSizes[] = {
      4096u,    16384u,   65536u,   262144u,
      1048576u, 32768u,   131072u,  524288u,
      8192u,    2097152u, 98304u,   393216u,
  };

  list->count = 0;
  size_t allocated = 0;
  uint32_t state = seed;
  const DWORD start = GetTickCount();

  while (allocated < targetBytes) {
    if (list->count == kMaxBlocks) {
      gAllocFailure = {stage, 0, allocated, 0, ERROR_NOT_ENOUGH_MEMORY,
                       ElapsedMs(start)};
      fprintf(stderr, "block table exhausted at %zu allocations\n", list->count);
      return false;
    }

    size_t size = kSizes[NextRand(state) %
                         (sizeof(kSizes) / sizeof(kSizes[0]))];
    if (size > targetBytes - allocated) {
      size = targetBytes - allocated;
    }
    if (!size) {
      break;
    }

    errno = 0;
    SetLastError(ERROR_SUCCESS);
    void* ptr = TestAlloc(size);
    if (!ptr) {
      gAllocFailure = {stage, size, allocated, errno, GetLastError(),
                       ElapsedMs(start)};
      fprintf(stderr,
              "allocator failure stage=%s requested=%zu completed_mib=%.1f\n",
              stage, size, MiB(allocated));
      return false;
    }

    Touch(ptr, size);
    list->blocks[list->count++] = {ptr, size};
    allocated += size;
  }

  return true;
}

void PrintAllocFailure(const Config& config, unsigned cycle) {
  printf(
      "FAILURE label=%s cycle=%u kind=heap_allocator stage=%s "
      "requested_bytes=%zu completed_mib=%.1f errno=%d win32_error=%lu "
      "elapsed_ms=%lu\n",
      config.label, cycle, gAllocFailure.stage ? gAllocFailure.stage : "unknown",
      gAllocFailure.requested, MiB(gAllocFailure.completed),
      gAllocFailure.crtErrno, gAllocFailure.win32Error,
      gAllocFailure.elapsedMs);
}

void FreeList(BlockList* list) {
  for (size_t i = 0; i < list->count; ++i) {
    if (list->blocks[i].ptr) {
      TestFree(list->blocks[i].ptr);
    }
    list->blocks[i] = {};
  }
  list->count = 0;
}

DWORD WINAPI AllocateThread(void* raw) {
#ifdef ALLOCATOR_RPMALLOC
  rpmalloc_thread_initialize();
#endif
  ThreadContext* ctx = static_cast<ThreadContext*>(raw);
  ctx->result =
      AllocatePattern(ctx->list, ctx->targetBytes, ctx->seed, "burst");
#ifdef ALLOCATOR_RPMALLOC
  rpmalloc_thread_finalize(1);
#endif
  return ctx->result ? 0 : 1;
}

DWORD WINAPI FreeThread(void* raw) {
#ifdef ALLOCATOR_RPMALLOC
  rpmalloc_thread_initialize();
#endif
  BlockList* list = static_cast<BlockList*>(raw);
  FreeList(list);
#ifdef ALLOCATOR_RPMALLOC
  rpmalloc_thread_finalize(1);
#endif
  return 0;
}

bool RunThread(LPTHREAD_START_ROUTINE routine, void* context) {
  HANDLE thread = CreateThread(nullptr, 0, routine, context, 0, nullptr);
  if (!thread) {
    fprintf(stderr, "CreateThread failed: %lu\n", GetLastError());
    return false;
  }

  DWORD wait = WaitForSingleObject(thread, INFINITE);
  DWORD exitCode = 1;
  if (wait == WAIT_OBJECT_0) {
    GetExitCodeThread(thread, &exitCode);
  }
  CloseHandle(thread);
  return wait == WAIT_OBJECT_0 && exitCode == 0;
}

bool RetireSurvivorGeneration(unsigned slot, bool onWorker) {
  if (!gSurvivors[slot].count) {
    return true;
  }
  if (onWorker) {
    return RunThread(FreeThread, &gSurvivors[slot]);
  }
  FreeList(&gSurvivors[slot]);
  return true;
}

bool SplitBurstAndFree(const Config& config, unsigned cycle,
                       bool burstAllocatedOnWorker) {
  const unsigned slot = (cycle - 1u) % kSurvivorGenerations;
  if (!RetireSurvivorGeneration(slot,
                                config.crossThread && (cycle % 2u) == 0u)) {
    return false;
  }

  BlockList* survivors = &gSurvivors[slot];
  survivors->count = 0;
  gToFree.count = 0;
  const uint64_t survivorTarget = config.survivorMiB * kMiB;
  uint64_t survivorBytes = 0;

  for (size_t i = 0; i < gBurst.count && survivorBytes < survivorTarget; ++i) {
    if (((i + cycle) % 5u) != 0u || !gBurst.blocks[i].ptr) {
      continue;
    }
    Block block = gBurst.blocks[i];
    survivors->blocks[survivors->count++] = block;
    survivorBytes += block.size;
    gBurst.blocks[i] = {};
  }

  for (size_t i = 0; i < gBurst.count && survivorBytes < survivorTarget; ++i) {
    if (!gBurst.blocks[i].ptr) {
      continue;
    }
    Block block = gBurst.blocks[i];
    survivors->blocks[survivors->count++] = block;
    survivorBytes += block.size;
    gBurst.blocks[i] = {};
  }

  for (size_t i = 0; i < gBurst.count; ++i) {
    if (!gBurst.blocks[i].ptr) {
      continue;
    }
    if (gToFree.count == kMaxBlocks) {
      return false;
    }
    gToFree.blocks[gToFree.count++] = gBurst.blocks[i];
    gBurst.blocks[i] = {};
  }
  gBurst.count = 0;

  bool freed = true;
  if (config.crossThread && !burstAllocatedOnWorker) {
    freed = RunThread(FreeThread, &gToFree);
  } else {
    FreeList(&gToFree);
  }

  printf(
      "SURVIVORS label=%s cycle=%u generation=%u survivor_mib=%.1f "
      "tracked_user_mib=%.1f\n",
      config.label, cycle, slot, MiB(BlockListBytes(*survivors)),
      MiB(TrackedUserBytes()));
  return freed;
}

uintptr_t AlignUp(uintptr_t value, size_t alignment) {
  const uintptr_t mask = static_cast<uintptr_t>(alignment - 1);
  return (value + mask) & ~mask;
}

bool IsAligned(void* ptr, size_t alignment) {
  return ptr && (reinterpret_cast<uintptr_t>(ptr) % alignment) == 0;
}

void ReleaseRegion(void* ptr) {
  if (ptr) {
    VirtualFree(ptr, 0, MEM_RELEASE);
  }
}

void* MapCommitted(size_t length, DWORD* error) {
  SetLastError(ERROR_SUCCESS);
  void* ptr =
      VirtualAlloc(nullptr, length, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
  *error = ptr ? ERROR_SUCCESS : GetLastError();
  return ptr;
}

void* MapCommittedAt(void* address, size_t length, DWORD* error) {
  SetLastError(ERROR_SUCCESS);
  void* ptr = VirtualAlloc(address, length, MEM_RESERVE | MEM_COMMIT,
                           PAGE_READWRITE);
  *error = ptr ? ERROR_SUCCESS : GetLastError();
  return ptr;
}

void* MapReservedAt(void* address, size_t length, DWORD* error) {
  SetLastError(ERROR_SUCCESS);
  void* ptr = VirtualAlloc(address, length, MEM_RESERVE, PAGE_NOACCESS);
  *error = ptr ? ERROR_SUCCESS : GetLastError();
  return ptr;
}

bool TryToAlignChunk(void** region, void** retainedRegion,
                     unsigned* attemptCounter, DWORD* lastError) {
  *retainedRegion = nullptr;

  for (unsigned guard = 0; guard < kMaxAlignAttempts && *region; ++guard) {
    ++(*attemptCounter);
    if (IsAligned(*region, kGcAlignment)) {
      return true;
    }

    const uintptr_t value = reinterpret_cast<uintptr_t>(*region);
    const size_t offset = value % kGcAlignment;
    const size_t retainedLength = kGcAlignment - offset;
    void* oldRegion = *region;
    ReleaseRegion(oldRegion);

    DWORD retainError = ERROR_SUCCESS;
    void* retained = MapReservedAt(oldRegion, retainedLength, &retainError);

    DWORD mapError = ERROR_SUCCESS;
    void* nextRegion = MapCommitted(kGcChunk, &mapError);
    *region = nextRegion;

    if (retained) {
      *retainedRegion = retained;
      *lastError = mapError;
      break;
    }

    *lastError = retainError ? retainError : mapError;
  }

  const bool success = IsAligned(*region, kGcAlignment);
  if (success && *retainedRegion) {
    ReleaseRegion(*retainedRegion);
    *retainedRegion = nullptr;
  }
  return success;
}

GcAllocResult AllocateGeckoLikeAligned1MiB() {
  const DWORD start = GetTickCount();
  unsigned attempts = 0;
  DWORD lastError = ERROR_SUCCESS;

  void* region = MapCommitted(kGcChunk, &lastError);
  ++attempts;
  if (region && IsAligned(region, kGcAlignment)) {
    Touch(region, kGcChunk);
    return {region, "initial-map", lastError, attempts, ElapsedMs(start)};
  }

  if (region) {
    void* retained = nullptr;
    if (TryToAlignChunk(&region, &retained, &attempts, &lastError)) {
      Touch(region, kGcChunk);
      return {region, "retained-align", lastError, attempts, ElapsedMs(start)};
    }
    ReleaseRegion(retained);
    ReleaseRegion(region);
    region = nullptr;
  }

  const size_t reserveLength = kGcChunk + kGcAlignment - kPageTouch;
  for (unsigned i = 0; i < kMaxAlignAttempts; ++i) {
    ++attempts;
    SetLastError(ERROR_SUCCESS);
    void* reserve =
        VirtualAlloc(nullptr, reserveLength, MEM_RESERVE, PAGE_NOACCESS);
    if (!reserve) {
      lastError = GetLastError();
      break;
    }

    void* aligned =
        reinterpret_cast<void*>(AlignUp(reinterpret_cast<uintptr_t>(reserve),
                                        kGcAlignment));
    ReleaseRegion(reserve);

    DWORD exactError = ERROR_SUCCESS;
    region = MapCommittedAt(aligned, kGcChunk, &exactError);
    if (region == aligned) {
      Touch(region, kGcChunk);
      return {region, "slow-overreserve", ERROR_SUCCESS, attempts,
              ElapsedMs(start)};
    }
    ReleaseRegion(region);
    region = nullptr;
    lastError = exactError;
  }

  void* tempMaps[kMaxAlignAttempts] = {};
  unsigned tempCount = 0;

  region = MapCommitted(kGcChunk, &lastError);
  ++attempts;
  if (region && IsAligned(region, kGcAlignment)) {
    Touch(region, kGcChunk);
    return {region, "last-ditch-initial", lastError, attempts,
            ElapsedMs(start)};
  }

  for (unsigned i = 0; i < kMaxAlignAttempts && region; ++i) {
    void* retained = nullptr;
    if (TryToAlignChunk(&region, &retained, &attempts, &lastError)) {
      break;
    }
    if (!region || !retained) {
      ReleaseRegion(retained);
      break;
    }
    tempMaps[tempCount++] = retained;
  }

  if (region && !IsAligned(region, kGcAlignment)) {
    ReleaseRegion(region);
    region = nullptr;
  }

  for (unsigned i = 0; i < tempCount; ++i) {
    ReleaseRegion(tempMaps[i]);
  }

  if (region) {
    Touch(region, kGcChunk);
    return {region, "last-ditch", ERROR_SUCCESS, attempts, ElapsedMs(start)};
  }

  return {nullptr, "failed", lastError, attempts, ElapsedMs(start)};
}

bool HoldGcChunks(const Config& config, unsigned cycle, unsigned count) {
  for (unsigned i = 0; i < count; ++i) {
    if (gGcBlockCount == kMaxGcBlocks) {
      printf(
          "FAILURE label=%s cycle=%u kind=gc_aligned_mapping "
          "stage=gc-table-exhausted\n",
          config.label, cycle);
      return false;
    }

    GcAllocResult result = AllocateGeckoLikeAligned1MiB();
    printf(
        "GC_ALLOC label=%s cycle=%u role=hold ordinal=%u success=%u "
        "path=%s attempts=%u elapsed_ms=%lu win32_error=%lu\n",
        config.label, cycle, i, result.ptr ? 1u : 0u, result.path,
        result.attempts, result.elapsedMs, result.win32Error);

    if (!result.ptr) {
      printf(
          "FAILURE label=%s cycle=%u kind=gc_aligned_mapping stage=hold "
          "path=%s attempts=%u elapsed_ms=%lu win32_error=%lu\n",
          config.label, cycle, result.path, result.attempts, result.elapsedMs,
          result.win32Error);
      return false;
    }

    gGcBlocks[gGcBlockCount++] = result.ptr;
  }
  return true;
}

bool ProbeAligned1MiB(const Config& config, unsigned cycle) {
  GcAllocResult result = AllocateGeckoLikeAligned1MiB();
  printf(
      "GC_ALLOC label=%s cycle=%u role=probe success=%u path=%s attempts=%u "
      "elapsed_ms=%lu win32_error=%lu\n",
      config.label, cycle, result.ptr ? 1u : 0u, result.path,
      result.attempts, result.elapsedMs, result.win32Error);

  if (!result.ptr) {
    printf(
        "FAILURE label=%s cycle=%u kind=gc_aligned_mapping stage=probe "
        "path=%s attempts=%u elapsed_ms=%lu win32_error=%lu\n",
        config.label, cycle, result.path, result.attempts, result.elapsedMs,
        result.win32Error);
    return false;
  }

  ReleaseRegion(result.ptr);
  return true;
}

void ReleaseGcChunks() {
  for (size_t i = 0; i < gGcBlockCount; ++i) {
    ReleaseRegion(gGcBlocks[i]);
    gGcBlocks[i] = nullptr;
  }
  gGcBlockCount = 0;
}

void InsertTop(uint64_t* top, uint64_t value) {
  for (size_t i = 0; i < 10; ++i) {
    if (value > top[i]) {
      for (size_t j = 9; j > i; --j) {
        top[j] = top[j - 1];
      }
      top[i] = value;
      break;
    }
  }
}

VaSnapshot ReadVaSnapshot() {
  VaSnapshot result = {};
  result.complete = true;

  SYSTEM_INFO info = {};
  GetSystemInfo(&info);

  uintptr_t address =
      reinterpret_cast<uintptr_t>(info.lpMinimumApplicationAddress);
  const uintptr_t maximum =
      reinterpret_cast<uintptr_t>(info.lpMaximumApplicationAddress);
  uint64_t top[10] = {};

  while (address <= maximum) {
    MEMORY_BASIC_INFORMATION mbi = {};
    SIZE_T queried =
        VirtualQuery(reinterpret_cast<void*>(address), &mbi, sizeof(mbi));
    if (!queried || mbi.RegionSize == 0) {
      result.complete = false;
      break;
    }

    ++result.queriedRegions;

    const uintptr_t base = reinterpret_cast<uintptr_t>(mbi.BaseAddress);
    const uint64_t rawEnd =
        static_cast<uint64_t>(base) + static_cast<uint64_t>(mbi.RegionSize);
    const uint64_t maxEnd = static_cast<uint64_t>(maximum) + 1u;
    const uint64_t end = rawEnd > maxEnd ? maxEnd : rawEnd;
    const uint64_t size = end > base ? end - base : 0;

    if (mbi.State == MEM_FREE) {
      ++result.freeRegions;
      result.freeBytes += size;
      if (size > result.largestFree) {
        result.largestFree = size;
      }
      InsertTop(top, size);

      if (size >= 4u * kMiB) {
        result.freeGe4 += size;
        ++result.regionsGe4;
      }
      if (size >= 16u * kMiB) {
        result.freeGe16 += size;
        ++result.regionsGe16;
      }
      if (size >= 64u * kMiB) {
        result.freeGe64 += size;
        ++result.regionsGe64;
      }

      const uintptr_t aligned = AlignUp(base, kGcAlignment);
      if (aligned < end) {
        const uint64_t alignedCapacity = end - aligned;
        if (alignedCapacity > result.largestAligned1MiB) {
          result.largestAligned1MiB = alignedCapacity;
        }
        result.aligned1MiBSlots += alignedCapacity / kGcChunk;
      }
    } else if (mbi.State == MEM_RESERVE) {
      result.reservedBytes += size;
    } else if (mbi.State == MEM_COMMIT) {
      result.committedBytes += size;
      if (mbi.Type == MEM_PRIVATE) {
        result.privateBytes += size;
      } else if (mbi.Type == MEM_IMAGE) {
        result.imageBytes += size;
      } else if (mbi.Type == MEM_MAPPED) {
        result.mappedBytes += size;
      }
    }

    if (end <= address || end > maximum) {
      break;
    }
    address = static_cast<uintptr_t>(end);
  }

  for (size_t i = 0; i < 5; ++i) {
    result.top5Free += top[i];
  }
  for (size_t i = 0; i < 10; ++i) {
    result.top10Free += top[i];
  }

  return result;
}

void PrintAllocatorPolicy(const Config& config) {
#ifdef ALLOCATOR_MIMALLOC
  printf(
      "MIMALLOC_POLICY label=%s arena_reserve_mib=%.1f "
      "disallow_arena_alloc=%ld retry_on_oom_ms=%ld purge_decommits=%ld\n",
      config.label, MiB(mi_option_get_size(mi_option_arena_reserve)),
      mi_option_get(mi_option_disallow_arena_alloc),
      mi_option_get(mi_option_retry_on_oom),
      mi_option_get(mi_option_purge_decommits));
#else
  (void)config;
#endif
}


bool RunNativeArenaOwnershipSmoke(const Config& config) {
#ifdef ALLOCATOR_MOZJEMALLOC
  arena_id_t arena = moz_create_arena();

  void* viaArena = moz_arena_malloc(arena, 64u * 1024u);
  if (!viaArena) {
    printf("ARENA_SMOKE label=%s success=0 stage=arena-malloc\n",
           config.label);
    moz_dispose_arena(arena);
    return false;
  }
  Touch(viaArena, 64u * 1024u);

  void* ordinary = TestAlloc(48u * 1024u);
  if (!ordinary) {
    printf("ARENA_SMOKE label=%s success=0 stage=ordinary-malloc\n",
           config.label);
    moz_arena_free(arena, viaArena);
    moz_dispose_arena(arena);
    return false;
  }
  Touch(ordinary, 48u * 1024u);

  using ReplaceProbeFn = unsigned(__cdecl*)(const void*, const void*);
  ReplaceProbeFn replaceProbe = nullptr;
  bool replaceExpected = false;
  char replacePath[MAX_PATH] = {};
  DWORD replaceLen = GetEnvironmentVariableA(
      "MOZ_REPLACE_MALLOC_LIB", replacePath, MAX_PATH);
  if (replaceLen) {
    replaceExpected = true;
    if (replaceLen >= MAX_PATH) {
      printf("ARENA_SMOKE label=%s success=0 stage=replace-path\n",
             config.label);
      TestFree(ordinary);
      moz_arena_free(arena, viaArena);
      moz_dispose_arena(arena);
      return false;
    }

    HMODULE module = GetModuleHandleA(replacePath);
    if (!module) {
      const char* slash = strrchr(replacePath, '\\');
      const char* forward = strrchr(replacePath, '/');
      const char* base = replacePath;
      if (slash && (!forward || slash > forward)) {
        base = slash + 1;
      } else if (forward) {
        base = forward + 1;
      }
      module = GetModuleHandleA(base);
    }
    if (!module) {
      printf("ARENA_SMOKE label=%s success=0 stage=replace-module\n",
             config.label);
      TestFree(ordinary);
      moz_arena_free(arena, viaArena);
      moz_dispose_arena(arena);
      return false;
    }

    replaceProbe = reinterpret_cast<ReplaceProbeFn>(
        GetProcAddress(module, "allocator_va_stress_replace_probe"));
    if (!replaceProbe) {
      printf("ARENA_SMOKE label=%s success=0 stage=replace-probe\n",
             config.label);
      TestFree(ordinary);
      moz_arena_free(arena, viaArena);
      moz_dispose_arena(arena);
      return false;
    }
  }

  unsigned probeFlags =
      replaceProbe ? replaceProbe(ordinary, viaArena) : 0u;
  if (replaceExpected && (probeFlags & 7u) != 7u) {
    printf(
        "REPLACE_SMOKE label=%s initialized=%u ordinary_mimalloc=%u "
        "arena_native=%u success=0 stage=ownership-initial\n",
        config.label, (probeFlags & 1u) ? 1u : 0u,
        (probeFlags & 2u) ? 1u : 0u, (probeFlags & 4u) ? 1u : 0u);
    TestFree(ordinary);
    moz_arena_free(arena, viaArena);
    moz_dispose_arena(arena);
    return false;
  }

  const size_t nativeUsable = TestUsableSize(viaArena);
  if (!nativeUsable) {
    printf("ARENA_SMOKE label=%s success=0 stage=plain-usable-size\n",
           config.label);
    TestFree(ordinary);
    moz_arena_free(arena, viaArena);
    moz_dispose_arena(arena);
    return false;
  }

  void* reallocated = TestRealloc(viaArena, 96u * 1024u);
  if (!reallocated) {
    printf("ARENA_SMOKE label=%s success=0 stage=plain-realloc\n",
           config.label);
    TestFree(ordinary);
    TestFree(viaArena);
    moz_dispose_arena(arena);
    return false;
  }
  Touch(reallocated, 96u * 1024u);

  probeFlags = replaceProbe ? replaceProbe(ordinary, reallocated) : 0u;
  if (replaceExpected && (probeFlags & 7u) != 7u) {
    printf(
        "REPLACE_SMOKE label=%s initialized=%u ordinary_mimalloc=%u "
        "arena_native=%u success=0 stage=ownership-after-realloc\n",
        config.label, (probeFlags & 1u) ? 1u : 0u,
        (probeFlags & 2u) ? 1u : 0u, (probeFlags & 4u) ? 1u : 0u);
    TestFree(ordinary);
    TestFree(reallocated);
    moz_dispose_arena(arena);
    return false;
  }

  TestFree(reallocated);
  TestFree(ordinary);

  void* viaArena2 = moz_arena_calloc(arena, 1u, 32u * 1024u);
  if (!viaArena2) {
    printf("ARENA_SMOKE label=%s success=0 stage=arena-calloc\n",
           config.label);
    moz_dispose_arena(arena);
    return false;
  }

  moz_arena_free(arena, viaArena2);
  moz_dispose_arena(arena);

  printf("ARENA_SMOKE label=%s success=1 native_usable=%zu\n",
         config.label, nativeUsable);
  if (replaceExpected) {
    printf(
        "REPLACE_SMOKE label=%s initialized=%u ordinary_mimalloc=%u "
        "arena_native=%u success=1\n",
        config.label, (probeFlags & 1u) ? 1u : 0u,
        (probeFlags & 2u) ? 1u : 0u, (probeFlags & 4u) ? 1u : 0u);
  }
#else
  (void)config;
#endif
  return true;
}

void PrintJemallocStats(const Config& config, const char* phase,
                        unsigned cycle) {
#ifdef ALLOCATOR_MOZJEMALLOC
  jemalloc_stats_t stats = {};
  jemalloc_stats(&stats);
  printf(
      "JEMALLOC label=%s phase=%s cycle=%u mapped_mib=%.1f "
      "allocated_mib=%.1f waste_mib=%.1f dirty_mib=%.1f fresh_mib=%.1f "
      "madvised_mib=%.1f bookkeeping_mib=%.1f bin_unused_mib=%.1f\n",
      config.label, phase, cycle, MiB(stats.mapped), MiB(stats.allocated),
      MiB(stats.waste), MiB(stats.pages_dirty), MiB(stats.pages_fresh),
      MiB(stats.pages_madvised), MiB(stats.bookkeeping), MiB(stats.bin_unused));
#else
  (void)config;
  (void)phase;
  (void)cycle;
#endif
}

VaSnapshot PrintSnapshot(const Config& config, const char* phase,
                         unsigned cycle) {
  VaSnapshot snapshot = ReadVaSnapshot();

  MEMORYSTATUSEX memory = {};
  memory.dwLength = sizeof(memory);
  const BOOL haveMemoryStatus = GlobalMemoryStatusEx(&memory);

  printf(
      "SNAPSHOT label=%s phase=%s cycle=%u complete=%u "
      "tracked_user_mib=%.1f free_mib=%.1f reserved_mib=%.1f "
      "committed_mib=%.1f private_mib=%.1f image_mib=%.1f mapped_mib=%.1f "
      "largest_mib=%.1f top5_mib=%.1f top10_mib=%.1f "
      "ge4_mib=%.1f ge4_regions=%u ge16_mib=%.1f ge16_regions=%u "
      "ge64_mib=%.1f ge64_regions=%u free_regions=%u "
      "aligned1m_max_mib=%.1f aligned1m_slots=%llu queried=%u "
      "avail_phys_mib=%.1f avail_pagefile_mib=%.1f avail_virtual_mib=%.1f "
      "gc_held_mib=%zu\n",
      config.label, phase, cycle, snapshot.complete ? 1u : 0u,
      MiB(TrackedUserBytes()), MiB(snapshot.freeBytes),
      MiB(snapshot.reservedBytes), MiB(snapshot.committedBytes),
      MiB(snapshot.privateBytes), MiB(snapshot.imageBytes),
      MiB(snapshot.mappedBytes), MiB(snapshot.largestFree),
      MiB(snapshot.top5Free), MiB(snapshot.top10Free), MiB(snapshot.freeGe4),
      snapshot.regionsGe4, MiB(snapshot.freeGe16), snapshot.regionsGe16,
      MiB(snapshot.freeGe64), snapshot.regionsGe64, snapshot.freeRegions,
      MiB(snapshot.largestAligned1MiB),
      static_cast<unsigned long long>(snapshot.aligned1MiBSlots),
      snapshot.queriedRegions,
      haveMemoryStatus ? MiB(memory.ullAvailPhys) : -1.0,
      haveMemoryStatus ? MiB(memory.ullAvailPageFile) : -1.0,
      haveMemoryStatus ? MiB(memory.ullAvailVirtual) : -1.0,
      gGcBlockCount);

  PrintJemallocStats(config, phase, cycle);
  fflush(stdout);
  return snapshot;
}

bool ParseSizeArg(const char* value, size_t* result) {
  char* end = nullptr;
  unsigned long parsed = strtoul(value, &end, 10);
  if (!value[0] || !end || *end != '\0') {
    return false;
  }
  *result = static_cast<size_t>(parsed);
  return true;
}

bool ParseUnsignedArg(const char* value, unsigned* result) {
  size_t parsed = 0;
  if (!ParseSizeArg(value, &parsed) || parsed > 0xffffffffu) {
    return false;
  }
  *result = static_cast<unsigned>(parsed);
  return true;
}

bool ParseArgs(int argc, char** argv, Config* config) {
  *config = {
      416u,
      256u,
      32u,
      30u,
      2u,
      100u,
      120000u,
      128u,
      2u,
      true,
#if defined(ALLOCATOR_RPMALLOC)
      "rpmalloc",
#elif defined(ALLOCATOR_MIMALLOC)
      "mimalloc",
#else
      "mozjemalloc",
#endif
  };

  for (int i = 1; i < argc; ++i) {
    const char* name = argv[i];
    if (!strcmp(name, "--no-cross-thread")) {
      config->crossThread = false;
      continue;
    }
    if (i + 1 >= argc) {
      fprintf(stderr, "missing value for %s\n", name);
      return false;
    }

    const char* value = argv[++i];
    if (!strcmp(name, "--label")) {
      config->label = value;
    } else if (!strcmp(name, "--live-mib")) {
      if (!ParseSizeArg(value, &config->liveMiB)) return false;
    } else if (!strcmp(name, "--burst-mib")) {
      if (!ParseSizeArg(value, &config->burstMiB)) return false;
    } else if (!strcmp(name, "--survivor-mib")) {
      if (!ParseSizeArg(value, &config->survivorMiB)) return false;
    } else if (!strcmp(name, "--cycles")) {
      if (!ParseUnsignedArg(value, &config->cycles)) return false;
    } else if (!strcmp(name, "--gc-hold-per-cycle")) {
      if (!ParseUnsignedArg(value, &config->gcHoldPerCycle)) return false;
    } else if (!strcmp(name, "--sleep-ms")) {
      if (!ParseUnsignedArg(value, &config->sleepMs)) return false;
    } else if (!strcmp(name, "--max-ms")) {
      if (!ParseUnsignedArg(value, &config->maxMs)) return false;
    } else if (!strcmp(name, "--stop-free-mib")) {
      if (!ParseSizeArg(value, &config->stopFreeMiB)) return false;
    } else if (!strcmp(name, "--stop-aligned-mib")) {
      if (!ParseSizeArg(value, &config->stopAlignedMiB)) return false;
    } else {
      fprintf(stderr, "unknown option: %s\n", name);
      return false;
    }
  }

  if (config->gcHoldPerCycle &&
      static_cast<uint64_t>(config->gcHoldPerCycle) * config->cycles >
          kMaxGcBlocks) {
    fprintf(stderr, "requested GC hold count exceeds internal table\n");
    return false;
  }

  return true;
}

const char* StopThresholdReason(const Config& config,
                                const VaSnapshot& snapshot) {
  if (config.stopFreeMiB &&
      snapshot.freeBytes <= config.stopFreeMiB * kMiB) {
    return "free-va-threshold";
  }

  if (config.stopAlignedMiB &&
      snapshot.largestAligned1MiB <= config.stopAlignedMiB * kMiB) {
    return "aligned-headroom-threshold";
  }

  return nullptr;
}

void PrintUsage() {
  puts(
      "allocator-va-stress [--label NAME] [--live-mib N] [--burst-mib N] "
      "[--survivor-mib N] [--cycles N] [--gc-hold-per-cycle N] "
      "[--sleep-ms N] [--max-ms N] [--stop-free-mib N] "
      "[--stop-aligned-mib N] [--no-cross-thread]");
}

}  // namespace

int main(int argc, char** argv) {
  Config config = {};
  if (!ParseArgs(argc, argv, &config)) {
    PrintUsage();
    return 2;
  }

  if (sizeof(void*) != 4) {
    fprintf(stderr, "this experiment requires a 32-bit process\n");
    return 3;
  }
#ifdef ALLOCATOR_RPMALLOC
  if (rpmalloc_initialize() != 0) {
    fprintf(stderr, "rpmalloc_initialize failed\n");
    return 5;
  }
  rpmalloc_thread_initialize();
  atexit(rpmalloc_finalize);
  printf("RPMALLOC_POLICY label=%s explicit_thread_lifecycle=1\n", config.label);
#endif

  SYSTEM_INFO info = {};
  GetSystemInfo(&info);
  const uint64_t minAddress =
      reinterpret_cast<uintptr_t>(info.lpMinimumApplicationAddress);
  const uint64_t maxAddress =
      reinterpret_cast<uintptr_t>(info.lpMaximumApplicationAddress);
  const uint64_t userVaBytes = maxAddress >= minAddress
                                   ? (maxAddress - minAddress + 1u)
                                   : 0u;

  printf(
      "CONFIG label=%s pointer_bits=%u live_mib=%zu burst_mib=%zu "
      "survivor_mib=%zu survivor_generations=%u cycles=%u "
      "gc_hold_per_cycle=%u cross_thread=%u max_ms=%u stop_free_mib=%zu "
      "stop_aligned_mib=%zu user_va_mib=%.1f user_va_min=0x%08llX "
      "user_va_max=0x%08llX\n",
      config.label, static_cast<unsigned>(sizeof(void*) * 8u), config.liveMiB,
      config.burstMiB, config.survivorMiB, kSurvivorGenerations,
      config.cycles, config.gcHoldPerCycle, config.crossThread ? 1u : 0u,
      config.maxMs, config.stopFreeMiB, config.stopAlignedMiB,
      MiB(userVaBytes), static_cast<unsigned long long>(minAddress),
      static_cast<unsigned long long>(maxAddress));

  PrintAllocatorPolicy(config);

  if (!RunNativeArenaOwnershipSmoke(config)) {
    return 4;
  }

  const DWORD runStart = GetTickCount();
  PrintSnapshot(config, "process_start", 0);

  const DWORD liveStart = GetTickCount();
  if (!AllocatePattern(&gLive, config.liveMiB * kMiB, 0x13579bdfu,
                       "base-live")) {
    PrintAllocFailure(config, 0);
    PrintSnapshot(config, "live_alloc_failed", 0);
    FreeList(&gLive);
    return 10;
  }
  printf("PHASE_TIME label=%s phase=base-live cycle=0 elapsed_ms=%lu\n",
         config.label, ElapsedMs(liveStart));

  VaSnapshot snapshot = PrintSnapshot(config, "live_ready", 0);
  const char* stopReason = StopThresholdReason(config, snapshot);
  bool stoppedByFailure = false;
  bool stoppedByDuration = false;
  unsigned completedCycles = 0;

  for (unsigned cycle = 1;
       cycle <= config.cycles && !stopReason && !stoppedByFailure; ++cycle) {
    if (config.maxMs && ElapsedMs(runStart) >= config.maxMs) {
      stoppedByDuration = true;
      printf("STOP label=%s cycle=%u reason=duration-limit elapsed_ms=%lu\n",
             config.label, cycle, ElapsedMs(runStart));
      break;
    }

    ThreadContext ctx = {
        &gBurst,
        config.burstMiB * kMiB,
        0x2468ace0u ^ (cycle * 0x9e3779b9u),
        false,
    };

    const bool burstAllocatedOnWorker =
        config.crossThread && (cycle & 1u);
    const DWORD burstStart = GetTickCount();
    bool allocated = false;
    if (burstAllocatedOnWorker) {
      allocated = RunThread(AllocateThread, &ctx);
    } else {
      allocated =
          AllocatePattern(ctx.list, ctx.targetBytes, ctx.seed, "burst");
    }
    printf(
        "PHASE_TIME label=%s phase=burst-alloc cycle=%u elapsed_ms=%lu "
        "worker=%u\n",
        config.label, cycle, ElapsedMs(burstStart),
        burstAllocatedOnWorker ? 1u : 0u);

    if (!allocated) {
      PrintAllocFailure(config, cycle);
      PrintSnapshot(config, "burst_alloc_failed", cycle);
      stoppedByFailure = true;
      break;
    }

    PrintSnapshot(config, "burst_peak", cycle);

    const DWORD freeStart = GetTickCount();
    if (!SplitBurstAndFree(config, cycle, burstAllocatedOnWorker)) {
      printf(
          "FAILURE label=%s cycle=%u kind=cross_thread_free "
          "stage=burst-free\n",
          config.label, cycle);
      stoppedByFailure = true;
      break;
    }
    printf("PHASE_TIME label=%s phase=burst-free cycle=%u elapsed_ms=%lu\n",
           config.label, cycle, ElapsedMs(freeStart));

    snapshot = PrintSnapshot(config, "after_burst_free", cycle);

    const DWORD gcStart = GetTickCount();
    if (!HoldGcChunks(config, cycle, config.gcHoldPerCycle)) {
      PrintSnapshot(config, "gc_hold_failed", cycle);
      stoppedByFailure = true;
      break;
    }

    const bool alignedProbe = ProbeAligned1MiB(config, cycle);
    printf("PHASE_TIME label=%s phase=gc-hold-and-probe cycle=%u "
           "elapsed_ms=%lu\n",
           config.label, cycle, ElapsedMs(gcStart));

    snapshot = PrintSnapshot(
        config, alignedProbe ? "after_gc_hold" : "aligned_probe_failed",
        cycle);

    if (!alignedProbe) {
      stoppedByFailure = true;
      break;
    }

    completedCycles = cycle;
    stopReason = StopThresholdReason(config, snapshot);
    if (stopReason) {
      printf("STOP label=%s cycle=%u reason=%s free_mib=%.1f "
             "aligned1m_max_mib=%.1f\n",
             config.label, cycle, stopReason, MiB(snapshot.freeBytes),
             MiB(snapshot.largestAligned1MiB));
      break;
    }

    if (config.sleepMs) {
      Sleep(config.sleepMs);
    }
  }

  FreeList(&gBurst);
  FreeList(&gToFree);
  FreeList(&gLive);
  for (unsigned i = 0; i < kSurvivorGenerations; ++i) {
    FreeList(&gSurvivors[i]);
  }
  ReleaseGcChunks();
  PrintSnapshot(config, "cleanup", config.cycles);

  const char* status = "completed";
  if (stoppedByFailure) {
    status = "allocation-boundary";
  } else if (stoppedByDuration) {
    status = "duration-limit";
  } else if (stopReason) {
    status = "threshold-stop";
  }

  printf(
      "RESULT label=%s status=%s cycles_completed=%u cycles_requested=%u "
      "elapsed_ms=%lu\n",
      config.label, status, completedCycles, config.cycles,
      ElapsedMs(runStart));
  return 0;
}
