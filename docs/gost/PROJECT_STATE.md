# r3dfox GOST TLS — Project State

Last updated: 2026-09-19

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
- source-under-test/head `62835966a1c680382b8ab8a7100b810abccbf2c5`;
- functional source fix `62835966a1c680382b8ab8a7100b810abccbf2c5` (`fix(xp): avoid thread manager singleton re-entry on detach`);
- changed product files: `xpcom/threads/nsThread.cpp`, `xpcom/threads/nsThread.h`, `xpcom/threads/nsThreadManager.cpp`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `35443499166`;
- job `105898364295` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result **completed / success / GREEN**.

The source change is the narrow browser consumer remediation for the already-localized GPU-child detach failure. The canonical build/static result establishes that the change integrates cleanly into Firefox/r3dfox 153 and preserves the existing XP build/package/static compatibility gates. It does not establish the physical runtime effect.

The canonical build completed the Firefox/r3dfox release compile/link, targeted XP compatibility gates, staging of the pinned XP CRT / legacy `D3DCompiler_47.dll` / private DirectWrite closure / proven `bcrypt.dll`, PE subsystem retargeting, package creation, package-survival checks, runtime-test archive creation, broad XP PE/direct-import audit, YY-Thunks inventory, all artifact uploads, and the final summary gate successfully.

Artifacts:

- package `10587340718` (`r3dfox-gost-xp-x32-package`), 333,347,227 bytes, digest `sha256:325d908cf19bfa20eba01307d4c4559518cad26d83bb2126e1ed530f5e2178a7`;
- runtime `10587396294` (`r3dfox-gost-xp-x32-runtime`), 76,173,133 bytes, digest `sha256:d86bc02ee189ac2105ebb8ef9327091b56beaf190fa01cf750aff22c9de56cd3`;
- diagnostics `10586618851` (`r3dfox-gost-xp-x32-diagnostics`), 420,573,279 bytes, digest `sha256:3d80cabc544c333d652e037e3fa88296ab7106b5704fc1752aad00197bf73d04`.

This supersedes source `6a3ffb8295bfdde77df3ed34dfca911beae9941a`, run `35346927393`, job `105605594476` as the latest integrated build/static baseline. Source `6a3ffb8...` remains the latest physically exercised exact browser target until the new package is run on XP.

This is a full-build/package/static compatibility PASS only. It does not by itself prove browser startup or stability on physical Windows XP and does not prove GOST TLS behavior.

## Physical XP browser/runtime state

The latest integrated full-build/static candidate, source `6a3ffb8295bfdde77df3ed34dfca911beae9941a`, run `35346927393`, job `105605594476`, is now also the latest physically exercised exact browser target. The user-supplied runtime hashes for `r3dfox.exe`, `xul.dll`, private `DWrite.dll` and private `pwrp_k32.dll` were independently matched against package artifact `10555076979`; matching diagnostics/PDB artifact is `10555616046`. See the 2026-09-19 entry in `TEST_LOG.md` for the exact hashes and sanitized Procmon evidence.

Current observed boundaries: the exact successor physically advances beyond the predecessor private-loader failure. In the parent browser process, private `pwrp_k32.dll`, private `DWrite.dll` and the remaining private DirectWrite closure load successfully; the parent then opens and reads the existing `DWriteCore/FontSet-v3.dat` cache and creates GPU, socket, tab/content, RDD, additional tab/content and utility child processes. Procmon still records the parent terminating roughly 5.55 seconds after start with signed exit status `-1073741819` / `0xC0000005`; that parent faulting EIP/stack remains unresolved.

A separate WinDbg capture on the same exact package has now localized a fatal `0xC0000005` in the GPU child (PID `0xAAC` / 2732, parent PID 2384) at `xul.dll+0x0090DED4`. The same exception repeats at second chance, so it is unhandled. Matching `xul.pdb` resolves the xul path through `nsThreadManager::get()` -> `nsThread::MaybeRemoveFromThreadList()` -> `nsThread::~nsThread()`, with `nsThreadManager::ReleaseThread` in the NSPR TPD ownership chain. The faulting thread has xul `_tls_index=5` but its TEB TLS slot 5 is null, while the same slot is non-null on 24 other threads. The correct dump shows the thread started inside xul's Rust `std::thread` entry path, so this is not explained merely by the thread predating xul loading.

The raw stack reaches the exact packaged `nss3.dll` entry-point path with DllMain reason `3` / `DLL_THREAD_DETACH`. The exact xul PE already contains the intended YY-Thunks `DllMainCRTStartupForYY_Thunks` entry/TLS contract, so a missing xul YY entry-point contract is not the issue. The remaining owner question is narrower: determine whether the YY XP TLS path failed to populate this particular thread's xul slot, or whether a previously valid slot was cleared during detach before NSPR re-entered xul. The current dump proves the null slot and fatal re-entry, but not yet which of those two lifecycle orderings produced it. This GPU-child blocker remains separate from the still-unlocalized parent-process AV and does not reopen the predecessor DWrite-loader blocker.

