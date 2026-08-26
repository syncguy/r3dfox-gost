# r3dfox GOST TLS — Project State

Last updated: 2026-08-26

This file is the current technical synthesis for the GOST TLS fork. Current experiment evidence is recorded in [`TEST_LOG.md`](./TEST_LOG.md). Historical experiment evidence through 2026-08-24 is preserved in [`TEST_LOG_2026-08-22_2026-08-24.md`](./TEST_LOG_2026-08-22_2026-08-24.md), with earlier 2026-08-25 evidence preserved in [`TEST_LOG_2026-08-25_2026-08-25.md`](./TEST_LOG_2026-08-25_2026-08-25.md). For workflow roles, see [`WORKFLOWS.md`](./WORKFLOWS.md).

## Repository and branches

- Repository: `syncguy/r3dfox-gost`.
- Default / active development branch: `agent/gost-tls-poc`.
- Frozen baseline: `win-153` at `0d023eb0e3517dea36f2f134a9a25f872611c688` when protection was configured.
- `win-153` is protected with restricted updates, restricted deletion, and blocked force-pushes. Fork syncing is disabled for that ruleset.
- PR #1 historically has base `win-153`; that does **not** make `win-153` the active development branch.

## Version policy

The project is based on `Eclipse-Community/r3dfox`, whose maintained/default line is still `win-153` as of 2026-08-24. Mozilla Firefox upstream having moved to 154 is not by itself a reason to retarget this fork. Continue on the current r3dfox 153 base, monitor `Eclipse-Community/r3dfox` for a newer maintained baseline, and evaluate any base migration only after r3dfox itself publishes such a line and the user explicitly decides to upgrade.

## Project objective

Add GOST TLS support to r3dfox while preserving the browser's normal TLS path.

Design intent:

- normal HTTPS continues through Firefox NSS;
- only allowlisted hosts are redirected to a GOST-capable TLS transport backed by `deemru/msspi` and Windows SSPI/CryptoPro;
- the first phase remains constrained to Windows, TLS 1.2, HTTP/1.1, and server authentication while transport and handshake behavior are stabilized.

The primary runtime test host is `fzs.roskazna.ru`. Treasury client-certificate login additionally uses `lk-fzs.roskazna.ru`.

## GOST TLS runtime track

### Architecture

The PoC adds a parallel TLS path around the normal NSS socket path for explicitly selected hosts.

Important pieces include:

- host allowlist selected by `R3DFOX_GOST_HOSTS`;
- `GostTLSService` / socket-provider routing;
- `GostSocketControl` implementing the TLS socket-control surface expected by Necko;
- `nsGostSSLIOLayer.cpp`, which pushes a custom NSPR I/O layer;
- MSSPI callbacks that read/write through the actual lower NSPR transport;
- Windows SSPI/CryptoPro performing TLS/GOST handshake and record protection.

Ordinary non-allowlisted HTTPS must remain on NSS.

For an ordinary HTTP proxy, Firefox/Necko owns proxy resolution, CONNECT generation, proxy authentication, response parsing, and retry behavior. The GOST layer remains plaintext-transparent until Necko reports a successful tunnel by calling `nsITLSSocketControl::ProxyStartSSL()`. Only then does MSSPI start the origin TLS handshake inside the established CONNECT tunnel.

### MSSPI baseline

Pinned MSSPI source commit:

`f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`

The Firefox wrapper configures the client with the equivalent of:

- `msspi_set_client`;
- TLS 1.2 via `msspi_set_version(..., 0x0303)`;
- `msspi_set_hostname`;
- `msspi_set_peerauth`.

Starting with commit `850a2e54aa154c025a9af35ed351c92dfe96a3d1`, the default diagnostic GOST mode also calls `msspi_set_cipherlist` with:

`C100:C101:C102:FF85:0081`

`R3DFOX_GOST_CIPHERS=default` skips that explicit call and reproduces the MSSPI native cipher-list behavior. Any other non-empty value is passed as a custom explicit list.

The successful proxy-compatible A/B runtime test at commit `4887e07d...` shows that both the explicit GOST-only list and the MSSPI native-default list complete a GOST TLS 1.2 handshake with `fzs.roskazna.ru`; both negotiate suite `0xFF85`. Therefore the explicit list is not required for this server to succeed, although it remains useful as a policy control to keep the allowlisted path deterministic and GOST-only.

### Confirmed runtime behavior

The earlier `caa420c25bcc2693137666b625e62a1b58fdcb0f` transport fix remains valid: the pushed GOST layer has a stable lower NSPR transport, nonblocking would-block handling works, and MSSPI exchanges bytes through that lower socket.

