# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-08_pre_xp_build_34213345771.md`](./TEST_LOG_2026-09-08_pre_xp_build_34213345771.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-09 — external Supermium DWrite dependency closure GREEN; project msvcr14x UCRT is a 37/37 export-compatible candidate

Track: Windows XP SP3 x86 graphics/runtime dependency compatibility. Independent of GOST TLS runtime. This is external static dependency evidence only; the workflow does not checkout or build Firefox and does not establish physical-XP runtime behavior.

Exact audit identity:

- workflow `.github/workflows/xp-supermium-dwrite-closure.yml` / `XP Supermium DWrite closure audit`;
- workflow/head SHA `13acb1557b8f96f942e138778f36105bcfed4c4b`;
- Firefox source-under-test: **NOT_APPLICABLE**;
- run `34295093838`;
- job `102289873905` (`Supermium DWrite / XP x86 dependency closure`);
- aggregate result: **completed / success / GREEN**;
- diagnostics artifact `10082963214`, digest `sha256:7b38da13b8c4cd8aba1831c4d0e8cfdcde3c78854ffe76448cea039735d1874e`.

Pinned external identities:

- Supermium tag `v132-r5-02`, asset `supermium_132_32_nonsetup.zip`, SHA-256 `3e181d50818fc95769f123012ad4cc0ffefe882f2fa4606620d2c031638a5912`;
- exact `DWrite.dll`: size `2667048`, SHA-1 `4e466d98bebea7b31764cfb15603b91a5f53fe72`, SHA-256 `945f83efcec25ea71334a2d6117666aa625641cc2a92def474ef96cffa969e77`, file version `1.5.0.2311`;
- YY-Thunks tag `v1.2.2`, source `83d9d0d3f2f212411006e4aa5c5f3db8a6ae2f20`, `YY-Thunks-Lib.zip` SHA-256 `ffe4d9c1b6bb53225ee2af1cac7b36bce90bb1f33ae65f9ba523debcb33ce6ab`, target `5.1.2600.0/x86`.

The corrected forwarder parser includes `(forwarded to module.symbol)` exports, so the UCRT leg that the preceding run omitted is now part of the recursive graph. The exact closure contains 11 app-local PEs:

- `DWrite.dll`;
- Supermium compatibility wrappers `p_advp32.dll`, `p_ole.dll`, `pwp_shd.dll`, `pwrp_k32.dll`;
- five CRT forwarders: `api-ms-win-crt-heap-l1-1-0.dll`, `api-ms-win-crt-math-l1-1-0.dll`, `api-ms-win-crt-runtime-l1-1-0.dll`, `api-ms-win-crt-stdio-l1-1-0.dll`, `api-ms-win-crt-string-l1-1-0.dll`;
- `ucrtbase.dll`.

Audit summary:

- `closure_file_count=11`;
- `companion_file_count=10`;
- `unresolved_external_count=0`;
- `retarget_required_count=10`;
- `yy_fallback_edge_count=9`;
- `provider_graph_status=RESOLVED`;
- `runtime_status=NOT_TESTED`;
- `xp_api_compatibility=REQUIRES_IMPORT_REVIEW`.

The five `api-ms-win-crt-*` DLLs in this closure are pure export-forwarder PEs in the observed graph: their relevant edges forward to `ucrtbase.dll` and they add no ordinary dependency-module edges. Exact `DWrite.dll` directly imports 37 CRT functions through those five forwarders: 5 heap, 11 math, 16 runtime, 3 stdio and 2 string functions.

A post-run static comparison was made against the physically proven project msvcr14x runtime artifact `9756275917` from source `b19ba4ff3eebd2f323743d92110241fc9d4ce399`, run `33387080767`, job `99472017220`. Its exact `ucrtbase.dll` is 908800 bytes, SHA-1 `1cb841790d61c3ed0c48a2a7b3dc8339bee91499`, SHA-256 `de0bd4b2152d9877a9f6e8ac05156bbd83fa7836e727f84bcfd9aa279be27906`, PE subsystem 5.1. All 37 UCRT target export names required by the exact DWrite/API-set path are present in this physically proven msvcr14x `ucrtbase.dll`.

