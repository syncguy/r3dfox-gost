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

One capture faults in `xul.dll` at `0x08460c61` on an `int 3`. The faulting raw stack contains the exact assertion text:

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

An additional user-supplied DrWatson capture reports another `0x80000003` / `int 3` in `xul.dll` at runtime address `0x02c99bf7` with `xul.dll` base `0x01bb0000`, giving RVA `0x010e9bf7`. Symbolization with the matching `xul.pdb` resolves the breakpoint to `CrashStatsLogForwarder::CrashAction(LogReason)` in `gfx/thebes/gfxPlatform.cpp:395`, where the non-telemetry path executes `MOZ_CRASH("GFX_CRASH")`.

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