# r3dfox GOST TLS — Project State

Last updated: 2026-09-13

This file is the authoritative current technical synthesis and handoff for new chats. The immediately preceding full synthesis is preserved unchanged in [`PROJECT_STATE_2026-09-12_pre_angle_d3d9_graph_pass.md`](./PROJECT_STATE_2026-09-12_pre_angle_d3d9_graph_pass.md). Detailed experiment evidence belongs in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes; closed milestones are in `DONE.md`; pending work is in `TODO.md`; workflow roles are in `WORKFLOWS.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default branch and canonical documentation source: `agent/gost-tls-poc`.
- Windows XP SP3 x86 implementation branch: `agent/winrt-source-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the active work branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides otherwise.

For Windows XP work, read `XP_BUILD_CONTRACT.md`, `XP_MOZ_XP_COMPAT_CONTRACT.md`, `XP_RUNTIME_COMPATIBILITY_STATUS.md`, and the newest XP entries in `TEST_LOG.md`.

## Evidence separation

Keep these tracks independent unless a deliberately combined experiment tests both:

1. GOST TLS runtime / NSS / NSPR / MSSPI / SSPI / CryptoPro / handshake.
2. Windows Vista/7/XP compatibility / Rust / msvcr14x / YY-Thunks / linker / PE imports / physical runtime.
3. Bundled extensions, localization and packaging.

Build success is not physical runtime success. Focused source-graph success is not full-build or PE/import success. Physical browser runtime success is not GOST TLS success. Documentation commits never replace the exact source-under-test SHA of an earlier artifact.

# GOST TLS runtime

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication. Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

Physical Windows XP GOST TLS server-auth proof exists for source `88453be37a7f39f690c504078f6f9434e2547ab6`, workflow run `34459906476`, job `102815008544`, runtime artifact `10150744314`. Under forced non-e10s and an explicit GOST host allowlist, the exact browser completed TLS 1.2 MSSPI handshakes with successful server verification and HTTP application traffic. This is server-auth evidence only; mTLS/client-certificate positive proof, fail-closed negative verification coverage, persistent certificate semantics and default-e10s acceptance remain separate work.

# Windows XP SP3 x86 compatibility

Active implementation is `agent/winrt-source-poc`; canonical documentation remains on `agent/gost-tls-poc`.

## ANGLE D3D9 graph and focused Gecko target — GREEN

The exact vendored ANGLE graph diagnosis and its transfer into the real focused Gecko `libGLESv2` XP x86 target are now closed at their respective focused scopes. `angle_d3d9_backend` reaches shared `angle_d3d_format_tables`; the narrow graph remediation retains shared D3D format sources for D3D9 while admitting the four D3D11-owned DXGI format/support-table files only when `(is_win && angle_enable_gl) || angle_enable_d3d11`.

Authoritative graph-generation closure:

- workflow `.github/workflows/xp-angle-d3d9-regenerate.yml` / `XP ANGLE D3D9-only regeneration smoke`;
- branch `agent/winrt-source-poc`;
- source-under-test/head `7b214d64fe0110431c73ef9e81f17e37c33b2926`;
- run `34684794502`;
- job `103529796175`;
- aggregate result **completed / success / GREEN**;
- artifact `10295651148` (`xp-angle-d3d9-regeneration-34684794502`), digest `sha256:e680e33dc7a788a6a4b4230c7f12af40e0f0fa97cf837d7bc13e186b09f11c7d`.

Generated-target semantic evidence:

- `d3d11_source_refs=0`, `d3d9_source_refs=20`;
- D3D11 define, `Renderer11`, `CompositorNativeWindow11`, `dxgi_format_map.{h,autogen.cpp}` and `dxgi_support_table.{h,autogen.cpp}` are absent;
- D3D9 define, `Renderer9`, shared `d3d_format.cpp` and `d3d9` OS_LIBS are present;
- `d3d11` OS_LIBS is absent.