The A/B capture from run `32692411195` established that the old `SEC_E_INVALID_TOKEN` was caused by starting MSSPI before the HTTP CONNECT tunnel existed. The roughly 1038/1039 bytes previously treated as a possible server handshake were actually plaintext `HTTP/1.1 400 Bad Request` from ASUGATE. That interpretation is superseded by the proxy-compatible runs below.

### First complete GOST HTTPS success

Authoritative main build:

- workflow: `GOST TLS PoC build`;
- Actions run: `32710363486`;
- job: `97380247020`;
- exact build commit: `4887e07d847b1c3c2e13b491dcc85f50ddaa9804` (`fix(gost): defer MSSPI until proxy tunnel`);
- CI result: success;
- release artifact: `9518011746` (`r3dfox-gost-win64-release`).

The same source commit passed the dedicated SSL compile check:

- run `32710363528`;
- job `97380247058`;
- result: success, including `Compile security manager SSL target objects`.

Runtime target: `fzs.roskazna.ru` through the configured system HTTP proxy / ASUGATE.

The runtime logs confirm the intended lifecycle:

```text
tlsActive=0
GostWrite/GostRead proxy plaintext ...
ProxyStartSSL host=fzs.roskazna.ru
GOST TLS activated ... after_proxy_tunnel=1
TLSBUF direction=out ... ClientHello
TLSBUF direction=in ... real TLS handshake records
MSSPI handshake complete host=fzs.roskazna.ru TLS=0x0303 cipher=0xff85
msspi_write / msspi_read ... protected application data
```

Two A/B logs were captured from the exact same build:

- explicit GOST-only cipher list `C100:C101:C102:FF85:0081`: seven successful proxy/TLS connection sequences;
- `R3DFOX_GOST_CIPHERS=default`: six successful proxy/TLS connection sequences.

Every completed handshake in both logs negotiated TLS 1.2 (`0x0303`) and suite `0xFF85`. After each handshake the logs show bidirectional MSSPI application-data traffic. The old proxy failure signatures (`HTTP/1.1 400 Bad Request`, `SEC_E_INVALID_TOKEN`, fatal `unexpected_message`) do not recur after TLS activation.

Most importantly, the user confirmed browser-visible end-to-end success: **Treasury pages loaded completely, including JavaScript and images**. This is the first confirmed project milestone where the real browser, the configured system proxy, HTTP CONNECT, MSSPI/CryptoPro GOST TLS, protected HTTP traffic, dependent resource loading, and final page rendering all work together.

Therefore the HTTP-proxy lifecycle blocker and the basic GOST TLS handshake/application-transport blocker are **closed for the tested environment and target site**. Successful compilation is no longer the strongest evidence; full page rendering is confirmed.

### Alternative full-build runtime cross-check

The same exact GOST TLS source commit was also tested in the alternative full browser build:

- workflow: `GOST TLS PoC build - thunk-rs experiment`;
- Actions run: `32710363484`;
- job: `97388836234`;
- exact build commit: `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`;
- CI result: success, attempt 2;
- release artifact: `9519011295` (`r3dfox-gost-win64-thunk-experiment`).

This build uses the ordinary-Rust + narrow-YY-Thunks compatibility path, while carrying the same GOST SSL/TLS source.

The uploaded runtime log `gost.moz_log` from `gost_experiment.zip` (SHA-256 `bbba5dfe695314c56411e872b7a997a62da1199e1bf886957a1002743b2e0039`) records 14 proxy/TLS connection sequences. All 14 reach `ProxyStartSSL()`, activate GOST TLS, complete MSSPI TLS 1.2 with suite `0xFF85`, and then carry application traffic. The capture contains 119 `msspi_write` calls and 381 `msspi_read` calls, with no `HTTP/1.1 400 Bad Request`, no `SEC_E_INVALID_TOKEN`, and no `E/GostTLS` entries.

The browser-visible result is stronger than a page-load smoke: the user navigated the Treasury site, filled forms, requested information, and received response lists from the site's web services. The application remained functional across these interactions.

Therefore **the same GOST runtime behavior is confirmed across both current full-build strategies**. The proxy/GOST success is not specific to only the main Win7 build-std path or only the alternative ordinary-Rust + narrow-YY path. This is a GOST runtime cross-build conclusion; it does not by itself prove complete Windows 7 feature compatibility for either strategy.

### Treasury client-certificate / mTLS baseline

Treasury certificate login redirects from `fzs.roskazna.ru` to `https://lk-fzs.roskazna.ru/certificate-list`. An initial attempt with only `fzs.roskazna.ru` in `R3DFOX_GOST_HOSTS` left the login host on ordinary NSS and produced `SSL_ERROR_NO_CYPHER_OVERLAP`. That result was a routing prerequisite, not an MSSPI mTLS result.