Conclusion: **STATIC PROVIDER CLOSURE PASS, WITH STRONG MSVCR14X UCRT REUSE EVIDENCE.** The preferred integration candidate is to keep the exact Supermium DWrite/wrapper/API-set layer while reusing the project's already selected msvcr14x `ucrtbase.dll` instead of introducing Supermium's separate UCRT binary. Because prebuilt `DWrite.dll` imports the five `api-ms-win-crt-*` DLL names directly, msvcr14x does not by itself remove those five forwarder DLLs; eliminating them would require a separate rebuild/relink or import-rewrite experiment.

Before transfer into the main XP browser workflow, require an automated exact-export compatibility gate against the msvcr14x UCRT used by that build and complete API-level XP review of the DWrite/wrapper closure. When staged, the ten new non-UCRT PEs must enter before the existing subsystem-retarget step, and any current `api-ms-win-*` import-policy exception must be narrow and bound to the exact pinned DWrite/forwarder set. Only after that should a full browser build and physical-XP runtime test be used to claim runtime progress.

Status: **current external static dependency baseline; Firefox integration and physical-XP validation pending.**

---

## 2026-09-08 — XP x32 battery legacy-path remediation builds GREEN and removes the Vista-only USER32 delay imports

Track: Windows XP SP3 x86 build/static compatibility. Independent of GOST TLS runtime. This entry is CI/static evidence, not physical-XP runtime proof.

Exact source/build identity:

- branch `agent/winrt-source-poc`;
- source-under-test `db334d39cf929de7a12ea2f74bea32ddc4f3e4e4`;
- battery implementation commit `b68b925efc504ffe6696fc28848f8df0b3cae343` (`fix(xp): use legacy battery power notifications`);
- battery final-import gate commit `db334d39cf929de7a12ea2f74bea32ddc4f3e4e4` (`ci(xp): gate Vista-only battery imports`);
- lineage also includes `dad33d25dddc060ee74d773dcc492d835a78fd1e`, which removes the earlier rejected shared-memory access-mask override while preserving the successful child-HANDLE inheritance remediation;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34213345771`, attempt `1`;
- job `102019253738` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / success / GREEN**.

Exact artifacts:

- package `10056086223` (`r3dfox-gost-xp-x32-package`), 327,786,207 bytes, digest `sha256:9135b55913dfcf49390d022b94c21520ed2f5852e8b846f4b117635696634949`;
- runtime `10056088395` (`r3dfox-gost-xp-x32-runtime`), 74,928,371 bytes, digest `sha256:2cf7cf6ca44c0d8abddb930564a65bdf57188f4a2ae0fd5a56b29d7c522ce57f`;
- diagnostics `10056127829` (`r3dfox-gost-xp-x32-diagnostics`), 420,515,830 bytes, digest `sha256:04d284ce8738a63b72508e00747576c56fb2dfb86233e6e460fc1803b4234b33`.

The exact run completed the full Firefox compile/link, package, physical-test runtime archive, diagnostics upload and final aggregate verdict. In particular, all of the following completed `success`:

- `Build release r3dfox XP x32`;
- `GATE - Require XP battery Vista-only USER32 imports absent from xul.dll`;
- `GATE - Require source-remediation quartet absent from xul.dll`;
- `GATE - Require ADVAPI32 compatibility family absent from xul.dll`;
- `GATE - Verify mozglue SetProcessDPIAware stays delay-loaded`;
- `GATE - Reject proven core browser XP direct imports`;
- legacy D3DCompiler staging/retarget/package gates;
- msvcr14x packaged CRT gate;
- pinned bcrypt packaged gate;
- `GATE - Audit XP x32 PE floor and direct imports`;
- YY-Thunks DLL entry-point inventory;
- package/runtime/diagnostics uploads;
- `GATE - Summarize XP x32 full build`.

The new battery gate checks both ordinary and delay-load USER32 imports in final `xul.dll` and passed, so this exact binary no longer contains either of the two Vista-only battery APIs that owned the preceding physical exception path:

```text
RegisterPowerSettingNotification
UnregisterPowerSettingNotification
```

The source remediation is intentionally narrow. Under C/C++ `MOZ_XP_COMPAT`, `hal/windows/WindowsBattery.cpp` keeps the existing hidden window and `GetSystemPowerStatus()` data path but listens for the XP-compatible `WM_POWERBROADCAST / PBT_APMPOWERSTATUSCHANGE` notification. The Vista+ `RegisterPowerSettingNotification` / `UnregisterPowerSettingNotification` path remains unchanged for non-XP builds.

This build is also the planned build-level control for the removal of the rejected `Platform::Freeze()` access-mask experiment: source `db334d...` includes that cleanup plus the already physically successful `base::LaunchApp` child-HANDLE inheritance fallback. Static/build success does not establish that SharedPrefMap remains physically passed; that must be checked on this exact new artifact.

Conclusion: **BUILD/STATIC PASS.** The precise `USER32!RegisterPowerSettingNotification` delay-import edge is absent from the final `xul.dll`, and the complete XP build/package/static contract remains GREEN at source `db334d...` / run `34213345771`.

Physical acceptance remains pending. On physical Windows XP SP3 x86, exercise the exact runtime/package artifact and require both:

1. continued advance past the already closed `SharedPrefMap.cpp:25` / invalid child-HANDLE boundary despite removal of the rejected shared-memory access-mask override;
2. advance past the previous `0xC06D007F` / `USER32!RegisterPowerSettingNotification` delay-load boundary.

If a later failure appears, record the next exact runtime boundary rather than reopening either old hypothesis without contradictory evidence.

Status: **current authoritative XP build/static candidate; physical XP runtime validation pending.**

---

## 2026-09-08 — physical XP `0xC06D007F` localized exactly to `USER32!RegisterPowerSettingNotification`

Track: Windows XP SP3 x86 physical runtime / Windows HAL compatibility. Independent of GOST TLS runtime.

Exact runtime identity remained the preceding physically exercised candidate:

- branch `agent/winrt-source-poc`;
- source-under-test `897e1cdf98bcc091e13283fa8004177971d30f27`;
- workflow run `34194737456`, job `101959901573`;
- user physical `r3dfox.exe` SHA-1 `dbfaed8d2d06d50195a572f8364186e4032f8a97`;
- user physical `xul.dll` SHA-1 `fcc09439c4e36be056b5796303f7e433a7afe585`.

The supplied physical-XP DrWatson capture repeatedly reported exception `0xC06D007F`. Exact package binaries and the matching PDB were recovered from the same run; their identities matched the physical files. Symbolization resolved the main-thread path through:

```text
kernel32!RaiseException
__delayLoadHelper2
_tailMerge_user32.dll
mozilla::hal::ObserversManager<mozilla::hal::BatteryInformation>::AddObserver
mozilla::hal::RegisterBatteryObserver
mozilla::gfx::GPUProcessManager::BatteryObserver::BatteryObserver
mozilla::gfx::GPUProcessManager::OnProcessLaunchComplete
```

The delay-load information in the captured stack established:

- loaded module `USER32.dll`;
- `dwLastError = 0x7f` (`ERROR_PROC_NOT_FOUND`);
- the delay-IAT slot maps exactly to `RegisterPowerSettingNotification`;
- the captured procedure-name string is exactly `RegisterPowerSettingNotification`.

Source ownership is `hal/windows/WindowsBattery.cpp::EnableBatteryNotifications()`. The corresponding `UnregisterPowerSettingNotification` API is the same Vista-era mechanism and must also be absent from the XP-compiled path.

Conclusion: **ROOT CAUSE LOCALIZED.** The physical `0xC06D007F` is an MSVC delay-load failure for `USER32.dll!RegisterPowerSettingNotification`, reached when the GPU process manager creates its battery observer. This is not a YY-Thunks ownership problem and should use the legacy Windows source path rather than a thunk.

Remediation selected for the successor build: under `MOZ_XP_COMPAT`, use XP-compatible `PBT_APMPOWERSTATUSCHANGE` and retain `GetSystemPowerStatus()` for the actual battery snapshot; compile out both Vista-only registration APIs. The successor build/static validation is recorded in the entry above.

Status: **physical root cause established on source `897e1cdf...`; successor source `db334d...` removes the edge statically, but physical closure awaits execution of the successor artifact.**