A focused lifecycle control validates the intended detach/re-entry topology independently of Firefox, but its first two physical-XP bundles were loader-invalid before the intended discriminator executed. Hosted source `14a081882ae657115ae799f7adeca6605677d9d0`, run `35448707456`, job `105912013098`, artifact `10586477797` remains valid hosted-control evidence for deterministic `late-first` versus `owner-first` ordering, but physical XP stopped before `main()` on missing `KERNEL32!FlsGetValue` from the staged CRT closure. Follow-up source `a98d08f3096f06bbc8d823584d3752465898f5d7`, run `35456649606`, job `105933017753`, artifact `10587894239` fixed the CRT path and passed CI, but physical XP again stopped before the test on missing `KERNEL32!AcquireSRWLockExclusive`. Artifact diagnostics localize that second defect to `tls-owner.dll`, which retained direct `AcquireSRWLockExclusive`, `ReleaseSRWLockExclusive`, `SleepConditionVariableSRW`, and `WakeAllConditionVariable` imports generated by the compiler thread-safe local-static guard.

Workflow-only corrective commit `5c323d003ca1c7f3fd7b740aa16a450e5bdcfe7a` now adds the exact YY weak-alias pairs for that quartet, requires the owner map to select the corresponding `YY_Thunks_*` symbols, and expands the final target-PE audit to the canonical curated post-XP import set. This commit is a remediation candidate, not yet a GREEN run by itself. The next focused discriminator is a new artifact built from this exact source (or a narrowly corrected successor) after CI passes, followed by physical XP execution of both `owner-first` and `late-first`. Only then can the detach/re-entry hypothesis be evaluated. Browser candidate `62835966a1c680382b8ab8a7100b810abccbf2c5` remains the current canonical full-build/static GREEN baseline; its independent physical XP validation is still open.

The predecessor source defect in `patched_LdrLoadDll` remains directly proven on source `52e05a...`, and the new source contains the narrow failed-output remediation. The successor's advancement through private DWrite and font-cache activity establishes physical progress beyond the old startup boundary.

The new Procmon capture still contains failed dynamic searches for `combase.dll`, but no successful `Load Image` of that DLL; the process continues substantially beyond those probes. Do not reassign the current blocker to COMBASE from filesystem lookups alone. The Abseil WinRT timezone probe remains compile-time excluded under `MOZ_XP_COMPAT`; any remaining COMBASE probe has a different, as-yet-unlocalized owner.

Predecessor physical evidence remains source `5845ff2da277f2cc4af40f74a1ef5dd8b8b2da11`, run `34688317433`, job `103539109910`, with package `10298184343`, runtime `10297859657`, and diagnostics/PDB `10298342641`. No newly accepted physical capture is assigned to the intermediate `55a5415b...` or `630804c5...` builds.

Two distinct intentional-breakpoint failure paths are confirmed on the predecessor physical lineage and must not be conflated:

1. **Early Rust/dwrote DirectWrite factory boundary.** A process faults with `0x80000003` on an `int 3`, and the faulting stack contains `assertion failed: !dwrite_create_factory_ptr.is_null()`. In that process module list the packaged private `DWrite.dll` is not loaded. The preserved assertion text does not prove that the exact second Rust check executed. Neither the loader return nor export-resolution result is established for that historical capture; do not infer either failure or weaken the assertion. Follow the new exact-target boundary above.
2. **Later WebRender/Moz2D replay boundary.** A separate process from the same artifact lineage progresses further and faults at `xul.dll + 0x011f8583`. Matching `xul.pdb` resolves this to `mozilla::wr::Moz2DRenderCallback` in `gfx/webrender_bindings/Moz2DImageRenderer.cpp`, after `translator.TranslateRecording(...)` returns false and the code executes `MOZ_RELEASE_ASSERT(false)`. Raw-stack text contains `FillGlyphs PLAY`, so glyph/font replay is a plausible investigation area, but ownership remains unproven until `translator.GetError()` or the exact failing replay event is captured. Do not weaken the release assertion.

The loaded-module evidence for the physically tested predecessor runs no longer contains `combase.dll`; the previous COMBASE dependency is therefore not the recorded runtime boundary on that lineage. Independently, current source `52e05a...` now excludes the Abseil WinRT timezone COMBASE probe from the XP build path at compile time. The new physical captures establish the private-loader boundary above, not a browser-wide proof that every dynamic COMBASE path is absent.