The decisive follow-up used the same alternative artifact from run `32710363484`, job `97388836234`, exact source SHA `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`, with both exact Treasury hosts allowlisted. Uploaded archive: `gost_2_mTLS.zip`; inner log `gost.moz_log`; SHA-256 `7b8cb1d2b3bd8593f4a3bbd5d5df5ab6a274fec5c7e0ccfad8bdab955b10809e`.

Across 15 repeated login attempts, `lk-fzs.roskazna.ru` consistently reaches the GOST socket provider, HTTP CONNECT, `ProxyStartSSL()`, and MSSPI. The TLS server flight is directly decodable as:

```text
ServerHello
Certificate
CertificateRequest
ServerHelloDone
```

One captured `CertificateRequest` has an 11,529-byte body and contains 34 acceptable CA distinguished names. After processing it, MSSPI transitions to `0x0000000A`, which is `MSSPI_READING | MSSPI_X509_LOOKUP`. This occurs on all 15 attempts.

At the tested source SHA `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`, the wrapper did not install `msspi_set_cert_cb()`. Pinned MSSPI also creates client Schannel credentials with `SCH_CRED_NO_DEFAULT_CREDS`, so simply adding valid certificates to the Windows `MY` store did not make Schannel choose one automatically.

The wire trace proves the resulting baseline behavior. Schannel sends an empty client Certificate handshake:

```text
0B 00 00 03 00 00 00
```

and then proceeds with ClientKeyExchange / ChangeCipherSpec / Finished. The server answers on every attempt with:

```text
15 03 03 00 02 02 28
```

which is a TLS fatal `handshake_failure` alert. Schannel maps that received alert to `0x80090326` (`SEC_E_ILLEGAL_MESSAGE`); MSSPI ends in `0x40000008` = `MSSPI_ERROR | MSSPI_X509_LOOKUP`. No `MSSPI handshake complete` occurs for the login host.

Therefore **the Treasury mTLS requirement is confirmed**. The tested baseline blocker was client-certificate selection/loading in the Firefox MSSPI wrapper, not proxy routing or GOST cipher negotiation.

### Stage 1 mTLS implementation and successful proof

Code-under-test:

- commit: `f5d04896e17f91f58b6a137af823360f4718eb29` (`feat(gost): add stage1 mTLS client cert selection`);
- file: `security/manager/ssl/nsGostSSLIOLayer.cpp`.

The Stage 1 implementation deliberately keeps the first proof narrow:

- `msspi_set_cert_cb()` is installed only for `lk-fzs.roskazna.ru`;
- the local selector is `R3DFOX_GOST_CLIENT_CERT_THUMBPRINT=<local-thumbprint>`;
- the selector is treated as a Windows SHA-1 certificate thumbprint and is never logged;
- selection searches only `CurrentUser\\MY` and requires a private-key provider binding;
- the selected certificate DER is passed to `msspi_set_mycert()` so MSSPI/Schannel can use the associated CryptoPro private key;
- there is no automatic certificate fallback and `msspi_get_issuerlist()` is not a Stage 1 selection gate;
- existing server-verification behavior is intentionally left unchanged for this first proof;
- raw outbound `TLSBUF` hex logging is suppressed from the certificate callback onward so client Certificate / CertificateVerify bytes cannot be published accidentally;
- sanitized logs expose only selector presence, certificate-selection success/failure class, MSSPI state/error codes, and final `client_cert_loaded` status.

The exact Stage 1 code passed all relevant build gates:

- main full build: run `32751967162`, job `97510763210`, workflow `GOST TLS PoC build`, result success;
- dedicated SSL compile check: run `32751967187`, job `97510762872`, workflow `GOST SSL compile check`, result success;
- experimental full build: run `32751967189`, job `97510762742`, workflow `GOST TLS PoC build - thunk-rs experiment`, result success.

The user then successfully tested both full artifacts against the real Treasury mTLS endpoint with a known-good local certificate selected by `R3DFOX_GOST_CLIENT_CERT_THUMBPRINT`. The concrete thumbprint remained local and was not published.

Sanitized main-build runtime evidence shows repeated successful certificate selection with `private_key_binding=1`, completed TLS 1.2 / `0xFF85` handshakes with `client_cert_loaded=1`, no recurrence of the old `0x80090326` rejection, and successful authenticated Treasury use. A second main-build capture also succeeded with MSSPI native-default cipher selection.

The experimental thunk-rs/YY-Thunks runtime capture shows 12 successful client-certificate selections, all with `private_key_binding=1`, followed by 12 completed mTLS handshakes on `lk-fzs.roskazna.ru`, all reporting TLS 1.2 (`0x0303`), suite `0xFF85`, and `client_cert_loaded=1`; there are no `0x80090326` or `E/GostTLS` failures in that capture.

Therefore **Stage 1 client-certificate GOST mTLS is confirmed successful across both current full-build strategies at exact source SHA `f5d04896e17f91f58b6a137af823360f4718eb29`**. The previous client-certificate-selection blocker is closed for the tested endpoint and environment.

