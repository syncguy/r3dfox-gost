# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog. Current synthesis is in `PROJECT_STATE.md`; [WEBRTC_XP_STATUS.md](WEBRTC_XP_STATUS.md) is the single source of truth for all Windows XP WebRTC build/runtime/codec/ICE/NAT status and remaining WebRTC boundaries; exact runtime test sequencing/recovery is in `STAGE2_RUNTIME_TEST_PLAN.md`; GIS GMP multi-host mTLS work is in `STAGE2_GIS_GMP.md`; Windows XP architecture/import triage is in `XP_COMPATIBILITY_STRATEGY.md`; the mandatory XP x86 build/dependency contract is in `XP_BUILD_CONTRACT.md`; experiment evidence is in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes.

## GOST TLS runtime — immediate

Already closed as experiments and not to be repeated on unchanged source merely for confirmation: F1 close/shutdown lifecycle, F2 positive `Once` fanout/scope, F3 generic GOST mTLS host scope, GIS-G4 cross-host decision isolation, explicit positive `Session` lifetime, SD1-SD6 Session-default exact-artifact regression, T3 explicit Cancel/no-certificate semantics, T4 involuntary tab/load Abort semantics, T7/T8 missing-medium/provider recovery, T9 long-provider-wait characterization, and T10 detailed Russian picker presentation.

Current open work:

1. **T6 — real Permanent semantics.** Implement persistence distinct from the process-local non-Once store. Prove process-restart persistence plus intended forget/change behavior.
2. **T11/T12 — discovery boundary.** Verify dynamic `CurrentUser\\MY` re-enumeration and determine whether provider/removable-media-only identities become discoverable without browser restart or unwanted provider/PIN/media UI during candidate enumeration.
3. **T5 — deterministic failure-boundary regression, deferred.** Resume only when an already-acquired provider/private-key credential can be invalidated safely inside the same browser process. Removing the medium after a successful Session acquisition is not a valid fault injection because CryptoPro/SSPI may retain the acquired credential context.
4. **Provider-wait Socket Thread isolation.** T9 established a synchronous provider/key-access wait of about 74.742 s during which the Firefox UI remained responsive but unrelated network work queued behind the shared Socket Thread. Compare with stock Firefox client-certificate/token behavior and only then evaluate a focused off-thread MSSPI/CryptoPro experiment that preserves NSPR/MSSPI ownership, cancellation and proxy/CONNECT sequencing.
5. **Remaining client-auth matrix.** Cover no acceptable certificate, unsuitable/wrong certificate, unavailable key, private-key/PIN failure, server rejection, issuer-aware validity/KU/EKU/private-key policy, sensitive-log audit, and final exact-build Treasury mTLS regression.

## GOST TLS security — mandatory Stage 2 server-trust closure

Complete and prove fail-closed server verification:

- reject `verifyOk == 0`;
- reject every nonzero verification failure status;
- integrate Firefox temporary/permanent certificate overrides without bypassing normal trust semantics;
- positive browser-session verification cache keyed by exact server identity;
- valid Treasury hostname/chain succeeds;
- wrong hostname fails;
- invalid/untrusted chain fails;
- client private-key operations cannot occur before server trust succeeds.

Do not use a production verification bypass.

## GOST network coverage — after trust/runtime closure

- direct connection without proxy;
- HTTPS proxy / nested TLS;
- SOCKS lifecycle;
- additional proxy authentication/reconnect edge cases beyond the already exercised HTTP CONNECT path.

## GOST UX — later

After core TLS behavior is stable, evaluate transparent one-shot discovery only under a strict design: explicit allowlist still enters MSSPI immediately; unknown host starts with NSS; only `SSL_ERROR_NO_CYPHER_OVERLAP` may authorize one MSSPI retry; no retry loops; only normally verified GOST success becomes session-confirmed; discovery never bypasses trust or client-auth policy.

# Windows XP compatibility — independent

## Clean-product acceptance

The consolidated clean release `win-153-xp@42bfe890d9f508c9e9ce677acf8ecf03ea666626`, run `36560808861 / 109380950857`, package `11039397943`, has completed its current physical Windows XP acceptance: artifact correlation, startup/live browsing, WebGL1 with the packaged legacy compiler fallback, graphics-triggered normal shutdown with complete process exit, and restart all PASS. The completed milestone is recorded in `DONE.md` and detailed evidence is in `TEST_LOG.md`.

No immediate clean-product lifecycle acceptance task remains. Add new work here only for a newly observed regression, a deliberately expanded feature-acceptance matrix, or a later release candidate; do not re-run the closed checks on unchanged source without contradictory evidence.

