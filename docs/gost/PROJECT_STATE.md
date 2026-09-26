# r3dfox GOST TLS — Project State

Last updated: 2026-09-26

This file is the authoritative current technical synthesis and handoff for new chats. Detailed experiment evidence is in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes; closed milestones are in `DONE.md`; pending work is in `TODO.md`; workflow roles are in `WORKFLOWS.md`; the mandatory Windows XP x86 build/dependency contract is in `XP_BUILD_CONTRACT.md`. [WEBRTC_XP_STATUS.md](WEBRTC_XP_STATUS.md) is the single source of truth for all Windows XP WebRTC build/runtime/codec/ICE/NAT status and remaining WebRTC boundaries; WebRTC state must not be duplicated here.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default branch and canonical documentation source: `agent/gost-tls-poc`.
- Windows XP SP3 x86 implementation branch: `agent/winrt-source-poc`.
- Current implementation-branch HEAD observed before this documentation update: `ad96945f101cedc25b9ed40df25bbed25c045833`. Product change `482bc4417601fc96f2ab135f377f64e03945cd27` adds the YY-Thunks TLS-aware DLL entry-point contract to Windows x86 `libGLESv2.dll`; the following commits add source/final-binary CI gates. The earlier pre-Vista D3DKMT guard remains in ancestry and is not reverted. The ANGLE product remediation remains rooted at `b01f3461d52eec1b60aa87d12e083f3485032fba`; `cee8175a...`, `d655a237...`, and `f15a047e...` add XP CI verification infrastructure, while `27f4271...` is the subsequent one-file product runtime A/B in `gfx/thebes/gfxWindowsPlatform.cpp`.
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
- source-under-test SHA `85863f2355a23223bf33f55b641ccb509a2b72ac`;
- workflow `.github/workflows/xp-release-build-x32.yml` / `XP release build x32`;
- run `35724604122`;
- job `106735182867`;
- aggregate result **completed / success / GREEN**;
- package artifact `10700255591`, digest `sha256:63b97b0e53b31bcb062dbf98d1ebdb67124de76af1bad663911972834c1c2cb2`;
- runtime artifact `10700395290`, digest `sha256:f8dd39d87d304f5e99d02e299a08c278287f18a523f207dd257c53aaa04076b3`;
- diagnostics artifact `10700061102`, digest `sha256:ab984ed4662365fdb8fcbba17166edc9ebb362d3ae95d44dd39281c7960eaad0`.

The full Firefox/r3dfox XP x86 compile/link, XP compatibility gates, package construction, runtime-archive generation, package-survival checks, broad PE/direct-import audit, artifact uploads and final summary all passed. This is authoritative **build/package/static** evidence for exact product source `85863f23...`.

The source contains the six-file WebGL/stock-language-pack fallback already physically proven on the implementation line.

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

## Last artifact-correlated clean-product physical baseline — PASS

The current source/artifact-correlated clean-product physical baseline remains:

- `win-153-xp @ 586fe5f856971a790db6e3529bdb0ac7a6133872`;
- workflow `XP release build x32`;
- run `35697342392`, job `106647034214`;
- package `10685004306`, runtime `10684874629`, diagnostics `10686043053`;
- build/package/static result **completed / success / GREEN**;
- physical Windows XP startup, new-profile creation, policy-driven uBlock installation, representative page browsing, normal shutdown and orderly termination **PASS**;
- four key runtime binaries were independently hash-correlated to package artifact `10685004306`.

This distinction is intentional: the newer source has the stronger build/static result, while the older source remains the latest clean-product physical result whose local binaries are proven to come from the named CI artifact.

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

The same verifier responsibility is integrated into the full XP x32 workflow on `agent/winrt-source-poc`. Current implementation HEAD `f15a047e...` adds `verify-angle-trace-xp-codegen.ps1 -Mode FullBuild` immediately after successful `mach build`; the final aggregate summary treats this ANGLE codegen gate as blocking while later diagnostics/artifact collection still proceeds.

