# r3dfox GOST TLS — Project State

Last updated: 2026-09-30

This file is the authoritative current technical synthesis and handoff for new chats. Detailed experiment evidence is in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes; closed milestones are in `DONE.md`; pending work is in `TODO.md`; workflow roles are in `WORKFLOWS.md`; the mandatory Windows XP x86 build/dependency contract is in `XP_BUILD_CONTRACT.md`. [WEBRTC_XP_STATUS.md](WEBRTC_XP_STATUS.md) is the single source of truth for all Windows XP WebRTC build/runtime/codec/ICE/NAT status and remaining WebRTC boundaries; WebRTC state must not be duplicated here.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default branch and canonical documentation source: `agent/gost-tls-poc`.
- Windows XP SP3 x86 implementation branch: `agent/winrt-source-poc`.
- Current implementation-branch HEAD observed for this update: `8fa810b1e1331c031fe8a6fd0f91fcd1623ecaae`; this HEAD hardens the ANGLE verifier/CI contract and retains the accepted implementation ancestry. The clean release branch has independently advanced to `win-153-xp@42bfe890d9f508c9e9ce677acf8ecf03ea666626`, which consolidates the final selected XP product compatibility fixes for release validation.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the active work branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides otherwise.

## Evidence separation

Keep these tracks independent unless a deliberately combined experiment tests both:

1. GOST TLS runtime / NSS / NSPR / MSSPI / SSPI / CryptoPro / handshake.
2. Windows Vista/7/XP compatibility / Rust / msvcr14x / YY-Thunks / linker / PE imports / physical runtime.
3. Bundled extensions, localization and packaging.

Build success is not physical runtime success. Static PE/import success is not runtime success. Physical browser runtime success is not a GOST TLS handshake. Documentation commits never replace the source-under-test SHA of a binary artifact.

# Clean `win-153-xp` release line

## Latest build/package/static baseline — GREEN

The current clean-product release candidate is:

- source-under-test branch `win-153-xp`;
- source-under-test SHA `42bfe890d9f508c9e9ce677acf8ecf03ea666626`;
- workflow `.github/workflows/xp-release-build-x32.yml` / `XP release build x32`;
- workflow/control SHA `260409cadad57eda3be880e021b4881c6a4d7ae7`;
- pinned XP CI scripts `agent/winrt-source-poc@8fa810b1e1331c031fe8a6fd0f91fcd1623ecaae`;
- run `36560808861`;
- job `109380950857`;
- aggregate result **completed / success / GREEN**;
- package artifact `11039397943`, digest `sha256:a8e2777bd5b7a9a529de8da3e3ae25d403445794b56134be356e60e0efbbcfa8`;
- runtime artifact `11038838555`, digest `sha256:1b72e68c931361527472e00ea86f1a0bcb794ccc5f218a73bf95bda002821872`;
- diagnostics artifact `11038753516`, digest `sha256:4654626e20a8e82c494d61bde3c6c272981158327d39a3d422a67876aa34e8f7`.

The full Firefox/r3dfox XP x86 compile/link, explicit ANGLE `FullBuild` codegen verification, XP compatibility/import gates, CRT/D3DCompiler/private-DWrite/bcrypt staging and package-survival checks, package construction, runtime-archive generation, broad PE/direct-import audit, artifact uploads and final aggregate summary all passed. This is authoritative **build/package/static** evidence for exact product source `42bfe890...`.

The prior release attempt `36538672431 / 109308603560` on the same product source remains classified as workflow-infrastructure RED because the ANGLE verifier mode was invoked incorrectly. Run `36560808861` is the completed successful revalidation with the corrected explicit `-Mode FullBuild` contract and supersedes that RED attempt for build/static acceptance.

Physical Windows XP SP3 x86 execution of this exact clean-release payload is now artifact-correlated and has passed startup/live-session acceptance. The user is actively using the exact browser for a real ChatGPT browsing session. Independent extraction of final `r3dfox-v153.0.3.win32.zip` from package artifact `11039397943` confirms byte-for-byte SHA-1 matches for `r3dfox.exe=3867c9f67f2d22ac59d092cccc3fb2b32a1d23a0`, `xul.dll=d2be72012f2881cec30df008d86c14f1e22ed1f5`, `libGLESv2.dll=5007c5df144c05db13037628305fb8b73f6e3019`, and `d3dcompiler_old.dll=98be17e1d324790a5b206e1ea1cc4e64fbe21240`. The physical `application.ini` / `platform.ini` values also match the package exactly: BuildIDs `20260929114625` / `20260929140444`, both with `SourceStamp=42bfe890d9f508c9e9ce677acf8ecf03ea666626`.

This establishes **artifact-correlated physical XP startup/session and ordinary browsing PASS** for the current clean-product candidate. The same exact artifact has now also passed physical WebGL1 rendering: on Windows XP, `https://get.webgl.org/` reports `Your browser supports WebGL` and visibly renders the WebGL cube. The tested package already contains the pinned Firefox 52 legacy compiler as `d3dcompiler_old.dll`; its SHA-1 `98be17e1d324790a5b206e1ea1cc4e64fbe21240` is independently artifact-correlated to package `11039397943`. Therefore the clean-release transfer of the accepted ANGLE/source fixes plus packaged legacy D3D compiler fallback is physically accepted at WebGL1 rendering scope.