The focused private Supermium DWrite path remains independently physically proven on XP by run `34317489430`, job `102356664699`, artifact `10090864697`: project msvcr14x UCRT loads at process startup with static TLS, private `pwrp_k32.dll` and `DWrite.dll` load, `DWriteCreateFactory()` succeeds and `GetSystemFontCollection()` succeeds. That focused component PASS remains a control; it does not establish the outcome of every full-browser process's loader/factory path.

The older source `88453be...` remains historical physical-browser evidence: it started, rendered and performed real remote workloads under forced non-e10s, later reaching `gfxFontGroup::GetDefaultFont()` / `gfxTextRun.cpp:2242`. That older default-font crash is no longer the sole current runtime boundary and must not be projected onto source `5845ff2d...`, `55a5415b...`, `630804c5...`, or `52e05a...` without matching evidence.

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

The canonical full XP x86 browser build/package/static compatibility boundary is **GREEN** on exact source `6a3ffb8295bfdde77df3ed34dfca911beae9941a`, run `35346927393`, job `105605594476`. This source contains the narrow `patched_LdrLoadDll` failed-output remediation and retains the previously accepted XP compatibility work, including the Abseil WinRT/COMBASE exclusion.

Physical XP runtime acceptance remains **OPEN**, but the exact successor now has physical evidence. Package `10555076979` advances through successful private DirectWrite loading, font-cache access and multiprocess startup, then the parent process exits with `0xC0000005`. The prior failed-output/private-helper startup boundary is therefore physically advanced beyond; the current acceptance blocker is the later parent-process AV whose faulting module/stack is not yet captured.

Next acceptance step: keep the exact source and temporary early `PreloadXPPrivatePwrp()` ordering unchanged and run a no-source-change teardown-order debugger experiment on the GPU child. Observe xul TLS slot 5 across the existing `DllMainCRTStartupForYY_Thunks` `DLL_THREAD_DETACH` call and the subsequent nss3/NSPR detach path, so “never allocated” and “cleared before callback” are distinguished before choosing a remediation. Keep the separate parent-process `0xC0000005` open until it is captured independently.

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

# Current XP runtime refinement — failed-load output handling in the browser hook

Additional symbolization of the predecessor physical-XP lineage (`5845ff2da277f2cc4af40f74a1ef5dd8b8b2da11`, run `34688317433`, job `103539109910`, diagnostics/PDB artifact `10298342641`) localizes one observed font-path `0x80000003` to `CrashStatsLogForwarder::CrashAction(LogReason)` with `LogReason::NativeFontResourceNotFound`. The symbolized caller chain reaches that crash from `GetUnscaledFont()` / `GetScaledFont()` inside `Moz2DRenderCallback`. In the exact pre-fix source, `NativeFontResourceDWrite::Create()` only queried `Factory::GetDWriteFactory()` and returned `nullptr` when the process-local factory was absent; the captured process module list also did not contain the packaged private `DWrite.dll`. This refines the later font/WebRender failure family but does not prove which internal DWrite load/create operation failed.

The subsequent XP-only factory-ensure source change (`5ed150c81c0ba10eff2f1b3eed614371898dfcd4`, cleanup/head `55a5415bc34a1e6db89f3643f9be881185127896`) passed the canonical full-build/static gates in run `34705592283`, job `103584935147`. It was followed by source `630804c5d2b244777e559ec16402fd71bf2607bf`, which preloads private `pwrp_k32.dll` before xul bootstrap and passed run `34824217341`, job `103912791195`.

Source `52e05a161da601e656e6ba3031084bcc60fdb098` contains functional commit `9d96597b74d726f3a51229937d48e1d0128c6ae1`, which excludes Abseil's WinRT local-time-zone path and its dynamic `combase.dll` probe when `MOZ_XP_COMPAT` is defined. Physical captures on that exact predecessor then localized the active blocker to the browser hook's handling of a failed DWrite API-set load.

Current source `6a3ffb8295bfdde77df3ed34dfca911beae9941a` implements the narrow owner fix in `patched_LdrLoadDll`: defined null initialization for the local handle, no failed-handle forwarding to the caller, and null passed to `ModuleLoadFrame::SetLoadStatus` on failed NTSTATUS while preserving successful-load semantics and the returned status. The exact successor passed the canonical full build/static gates in run `35346927393`, job `105605594476`, with package/runtime/diagnostics artifacts recorded above.

The hook's predecessor invalid-output propagation is directly proven. The successor remediation is now both full-build/package/static accepted and physically exercised: the exact package from run `35346927393` progresses through private DWrite loading, font-cache access and child-process startup instead of dying at the predecessor private-loader boundary. Sustained runtime is still not accepted because the parent later exits with a new `0xC0000005`; WinDbg localization is the next evidence boundary. Absence of the probed API-set alone does not establish a need for an additional provider DLL.

Publication check: xp-bridge-allowlist-v1 checked