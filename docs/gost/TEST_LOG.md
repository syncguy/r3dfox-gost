# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-27_2026-08-28_part2.md`](./TEST_LOG_2026-08-27_2026-08-28_part2.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. For current technical synthesis, see [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); workflow roles are in [`WORKFLOWS.md`](./WORKFLOWS.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, artifact identity/digest when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

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

### Secondary CRT-validation RED is not the current XP blocker

The aggregate Actions job later failed at the post-package CRT verification stage. That RED must not replace the physical-XP loader blocker. The diagnostics artifact itself contains `packaged-crt-contract.txt` proving that the package contains the expected app-local CRT payload, including `ucrtbase.dll` and `msvcp140.dll` with recorded SHA-256 values. Treat the CRT validator failure as a secondary CI/gate issue to clean up, not as evidence that the package lacked those DLLs and not as the next XP runtime target.

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

**Conclusion:** run `33600786738` / job `100153789478` / SHA `0184985c...` closes the 24-API core KERNEL32 cluster at representative/hosted level. The prior `_ProcessPrng@8` failure is closed as a narrow-provider internal-dependency omission. `CreateWaitableTimerExA` remains an expected capability-missing `SKIP` and a separate investigation; physical-XP execution remains a separate gate.

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
**Diagnostics artifact:** `9836714005` (`xp-kernel32-delta-on-srw-baseline-diagnostics`), digest `sha256:163d410b8cf06d6641086c7f454fee3f8b3aab1df1`

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
