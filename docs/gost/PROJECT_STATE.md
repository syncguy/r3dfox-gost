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

The current r3dfox baseline is from the Firefox/r3dfox 153 line. Firefox upstream has moved to 154, but this project must not automatically migrate, rebase, or retarget to 154. That is a separate future decision requiring explicit user direction.

## Project objective

Add GOST TLS support to r3dfox while preserving the browser's normal TLS path.

Design intent:

- normal HTTPS continues through Firefox NSS;
- only allowlisted hosts are redirected to a GOST-capable TLS transport backed by `deemru/msspi` and Windows SSPI/CryptoPro;
- the first phase remains constrained to Windows, TLS 1.2, HTTP/1.1, and server authentication while transport and handshake behavior are stabilized.

The primary runtime test host is `fzs.roskazna.ru`.

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

For an ordinary HTTP proxy, Firefox/Necko owns proxy resolution, CONNECT generation, proxy authentication, response parsing, and retry behavior. The GOST layer must remain plaintext-transparent until Necko reports a successful tunnel by calling `nsITLSSocketControl::ProxyStartSSL()`. Only then may MSSPI start the origin TLS handshake inside the established CONNECT tunnel.

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

The A/B runtime capture from main-build run `32692411195` proves that this configuration switch really changes the ClientHello, but it does **not** yet prove which cipher list is required by `fzs.roskazna.ru`, because those ClientHello records were sent to the HTTP proxy rather than to the origin server.

### Confirmed runtime behavior

The earlier `caa420c25bcc2693137666b625e62a1b58fdcb0f` transport fix remains valid: the pushed GOST layer has a stable lower NSPR transport, nonblocking would-block handling works, and MSSPI can exchange bytes through that lower socket.

The interpretation of the peer bytes from the earlier run has changed because run `32692411195` added exact TLS-buffer logging.

Authoritative A/B build and logs:

- workflow: `GOST TLS PoC build`;
- Actions run: `32692411195`;
- job: `97328339347`;
- exact build commit: `08203bb0d7023b7186dc11e4d765f0349aadf076`;
- CI result: success;
- runtime host: `fzs.roskazna.ru` through the configured system HTTP proxy.

Forced GOST-list run:

- `msspi_set_cipherlist(..., "C100:C101:C102:FF85:0081")` succeeded;
- MSSPI emitted a 122-byte TLS 1.2 ClientHello offering only `C100`, `C101`, `C102`, `FF85`, and `0081`;
- the next 1038 bytes received from the lower socket begin with ASCII `HTTP/1.1 400 Bad Request` and identify `Via: 1.1 ASUGATE`, proxy address `10.138.1.254`, server `ASUGATE.ctikem.ru`, source `proxy`.

Native-default control run:

- `R3DFOX_GOST_CIPHERS=default` skipped the explicit cipher call;
- MSSPI emitted the previous 198-byte ClientHello with the broader native suite set plus the GOST suites;
- the lower socket returned the same 1038-byte ASUGATE HTTP 400 response;
- MSSPI then emitted `15 03 03 00 02 02 0A`, a TLS 1.2 fatal `unexpected_message` alert;
- `msspi_connect` returned `SEC_E_INVALID_TOKEN` (`0x80090308`), followed later by the already-known secondary `0x0000054f` after MSSPI had entered `MSSPI_ERROR`.

Therefore the old description of those roughly 1039 bytes as a real server TLS handshake flight is superseded. The origin server had not yet received either ClientHello. SSPI was rejecting plaintext HTTP proxy error data as an invalid TLS token.

### Current runtime blocker

The current proven blocker is the Firefox HTTP-proxy lifecycle:

```text
Firefox intends to send CONNECT fzs.roskazna.ru:443
        -> old GOST layer intercepted the first socket I/O
        -> MSSPI started TLS immediately
        -> TLS ClientHello was sent directly to ASUGATE
        -> ASUGATE returned HTTP/1.1 400 Bad Request
        -> SSPI consumed HTTP bytes as TLS and returned SEC_E_INVALID_TOKEN
```

This means `SEC_E_INVALID_TOKEN` from the captured runs is not evidence that CryptoPro rejected a real `fzs.roskazna.ru` GOST handshake. The project has not yet observed the origin server's real ServerHello in the MSSPI path.

### Proxy-compatible implementation under test

Commit `4887e07d847b1c3c2e13b491dcc85f50ddaa9804` (`fix(gost): defer MSSPI until proxy tunnel`) implements the next runtime experiment without changing the Win7/toolchain line:

- reads resolved `nsIProxyInfo` supplied by Firefox rather than consulting Windows proxy settings independently;
- for an ordinary `http` proxy, creates/configures MSSPI but starts the GOST layer with TLS inactive;
- while TLS is inactive, `read`, `recv`, `write`, `send`, `available`, and `poll` pass transparently to the stored lower NSPR transport;
- `GostSocketControl` now implements `ProxyStartSSL()` and `StartTLS()`;
- those entry points only activate MSSPI TLS state; they do not synchronously force a handshake;
- `DriveHandshake` refuses to enter MSSPI before TLS activation;
- direct/non-HTTP-proxy behavior retains immediate TLS activation;
- MSSPI shutdown is skipped when a proxy connection closes before TLS was ever activated.

This commit is an implementation hypothesis until the existing main-workflow SSL compile gate and a runtime test both pass. Do not call the proxy blocker fixed merely because the source change exists.

### Next runtime experiment

Use the existing `.github/workflows/gost-poc-build.yml` main GOST build. Its `GATE - Compile security manager SSL target objects` is the first compile check for commit `4887e07d...`; only the run whose head SHA is exactly that commit (or a deliberately identified descendant containing the same source) is evidence for this change.

If the full build produces a runnable artifact, test it with the real system HTTP proxy and preserve the GOST log. The decisive expected sequence is:

```text
attached MSSPI GOST layer ... tlsActive=0 proxyType=http
GostWrite/GostRead ... proxy plaintext ...
ProxyStartSSL host=fzs.roskazna.ru
GOST TLS activated ... after_proxy_tunnel=1
TLSBUF direction=out ... ClientHello
TLSBUF direction=in ... real TLS record from fzs.roskazna.ru
```

The first high-value runtime gate is that the post-activation input must no longer begin with `HTTP/1.1 400 Bad Request`. Only after a real origin TLS response is captured can cipher selection, certificate messages, and any subsequent SSPI error be diagnosed meaningfully.

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
- **GOST TLS success** requires the complete TLS handshake and usable HTTPS traffic.

At present the lower transport path works, but the last runtime capture did not reach the origin server because MSSPI started before the HTTP CONNECT tunnel was established. Commit `4887e07d847b1c3c2e13b491dcc85f50ddaa9804` contains the proxy-lifecycle fix candidate and is awaiting compile/runtime validation.

## Maintenance rule

After each meaningful test:

1. append the run/SHA, hypothesis, observation, and conclusion to `TEST_LOG.md`;
2. update this file only if the current blocker, architecture, pinned dependency, confirmed behavior, or next experiment changed;
3. mark speculative interpretations explicitly as hypotheses;
4. never overwrite historical failures just because a later experiment superseded them.