This does not yet claim exact-build graphics-triggered shutdown/restart, WebRTC behavior, or GOST TLS behavior.

## 2026-09-23 physical XP runtime smoke — PASS for exact local hashes; release-candidate correlation disproven

The user physically exercised a Windows XP browser and supplied exact local SHA-1 identities:

- `r3dfox.exe`: `b1e38de25a5212a54833ddcd4ca830318a10467c`;
- `xul.dll`: `266b8baea04e92d301fb6ffdd5ad87f492c398eb`.

For that exact local pair, the physical XP smoke is a **PASS**:

- browser remains usable on XP;
- ChatGPT loads over ordinary Firefox NSS HTTPS;
- Page Info General, Media, Permissions and Security render;
- the Permissions page includes the source-owned `Create WebGL context` fallback;
- certificate viewer opens and displays the `chatgpt.com -> WE1 -> GTS Root R4` chain;
- Page Info reports TLS 1.3 / `TLS_AES_128_GCM_SHA256` for the ordinary HTTPS connection;
- Saved Passwords opens `about:logins` successfully.

The authoritative CI artifacts from release run `35724604122` were independently inspected. Both package artifact `10700255591` and runtime artifact `10700395290` contain:

- `r3dfox.exe` SHA-1 `adc00ebb4cee4bc9fdd611016433827a695c93a0`;
- `xul.dll` SHA-1 `b7806d06aecdb47b83482666d3a7d59dcd8c5c6a`.

Those hashes do not match the physically tested local pair. The local pair is now user-identified as the later WebRTC/GOST full-build lineage from run `35737946733`, job `106779925555`, source-under-test `afee8c9e5ad2da729407ae06cda8d8029895ab06`; the same pair was again supplied when confirming physical XP startup of that build. Therefore the earlier smoke must not be attributed to clean release source `85863f23...`.

The release-line conclusion remains: **`85863f23...` has build/package/static GREEN evidence, but no hash-correlated physical runtime PASS yet.** The prior provenance ambiguity is resolved in the sense that the tested local pair belongs to a different implementation/WebRTC build lineage; independent artifact-side rehash of the `35737946733` payload against the supplied local SHA-1 pair is still desirable before calling that pair artifact-correlated rather than user-associated.

Detailed release-line evidence remains in `TEST_LOG_2026-09-23_release_runtime_smoke.md`.

## Current artifact-correlated clean-product physical baseline — PASS at startup/session scope

The current clean-product physical baseline has advanced to:

- `win-153-xp @ 42bfe890d9f508c9e9ce677acf8ecf03ea666626`;
- workflow `XP release build x32`;
- run `36560808861`, job `109380950857`;
- package artifact `11039397943`, runtime artifact `11038838555`, diagnostics artifact `11038753516`;
- build/package/static result **completed / success / GREEN**;
- physical Windows XP startup and sustained interactive browsing/network session **PASS**;
- the user is actively using this exact browser build for the current ChatGPT session;
- four key runtime binaries and both BuildID/SourceStamp identities are independently correlated to the final package bytes.

Artifact-side identities for the same final package are SHA-256 `r3dfox.exe=f06eaef9165248e933a8e0622b403d84fc66f324934b42513dad01bccd4f5dc8`, `xul.dll=c44a22dce70864d88ec2e58f75612ce8442e1425b1a7ef259cfea1ac25a0b399`, `libGLESv2.dll=f7cdd21624a817a189838f1fbb3dede53c8817646ef8939c2cc2ec9493d76b62`, and `d3dcompiler_old.dll=2f23182ec6f4889397ac4bf03d62536136c5bdba825c7d2c4ef08c827f3a8a1c`.

The older `586fe5f8...` / run `35697342392` result remains the last clean-product artifact with a separately recorded full lifecycle including normal shutdown. For the new consolidated `42bfe890...` package, startup/session/browsing and WebGL1 rendering are now physically accepted; graphics-triggered shutdown/process exit and restart remain the final lifecycle checks before calling the new package a full lifecycle PASS.

# Localization / packaging

The reproduced Russian-language-pack Page Info/WebGL localization blocker is closed. The source-owned Fluent fallback was physically accepted on implementation source `9e692fc9dfb1dd6f8099503e94afe887545cb5bb`, run `35700636148`, job `106657546780`, and is transferred unchanged into clean-product source `85863f23...`.

The physical Page Info smoke on 2026-09-23 also shows that General, Media, Permissions, Security, certificate-viewer and saved-password UI paths remain functional for the exact local hashes recorded above. Those hashes are now associated with the later WebRTC/GOST implementation build, not with release candidate `85863f23...`; this observation therefore remains separate from clean-release acceptance.

# GOST TLS runtime

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication. Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

Physical Windows XP GOST TLS server-auth proof exists for source `88453be37a7f39f690c504078f6f9434e2547ab6`, workflow run `34459906476`, job `102815008544`, runtime artifact `10150744314`. Under forced non-e10s and an explicit GOST allowlist, the exact browser completed TLS 1.2 MSSPI handshakes with successful server verification and HTTP application traffic.

A later no-preload XP build at source `f7d1df4eebe527f0167b0e805d1c9d9c46eaed5f`, run `35500734933`, job `106051926870`, was also user-observed to run on physical XP with ordinary RSA HTTPS and GOST TLS working. Keep that TLS-runtime evidence independent from the clean-product release line, which contains no GOST TLS/MSSPI source injection.

