# Windows XP memory pressure / TabUnloader status

Last updated: 2026-10-03

This document is the focused source of truth for the Windows XP / low-RAM analysis around Firefox/r3dfox tab unloading and memory-pressure detection. It is an **XP compatibility / runtime policy** track and is independent of GOST TLS, WebRTC, and packaging evidence.

No runtime PASS/FAIL is claimed here yet. The current state is a source-level analysis plus a proposed low-cost physical A/B experiment.

## Code identity used for this analysis

Repository: `syncguy/r3dfox-gost`.

Canonical documentation branch observed at analysis time:

- `agent/gost-tls-poc@56c9a779e8d8f0386ea50e2300e155ca3d90c99e`.

Windows XP implementation branch observed at analysis time:

- `agent/winrt-source-poc@56ea4129e318e3565dfdd81d0bf60a8735961976`.

Clean physical XP product baseline:

- `win-153-xp@42bfe890d9f508c9e9ce677acf8ecf03ea666626`.

Files analyzed on the clean XP source:

- `xpcom/base/AvailableMemoryWatcherWin.cpp`, blob `d9ac9d681c487e6de768661eb9ebd23460465520`;
- `browser/components/tabbrowser/TabUnloader.sys.mjs`, blob `991f75c2e2559fe752d6d18f8917e7f23215f443`;
- `browser/app/profile/firefox.js`;
- `modules/libpref/init/StaticPrefList.yaml`;
- `xpcom/base/AvailableMemoryWatcher.cpp`;
- `browser/components/tabbrowser/content/tabbrowser.js`.

The analyzed `TabUnloader.sys.mjs` blob is identical on `win-153`, `win-153-xp`, `agent/winrt-source-poc`, and `agent/gost-tls-poc`. The observed behavior therefore predates the project XP compatibility patches and must not be attributed to them.

## r3dfox provenance

Git history identifies r3dfox commit:

- `80774a9c815ec05c1395468213f2df0ebac423c7`;
- subject: `[WIP] Enhanced Tab Unloading on Low Memory`.

That commit materially changes both the Windows memory watcher and TabUnloader policy.

For Windows it replaces the earlier event-driven `CreateMemoryResourceNotification(LowMemoryResourceNotification)` / wait-handle design with an always-running timer that polls `GlobalMemoryStatusEx()`.

It also adds the fixed physical-memory threshold, the configurable polling interval, selected-tab recovery handling, and extended TabUnloader behavior. This WIP provenance is important: the current low-memory policy should be treated as r3dfox-specific behavior requiring validation on the project's 2 GB XP target rather than assumed to be an accepted Mozilla default.

## Current Windows watcher control flow

`nsAvailableMemoryWatcher::Init()` creates an `nsITimer` and starts a repeating slack timer.

Relevant default preferences:

- `browser.memory_poll_interval_ms = 5000`;
- `browser.low_commit_space_threshold_mb = 200`;
- `browser.low_physical_memory_threshold_mb = 2048`.

The interval is clamped to 100..60000 ms.

Every timer callback executes:

```text
Notify()
  -> IsMemoryLow()
       -> IsCommitSpaceLow()
       -> IsPhysicalMemoryLow()
  -> OnLowMemory() or OnHighMemory()
```

The current predicate is logically:

```text
low memory =
    available page-file/commit proxy < 200 MB
    OR
    available physical RAM < 2048 MB
```

Both values come from `GlobalMemoryStatusEx()`.

### Low-commit branch

`IsCommitSpaceLow()` tests `MEMORYSTATUSEX::ullAvailPageFile` against the 200 MB preference.

Terminology matters: `ullAvailPageFile` is used here as Windows-reported available commit headroom; it is not simply "free bytes inside the pagefile", and it does not measure free/contiguous user virtual address space in the 32-bit browser process.

This is the existing code's commit-exhaustion guard and is not currently the primary concern.

### Physical-memory branch

`IsPhysicalMemoryLow()` tests `MEMORYSTATUSEX::ullAvailPhys` against the fixed 2048 MB threshold.

For a machine with approximately 2 GB total physical memory, the condition

```text
available physical memory < 2048 MB
```

is expected to be true during essentially all normal operation because available RAM is necessarily below total installed RAM once the OS and applications occupy memory.

This makes the default physical threshold structurally unsuitable for the project's 2 GB XP target.

This conclusion is source/math analysis. Continuous low-memory runtime signaling on the exact physical machine is **not yet directly measured** and must be verified before it is recorded as runtime fact.

## Important behavior when tab unloading is disabled

The product default in `browser/app/profile/firefox.js` is:

```text
browser.tabs.unloadOnLowMemory = false
```

This does **not** disable the Windows watcher.

On every low-memory watcher invocation:

```text
AvailableMemoryWatcherWin::OnLowMemory()
  -> nsITabUnloader::UnloadTabAsync()
```

`TabUnloader.unloadTabAsync()` observes the disabled preference and returns through:

```text
watcher.onUnloadAttemptCompleted(NS_ERROR_NOT_AVAILABLE)
```

`nsAvailableMemoryWatcherBase::OnUnloadAttemptCompleted()` handles that result by incrementing the memory-pressure counter and requesting:

```text
NS_NotifyOfEventualMemoryPressure(MemoryPressureState::LowMemory)
```

Therefore the disabled tab-unload preference does not make the low-memory path inert.

### Memory-pressure state machine

The eventual request is then normalized by `xpcom/threads/nsMemoryPressure.cpp`.

The delivered observer semantics are:

```text
previous internal state   requested state     delivered notification
NoPressure                LowMemory           memory-pressure / low-memory
LowMemory                 LowMemory           memory-pressure / low-memory-ongoing
LowMemory                 NoPressure          memory-pressure-stop
```

Pending requests can be coalesced before main-thread delivery.

This is an important qualification to the original analysis: a continuously true Windows predicate does **not** imply a fresh full low-memory episode, shrinking GC and cycle collection every polling interval. After the first delivered `low-memory`, subsequent delivered pressure notifications are normally `low-memory-ongoing` until a `NoPressure` transition occurs.

The Windows watcher still calls `UnloadTabAsync()` repeatedly while the predicate remains true; `mUnderMemoryPressure` prevents repeated episode-count increments but does not suppress those calls. A successfully saved memory report is likewise limited to one save per pressure episode by `mSavedReport`.

### Verified consumers of new versus ongoing pressure

The distinction is respected by some expensive consumers:

- `dom/base/nsJSEnvironment.cpp` returns immediately for `low-memory-ongoing`; the initial `low-memory` can set low-memory state and schedule low-memory GC, but ongoing pressure does not repeat that GC/CC path;
- `dom/workers/RuntimeService.cpp` also returns immediately for `low-memory-ongoing`; the initial pressure can set worker low-memory state, run shrinking worker GC, worker CC, and worker memory-pressure handling.

Other verified consumers react to the generic `memory-pressure` topic without checking whether the data is `low-memory` or `low-memory-ongoing`:

- `image/SurfaceCache.cpp` calls its memory-pressure discard path;
- `image/imgLoader.cpp` calls `MinimizeCache()`;
- `netwerk/cache2/CacheObserver.cpp` requests `PurgeFromMemory(PURGE_EVERYTHING)` for the in-memory network cache.

`dom/ipc/ContentParent.cpp` forwards both the pressure reason and pressure-stop state into live content processes, so the observer activity is not limited to the parent process.

Do not describe this as repeatedly clearing the entire disk cache: the verified Necko path is an in-memory purge request.

### Runtime hypothesis to test

On a 2 GB XP system, the fixed 2048 MB physical threshold may keep the browser in a prolonged low-memory state even while automatic tab discard remains disabled.

The most credible recurring cost is therefore not "full GC/CC every five seconds". It is repeated ongoing-pressure work in consumers that do not distinguish the ongoing state, plus observer/IPC activity and possible cache eviction/refill churn. Image re-decoding, disk/network re-fetch work, and user-visible stalls are plausible consequences when caches are actively repopulated, but their physical cost is **not yet established**.

On an already-empty cache, repeated ongoing handling may be cheap. A controlled A/B is required before this mechanism is attributed to previously observed browser slowness.

## TabUnloader behavior when enabled

The automatic tab unloader is guarded by:

```text
browser.tabs.unloadOnLowMemory
```

and the default minimum inactive duration is:

```text
browser.tabs.min_inactive_duration_before_unload = 600000
```

or 10 minutes.

Foreground selected tabs are protected by default because:

```text
browser.tabs.unloadActiveForegroundTab = false
```

### Base weighting

The current r3dfox policy assigns approximately:

- normal background tab: weight 0;
- pinned: +2;
- selected tab in a background browser window: +100;
- selected tab in the foreground browser window: +1000 only if foreground unloading is explicitly enabled, otherwise excluded;
- Picture-in-Picture: effectively non-discardable;
- playing media: effectively non-discardable;
- active WebRTC: effectively non-discardable;
- private browsing tab: effectively non-discardable;
- `undiscardable`: effectively non-discardable;
- ordinary `about:` pages: excluded;
- dedicated recovery tabs: excluded.

The configured `isLoading` criterion has weight 8 in the criterion table, but the current method returns 0 unconditionally, so it does not currently affect ordering.

### Process-aware selection

For a larger candidate set, TabUnloader performs a more expensive process-aware calculation.

It walks each candidate tab's browsing contexts, maps frames to OS PIDs, calls `ChromeUtils.requestProcInfo()`, and obtains child-process memory information.

