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

### GPU process — WebGL rendering reached; Glean GPU-time telemetry boundary open

Exact source `3119c849b3930145c8e4181b8a06a692ec20514d`, run `35860139917`, job `107178068460`, runtime artifact `10759971452` has now been physically tested on Windows XP with matching `r3dfox.exe`, `xul.dll`, and `libGLESv2.dll` hashes.

The narrow trace-cache fix advances past predecessor fault `libGLESv2+0x0003C1CA`, but WebGL reaches a new `0xC0000005` at `libGLESv2+0x00159EBB`. Matching PDB resolves the new boundary to `rx::d3d9_gl::GenerateCaps()` / `std::_Tree::begin()` at `renderer9_utils.cpp:517`, after `gl::GetAllSizedInternalFormats()` returns an unconstructed/invalid local-static `FormatSet`. Exact-DLL disassembly shows the second MSVC TLS-backed thread-safe-local-static guard and matching `_Init_thread_header` / `_Init_thread_footer`.

Current browser/ANGLE remediation commit: `b01f3461d52eec1b60aa87d12e083f3485032fba`. Current implementation/CI source-under-test for the dispatched full build: `f15a047e847cdca07d90396fe88d32a74cee416e`.

- `5934345e6c6e805a703efc1cc425b6aebfe8c0a4`: apply `/Zc:threadSafeInit-` to Windows x86 ANGLE;
- `b01f3461...`: restore the normal trace-event static cache so the build flag covers both reproduced sites.

Focused run `35974426502`, job `107551429542`, product source `b01f3461...`, is GREEN. It proves both known owner translation units compile with `/Zc:threadSafeInit-` and both resulting objects have `Init_thread_matches=0`. Focused `libGLESv2.dll` static inspection also passes.

The full XP workflow contains the corresponding blocking gate after `mach build`; implementation HEAD is `f15a047e...`. Full run `35980235042`, job `107570122638`, is completed / success / GREEN. Package artifact `10806218628`, runtime artifact `10806283395`, and diagnostics artifact `10806562241` were published. The full-build verifier reports zero `_Init_thread_*` matches in both known owner objects.

Current physical result:

- console-session XP test on SourceStamp `f15a047e...` reaches artifact-correlated WebGL context creation and visible rendering;
- `about:support` confirms Software WebRender compositor fallback, an active GPU process, and WebGL available as a separate feature decision;
- two independent `0x80000007 / STATUS_WAKE_SYSTEM_DEBUGGER` captures converge on `gfxWindowsPlatform::GetGpuTimeSinceProcessStartInMs() -> glean::RecordPowerMetrics() -> glean::FlushFOGData()`, with the native stack entering `LoadLibraryW` / mozglue loader handling;
- one capture occurs during ordinary FOG IPC flushing and the newer capture occurs on browser shutdown through GPU `FlushFOGData`, so the recurring symptom is no longer assigned to ANGLE rendering.

Artifact correlation is complete: the physically tested `r3dfox.exe`, `xul.dll`, and final packaged `libGLESv2.dll` match package artifact `10806218628` byte-for-byte.

The narrow telemetry A/B is implemented at `agent/winrt-source-poc @ 27f4271bddc228f21d64370a3781ba35a92a96e0`: `gfxWindowsPlatform::GetGpuTimeSinceProcessStartInMs()` returns `NS_ERROR_NOT_AVAILABLE` on pre-Vista Windows before `LoadLibrary(L"gdi32.dll")`, without changing ANGLE/WebGL/D3D9 code. Full XP x32 run `36164782271`, job `108169777457`, is **completed / success / GREEN** against that exact source. Published artifacts: package `10883654763`, runtime `10883894624`, diagnostics `10884079570`.

The remaining acceptance sequence is:

1. Test the exact new payload on physical XP: repeat an active WebGL rendering session and then normal browser shutdown.
2. Correlate the physically exercised binaries to the named package/runtime artifact before promoting the runtime result.
3. If `0x80000007` still occurs, symbolize the new exact capture against matching PDBs before any broader workaround. Procmon remains secondary unless the evidence moves to an external DLL/file/registry/driver-loading boundary.
4. Do not reuse predecessor ANGLE RVAs `+0x3C1CA` or `+0x159EBB` as breakpoints for this telemetry/shutdown line and do not reopen the already-closed local-static hypothesis without contradictory evidence.


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