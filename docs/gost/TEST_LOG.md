# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-06_pre_full_xp_green.md`](./TEST_LOG_2026-09-06_pre_full_xp_green.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-07 — physical XP clears the IP Helper boundary and repeatedly hits `MOZ_RELEASE_ASSERT(map)` in `xul.dll`

Track: Windows XP SP3 x86 compatibility / physical runtime. This is independent of GOST TLS runtime and does not prove a GOST TLS handshake.

Exact source/build identity:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `0a18ba85b3f493b17c5a62742e869788ca3f2f6b`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34079480996`, attempt `1`;
- job `101611911453` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **success**;
- runtime artifact `10005434852` (`r3dfox-gost-xp-x32-runtime`), digest `sha256:23ea95085afbe98035f736fafaa04b6225acadfd79dde571de034eca9d4da971`;
- diagnostics artifact `10005435712`, digest `sha256:55615a9294107a6d890d9bb34a61970c225d6425cb15e43e77d45b5b12009d7c`.

The exact Actions job completed the dedicated `DIAG - Record xul IPHLPAPI XP compatibility imports` step and all later build/package/static gates successfully. The user then physically executed this build on Windows XP SP3 x86 and reported that the preceding IP Helper runtime problem is no longer observed. The same build starts on physical Windows 7 x86.

The supplied physical-XP Dr. Watson log `drwtsn32.log`, SHA-256 `15e948215d79d0ce33b2980f5a562764bdc055df8fbdf519e7dea36dd7c3a151`, contains **six** application exceptions between `12:54:42.642` and `12:55:10.313`. All six are the same exception class and same fault site rather than six different crash families:

- exception `0x80000003` (`hardcoded breakpoint`);
- faulting module `xul.dll`;
- `xul.dll` load base `0x01bb0000`;
- fault VA `0x01e34926` / RVA `0x00284926`;
- fault instruction `CC` / `int 3`;
- six distinct `r3dfox.exe` PIDs hit this exact site.

Disassembly of the exact `xul.dll` from package artifact `10005434231` shows the breakpoint is an intentional Mozilla fatal-assert path. Immediately before `int 3`, xul stores a relocated pointer to the crash-reason string. Resolving that pointer against the exact PE yields:

```text
MOZ_RELEASE_ASSERT(map)
```

The matching Firefox/SpiderMonkey source owner is `js/src/wasm/WasmProcess.cpp`, where `map` is the process-wide `sThreadSafeCodeBlockMap`. The exact assertion exists in `wasm::RegisterCodeBlock`, `wasm::UnregisterCodeBlock`, and `wasm::ShutDown`; the early-startup context makes registration-before-initialization the leading interpretation, but stripped Dr. Watson symbols do not yet prove which of those three call sites emitted the inline assert.

Interpretation: **IP HELPER RUNTIME BOUNDARY CLEARED / NEW CURRENT XP BLOCKER = REPEATED WASM PROCESS-MAP RELEASE ASSERT.** The six `0x80000003` events are one repeated fatal path, not six independent incompatibilities. Relative to the user's preceding observation of three hardcoded breakpoints, the increased count can be explained by more process instances/retries reaching the same latent assert after progression past the earlier IP Helper boundary; it is not evidence by itself that three new root causes appeared.

The same source works on Win7 x86, so the next investigation should stay in the XP compatibility track and focus on why SpiderMonkey/Wasm process initialization ordering differs on XP. XP-only synchronization/TLS/one-time-init behavior, including the narrow YY-Thunks path used in `xul.dll`, is a higher-priority hypothesis than further IP Helper work. Do not disable the release assertion as a fix; identify why `sThreadSafeCodeBlockMap` is null at the failing call site.

Status: **current authoritative physical-XP runtime blocker after IP Helper remediation.**

---

## 2026-09-07 — physical XP advances past the `xul.dll` `RtlpWaitForCriticalSection` crash after YY DLL/TLS entry-point integration

Track: Windows XP SP3 x86 compatibility / physical runtime of the exact full-build candidate carrying the YY-Thunks DLL/TLS entry-point contract for `xul.dll`. This is independent of GOST TLS runtime and does not prove a GOST TLS handshake.

Exact source/build identity:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `b386b7f4ba8fd20619a2b7ee541a6b8fe609e278`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34038288272`, attempt `1`;
- job `101500284497` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- runtime artifact `9992440155` (`r3dfox-gost-xp-x32-runtime`), digest `sha256:33731607bbef1e01cfe8b9063be56dd17f149bb9aae547349e7e5b6f5d8c32f4`.

Physical extracted-binary identity reported by the user for the browser actually executed on Windows XP:

- `r3dfox.exe` SHA-1 `a2a64f6eb719d632b6264d48984de9e85a82acb7`;
- `xul.dll` SHA-1 `7ef46570af15390fa1c431c9d1b93ff985d79c22`.

