# Windows XP x86 — CreateWaitableTimerExA closure evidence

Date: 2026-09-03

Track: Windows XP SP3 x86 compatibility only. This is not GOST TLS runtime/handshake evidence.

## Why this correction exists

An earlier focused KERNEL32/YY-Thunks capability smoke correctly reported that the requested `CreateWaitableTimerExA` capability was not available from the tested YY-Thunks 1.2.2 surface. That historical observation was later easy to misread as a current Firefox/XP blocker.

It is **not** a current blocker.

The project resolved the dependency at the preferred source/configuration boundary instead of adding a thunk. The XP build excludes the base-profiler modern high-resolution waitable-timer path under `MOZ_NO_WINRT`; when that path is unavailable, Firefox uses its existing legacy fallback path. Therefore the generic Windows source may still contain a `CreateWaitableTimerExA` call while the XP product build does not need to import or execute it.

## Historical YY capability evidence — superseded for production planning

- experiment branch: `agent/winrt-source-poc`;
- source-under-test: `0184985c2f0c5ab1c4c732a200cfbda07a6aefb4`;
- Actions run: `33600786738`;
- job: `100153789478`;
- workflow: `XP x86 core KERNEL32 cluster smoke`;
- conclusion relevant to this API: requested YY-Thunks 1.2.2 capability for `CreateWaitableTimerExA` was missing.

This result remains valid as a statement about that focused YY capability inventory only. It is **superseded** as a production blocker because Firefox no longer requires the modern API on the XP path.

## Source remediation

Relevant remediation lineage includes commit:

- `70422044f90058c90d276f231457f9a08c1343ff`.

The XP configuration applies `MOZ_NO_WINRT` to the unified base-profiler compilation unit. The modern waitable-timer path is therefore not part of the XP build; the pre-existing Firefox fallback is selected instead.

Classification:

- remediation class: `SOURCE_REMEDIATION`;
- production status: **CLOSED**;
- YY thunk required: **NO**;
- broad `kernel32.lib` interposition: **NO**.

## Full-build confirmation

Exact evidence identity:

- experiment branch: `agent/winrt-source-poc`;
- source-under-test: `17cdb459ec4f115a209fd50ac225cf867b9f3a2f`;
- workflow: `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run: `33638897692`, attempt `1`;
- job: `100276666021`;
- package artifact: `9855749298`;
- diagnostics artifact: `9855751471`.

Relevant passed boundaries in that exact job:

- `Build release r3dfox XP x32` — **PASS**;
- `GATE - Reject proven core browser XP direct imports` — **PASS**;
- `Package XP x32 experiment` — **PASS**.

The overall workflow is still **RED**, but for a later and independent packaging-integrity failure:

- `GATE - Verify msvcr14x CRT survived portable packaging` — **FAIL**.

The later CRT packaging failure must not be used to reopen the already source-remediated `CreateWaitableTimerExA` dependency.

The final broad XP PE-floor/direct-import audit did not execute because the CRT-survival gate failed first. Therefore this record proves the intended source-remediation/full-build boundary for `CreateWaitableTimerExA`; it is not a claim that the entire package has complete XP import closure.

## Current rule

Do not list `CreateWaitableTimerExA` in the open YY queue or current XP blocker budget.

Reopen only if a later exact XP build shows one of the following:

1. a hard `KERNEL32.dll!CreateWaitableTimerExA` import in a required product PE;
2. a compile/link regression caused by the XP source exclusion;
3. physical-XP runtime evidence showing that the existing fallback path is not sufficient.

Until such contradictory evidence exists, the authoritative status is:

**`CreateWaitableTimerExA` — CLOSED / SOURCE_REMEDIATION / existing Firefox fallback.**