Open GOST work remains real `Permanent` client-certificate persistence, discovery/provider semantics, deferred deterministic T5 credential invalidation, fail-closed server-trust closure and negative verification tests, remaining mTLS/client-certificate matrix coverage, and the confirmed provider-wait Socket Thread starvation follow-up. See `TODO.md` and Stage 2 documents.

# Windows XP SP3 x86 compatibility

The project has an established physical full-browser lifecycle PASS on the GOST-bearing implementation lineage at source `62835966a1c680382b8ab8a7100b810abccbf2c5`, run `35443499166`, job `105898364295`, with eight key binaries independently matched to package artifact `10587340718`. That closed the earlier GPU-child detach AV as an immediate browser blocker without claiming a global YY/static-TLS lifecycle fix.

The temporary early private-`pwrp_k32.dll` preload is removed from the accepted line; source `f7d1df4e...` proved the narrow failed-`LdrLoadDll` output remediation is sufficient for the exercised physical lifecycle without that ordering workaround.

The XP legacy Windows file-picker fallback is physically accepted on exact source `e9d4a1115d3c97cad8cdeb0aa42c61ee5e9240a8`, focused run `35509299508 / 106074306188`, full-build run `35509338997 / 106074415929`.

The focused YY/static-TLS detach-order reproducer remains forensic evidence only: on exact source `1a61565dd3442d817893c52d473365442e24ba6c`, run `35495864771`, job `106038556671`, `owner-first` passes while `late-first` hangs during teardown. Do not use that focused result as a substitute for browser runtime evidence and do not broaden YY-Thunks from inference.

The active implementation branch has moved beyond the release candidate with additional compatibility work. Do not infer physical acceptance from its current HEAD. Every new runtime claim still requires exact source/artifact/binary identity.

## Download completion / Windows Recent Documents XP line

The predecessor physical XP build from implementation source `9e692fc9dfb1dd6f8099503e94afe887545cb5bb`, run `35700636148`, job `106657546780`, exposed a stable `0xC06D007F` crash when an ordinary download completed while `browser.download.manager.addToRecentDocs=true`. Matching dump/PDB/PE analysis localized the exact delayed API to `SHELL32.dll!SHCreateItemFromParsingName`, called from `AddToRecentDocs()` in `DownloadPlatform::DownloadDone()`.

On that same predecessor build, setting `browser.download.manager.addToRecentDocs=false` allowed downloads to complete without the crash. This is a useful A/B runtime confirmation of the owner/path, but it is a workaround on the old binary and not proof of the source fix.

The narrow implementation fix is source `e13354c79ebfa206fbccc946592256d33e4ac519`, containing:

- `2c8dc1dc4696c5efcef0b00da4106ac4170b4de7` — under `MOZ_XP_COMPAT`, skip the AppUserModelID / `SHCreateItemFromParsingName` path and use the existing `SHAddToRecentDocs(SHARD_PATHW, ...)` fallback;
- `e13354c79ebfa206fbccc946592256d33e4ac519` — add `SHCreateItemFromParsingName` to the core-browser XP import regression gate.

Canonical full-build evidence for this exact source is:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `35810132801`, job `107019631325`;
- aggregate result **completed / success / GREEN**;
- package artifact `10733487295`, digest `sha256:cc72661870838b6127e08b5c80f27a91de69ab5725546d5134095d6fb27d2b2c`;
- runtime artifact `10733956483`, digest `sha256:e9edf4fdeb2902592b88332655332f130cf8e914d693fa926b14a4d3dffb45eb`;
- diagnostics artifact `10733113244`, digest `sha256:d47de71f9b51dbcdf2fdaa857dcac8ce6a5edc1b24d96042ed73afdf0ee02013`.

The full build, package creation, runtime archive, core-browser import gate, broad XP PE/direct-import audit, artifact uploads and final summary all passed. Physical Windows XP validation of the exact successor runtime also passed with `browser.download.manager.addToRecentDocs=true`: an ordinary user download completed without error or browser crash.

User-recorded SHA-1 identities are `r3dfox.exe=3f4f98bb9ad710bda5c72fa25d1e124d37c211b4` and `xul.dll=17ee19d4a947466b25d95089a967f7d055261c2b`; both match the binaries independently extracted from runtime artifact `10733956483`.

Conclusion: **the download-completion `0xC06D007F` / `SHELL32!SHCreateItemFromParsingName` blocker is physically closed for artifact-correlated source `e13354c...`.**

## ANGLE / WebGL GPU-child XP line

Physical Windows XP testing of predecessor source `e13354c79ebfa206fbccc946592256d33e4ac519` reproduced a GPU-child `0xC0000005` at `libGLESv2+0x0003C1CA` in the ANGLE trace-category function-local static used before renderer implementation initialization.

Exact successor source `3119c849b3930145c8e4181b8a06a692ec20514d`, run `35860139917`, job `107178068460`, runtime artifact `10759971452`, diagnostics artifact `10759359771`, is build/package/static GREEN and has now been physically exercised on XP with artifact-matching hashes:

- `r3dfox.exe=4103c98f53c53513f42f087df4ff6306083cc9dd`;
- `xul.dll=790260efa0bde58fb4faa964a517914efbe44d40`;
- `libGLESv2.dll=84edd61305a6bd048c1710f2a6e7d326fd11ac4c`.

A fresh profile starts and browses normally. WebGL still fails, but not at the former trace site: the new physical fault is `libGLESv2+0x00159EBB`. Matching PDB maps it to `std::_Tree<...>::begin()` inside `rx::d3d9_gl::GenerateCaps()` at `renderer9_utils.cpp:517`, immediately after `gl::GetAllSizedInternalFormats()` at `formatutils.cpp:2006`. That function contains another dynamically initialized local static `angle::base::NoDestructor<FormatSet>`.

Exact-DLL disassembly and matching PDB show the MSVC thread-safe-static TLS/epoch path at this second site, including `fs:[0x2c]`, `_Init_thread_header`, and `_Init_thread_footer`. The returned `FormatSet` has a null tree head and faults in `begin()`. Therefore the previous trace-only source fix advanced the runtime boundary but did not close the broader ANGLE local-static/TLS compatibility class.

Product remediation commit `b01f3461d52eec1b60aa87d12e083f3485032fba`:

- `5934345e6c6e805a703efc1cc425b6aebfe8c0a4` adds `/Zc:threadSafeInit-` for Windows x86 ANGLE in `gfx/angle/moz.build.common`;
- `b01f3461...` restores the normal trace-event static cache so the component build configuration handles both known sites uniformly.

Focused workflow run `35974426502`, job `107551429542`, artifact `10798373361` is now **completed / success / GREEN** against product source `b01f3461...` with workflow/control SHA `741ebbca...`. The corrected codegen gate reports `Display.cpp: /Zc:threadSafeInit-=True Init_thread_matches=0` and `formatutils.cpp: /Zc:threadSafeInit-=True Init_thread_matches=0`. The following binary gate also passed for focused `libGLESv2.dll` SHA-256 `8db4feb9db2f99eb61e3bc611abd2845a913e4b2cc1a281e1df0264ee8c46aa6`, with `DXGI=False`, `CreateDXGIFactory=False`, `CreateDXGIFactory1=False`, `D3D9=True`.

The same verifier responsibility was integrated into the full XP x32 workflow at historical implementation commit `f15a047e...`, which added `verify-angle-trace-xp-codegen.ps1 -Mode FullBuild` immediately after successful `mach build`; the final aggregate summary treats this ANGLE codegen gate as blocking while later diagnostics/artifact collection still proceeds. The current implementation HEAD is recorded in the repository/branch section above.

Full run `35980235042`, job `107570122638`, exact source-under-test `f15a047e847cdca07d90396fe88d32a74cee416e`, is now **completed / success / GREEN**. The browser build, ANGLE full-build codegen gate, remaining XP package/import gates, package/runtime creation, artifact uploads and final aggregate summary all passed. The full-build verifier reports `Display.obj: Init_thread_matches=0` and `formatutils.obj: Init_thread_matches=0`; produced `libGLESv2.dll` SHA-256 is `30ff7dc27e949e5d952ccc1e15186aff07523d1acd5da6ec18ba51493d8075f7`. Artifacts: package `10806218628`, runtime `10806283395`, diagnostics `10806562241`.

This closes the full-build/static acceptance boundary for the ANGLE remediation.

Physical Windows XP testing has now advanced the runtime boundary further. In a console session, the GPU child carries SourceStamp `f15a047e847cdca07d90396fe88d32a74cee416e` / BuildID `20260924094702`; `get.webgl.org` successfully reports WebGL support and visibly renders the test cube. Therefore WebGL context creation and exercised rendering are now physically observed on the remediated source, beyond both predecessor local-static failure boundaries.

The physical WebGL result is now artifact-correlated to package artifact `10806218628`: the tested `r3dfox.exe`, `xul.dll`, and final packaged `libGLESv2.dll` all match the portable ZIP byte-for-byte. Published final-package SHA-256 identities are `e46e86105a7acd99dd9cb3ed803eca90ccd0df519a3a9f10b4bf471f4e3e370c`, `44bf7b20cca45742bac988876cf2cf179435eb2adbf7ca0a66e2bed932b1c165`, and `ae6589abc4acaee7535e706106183b8d201adf5f2aa71a992db5197ffe87624c`, respectively. The package carries the same SourceStamp `f15a047e...` and BuildIDs observed in the physical test.

The earlier full-build verifier hash `30ff7dc27e949e5d952ccc1e15186aff07523d1acd5da6ec18ba51493d8075f7` is the pre-retarget diagnostic `libGLESv2.dll` copied immediately after `mach build`; the final packaged file is later PE-retargeted and therefore has the distinct final hash above.

The remaining blocker is GPU-process stability, not initial WebGL bring-up or provenance. `about:support` confirms an active GPU process, Software WebRender compositor fallback, and WebGL still available as a separate feature decision; compositor fallback therefore does not invalidate the physical WebGL rendering PASS.