Physical observation supplied by the user: this exact build no longer fails in the previous `xul.dll` startup path at `ntdll!RtlpWaitForCriticalSection`. The earlier crash from runtime artifact `9989657830` is therefore not reproduced after applying the YY-Thunks DLL/TLS entry-point contract to `xul.dll`; execution has advanced beyond that boundary.

Conclusion: **PASS / `RtlpWaitForCriticalSection` BLOCKER CLOSED FOR THE EXACT `b386b7f4...` BROWSER.** The preceding runtime failure remains valid historical evidence for source `176eb94b...`, but it is superseded as the current XP startup blocker. This closure is physical-runtime evidence, not merely a build inference.

The project has already continued beyond this boundary on `agent/winrt-source-poc` into IP Helper API compatibility. The continuation is source-level work after `b386b7f4...`: `97ad36ef0322f307ccb43bc4dd5fdcc744a22f16` adds the XP `NotifyAddrChange` network-monitoring path, `9ea33a7b2972e231c95157db416fe866e6f6c667` activates the XP-owned listener build path, `7e4965bc2057f6f0a75d043f0711fefbcfddff68` replaces the modern MTU interface-table path with a legacy adapter lookup, and current source `0a18ba85b3f493b17c5a62742e869788ca3f2f6b` adds a non-blocking final-`xul.dll` IPHLPAPI import diagnostic. The matching full-build validation run `34079480996`, job `101611911453`, was still **in progress** when this entry was written; no pending IPHLPAPI diagnostic or final build gate is recorded as passed here.

Status: **current authoritative physical closure of the old xul critical-section blocker; superseded as current blocker by the later exact physical-XP `MOZ_RELEASE_ASSERT(map)` result recorded above.**

---

## 2026-09-06 — full XP x32 rebuild is GREEN with the YY-Thunks DLL/TLS entry-point contract applied to `xul.dll`

Track: Windows XP SP3 x86 compatibility / full Firefox build and build-time integration of the narrow YY-Thunks DLL/TLS entry-point contract. This is independent of GOST TLS runtime and does not prove a GOST TLS handshake.

Exact source/build identity:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `b386b7f4ba8fd20619a2b7ee541a6b8fe609e278`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34038288272`, attempt `1`;
- job `101500284497` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate run/job conclusion: **success**.

Exact evidence artifacts:

- package artifact `9992439692` (`r3dfox-gost-xp-x32-package`), `327779922` bytes, digest `sha256:d38cee9081debcab2beedab3b8254574bbc85e6cc135f52839a6ec2bb58db651`;
- runtime artifact `9992440155` (`r3dfox-gost-xp-x32-runtime`), `74923409` bytes, digest `sha256:33731607bbef1e01cfe8b9063be56dd17f149bb9aae547349e7e5b6f5d8c32f4`;
- diagnostics artifact `9992440699` (`r3dfox-gost-xp-x32-diagnostics`), `6007435` bytes, digest `sha256:0820af3fdfc031ca10dc21546c5f4caee6080da7477aac4109c8e5a3be9fdc6f`.

This source is two commits ahead of the preceding GREEN source `176eb94b503e773334593508df408fa491faa45f`, and the compare contains only `.github/workflows/gost-poc-build-xp-x32.yml` changes. Commit `87f09e31b24157af44b3068480295da66e054405` adds the focused `xul.dll` linker contract:

```text
-ENTRY:DllMainCRTStartupForYY_Thunks
-alternatename:_YY_ThunksOriginalDllMainCRTStartup@12=__DllMainCRTStartup@12
```

Commit `b386b7f4ba8fd20619a2b7ee541a6b8fe609e278` fixes the generated `toolkit/library/moz.build` indentation so that the contract is applied under the `xul-real` / `WINNT` scope.

In the exact job, `Apply YY-Thunks XP DLL TLS entry point to xul.dll` completed successfully before configure/build. The subsequent full Firefox compile/link, packaging, source-remediation gates, ADVAPI32 compatibility gate, DPI delay-import gate, core XP direct-import rejection, PE retarget/audit gates, all three artifact uploads, and final summary all completed successfully.

Interpretation: **PASS / FULL-BUILD AND STATIC-COMPATIBILITY BASELINE WITH YY DLL/TLS ENTRY-POINT INTEGRATION.** The project has a fully GREEN browser candidate that includes the intended YY-Thunks DLL/TLS entry-point contract for `xul.dll` without regressing the current build/package/static-import gates.

The subsequent physical-XP experiment is now recorded immediately above. Exact runtime artifact `9992440155`, with user-reported extracted identities `r3dfox.exe` SHA-1 `a2a64f6eb719d632b6264d48984de9e85a82acb7` and `xul.dll` SHA-1 `7ef46570af15390fa1c431c9d1b93ff985d79c22`, advances beyond the prior `RtlpWaitForCriticalSection` failure. Therefore the build-time entry-point integration is not only GREEN but is associated with physical progression past the old blocker on this exact browser.

Status: **authoritative GREEN build/static baseline for the physically proven critical-section closure; newer physical-XP evidence is recorded above.**

---

## 2026-09-06 — physical Win7 x86 starts; physical XP reaches runtime and crashes in `RtlpWaitForCriticalSection`

Track: Windows XP SP3 x86 compatibility / physical runtime of the preceding fully GREEN Firefox build. This is independent of GOST TLS runtime and does not prove a GOST TLS handshake.

Exact source/build identity:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `176eb94b503e773334593508df408fa491faa45f`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34027798932`, attempt `1`;
- job `101471779766`;
- runtime artifact `9989657830` (`r3dfox-gost-xp-x32-runtime`), digest `sha256:64b0f5a0ccf94900fa882069369e26d3beaf46fa128f7b6b650c44d1e87c2c2f`;
- diagnostics artifact `9989658809`, digest `sha256:9e3e9e2e6fac3f0a33a17d94bdf0460edd1020c61c388307a2f8ccd78e2f50fb`.

