/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

#ifndef XPVirtualMemoryPool_h
#define XPVirtualMemoryPool_h

#if defined(XP_WIN) && defined(MOZ_XP_COMPAT) && !defined(_WIN64)

#  include <cstddef>
#  include <cstdint>

#  include "Mutex.h"

struct XPVirtualMemoryPoolStats {
  size_t enabled = 0;
  size_t mapRequests = 0;
  size_t mapSuccesses = 0;
  size_t slotReuses = 0;
  size_t fallbackRequests = 0;
  size_t reserveFailures = 0;
  size_t commitFailures = 0;
  size_t poolCreates = 0;
  size_t poolReleases = 0;
  size_t activePools = 0;
  size_t activeSlots = 0;
  size_t reservedBytes = 0;
  size_t unusedSlotBytes = 0;
  size_t peakReservedBytes = 0;
};

class XPVirtualMemoryPool {
 public:
  static constexpr size_t kChunkSize = 1024 * 1024;
  static constexpr size_t kSlotsPerPool = 32;
  static constexpr size_t kPoolSize = kChunkSize * kSlotsPerPool;

  void Init(bool aEnabled);
  bool Enabled() const { return mEnabled; }
  void* Map();
  bool Unmap(void* aChunk);
  void NoteFallback();
  XPVirtualMemoryPoolStats GetStats();

 private:
  static constexpr size_t kMaxPools = 64;

  struct Pool {
    void* mBase = nullptr;
    uint32_t mUsed = 0;
    uint32_t mSeen = 0;
    uint8_t mActive = 0;
  };

  Mutex mLock;
  Pool mPools[kMaxPools] = {};
  XPVirtualMemoryPoolStats mStats;
  bool mEnabled = false;

  static void* ReserveAligned();
};

XPVirtualMemoryPool& GetXPVirtualMemoryPool();

#endif

#endif