## Active XP implementation work

`agent/winrt-source-poc` is allowed to move ahead of the clean release baseline. Its HEAD is not a runtime baseline merely because it contains later fixes/tests. Before every physical claim, bind the exact source-under-test, run/job, artifact and local binary hashes.

### XP memory-pressure / native TabUnloader policy — open

Focused analysis is in [XP_MEMORY_PRESSURE_STATUS.md](XP_MEMORY_PRESSURE_STATUS.md). The r3dfox WIP memory watcher polls `GlobalMemoryStatusEx()` on a repeating-slack timer with a 5000 ms default and treats available commit below 200 MB **or** available physical RAM below 2048 MB as low memory. The accepted product default keeps `browser.tabs.unloadOnLowMemory=false`, but source analysis proves that this does not make the watcher inert: rejected unload attempts request global low-memory pressure.

Important qualification: `nsMemoryPressure.cpp` delivers the first request in an episode as `memory-pressure / low-memory`, later delivered requests as `low-memory-ongoing`, and recovery as `memory-pressure-stop`. Main JS and worker GC/CC explicitly skip ongoing pressure, while verified image/network memory-cache consumers still react to every delivered `memory-pressure`. The open question is therefore the physical cost of prolonged ongoing-pressure cache/observer/IPC activity on the 2 GB XP target, not "full GC/CC every five seconds".

Next sequence:

1. On the exact accepted physical XP package, run a controlled **A -> B -> A** with automatic tab unloading disabled throughout.
2. A1: physical threshold 2048 MB, commit 200 MB, poll 5000 ms. B: change only `browser.low_physical_memory_threshold_mb=512`, full restart. A2: restore 2048 MB and restart again.
3. Keep B interpretable: available physical memory must remain >=512 MB and commit headroom >=200 MB during the measurement, otherwise continued pressure is expected from another branch of the predicate.
4. Record separately delivered `low-memory`, `low-memory-ongoing`, and `memory-pressure-stop`; available physical/commit headroom; browser-process CPU time and one repeatable UI-latency measure; and `TabBrowserDiscarded` count (expected zero). Use GC/CC reasons/durations and disk activity if already convenient. Do not use `LowPhysicalMemoryEvents` as the ongoing-event counter.
5. Do not manually invoke `about:unloads` Unload or "Minimize memory usage" during this trigger A/B.
6. Only after trigger cost is understood, enable native `browser.tabs.unloadOnLowMemory` with the corrected diagnostic threshold and measure actual reclamation/process exit on eligible >10-minute inactive tabs.
7. Preserve process-aware TabUnloader ranking and native `discardBrowser()` unless contrary evidence appears. Its Windows process-memory metric is `PROCESS_MEMORY_COUNTERS_EX::PrivateUsage`, and its candidate process map has known heuristic limitations; neither is yet a demonstrated blocker.
8. If the A/B shows a reproducible benefit, prefer a narrow XP-specific fixed threshold as the first product experiment. Consider RAM-relative bounds/hysteresis only if multiple low-RAM classes require it; event-driven Windows notification remains a later architectural option.
9. Separately review the selected-background-window recovery path: fresh selected tabs can outlive the normal age filter and recovery selection currently occurs before final discard success.

Do not attribute earlier XP slowness to this mechanism until the physical A/B proves a material effect.

### Download completion / Recent Documents — closed

Closed on artifact-correlated source `e13354c...`, run `35810132801 / 107019631325`. See [DONE.md](DONE.md) for the compact closure and [TEST_LOG.md](TEST_LOG.md) for detailed evidence.

### GPU process — libGLESv2 XP static-TLS detach remediation awaiting build/runtime acceptance

Exact artifact-correlated source `27f4271bddc228f21d64370a3781ba35a92a96e0`, run `36164782271`, job `108169777457`, package `10883654763`, diagnostics `10884079570` now has a stronger live-debug boundary than the earlier Watson-only `0x80000007` capture.

WinDbg with child-process debugging and matching `libGLESv2.pdb` caught an unhandled second-chance `0xC0000005` in `libGLESv2!DllMain` with `fdwReason=DLL_THREAD_DETACH`. The owner path is `egl::DeallocateCurrentThread() -> SafeDelete(gCurrentThread)`; `thread_local gCurrentThread` is NONNULL but invalid for the observed read dereference. YY-Thunks TLS-remediation state is linked into the DLL, runtime shows symbolic mode `g_TlsMode=None`, and exact PE inspection maps the DLL entry point to ordinary `_DllMainCRTStartup`, not the YY TLS-aware wrapper. Debugger-derived numeric pointer/memory content is withheld from the public record.