Full run `35980235042`, job `107570122638`, exact source-under-test `f15a047e847cdca07d90396fe88d32a74cee416e`, is now **completed / success / GREEN**. The browser build, ANGLE full-build codegen gate, remaining XP package/import gates, package/runtime creation, artifact uploads and final aggregate summary all passed. The full-build verifier reports `Display.obj: Init_thread_matches=0` and `formatutils.obj: Init_thread_matches=0`; produced `libGLESv2.dll` SHA-256 is `30ff7dc27e949e5d952ccc1e15186aff07523d1acd5da6ec18ba51493d8075f7`. Artifacts: package `10806218628`, runtime `10806283395`, diagnostics `10806562241`.

This closes the full-build/static acceptance boundary for the ANGLE remediation.

Physical Windows XP testing has now advanced the runtime boundary further. In a console session, the GPU child carries SourceStamp `f15a047e847cdca07d90396fe88d32a74cee416e` / BuildID `20260924094702`; `get.webgl.org` successfully reports WebGL support and visibly renders the test cube. Therefore WebGL context creation and exercised rendering are now physically observed on the remediated source, beyond both predecessor local-static failure boundaries.

The physical WebGL result is now artifact-correlated to package artifact `10806218628`: the tested `r3dfox.exe`, `xul.dll`, and final packaged `libGLESv2.dll` all match the portable ZIP byte-for-byte. Published final-package SHA-256 identities are `e46e86105a7acd99dd9cb3ed803eca90ccd0df519a3a9f10b4bf471f4e3e370c`, `44bf7b20cca45742bac988876cf2cf179435eb2adbf7ca0a66e2bed932b1c165`, and `ae6589abc4acaee7535e706106183b8d201adf5f2aa71a992db5197ffe87624c`, respectively. The package carries the same SourceStamp `f15a047e...` and BuildIDs observed in the physical test.

The earlier full-build verifier hash `30ff7dc27e949e5d952ccc1e15186aff07523d1acd5da6ec18ba51493d8075f7` is the pre-retarget diagnostic `libGLESv2.dll` copied immediately after `mach build`; the final packaged file is later PE-retargeted and therefore has the distinct final hash above.

The remaining blocker is GPU-process stability, not initial WebGL bring-up or provenance. `about:support` confirms an active GPU process, Software WebRender compositor fallback, and WebGL still available as a separate feature decision; compositor fallback therefore does not invalidate the physical WebGL rendering PASS.

Two independent physical captures of the exact `f15a...` line now converge on the same `0x80000007 / STATUS_WAKE_SYSTEM_DEBUGGER` boundary. Matching `xul.pdb` maps the Firefox side to `gfxWindowsPlatform::GetGpuTimeSinceProcessStartInMs() -> mozilla::glean::RecordPowerMetrics() -> mozilla::glean::FlushFOGData()`. The current shutdown capture reaches it through GPU-process `FlushFOGData` IPC; the earlier intermittent capture reaches the same power-metrics path from a FOG IPC payload flush. Immediately below the Firefox frame, the native stack is in `LoadLibraryW` / mozglue DLL-blocklist / `GetModuleHandleW` loader handling. Source inspection shows `GetGpuTimeSinceProcessStartInMs()` loads `gdi32.dll` before resolving `D3DKMTQueryStatistics`.

This establishes a repeatable telemetry/loader boundary distinct from ANGLE/WebGL rendering. It still does not prove the exact mechanism behind `0x80000007`. The narrow pre-Vista A/B is implemented in source `27f4271bddc228f21d64370a3781ba35a92a96e0`: pre-Vista Windows returns `NS_ERROR_NOT_AVAILABLE` before the `LoadLibrary(L"gdi32.dll")` call, while Vista+ behavior and all ANGLE/D3D9 rendering remain unchanged. Full XP x32 run `36164782271`, job `108169777457`, is **completed / success / GREEN** against that exact source. Package `10883654763`, runtime `10883894624`, and diagnostics `10884079570` were published. This is build/package/static evidence only; the physical XP runtime result for the new source remains open.

## WebRTC XP line

[WEBRTC_XP_STATUS.md](WEBRTC_XP_STATUS.md) is the single source of truth for Windows XP WebRTC build identity, runtime evidence, codec/media/ICE/NAT coverage, closed blockers, and remaining boundaries. Do not duplicate or maintain WebRTC status in `PROJECT_STATE.md`; update that document directly.

# Build-configuration identity

Keep the XP mechanisms distinct:

- C/C++: `CFLAGS/CXXFLAGS += -DMOZ_XP_COMPAT`;
- Rust: `RUSTFLAGS="--cfg moz_xp_compat"`;
- neither implies `CONFIG["MOZ_XP_COMPAT"]` in `moz.build`.

# Current acceptance / next boundary

For the clean release line, no evidence currently overturns the proven physical XP lifecycle of `586fe5f8...`. The newer `85863f23...` release candidate is GREEN through build/package/static gates, but the physical binaries previously assumed to belong to it are now identified as a different WebRTC/GOST implementation lineage. Immediate clean-product acceptance boundary remains physical execution of the exact `10700255591` / `10700395290` release payload with matching hashes.

For the implementation XP line, the download/recent-documents blocker remains physically closed on artifact-correlated source `e13354c...`. Source `3119c849...` physically advances past the former ANGLE trace-category `libGLESv2+0x3C1CA` crash but reaches a second TLS-backed local-static failure at `libGLESv2+0x159EBB` in `GenerateCaps -> GetAllSizedInternalFormats`. The ANGLE product remediation remains `b01f3461...` (`/Zc:threadSafeInit-` plus restored normal trace static). Focused run `35974426502 / 107551429542` proves both known owner objects contain zero `_Init_thread_header/footer/epoch` matches and passes the focused `libGLESv2.dll` binary gate. Full run `35980235042 / 107570122638` is completed / success / GREEN on `f15a047e...`, and physical console XP reaches artifact-correlated WebGL context creation and rendering on that package output. The later telemetry A/B source `27f4271...` also has completed / success / GREEN full-build evidence from run `36164782271 / 108169777457`, with package `10883654763`, runtime `10883894624`, and diagnostics `10884079570`. Exact binaries from that package are independently hash-correlated and ordinary RDP startup/profile/policy/browsing/shutdown remains a physical lifecycle PASS. Contradictory graphics-triggered evidence now narrows that acceptance: after opening the WebGL test page and then closing the browser, the exact new-build GPU child again produces `0x80000007 / STATUS_WAKE_SYSTEM_DEBUGGER`. Matching `xul.pdb` no longer shows the predecessor `GetGpuTimeSinceProcessStartInMs -> RecordPowerMetrics -> FlushFOGData` / `LoadLibraryW` path; instead the exception-thread Firefox frame is in `mozilla::widget::WinUtils::WaitForMessage()`, with the upper stack in the ordinary GPU child app/message loop. Exact disassembly shows the return site follows `USER32!MsgWaitForMultipleObjectsEx`; Watson's `GetLastInputInfo+...` export label is not the actual imported call. Therefore the pre-Vista D3DKMT guard is retained as a successful boundary advancement, but graphics-triggered GPU-child teardown remains open and no new root-cause owner is proven. The predecessor `f15a...` console test remains the latest accepted WebGL rendering evidence; console WebGL on `27f4271...` is still pending.

A later live WinDbg reproduction on the exact artifact-correlated `27f4271...` payload materially advances the graphics-triggered teardown boundary. Matching `libGLESv2.pdb` captures an unhandled second-chance `0xC0000005` in `libGLESv2!DllMain` with `fdwReason=DLL_THREAD_DETACH`. The faulting path is `egl::DeallocateCurrentThread() -> SafeDelete(gCurrentThread)`; the module TLS slot is present, while `thread_local gCurrentThread` is NONNULL but invalid for the observed read dereference. Debugger-derived numeric pointer/memory content is withheld from the public record. The same DLL contains YY-Thunks TLS-remediation state, yet runtime shows `g_TlsMode=None`, and independent PE inspection proves its entry point maps to ordinary `_DllMainCRTStartup` rather than `DllMainCRTStartupForYY_Thunks`.

This establishes a specific current owner for the captured AV: the Windows XP static-TLS lifecycle contract of dynamically loaded `libGLESv2.dll`. It does not retroactively prove that every earlier `0x80000007` capture had the same initiating event. Narrow remediation is committed at `482bc441...` by applying the already-used xul YY DLL entry-point contract only to Windows x86 `libGLESv2`; implementation HEAD `ad96945f...` additionally makes source verification and final packaged-runtime `contract=true` verification blocking. CI and physical runtime acceptance for this remediation are still pending.

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