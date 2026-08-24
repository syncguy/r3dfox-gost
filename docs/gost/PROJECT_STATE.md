# r3dfox GOST TLS — Project State

Last updated: 2026-08-24

This file is the current technical synthesis for the GOST TLS fork. For chronology and evidence from individual experiments, see [`TEST_LOG.md`](./TEST_LOG.md). For workflow roles, see [`WORKFLOWS.md`](./WORKFLOWS.md).

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

Every completed handshake in both logs negotiated TLS 1.2 (`0x0303`) and suite `0xFF85`. After each handshake the logs show bidirectional MSSPI application-data traffic. The old proxy failure signatures (`HTTP/1.1 400`, `SEC_E_INVALID_TOKEN`, fatal `unexpected_message`) do not recur after TLS activation.

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

The browser-visible result is stronger than a page-load smoke: the user navigated the Treasury site, filled forms, requested information, and received response lists from the site's web services. The application remained functional across these interactive workflows.

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

The current wrapper does not install `msspi_set_cert_cb()`. Pinned MSSPI also creates client Schannel credentials with `SCH_CRED_NO_DEFAULT_CREDS`, so simply adding valid certificates to the Windows `MY` store does not make Schannel choose one automatically.

The wire trace proves the resulting behavior. Schannel sends an empty client Certificate handshake:

```text
0B 00 00 03 00 00 00
```

and then proceeds with ClientKeyExchange / ChangeCipherSpec / Finished. The server answers on every attempt with:

```text
15 03 03 00 02 02 28
```

which is a TLS fatal `handshake_failure` alert. Schannel maps that received alert to `0x80090326` (`SEC_E_ILLEGAL_MESSAGE`); MSSPI ends in `0x40000008` = `MSSPI_ERROR | MSSPI_X509_LOOKUP`. No `MSSPI handshake complete` occurs for the login host.

Therefore **the Treasury mTLS requirement is confirmed and the current blocker is precisely client-certificate selection/loading in the Firefox MSSPI wrapper**. Proxy routing, GOST cipher negotiation, and reaching the real login server are not the blocker in this capture.

### Current GOST runtime security/integration questions

Two related but distinct items remain:

1. **Server-certificate verification must become fail-closed.** Successful ordinary Treasury sessions still contain:

   ```text
   DriveHandshake verify host=fzs.roskazna.ru ok=0 status=0x00000000
   ```

   The wrapper currently rejects only `verifyOk && verifyStatus != 0`; if `msspi_get_verify_status()` itself returns 0, it continues. Pinned MSSPI uses `SCH_CRED_MANUAL_CRED_VALIDATION`, so this is not yet proof that chain/hostname validation is enforced.

2. **mTLS client-certificate selection must be integrated.** `lk-fzs.roskazna.ru` definitively reaches `MSSPI_X509_LOOKUP`, but no certificate callback exists, so an empty client certificate is sent and the server rejects the handshake.

These items should be integrated safely: pinned MSSPI's intended certificate callback flow explicitly verifies the server before selecting/disclosing a client certificate. Do not solve mTLS by bypassing the outstanding server-verification problem.

### Next GOST runtime experiments

1. Instrument the `msspi_get_verify_status()` failure path with the exact `msspi_last_error()` value and, if needed, peer-certificate/chain retrieval status. Determine why verification returns 0 on otherwise successful Treasury sessions.
2. Add `msspi_set_cert_cb()` handling for `MSSPI_X509_LOOKUP`. In the callback, verify the server first and read/log the real issuer list with `msspi_get_issuerlist()`.
3. For a first controlled proof, add a diagnostic explicit selector for one known-good CryptoPro certificate from Windows `MY` and load it with `msspi_set_mycert()` while preserving the private-key provider binding. Do not rely on Schannel default certificate selection; `SCH_CRED_NO_DEFAULT_CREDS` intentionally prevents that path.
4. Prove a complete mTLS handshake and successful personal-cabinet navigation, including CryptoPro private-key/PIN behavior.
5. Once server verification returns a meaningful result, make wrapper behavior fail-closed for both `verifyOk == 0` and nonzero verification status, and prove valid and invalid hostname/chain cases.
6. After the explicit-certificate proof, design Firefox-facing certificate-selection UX and negative cases rather than keeping the diagnostic selector as the final interface.

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

The delay-load API parser is **not yet complete**. `dumpbin /imports` formats delay API rows differently from ordinary import rows. The workflow switches to a delay section and records delay DLL names, but the API regex in `ae3d52f4...` matches only the ordinary-import row shape. Therefore `xul-thunk-win7-delay-import-api-names.txt` is empty and must not be interpreted as proof that there are no delay-loaded APIs.

Re-parsing the retained raw import dump with the correct delay-row shape yields 504 unique delay API names. Relevant post-Win7 candidates include:

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
- **Treasury mTLS requirement** is confirmed for `lk-fzs.roskazna.ru`: the server sends a real TLS `CertificateRequest`, MSSPI enters `MSSPI_X509_LOOKUP`, and the current wrapper sends an empty client certificate because no certificate-selection callback is installed.
- **GOST client-certificate authentication success** is **not yet confirmed**; the login server rejects the empty client Certificate with fatal `handshake_failure`.
- **GOST certificate-verification success** is **not yet confirmed**; the current `msspi_get_verify_status()` return handling must be investigated and made explicitly fail-closed before making that security claim.

## Maintenance rule

After each meaningful test:

1. append the run/SHA, hypothesis, observation, and conclusion to `TEST_LOG.md`;
2. update this file only if the current blocker, architecture, pinned dependency, confirmed behavior, or next experiment changed;
3. mark speculative interpretations explicitly as hypotheses;
4. never overwrite historical failures just because a later experiment superseded them.