Two independent physical captures of the exact `f15a...` line now converge on the same `0x80000007 / STATUS_WAKE_SYSTEM_DEBUGGER` boundary. Matching `xul.pdb` maps the Firefox side to `gfxWindowsPlatform::GetGpuTimeSinceProcessStartInMs() -> mozilla::glean::RecordPowerMetrics() -> mozilla::glean::FlushFOGData()`. The current shutdown capture reaches it through GPU-process `FlushFOGData` IPC; the earlier intermittent capture reaches the same power-metrics path from a FOG IPC payload flush. Immediately below the Firefox frame, the native stack is in `LoadLibraryW` / mozglue DLL-blocklist / `GetModuleHandleW` loader handling. Source inspection shows `GetGpuTimeSinceProcessStartInMs()` loads `gdi32.dll` before resolving `D3DKMTQueryStatistics`.

This establishes a repeatable telemetry/loader boundary distinct from ANGLE/WebGL rendering. It still does not prove the exact mechanism behind `0x80000007`. The narrow pre-Vista A/B is implemented in source `27f4271bddc228f21d64370a3781ba35a92a96e0`: pre-Vista Windows returns `NS_ERROR_NOT_AVAILABLE` before the `LoadLibrary(L"gdi32.dll")` call, while Vista+ behavior and all ANGLE/D3D9 rendering remain unchanged. Full XP x32 run `36164782271`, job `108169777457`, is **completed / success / GREEN** against that exact source. Package `10883654763`, runtime `10883894624`, and diagnostics `10884079570` were published. At build completion this established build/package/static evidence only; later physical RDP and graphics-triggered runtime evidence for the same exact payload is recorded below.

## WebRTC XP line

[WEBRTC_XP_STATUS.md](WEBRTC_XP_STATUS.md) is the single source of truth for Windows XP WebRTC build identity, runtime evidence, codec/media/ICE/NAT coverage, closed blockers, and remaining boundaries. Do not duplicate or maintain WebRTC status in `PROJECT_STATE.md`; update that document directly.

# Build-configuration identity

Keep the XP mechanisms distinct:

- C/C++: `CFLAGS/CXXFLAGS += -DMOZ_XP_COMPAT`;
- Rust: `RUSTFLAGS="--cfg moz_xp_compat"`;
- neither implies `CONFIG["MOZ_XP_COMPAT"]` in `moz.build`.

# Current acceptance / next boundary

For the clean release line, `win-153-xp@42bfe890d9f508c9e9ce677acf8ecf03ea666626` is now the latest accepted **build/package/static** candidate: workflow `XP release build x32`, run `36560808861`, job `109380950857`, package `11039397943`, runtime `11038838555`, diagnostics `11038753516`, completed / success / GREEN. The immediate clean-product acceptance boundary is physical Windows XP execution of that exact payload with binary/artifact correlation. Until then, `win-153-xp@586fe5f856971a790db6e3529bdb0ac7a6133872` remains the last clean-product source with artifact-correlated physical lifecycle PASS.

For the implementation XP line, the download/recent-documents blocker remains physically closed on artifact-correlated source `e13354c...`. Source `3119c849...` physically advances past the former ANGLE trace-category `libGLESv2+0x3C1CA` crash but reaches a second TLS-backed local-static failure at `libGLESv2+0x159EBB` in `GenerateCaps -> GetAllSizedInternalFormats`. The ANGLE product remediation remains `b01f3461...` (`/Zc:threadSafeInit-` plus restored normal trace static). Focused run `35974426502 / 107551429542` proves both known owner objects contain zero `_Init_thread_header/footer/epoch` matches and passes the focused `libGLESv2.dll` binary gate. Full run `35980235042 / 107570122638` is completed / success / GREEN on `f15a047e...`, and physical console XP reaches artifact-correlated WebGL context creation and rendering on that package output. The later telemetry A/B source `27f4271...` also has completed / success / GREEN full-build evidence from run `36164782271 / 108169777457`, with package `10883654763`, runtime `10883894624`, and diagnostics `10884079570`. Exact binaries from that package are independently hash-correlated and ordinary RDP startup/profile/policy/browsing/shutdown remains a physical lifecycle PASS. Contradictory graphics-triggered evidence now narrows that acceptance: after opening the WebGL test page and then closing the browser, the exact new-build GPU child again produces `0x80000007 / STATUS_WAKE_SYSTEM_DEBUGGER`. Matching `xul.pdb` no longer shows the predecessor `GetGpuTimeSinceProcessStartInMs -> RecordPowerMetrics -> FlushFOGData` / `LoadLibraryW` path; instead the exception-thread Firefox frame is in `mozilla::widget::WinUtils::WaitForMessage()`, with the upper stack in the ordinary GPU child app/message loop. Exact disassembly shows the return site follows `USER32!MsgWaitForMultipleObjectsEx`; Watson's `GetLastInputInfo+...` export label is not the actual imported call. Therefore the pre-Vista D3DKMT guard is retained as a successful boundary advancement. That Watson capture alone did not prove a new root-cause owner; the later live WinDbg evidence in the following paragraph advances the graphics-triggered teardown boundary to the `libGLESv2.dll` static-TLS lifecycle contract. The predecessor `f15a...` console test remains the latest accepted WebGL rendering evidence; console WebGL on `27f4271...` is still pending.

