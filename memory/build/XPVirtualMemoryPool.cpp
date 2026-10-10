/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

#include "XPVirtualMemoryPool.h"

#if defined(XP_WIN) && defined(MOZ_XP_COMPAT) && !defined(_WIN64)

#  include <windows.h>

#  include "mozilla/Assertions.h"

static constinit XPVirtualMemoryPool sXPVirtualMemoryPool;

XPVirtualMemoryPool& GetXPVirtualMemoryPool() {
  return sXPVirtualMemoryPool;
}

void XPVirtualMemoryPool::Init(size_t aPoolSizeMiB) {
  if ((aPoolSizeMiB == 4 || aPoolSizeMiB == 8 ||
       aPoolSizeMiB == 16 || aPoolSizeMiB == 32 ||
       aPoolSizeMiB == 64) && mLock.Init()) {
    mSlotsPerPool = aPoolSizeMiB;
    mPoolSize = mSlotsPerPool * kChunkSize;
    mEnabled = true;
    mStats.enabled = 1;
    mStats.poolSizeBytes = mPoolSize;
  }
}

void* XPVirtualMemoryPool::ReserveAligned() {
  SYSTEM_INFO systemInfo;
  GetSystemInfo(&systemInfo);

  uintptr_t address =
      reinterpret_cast<uintptr_t>(systemInfo.lpMinimumApplicationAddress);
  const uintptr_t limit =
      reinterpret_cast<uintptr_t>(systemInfo.lpMaximumApplicationAddress);

  while (address <= limit) {
    MEMORY_BASIC_INFORMATION info;
    if (!VirtualQuery(reinterpret_cast<const void*>(address), &info,
                      sizeof(info))) {
      break;
    }

    const uintptr_t base = reinterpret_cast<uintptr_t>(info.BaseAddress);
    const uintptr_t end = base + info.RegionSize;
    if (end <= address) {
      break;
    }

    if (info.State == MEM_FREE) {
      const uintptr_t candidate =
          (base + kChunkSize - 1) & ~(uintptr_t(kChunkSize) - 1);
      if (candidate >= base && candidate <= end &&
          end - candidate >= mPoolSize) {
        void* reserved =
            VirtualAlloc(reinterpret_cast<void*>(candidate), mPoolSize,
                         MEM_RESERVE, PAGE_NOACCESS);
        if (reserved) {
          return reserved;
        }
      }
    }
    address = end;
  }

  return nullptr;
}

void* XPVirtualMemoryPool::Map() {
  if (!mEnabled) {
    return nullptr;
  }

  Pool* pool = nullptr;
  size_t slot = 0;
  uint64_t mask = 0;
  bool reused = false;
  void* chunk = nullptr;

  MutexAutoLock lock(mLock);
  ++mStats.mapRequests;

  {
    for (auto& candidate : mPools) {
      if (candidate.mBase && candidate.mActive < mSlotsPerPool &&
          (!pool || candidate.mActive > pool->mActive)) {
        pool = &candidate;
      }
    }

    if (!pool) {
      for (auto& candidate : mPools) {
        if (!candidate.mBase) {
          pool = &candidate;
          break;
        }
      }
      if (!pool) {
        ++mStats.reserveFailures;
        return nullptr;
      }

      void* reservation = ReserveAligned();
      if (!reservation) {
        ++mStats.reserveFailures;
        return nullptr;
      }
      pool->mBase = reservation;
      pool->mUsed = 0;
      pool->mSeen = 0;
      pool->mActive = 0;
      ++mStats.poolCreates;
      ++mStats.activePools;
      const size_t reserved = mStats.activePools * mPoolSize;
      if (reserved > mStats.peakReservedBytes) {
        mStats.peakReservedBytes = reserved;
      }
    }

    while (slot < mSlotsPerPool && (pool->mUsed & (uint64_t(1) << slot))) {
      ++slot;
    }
    MOZ_RELEASE_ASSERT(slot < mSlotsPerPool);

    mask = uint64_t(1) << slot;
    reused = (pool->mSeen & mask) != 0;
    pool->mUsed |= mask;
    ++pool->mActive;
    ++mStats.activeSlots;
    chunk = reinterpret_cast<void*>(reinterpret_cast<uintptr_t>(pool->mBase) +
                                    slot * kChunkSize);
  }

  if (!VirtualAlloc(chunk, kChunkSize, MEM_COMMIT, PAGE_READWRITE)) {
    MOZ_RELEASE_ASSERT((pool->mUsed & mask) != 0);
    pool->mUsed &= ~mask;
    --pool->mActive;
    --mStats.activeSlots;
    ++mStats.commitFailures;
    if (pool->mActive == 0) {
      MOZ_RELEASE_ASSERT(VirtualFree(pool->mBase, 0, MEM_RELEASE));
      pool->mBase = nullptr;
      pool->mUsed = 0;
      pool->mSeen = 0;
      ++mStats.poolReleases;
      --mStats.activePools;
    }
    return nullptr;
  }

  pool->mSeen |= mask;
  ++mStats.mapSuccesses;
  if (reused) {
    ++mStats.slotReuses;
  }
  return chunk;
}

bool XPVirtualMemoryPool::Unmap(void* aChunk) {
  if (!mEnabled) {
    return false;
  }

  MutexAutoLock lock(mLock);
  const uintptr_t address = reinterpret_cast<uintptr_t>(aChunk);
  for (auto& pool : mPools) {
    if (!pool.mBase) {
      continue;
    }

    const uintptr_t base = reinterpret_cast<uintptr_t>(pool.mBase);
    if (address < base || address - base >= mPoolSize) {
      continue;
    }

    const uintptr_t offset = address - base;
    MOZ_RELEASE_ASSERT((offset & (kChunkSize - 1)) == 0);
    const uint64_t mask = uint64_t(1) << (offset / kChunkSize);
    MOZ_RELEASE_ASSERT(pool.mUsed & mask);

    MOZ_RELEASE_ASSERT(VirtualFree(aChunk, kChunkSize, MEM_DECOMMIT));
    pool.mUsed &= ~mask;
    --pool.mActive;
    --mStats.activeSlots;

    if (pool.mActive == 0) {
      MOZ_RELEASE_ASSERT(VirtualFree(pool.mBase, 0, MEM_RELEASE));
      pool.mBase = nullptr;
      pool.mUsed = 0;
      pool.mSeen = 0;
      ++mStats.poolReleases;
      --mStats.activePools;
    }
    return true;
  }
  return false;
}

void XPVirtualMemoryPool::NoteFallback() {
  if (!mEnabled) {
    return;
  }
  MutexAutoLock lock(mLock);
  ++mStats.fallbackRequests;
}

XPVirtualMemoryPoolStats XPVirtualMemoryPool::GetStats() {
  if (!mEnabled) {
    return XPVirtualMemoryPoolStats{};
  }
  MutexAutoLock lock(mLock);
  XPVirtualMemoryPoolStats snapshot = mStats;
  snapshot.reservedBytes = snapshot.activePools * mPoolSize;
  snapshot.unusedSlotBytes =
      (snapshot.activePools * mSlotsPerPool - snapshot.activeSlots) *
      kChunkSize;
  return snapshot;
}

#endif