Physical runtime observations supplied by the user:

- Windows 7 x86: browser starts and works, providing a useful regression check that the compatibility changes did not generically break the x86 browser;
- Windows XP SP3 x86: no then-current loader/import dialog appeared, but startup crashed.

The supplied Dr. Watson log `drwtsn32.log`, SHA-256 `d436c0056af14012fac84aa1b78afe607f61ceb6ba9229cffc9f211b5530d2f4`, records exception `C0000005` in XP `ntdll.dll` at `ntdll!RtlpWaitForCriticalSection`. The stack reaches the failure through `ntdll!RtlEnterCriticalSection` from `xul.dll` during the early `XRE_GetBootstrap` startup path.

At the fault, the critical-section pointer is in `ESI`; `RtlpWaitForCriticalSection` executes:

```text
mov eax,[esi]
inc dword ptr [eax+0x10]
```

and `EAX == 0`. For an x86 `RTL_CRITICAL_SECTION`, the first field is `DebugInfo`; therefore this crash shape is consistent with a contended critical section whose `DebugInfo` pointer is null. XP then dereferences `NULL+0x10` while entering the wait path.

The exact diagnostics artifact also proves that the narrow YY provider linked for the build contains the selected `InitializeCriticalSectionEx` weak alias and the shared `YY_Thunks_for_5.1.2600.0.obj` implementation. Local disassembly of that exact implementation shows its XP fallback ignores the third `Flags` argument and calls `InitializeCriticalSectionAndSpinCount`. Consequently, the hypothesis that this thunk directly propagated `CRITICAL_SECTION_NO_DEBUG_INFO` into XP was not supported by the exact object.

A separate YY integration concern remained: the shared implementation object contains `DllMainCRTStartupForYY_Thunks`, while this older full `xul.dll` link had not explicitly applied YY-Thunks' DLL/TLS entry-point contract. The next exact GREEN source `b386b7f4...` added that contract.

Conclusion at the time: **WIN7 X86 PHYSICAL START PASS / XP PHYSICAL START FAIL / RUNTIME BLOCKER.** This remains authoritative historical evidence for runtime artifact `9989657830`.

Status: **superseded as the current XP blocker.** The exact successor runtime artifact `9992440155` physically advances past `RtlpWaitForCriticalSection`; do not reopen this blocker without contradictory evidence on a later exact browser.

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

The exact job completed the substantive full-build sequence, packaging, compatibility/import gates, evidence collection and final summary with **success**. This was the first current full-build candidate after integrating the accumulated XP compatibility work, including the previously isolated WS2_32 and ANGLE/DXGI blockers, for which the workflow itself was fully GREEN rather than stopping at the final compatibility summary gate.

Interpretation: **PASS / SUPERSEDED FULL-BUILD AND STATIC-COMPATIBILITY BASELINE.** All incompatibilities discovered by this build/audit line were walked through far enough for this exact Firefox 153 XP x86 candidate to build, package and pass the workflow's static compatibility gates. The newer source `b386b7f4...`, run `34038288272`, preserves those gates and adds the YY DLL/TLS entry-point integration, so this earlier build is no longer the newest build/static baseline.

Evidence boundary: this result is not physical Windows XP runtime acceptance. A GREEN CI build cannot establish that no runtime-only missing export, delay-load edge, subsystem behavior, or other XP-specific incompatibility remains. It also proves nothing new about the independent GOST TLS handshake path.

Status: **superseded as build/static baseline by source `b386b7f4...`; remains authoritative for the historical physical runtime result tied to artifact `9989657830`.**