A later live WinDbg reproduction on the exact artifact-correlated `27f4271...` payload materially advances the graphics-triggered teardown boundary. Matching `libGLESv2.pdb` captures an unhandled second-chance `0xC0000005` in `libGLESv2!DllMain` with `fdwReason=DLL_THREAD_DETACH`. The faulting path is `egl::DeallocateCurrentThread() -> SafeDelete(gCurrentThread)`; the module TLS slot is present, while `thread_local gCurrentThread` is NONNULL but invalid for the observed read dereference. Debugger-derived numeric pointer/memory content is withheld from the public record. The same DLL contains YY-Thunks TLS-remediation state, yet runtime shows `g_TlsMode=None`, and independent PE inspection proves its entry point maps to ordinary `_DllMainCRTStartup` rather than `DllMainCRTStartupForYY_Thunks`.

This establishes a specific current owner for the captured AV: the Windows XP static-TLS lifecycle contract of dynamically loaded `libGLESv2.dll`. It does not retroactively prove that every earlier `0x80000007` capture had the same initiating event. Narrow remediation is committed at `482bc441...` by applying the already-used xul YY DLL entry-point contract only to Windows x86 `libGLESv2`; implementation HEAD `ad96945f...` additionally makes source verification and final packaged-runtime `contract=true` verification blocking.

Focused qualification is now complete: corrected `XP ANGLE libGLESv2 smoke` run `36257921234`, job `108448117969`, checks out exact product source `ad96945f101cedc25b9ed40df25bbed25c045833` and is **completed / success / GREEN**. The focused link resolves `DllMainCRTStartupForYY_Thunks` through the proven narrow YY provider, the ANGLE trace-codegen gate passes, and focused binary inspection preserves D3D9 while reporting no DXGI/CreateDXGIFactory imports. Predecessor focused run `36255787912 / 108442196461` is classified as workflow-infrastructure RED because the short workflow had not yet activated the YY provider.

Full implementation build/static acceptance is now complete: run `36294912858`, job `108551864059`, exact source `ad96945f101cedc25b9ed40df25bbed25c045833`, is **completed / success / GREEN**. The full browser build, ANGLE XP local-static codegen gate, XP PE/import audit, package/runtime creation and aggregate summary all passed. Final runtime-closure inspection reports `libGLESv2.dll` with `entry_wrapper=true`, `yy_first_tls_callback=true`, and `contract=true`; package artifact `10925293352`, runtime artifact `10925462253`, and diagnostics artifact `10925258640` were published. The non-blocking YY DLL inventory also reports `strong candidates=16`, `contracts=4`, `missing-contract candidates=12`; those remaining entries are diagnostic follow-up candidates, not established defects. The exact package has now also advanced physically on Windows XP under RDP: artifact-correlated `r3dfox.exe` SHA-1 `5782f259de42100eeb381ad24f3ff74d168f2784`, `xul.dll` SHA-1 `f9ed3373bcd84c5bf3924406a19710cce08d8b5c`, and `libGLESv2.dll` SHA-1 `8a2b7558af0b7fdbcc741b4fed6f71fedf44c16f` start successfully and the prior visible error dialogs are not reproduced. A subsequent `get.webgl.org` RDP exercise also completes with clean browser shutdown: the MOZ network/IPC log shows real `get.webgl.org:443` activity, a live GPU child, and orderly `xpcom-shutdown`, with no fatal/crash/exception marker in the supplied log. The accompanying `about:support` capture reports software WebRender, the RDP display path, and WebGL 1/2 disabled, so this does not exercise or accept the real WebGL rendering/`libGLESv2` teardown path. Targeted console-capable WebGL+GPU-child teardown acceptance remains pending.


A narrow WebGL presentation-path fix is now implemented at source `705470c0f1fd7302669b1f4d4c9aead33b773928`. It makes `SurfaceFactory_ANGLEShareHandle::Create()` reject an ANGLE display that has no D3D11 device, allowing the already-existing `SurfaceFactory_Basic` readback/copy fallback to be selected before a later `CreateShared()` failure can force `LoseContext()`. Full run `36325907730`, job `108638512476`, is **completed / success / GREEN** on that exact source. Package `10936509397`, runtime `10937007948`, and diagnostics `10936509452` are bound to the run; all blocking build/package/static gates completed successfully.

The same new build has also passed the Windows 10 control-system functional A/B with byte-for-byte artifact correlation: with ANGLE D3D9Ex, `get.webgl.org` visibly renders the rotating cube, whereas the predecessor source lost the WebGL context at `Swap chain surface creation failed.`. User SHA-1 values for `r3dfox.exe`, `xul.dll`, and `libGLESv2.dll` match the corresponding files extracted from package artifact `10936509397` exactly. This materially supports the diagnosed factory-selection defect and the Basic/readback fallback as the correct presentation route. It does not close the independent physical Windows XP WebGL/teardown boundary.

Physical XP has now exercised the exact `705470c0...` package and **does not pass WebGL presentation**. Artifact-correlated SHA-1 values for `r3dfox.exe`, `xul.dll`, and `libGLESv2.dll` match package `10936509397` exactly. On `get.webgl.org`, the cube remains blank and the console reports `<Present>: Swap chain surface creation failed.` followed by `WebGL context was lost.`. Therefore the Windows 10 fallback fix does not close the XP presentation boundary. The next owner is below `SwapChain::Acquire()`; the selected surface factory and first failed query/allocation are still unmeasured.