`dxgi` remains in generated `OS_LIBS` both before and after this focused change, so that line alone is not evidence that the four unwanted source files remain and is not equivalent to final PE/import evidence. `d3d_format.h` is a GN/header dependency and need not appear as a compile-source line in `moz.build`.

The narrow generated build-path transfer is commit/source `e7424ea9b68eafae79513e5d794b799e0ec454b7` (`build(xp): apply generated ANGLE D3D9 graph fix`). It changes only `gfx/angle/targets/libGLESv2/moz.build`, removing the two D3D11-owned DXGI format/support `.cpp` sources and `dxguid` while retaining D3D9, shared `d3d_format.cpp`, and baseline `dxgi`. Regeneration-only harness changes were deliberately not promoted into the product path.

Authoritative focused Gecko target integration closure:

- trigger `.github/workflows/xp-angle-smoke-trigger.yml` calling `.github/workflows/xp-angle-libglesv2-smoke.yml`;
- branch `agent/winrt-source-poc`;
- source-under-test/head `e7424ea9b68eafae79513e5d794b799e0ec454b7`;
- run `34686743277`;
- job `103534931543` (`ANGLE libGLESv2 / XP x86 focused build`);
- aggregate result **completed / success / GREEN**;
- artifact `10296028734` (`xp-angle-libglesv2-smoke`), 1,573,962 bytes, digest `sha256:6790fa5618456237e5a2290e21dcae88a3805eed1c0ac6c39a8399f9b99dcf61`;
- configure/export, dependency dry-run, real link prerequisites, `Build libGLESv2 only`, focused `mozglue.dll` inspection and `GATE - Inspect focused libGLESv2 binary` all completed successfully.

Earlier hosted-SDK pinning, shallow ANGLE history, PowerShell native stderr and regeneration-harness patch mechanics remain test-infrastructure history and do not reopen either focused closure.

**Boundary:** source-graph generation and focused `libGLESv2` compile/link integration are both closed. Their integration into the canonical full Firefox/r3dfox XP x86 build is also now proven by the all-GREEN full-build baseline below. Physical XP runtime remains a separate acceptance boundary.

## Current integrated full-build/static baseline — GREEN

The current authoritative integrated full-build/static baseline is:

- branch `agent/winrt-source-poc`;
- source-under-test/head `55a5415bc34a1e6db89f3643f9be881185127896`;
- functional DWrite factory-ensure commit `5ed150c81c0ba10eff2f1b3eed614371898dfcd4`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34705592283`;
- job `103584935147` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result **completed / success / GREEN**.

The canonical build completed the Firefox/r3dfox release compile/link, targeted xul/mozglue compatibility gates, staging of the pinned XP CRT / legacy `D3DCompiler_47.dll` / private DirectWrite closure / proven `bcrypt.dll`, PE subsystem retargeting, package creation, package-survival checks, runtime-test archive creation, the broad `GATE - Audit XP x32 PE floor and direct imports`, YY-Thunks inventory, all artifact uploads, and the final summary gate successfully.

Artifacts:

- package `10303966628` (`r3dfox-gost-xp-x32-package`), 333,354,441 bytes, digest `sha256:c8e435e1bc93ab7a7ff7f802154ed02d6090f3765acdc03551677b142a7bb4f7`;
- runtime `10303801915` (`r3dfox-gost-xp-x32-runtime`), 76,174,967 bytes, digest `sha256:dcca9fcb3e1e666c85542bb1b653c73b1fe387d716f1d960805b8f8e49da36a3`;
- diagnostics `10303639849` (`r3dfox-gost-xp-x32-diagnostics`), 420,544,198 bytes, digest `sha256:bb72735d72b7932ac9b7f9cc2b57f3b180df97d7e875768abf42124c2a1025c9`.

This supersedes source `5845ff2da277f2cc4af40f74a1ef5dd8b8b2da11`, run `34688317433`, job `103539109910` as the latest integrated build/static baseline. The predecessor remains the current physical-XP runtime evidence lineage until the new exact artifacts are tested on Windows XP.

This is a full-build/package/static PE-import PASS only. It does **not** by itself prove browser startup or stability on physical Windows XP, does not prove that `NativeFontResourceNotFound` is fixed at runtime, and does not prove GOST TLS behavior.

## Physical XP browser/runtime state

The latest physically exercised all-GREEN build remains source `5845ff2da277f2cc4af40f74a1ef5dd8b8b2da11`, run `34688317433`, job `103539109910`, with package artifact `10298184343`, runtime artifact `10297859657`, and matching diagnostics/PDB artifact `10298342641`. The newer build/static baseline `55a5415b...` / run `34705592283` has not yet been physically validated on XP.

Two distinct intentional-breakpoint failure paths are confirmed on the predecessor physical lineage and must not be conflated:

1. **Early Rust/dwrote DirectWrite factory boundary.** A process faults with `0x80000003` on an `int 3`, and the faulting stack contains `assertion failed: !dwrite_create_factory_ptr.is_null()`. In that process module list the packaged private `DWrite.dll` is not loaded. The immediate failure condition is a null DirectWrite factory function pointer in the dwrote initialization path. The next debugger task is to determine why that launch/process path did not load or resolve the packaged private `DWrite.dll!DWriteCreateFactory`; do not weaken the assertion.
2. **Later WebRender/Moz2D replay boundary.** A separate process from the same artifact lineage progresses further and faults at `xul.dll + 0x011f8583`. Matching `xul.pdb` resolves this to `mozilla::wr::Moz2DRenderCallback` in `gfx/webrender_bindings/Moz2DImageRenderer.cpp`, after `translator.TranslateRecording(...)` returns false and the code executes `MOZ_RELEASE_ASSERT(false)`. Raw-stack text contains `FillGlyphs PLAY`, so glyph/font replay is a plausible investigation area, but ownership remains unproven until `translator.GetError()` or the exact failing replay event is captured. Do not weaken the release assertion.

The loaded-module evidence for these current runs no longer contains `combase.dll`; the previous COMBASE dependency is therefore not the current runtime boundary.

The focused private Supermium DWrite path remains independently physically proven on XP by run `34317489430`, job `102356664699`, artifact `10090864697`: project msvcr14x UCRT loads at process startup with static TLS, private `pwrp_k32.dll` and `DWrite.dll` load, `DWriteCreateFactory()` succeeds and `GetSystemFontCollection()` succeeds. That focused component PASS is a control and does not by itself explain why one current full-browser process leaves the dwrote factory pointer null.

The older source `88453be...` remains historical physical-browser evidence: it started, rendered and performed real remote workloads under forced non-e10s, later reaching `gfxFontGroup::GetDefaultFont()` / `gfxTextRun.cpp:2242`. That older default-font crash is no longer the sole current runtime boundary and must not be projected onto source `5845ff2d...` or `55a5415b...` without matching evidence.

## Closed compatibility boundaries retained

Do not reopen without contradictory evidence on a later exact artifact:

- SharedPrefMap invalid inherited child HANDLE / `0x80000003`, physically advanced beyond on source `897e1cdf98bcc091e13283fa8004177971d30f27`;
- `USER32!RegisterPowerSettingNotification` / `0xC06D007F`, physically advanced beyond on successor `88453be...`;
- `xul.dll` `ntdll!RtlpWaitForCriticalSection` startup failure;
- IP Helper runtime boundary;
- `USER32!SetProcessDPIAware` delay-load boundary;
- `NtCancelIoFileEx`;
- ADVAPI32 ETW family;
- KERNEL32 restart/named-pipe source-remediation quartet;
- PROPSYS ordinary-import dependency;
- observed WS2_32 compatibility family;
- direct ANGLE `CreateDXGIFactory1` edge;
- 13/13 strong-candidate YY DLL entry-point/TLS static coverage;
- focused private DWrite component runtime contract.

Full YY `kernel32.lib` interposition remains prohibited; compatibility ownership stays narrow by source/provider/PE.

## Build-configuration identity

Keep the XP mechanisms distinct:

- C/C++: `CFLAGS/CXXFLAGS += -DMOZ_XP_COMPAT`;
- Rust: `RUSTFLAGS="--cfg moz_xp_compat"`;
- neither implies `CONFIG["MOZ_XP_COMPAT"]` in `moz.build`.

## XP acceptance boundary

The canonical full XP x86 browser build/package/static PE-import boundary is **GREEN** on exact source `55a5415bc34a1e6db89f3643f9be881185127896`, run `34705592283`, job `103584935147`.

Physical XP runtime acceptance remains **OPEN**. The newest exact build has not yet been physically exercised, while the predecessor `5845ff2d...` lineage proved browser execution far enough to expose the early Rust/dwrote null-`DWriteCreateFactory` assertion and the later font/WebRender failure family. The next acceptance experiment is physical XP execution of the exact `55a5415b...` artifacts with matching binary/PDB identity, first checking whether the `NativeFontResourceNotFound` boundary advances and then recording the next actual runtime boundary.

# Bundled government-system extensions / localization

Current proven three-extension packaging checkpoint remains source `b3d097de20b7a5711f161199a727bcfe9468bcc8`, run `32976571122`, job `98202641607`.

Current corrected Russian localization package gate is source `3e2c32386f373d4693db52b32c05aa2000878def`, workflow `CryptoPro Mozilla packaging smoke`, run `33520207057`, job `99897230730`, success.

# Global evidence rules

- Build success != GOST handshake success.
- Focused source/dependency success != full Firefox startup.
- Win7 x86 startup != XP startup.
- Static source/import removal != physical-XP runtime closure until the exact accepted artifact advances past it.
- Documentation HEADs never replace exact source-under-test SHA.
- A PDB may symbolize only the matching binary from the same build.
- Runtime claims stay bound to exact source SHA + Actions run/job + exact artifact/binary identity.

# Current XP runtime refinement — NativeFontResourceNotFound and factory-ensure validation build

Additional symbolization of the predecessor physical-XP lineage (`5845ff2da277f2cc4af40f74a1ef5dd8b8b2da11`, run `34688317433`, job `103539109910`, diagnostics/PDB artifact `10298342641`) localizes another observed `0x80000003` to `CrashStatsLogForwarder::CrashAction(LogReason)` with `LogReason::NativeFontResourceNotFound`. The symbolized caller chain reaches that crash from `GetUnscaledFont()` / `GetScaledFont()` inside `Moz2DRenderCallback`. In the exact pre-fix source, `NativeFontResourceDWrite::Create()` only queried `Factory::GetDWriteFactory()` and returned `nullptr` when the process-local factory was absent; the captured process module list also did not contain the packaged private `DWrite.dll`. This refines the later font/WebRender failure family but does not prove which internal DWrite load/create operation failed.

The narrow XP-only source experiment on `agent/winrt-source-poc` is now built and statically accepted. Functional commit `5ed150c81c0ba10eff2f1b3eed614371898dfcd4`, with cleanup-only successor/head `55a5415bc34a1e6db89f3643f9be881185127896`, changes `NativeFontResourceDWrite::Create()` to call `Factory::EnsureDWriteFactory()` under `MOZ_XP_COMPAT`; non-XP behavior remains the existing `GetDWriteFactory()` path. Exact full build run `34705592283`, job `103584935147`, completed **success / GREEN** with package, runtime and diagnostics artifacts recorded above. This proves build/package/static integration only; it is **not yet physical runtime evidence** that the font boundary is fixed.

Working hypothesis only: the user's observation that otherwise successful XP sessions often showed font-search activity shortly before the browser disappeared may indicate that the short-lived sustained-runtime problem shares this DirectWrite/font/WebRender owner family. There is not yet a captured termination owner or exit code linking the clean-looking browser shutdown to this failure, so the correlation remains a diagnostic lead rather than a conclusion. Next acceptance experiment: physically exercise exact source `55a5415b...`, check whether `NativeFontResourceNotFound` / the late font-path `0x80000003` disappears or advances, verify private `xpcompat\dwrite\DWrite.dll` loading in the relevant PID, and independently capture any clean-looking process termination owner and exit code.