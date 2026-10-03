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

`IsCommitSpaceLow()` tests `MEMORYSTATUSEX::ullAvailPageFile` against the 200 MB preference. In this project analysis it should be treated as the existing code's low-commit/page-file exhaustion proxy.

This is a plausible last-resort condition and is not currently the primary concern.

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

`nsAvailableMemoryWatcherBase::OnUnloadAttemptCompleted()` handles that result by incrementing the memory-pressure counter and calling:

```text
NS_NotifyOfEventualMemoryPressure(MemoryPressureState::LowMemory)
```

Therefore the disabled tab-unload preference does not make the low-memory path inert. Under a continuously true watcher predicate, Firefox can still repeatedly enter its global memory-pressure path.

This is the central source-level finding.

### Runtime hypothesis to test

On a 2 GB XP system, the fixed 2048 MB physical threshold may cause the browser to spend most or all of its life in repeated low-memory handling, even while automatic tab discard remains disabled.

Possible consequences include excessive cache trimming, repeated memory minimization work, GC/CC-related pressure handling, or other subsystem reactions. These are **hypotheses**, not established explanations for previously observed browser slowness.

Do not attribute past stalls or high RAM use to this mechanism without a controlled physical comparison.

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

It walks each tab's browsing contexts, maps frames to OS PIDs, calls `ChromeUtils.requestProcInfo()`, and obtains child-process memory information.

It then estimates per-tab memory by distributing shared process memory among top-level and subframe users. A top-level frame receives twice the frame weight of a subframe in the estimator.

The selection also computes `uniqueCount`: the number of processes referenced only by one tab. Tabs whose unloading can release more unique processes are favored.

Conceptually the later-stage ranking combines:

```text
base priority / user impact
+ last-accessed ordering
+ unique-process release potential
+ estimated process memory
```

This process-aware mechanism is more relevant to the project's low-RAM target than a WebExtension-level JS heap estimate and should be preserved unless runtime evidence shows a defect.

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

If such a selected tab must be unloaded, the code creates or reuses one `about:blank` recovery tab for that window, selects it, and then discards the original tab. Selected-tab replacement is throttled by a 30-second per-window cooldown.

There is a policy corner case worth testing:

- recently accessed ordinary background tabs younger than the minimum inactive duration are omitted;
- a selected tab in a background window is deliberately kept in the candidate list;
- therefore a fresh selected tab in another window can remain eligible when equally fresh ordinary background tabs are excluded.

No change is proposed yet, but the project's preferred low-RAM policy should probably exhaust normal inactive background tabs before considering any selected tab from any window.

## about:unloads qualification

`about:unloads` is useful for observing the current ranking and manually exercising native discard.

However its UI requests `TabUnloader.getSortedTabs(null)`, and its manual Unload action calls `unloadLeastRecentlyUsedTab(null)`.

Passing `null` disables the normal minimum-inactive-duration filter. Therefore a manual `about:unloads` test does **not** exactly reproduce automatic low-memory selection.

Use it to measure discard effectiveness and process/memory behavior, but do not use it alone to prove automatic 10-minute policy behavior.

## Proposed physical experiment sequence

The first experiment should separate the **watcher trigger** from the **tab-discard mechanism**.

Use the exact currently accepted XP browser package and record the exact binary identity before testing.

### A — current control

Keep:

```text
browser.tabs.unloadOnLowMemory = false
browser.low_physical_memory_threshold_mb = 2048
browser.low_commit_space_threshold_mb = 200
browser.memory_poll_interval_ms = 5000
```

Exercise a repeatable small browsing workload and record:

- available physical memory;
- browser responsiveness;
- process working-set/private-memory behavior where practical;
- evidence of repeated memory-pressure activity if it can be observed without invasive instrumentation.

### B — physical-threshold A/B

Change only:

```text
browser.low_physical_memory_threshold_mb = 512
```

Keep automatic tab unloading disabled and leave the 200 MB commit threshold and 5000 ms poll interval unchanged.

Restart the browser and repeat the same workload.

Purpose: test whether suppressing the structurally over-broad 2048 MB physical trigger changes runtime behavior before introducing tab discard as another variable.

The value 512 MB is an initial diagnostic threshold, not an accepted product default.

### C — native TabUnloader experiment

Only after the trigger behavior is understood, enable:

```text
browser.tabs.unloadOnLowMemory = true
```

with the corrected diagnostic physical threshold.

Create multiple tabs, allow eligible background tabs to exceed the 10-minute inactive duration, then reduce available memory deliberately through a controlled local workload and observe:

- which tab is chosen;
- whether active media/WebRTC/foreground tabs remain protected;
- actual memory reclaimed after discard;
- whether unique content processes exit;
- whether browsing remains usable;
- whether pressure resolves without repeated unnecessary discards.

Do not use the 2048 MB threshold for this acceptance experiment on a 2 GB machine.

## Candidate product direction after evidence

Do not patch the product before the A/B establishes the real runtime behavior.

If the hypothesis is confirmed, prefer the narrowest remediation:

1. fix the XP/low-RAM trigger policy rather than replacing TabUnloader;
2. preserve the 200 MB low-commit emergency path unless evidence says otherwise;
3. derive a physical-memory threshold appropriate to small-memory systems instead of a fixed 2048 MB value;
4. keep foreground selected tabs protected;
5. evaluate whether selected tabs in background windows should also remain protected until all normal eligible background tabs are exhausted;
6. preserve process-aware tab ranking and native `discardBrowser()`.

An XP-only policy under `MOZ_XP_COMPAT` is acceptable if the problem is specific to the XP product target and the normal Windows path should remain unchanged. The final choice between a fixed small threshold, a RAM-relative threshold, or restoration of an event-driven Windows memory-resource notification path requires physical evidence first.

## Evidence status

**PROVEN from source/history:**

- r3dfox commit `80774a9c...` introduced the current WIP enhanced low-memory policy;
- Windows currently polls memory periodically instead of relying on the earlier memory-resource notification path;
- the default physical threshold is 2048 MB;
- the clean product default has automatic tab unloading disabled;
- a low-memory attempt with tab unloading disabled is converted into global `MemoryPressureState::LowMemory`;
- TabUnloader contains process-aware ranking and native browser destruction/lazy restoration.

**NOT YET PROVEN on physical XP:**

- exact frequency of low-memory notifications on the accepted 2 GB machine;
- whether that signaling materially contributes to observed UI stalls or high memory churn;
- the amount of memory reclaimed per native discard for the project's common workloads;
- whether 512 MB is an appropriate product threshold;
- whether the selected-background-window fallback causes undesirable user-visible behavior in practice.

Record physical results in `TEST_LOG.md` after the experiment. Update `PROJECT_STATE.md` only if the experiment changes the accepted blocker, architecture, or next remediation.
