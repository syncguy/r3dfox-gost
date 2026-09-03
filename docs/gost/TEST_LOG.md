# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-27_2026-08-28_part2.md`](./TEST_LOG_2026-08-27_2026-08-28_part2.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. For current technical synthesis, see [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); workflow roles are in [`WORKFLOWS.md`](./WORKFLOWS.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, artifact identity/digest when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-03 — full XP x32 package dependency closure GREEN; broad distribution import inventory remains RED

**Track:** Windows XP SP3 x86 compatibility / full Firefox 153 x32 integration  
**Branch:** `agent/winrt-source-poc`  
**Source-under-test:** `4949a16e730cc15fc85b128fd62dac2a27c4d9c5` (`ci(xp): preserve artifacts across diagnostic reds`)  
**Workflow:** `GOST TLS PoC build  XP x32` (`.github/workflows/gost-poc-build-xp-x32.yml`)  
**Actions run:** `33718674533`  
**Job:** `100533128424`  
**Run attempt:** `1`  
**Aggregate result:** failure, intentionally propagated by the final evidence summary after non-fatal diagnostic collection  
**Package artifact:** `9883134667`, `327699666` bytes, digest `sha256:64b9537376b72a9e38728236b666b929e84e9c6895a022a1dd66338b9a645582`  
**Runtime artifact:** `9883135451`, `74911275` bytes, digest `sha256:9a5380bfec2b05a8460f6dfef99c85a1c053e1b31f9f18f101d6a7fc5563127b`  
**Diagnostics artifact:** `9883136547`, `5912540` bytes, digest `sha256:b7fb3503a258d78fec927cd0f81413d5124f6f9b4a61cd27a034ec6092607f1c`

The full build, core-browser import gate, CRT staging, D3D staging/retarget, bcrypt staging, `mach package`, CRT package-survival gate, bcrypt package-survival gate, runtime-archive creation, and all artifact uploads completed successfully.

The previous CRT packaging blocker is closed. `packaged-crt-contract.txt` records accepted archive `r3dfox-v153.0.3.win32.portable.7z` with matching staged/packaged identities: `ucrtbase.dll` SHA-256 `455fa6bc5ceedd89fc3650a224f96ba4dee0fbcb87e2823c1670a4704b737b2f` and `msvcp140.dll` SHA-256 `a1d6099eea3b7742b86ba44a7be7fc64bf0041a80e67ef7e54641ab283285c19`.

The app-local bcrypt contract is also closed at automated build/package level. The accepted archive contains exactly the proven `xp-bcrypt-v1` binary: size `520704`, SHA-1 `ae021f44edc48b03bb4d67cb5773b62bdf60cb67`, SHA-256 `f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`, release asset ID `539647946`.

The aggregate RED is not a packaging failure. The broad all-PE import audit runs with `continue-on-error: true` so diagnostics and runnable artifacts are preserved; it produced 69 known post-XP findings in auxiliary/media/test PEs, and the final summary correctly promoted that diagnostic outcome to the run-level failure. The current residual-three names `InitOnceExecuteOnce`, `GetThreadPreferredUILanguages`, and `QueryFullProcessImageNameA` are absent from that broad forbidden-import report, while the production core-browser gate is GREEN. This advances residual-three to full-build/import evidence but not physical-XP closure.

**Conclusion:** FULL BUILD + CRT PACKAGE + BCRYPT PACKAGE + RUNTIME ARCHIVE GREEN; BROAD DISTRIBUTION IMPORT INVENTORY RED. Runtime artifact `9883135451` is the next exact physical-XP candidate to determine whether startup advances beyond the previously observed `KERNEL32!InitOnceExecuteOnce` edge. Classify broad-audit findings by shipped/runtime-required versus test-only/non-shipped before remediating them. No GOST TLS handshake conclusion follows.

Detailed evidence is also recorded in `TEST_LOG_2026-09-03.md`.

---

## 2026-09-02 — full XP x32 build removes `CreateWaitableTimerExA`; post-package msvcr14x survival is the new immediate RED

