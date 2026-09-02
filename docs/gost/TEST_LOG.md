# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-27_2026-08-28_part2.md`](./TEST_LOG_2026-08-27_2026-08-28_part2.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. For current technical synthesis, see [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); workflow roles are in [`WORKFLOWS.md`](./WORKFLOWS.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, artifact identity/digest when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

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
