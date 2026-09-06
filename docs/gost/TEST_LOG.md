# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-06_pre_full_xp_green.md`](./TEST_LOG_2026-09-06_pre_full_xp_green.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-06 — physical Win7 x86 starts; physical XP reaches runtime and crashes in `RtlpWaitForCriticalSection`

Track: Windows XP SP3 x86 compatibility / physical runtime of the current fully GREEN Firefox build. This is independent of GOST TLS runtime and does not prove a GOST TLS handshake.

Exact source/build identity:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `176eb94b503e773334593508df408fa491faa45f`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34027798932`, attempt `1`;
- job `101471779766`;
- runtime artifact `9989657830` (`r3dfox-gost-xp-x32-runtime`), digest `sha256:64b0f5a0ccf94900fa882069369e26d3beaf46fa128f7b6b650c44d1e87c2c2f`;
- diagnostics artifact `9989658809`, digest `sha256:9e3e9e2e6fac3f0a33a17d94bdf0460edd1020c61c388307a2f8ccd78e2f50fb`.

Physical runtime observations supplied by the user:

- Windows 7 x86: browser starts and works, providing a useful regression check that the current compatibility changes did not generically break the x86 browser;
- Windows XP SP3 x86: no current loader/import dialog appears, but startup crashes.

The supplied Dr. Watson log `drwtsn32.log`, SHA-256 `d436c0056af14012fac84aa1b78afe607f61ceb6ba9229cffc9f211b5530d2f4`, records exception `C0000005` in XP `ntdll.dll` at `ntdll!RtlpWaitForCriticalSection`. The stack reaches the failure through `ntdll!RtlEnterCriticalSection` from `xul.dll` during the early `XRE_GetBootstrap` startup path.

At the fault, the critical-section pointer is in `ESI`; `RtlpWaitForCriticalSection` executes:

```text
mov eax,[esi]
inc dword ptr [eax+0x10]
```

and `EAX == 0`. For an x86 `RTL_CRITICAL_SECTION`, the first field is `DebugInfo`; therefore this crash shape is consistent with a contended critical section whose `DebugInfo` pointer is null. XP then dereferences `NULL+0x10` while entering the wait path.

This is materially different from the earlier XP startup blockers. The current failure is **not an observed missing direct import or missing-export loader dialog**. The full build/static gates remain valid and GREEN; physical XP has advanced into executable runtime and exposed a synchronization/initialization failure.

The exact diagnostics artifact also proves that the narrow YY provider linked for the build contains the selected `InitializeCriticalSectionEx` weak alias and the shared `YY_Thunks_for_5.1.2600.0.obj` implementation. Local disassembly of that exact implementation shows its XP fallback ignores the third `Flags` argument and calls `InitializeCriticalSectionAndSpinCount`. Consequently, the tempting hypothesis that this thunk directly propagated `CRITICAL_SECTION_NO_DEBUG_INFO` into XP is **not proven and should not be treated as root cause**.

A second YY-specific audit item remains relevant but unproven: the shared YY implementation object contains `DllMainCRTStartupForYY_Thunks`, while the current full-build integration should be checked against YY-Thunks' DLL/TLS entry-point contract. This is a candidate compatibility concern, not a demonstrated explanation for the observed null `DebugInfo` critical section.

Conclusion: **WIN7 X86 PHYSICAL START PASS / XP PHYSICAL START FAIL / NEW RUNTIME BLOCKER.** Static import closure remains closed for the current workflow inventory. The active XP blocker is now the early-runtime `RtlpWaitForCriticalSection` access violation. The next investigation must identify the exact `xul.dll` owner/call site and the initialization history of the specific critical section before changing YY or Firefox synchronization code.

Status: **current authoritative physical-runtime result for source `176eb94b...`; root cause still open.**

---

## 2026-09-06 — full XP x32 build is GREEN after closing all currently discovered build/static blockers

Track: Windows XP SP3 x86 compatibility / full Firefox build, packaging and static import closure. This is independent of GOST TLS runtime and does not prove a GOST TLS handshake.

Exact source/build identity:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `176eb94b503e773334593508df408fa491faa45f`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34027798932`, attempt `1`;
- job `101471779766`;
- aggregate run/job conclusion: **success**.

Exact evidence artifacts:

- package artifact `9989656813` (`r3dfox-gost-xp-x32-package`), `327776567` bytes, digest `sha256:67e490b43001c092f2cb403d88273fd722b9cec5d6b72d1c2bcea02f74fea886`;
- runtime artifact `9989657830` (`r3dfox-gost-xp-x32-runtime`), `74920900` bytes, digest `sha256:64b0f5a0ccf94900fa882069369e26d3beaf46fa128f7b6b650c44d1e87c2c2f`;
- diagnostics artifact `9989658809` (`r3dfox-gost-xp-x32-diagnostics`), `5999340` bytes, digest `sha256:9e3e9e2e6fac3f0a33a17d94bdf0460edd1020c61c388307a2f8ccd78e2f50fb`.

The exact job completed the substantive full-build sequence, packaging, compatibility/import gates, evidence collection and final summary with **success**. This is the first current full-build candidate after integrating the accumulated XP compatibility work, including the previously isolated WS2_32 and ANGLE/DXGI blockers, for which the workflow itself is fully GREEN rather than stopping at the final compatibility summary gate.

Interpretation: **PASS / CURRENT FULL-BUILD AND STATIC-COMPATIBILITY CLOSURE.** All incompatibilities currently discovered by this build/audit line have been walked through far enough for this exact Firefox 153 XP x86 candidate to build, package and pass the workflow's current static compatibility gates. The active project blocker therefore moves beyond build/link/import closure.

Evidence boundary: this result is not physical Windows XP runtime acceptance. A GREEN CI build cannot establish that no runtime-only missing export, delay-load edge, subsystem behavior, or other XP-specific incompatibility remains. It also proves nothing new about the independent GOST TLS handshake path.

The subsequent exact physical-runtime test is now recorded above: Win7 x86 starts, while XP reaches runtime and crashes in `ntdll!RtlpWaitForCriticalSection`. Therefore this build/static result remains valid, but physical-XP acceptance is not achieved.

Status: **current authoritative full XP x32 build/static baseline; build/static blockers currently known are closed.**