**Track:** Windows XP SP3 x86 compatibility / full Firefox 153 x32 integration and package closure  
**Branch:** `agent/winrt-source-poc`  
**Source-under-test:** `17cdb459ec4f115a209fd50ac225cf867b9f3a2f` (`docs(xp): advance waitable timer validation plan`)  
**Workflow:** `GOST TLS PoC build  XP x32` (`.github/workflows/gost-poc-build-xp-x32.yml`)  
**Actions run:** `33638897692`  
**Job:** `100276666021` (`Windows x86 / r3dfox GOST / XP SP3 full build`)  
**Run attempt:** `1`  
**Aggregate run/job result:** failure  
**Package artifact:** `9855749298` (`r3dfox-gost-xp-x32-package`), `250936246` bytes, digest `sha256:b8cd19fda1244a2f2f55ff08bbc35ca180e8d0cbf487ec67cb64d54586b9c6ad`  
**Diagnostics artifact:** `9855751471` (`r3dfox-gost-xp-x32-diagnostics`), `5743723` bytes, digest `sha256:bce0bbdbc778b0114b9d33e670a9bf687e4699cfda7353efebc6b92650f03eed`

### Major build/link/import progression — PASS

The exact job completed every expensive build boundary before packaging validation:

- pinned msvcr14x Release x86 build — PASS;
- mandatory XP x86 msvcr14x runtime contract gate — PASS;
- narrow YY XP x86 provider construction — PASS;
- Firefox x86 configure/export — PASS;
- security manager SSL target-object compile — PASS;
- full `mach build` / `Build release r3dfox XP x32` — PASS;
- core-browser direct-import gate — PASS;
- staging of `ucrtbase.dll` and `msvcp140.dll` into `dist/bin` — PASS;
- legacy XP `D3DCompiler_47.dll` staging/retarget gate — PASS;
- PE subsystem retarget step — PASS;
- pre-package CRT identity recording — PASS;
- `mach package` / `Package XP x32 experiment` — PASS;
- post-package legacy `D3DCompiler_47.dll` survival gate — PASS.

The core-browser gate in this exact workflow rejects 34 already-proven post-XP KERNEL32 APIs — the closed ten SRW/condition-variable APIs plus the closed 24-API KERNEL32 cluster — across all four production core PEs: `r3dfox.exe`, `xul.dll`, `mozglue.dll`, and `plugin-container.exe`. That gate is GREEN and `surviving-sync-imports.txt` is empty.

The workflow's 34-name fatal list at this SHA still does **not** include `CreateWaitableTimerExA`, so its removal must not be inferred merely from the green gate. Independent inspection of the exact diagnostics artifact closes the build/import half of that delta: `CreateWaitableTimerExA` is absent from all four saved core-browser import inventories, including `mozglue.dll-imports.txt`. Therefore the implemented base-profiler source cut successfully removes the historical direct dependency:

`mozglue.dll -> KERNEL32!CreateWaitableTimerExA`

from this exact full Firefox build.

This is stronger than the earlier implementation-only checkpoint, but it is not yet physical-XP runtime closure. `CreateWaitableTimerExA` must remain open until an accepted package advances past that historical loader edge on physical Windows XP.

### New immediate RED — staged msvcr14x CRT is not accepted in any produced package

The first failing step is `GATE - Verify msvcr14x CRT survived portable packaging`.

Immediately before packaging, the job records the exact staged hashes:

- `ucrtbase.dll` SHA-256 `1d4d54cf0d59d2911367d533a6e252316c7c6f53c862de574af1701c20eed6e5`;
- `msvcp140.dll` SHA-256 `61815cf338d36d7ccec21997e693d37ea7a2042b66b49926b64789961e0796b6`.

The exact diagnostics file `packaged-crt-contract.txt` contains only those two pre-package identity lines. It contains no successful `archive=...` record. The gate implementation tests every produced `.7z`/`.zip` candidate and accepts only an archive containing exactly one `ucrtbase.dll` and exactly one `msvcp140.dll`, both with the recorded hashes. No candidate satisfied that contract, so the gate fails.

Independent inspection of the uploaded package artifact confirms the same packaging-boundary problem for the normal ZIP payload: `r3dfox-v153.0.3.win32.zip` contains the successfully preserved `d3dcompiler_47.dll` but contains neither `ucrtbase.dll` nor `msvcp140.dll`.