Narrow remediation is committed on `agent/winrt-source-poc`:

- `482bc4417601fc96f2ab135f377f64e03945cd27`: Windows x86 `libGLESv2` uses `DllMainCRTStartupForYY_Thunks` with the same original-CRT alternate contract already used for xul;
- `e8bb142248ccbf03b24f6a7a8cddf510ef54986e`: source gate covers xul + libGLESv2 contracts;
- `3bb7c0d17112b0ec65cb144f5291ee03431c1550`: final packaged-runtime libGLESv2 contract gate;
- `ad96945f101cedc25b9ed40df25bbed25c045833`: final aggregate treats that gate as blocking.

Focused preflight is complete: corrected run `36257921234`, job `108448117969`, exact product source `ad96945f101cedc25b9ed40df25bbed25c045833`, is completed/success. The focused link resolves the YY TLS-aware entry point through the proven narrow provider; codegen and focused binary inspection pass. Failed predecessor run `36255787912 / 108442196461` is an infrastructure failure from the missing YY provider in the short workflow.

Remaining sequence:

1. New presentation-fallback candidate is now fully built: source `705470c0f1fd7302669b1f4d4c9aead33b773928`, run `36325907730`, job `108638512476`, completed/success. Package `10936509397`, runtime `10937007948`, and diagnostics `10936509452` are the current CI artifacts. All blocking build/package/static gates passed.
2. Windows 10 control A/B is now artifact-correlated: with ANGLE D3D9Ex, the exact package from run `36325907730` visibly renders the `get.webgl.org` rotating cube instead of losing the context at `Swap chain surface creation failed.`. User SHA-1 values for `r3dfox.exe`, `xul.dll`, and `libGLESv2.dll` match the corresponding files from package artifact `10936509397` exactly.
3. Physical Windows XP has now proven the `SurfaceFactory_Basic` route and the first failing allocation boundary: `MozFramebuffer::CreateImpl(size:140x150, samples:0, depthAndStencil:false, colorTarget=GL_TEXTURE_2D, colorName=0)` with framebuffer status `0x0`. Before another source workaround, run a low-cost A/B with `webgl.use-canvas-render-thread=false` and a full browser restart. If unchanged, instrument `MozFramebuffer::Create()` / `GLContext::MakeCurrent()` to record actual-current state and generated object names; investigate context-current/thread ownership rather than the already-correct D3D11-to-Basic factory fallback.
4. Legacy D3D compiler A/B is now PASS and clean-config confirmed: adding Firefox 52.9.0's `D3DCompiler_43.dll` as `D3DCompiler_old.dll` makes the exact XP browser render the rotating WebGL cube, and the result persists after all diagnostic `webgl.*` prefs are restored to defaults. Next product work is to package/provision this XP-compatible fallback reproducibly and legally for the XP build, preserving ANGLE's existing fallback name/logic rather than replacing the modern compiler globally.
5. RDP may be tested as a separate capability path. Control WebGL feature policy explicitly (`webgl.disabled=false`, and when needed `webgl.ignore-blocklist=true` / `webgl.force-enabled=true`) so an RDP gfx blocklist decision is not confused with the presentation-fallback result. If RDP still cannot create WebGL, record that as a feature-selection boundary rather than reopening the swap-chain defect.
6. Audit the current final-runtime YY DLL inventory before changing any additional DLL. Distinguish real compiler TLS / PE TLS / load-lifecycle requirements from resolver-only false positives; do not apply the YY entry point globally.
7. Preserve the established `/Zc:threadSafeInit-` ANGLE remediation and pre-Vista D3DKMT guard. Do not reopen predecessor local-static or telemetry blockers without contradictory exact-build evidence.
8. Keep earlier `0x80000007` captures as historical top-level symptoms; do not claim they were all caused by the detach AV unless new first-chance evidence proves that linkage.


## XP WebRTC

[WEBRTC_XP_STATUS.md](WEBRTC_XP_STATUS.md) is the single source of truth for Windows XP WebRTC build identity, runtime evidence, codec/media/ICE/NAT coverage, closed blockers, and remaining WebRTC work. Do not duplicate or maintain WebRTC status in `TODO.md`; update that document directly.

## Focused YY/static-TLS line — deferred unless needed

Current focused physical evidence remains source `1a61565dd3442d817893c52d473365442e24ba6c`, run `35495864771`, job `106038556671`, artifact `10600581430`: `owner-first` PASS, `late-first` teardown HANG.

If resumed, add narrow non-CRT boundary markers around owner detach, late callback and YY TLS cleanup. Do not broaden YY-Thunks from inference. The browser has already achieved sustained physical XP lifecycle PASS on later exact packages, so this is forensic/deferred work rather than an immediate browser-launch blocker.

