# Windows XP x86 — CreateWaitableTimerExA status

Last updated: 2026-09-03

This document resolves the project-status ambiguity around `KERNEL32!CreateWaitableTimerExA` in the Windows XP SP3 x86 compatibility track. It is not GOST TLS runtime/handshake evidence.

## Status

**CLOSED by source-level remediation.** `CreateWaitableTimerExA` is not an open XP blocker and is not a function that production Firefox needs to obtain from YY-Thunks.

The older focused YY capability inventory remains historically correct: YY-Thunks 1.2.2 did not provide the requested XP x86 `CreateWaitableTimerExA` capability and therefore the cluster smoke reported it as missing/SKIP. That fact must not be interpreted as a current product blocker after the Firefox source remediation described below.

## Exact source remediation

The exact Firefox owner was identified as `mozilla::baseprofiler::SamplerThread` in:

`mozglue/baseprofiler/core/platform-win32.cpp`

The call was used only to create the profiler's optional high-resolution waitable timer. Firefox already contains a valid fallback path for `mHiResTimer == nullptr`.

Implementation checkpoint:

- branch lineage: `agent/winrt-source-poc`;
- implementation commit: `70422044f90058c90d276f231457f9a08c1343ff`;
- commit title: `xp: keep base profiler unified with legacy Windows define`.

For the legacy-Windows build, the existing `MOZ_NO_WINRT` switch is made available to the base-profiler source. Under that switch `SamplerThread` initializes:

```cpp
mHiResTimer(nullptr)
```

instead of calling:

```cpp
CreateWaitableTimerExA(... CREATE_WAITABLE_TIMER_HIGH_RESOLUTION ...)
```

No emulation, custom thunk, replacement timer API, or runtime probing is required. Execution intentionally follows Firefox's pre-existing no-high-resolution-timer fallback.

## Full Firefox confirmation

The source-level cut was carried into the later full XP x32 Firefox build:

- source-under-test: `17cdb459ec4f115a209fd50ac225cf867b9f3a2f`;
- workflow: `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run: `33638897692`;
- job: `100276666021`;
- package artifact: `9855749298`;
- diagnostics artifact: `9855751471`.

For this exact run:

- full Firefox x86 configure/build/link succeeds;
- `GATE - Reject proven core browser XP direct imports` succeeds;
- `mach package` succeeds;
- the workflow fails later and independently at `GATE - Verify msvcr14x CRT survived portable packaging` because the packaged portable output did not preserve the staged `ucrtbase.dll` and `msvcp140.dll` identities.

Therefore run `33638897692` confirms that the `CreateWaitableTimerExA` source remediation is compatible with the full Firefox build and that the historical `mozglue.dll -> KERNEL32!CreateWaitableTimerExA` edge is no longer the build/import blocker in this lineage.

The later CRT packaging failure does not reopen `CreateWaitableTimerExA`.

## Documentation rule

Any older project note saying that YY-Thunks reports `CreateWaitableTimerExA` as missing/SKIP is retained only as historical capability evidence. The correct current interpretation is:

- `YY capability`: **missing / not used**;
- `Firefox source owner`: **identified**;
- `source remediation`: **implemented**;
- full Firefox compile/link + early selected-core import gate: **PASS** on run `33638897692`, job `100276666021`, source `17cdb459...`;
- current blocker status: **CLOSED**;
- production strategy: **use Firefox's existing `mHiResTimer == nullptr` fallback; do not add a YY thunk**.

Do not put `CreateWaitableTimerExA` back into the open YY-remediation queue unless a future exact build reintroduces the hard import.

## Relationship to current work

Current incremental YY work should target newly observed residual imports such as `InitOnceExecuteOnce`, `GetThreadPreferredUILanguages`, and `QueryFullProcessImageNameA`. `CreateWaitableTimerExA` must not consume another focused or full-build cycle merely because the older capability smoke listed it as unsupported by YY-Thunks.