### Current GOST runtime security/integration questions

Stage 1 is complete. The current GOST runtime work is the mandatory **Stage 2 mTLS security/UX closure**.

Stage 2.1 diagnostics originally localized the server-certificate acquisition failure to `SECPKG_ATTR_REMOTE_CERT_CHAIN` returning `0x80090302` from the active SSPI/CryptoPro provider. Source SHA `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e` switches that path to `SECPKG_ATTR_REMOTE_CERT_CONTEXT`; runtime from the main build run `32844083378`, job `97789764275`, artifact `9567881847`, now shows the real Treasury host reaching `verify ok=1 status=0x00000000` with peer certificate and chain available. Positive acquisition is therefore repaired for the tested environment, but final fail-closed negative verification remains mandatory.

The same source also contains the first asynchronous Firefox-facing client-certificate picker. Real Treasury runtime now confirms all of the following:

- a timely picker selection can complete GOST mTLS with `client_cert_loaded=1`;
- leaving the picker unanswered exposes Firefox's 30-second TLS-handshake timeout, busy-polling in `MSSPI_X509_LOOKUP`, and stale negative session caching after automatic dialog teardown;
- zero eligible `CurrentUser\\MY` candidates are re-enumerated on every later connection and do not create a sticky negative decision;
- restoring an eligible certificate to `CurrentUser\\MY` while the same browser process is running changes a later attempt from `count=0` to `count=1`, opens the picker, and completes real mTLS without restarting r3dfox;
- the real login flow can create several simultaneous client-auth handshakes. The current one-dialog-per-socket implementation requested five additional dialogs within about 20 ms in the live recovery capture, after which positive remembered selections and later negative remembered outcomes were both consumed during the same page transition. The current logging does not expose enough decision-key detail to distinguish same-key overwrite from different OriginAttributes, but independent per-socket dialog lifecycles are conclusively not coordinated safely.

The user reported a browser-visible HTTP/application error 500 in that concurrent recovery session. The GostTLS-only log shows multiple successful mTLS handshakes and protected application-data exchanges before later no-certificate failures, and does not contain decrypted HTTP status text. The 500 therefore must not be classified as a basic TLS/client-certificate handshake failure from this capture; the client-auth race must be removed before deciding whether an independent application-layer issue remains.

The agreed final picker contract is maintained in `STAGE2_PLAN.md`: stock Firefox UI, human-readable certificate rows, positive-only remembering, explicit `Pending`/`Selected`/`Declined`/`Aborted`/`NoUsableCertificate`/`Failed` attempt states, clean Necko suspend/resume, and a single-flight selection broker for compatible concurrent client-auth requests. Direct token-only/CSP/KSP discovery remains a separate open question because the live recovery proof restored the certificate to `CurrentUser\\MY`; it did not enumerate a certificate that existed only on removable media.

Before mTLS may be considered complete, Stage 2 must close the security and integration debt defined in `TODO.md`: fail-closed server verification with positive and negative cases; coordinated, non-spinning Firefox client-auth lifecycle; final acceptable-issuer/candidate-source policy; negative client-auth paths; diagnostic/privacy audit; and a final hardened Treasury regression trace.

### Next GOST runtime experiments

1. Implement the coordinated client-auth lifecycle first: one single-flight picker for compatible concurrent requests, quiescent `MSSPI_X509_LOOKUP` waiters, stale-callback generation checks before remembered-state mutation, and positive-only remember semantics.
2. Re-run the exact Treasury recovery/login scenario and prove one user decision can safely resume all compatible live waiters without duplicate/queued dialogs, negative-cache poisoning, busy-looping, or the 30-second timeout.
3. Complete fail-closed server-certificate verification and prove the positive Treasury host plus wrong-hostname/invalid-chain negative cases.
4. Finish issuer-aware candidate policy and then test whether a certificate existing only on inserted CryptoPro/removable media is discoverable without restoring/installing it into `CurrentUser\\MY`; add provider enumeration only if the current store view cannot expose it.
5. Exercise explicit no-certificate, abort, unavailable private key/PIN/provider failure, wrong certificate, and server-rejection paths, ensuring none creates a sticky negative decision.
6. Re-run the successful Treasury mTLS application workflow after Stage 2 hardening and preserve a sanitized exact-run/exact-SHA regression proof.

## Windows Vista/7 build-compatibility track

This track is separate from the GOST TLS runtime handshake.

### Retained constraints

- Firefox is normally built in the `/MD` dynamic CRT model.
- Do not solve Win7 compatibility by forcing a static CRT into the existing Firefox `/MD` world.
- The earlier static VC-LTL experiment exposed `/failifmismatch` conflicts such as `MD_DynamicRelease` versus `MT_StaticRelease` / `libcpmt.lib`.
- A successful linker invocation is not enough; final PE imports and target-OS execution matter.
- The complete YY-Thunks `kernel32.lib` must not be placed before Rust/gkrust as a broad interposition mechanism.