On Windows, the underlying process-memory helper fills this metric from `PROCESS_MEMORY_COUNTERS_EX::PrivateUsage`. The ranking therefore does not directly measure resident physical RAM and the reported value must not be interpreted as "bytes that unloading this tab will certainly return to physical memory".

It then estimates per-tab memory by distributing shared process memory among top-level and subframe users. A top-level frame receives twice the frame weight of a subframe in the estimator.

The selection also computes `uniqueCount`: the number of processes referenced only by one tab **within the candidate map**. Tabs whose unloading can release more apparently unique processes are favored.

Conceptually the later-stage ranking combines:

```text
base priority / user impact
+ last-accessed ordering
+ unique-process release potential
+ estimated process memory rank
```

The final resource score is ranking-based rather than a direct "largest number of megabytes wins" rule.

There is a source-level limitation: recently used ordinary background tabs are filtered before `getAllProcesses()` constructs the process map. If an excluded fresh tab shares a content process with a retained candidate, that process can appear unique within the analyzed candidate set even though it is not unique across all live tabs. Treat this as an approximation weakness, not a proven runtime defect.

Despite these qualifications, this native process-aware mechanism is more relevant to the project's low-RAM target than a WebExtension-level JS heap estimate and should be preserved unless runtime evidence shows a defect.

### One tab per pressure attempt

`unloadLeastRecentlyUsedTab()` returns after one successful discard.

With the current five-second watcher, sustained pressure therefore tends toward:

```text
pressure event
  -> discard one candidate
  -> wait for next poll
  -> re-evaluate
```

rather than discarding many tabs in one pass.

### Actual discard boundary

The final discard path reaches `gBrowser.prepareDiscardBrowser()` and `gBrowser.discardBrowser()`.

The browser first flushes current tab state to SessionStore, then resets the browser to lazy state, destroys the live browser, removes its panel, and creates a lazy browser placeholder.

This is a real resource-unload operation rather than a cosmetic placeholder implemented by an extension.

## Selected tab in a background window

r3dfox extends the unloader to permit a selected tab from a **background browser window** to remain a last-resort candidate with weight 100.

If such a selected tab must be unloaded, the code creates or reuses one `about:blank` recovery tab for that window, selects it, and then attempts to discard the original tab. Selected-tab replacement is throttled by a 30-second per-window cooldown.

The recovery design avoids uncontrolled multiplication: one marked recovery tab is tracked per browser window and can be reused. The cooldown applies to selected-tab replacement, not to the complete pressure loop.

There is a policy corner case worth testing:

- recently accessed ordinary background tabs younger than the minimum inactive duration are omitted;
- a selected tab in a background window is deliberately kept in the candidate list;
- therefore a fresh selected tab in another window can remain eligible when equally fresh ordinary background tabs are excluded.

There are also transactional review points in the current source:

- selection switches to the recovery tab before final `discardBrowser()` success is known;
- if discard ultimately returns false, there is no explicit rollback to the original selected tab in this path;
- `prepareDiscardBrowser()` is asynchronous, but the complete TabUnloader policy set (media/WebRTC/window-selection status, etc.) is not recalculated after the await immediately before discard.

These are source-level review findings, not demonstrated user-visible failures. No change is proposed yet, but the project's preferred low-RAM policy should probably exhaust normal inactive background tabs before considering any selected tab from any window.

## about:unloads qualification

`about:unloads` is useful for observing the current ranking and manually exercising native discard.

However its UI requests `TabUnloader.getSortedTabs(null)`, and its manual Unload action calls `unloadLeastRecentlyUsedTab(null)`.

Passing `null` disables the normal minimum-inactive-duration filter. Therefore a manual `about:unloads` test does **not** exactly reproduce automatic low-memory selection.

Use it to measure discard effectiveness and process/memory behavior, but do not use it alone to prove automatic 10-minute policy behavior.

## Proposed physical experiment sequence

The first experiment should separate the **watcher trigger** from the **tab-discard mechanism**.

Use the exact currently accepted XP browser package and record the exact binary identity before testing.

Run a short **A -> B -> A** sequence with the same profile, same initial tab set, same warm-up, same observation interval, and the same scripted/manual interaction sequence.

Do not manually invoke `about:unloads` Unload or "Minimize memory usage" during this measurement.

### A1 — current control

Keep:

```text
browser.tabs.unloadOnLowMemory = false
browser.low_physical_memory_threshold_mb = 2048
browser.low_commit_space_threshold_mb = 200
browser.memory_poll_interval_ms = 5000
```

### B — physical-threshold probe

Change only:

```text
browser.low_physical_memory_threshold_mb = 512
```

Keep automatic tab unloading disabled and leave the 200 MB commit threshold and 5000 ms poll interval unchanged. Perform a full browser restart before measuring.