The package manifest explains the likely mechanism. On Windows, `browser/installer/package-manifest.in` only includes `ucrtbase.dll` under `MOZ_PACKAGE_WIN_UCRT_DLLS` and the MSVC C++ runtime under `MOZ_PACKAGE_MSVC_DLLS`. The XP workflow manually stages the pinned msvcr14x DLLs after the Firefox build, but that staging alone does not activate those Mozilla packaging predicates. This is the leading root-cause hypothesis and should be fixed at the package-input/manifest contract rather than by weakening the post-package gate.

### Important correction to the previous run record

The prior entry for source `6998ba51b1052b08d8b0b2a221d63b896eccd219`, run `33610933602`, job `100185641911`, had described its `packaged-crt-contract.txt` as proof that the portable package contained the expected CRT. Reinspection of that exact earlier diagnostics artifact `9843568460` shows the same structure as the current run: only pre-package hashes are present and there is no successful `archive=...` record. That earlier interpretation was incorrect.

This correction does **not** invalidate the earlier physical-XP `CreateWaitableTimerExA` observation: the exact browser reached that loader edge in that test. It only means the CRT package-survival contract was already independently red and had not been closed by that run.

### Evidence boundary / skipped stages

Because the CRT package-survival gate failed:

- `Build XP x32 runtime test archive from dist/bin` was skipped;
- the broad `GATE - Audit XP x32 PE floor and direct imports` was skipped;
- the dedicated physical-test runtime archive upload was skipped;
- the final workflow summary gate was skipped.

The general package artifact and diagnostics artifact were nevertheless uploaded. The package artifact is valuable build/package evidence but is **not accepted as the next physical-XP runtime candidate** because the required app-local msvcr14x package closure is not validated.

### Conclusion / next step

**BUILD/LINK/CORE-IMPORT PASS; PACKAGE-CONTRACT RED.** Run `33638897692` materially advances the full Firefox XP line: the full x86 browser builds and packages, all 34 already-proven core KERNEL32 imports are absent across the four core PEs, and the exact diagnostics independently prove that `CreateWaitableTimerExA` has disappeared from `mozglue.dll` and the other core import inventories.

The immediate blocker is now the `dist/bin -> packaged archive` survival of the pinned msvcr14x `ucrtbase.dll` + `msvcp140.dll` pair. Repair the package manifest/configuration contract so the exact staged DLLs survive packaging, keep the current hash-equality gate fail-closed, rerun the full workflow from a new exact SHA, require the runtime archive and broad PE audit to execute, and only then use that exact accepted artifact for physical Windows XP startup progression.

No GOST TLS runtime/handshake conclusion follows from this Windows compatibility result.

Status: current immutable experiment evidence; full build/import progression GREEN, packaging CRT survival RED, physical-XP validation of the `CreateWaitableTimerExA` source cut still pending.

---

## 2026-09-02 — `CreateWaitableTimerExA` call-site mapped and XP compile-time cut implemented; build validation pending

**Track:** Windows XP SP3 x86 compatibility / `mozglue.dll` loader closure  
**Branch:** `agent/winrt-source-poc`  
**Prior failing production evidence:** source `6998ba51b1052b08d8b0b2a221d63b896eccd219`, run `33610933602`, job `100185641911`, package artifact `9843567202`, diagnostics artifact `9843568460`  
**Implementation checkpoint:** `70422044f90058c90d276f231457f9a08c1343ff`  
**Actions run for the implementation:** not yet run at this checkpoint

### Exact source owner and semantics

The surviving direct import is owned by the Windows base profiler path in `mozglue/baseprofiler/core/platform-win32.cpp`, specifically `mozilla::baseprofiler::SamplerThread`.

The constructor previously initialized `mHiResTimer` with:

`CreateWaitableTimerExA(nullptr, nullptr, CREATE_WAITABLE_TIMER_HIGH_RESOLUTION, TIMER_ALL_ACCESS)`

Therefore the call is:

- unnamed;
- no custom security attributes;
- auto-reset rather than manual-reset;
- requested with `CREATE_WAITABLE_TIMER_HIGH_RESOLUTION`;
- requested with `TIMER_ALL_ACCESS`;
- used only as the profiler sampler's high-resolution sleep primitive.

This is not a general Firefox synchronization primitive and not part of the GOST TLS runtime path.

### Existing fallback makes an XP source cut semantically valid

`SamplerThread` already has a complete `mHiResTimer == nullptr` path. When the timer is absent, the constructor optionally calls `timeBeginPeriod(...)` for short profiler intervals, `SleepMicro()` uses the existing `Sleep(...)` / sub-millisecond spin fallback, and `Stop()` balances the timer-resolution change with `timeEndPeriod(...)`.

Therefore XP does not require emulation of `CreateWaitableTimerExA`, a new YY thunk, or runtime `GetProcAddress` probing. The correct XP policy is to compile out the high-resolution optimization and enter the existing fallback immediately.

A simple replacement with `CreateWaitableTimerA` or routing through YY's `CreateWaitableTimerExW` fallback was rejected because it could return a non-null ordinary waitable timer and thereby suppress the profiler's intentional `mHiResTimer == nullptr` fallback while not providing the requested high-resolution semantics.

### Implemented source policy

The XP branch reuses the same legacy-Windows build switch already used to exclude WinRT-only code: `MOZ_NO_WINRT`.

At implementation checkpoint `70422044f90058c90d276f231457f9a08c1343ff`:

- `mozglue/baseprofiler/moz.build` defines `MOZ_NO_WINRT` for the Windows base-profiler build while keeping `core/platform.cpp` in its normal unified build;
- `mozglue/baseprofiler/core/platform-win32.cpp` initializes `mHiResTimer(nullptr)` when `MOZ_NO_WINRT` is defined;
- the `CreateWaitableTimerExA` expression is under the opposite compile-time branch and therefore must not contribute a reference/import in the XP build;
- non-legacy builds retain the original high-resolution timer code unchanged.

The net production-code delta from pre-change branch HEAD `fd927a18af3275404ff34bcc79dffd63d1796477` is limited to those two base-profiler files.

### Acceptance / next evidence

This implementation is **not yet a closed GREEN**. The next full XP x32 build must be tied to its exact source SHA/run/job and prove at minimum:

1. Firefox 153 x86 still compiles and links with the existing proven XP baseline;
2. `mozglue.dll` no longer directly imports `KERNEL32!CreateWaitableTimerExA`;
3. the produced PE remains x86 / XP 5.01 compatible under the established gates;
4. the runnable package advances past the historical `CreateWaitableTimerExA` loader failure on physical Windows XP SP3 x86.

If physical XP advances to a new loader/runtime failure, that new exact dependency becomes a separate blocker. The earlier 24-API KERNEL32 cluster remains closed and must not be reopened merely because this new delta is under test.

**Conclusion:** the call-site analysis is complete and supports a minimal compile-time exclusion. The implementation intentionally disables only the high-resolution profiler timer on the legacy-Windows build and relies on Firefox's pre-existing fallback. Status remains **candidate implemented / build and physical-XP validation pending**.

---

## 2026-09-02 — full Firefox XP x32 build reaches the expected physical-XP `CreateWaitableTimerExA` loader blocker

**Track:** Windows XP SP3 x86 compatibility / full Firefox 153 x32 integration and physical-XP loader progression  
**Branch:** `agent/winrt-source-poc`  
**Source-under-test:** `6998ba51b1052b08d8b0b2a221d63b896eccd219` (`ci(xp): run integrated kernel32 source-thunk cluster build`)  
**Workflow:** `GOST PoC build XP x32` (`.github/workflows/gost-poc-build-xp-x32.yml`)  
**Actions run:** `33610933602`  
**Job:** `100185641911` (`Build GOST PoC XP x32`)  
**Aggregate job result:** failure  
**Package artifact:** `9843567202` (`r3dfox-gost-xp-x32-package`), `250937297` bytes, digest `sha256:62a2426e411d36076c372fc93485f9d26b814fcd93df3ca36205dc14da5762e1`  
**Diagnostics artifact:** `9843568460` (`r3dfox-gost-xp-x32-diagnostics`), `5749701` bytes, digest `sha256:8862483c39505599aa75e1db2171472f01ffb5aab65bc1900514fd66ed73783a`