The retained negative full-build proof for broad YY `kernel32.lib` interposition is:

- run `32623108290`;
- job `97162633898`;
- commit `a73f18e823c083c970eea649ce305da648640e2f`;
- failure: duplicate `LockResource` between `gkrust.lib` raw-dylib surface and YY `kernel32.lib`.

### Proven narrow ProcessPrng strategy

Representative closing smoke:

- run `32644291202`;
- job `97207125757`;
- commit `fd925b1780fa3470a2cfba743a7374f7d7e644d6`;
- result: success.

The passing strategy uses YY-Thunks 1.2.2 `synchronization.lib` plus a physically narrow archive built from:

- `ProcessPrng.obj`;
- `ProcessPrng.obi`;
- `YY_Thunks_for_6.1.7600.0.obj`.

It preserves `/MD`, leaves the full YY `kernel32.lib` out of the final linker inputs, keeps `LockResource` as a normal KERNEL32 import, and removes `ProcessPrng` plus the selected Win8+ synchronization imports from the representative PE.

### First xul-scale result and precise-time blocker

Full Firefox run:

- run `32647338452`;
- job `97213486474`;
- commit `0eb29ecccaa3d2a0762af17e458c42cf245410d7`.

The build and package succeeded. The xul import audit showed the ProcessPrng/synchronization strategy had scaled far enough that the next hard direct blocker was:

`KERNEL32.dll!GetSystemTimePreciseAsFileTime`

That API requires Windows 8 and was therefore a real Windows 7 loader-hard blocker in that binary.

### Precise-time closing smoke

Focused workflow result:

- run `32680494331`;
- job `97296220325`;
- commit `cdef097b1912f68232de13d5e41b1a84add466d6`;
- workflow `YY-Thunks precise-time closing smoke`;
- result: success on the first attempt.

The smoke proved the narrow provider can close `GetSystemTimePreciseAsFileTime` using exactly:

- `GetSystemTimePreciseAsFileTime.obj`;
- `GetSystemTimePreciseAsFileTime.obi`;
- `YY_Thunks_for_6.1.7600.0.obj`.

It verified both ordinary and `__imp_` COFF weak aliases, did not expose the broad `LockResource`/`LoadLibraryExW` surface, and removed precise-time from the final representative PE imports without supplying the full YY `kernel32.lib`.

A prior direct edit of the full workflow in commit `b3c3d3b00c6e4a76fbfaa615b9104828c26e78ba` corrupted embedded-Python newline literals and was not experimental proof. The malformed workflow surfaced as run `32692410607` at commit `08203bb0d7023b7186dc11e4d765f0349aadf076`, which GitHub rejected before creating a build job.

### Current xul-scale result

The narrow ProcessPrng + precise-time strategy has now crossed the real Firefox/xul build boundary.

Actions result:

- run `32695496647`;
- job `97336702701`;
- exact commit `ae3d52f42b8b6b509c1263418bead8bb9324dd00`;
- release artifact `9512347999`;
- diagnostics artifact `9512349511`.

The following stages all passed:

- narrow YY ProcessPrng + precise-time provider construction;
- libxul linker patch;
- configure/export/SSL target gates;
- full release Firefox build;
- package;
- release artifact upload;
- xul import-audit step;
- diagnostics upload.

Only the final policy gate failed.

The diagnostics prove that `GetSystemTimePreciseAsFileTime` is absent from the final xul direct imports. The previous hard blocker is therefore closed at full Firefox build/package scale. `ProcessPrng`, `WaitOnAddress`, `WakeByAddressAll`, `WakeByAddressSingle`, and `GetOverlappedResultEx` are also absent from the checked direct-import set.

The generated forbidden-direct file contains exactly:

`GetQueuedCompletionStatusEx`

That API is genuinely a direct KERNEL32 import in this xul, but it is **not** a Windows-8-only API. Microsoft documents minimum supported client Windows Vista, so it is valid on Windows 7. The red final status of run `32695496647` is therefore a policy/harness false positive, not a new Win7 loader blocker.

Commit `e2a9c3bcbbdfade62a15a144da9117e249cc6305` removes only `GetQueuedCompletionStatusEx` from the Win8+ hard blacklist. It does not change the linker strategy.

### Direct versus delay-load audit status

The ordinary/direct import parser used in run `32695496647` is sufficient for the current hard-loader gate and is the basis for the precise-time closure conclusion.