The value 512 MB is a diagnostic probe, not an accepted product default.

For B to isolate the physical-threshold branch, available physical memory must remain at or above 512 MB and available commit headroom must remain at or above 200 MB during the measured interval. If either lower threshold is crossed, continued pressure is expected and the experiment no longer isolates the 2048 MB trigger.

### A2 — return to control

Restore the 2048 MB physical threshold, restart again, and repeat the same workload.

A reproducible B effect that disappears after restoring A is materially stronger than a single A/B comparison.

### Minimum measurements

Prefer direct counters/observability for:

1. separately delivered `memory-pressure / low-memory`, `memory-pressure / low-memory-ongoing`, and `memory-pressure-stop`;
2. available physical memory and available commit headroom over the interval;
3. browser-process CPU time over the same interval and one repeatable UI latency measurement;
4. `TabBrowserDiscarded` count, expected to remain zero because `browser.tabs.unloadOnLowMemory=false`;
5. GC/CC durations/reasons and disk activity if an already convenient measurement path exists.

Do not use the crash annotation / `LowPhysicalMemoryEvents` counter as the event count for item 1: the watcher increments it on entry into a pressure episode, not for every ongoing observer delivery.

### Interpretation

- pressure signals disappear in B but runtime behavior is unchanged: the trigger problem is confirmed, but a material performance cost is not;
- pressure signals disappear in B, a runtime effect reproducibly appears, and the effect returns in A2: the current policy is implicated, but the expensive consumer still requires localization;
- pressure signals do not disappear in B: first determine whether the 512 MB physical condition, 200 MB commit condition, or another pressure source remained active.

Only after this trigger experiment is understood should native `browser.tabs.unloadOnLowMemory` be enabled for a separate discard/reclamation experiment with eligible tabs older than the normal 10-minute inactivity threshold.

## Candidate product direction after evidence

Do not patch the product before the A/B establishes the real runtime behavior.

If the hypothesis is confirmed, prefer the narrowest remediation:

1. fix the XP/low-RAM trigger policy rather than replacing TabUnloader;
2. preserve the 200 MB low-commit emergency path unless evidence says otherwise;
3. for the first product experiment, prefer a small XP-specific fixed physical threshold selected from measurements rather than immediately redesigning the watcher;
4. if the product must support materially different low-RAM classes, evaluate a RAM-relative threshold with sensible lower/upper bounds and hysteresis so threshold jitter does not repeatedly create new low-memory episodes and their expensive initial GC/CC work;
5. keep foreground selected tabs protected;
6. evaluate whether selected tabs in background windows should also remain protected until all normal eligible background tabs are exhausted;
7. preserve process-aware tab ranking and native `discardBrowser()`.

Restoring the earlier event-driven Windows memory-resource notification model remains a valid later design option because the API is available on XP, but it changes both trigger semantics and lifecycle behavior and should not be the automatic first fix. The predecessor was itself a hybrid: OS notification initiated the episode, then polling tracked recovery and commit state.

An XP-only policy under `MOZ_XP_COMPAT` is acceptable if the problem is specific to the XP product target and the normal Windows path should remain unchanged.

## Evidence status

**PROVEN from source/history:**

- r3dfox commit `80774a9c...` introduced the current WIP enhanced low-memory policy;
- Windows currently polls memory periodically instead of relying on the earlier memory-resource notification path;
- the default physical threshold is 2048 MB;
- the clean product default has automatic tab unloading disabled;
- a low-memory attempt with tab unloading disabled requests global `MemoryPressureState::LowMemory`;
- `nsMemoryPressure.cpp` turns the first delivered request into `low-memory`, subsequent delivered requests in the same episode into `low-memory-ongoing`, and a recovery transition into `memory-pressure-stop`;
- main JS and worker GC/CC handlers explicitly skip `low-memory-ongoing`, while verified image/network memory-cache consumers do not distinguish it;
- ContentParent forwards the pressure reason to content processes;
- TabUnloader contains process-aware ranking and native browser destruction/lazy restoration;
- the Windows process-memory metric used by ProcInfo is `PROCESS_MEMORY_COUNTERS_EX::PrivateUsage`.

**NOT YET PROVEN on physical XP:**

- exact frequency of delivered new/ongoing/stop memory-pressure notifications on the accepted 2 GB machine;
- whether ongoing cache/observer/IPC work materially contributes to observed UI stalls or memory/cache churn;
- the amount of memory reclaimed per native discard for the project's common workloads;
- whether 512 MB is an appropriate product threshold;
- whether the selected-background-window fallback causes undesirable user-visible behavior in practice.

Record physical results in `TEST_LOG.md` after the experiment. Update `PROJECT_STATE.md` only if the experiment changes the accepted blocker, architecture, or next remediation.