### Build/package boundary

The exact Actions job successfully completed the full Firefox XP x32 compilation and package-generation stages before the later validation failure. This is useful build evidence, but it is **not** a closed XP runtime milestone and must not be promoted to one.

The runnable package was then tested on physical Windows XP SP3 x86. Browser startup fails immediately with the loader dialog:

`r3dfox.exe - Entry Point Not Found`

`The procedure entry point CreateWaitableTimerExA could not be located in the dynamic link library KERNEL32.dll.`

This is the expected physical-XP edge already identified by the earlier loader progression. The new full build therefore **re-confirms rather than closes** the current runtime blocker.

### Exact import evidence from this build

The diagnostics artifact from this exact run contains the final core-browser import inventories under `xp-x32-sync-import-gate/`.

`mozglue.dll-imports.txt` contains, under `DLL: KERNEL32.dll`, the direct symbol:

`CreateWaitableTimerExA`

The corresponding saved inventories for `r3dfox.exe`, `xul.dll`, and `plugin-container.exe` contain no direct `CreateWaitableTimerExA` occurrence. Therefore the exact direct dependency responsible for the physical-XP loader failure is:

`mozglue.dll -> KERNEL32.dll!CreateWaitableTimerExA`

The dialog is presented as an `r3dfox.exe` startup error because loading the browser loads `mozglue.dll`; the direct PE import is in `mozglue.dll`.

### Import-gate defect

The workflow's final direct-import gate scans these exact core-browser import inventories, but its fatal API list covers the 24 already-closed YY capability-present KERNEL32 APIs and **omits `CreateWaitableTimerExA`**.

Elsewhere in the same workflow, `CreateWaitableTimerExA` is explicitly treated as the separately required/outside-provider export because YY-Thunks 1.2.2 exposes no matching XP x86 capability. The final gate therefore had enough project context to know this API remained special, but it did not make a surviving direct `KERNEL32!CreateWaitableTimerExA` import fatal.

That is why the build-time import check did not stop where the physical XP loader later stopped. The gate contract must be hardened so that any surviving direct `CreateWaitableTimerExA` import in the production core-browser binaries is a hard failure until a proven XP-compatible remediation removes it.

### Secondary CRT-validation RED — corrected interpretation

The aggregate Actions job later failed at the post-package CRT verification stage. The earlier interpretation of `packaged-crt-contract.txt` as proof that the portable package contained the expected `ucrtbase.dll` and `msvcp140.dll` was incorrect. Reinspection of exact diagnostics artifact `9843568460` shows only the two pre-package hash lines and no successful `archive=...` record. Therefore this run did **not** close the CRT package-survival contract.

That packaging RED still did not replace the physical-XP blocker observed from this exact test: the browser reached and reported `CreateWaitableTimerExA`. However, once the source cut removes that direct import, CRT package survival must be repaired before the next package is accepted as the physical-XP candidate.

### Conclusion

Run `33610933602` / job `100185641911` / SHA `6998ba51...` proves that the integrated Firefox XP x32 source reaches full build/package generation, but the exact produced browser is **not XP-startup compatible**. Physical Windows XP SP3 x86 and the run's own PE-import diagnostics agree on the same current blocker:

`mozglue.dll -> KERNEL32!CreateWaitableTimerExA`

The next technical work remains the already-defined semantic investigation/remediation for `CreateWaitableTimerExA`, preceded or accompanied by a fail-closed production import gate for this exact symbol. Do not re-open the 24 capability-present KERNEL32 cluster. No GOST TLS runtime/handshake conclusion follows from this XP compatibility result.

Status: current immutable experiment evidence; build/package generation reached, physical XP startup RED at the expected `CreateWaitableTimerExA` loader dependency; current blocker confirmed, not closed.

---

## 2026-09-02 — XP x86 core KERNEL32 capability cluster closes GREEN at representative/hosted level