## Deferred XP cleanup / component work

- **Supermium private DWrite refresh:** keep the physically proven 132 component as the browser-integration control while testing newer component generations separately. Do not replace the full-browser pin merely because a newer release exists.
- **Battery observer simplification:** after current runtime work stabilizes, re-audit `BatteryInformation` consumers and consider an XP-only permanent-external-power/charging stub if it is source-compatible. Do not change it during unrelated blocker work.
- **`ncrypt.dll`:** do not preemptively remediate. If an exact XP artifact reaches a real NCRYPT boundary, prefer source-level selection of Firefox's legacy CryptoAPI backend under the project-owned Rust XP cfg; use a narrow provider/thunk only if source removal is proven insufficient.

## Closed XP families — do not reopen without contradictory exact evidence

Do not spend new cycles on already closed/advanced-past non-WebRTC families merely because a similar symbol appears elsewhere. This includes the SharedPrefMap inherited-HANDLE boundary, the battery `RegisterPowerSettingNotification` boundary, `NtCancelIoFileEx`, the ADVAPI32 ETW family, direct ANGLE `CreateDXGIFactory1`, the accepted private DWrite component contract, the failed-`LdrLoadDll` output bug after its narrow correction, the temporary early `pwrp_k32.dll` preload, the XP legacy file-picker blocker, and the download-completion `SHELL32!SHCreateItemFromParsingName` blocker closed on artifact-correlated source `e13354c...`. WebRTC-specific blocker state is maintained only in [WEBRTC_XP_STATUS.md](WEBRTC_XP_STATUS.md).

# Packaging / localization

The reproduced stock-Russian-langpack Page Info/WebGL failure is closed by the source-owned Fluent fallback. Preserve the fallback when rebasing/transferring release-product changes and keep packaging proof independent from physical runtime and GOST TLS proof.

# Evidence discipline for every remaining task

- Build success != physical runtime PASS.
- Physical runtime PASS != GOST handshake PASS.
- Static PE/import PASS != runtime PASS.
- Keep workflow/control SHA separate from product source-under-test SHA.
- Do not call an in-progress run GREEN.
- Match runtime binaries/PDBs to the exact artifact before using crash or PASS evidence.
- Prefer source-level fallback, then correct build configuration, then legacy Windows API path, then a narrow provider/thunk; broad workarounds are last resort.

- Exact-source full run `36448769364 / 109017796850` on `94ff24222ce2b05c2f89185778f062120a332881` is **success / GREEN**, and package artifact `10990972577` now has artifact-correlated physical Windows XP startup/session PASS, **physical WebGL1 PASS**, **HTTP User-Agent PASS without `general.useragent.override`**, **JS-visible web-identity PASS**, and **graphics-triggered clean shutdown PASS**. A direct console probe also confirms `webgl1: true`, `webgl2: false`; source inspection ties WebGL2 failure (`FEATURE_FAILURE_EGL_NO_CONFIG`) to the accepted ANGLE D3D9 backend's hard ES 2.0 cap. Treat WebGL2-on-XP as a separate future graphics-backend/architecture task, not as an open blocker for this accepted WebGL1 path. No error dialogs were observed during the morning session. The focused XP runtime acceptance set for this exact package is complete; future work should move to new blockers/regressions or the separate GOST TLS line rather than re-opening these closed checks without contrary evidence.


### Standalone bcrypt browser integration

- COMPLETE: `gost-poc-build-xp-x32.yml` run `36956985064 / 110682033011` on `agent/winrt-source-poc@56ea4129e318e3565dfdd81d0bf60a8735961976` completed SUCCESS with exact standalone `syncguy/bcrypt@v0.1.0-alpha.1` DLL SHA-256 `47182ec8...` staged and preserved in the final package.
- Require CI staging/package gates to prove the standalone DLL survives into the final browser package unchanged.
- After GREEN build, physically run the exact produced browser package on Windows XP SP3 x86 before declaring browser integration PASS.
- Do not rebuild the standalone bcrypt project unless contradictory evidence appears; the browser integration test consumes the already accepted published DLL.


- COMPLETE: clean release standalone bcrypt integration is closed. `XP release build x32` run `36961506702 / 110696007845` on product source `win-153-xp@42bfe890d9f508c9e9ce677acf8ecf03ea666626` completed SUCCESS, preserved standalone bcrypt SHA-256 `47182ec8...`, and the exact package artifact `11212035828` was physically run on Windows XP with matching `r3dfox.exe`, `xul.dll`, and `bcrypt.dll` identities.