The delay-load API parser is **not yet complete**. `dumpbin /imports` formats delay API rows differently from ordinary import rows. The workflow switches to a delay section and records delay DLL names, but the API regex in `ae3d52f4...` matches only the ordinary-import line shape. Therefore `xul-thunk-win7-delay-import-api-names.txt` is empty and must not be interpreted as proof that there are no delay-loaded APIs.

Re-parsing the retained raw import dump with the correct delay-load line shape yields 504 unique delay API names. Relevant post-Win7 candidates include:

- `GetAutoRotationState`;
- `GetPointerFrameTouchInfo`;
- `GetPointerType`;
- `CoIncrementMTAUsage`;
- `RoActivateInstance`;
- `RoGetActivationFactory`;
- Windows Runtime string APIs.

These are delay-loaded in the inspected binary and therefore must be analyzed as runtime-path compatibility questions, not automatically promoted to process-loader blockers.

Separate direct imports such as `api-ms-win-crt-*` belong to CRT/UCRT deployment analysis and must not be conflated with YY-Thunks symbol interposition.

### msvcr14x coexistence proof

The CRT/UCRT compatibility direction has now passed a representative combined-link smoke without weakening the proven YY strategy.

Authoritative coexistence result:

- branch: `agent/msvcr14x-win7-smoke`;
- workflow: `msvcr14x Rust YY coexistence smoke`;
- Actions run: `32713958570`;
- job: `97391163925`;
- exact commit: `1abf867307ca56b97b7f2fb41e5e58e86ee08463`;
- pinned msvcr14x commit: `6495947edbdd8f5dc4b2ddb8ca0cb5dbdac05384`;
- YY-Thunks: `1.2.2`;
- Rust: `nightly-2026-08-20`;
- CI result: success.

The representative final link combines an ordinary C++ `/MD` / `MD_DynamicRelease` object, modern Rust/libstd, YY `synchronization.lib`, the physically narrow ProcessPrng + precise-time provider, and msvcr14x import libraries. The final link excludes complete YY `kernel32.lib` and the full YY library directory.

The successful gates establish that the representative PE:

- keeps the C++ runtime model at `MD_DynamicRelease`;
- resolves Rust/libstd `ProcessPrng` and synchronization requirements through the proven narrow YY strategy;
- resolves `GetSystemTimePreciseAsFileTime` through the same narrow provider;
- keeps `LockResource` as a normal KERNEL32 positive-control import without duplicate-symbol collision;
- has no direct `ProcessPrng`, `WaitOnAddress`, `WakeByAddressAll`, `WakeByAddressSingle`, `GetSystemTimePreciseAsFileTime`, or `GetOverlappedResultEx`;
- has no direct `api-ms-win-*`, `ext-ms-*`, `VCRUNTIME140.dll`, or `VCRUNTIME140_1.dll` dependency;
- selects `ucrtbase.dll` and `msvcp140.dll` from the msvcr14x runtime surface;
- executes successfully on the Windows 2022 runner.

This closes the representative coexistence question. It does **not** yet prove that msvcr14x integration scales through the complete Firefox/xul link or that an msvcr14x-integrated Firefox package starts on Windows 7.

### Windows 7 target-OS startup validation

The exact portable package from the full xul-scale experiment has now been executed on Windows 7.

Validated build identity:

- Actions run `32695496647`;
- job `97336702701`;
- commit `ae3d52f42b8b6b509c1263418bead8bb9324dd00`;
- release artifact `9512347999`;
- package `r3dfox-v153.0.3.win64.portable.7z`;
- package SHA-256 `534adf0777685f554f8948e19d84042b84520d9521a6f6084534c84c6558c08b`.

Manual target-OS result on 2026-08-24: **the browser starts successfully on Windows 7**.

This is the first direct runtime proof that the current narrow YY-Thunks full-Firefox build can get through the Windows 7 loader and normal browser startup. It is stronger than a clean import audit alone and closes the question of basic startup compatibility for this exact build.

The scope remains specific. Successful startup does not prove that every browser feature or every delay-loaded post-Win7 API path is safe on Windows 7, and it does not prove GOST TLS handshake success. Those are separate runtime-coverage questions.

### Current next Win7 experiments

1. Integrate the exact proven coexistence strategy into one full Firefox/xul experiment: preserve `/MD`, keep YY-Thunks 1.2.2 `synchronization.lib` plus the existing physically narrow ProcessPrng + precise-time provider, select pinned msvcr14x import libraries at link time, and package the required app-local msvcr14x runtime DLLs. Audit the produced Firefox PE set for direct `api-ms-win-*`, `ext-ms-*`, `VCRUNTIME140*.dll`, and the known Win8+ hard imports before target-OS testing.
2. Run the resulting portable package on Windows 7 without the current copied API-set/UCRT compatibility bundle. This is the decisive target-OS proof for the msvcr14x-integrated build.
3. Obtain or retain a formal full-build result with the corrected direct-import policy from commit `e2a9c3bcbbdfade62a15a144da9117e249cc6305` or an exact descendant as CI/gate hygiene; this is no longer prerequisite for basic Win7 startup proof.
4. Fix or replay the delay-load API parser against the retained raw dump before claiming complete delay-load coverage.
5. Classify the actual delay-loaded post-Win7 APIs by whether Firefox guards those runtime paths on Windows 7, and exercise representative browser paths beyond startup.
6. Keep any GOST TLS-on-Windows-7 test separate: bind its runtime log to the exact build run/SHA and evaluate the MSSPI/SSPI handshake independently from old-Windows loader compatibility.