**Track:** Windows XP SP3 x86 compatibility / YY-Thunks KERNEL32 closure  
**Branch:** `agent/winrt-source-poc`  
**Source-under-test:** `0184985c2f0c5ab1c4c732a200cfbda07a6aefb4` (`ci(xp): restore cluster probe source`)  
**Workflow:** `XP x86 core KERNEL32 cluster smoke` (`.github/workflows/xp-core-kernel32-cluster-smoke.yml`)  
**Actions run:** `33600786738`  
**Job:** `100153789478` (`Core post-XP API cluster / XP x86`)  
**Result:** success  
**YY-Thunks:** `1.2.2`, target `5.1.2600.0` / x86  
**msvcr14x:** pinned commit `6495947edbdd8f5dc4b2ddb8ca0cb5dbdac05384`, `Release|x86`  
**Runtime artifact:** `9835297933` (`xp-core-kernel32-cluster-runtime`), digest `sha256:5c6e9d81e8277dc8225c5e7e7f8fc7dbde66b56184df19e0774a264e1890020d`  
**Diagnostics artifact:** `9835298737` (`xp-core-kernel32-cluster-diagnostics`), digest `sha256:92cc62ac5d452257a26fef13fa5b705277ece44c9df01cebd9ba4013403f179b`

### Exact closure proved by the run

The focused workflow passed the complete representative/hosted sequence:

- pinned msvcr14x `Release|x86` build;
- YY-Thunks 1.2.2 XP x86 capability inventory;
- construction of a physically narrow YY provider rather than broad `kernel32.lib` interposition;
- ordinary x86 `/MD` probe compilation;
- native `lld-link` closure with exit code `0` and `native_link=PASS`;
- XP PE contract/direct-import gate with `cluster_import_gate=PASS`;
- app-local runtime staging;
- functional execution on the hosted Windows runner with `Overall: PASS` and `ExitCode=0`;
- publication of a separate physical-XP runtime bundle and diagnostics artifact.

YY capability inventory reports **24 tested KERNEL32 APIs capable**:

`GetTickCount64`, `InitializeCriticalSectionEx`, `CompareStringOrdinal`, `GetCurrentProcessorNumber`, `GetFileInformationByHandleEx`, `GetFinalPathNameByHandleW`, `GetLocaleInfoEx`, `LCIDToLocaleName`, `LocaleNameToLCID`, `SetFileInformationByHandle`, `CancelIoEx`, `CreateWaitableTimerExW`, `CancelSynchronousIo`, `GetDynamicTimeZoneInformation`, `GetProcessIdOfThread`, `GetQueuedCompletionStatusEx`, `GetThreadId`, `GetTimeZoneInformationForYear`, `GetUserPreferredUILanguages`, `InitOnceBeginInitialize`, `InitOnceComplete`, `QueryFullProcessImageNameW`, `QueryProcessCycleTime`, and `QueryThreadCycleTime`.

The hosted functional probe reports `PASS` for every one of those 24 APIs. The PE gate additionally proves that the final probe is x86 with subsystem version no newer than XP 5.1, retains no direct import of any capability-present API, and contains none of the workflow-forbidden dependency classes `api-ms-win-*`, `ext-ms-*`, `KERNELBASE.dll`, or `bcrypt.dll`.

### `ProcessPrng` diagnosis is closed for this cluster

The immediately preceding diagnostic failure, run `33599812797`, job `100150793264`, source `80e42dd85a2c1902de5fdce402d4983becc2f77c`, failed native link with the exact unresolved symbol `_ProcessPrng@8`. That failure came from YY-Thunks' common implementation / `GetProcAddress` workaround and was an omitted **internal provider dependency**, not evidence that one of the 24 target KERNEL32 APIs was unusable.

Source `0184985c...` restores `_ProcessPrng@8.obj` and `_ProcessPrng@8.obi` to the narrow provider as internal closure members, alongside the capability-present target alias/import members and the common `YY_Thunks_for_5.1.2600.0.obj`. Run `33600786738` then links, passes the PE gate and executes the full 24-API functional probe successfully.

Therefore there is no need to split these 24 APIs into one-by-one shards merely to work around the earlier `_ProcessPrng@8` RED. The broad capability-present cluster itself is now GREEN at the representative/hosted evidence level.

