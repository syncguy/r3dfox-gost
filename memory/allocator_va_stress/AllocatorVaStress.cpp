#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef ALLOCATOR_MOZJEMALLOC
#  include "mozmemory.h"
#endif

#ifdef ALLOCATOR_MIMALLOC
#  include "mimalloc.h"
#endif

namespace {

constexpr size_t kMiB = 1024u * 1024u;
constexpr size_t kPageTouch = 4096u;
constexpr size_t kMaxBlocks = 65536u;
constexpr size_t kMaxGcBlocks = 4096u;
constexpr size_t kGcChunk = 1u * kMiB;
constexpr size_t kGcAlignment = 1u * kMiB;

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
  unsigned cycles;
  unsigned gcHoldPerCycle;
  unsigned sleepMs;
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

struct ThreadContext {
  BlockList* list;
  size_t targetBytes;
  uint32_t seed;
  bool result;
};

BlockList gLive = {};
BlockList gBurst = {};
void* gGcBlocks[kMaxGcBlocks] = {};
size_t gGcBlockCount = 0;

void* TestAlloc(size_t size) {
#ifdef ALLOCATOR_MIMALLOC
  return mi_malloc(size);
#else
  return malloc(size);
#endif
}

void TestFree(void* ptr) {
#ifdef ALLOCATOR_MIMALLOC
  mi_free(ptr);
#else
  free(ptr);
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

bool AllocatePattern(BlockList* list, size_t targetBytes, uint32_t seed) {
  static const size_t kSizes[] = {
      4096u,    16384u,   65536u,   262144u,
      1048576u, 32768u,   131072u,  524288u,
      8192u,    2097152u, 98304u,   393216u,
  };

  list->count = 0;
  size_t allocated = 0;
  uint32_t state = seed;

  while (allocated < targetBytes) {
    if (list->count == kMaxBlocks) {
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

    void* ptr = TestAlloc(size);
    if (!ptr) {
      fprintf(stderr,
              "allocator failure after %.1f MiB in current allocation phase\n",
              static_cast<double>(allocated) / kMiB);
      return false;
    }

    Touch(ptr, size);
    list->blocks[list->count++] = {ptr, size};
    allocated += size;
  }

  return true;
}

void FreeList(BlockList* list) {
  for (size_t i = 0; i < list->count; ++i) {
    TestFree(list->blocks[i].ptr);
    list->blocks[i] = {};
  }
  list->count = 0;
}

DWORD WINAPI AllocateThread(void* raw) {
  ThreadContext* ctx = static_cast<ThreadContext*>(raw);
  ctx->result = AllocatePattern(ctx->list, ctx->targetBytes, ctx->seed);
  return ctx->result ? 0 : 1;
}

DWORD WINAPI FreeThread(void* raw) {
  BlockList* list = static_cast<BlockList*>(raw);
  FreeList(list);
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

uintptr_t AlignUp(uintptr_t value, size_t alignment) {
  const uintptr_t mask = static_cast<uintptr_t>(alignment - 1);
  return (value + mask) & ~mask;
}

void* AllocateAligned1MiB() {
  SYSTEM_INFO info = {};
  GetSystemInfo(&info);

  uintptr_t address =
      reinterpret_cast<uintptr_t>(info.lpMinimumApplicationAddress);
  const uintptr_t maximum =
      reinterpret_cast<uintptr_t>(info.lpMaximumApplicationAddress);

  while (address <= maximum) {
    MEMORY_BASIC_INFORMATION mbi = {};
    SIZE_T queried =
        VirtualQuery(reinterpret_cast<void*>(address), &mbi, sizeof(mbi));
    if (!queried || mbi.RegionSize == 0) {
      return nullptr;
    }

    const uintptr_t base = reinterpret_cast<uintptr_t>(mbi.BaseAddress);
    const uint64_t end64 =
        static_cast<uint64_t>(base) + static_cast<uint64_t>(mbi.RegionSize);
    const uint64_t maxEnd = static_cast<uint64_t>(maximum) + 1u;
    const uintptr_t end =
        static_cast<uintptr_t>(end64 > maxEnd ? maxEnd : end64);

    if (mbi.State == MEM_FREE && end > base) {
      uintptr_t candidate = AlignUp(base, kGcAlignment);
      while (candidate < end &&
             static_cast<uint64_t>(candidate) + kGcChunk <= end) {
        void* ptr = VirtualAlloc(reinterpret_cast<void*>(candidate), kGcChunk,
                                 MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
        if (ptr == reinterpret_cast<void*>(candidate)) {
          Touch(ptr, kGcChunk);
          return ptr;
        }
        if (ptr) {
          VirtualFree(ptr, 0, MEM_RELEASE);
        }
        if (candidate > maximum - kGcAlignment) {
          break;
        }
        candidate += kGcAlignment;
      }
    }

    if (end <= address || end > maximum) {
      break;
    }
    address = end;
  }

  return nullptr;
}

bool HoldGcChunks(unsigned count) {
  for (unsigned i = 0; i < count; ++i) {
    if (gGcBlockCount == kMaxGcBlocks) {
      fprintf(stderr, "GC block table exhausted\n");
      return false;
    }
    void* ptr = AllocateAligned1MiB();
    if (!ptr) {
      fprintf(stderr, "failed to reserve aligned 1 MiB GC-like chunk\n");
      return false;
    }
    gGcBlocks[gGcBlockCount++] = ptr;
  }
  return true;
}

bool ProbeAligned1MiB() {
  void* ptr = AllocateAligned1MiB();
  if (!ptr) {
    return false;
  }
  VirtualFree(ptr, 0, MEM_RELEASE);
  return true;
}

void ReleaseGcChunks() {
  for (size_t i = 0; i < gGcBlockCount; ++i) {
    VirtualFree(gGcBlocks[i], 0, MEM_RELEASE);
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

double MiB(uint64_t bytes) {
  return static_cast<double>(bytes) / static_cast<double>(kMiB);
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
      "free_mib=%.1f reserved_mib=%.1f committed_mib=%.1f "
      "private_mib=%.1f image_mib=%.1f mapped_mib=%.1f "
      "largest_mib=%.1f top5_mib=%.1f top10_mib=%.1f "
      "ge4_mib=%.1f ge4_regions=%u ge16_mib=%.1f ge16_regions=%u "
      "ge64_mib=%.1f ge64_regions=%u free_regions=%u "
      "aligned1m_max_mib=%.1f aligned1m_slots=%llu queried=%u "
      "avail_phys_mib=%.1f avail_pagefile_mib=%.1f avail_virtual_mib=%.1f "
      "gc_held_mib=%zu\n",
      config.label, phase, cycle, snapshot.complete ? 1u : 0u,
      MiB(snapshot.freeBytes), MiB(snapshot.reservedBytes),
      MiB(snapshot.committedBytes), MiB(snapshot.privateBytes),
      MiB(snapshot.imageBytes), MiB(snapshot.mappedBytes),
      MiB(snapshot.largestFree), MiB(snapshot.top5Free),
      MiB(snapshot.top10Free), MiB(snapshot.freeGe4), snapshot.regionsGe4,
      MiB(snapshot.freeGe16), snapshot.regionsGe16, MiB(snapshot.freeGe64),
      snapshot.regionsGe64, snapshot.freeRegions,
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
      512u,
      256u,
      30u,
      2u,
      100u,
      128u,
      2u,
      true,
#ifdef ALLOCATOR_MIMALLOC
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
    } else if (!strcmp(name, "--cycles")) {
      if (!ParseUnsignedArg(value, &config->cycles)) return false;
    } else if (!strcmp(name, "--gc-hold-per-cycle")) {
      if (!ParseUnsignedArg(value, &config->gcHoldPerCycle)) return false;
    } else if (!strcmp(name, "--sleep-ms")) {
      if (!ParseUnsignedArg(value, &config->sleepMs)) return false;
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

bool BelowStopThreshold(const Config& config, const VaSnapshot& snapshot) {
  if (config.stopFreeMiB &&
      snapshot.freeBytes <= config.stopFreeMiB * kMiB) {
    printf("STOP reason=free-va-threshold threshold_mib=%zu\n",
           config.stopFreeMiB);
    return true;
  }

  if (config.stopAlignedMiB &&
      snapshot.largestAligned1MiB <= config.stopAlignedMiB * kMiB) {
    printf("STOP reason=aligned-headroom-threshold threshold_mib=%zu\n",
           config.stopAlignedMiB);
    return true;
  }

  return false;
}

void PrintUsage() {
  puts(
      "allocator-va-stress [--label NAME] [--live-mib N] [--burst-mib N] "
      "[--cycles N] [--gc-hold-per-cycle N] [--sleep-ms N] "
      "[--stop-free-mib N] [--stop-aligned-mib N] [--no-cross-thread]");
}

}  // namespace

int main(int argc, char** argv) {
  Config config = {};
  if (!ParseArgs(argc, argv, &config)) {
    PrintUsage();
    return 2;
  }

  printf(
      "CONFIG label=%s pointer_bits=%u live_mib=%zu burst_mib=%zu cycles=%u "
      "gc_hold_per_cycle=%u cross_thread=%u stop_free_mib=%zu "
      "stop_aligned_mib=%zu\n",
      config.label, static_cast<unsigned>(sizeof(void*) * 8u), config.liveMiB,
      config.burstMiB, config.cycles, config.gcHoldPerCycle,
      config.crossThread ? 1u : 0u, config.stopFreeMiB,
      config.stopAlignedMiB);

  if (sizeof(void*) != 4) {
    fprintf(stderr, "this experiment requires a 32-bit process\n");
    return 3;
  }

  PrintSnapshot(config, "process_start", 0);

  if (!AllocatePattern(&gLive, config.liveMiB * kMiB, 0x13579bdfu)) {
    PrintSnapshot(config, "live_alloc_failed", 0);
    FreeList(&gLive);
    return 10;
  }

  VaSnapshot snapshot = PrintSnapshot(config, "live_ready", 0);
  if (BelowStopThreshold(config, snapshot)) {
    FreeList(&gLive);
    return 0;
  }

  bool stoppedByFailure = false;

  for (unsigned cycle = 1; cycle <= config.cycles; ++cycle) {
    ThreadContext ctx = {
        &gBurst,
        config.burstMiB * kMiB,
        0x2468ace0u ^ (cycle * 0x9e3779b9u),
        false,
    };

    bool allocated = false;
    if (config.crossThread && (cycle & 1u)) {
      allocated = RunThread(AllocateThread, &ctx);
    } else {
      allocated = AllocatePattern(ctx.list, ctx.targetBytes, ctx.seed);
    }

    if (!allocated) {
      PrintSnapshot(config, "burst_alloc_failed", cycle);
      stoppedByFailure = true;
      break;
    }

    PrintSnapshot(config, "burst_peak", cycle);

    bool freed = true;
    if (config.crossThread && !(cycle & 1u)) {
      freed = RunThread(FreeThread, &gBurst);
    } else {
      FreeList(&gBurst);
    }

    if (!freed) {
      fprintf(stderr, "cross-thread free failed\n");
      stoppedByFailure = true;
      break;
    }

    snapshot = PrintSnapshot(config, "after_burst_free", cycle);

    if (!HoldGcChunks(config.gcHoldPerCycle)) {
      PrintSnapshot(config, "gc_hold_failed", cycle);
      stoppedByFailure = true;
      break;
    }

    const bool alignedProbe = ProbeAligned1MiB();
    snapshot = PrintSnapshot(config,
                             alignedProbe ? "after_gc_hold" : "aligned_probe_failed",
                             cycle);
    printf("ALIGNED_PROBE label=%s cycle=%u success=%u\n", config.label, cycle,
           alignedProbe ? 1u : 0u);

    if (!alignedProbe) {
      stoppedByFailure = true;
      break;
    }

    if (BelowStopThreshold(config, snapshot)) {
      break;
    }

    if (config.sleepMs) {
      Sleep(config.sleepMs);
    }
  }

  FreeList(&gBurst);
  FreeList(&gLive);
  ReleaseGcChunks();
  PrintSnapshot(config, "cleanup", config.cycles);

  printf("RESULT label=%s status=%s\n", config.label,
         stoppedByFailure ? "allocation-boundary" : "completed");
  return 0;
}
