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

## Immediate clean-product acceptance task — run the exact release payload

Release candidate build/static identity:

- product source `win-153-xp @ 85863f2355a23223bf33f55b641ccb509a2b72ac`;
- workflow `XP release build x32`;
- run `35724604122`, job `106735182867`, **completed / success / GREEN**;
- package artifact `10700255591`;
- runtime artifact `10700395290`;
- diagnostics artifact `10700061102`.

The 2026-09-23 physical XP Page Info / certificate / ordinary NSS HTTPS smoke passed for exact local SHA-1 identities:

- `r3dfox.exe=b1e38de25a5212a54833ddcd4ca830318a10467c`;
- `xul.dll=266b8baea04e92d301fb6ffdd5ad87f492c398eb`.

That local pair is now user-identified as the WebRTC/GOST implementation build from run `35737946733`, job `106779925555`, source `afee8c9e5ad2da729407ae06cda8d8029895ab06`, not the clean release run above. The authoritative release package/runtime payloads instead contain:

- `r3dfox.exe=adc00ebb4cee4bc9fdd611016433827a695c93a0`;
- `xul.dll=b7806d06aecdb47b83482666d3a7d59dcd8c5c6a`.

Therefore the release-line provenance ambiguity is resolved: the earlier physical smoke does not validate `85863f23...`. The remaining clean-product acceptance task is now singular and concrete: extract directly from artifact `10700255591` or `10700395290`, verify the expected release hashes before launch, and perform the short physical XP regression smoke.

Until that is done, retain `win-153-xp @ 586fe5f856971a790db6e3529bdb0ac7a6133872`, run `35697342392`, job `106647034214`, package `10685004306` as the last artifact-correlated clean-product physical lifecycle baseline.

Detailed release evidence: `TEST_LOG_2026-09-23_release_runtime_smoke.md`.

## Active XP implementation work

`agent/winrt-source-poc` is allowed to move ahead of the clean release baseline. Its HEAD is not a runtime baseline merely because it contains later fixes/tests. Before every physical claim, bind the exact source-under-test, run/job, artifact and local binary hashes.

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

- Run the next full XP x32 build from implementation candidate `8bb4ef8fed2362030a27e67058be87e12be61bba` and inspect the new D3DCompiler gates: unchanged build-produced `d3dcompiler_47.dll`, exact pinned `d3dcompiler_old.dll`, no PE retarget of either vendor DLL, no required XP PE hard-import of `_47`, final portable-package identity checks, and `vs_3_0` + `ps_3_0` compile probes. If static/package gates pass, perform exact-package physical XP WebGL + graphics-triggered clean shutdown and a Windows 10 regression check.