The forward `yy-thunks-rust-smoke.yml` canary may independently test newer VC-LTL releases such as 5.3.1. Do not conflate that canary's dependency-version investigation with the full xul linker strategy above.

## Bundled government-system extensions track

This is a third, independent product-packaging track. It does not change the current GOST TLS handshake conclusions and does not establish or alter Windows Vista/7 binary compatibility.

The first target is the CryptoPro CAdES Firefox extension:

- extension ID: `ru.cryptopro.nmcades@cryptopro.ru`;
- committed fallback: `r3dfox/extensions/ru.cryptopro.nmcades@cryptopro.ru.xpi`;
- fallback version: `1.2.14`;
- fallback SHA-256: `3df7ee8c7d655921abce942befc2bfd6e0ddcf9179e6173d72e35083844cc0e7`;
- updater: `build/update-cryptopro-extension.py`;
- dedicated real-packaging workflow: `.github/workflows/cryptopro-mozilla-packaging-smoke.yml`.

The standalone preparation/staging/package contract is proven by Actions run `32815118778`, job `97701728235`, exact source-under-test SHA `2ad7025ca300613d39a227b9e7582a341260d648`, result success, evidence artifact `9551126137`.

That run proves valid committed fallback handling, forced network-failure fallback, invalid-fallback hard failure, acceptance of a valid downloaded candidate, malformed-candidate fallback, wrong-extension-ID fallback, a live download from the official CryptoPro endpoint, staging into a minimal `distribution/extensions` layout, and final ZIP path/hash/ID validation. During the live check the official endpoint returned the same version `1.2.14` and the same SHA-256 as the committed fallback.

The dedicated real Mozilla packaging integration is also proven:

- workflow: `CryptoPro Mozilla packaging smoke`;
- Actions run: `32847887872`;
- job `97801745453`;
- exact source-under-test SHA `17b8d9762b489ed8fc9c3a8e1595802065dd7188`;
- evidence artifact `9569388324` (`cryptopro-mozilla-packaging-evidence`);
- packaged-browser artifact `9569387758` (`r3dfox-cryptopro-mozilla-packaging`);
- result: success.

The exact passing run completed updater/selection, the full Firefox build, selected-XPI verification in real `dist/bin/distribution/extensions`, `mach package`, and final portable-archive verification together. The expected XPI is therefore proven to survive the real Mozilla build/package graph into the produced portable archive.

This closes the final-archive omission diagnosed by run `32817910715`, job `97709832302`, source SHA `686b7a1d11ff2ad2d4a7cc9907361c8a6f197560`. That failed run remains historical evidence that `FINAL_TARGET_FILES` reaching `dist/bin` did not by itself package the XPI until the exact path was added to `browser/installer/package-manifest.in`.

The same packaged-browser artifact `9569387758` from run `32847887872` has now been tested manually with a new Firefox profile. The bundled `ru.cryptopro.nmcades@cryptopro.ru` extension is discovered automatically without manual XPI installation, appears enabled as version `1.2.14`, and the user confirmed normal CryptoPro signature-verification functionality works. Therefore clean-profile discovery/install and basic functional runtime use are **proven** for exact source SHA `17b8d9762b489ed8fc9c3a8e1595802065dd7188`.

The update configuration for that exact source is also understood. `browser/app/profile/firefox.js` sets both `extensions.update.enabled = true` and `extensions.update.autoUpdateDefault = true`, with the normal extension-update interval at `86400` seconds. The bundled XPI declares CryptoPro's official `ffupdates.json` update manifest, while `r3dfox/policies.json` has no CryptoPro-specific override and does not disable extension updates. The runtime UI shows the per-extension choice as `Default`, so an untouched clean profile is expected to use the global automatic-update behavior. A real version-to-version update has **not yet** been observed and remains the final runtime-update proof.

The next extension work is limited to transferring only the proven updater preparation and final package-verification gates into `.github/workflows/gost-poc-build.yml` and `.github/workflows/gost-poc-build-thunk.yml`, plus a later real CryptoPro version-to-version update test using an older valid signed XPI or a future vendor release newer than `1.2.14`.

Detailed extension design and evidence are in [`EXTENSIONS.md`](./EXTENSIONS.md).