### Explicit boundary: `CreateWaitableTimerExA` remains separate

`CreateWaitableTimerExA` is the sole requested API in this smoke for which YY-Thunks 1.2.2 reports no matching XP x86 capability. It is intentionally emitted as:

`CreateWaitableTimerExA: SKIP (YY capability missing)`

It is not allowed to survive as a direct import merely to make the probe pass, and this GREEN result does not solve or redefine the separate Firefox production/runtime question for `CreateWaitableTimerExA`.

### Evidence boundary

This run proves **representative XP x86 build/link/PE-import closure and hosted functional behavior** for the 24 capability-present APIs with the proven msvcr14x + `synchronization.lib` + physically narrow YY strategy.

It does **not** prove:

- execution of this cluster artifact on a physical Windows XP SP3 x86 machine;
- full Firefox 153 / `mozglue.dll` / `xul.dll` integration;
- a production remediation for `CreateWaitableTimerExA`;
- GOST TLS runtime or handshake behavior.

The workflow's own identity record explicitly classifies its proof level as `YY capability + hosted runner; physical XP pending` and states that no production decision is made by this smoke.

**Conclusion:** run `33600786738` / job `100153789478` / SHA `0184985c...` closes the 24-API core KERNEL32 cluster at representative/hosted level. The prior `_ProcessPrng@8` failure is closed as a narrow-provider internal dependency omission. `CreateWaitableTimerExA` remains an expected capability-missing `SKIP` and a separate investigation; physical-XP execution remains a separate gate.

Status: current immutable experiment evidence; representative/hosted KERNEL32 cluster closure GREEN, physical XP not claimed.

---

## 2026-09-02 — later baseline+delta RED is auxiliary evidence, not a regression of the closed cluster

**Track:** Windows XP SP3 x86 compatibility / auxiliary baseline+delta formulation  
**Branch:** `agent/winrt-source-poc`  
**Source-under-test:** `523601862d227da08819a0e4a74276cf3288fb56`  
**Workflow:** `XP x86 KERNEL32 delta on proven SRW baseline` (`.github/workflows/xp-kernel32-delta-on-srw-baseline-smoke.yml`)  
**Actions run:** `33604407934`  
**Job:** `100165018692` (`Proven SRW/Rust/CRT closure + KERNEL32 delta / XP x86`)  
**Result:** failure  
**Diagnostics artifact:** `9836714005` (`xp-kernel32-delta-on-srw-baseline-diagnostics`), digest `sha256:163d410b8cf06d6641086c5fc21dcc2a093b1467b86c7f454fee3f8b3aab1df1`

Observed execution boundary:

- exact-baseline-plus-delta provider construction PASS;
- unchanged baseline C++ helper PASS;
- KERNEL32 delta helper PASS;
- representative Rust archive PASS;
- native link FAIL;
- PE/import, XP-floor, hosted-runtime and physical-package stages were consequently SKIPPED;
- diagnostics upload PASS.

This workflow is a later, auxiliary re-expression of the experiment. It stopped at native-link evidence and therefore reached a **weaker evidence level** than the already successful run `33600786738`, which completed native link, PE/import closure and hosted functional runtime for the 24 capability-present APIs.

**Conclusion:** run `33604407934` does not revoke, supersede or reopen the GREEN 24-API KERNEL32 cluster. No target-API regression was demonstrated. Future work must not return to re-proving that closed cluster merely because this auxiliary workflow is red.

The active physical-XP production/runtime edge remains the already observed Firefox loader dependency:

`mozglue.dll -> KERNEL32!CreateWaitableTimerExA`

YY-Thunks 1.2.2 has no direct XP x86 capability for `CreateWaitableTimerExA`. The next experiment is therefore **not** another reconstruction of the 24-API cluster: first identify the exact Firefox/r3dfox caller and required `CreateWaitableTimerExA` semantics, then design the narrowest XP-compatible remediation and validate it in a focused probe before any full Firefox rebuild.

Status: current auxiliary RED retained for provenance; does not invalidate the stronger GREEN; not the active blocker.