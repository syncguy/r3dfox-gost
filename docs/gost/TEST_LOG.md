# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-08_pre_xp_build_34213345771.md`](./TEST_LOG_2026-09-08_pre_xp_build_34213345771.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-11 — XP x32 successor full build packages successfully; aggregate summary remains RED

Track: Windows XP SP3 x86 full-browser build/static integration. Independent of GOST TLS runtime and not physical-XP browser-runtime evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test `71c7f135210030dde4ec9eeee04e6cb36a2cbffc` (`fix(xp): refresh dwrote checksum after import fix`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34485182943`, attempt `1`;
- job `102897550999` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / failure / RED**.

Exact artifacts uploaded by this run:

- package `10162565742` (`r3dfox-gost-xp-x32-package`), 334,156,033 bytes, digest `sha256:2c416478c8d57ed08f863f1506f5969980ff8b0c1e53845fe4de695f1727592d`;
- runtime `10162567956` (`r3dfox-gost-xp-x32-runtime`), 76,357,019 bytes, digest `sha256:99c67fac2074222371db284e57e0c78a75f617c7b5a3bc0b237bb95154d87fb8`;
- diagnostics `10162609423` (`r3dfox-gost-xp-x32-diagnostics`), 420,570,776 bytes, digest `sha256:a890ac3fc0b972dee2c0a396559cf82ce04f27ee13daa41f0b0ed2c631fd3513`.

The Actions step record establishes the bookkeeping boundary without requiring a log deep-dive. Full Firefox compile/link, all listed targeted xul/mozglue XP gates, private DirectWrite preparation/staging/retarget/package-survival gates, msvcr14x/bcrypt/D3DCompiler package checks, runtime archive creation, `GATE - Audit XP x32 PE floor and direct imports`, YY inventory, and all three artifact uploads completed `success`. The only failed Actions step is `GATE - Summarize XP x32 full build`.

This documentation pass intentionally does **not** inspect or classify the final summary's emitted gate reason and does not inspect the diagnostics payload. Therefore the prior run's analyzed `gate:broad-import-audit=failure` / 22-row private-DWrite finding must not be copied forward as the cause of this run without separate evidence. The exact aggregate cause for run `34485182943` is left **UNCLASSIFIED IN THIS ENTRY**.

Conclusion: **FULL FIREFOX BUILD/PACKAGE/ARTIFACT PRODUCTION PASS; AGGREGATE WORKFLOW RESULT RED AT FINAL SUMMARY.** This run is not GREEN, is not physical-XP browser runtime evidence, and is not GOST TLS handshake evidence. It supersedes run `34439013068` only as the latest integrated full-build identity; the earlier run retains its own exact, separately analyzed 22-row private-DWrite evidence.

Status: **current latest integrated full-build evidence; final-summary failure recorded but deliberately not root-caused in this bookkeeping pass.**

---

## 2026-09-10 — successor private-DWrite-integrated full build packages successfully; broad RED is confined to the same 22 DWrite policy hits

Track: Windows XP SP3 x86 full-browser build/static integration. Independent of GOST TLS runtime and not physical-XP browser-runtime evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test `c0b5561dc58d588ecb970a333d49ac78fae84eb0` (`fix(xp): declare safe DWM attribute helper before use`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34439013068`, attempt `1`;
- job `102749929410` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / failure / RED**.

Exact artifacts uploaded by this run:

- package `10141487002` (`r3dfox-gost-xp-x32-package`), 334,151,885 bytes, digest `sha256:2de12c81d78288dff660c5b15aa1b5a5684bc6f942797abb95405dfbd28c387c`;
- runtime `10141488631` (`r3dfox-gost-xp-x32-runtime`), 76,354,553 bytes, digest `sha256:852da904ab86334dae37f48c40eb64b69c9226db7fef8564279f50b1ea9e98d0`;
- diagnostics `10141520421` (`r3dfox-gost-xp-x32-diagnostics`), 420,568,254 bytes, digest `sha256:1273198aae68a8a677b7441f5ea6422a55986587ff4e407d3f27b62be9456938`.

The Actions step record proves that this is not a Firefox compile/link, staging, packaging, package-integrity, runtime-archive or artifact-upload failure. `Build release r3dfox XP x32`, all targeted xul/mozglue XP import gates, private DirectWrite preparation/staging/retarget/package-survival gates, bcrypt/D3DCompiler/CRT package gates, runtime archive creation, `GATE - Audit XP x32 PE floor and direct imports`, YY inventory and all three uploads completed `success`. The only failed Actions step is `GATE - Summarize XP x32 full build`, whose aggregate verdict remains `gate:broad-import-audit=failure`.

The exact diagnostics artifact localizes that verdict. `xp-x32-forbidden-direct-imports.txt` contains **22 rows total, all 22 attributed to the staged private `dist/bin/xpcompat/dwrite/DWrite.dll` and no other PE**:

```text
AcquireSRWLockExclusive
AcquireSRWLockShared
CreateMutexExW
CreateSemaphoreExW
CreateThreadpoolWork
EventRegister
EventUnregister
EventWriteTransfer
GetLocaleInfoEx
GetUserDefaultLocaleName
InitializeConditionVariable
InitializeCriticalSectionEx
InitializeSRWLock
InitOnceBeginInitialize
InitOnceComplete
ReleaseSRWLockExclusive
ReleaseSRWLockShared
SleepConditionVariableSRW
SubmitThreadpoolWork
TryAcquireSRWLockExclusive
WakeAllConditionVariable
WakeConditionVariable
```

This 22-name set is identical to the forbidden-name set in diagnostics artifact `10112367455` from preceding integrated run `34353829276` / source `35c7482bc7e5f4a37427937ecbf4fdcb6daeffec`. Therefore the successor source introduced no new broad forbidden-name hit in `xul.dll`, `mozglue.dll`, another browser DLL or executable. The aggregate RED remains confined to the already-selected private DWrite component's API-name audit treatment.

Keep the distinction precise: this run itself does not turn the final broad gate GREEN, and the broad diagnostic records API names without enough provider-resolution context to supersede the focused DWrite closure proof. Focused component run `34317489430` / job `102356664699` / artifact `10090864697` remains the physical-XP evidence that the selected private DWrite/provider layout loads and executes `DWriteCreateFactory` and `GetSystemFontCollection()` successfully. The full-build RED is therefore a **static acceptance/policy issue to reconcile with that proven private provider closure**, not evidence that the exact browser artifact has failed on physical XP.

Conclusion: **SUCCESSOR FULL FIREFOX BUILD/PACKAGE PASS; AGGREGATE STATIC ACCEPTANCE RED; RESIDUAL BROAD SET = 22/22 PRIVATE DWRITE ROWS, UNCHANGED FROM THE PRECEDING INTEGRATED BUILD.** Source `c0b5561d...` is the latest completed integrated build evidence, but it is not an all-GREEN static baseline and has no physical-XP browser PASS. Do not re-open already closed xul/mozglue import families from this aggregate RED without contradictory per-PE evidence.

Status: **superseded as latest integrated full-build identity by run `34485182943`; retained as the latest run with the 22-row private-DWrite RED explicitly classified from diagnostics.**

---

## 2026-09-09 — private DirectWrite full Firefox integration builds/packages; aggregate full-build result remains RED

Track: Windows XP SP3 x86 full-browser build/static integration. Independent of GOST TLS runtime. This run transfers the focused physically proven private DirectWrite component into the full Firefox/r3dfox XP build, but it is not physical-XP full-browser runtime evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test `35c7482bc7e5f4a37427937ecbf4fdcb6daeffec` (`ci(xp): integrate proven private DirectWrite closure`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34353829276`, attempt `1`;
- job `102473382783` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / failure / RED**.

Exact artifacts uploaded by this run:

- package `10112321926` (`r3dfox-gost-xp-x32-package`), 334,154,544 bytes, digest `sha256:42a718a7e7913d113d9946bce32fb7e77c17ef6c327b32e1723906770bb2ebf5`;
- runtime `10112323489` (`r3dfox-gost-xp-x32-runtime`), 76,353,966 bytes, digest `sha256:866d3f08ce6dd7ccebcd19bfbfa0f8c8fefd84fbd08014a8b5b981a375f2c583`;
- diagnostics `10112367455` (`r3dfox-gost-xp-x32-diagnostics`), 420,551,770 bytes, digest `sha256:cabf38f27b6ed7eb39bd654c2d875e30556321439cee272a845e5f1dc706fa91`.

The Actions job record establishes that this was **not** a Firefox compile/link, staging, packaging or artifact-upload failure. In particular, all of the following completed `success`:

- `Build release r3dfox XP x32`;
- `Prepare pinned private DirectWrite integration`;
- `Stage pinned private DirectWrite closure`;
- `GATE - Verify private DirectWrite closure after PE retarget`;
- `Package XP x32 experiment`;
- `GATE - Verify private DirectWrite closure survived portable packaging`;
- `Build XP x32 runtime test archive from dist/bin`;
- `GATE - Audit XP x32 PE floor and direct imports`;
- package/runtime/diagnostics uploads.

The existing targeted browser-import gates also remained successful: the XP battery Vista-only USER32 pair, the source-remediation quartet, the ADVAPI32 compatibility family, the mozglue `SetProcessDPIAware` delay-load contract and the proven-core-browser direct-import rejection gate all completed `success`.

The only failed Actions step is the final `GATE - Summarize XP x32 full build`. Its emitted aggregate verdict identifies `gate:broad-import-audit=failure`. This must not be confused with the execution status of the preceding `GATE - Audit XP x32 PE floor and direct imports` step itself, which Actions records as `success`: the audit/evidence collection completed, while its accumulated broad-import policy result made the final aggregate verdict RED.

Conclusion: **FULL FIREFOX PRIVATE-DWRITE INTEGRATION BUILD/PACKAGE PASS; AGGREGATE STATIC ACCEPTANCE RED.** Exact source `35c7482b...` proves that the selected private DirectWrite layout can be integrated into the full Firefox XP build, survive PE retargeting and portable packaging, and produce a physical-test runtime archive. It does **not** supersede the preceding all-GREEN full-build baseline because the aggregate broad-import verdict remains failed.

This result also does not establish physical Firefox startup on XP. The component-scale physical DWrite PASS from run `34317489430` remains valid independently, but the exact browser artifact from run `34353829276` has not acquired a physical-XP PASS merely because the same component was packaged into it.

Status: **current latest private-DWrite-integrated full-build evidence; compile/link/staging/package integration proven, aggregate broad-import acceptance still RED.** Resolve/classify the broad-import findings and obtain an accepted exact integrated browser candidate before using it for the next physical-XP browser boundary test.

---

## 2026-09-09 — Supermium DWrite private component physically passes on XP with load-time project msvcr14x UCRT

Track: Windows XP SP3 x86 graphics/runtime dependency compatibility. Independent of GOST TLS runtime. This is a focused private-component runtime proof; it does not build or run Firefox and does not establish full-browser XP startup.

Exact experiment identity:

- workflow `.github/workflows/xp-supermium-dwrite-closure.yml` / `XP Supermium DWrite closure audit`;
- workflow/head SHA `a42b144cbeeeac6a3765d132111208d600f1a3fc`;
- Firefox source-under-test: **NOT_APPLICABLE**;
- run `34317489430`, attempt `1`;
- job `102356664699` (`Supermium DWrite / XP x86 closure and dist-bin smoke`);
- aggregate result: **completed / success / GREEN**;
- candidate artifact `10090864697` (`xp-supermium-dwrite-dist-bin-34317489430`), 9,022,276 bytes, digest `sha256:de0765b8ed2e28259420d9671c2b4e4a54b492555698724187a7f6ea2ee40a47`;
- diagnostics artifact `10090863781` (`xp-supermium-dwrite-diagnostics-34317489430`), 3,793,851 bytes, digest `sha256:549913f8ea9a92a87bc602bc486e627be25667cec66fe4ef917939fabd29a8ef`.

The candidate preserves the intended future layout:

```text
dist/bin/
  dwrite-loader-smoke.exe
  ucrtbase.dll                         project msvcr14x shared runtime
  xpcompat/dwrite/
    DWrite.dll
    p_advp32.dll
    p_ole.dll
    pwp_shd.dll
    pwrp_k32.dll
    api-ms-win-crt-heap-l1-1-0.dll
    api-ms-win-crt-math-l1-1-0.dll
    api-ms-win-crt-runtime-l1-1-0.dll
    api-ms-win-crt-stdio-l1-1-0.dll
    api-ms-win-crt-string-l1-1-0.dll
```

Supermium `ucrtbase.dll` is **not** staged. The shared `dist/bin/ucrtbase.dll` is built from the project-pinned `Chuyu-Team/msvcr14x` source `6495947edbdd8f5dc4b2ddb8ca0cb5dbdac05384`.

The final focused workflow preserves and passes the static gates established by the preceding closure work:

- recursive provider graph resolved;
- exact Supermium DWrite identity pinned;
- all 37 DWrite CRT imports through the five private `api-ms-win-crt-*` forwarders are satisfied by the staged msvcr14x UCRT export surface;
- final private/shared module graph contains no unresolved edge and no known post-XP direct system-API hit under the workflow policy;
- all staged target PEs are x86 with subsystem 5.01-or-lower after the controlled retarget step;
- the smoke executable itself has a normal **load-time** import on `ucrtbase.dll` via the pinned msvcr14x `ucrt.lib`, rather than late-loading UCRT with `LoadLibraryEx`;
- `_errno` is retained as a static-TLS positive control before private DWrite loading;
- `pwrp_k32.dll` and `DWrite.dll` are loaded by absolute path from `xpcompat/dwrite` with `LOAD_WITH_ALTERED_SEARCH_PATH`.

Physical Windows XP SP3 x86 execution of the exact candidate artifact produced:

```text
UCRT_STARTUP_LOAD_PASS
UCRT_PATH=D:\2026\09\09\xp-supermium-dwrite-dist-bin-34317489430\dist\bin\ucrtbase.dll
UCRT_STATIC_TLS_PASS
PWRP_LOAD_PASS
PWRP_PATH=D:\2026\09\09\xp-supermium-dwrite-dist-bin-34317489430\dist\bin\xpcompat\dwrite\pwrp_k32.dll
DWRITE_LOAD_PASS
DWRITE_FACTORY_PASS
DWRITE_FONT_COLLECTION_PASS
DWRITE_SMOKE_PASS
```

This directly proves all of the following for the exact focused artifact on physical XP:

1. the project msvcr14x `ucrtbase.dll` is loaded from `dist/bin` at process startup;
2. its static TLS is valid for the main thread (`_errno` read/write/restore positive control passes);
3. the exact private `pwrp_k32.dll` is loaded from `dist/bin/xpcompat/dwrite`;
4. the exact private Supermium `DWrite.dll` then loads successfully;
5. `DWriteCreateFactory` succeeds;
6. `IDWriteFactory::GetSystemFontCollection()` succeeds.

The immediately preceding focused artifact from run `34312848959`, job `102342884960`, had produced `UCRT_LOAD_PASS`, `PWRP_LOAD_PASS`, then `DWRITE_LOAD_FAIL GetLastError=0x000003E6` on physical XP. WinDbg localized that failure inside the project msvcr14x UCRT static-TLS access during DWrite CRT process attach. That test late-loaded `ucrtbase.dll` with `LoadLibraryEx`, which is not equivalent to the project's proven XP process-startup CRT model. The final run above fixes only that modeling error by making UCRT a normal executable import; it does **not** substitute Supermium UCRT.

Conclusion: **FOCUSED PHYSICAL XP RUNTIME PASS.** The selected DWrite compatibility architecture is now physically proven at component scale: shared project msvcr14x UCRT loaded at process startup plus an isolated `xpcompat/dwrite` private subtree, with `pwrp_k32.dll` preloaded and `DWrite.dll` loaded through `LOAD_WITH_ALTERED_SEARCH_PATH`. The earlier idea that Supermium UCRT is required is rejected for this focused path.

Next step is Firefox integration, not another standalone DWrite closure experiment: stage the proven private subtree in the main XP package and implement the narrow XP DWrite owner load path while preserving normal system DWrite behavior on Vista/7. A successful full build will still require a separate physical Firefox XP runtime test before the graphics/runtime blocker is called closed.

Status: **current focused DWrite runtime baseline; component-scale physical XP PASS, Firefox integration pending.**

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

Status: **historical static dependency baseline; superseded for component runtime by the physical PASS above.**

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