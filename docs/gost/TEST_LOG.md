# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-12_pre_angle_d3d9_graph_pass.md`](./TEST_LOG_2026-09-12_pre_angle_d3d9_graph_pass.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-12 — exact-vendored ANGLE D3D9 generated graph passes the authoritative semantic gate

Track: Windows XP SP3 x86 ANGLE build-graph generation. Independent of GOST TLS runtime and not physical-XP browser-runtime evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test and Actions head SHA `7b214d64fe0110431c73ef9e81f17e37c33b2926`;
- workflow `.github/workflows/xp-angle-d3d9-regenerate.yml` / `XP ANGLE D3D9-only regeneration smoke`;
- run `34684794502`;
- job `103529796175` (`Regenerate exact vendored ANGLE with D3D11 disabled`);
- aggregate result: **completed / success / GREEN**;
- evidence artifact `10295651148` (`xp-angle-d3d9-regeneration-34684794502`), 361,098 bytes, digest `sha256:e680e33dc7a788a6a4b4230c7f12af40e0f0fa97cf837d7bc13e186b09f11c7d`.

The persisted generated `libGLESv2.moz.build` passes the authoritative post-regeneration semantic gate:

- `d3d11_source_refs=0`;
- `d3d9_source_refs=20`;
- `ANGLE_ENABLE_D3D11_TRUE=False`;
- `ANGLE_ENABLE_D3D9_TRUE=True`;
- `Renderer11=False`, `Renderer9=True`;
- `CompositorNativeWindow11=False`;
- `dxgi_format_map_autogen=False`;
- `dxgi_support_table_autogen=False`;
- `dxgi_format_map_header=False`;
- `dxgi_support_table_header=False`;
- shared `d3d_format.cpp=True`;
- `OS_LIBS_d3d11=False`, `OS_LIBS_d3d9=True`.

`OS_LIBS_dxgi=True` is retained only as diagnostic evidence because it is also `True` in the baseline generated file; it is not evidence that the four D3D11-owned DXGI format/support-table sources remain. Likewise `d3d_format.h` is a GN/header dependency and is not required to appear as a compile-source line in this generated `moz.build`.

The artifact also preserves the raw graph evidence: `gn-desc.json` is 582,587 bytes (`sha256:e1750ac65e388cbf56cff1fa69b5860494d97e8b5db5ce102a3700b513165570`) and `export-targets.json` is 126,888 bytes (`sha256:fc8e788b164c572d28515a9d404f2163d789671b18074fc8290e12455faac821`).

One harness distinction is intentional and must remain explicit: the older internal regeneration script still reports `regeneration_step_outcome=failure` after regeneration because its legacy blanket checkout-change verdict is overbroad. The workflow deliberately treats that step as diagnostic and makes the subsequent semantic validator authoritative. In this run the semantic validator reports `semantic validation PASS`, and the aggregate job/workflow result is GREEN. The earlier REDs caused by SDK pinning, shallow merge-base history, native-stderr handling and fragile harness patching are therefore test-infrastructure history, not evidence against the generated D3D9 graph.

Conclusion: **FOCUSED ANGLE SOURCE-GRAPH PASS.** For the exact Firefox/r3dfox 153 vendored ANGLE snapshot, the narrow `angle_d3d_format_tables` split removes the four D3D11-owned DXGI format/support-table files while retaining the D3D9 backend and shared D3D format implementation. The functional correction remains a small conditional in upstream `BUILD.gn`; manually deleting final generated `moz.build` entries is not required.

This does **not** prove a full Firefox/r3dfox XP build, final PE/import cleanliness, physical Windows XP runtime, or GOST TLS behavior. Next evidence boundary: transfer the narrow source-graph fix into the full XP x86 build, inspect the resulting final PE/import evidence independently, and then exercise the exact accepted browser artifact on physical XP.

Status: **current authoritative focused ANGLE D3D9 graph closure.**

---

## 2026-09-12 — transferred ANGLE D3D9 graph correction passes focused XP x86 libGLESv2 build

Track: Windows XP SP3 x86 ANGLE focused compile/link integration. Independent of GOST TLS runtime and not full-browser or physical-XP evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test and Actions head SHA `e7424ea9b68eafae79513e5d794b799e0ec454b7`;
- product-change commit `e7424ea9b68eafae79513e5d794b799e0ec454b7` (`build(xp): apply generated ANGLE D3D9 graph fix`);
- trigger workflow `.github/workflows/xp-angle-smoke-trigger.yml` calling `.github/workflows/xp-angle-libglesv2-smoke.yml`;
- run `34686743277`;
- job `103534931543` (`ANGLE libGLESv2 / XP x86 focused build`);
- aggregate result: **completed / success / GREEN**;
- evidence artifact `10296028734` (`xp-angle-libglesv2-smoke`), 1,573,962 bytes, digest `sha256:6790fa5618456237e5a2290e21dcae88a3805eed1c0ac6c39a8399f9b99dcf61`.

The transferred product/build-path change is deliberately narrow. In generated `gfx/angle/targets/libGLESv2/moz.build` it removes `dxgi_format_map_autogen.cpp`, `dxgi_support_table_autogen.cpp`, and the `dxguid` OS library while retaining the D3D9 backend, shared `d3d_format.cpp`, and the pre-existing `dxgi` OS library. Regeneration-only infrastructure used to prove the graph — temporary generator/export patches, hosted-SDK adaptation, ANGLE-history handling, PowerShell native-stderr handling and semantic-validator plumbing — was not promoted into the product build path.

The focused job completed every decisive build stage successfully: configure/export prerequisites, bulk dependency dry-run diagnostics, the real libGLESv2 link-prerequisite closure, focused `mozglue.dll` inspection, `Build libGLESv2 only`, and `GATE - Inspect focused libGLESv2 binary`. Artifact upload and final summary also passed.

Conclusion: **FOCUSED ANGLE libGLESv2 COMPILE/LINK PASS.** The correction proven by the preceding source-graph experiment now survives a real focused Gecko XP x86 target build and focused binary-inspection gate on exact source `e7424ea9...`.

This does **not** prove the canonical full Firefox/r3dfox XP x86 build/package, browser-wide final PE/import cleanliness, or physical Windows XP runtime. The next evidence boundary is the full `.github/workflows/gost-poc-build-xp-x32.yml` integration build from exact source `e7424ea9b68eafae79513e5d794b799e0ec454b7`, followed by independent final PE/import evaluation and only then physical XP execution of the accepted artifact.