Physical XP `about:support` now narrows the current WebGL presentation failure further. The Graphics failure log shows `RcANGLE(no compositor device for EGLDisplay)(Create)` followed by `MozFramebuffer::CreateImpl(size:Size(140,150), samples:0, depthAndStencil:false, colorTarget:0xde1, colorName:0): Incomplete: 0x0`. The exact canvas-sized, no-depth/no-MSAA allocation identifies the `SurfaceFactory_Basic` presentation route. Therefore the D3D11-factory early rejection is working on XP; the remaining failure is inside Basic-surface allocation. `MozFramebuffer::Create()` reaches `CreateImpl()` with texture name zero, meaning `gl->CreateTexture()/fGenTextures()` produced no usable GL object name. The reason remains open; stale/non-current EGL context or thread-current ownership is a leading hypothesis, not yet a conclusion.

A second concrete XP graphics blocker is now proven in parallel with the Basic framebuffer failure: the exact packaged `d3dcompiler_47.dll` loads under WinDbg and immediately raises first-chance `0xC0000139 / STATUS_ENTRYPOINT_NOT_FOUND`. The packaged DLL directly imports `_except_handler4_common` from `msvcrt.dll`; historical Mozilla work on D3DCompiler 47 identified this as Vista-only and therefore incompatible with XP even after lowering the PE subsystem version. Current ANGLE already contains a fallback load of `d3dcompiler_old.dll`, but the package does not ship that file.

Physical Windows XP WebGL presentation has now achieved a visible-render PASS using the exact base browser from source `705470c0...` plus ANGLE's already-existing legacy compiler fallback. A Firefox 52.9.0 32-bit `D3DCompiler_43.dll` was placed beside the browser as `D3DCompiler_old.dll` (SHA-1 `98be17e1d324790a5b206e1ea1cc4e64fbe21240`, version `9.29.952.3111`). With that single runtime addition, `get.webgl.org` renders the rotating cube on XP and the previous shader/program-null plus `MozFramebuffer ... colorName:0` failure disappears. This validates the existing ANGLE fallback architecture and identifies the packaged D3DCompiler 47 incompatibility as the active XP WebGL packaging/runtime blocker.
A subsequent clean-config retest restored all diagnostic `webgl.*` preferences to defaults, restarted the browser, and still produced the rotating cube. Therefore no special WebGL preference override is required for this PASS; the decisive runtime dependency is the XP-compatible legacy D3D compiler fallback.

The active XP graphics boundary is therefore now: instrument or otherwise establish the requested texture type, selected `SurfaceFactory`, and first failed operation on the exact XP path. If `SurfaceFactory_Basic` is already selected, the next source boundary is `SharedSurface_Basic::Create() -> MozFramebuffer::Create()`; if not, identify the typed-factory failure path first. Only after visible frame presentation succeeds should the graphics-triggered shutdown test be used to close the prior `libGLESv2!DllMain` / `DLL_THREAD_DETACH` second-chance AV boundary. An RDP-specific WebGL test is useful but must control the feature-policy/blocklist prefs separately from the presentation fix.

For Windows XP WebRTC acceptance and remaining WebRTC boundaries, consult [WEBRTC_XP_STATUS.md](WEBRTC_XP_STATUS.md); no WebRTC status is restated here.

Keep later XP compatibility experiments, WebRTC, packaging/localization and GOST TLS runtime as independent evidence lines.

# Global evidence rules

- Build success != physical runtime PASS.
- Physical runtime PASS != GOST handshake PASS.
- Static PE/import PASS != runtime PASS.
- Win7 x86 startup != XP startup.
- Static source/import removal != physical-XP closure until the exact accepted artifact advances past it.
- Documentation HEADs never replace source-under-test SHA.
- A PDB may symbolize only its matching binary from the same build.
- Runtime claims stay bound to exact source SHA + Actions run/job + exact artifact/binary identity.

### XP-compatible web identity

Implementation commit `94ff24222ce2b05c2f89185778f062120a332881` adds the previously deferred `MOZ_XP_COMPAT` branch in `nsHttpHandler.cpp`: XP-compatible builds format the Windows OS/CPU component as `Windows NT 10.0` instead of exposing the physical XP `5.1` result from `GetVersionEx`. This drives the normal HTTP User-Agent service and `navigator.oscpu`; `navigator.platform` remains `Win32`. The change is compile-time build policy, not a physical-XP-only runtime branch, and does not remove the separate `r3dfox/153.0.3` product token.

Full workflow `36448769364 / 109017796850` completed **success / GREEN** on exact source-under-test `94ff24222ce2b05c2f89185778f062120a332881`, so the web-identity implementation now has full build/package/static acceptance. Artifacts: package `10990972577` (`sha256:042eca7570bccf7df6764eaf6d7caf6dfd3a01b6a67fc3facddfa85bede59aa8`), runtime `10990353061` (`sha256:4c744ce5abde18d0d5d0c3ed08afaed5141f1767dd860ffed5902323abed4dd8`), diagnostics `10990717703` (`sha256:60192433e2bcfe0b28e43acb70f95267921a847b60feeb29f8cf42a4e23ca14e`). Static/build GREEN is not physical XP runtime PASS: the remaining acceptance is an exact-package runtime check with no manual `general.useragent.override`, covering `navigator.userAgent`, `navigator.oscpu`, `navigator.platform`, `navigator.appVersion`, the actual outgoing HTTP `User-Agent`, WebGL with the packaged compiler pair, and graphics-triggered clean shutdown.

