# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog. Current synthesis is in `PROJECT_STATE.md`; current Windows XP WebRTC runtime/codec status is in [WEBRTC_XP_STATUS.md](WEBRTC_XP_STATUS.md); exact runtime test sequencing/recovery is in `STAGE2_RUNTIME_TEST_PLAN.md`; GIS GMP multi-host mTLS work is in `STAGE2_GIS_GMP.md`; Windows XP architecture/import triage is in `XP_COMPATIBILITY_STRATEGY.md`; the mandatory XP x86 build/dependency contract is in `XP_BUILD_CONTRACT.md`; experiment evidence is in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes.

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

The source remediation is build- and runtime-proven on exact source `e13354c79ebfa206fbccc946592256d33e4ac519`, workflow `GOST TLS PoC build  XP x32`, run `35810132801`, job `107019631325`, **completed / success / GREEN**. Canonical artifacts are package `10733487295`, runtime `10733956483`, and diagnostics `10733113244`.

The source contains both the XP-only fallback away from `SHELL32!SHCreateItemFromParsingName` and a core-browser import regression gate for that symbol. The targeted core-browser import gate and the broad XP PE/direct-import audit both passed in this run.

Physical Windows XP validation of the exact successor runtime also passed with `browser.download.manager.addToRecentDocs=true`: an ordinary user download completed without error or browser crash. User-recorded SHA-1 identities are `r3dfox.exe=3f4f98bb9ad710bda5c72fa25d1e124d37c211b4` and `xul.dll=17ee19d4a947466b25d95089a967f7d055261c2b`; both match the binaries independently extracted from runtime artifact `10733956483`.

The predecessor `0xC06D007F` / `SHELL32!SHCreateItemFromParsingName` boundary is therefore physically closed for this exact artifact-correlated source/run. `browser.download.manager.addToRecentDocs=false` is only a temporary workaround for older affected binaries and is not needed for the accepted successor.

## XP WebRTC

The initial WebRTC-enabled source `75b4e8f052fb6fc09c723651938fde18f95af4ea` built/package GREEN but physically failed at the XP loader because `xul.dll` directly imported unavailable `WS2_32!inet_pton` from nICEr.

Source `afee8c9e5ad2da729407ae06cda8d8029895ab06` uses an XP-only local copy of the proven IPv4/IPv6 parser in the Windows nICEr port while non-XP retains native `inet_pton`. Its full build, run `35737946733`, job `106779925555`, completed **success / GREEN** with package `10707883013`, runtime `10707967905`, and diagnostics `10707868191`. Physical Windows XP startup also advances past the old boundary: the browser starts and the missing-entry-point dialog for `WS2_32!inet_pton` no longer appears. User-reported local hashes are `r3dfox.exe=b1e38de25a5212a54833ddcd4ca830318a10467c` and `xul.dll=266b8baea04e92d301fb6ffdd5ad87f492c398eb`.

The loader blocker is therefore closed for that exact source/user-associated build. The later hardened regression rule added by `1ba6150ca58ea9da341f53374f9bf5dc8d0a4366` is now also build-proven on successor source `e13354c79ebfa206fbccc946592256d33e4ac519`: run `35810132801`, job `107019631325` completed GREEN with both the targeted core-browser import gate and the broad XP PE/direct-import audit successful.

Remaining functional WebRTC acceptance sequence:

- verify JavaScript surface presence: `typeof RTCPeerConnection` and `typeof navigator.mediaDevices?.getUserMedia`;
- exercise an RTCDataChannel sample;
- exercise `getUserMedia` on XP;
- exercise a same-host/sample PeerConnection path such as `pc1`;
- exercise ICE/STUN candidate gathering and connectivity;
- later exercise a real call; H.264 is not an initial acceptance criterion;
- only after functional WebRTC runtime acceptance, deduplicate the copied parser into a neutral Windows compatibility helper shared by libwebrtc and nICEr without introducing an unwanted direct nICEr-to-libwebrtc build dependency.

Do not reinterpret physical browser startup or a clean import gate as WebRTC functional PASS.

## Focused YY/static-TLS line — deferred unless needed

Current focused physical evidence remains source `1a61565dd3442d817893c52d473365442e24ba6c`, run `35495864771`, job `106038556671`, artifact `10600581430`: `owner-first` PASS, `late-first` teardown HANG.

If resumed, add narrow non-CRT boundary markers around owner detach, late callback and YY TLS cleanup. Do not broaden YY-Thunks from inference. The browser has already achieved sustained physical XP lifecycle PASS on later exact packages, so this is forensic/deferred work rather than an immediate browser-launch blocker.

## Deferred XP cleanup / component work

- **Supermium private DWrite refresh:** keep the physically proven 132 component as the browser-integration control while testing newer component generations separately. Do not replace the full-browser pin merely because a newer release exists.
- **Battery observer simplification:** after current runtime work stabilizes, re-audit `BatteryInformation` consumers and consider an XP-only permanent-external-power/charging stub if it is source-compatible. Do not change it during unrelated blocker work.
- **`ncrypt.dll`:** do not preemptively remediate. If an exact XP artifact reaches a real NCRYPT boundary, prefer source-level selection of Firefox's legacy CryptoAPI backend under the project-owned Rust XP cfg; use a narrow provider/thunk only if source removal is proven insufficient.

## Closed XP families — do not reopen without contradictory exact evidence

Do not spend new cycles on already closed/advanced-past families merely because a similar symbol appears elsewhere. This includes the SharedPrefMap inherited-HANDLE boundary, the battery `RegisterPowerSettingNotification` boundary, `NtCancelIoFileEx`, the ADVAPI32 ETW family, direct ANGLE `CreateDXGIFactory1`, the accepted private DWrite component contract, the failed-`LdrLoadDll` output bug after its narrow correction, the temporary early `pwrp_k32.dll` preload, the XP legacy file-picker blocker, the nICEr direct `WS2_32!inet_pton` startup blocker on source `afee8c9e...`, and the download-completion `SHELL32!SHCreateItemFromParsingName` blocker closed on artifact-correlated source `e13354c...`.

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