## Separation of conclusions

Keep these statements distinct:

- **Build success** means the selected source/toolchain combination compiled and packaged.
- **Win7 direct-import success** means the current exact loader-hard blacklist is absent from ordinary imports; it is a static compatibility property.
- **Win7 representative msvcr14x coexistence success** is confirmed by run `32713958570` / commit `1abf867307ca56b97b7f2fb41e5e58e86ee08463`; it proves the combined `/MD` + Rust/libstd + narrow YY + msvcr14x link model at smoke scale, not at full Firefox scale.
- **Win7 basic startup success** is confirmed for the exact run `32695496647` / commit `ae3d52f42b8b6b509c1263418bead8bb9324dd00` portable build on a real Windows 7 system; that build predates msvcr14x integration.
- **Broader Win7 runtime compatibility** still requires representative feature exercise and guarded handling of relevant delay-loaded APIs/runtime dependencies.
- **GOST transport success** means MSSPI can exchange bytes through the NSPR layer.
- **GOST TLS handshake success** is confirmed for the exact main build run `32710363486` / commit `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`: TLS 1.2 with suite `0xFF85` completes through the system HTTP proxy.
- **GOST HTTPS application success** is confirmed for both full-build strategies at the same exact GOST source commit `4887e07d...`: the main build fully renders Treasury pages including JavaScript/images, and the alternative thunk-rs full build additionally completes form submission, information requests, and web-service-backed response-list workflows.
- **GOST cross-build runtime independence** is confirmed between run `32710363486` and run `32710363484`: the proxy/GOST behavior is not specific to only one of the two tested Windows build strategies.
- **Treasury mTLS requirement** is confirmed for `lk-fzs.roskazna.ru`: the server sends a real TLS `CertificateRequest` and the baseline enters `MSSPI_X509_LOOKUP`.
- **Stage 1 GOST client-certificate authentication success** is confirmed at exact source SHA `f5d04896e17f91f58b6a137af823360f4718eb29` in both the main full build (`32751967162` / `97510763210`) and the experimental thunk-rs full build (`32751967189` / `97510762742`).
- **Stage 1 cross-build mTLS independence** is confirmed: the same client-auth source works through both current full-build strategies; this does not merge the GOST-runtime and Win7-compatibility investigation tracks.
- **Current Firefox-facing client-auth positive runtime** is confirmed for main artifact `9567881847` / run `32844083378` / source `5e8c8821...`: a dynamically rediscovered `CurrentUser\\MY` candidate can be selected and complete real TLS 1.2 / `0xFF85` mTLS with protected application traffic in the same browser process.
- **Current Firefox-facing client-auth lifecycle is not production-ready**: timeout/busy-wait behavior, stale negative callbacks, and uncoordinated parallel per-socket pickers are confirmed blockers; the final path requires quiescent single-flight selection and positive-only remembered choices.
- **GOST certificate-verification success** is **not yet confirmed as a final fail-closed policy**; positive `verify ok=1/status=0` is now observed after `REMOTE_CERT_CONTEXT`, but wrong-hostname/invalid-chain rejection and final fail-closed enforcement remain required.
- **mTLS integration complete/production-ready** is **not yet true**; Stage 2 server verification, coordinated certificate-selection/issuer policy, negative paths, privacy audit, and hardened regression proof remain required.
- **CryptoPro standalone extension packaging success** is confirmed by run `32815118778` / SHA `2ad7025ca300613d39a227b9e7582a341260d648`; this proves updater/fallback/staging/package behavior but not the real Mozilla packaging graph or Firefox installation.
- **CryptoPro real Mozilla portable-packaging success** is confirmed by run `32847887872`, job `97801745453`, SHA `17b8d9762b489ed8fc9c3a8e1595802065dd7188`; this proves the selected XPI survives the real Firefox build and package graph into the final portable archive.
- **CryptoPro clean-profile runtime discovery/basic functionality success** is confirmed for packaged-browser artifact `9569387758` from the same run/SHA: a new profile discovers the extension automatically and normal signature-verification functionality works.
- **CryptoPro automatic-update configuration is enabled by default** for that exact source (`extensions.update.enabled = true`, `extensions.update.autoUpdateDefault = true`, per-extension `Default`, vendor update manifest present), but a real version-to-version automatic update is **not yet runtime-proven**.

## Maintenance rule

After each meaningful test:

1. append the run/SHA, hypothesis, observation, and conclusion to the current `TEST_LOG.md`;
2. treat dated `TEST_LOG_*.md` files as immutable historical evidence volumes and consult them for earlier experiments;
3. update this file only if the current blocker, architecture, pinned dependency, confirmed behavior, or next experiment changed;
4. mark speculative interpretations explicitly as hypotheses;
5. never overwrite historical failures just because a later experiment superseded them.