Physical Windows XP SP3 x86 runtime acceptance has now begun on this exact package and is artifact-correlated. The locally running browser reports `application.ini BuildID=20260928163654`, `platform.ini BuildID=20260928185320`, and `SourceStamp=94ff24222ce2b05c2f89185778f062120a332881` in both files. Local SHA-1 values match the corresponding files extracted from package artifact `10990972577` exactly: `r3dfox.exe=73ee1b683e4410804f4aa113e3057a3a2f50575d`, `xul.dll=fc1c57d8aa5827c76f0e6c51631424acde65438b`, `libGLESv2.dll=e01c0757697214101e9d6aa887576f46011b1c21`, `d3dcompiler_47.dll=ac019f36f22d527b60773e380b473a764721d377`, `d3dcompiler_old.dll=98be17e1d324790a5b206e1ea1cc4e64fbe21240`. On physical XP the browser launches and sustains an interactive browsing/network session (the user is actively using this exact build for the current ChatGPT session). WebGL is also now physically PASS on this exact artifact: `https://get.webgl.org/` reports `Your browser supports WebGL` and visibly renders the rotating cube. HTTP web-identity is now physically PASS for this exact artifact and source fix. The earlier contaminating `general.useragent.override` was explicitly removed from the profile, the browser was fully restarted, and the pref was confirmed absent. After restart, `httpbin.org/user-agent` reports `Mozilla/5.0 (Windows NT 10.0; rv:153.0) Gecko/20100101 Firefox/153.0 r3dfox/153.0.3`. This is the normal product UA shape and proves the server receives `Windows NT 10.0` without a manual override on source `94ff242...`. JS-visible web identity is also now physically PASS in the same no-override session: `navigator.userAgent="Mozilla/5.0 (Windows NT 10.0; rv:153.0) Gecko/20100101 Firefox/153.0 r3dfox/153.0.3"`, `navigator.oscpu="Windows NT 10.0"`, `navigator.platform="Win32"`, and `navigator.appVersion="5.0 (Windows)"`. This closes the intended web-identity boundary for commit `94ff242...`. Graphics-triggered clean shutdown is now physically PASS on the same exact artifact: after loading `https://get.webgl.org/` and rendering the WebGL cube, the browser was closed normally, all `r3dfox.exe` processes were observed to exit, and the browser then restarted successfully into another live session. No error dialogs were observed during the morning test session. This closes the focused XP runtime acceptance for startup/session, WebGL, web identity, and graphics-triggered shutdown on package artifact `10990972577`. GOST TLS remains a separate evidence line.


### XP WebGL capability boundary

Physical XP runtime and source inspection now establish the capability boundary of the accepted graphics path. On exact package artifact `10990972577` / source `94ff24222ce2b05c2f89185778f062120a332881`, `canvas.getContext("webgl")` succeeds while `canvas.getContext("webgl2")` returns `null` with `tryANGLE (FEATURE_FAILURE_EGL_NO_CONFIG)` followed by `FEATURE_FAILURE_WEBGL_EXHAUSTED_DRIVERS`.

This is consistent with and directly explained by the current source path: `WebGLContext.cpp` sets `CreateContextFlags::PREFER_ES3` for WebGL2; `GLContextProviderEGL.cpp` then asks EGL for an ES3-capable config/context and reports `FEATURE_FAILURE_EGL_NO_CONFIG` when no compatible config exists; the active ANGLE D3D9 backend hard-caps both `getMaxSupportedESVersion()` and `getMaxConformantESVersion()` at `gl::Version(2, 0)`. Therefore the accepted XP ANGLE/D3D9 path provides WebGL1 / GLES2 capability, not WebGL2 / GLES3.

This is a confirmed capability boundary, not a regression in the now-accepted WebGL1 path. Adding WebGL2 on XP would require a separate graphics architecture/backend effort rather than another D3DCompiler fallback change.

### D3DCompiler packaging state

Focused run `36385541515 / 108810027817` proved the Firefox 52.9.0 ESR SDK as a reproducible source for both `D3DCompiler_43.dll` and the unmodified `d3dcompiler_47.dll`. The legacy 43 binary is the proven physical-XP WebGL fallback when staged as `d3dcompiler_old.dll`; the 47 reference remains subsystem 6.0 and should not be retargeted to XP.

Full run `36390265057 / 108824318489` on source `8bb4ef8fed2362030a27e67058be87e12be61bba` completed with all D3DCompiler retarget/package/SM3 gates PASS, together with successful build, package, CRT, private-DirectWrite and bcrypt gates. The final aggregate remained RED only because the broad import audit had incorrectly generalized historical `_except_handler4_common` evidence into a bare-symbol ban; diagnostics artifact `10962284979` shows all 23 hits were imports satisfied by the pinned app-local `ucrtbase.dll`. The special `_except_handler4_common` audit rule has now been removed entirely. Source `0832bbb1dbbe52f9dde9f101bef2a512c5daf72e` keeps the broad audit's pre-existing XP rules and the narrow optional root `_47` role, but adds no speculative guard for that historical D3DCompiler symbol. Full run `36422520907 / 108928478106` on that exact source is now completed **success / GREEN**, closing the CI build/package/static acceptance for this cleaned candidate. Physical XP/Windows 10 acceptance of the automatically packaged compiler pair remains separate.