Status: **current authoritative focused ANGLE integration/build closure.**

---

## 2026-09-12 — canonical XP x86 full build passes after ANGLE D3D9 transfer and private-DWrite audit correction

Track: Windows XP SP3 x86 full-browser build/static compatibility. Independent of GOST TLS handshake/runtime proof and not physical-XP execution evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test and Actions head SHA `5845ff2da277f2cc4af40f74a1ef5dd8b8b2da11`;
- parent product graph fix `e7424ea9b68eafae79513e5d794b799e0ec454b7` (`build(xp): apply generated ANGLE D3D9 graph fix`);
- head commit `5845ff2da277f2cc4af40f74a1ef5dd8b8b2da11` (`fix(xp): exempt pinned private DWrite APIs from broad audit`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34688317433`;
- job `103539109910` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / success / GREEN**.

All decisive full-build/static stages completed successfully, including `Build release r3dfox XP x32`, the targeted xul/mozglue XP compatibility import gates, staging of the pinned XP CRT / legacy `D3DCompiler_47.dll` / private DirectWrite closure / proven `bcrypt.dll`, PE subsystem retargeting, package creation, post-package closure checks, runtime-test archive creation, `GATE - Audit XP x32 PE floor and direct imports`, YY-Thunks inventory, all three artifact uploads, and `GATE - Summarize XP x32 full build`.

Artifacts bound to the exact source-under-test:

- package artifact `10298184343` (`r3dfox-gost-xp-x32-package`), 333,354,453 bytes, digest `sha256:2458506d6285702bf3d86e5d0345a3a7a974a21353cdbe713875fc03b5a779bd`;
- physical-test runtime artifact `10297859657` (`r3dfox-gost-xp-x32-runtime`), 76,170,738 bytes, digest `sha256:734a9b5189e11d3a38d0916c04e8efa98043a66e83ebce933cd39bf1abc981fc`;
- diagnostics artifact `10298342641` (`r3dfox-gost-xp-x32-diagnostics`), 420,551,835 bytes, digest `sha256:c12b0599aef570df9a90b725acb52eaa130f71e1af6e848c633287864d8d0347`.

Conclusion: **FULL XP x86 BUILD / PACKAGE / STATIC PE-IMPORT BASELINE GREEN.** The narrow ANGLE D3D9 generated build-path correction is now integrated into the canonical full Firefox/r3dfox 153 XP x86 build, and the corrected private-DWrite broad-audit ownership no longer makes the aggregate build RED. This supersedes run `34485182943` / source `71c7f135...` as the latest integrated full-build/static baseline.

This result does **not** prove that the produced browser starts or remains stable on physical Windows XP, does not by itself close the existing default-font/runtime boundary, and does not prove any GOST TLS handshake behavior. The next acceptance boundary is physical Windows XP SP3 x86 execution of the exact runtime/package from source `5845ff2d...`, with matching binary/PDB/hash identity captured before interpreting any runtime result.

Status: **current authoritative all-GREEN XP full-build/static baseline; physical XP runtime pending.**

---

## 2026-09-12 — physical XP run of the all-GREEN build reaches two distinct intentional-breakpoint runtime failures

Track: Windows XP SP3 x86 physical browser runtime. Independent of GOST TLS handshake evidence.

Exact build lineage under test:

- branch/source-under-test `agent/winrt-source-poc` / `5845ff2da277f2cc4af40f74a1ef5dd8b8b2da11`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml`;
- run `34688317433`, job `103539109910`;
- package artifact `10298184343`, runtime artifact `10297859657`, diagnostics artifact `10298342641`;
- diagnostics artifact digest `sha256:c12b0599aef570df9a90b725acb52eaa130f71e1af6e848c633287864d8d0347`;
- physical OS: Windows XP SP3 x86 / 5.1.2600.

The user supplied two DrWatson captures from the extracted package lineage. Both failures are `0x80000003` hardcoded breakpoints, not loader missing-entry-point failures and not access violations. The loaded-module lists no longer contain `combase.dll`, so the previous COMBASE dependency is not the current boundary.

### Boundary A — early Rust/dwrote DirectWrite factory assertion

One capture faults in `xul.dll` on an `int 3`; its absolute runtime address is withheld under the current publication policy. The faulting raw stack contains the exact assertion text:

`assertion failed: !dwrite_create_factory_ptr.is_null()`

In that process module list the packaged private `DWrite.dll` is not loaded. The confirmed immediate failure condition is therefore a null DirectWrite factory function pointer in the Rust/dwrote initialization path, followed by its intentional assertion breakpoint. Do not weaken this assertion. The unresolved owner question is why this launch/process path did not load or resolve the packaged private `DWrite.dll!DWriteCreateFactory` even though the separately focused private-DWrite component contract is physically proven on XP.

### Boundary B — later WebRender/Moz2D recording replay assertion

A separate capture from the same build lineage progresses beyond the early DirectWrite condition and faults at `xul.dll + 0x011f8583`. Matching `xul.pdb` from diagnostics artifact `10298342641` resolves the point to `mozilla::wr::Moz2DRenderCallback` in `gfx/webrender_bindings/Moz2DImageRenderer.cpp`, at the release assertion reached after:

`translator.TranslateRecording(...) == false`

The exact source path logs `Replay failure: <translator.GetError()>` and then executes `MOZ_RELEASE_ASSERT(false)`. Nearby raw-stack strings include `FillGlyphs PLAY`, which makes glyph/font replay a plausible investigation area, but that string alone is not sufficient to assign ownership. The next diagnostic must capture the actual `translator.GetError()` text or inspect the failing replay event in WinDbg. Do not weaken the release assertion merely to continue execution.

Conclusion: the all-GREEN static build is physically executable far enough to reach browser runtime code, and the current exact artifact exposes at least two distinct runtime failure paths. Neither is a recurrence of the removed `combase.dll` dependency. The early `dwrote` null-factory assertion and the later Moz2D/WebRender replay assertion must remain separate blockers until debugger evidence identifies their concrete owners.

Status: **current physical-XP runtime blockers for source `5845ff2d...`; debugger follow-up pending.**

---

## 2026-09-12 — additional XP symbolization localizes a font-path GFX_CRASH to NativeFontResourceNotFound

Track: Windows XP SP3 x86 physical browser runtime diagnosis. Independent of GOST TLS handshake evidence.

Evidence remains bound to the same accepted all-GREEN browser lineage: branch/source `agent/winrt-source-poc` / `5845ff2da277f2cc4af40f74a1ef5dd8b8b2da11`, workflow run `34688317433`, job `103539109910`, package artifact `10298184343`, and matching diagnostics/PDB artifact `10298342641`.

An additional user-supplied DrWatson capture reports another `0x80000003` / `int 3` at `xul.dll+0x010e9bf7` (absolute runtime address and load base withheld under the current publication policy). Symbolization with the matching `xul.pdb` resolves the breakpoint to `CrashStatsLogForwarder::CrashAction(LogReason)` in `gfx/thebes/gfxPlatform.cpp:395`, where the non-telemetry path executes `MOZ_CRASH("GFX_CRASH")`.

The symbolized caller chain passes through `mozilla::gfx::CriticalLogger::CrashAction`, the gfx logging destructor path, `mozilla::wr::GetUnscaledFont`, `mozilla::wr::GetScaledFont`, `mozilla::wr::Moz2DRenderCallback`, `wr_moz2d_render_cb`, and WebRender blob rasterization. The captured `CrashAction` reason is `0x22` / decimal `34`, which maps to `LogReason::NativeFontResourceNotFound` in the exact source.

The immediate source condition is therefore more specific than the earlier generic replay assertion: `GetUnscaledFont()` requested `Factory::CreateNativeFontResource(..., FontType::DWRITE, ...)`, and native DWrite resource creation returned `nullptr`, causing `gfxDevCrash(LogReason::NativeFontResourceNotFound)` and the intentional GFX crash. In the exact pre-fix source, `NativeFontResourceDWrite::Create()` only called `Factory::GetDWriteFactory()` and returned `nullptr` if the process-local factory had not already been initialized. The capture's module list does not contain the packaged private `DWrite.dll`.

This does **not** yet prove which internal DWrite creation branch failed. In particular, absence of the private DWrite module plus a null factory makes missing/failed per-process DWrite initialization a strong candidate, but the capture alone does not prove whether `LoadLibraryXPPrivateDWrite()` was never reached, its `LoadLibraryExW` failed, `DWriteCreateFactory` resolution failed, or a later native-font operation failed.

A narrow source remediation has been committed on `agent/winrt-source-poc`: functional commit `5ed150c81c0ba10eff2f1b3eed614371898dfcd4`, followed by cleanup-only commit `55a5415bc34a1e6db89f3643f9be881185127896` restoring an accidentally touched pre-existing comment. Effective product change relative to `5845ff2d...`: under `MOZ_XP_COMPAT`, `NativeFontResourceDWrite::Create()` now obtains the required factory via `Factory::EnsureDWriteFactory()`; non-XP Windows keeps `Factory::GetDWriteFactory()`. This patch is **UNBUILT / UNTESTED** at the time of this log entry and is not runtime evidence.

Working hypothesis only: the user's historical observation that short-lived successful browser sessions often emitted font-search activity shortly before the browser disappeared may belong to this same DirectWrite/font/WebRender family. That correlation is not yet tied to a captured termination owner or exit code and must not be recorded as the proven cause of the sustained-runtime shutdown. The next decisive experiment is to build exact source `55a5415b...`, run that artifact on physical XP, and determine whether the `NativeFontResourceNotFound` / late font-path `0x80000003` boundary disappears or advances while independently tracking any clean-looking spontaneous process termination.

Status: **diagnostic attribution proven; remediation and sustained-runtime causal link remain hypotheses pending exact-build physical XP validation.**

---

## 2026-09-13 — factory-ensure successor passes canonical XP x86 full build/static gates

Track: Windows XP SP3 x86 full-browser build/static compatibility. Independent of GOST TLS handshake/runtime proof and not physical-XP execution evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test and Actions head SHA `55a5415bc34a1e6db89f3643f9be881185127896`;
- functional remediation commit `5ed150c81c0ba10eff2f1b3eed614371898dfcd4` (`NativeFontResourceDWrite::Create()` uses `Factory::EnsureDWriteFactory()` under `MOZ_XP_COMPAT`);
- cleanup-only head commit `55a5415bc34a1e6db89f3643f9be881185127896`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34705592283`;
- job `103584935147` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / success / GREEN**.

All decisive full-build/static stages completed successfully, including release compile/link, targeted xul/mozglue XP compatibility gates, private DirectWrite staging and packaging checks, broad XP PE/direct-import audit, YY inventory, all three artifact uploads, and the final summary gate.

Artifacts bound to the exact source-under-test:

- package artifact `10303966628` (`r3dfox-gost-xp-x32-package`), 333,354,441 bytes, digest `sha256:c8e435e1bc93ab7a7ff7f802154ed02d6090f3765acdc03551677b142a7bb4f7`;
- physical-test runtime artifact `10303801915` (`r3dfox-gost-xp-x32-runtime`), 76,174,967 bytes, digest `sha256:dcca9fcb3e1e666c85542bb1b653c73b1fe387d716f1d960805b8f8e49da36a3`;
- diagnostics artifact `10303639849` (`r3dfox-gost-xp-x32-diagnostics`), 420,544,198 bytes, digest `sha256:bb72735d72b7932ac9b7f9cc2b57f3b180df97d7e875768abf42124c2a1025c9`.

Conclusion: **FULL XP x86 BUILD / PACKAGE / STATIC PE-IMPORT BASELINE GREEN** for the exact factory-ensure successor. This supersedes `5845ff2d...` / run `34688317433` as the latest integrated build/static baseline only.

The result does **not** prove that the `NativeFontResourceNotFound` runtime boundary is fixed, does not prove that private `xpcompat\dwrite\DWrite.dll` is loaded in the relevant browser/WebRender process on XP, does not prove sustained browser lifetime, and does not prove any GOST TLS behavior. The predecessor `5845ff2d...` remains the latest physical-XP evidence lineage until this exact successor artifact is exercised on Windows XP with matching binary/PDB identity.

Next evidence boundary: physically run exact source `55a5415b...`, verify whether `NativeFontResourceNotFound -> GFX_CRASH -> 0x80000003` disappears or advances, and if the browser terminates without an exception capture the actual termination owner, target PID and exit code.

Status: **current authoritative all-GREEN XP full-build/static baseline; physical XP validation pending.**

---

## 2026-09-14 — private `pwrp_k32.dll` preload successor passes canonical XP x86 full build/static gates

Track: Windows XP SP3 x86 full-browser build/static compatibility. Independent of GOST TLS handshake/runtime proof and not physical-XP execution evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test and Actions head SHA `630804c5d2b244777e559ec16402fd71bf2607bf`;
- head commit `630804c5d2b244777e559ec16402fd71bf2607bf` (`xp: preload private pwrp_k32 before xul bootstrap`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34824217341`;
- job `103912791195` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / success / GREEN**.

The canonical job completed every decisive build/static stage successfully: release compile/link, targeted XP compatibility gates, private DirectWrite closure staging, package creation and survival gates, runtime-test archive generation, broad XP PE/direct-import audit, YY-Thunks inventory, all artifact uploads, and the final summary gate.

Artifacts bound to the exact source-under-test:

- package artifact `10344063698` (`r3dfox-gost-xp-x32-package`), 333,354,429 bytes, digest `sha256:8dd89efca38b26a312581b0cf5fe615f089f0938a77550be9b51c5a1f3bf3c64`;
- physical-test runtime artifact `10344972309` (`r3dfox-gost-xp-x32-runtime`), 76,173,645 bytes, digest `sha256:2f73ae5b18770fb3b00cb7c8dd73ebe1ba20bd9ed735561bd540eff7d0f910d2`;
- diagnostics artifact `10344674484` (`r3dfox-gost-xp-x32-diagnostics`), 420,566,084 bytes, digest `sha256:2cb6dac77f8c6486e87a1252a6a79eb5e233f01b68edadd3e863811ad2cff6cb`.

Conclusion: **FULL XP x86 BUILD / PACKAGE / STATIC PE-IMPORT PASS** for the preload experiment. The source change that preloads the private `pwrp_k32.dll` before xul bootstrap is accepted by the canonical full Firefox/r3dfox 153 XP x86 build and its static/package gates. This supersedes `55a5415b...` / run `34705592283` as the latest integrated full-build/static baseline only.

This result does **not** prove that the access violation motivating the preload experiment is fixed on physical Windows XP, does not prove successful runtime loading/initialization order in the crashing process, and does not prove GOST TLS behavior. Physical runtime acceptance remains open until the exact `630804c5...` artifacts are exercised on XP with matching binary/PDB identity.

Next evidence boundary: run the exact package/runtime from source `630804c5d2b244777e559ec16402fd71bf2607bf` on physical XP, verify the private preload/load order in the relevant PID, and record whether the prior AV boundary advances or reproduces.

Status: **current authoritative all-GREEN XP full-build/static baseline for the preload experiment; physical XP validation pending.**

---

## 2026-09-16 — post-COMBASE timezone exclusion passes canonical XP x86 full build/static gates

Track: Windows XP SP3 x86 full-browser build/static compatibility. Independent of GOST TLS handshake/runtime proof and not physical-XP execution evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test and Actions head SHA `52e05a161da601e656e6ba3031084bcc60fdb098`;
- functional remediation commit `9d96597b74d726f3a51229937d48e1d0128c6ae1` (`fix(xp): omit WinRT timezone combase probe`);
- cleanup-only head commit `52e05a161da601e656e6ba3031084bcc60fdb098` (`chore(xp): preserve abseil file newline`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `35059756036`;
- job `104677385743` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / success / GREEN**.

The functional source correction is narrow and source-owned. In `third_party/abseil-cpp/absl/time/internal/cctz/src/time_zone_lookup.cc`, definition of `USE_WIN32_LOCAL_TIME_ZONE` now additionally requires `!defined(MOZ_XP_COMPAT)`. Therefore the WinRT timezone helper and its `LoadLibraryEx(_T("combase.dll"), ..., LOAD_LIBRARY_SEARCH_SYSTEM32)` probe are excluded from the XP C/C++ build path rather than being reached dynamically on XP. The head commit changes only the final newline and does not alter that functional behavior.

The canonical job completed every decisive build/static stage successfully: release compile/link, targeted XP compatibility gates, staging of the pinned XP runtime closures, package creation and package-survival checks, runtime-test archive generation, the broad XP PE/direct-import audit, YY-Thunks inventory, all three artifact uploads, and the final summary gate.

Artifacts bound to the exact source-under-test:

- package artifact `10436053344` (`r3dfox-gost-xp-x32-package`), 333,355,578 bytes, digest `sha256:aed5c8ee68f7eadb703136f9974b6b40d81e50de90f45dd6ae5d9a7cc3950e7e`;
- physical-test runtime artifact `10436611625` (`r3dfox-gost-xp-x32-runtime`), 76,173,243 bytes, digest `sha256:0aca22830230068ab475fa986ca6b5d618a22b005b4c4c491a784054e435ba15`;
- diagnostics artifact `10436392402` (`r3dfox-gost-xp-x32-diagnostics`), 420,566,978 bytes, digest `sha256:b6d9c7fab1fe28c21e7906da42f6fc9aee8c49d16b41d2f2de4d307cb9024f0e`.

Conclusion: **FULL XP x86 BUILD / PACKAGE / STATIC COMPATIBILITY PASS AFTER THE COMBASE SOURCE REMEDIATION.** Exact source `52e05a...`, which contains the `9d96597b...` XP-only exclusion of the Abseil WinRT/COMBASE timezone path, builds and packages successfully through the canonical Firefox/r3dfox 153 XP x86 workflow. This supersedes `630804c5...` / run `34824217341` as the latest integrated full-build/static baseline.

This evidence proves successful build integration of the source-level COMBASE exclusion. It does **not** by itself prove that the exact produced browser starts or remains stable on physical Windows XP, and because the removed dependency was a dynamic `LoadLibraryEx` path rather than an ordinary PE import, the broad PE-import PASS alone must not be reinterpreted as physical proof that `combase.dll` is never loaded. Physical runtime acceptance requires execution of the exact `52e05a...` artifacts with matching binary/PDB identity. It also does not prove GOST TLS behavior.

Next evidence boundary: physically run the exact package/runtime from source `52e05a161da601e656e6ba3031084bcc60fdb098` on Windows XP SP3 x86, bind the run to the matching binaries/PDBs, confirm the process/module behavior after the COMBASE source exclusion, and record the next actual runtime boundary.

Status: **current authoritative all-GREEN XP full-build/static baseline after the COMBASE source remediation; physical XP validation pending.**

---

## 2026-09-18 — exact XP target reaches a private-loader AV; targeted capture establishes failed LdrLoadDll return

Track: physical Windows XP SP3 x86 browser startup, independent of GOST TLS.

- Source under test: `agent/winrt-source-poc` / `52e05a161da601e656e6ba3031084bcc60fdb098`.
- Build: `.github/workflows/gost-poc-build-xp-x32.yml`, run `35059756036`, job `104677385743`.
- Test input: complete `r3dfox-v153.0.3.win32.portable.7z` from package `10436053344`; diagnostics `10436392402`. This is the selected portable payload, not an assumed-equivalent separate runtime bundle.
- Identity: independently downloaded package/diagnostics ZIP digests matched GitHub metadata; all four reported runtime file SHA-1 values and the `xul.pdb` SHA-1 matched the selected artifact files. Offline `xul.dll` RSDS and PDB GUID+Age matched: `8515B3C7-4F66-F5DE-4C4C-44205044422E`, Age `1`. Live PDB loading is not established and is not required for these checked instruction offsets.
- Configuration: user-reported unchanged portable extraction and empty profile at each launch; WinDbg x86 `6.12.0002.633`. Checked `MOZ_FORCE_DISABLE_E10S`, `MOZ_GFX_CRASH_MOZ_CRASH`, `MOZ_DISABLE_CONTENT_SANDBOX`, `MOZ_LOG`: `UNSET`; GOST-specific overrides: `CLEARED`; other external overrides: `UNKNOWN`.
- Private capture aliases: `E001`, `E002`, `E003`, distinct launched process captures. In each relevant supplied capture, `P1` is the initial debuggee and event thread `T1` differs from the initial main thread. These aliases are capture-scoped; no forced single-process mode is inferred.

**PROVEN — observed AV and mechanism.** `E001` and `E002` reach first-chance `0xc0000005`, read access, at `pwrp_k32+0x2c50d`. Local analysis of the `E002` dump confirms the DWrite request `api-ms-win-core-fibers-l1-1-1`, the import/call route through private and system `LoadLibraryExW`, and a `NONNULL` value inside `ntdll.dll` being treated as an image base. The private wrapper's saved loader-result slot contains that value. Its helper reads a presumed PE header offset and faults while locating the PE32 TLS directory. Mapping private DWrite and its closure does not prove successful DLL initialization.

**PROVEN — targeted return boundary.** The `E003` user-supplied WinDbg transcript stops at `mozglue+0x70806`, immediately after the original `LdrLoadDll` call returns for that exact API-set request. The actual returned NTSTATUS is `STATUS_DLL_NOT_FOUND` (`0xc0000135`). At this stop, the hook-local handle is `NONNULL` and equals the invalid pointer value seen in `E002`; the caller's output handle remains `NULL`. The supplied instructions next copy the local handle to that output at `mozglue+0x70810`, without testing the failure status. The transcript stops before this store executes.

**PROVEN — exact-source defect site and code correspondence.** In [`toolkit/xre/dllservices/mozglue/WindowsDllBlocklist.cpp`](https://github.com/syncguy/r3dfox-gost/blob/52e05a161da601e656e6ba3031084bcc60fdb098/toolkit/xre/dllservices/mozglue/WindowsDllBlocklist.cpp#L557-L570), `patched_LdrLoadDll` declares `HANDLE myHandle;` without initialization, passes its address to the original loader, and copies it to the caller and `SetLoadStatus` without a success-status guard. The inspected `E002` hook and private wrapper/helper instruction ranges match the public portable artifact after relocation adjustment. The captured XP `kernel32!LoadLibraryExW` initializes its output local to null but returns that local even through its loader-failure branch.

**WORKING HYPOTHESIS — complete AV causality.** The browser hook propagates an invalid output from a failed DLL load into XP's initially null handle slot; the private wrapper then treats it as a successful module handle and reaches the observed PE/TLS read AV. The upstream source owner is now narrowed to the hook's failed-load output handling. Still required: observe the output store and the immediate system `LoadLibraryExW` return in the same `E003` call. The current stop does not prove whether the original loader left the local untouched or wrote it on failure; either way, its failed-call output is not a proven valid module handle.

**NOT ESTABLISHED:** post-store output, immediate Win32 return/error in `E003`, exception fatality, browser startup/stability PASS, or any GOST TLS result. Earlier stored thread error fields in `E002` are not a substitute for the new directly observed NTSTATUS.

Next step: continue the existing `E003` stop through the five displayed instructions, verify the caller output, then capture the same thread's return at `pwrp_k32+0x298fd`. Prefer a narrow source correction to failed-load output handling after this chain is established. No source change, replacement DLL, full build or runtime patch was performed.

Historical evidence qualification: the earlier dwrote assertion text and module list do not alone prove that the exact second Rust assertion executed, nor whether loading or export resolution failed. Do not infer either outcome or reopen a closed component boundary from that text.

Publication correction in this update: absolute runtime addresses/load base were removed from two older entries in this active log; their retained module/RVA and diagnostic conclusions are unchanged. This does not remove earlier Git history. Original captures, paths, OS identifiers, register/memory output and private capture hashes are withheld.

Publication check: xp-bridge-allowlist-v1 checked

Status: **exact-target physical exception and failed-loader-return evidence established; complete AV propagation and physical runtime acceptance remain open.**

### E003 continuation — invalid output store and Win32 return proven

The next user-supplied WinDbg transcript continues the same stopped `E003` call in `P1/T1`; source/build/package identity above is unchanged.

- **PROVEN:** stepping executes the store at `mozglue+0x70810`. The caller's output changes from `NULL` to the same invalid `NONNULL` value held in the hook-local handle. The preceding original-loader return was `STATUS_DLL_NOT_FOUND`.
- **PROVEN:** a breakpoint restricted to this thread then stops at `pwrp_k32+0x298fd`, immediately after the system `LoadLibraryExW` call. The Win32 return is that same invalid `NONNULL` value; the request is still `api-ms-win-core-fibers-l1-1-1`.
- **Conclusion:** propagation from the browser hook's failed-load output through the XP Win32 loader return into the private wrapper is directly observed in one call. This supersedes the previous entry's pending post-store and Win32-return observations. The responsible source path is `patched_LdrLoadDll` in `toolkit/xre/dllservices/mozglue/WindowsDllBlocklist.cpp`; this attribution does not rest solely on the faulting DLL name.
- **NOT ESTABLISHED:** immediate Win32 last-error/last-status fields in this continuation. `!gle` reported missing `ntdll!_TEB` type information, so its displayed zeros are not accepted as successful-load evidence. This does not invalidate the already captured actual NTSTATUS or return value.
- Symbol-independent reads were checked against the captured XP `ntdll` implementations of `RtlGetLastWin32Error` and `RtlGetLastNtStatus`. Both read fixed fields from the current TEB. The locally supplied offsets are verified for this XP x86 target; no claim is made for other platforms.
- Next: read those two fields at the current stop, then continue the unmodified call to its next exception/breakpoint. If it reaches the previous private-helper AV, preserve the exception and helper-input evidence in this same capture. Final `E003` AV recurrence and exception disposition are not yet observed.
- Narrow remediation direction: define the local handle's initial state and normalize failed-call output before forwarding it to the caller and `ModuleLoadFrame::SetLoadStatus`, while preserving the returned NTSTATUS and successful-load behavior. This is a proposed source correction, not an implemented or tested fix. No extra API-set provider, target-memory correction, source edit or build has been performed.

Raw registers, memory, paths, identities and transcript remain private.

Publication check: xp-bridge-allowlist-v1 checked

---

## 2026-09-18 — failed-`LdrLoadDll` output remediation passes canonical XP x86 full build/static gates

Track: Windows XP SP3 x86 full-browser build/static compatibility. Independent of GOST TLS handshake/runtime proof and not physical-XP execution evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test and Actions head SHA `6a3ffb8295bfdde77df3ed34dfca911beae9941a`;
- functional commit `6a3ffb8295bfdde77df3ed34dfca911beae9941a` (`fix(xp): sanitize failed LdrLoadDll output`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `35346927393`;
- job `105605594476` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / success / GREEN**.

The source correction is narrow and owner-local in `toolkit/xre/dllservices/mozglue/WindowsDllBlocklist.cpp`. `patched_LdrLoadDll` now initializes its local handle to null, forwards the handle to the caller only for successful NTSTATUS values, and passes null to `ModuleLoadFrame::SetLoadStatus` on failure. The original NTSTATUS return and successful-load handle path are preserved.

This correction directly targets the physical `E003` evidence from predecessor source `52e05a161da601e656e6ba3031084bcc60fdb098`: the original loader returned `STATUS_DLL_NOT_FOUND` for the fibers API-set request, while the hook propagated an invalid `NONNULL` local handle through the caller output and system `LoadLibraryExW` return. The new source prevents that failed-load output from being treated as a valid module handle. The build result itself does not establish the physical runtime effect.

The canonical job completed all decisive build/static stages successfully: release compile/link, XP compatibility gates, private DirectWrite closure preparation/staging, package creation and survival gates, runtime-test archive generation, broad XP PE/direct-import audit, YY-Thunks inventory, all three artifact uploads, and final summary.

Artifacts bound to exact source-under-test `6a3ffb8...`:

- package artifact `10555076979` (`r3dfox-gost-xp-x32-package`), 333,353,834 bytes, digest `sha256:5621adb535c7493f9c38390c9935b8cd2096cef1d4ae38450256fd15814b2b58`;
- physical-test runtime artifact `10554622022` (`r3dfox-gost-xp-x32-runtime`), 76,174,201 bytes, digest `sha256:1fef7a5316c3a102978bcfc7fb996ad06a3be7fe3514d4f3fa3883d5986e3126`;
- diagnostics artifact `10555616046` (`r3dfox-gost-xp-x32-diagnostics`), 420,580,984 bytes, digest `sha256:b0c8d736edc22a1efdd41b775ea1721981abbd7e0929b7f82529f69f303c9838`.

Conclusion: **FULL XP x86 BUILD / PACKAGE / STATIC COMPATIBILITY PASS for the failed-`LdrLoadDll` output remediation.** This supersedes source `52e05a...`, run `35059756036`, job `104677385743` as the latest integrated build/static baseline only.

Physical XP runtime acceptance remains **OPEN**. Next evidence boundary: use the complete portable archive from package `10555076979` with matching diagnostics `10555616046`, establish exact local binary/PDB identity, and verify whether the prior private-loader AV disappears and startup advances. A successful build is not a physical runtime PASS. If the loader remediation is physically accepted, the planned follow-up is to remove the temporary early `PreloadXPPrivatePwrp()` path and rebuild/retest without that ordering workaround.

Status: **current authoritative all-GREEN XP full-build/static baseline; physical XP validation pending.**



---

## 2026-09-19 — exact loader-fix successor advances through private DWrite and exits with parent-process AV

Track: Windows XP SP3 x86 physical browser runtime. Independent of GOST TLS handshake evidence.

Exact experiment identity:

- branch/source-under-test `agent/winrt-source-poc` / `6a3ffb8295bfdde77df3ed34dfca911beae9941a`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `35346927393`;
- job `105605594476`;
- package artifact `10555076979` (`r3dfox-gost-xp-x32-package`);
- diagnostics artifact `10555616046` (`r3dfox-gost-xp-x32-diagnostics`);
- physical OS: Windows XP SP3 x86;
- runtime observation source: user-supplied Procmon CSV capture; raw local paths and unrelated machine inventory remain private.

Runtime-file identity is now bound directly to the packaged artifact. The user supplied SHA-1 values for the physically launched files, and independent extraction of `r3dfox-v153.0.3.win32.zip` from package artifact `10555076979` produced exact matches:

- `r3dfox.exe`: `b8d433694f2e913d1d9e749a4a41a199d2b72a5b`;
- `xul.dll`: `4cc50f561dc273673b44e6ff02b2f74079d36b23`;
- `xpcompat/dwrite/DWrite.dll`: `a72f49accb58a5dc894a9735ccd470fd7f89845d`;
- `xpcompat/dwrite/pwrp_k32.dll`: `22406c8122a25a61fb3fe4ff9e20b0a72472328a`.

The matching diagnostics artifact contains `xul.pdb`; its artifact-side SHA-1 is `5adb2a93d6640d1cfd0964fdf45e5b535f95ac7c`. Local PDB identity must still be checked before symbolizing a future dump.

**PROVEN — startup advances beyond the predecessor private-loader failure boundary.** In the parent browser process, private `pwrp_k32.dll` loads successfully, followed by private `DWrite.dll` and the rest of the private DirectWrite closure. The same parent later opens and successfully reads the existing `DWriteCore/FontSet-v3.dat` cache (267,292 bytes). Before termination it successfully creates GPU, socket, tab/content, RDD, additional tab/content, and utility child processes. This is materially later than predecessor source `52e05a...`, whose physical captures faulted inside the private loader while handling the missing fibers API-set. The successor therefore physically advances beyond that startup boundary. Procmon does not provide the new faulting EIP, so this entry does not claim a debugger-confirmed non-recurrence of the exact predecessor instruction.

**PROVEN — current termination is an access violation in the parent process, not a clean shutdown.** The parent starts at 15:31:30.672 and exits at 15:31:36.223 with signed exit status `-1073741819`, i.e. `0xC0000005`. It survives roughly 5.55 seconds and continues for several seconds after private DWrite loads and the font cache is read. The observed child processes predominantly exit with status 0 after the parent begins teardown. DrWatson did not capture this failure, but Procmon records the parent process exit code.

**COMBASE qualification.** The capture contains failed filesystem searches for `combase.dll`, but no successful `Load Image` of `combase.dll`. The parent continues through private DWrite initialization, font-cache access and child-process startup after those probes. Therefore the presence of a dynamic COMBASE lookup is not evidence that COMBASE owns the current AV. The previously implemented Abseil WinRT timezone COMBASE exclusion remains a separate source-level fact; ownership of the remaining probe is unresolved.

**NOT ESTABLISHED:** the new AV's faulting module, EIP, thread, stack, first-chance/second-chance disposition, or source owner. The last visible Procmon I/O is not sufficient to assign crash ownership.

Next diagnostic: run this exact binary set under matching WinDbg/PDB without changing e10s, sandbox or graphics behavior; break on access violations, capture `.exr -1`, registers, stack, faulting module/symbol and a full dump. Keep the temporary early private-`pwrp_k32.dll` preload in place during this diagnostic so cleanup does not change the boundary under investigation.

Conclusion: **PHYSICAL XP ADVANCEMENT PAST THE PREDECESSOR PRIVATE-DWRITE LOADER BOUNDARY; SUSTAINED RUNTIME STILL FAILS WITH A NEW PARENT-PROCESS `0xC0000005`.**

Publication check: xp-bridge-allowlist-v1 checked

Status: **current exact physical-XP runtime boundary for source `6a3ffb8...`; debugger localization pending.**


---

## 2026-09-19 — exact XP GPU-child AV is fatal with a missing xul TLS block on the detaching thread

Track: Windows XP SP3 x86 physical browser runtime diagnosis. Independent of GOST TLS handshake evidence and separate from the still-unlocalized parent-process AV seen in Procmon.

Exact browser/build identity remains:

- source-under-test `agent/winrt-source-poc` / `6a3ffb8295bfdde77df3ed34dfca911beae9941a` (`fix(xp): sanitize failed LdrLoadDll output`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml`, run `35346927393`, job `105605594476`, completed / success / GREEN;
- package artifact `10555076979`, diagnostics artifact `10555616046`;
- matching `xul.pdb` SHA-1 `5adb2a93d6640d1cfd0964fdf45e5b535f95ac7c`;
- current user-supplied dump `r3dfox-next-av.dmp`: SHA-256 `27a0af551d3f9d856f9b9086a364ca122c49eb264fc341b5dd2f704124ec2a8c` (SHA-1 `b5a36e10600dc7d6ae0e5620660fd172529ff741`). The containing uploaded ZIP hashes to SHA-256 `6c70f113b7f0c0593e4629c2919a4bcbe3f34d38d17f3940684df0e29893a9ca`.

The dump is from the current 2026-09-18 portable payload and carries BuildID `20260918132121`. WinDbg process index 0 is parent PID `0x950` / 2384; the fault occurs in child PID `0xAAC` / 2732. The child command line identifies it as the GPU process (`-parentPid 2384 ... - 1 gpu`). Therefore this capture must not be substituted for the separate parent-process `0xC0000005` previously observed by Procmon.

WinDbg catches first-chance `0xC0000005` on thread `0x11C0` / 4544 at `xul.dll + 0x0090DED4`. After changing AV handling to second-chance-only and continuing, the same thread stops again at the same RVA as `0xC0000005 (second chance)`. The exception is therefore unhandled/fatal for this GPU child, not benign first-chance noise. The instruction is `cmp eax,dword ptr [ecx+14B4h]`; `ecx == 0`, and the exception record reports a read from `0x000014B4`.

Matching-PDB symbolization resolves the xul path to `nsThreadManager::get()` (`xpcom/threads/nsThreadManager.cpp:285`), inlined through `nsThread::MaybeRemoveFromThreadList()` and `nsThread::~nsThread()`, with the registered NSPR TPD release callback `nsThreadManager::ReleaseThread(void*)` in the ownership chain.

The fault is specifically a missing static-TLS block for xul on this thread, not a null `nsThreadManager*`. The exact machine sequence reads xul's PE TLS index, reads the current TEB TLS vector through `fs:[0x2C]`, loads the xul slot, and then accesses the compiler thread-safe-static epoch. Live values are:

- xul `_tls_index = 5`;
- current `fs:[0x2C] = 0x0C1E98F8`;
- slot `[fs:[0x2C] + 5*4] = 0`.

A whole-process thread check found the xul TLS slot non-null on 24 other threads and null only on the faulting thread. The condition is therefore not process-wide loss of xul TLS.

The correct dump also shows that the faulting thread starts in xul's Rust `std::thread` Windows entry path. This rules out the simple provisional explanation that the thread merely existed before xul was loaded.

The raw stack reaches the exact packaged `nss3.dll` entry-point path with DllMain reason `3` / `DLL_THREAD_DETACH`, and the xul callback path is consistent with NSPR thread-private-data destruction invoking the registered `nsThreadManager::ReleaseThread` destructor while that thread is exiting.

The exact `xul.dll` already contains the committed YY-Thunks DLL/TLS contract: its PE entry point is `DllMainCRTStartupForYY_Thunks`, and the current project uses YY-Thunks v1.2.2 for the XP target. Therefore this is **not** evidence that the YY xul entry-point contract is absent.

What is **not yet proven** is the ordering that produced the null slot. Two materially different mechanisms remain open: the YY XP TLS path may have failed to populate this particular thread's xul slot, or the slot may have been valid earlier and then cleared during thread-detach processing before NSPR re-entered xul. Do not record either mechanism as established until the xul DLL entry-point/TLS slot is observed directly across `DLL_THREAD_DETACH`.

Next diagnostic: on the same exact binaries, keep the large PDB out of the live symbol path, break on xul's known PE entry-point RVA during `DLL_THREAD_DETACH`, record slot 5 immediately before and immediately after `DllMainCRTStartupForYY_Thunks`, then observe the subsequent `nss3.dll` `DLL_THREAD_DETACH` entry on that thread. This distinguishes “never allocated” from “cleared before NSPR callback” without changing source or build configuration.

Conclusion: **FATAL GPU-CHILD XUL STATIC-TLS BLOCKER LOCALIZED TO A NULL PER-THREAD XUL TLS SLOT DURING THREAD DETACH.** The exact teardown ordering/owner inside the existing YY/NSPR lifecycle remains the next evidence boundary. The separate Procmon parent-process AV remains unresolved.

Status: **current exact GPU-child blocker; teardown-order breakpoint experiment pending.**

---

## 2026-09-19 — focused YY static-TLS detach re-entry control passes on hosted Windows

Track: Windows XP SP3 x86 compatibility / focused TLS-lifecycle control. Independent of GOST TLS runtime and not physical-XP browser-runtime evidence.

Exact experiment identity:

- workflow `.github/workflows/xp-yy-tls-detach-reentry-smoke.yml` / `XP YY TLS detach re-entry smoke`;
- source-under-test `14a081882ae657115ae799f7adeca6605677d9d0`;
- run `35448707456`;
- job `105912013098` (`YY DLL static-TLS detach re-entry / XP x86`);
- aggregate result: **completed / success / GREEN**;
- artifact `10586477797` (`xp-yy-tls-detach-reentry-smoke`), 3,458,607 bytes, digest `sha256:83e02cd021e40ab7e5e6e75e3ac5d781ee30f83edacbbf6b0facfa7f41bb2fe3`.

The focused harness builds an x86 / PE 5.01 owner DLL with a real nonzero PE Thread Storage Directory, compiler-generated thread-safe function-local-static state, and the YY-Thunks v1.2.2 DLL entry-point contract. A second DLL invokes the owner's exported local-static consumer from its own `DLL_THREAD_DETACH` callback. The PE/TLS contract gate and hosted control both passed.

Hosted Windows control results:

- `late-first`: worker exit 0, owner detach order 1, late-callback detach order 2, callback count 1, and `reentry_after_owner_detach=YES`; the re-entry completed without a crash.
- `owner-first`: worker exit 0, late-callback detach order 1, owner detach order 2, callback count 1, and `reentry_after_owner_detach=NO`; this is the inverse-order control.

Conclusion: **the focused reproducer is valid and can deterministically exercise callback re-entry after the owner DLL has already received `DLL_THREAD_DETACH`.** Hosted Windows surviving that order is a control only; it does not establish the XP YY-emulated TLS lifetime. The next focused discriminator is to execute artifact `10586477797` unchanged on physical Windows XP SP3 x86 in both modes, with `late-first` as the decisive re-entry case.

This result does not close the separate full-browser GPU-child AV, does not close the separate parent-process AV, and does not change the GOST TLS runtime state.

Publication check: xp-bridge-allowlist-v1 checked
---

## 2026-09-19 — nsThread detach re-entry consumer fix passes canonical XP x86 full build/static gates

Track: Windows XP SP3 x86 full-browser build/static compatibility. Independent of GOST TLS handshake/runtime proof and not physical-XP execution evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test and Actions head SHA `62835966a1c680382b8ab8a7100b810abccbf2c5`;
- functional commit `62835966a1c680382b8ab8a7100b810abccbf2c5` (`fix(xp): avoid thread manager singleton re-entry on detach`);
- changed product files: `xpcom/threads/nsThread.cpp`, `xpcom/threads/nsThread.h`, `xpcom/threads/nsThreadManager.cpp`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `35443499166`;
- job `105898364295` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / success / GREEN**.

The canonical job completed the release Firefox/r3dfox XP x86 compile/link, targeted compatibility gates, staging of the pinned XP CRT / legacy `D3DCompiler_47.dll` / private DirectWrite closure / proven `bcrypt.dll`, PE subsystem retargeting, package creation and survival checks, runtime-test archive generation, broad XP PE/direct-import audit, YY-Thunks inventory, all three artifact uploads, and the final summary gate successfully.

Artifacts bound to exact source-under-test `62835966...`:

- package artifact `10587340718` (`r3dfox-gost-xp-x32-package`), 333,347,227 bytes, digest `sha256:325d908cf19bfa20eba01307d4c4559518cad26d83bb2126e1ed530f5e2178a7`;
- physical-test runtime artifact `10587396294` (`r3dfox-gost-xp-x32-runtime`), 76,173,133 bytes, digest `sha256:d86bc02ee189ac2105ebb8ef9327091b56beaf190fa01cf750aff22c9de56cd3`;
- diagnostics artifact `10586618851` (`r3dfox-gost-xp-x32-diagnostics`), 420,573,279 bytes, digest `sha256:3d80cabc544c333d652e037e3fa88296ab7106b5704fc1752aad00197bf73d04`.

Conclusion: **FULL XP x86 BUILD / PACKAGE / STATIC COMPATIBILITY PASS for the narrow detach re-entry consumer remediation.** This source supersedes `6a3ffb8295bfdde77df3ed34dfca911beae9941a` / run `35346927393` as the latest integrated full-build/static baseline only.

This result does **not** prove that the prior physical GPU-child `0xC0000005` is fixed, does not establish any physical-XP runtime behavior for source `62835966...`, and does not prove GOST TLS behavior. The physically exercised baseline remains `6a3ffb8...` until the exact new package/runtime is run on Windows XP with matching binary/PDB identity. The focused YY detach reproducer remains an independent evidence line.

Next browser evidence boundary: execute the exact `62835966...` package/runtime on physical Windows XP SP3 x86 and determine whether execution advances beyond the prior GPU-child `nsThreadManager::get()` / null-xul-TLS-slot detach boundary while keeping the separate parent-process AV and focused YY lifecycle control distinct.

Status: **current authoritative all-GREEN XP full-build/static baseline; physical XP validation pending.**
