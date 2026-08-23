# r3dfox GOST TLS — Project State

Last updated: 2026-08-23

This file is the current technical synthesis for the GOST TLS fork. For chronology and evidence from individual experiments, see [`TEST_LOG.md`](./TEST_LOG.md).

## Repository and branches

- Repository: `syncguy/r3dfox-gost`.
- Default / active development branch: `agent/gost-tls-poc`.
- Frozen baseline: `win-153` at `0d023eb0e3517dea36f2f134a9a25f872611c688` when protection was configured.
- `win-153` is protected with restricted updates, restricted deletion, and blocked force-pushes. Fork syncing is disabled for that ruleset.
- PR #1 historically has base `win-153`; that does **not** make `win-153` the active development branch.
- The last code/CI commit before these context files were introduced was `79061580dabae72a03f78e66fe8b90d1f1cb1ee7` (`ci: test VC-LTL 5.2.2 with YY-Thunks 1.2.2`).

## Version policy

The current r3dfox baseline is from the Firefox/r3dfox 153 line. Firefox upstream has already moved to 154, but the r3dfox author had not yet published the corresponding r3dfox 154 base when this state was recorded.

Do not automatically rebase or migrate this project to Firefox/r3dfox 154. That is a separate future decision.

## Project objective

Add GOST TLS support to r3dfox while preserving the browser's normal TLS path.

Design intent:

- Normal HTTPS continues through Firefox NSS.
- Only allowlisted hosts are redirected to a GOST-capable TLS transport backed by `deemru/msspi` and Windows SSPI/CryptoPro.
- Keep the first phase deliberately constrained to TLS 1.2 / HTTP/1.1 / server authentication while the transport and handshake are stabilized.

The primary runtime test host is `fzs.roskazna.ru`.

## Current architecture

The PoC adds a parallel TLS path around the normal NSS socket path for explicitly selected hosts.

Important pieces include:

- host allowlist selected by `R3DFOX_GOST_HOSTS`;
- `GostTLSService` / socket-provider routing;
- `GostSocketControl` implementing the TLS socket-control surface expected by Necko;
- `nsGostSSLIOLayer.cpp`, which pushes a custom NSPR I/O layer;
- MSSPI callbacks that read/write through the actual lower NSPR transport;
- Windows SSPI/CryptoPro performing the TLS/GOST handshake and record protection.

Ordinary non-allowlisted HTTPS must remain on NSS.

## MSSPI baseline

Pinned MSSPI source commit:

`f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`

This corresponds to MSSPI 1.0.8-era code used by the CI integration. The build currently vendors/copies the pinned source during CI and applies only the Windows header case adjustment required by the build environment.

The Firefox wrapper currently configures the client with the equivalent of:

- `msspi_set_client`;
- TLS 1.2 via `msspi_set_version(..., 0x0303)`;
- `msspi_set_hostname`;
- `msspi_set_peerauth`.

The current Firefox integration does **not** explicitly call `msspi_set_cipherlist`.

A working Chromium-Gost MSSPI path does configure an explicit cipher list, so cipher-list negotiation is a leading comparison point, but it has not yet been proven to be the root cause of the current failure.

## GOST TLS runtime status

### Confirmed working

The transport-side NSPR/MSSPI integration is now far enough to exchange a real TLS handshake flight with the server.

With the `caa420c25bcc2693137666b625e62a1b58fdcb0f` transport fix and the successful build from Actions run `32571061759`:

1. `fzs.roskazna.ru` matches the allowlist.
2. A TCP socket is created.
3. MSSPI is opened and configured as a TLS 1.2 client.
4. The GOST NSPR layer is pushed.
5. The wrapper resolves and stores the real lower transport after the push.
6. MSSPI emits a 198-byte initial TLS flight; `LowerWrite` sends all 198 bytes.
7. The first nonblocking read returns Winsock `10035` / would-block and is correctly treated as pending.
8. A later `LowerRead` receives 1039 bytes from the server.
9. The failure occurs only after those server bytes reach SSPI.

This proves the earlier callback/lower-layer transport bug is no longer the current blocker.

### Resolved transport bug

Before commit `caa420c...`, MSSPI callbacks were tied to a `PRFileDesc*` whose lower-layer relationship was not stable across `PR_PushIOLayer`.

The fix:

- passes `GostSecret*` as the stable MSSPI callback argument;
- resolves the active pushed GOST layer with `PR_GetIdentitiesLayer`;
- stores `secret->lower` after the push;
- makes `LowerRead`/`LowerWrite` use that stable lower transport;
- makes shutdown/close handling safer.

Do not return to redesigning Poll/LowerRead/LowerWrite unless new evidence shows a transport regression.

### Current runtime blocker

After receiving the 1039-byte server handshake flight, the call through MSSPI to `InitializeSecurityContextA` fails with:

`0x80090308` — `SEC_E_INVALID_TOKEN`

MSSPI then enters `MSSPI_ERROR` (`0x40000000`).

The later `0x0000054f` / `ERROR_INTERNAL_ERROR` seen on another `msspi_connect` call is secondary: MSSPI is already in its error state and should not be diagnosed as the initiating failure.

Immediately after SSPI consumes the 1039-byte input, MSSPI writes 7 bytes. The strongest current interpretation is that this is an SSPI-generated TLS Alert (5-byte TLS record header + 2-byte alert payload). That needs to be confirmed by dumping the bytes.

Current observed flow:

```text
Firefox/MSSPI
  -> 198-byte client TLS flight
fzs.roskazna.ru
  -> 1039-byte server TLS flight
SSPI InitializeSecurityContextA
  -> SEC_E_INVALID_TOKEN (0x80090308)
MSSPI/SSPI
  -> 7-byte output, very likely TLS Alert
```

### Leading runtime questions

The next investigation should determine what SSPI disliked about the server flight rather than changing the NSPR transport again.

Highest-value questions:

1. What exactly is in the 198-byte ClientHello emitted by the current MSSPI configuration?
2. What TLS records and handshake messages are in the 1039-byte server response?
3. Which cipher suite did the ServerHello select?
4. What are the exact 7 bytes emitted after `SEC_E_INVALID_TOKEN`, especially the TLS alert level and description?
5. Does the current ClientHello differ materially from the direct MSSPI path used by Chromium-Gost because Firefox does not call `msspi_set_cipherlist`?

A useful forced-GOST TLS 1.2 cipher-list experiment, after obtaining the baseline dump, is based on:

`C100:C101:C102:FF85:0081`

Do not treat that list as a proven fix. Ideally expose a cipher-list override as a diagnostic option so the baseline and forced-cipher behavior can be tested from one build.

### Investigated details that are not leading suspects

- MSSPI callback `-1` semantics match the wrapper's would-block handling; the observed `WSAEWOULDBLOCK` path is behaving correctly.
- MSSPI 1.0.8's dynamic I/O buffering is consistent with the observed 18432-byte read request and does not currently explain the failure.
- `msspi_set_peerauth(1)` is not the leading explanation for `SEC_E_INVALID_TOKEN`; inspection of MSSPI indicates it does not directly add a client `InitializeSecurityContext` mutual-auth flag in this path.

## Runtime test invocation

Typical manual test:

```bat
set R3DFOX_GOST_HOSTS=fzs.roskazna.ru

r3dfox.exe -no-remote ^
  --MOZ_LOG=timestamp,sync,GostTLS:5 ^
  --MOZ_LOG_FILE=C:\Temp\r3dfox-gost ^
  https://fzs.roskazna.ru/
```

Always preserve the produced GOST log together with the exact build run ID / SHA.

## Windows Vista/7 build-compatibility track

This is a separate track from the runtime GOST handshake.

The project is also testing how to keep current Firefox/Rust output usable on Windows Vista/7 by controlling imports and linker behavior.

Important retained findings:

- Firefox is normally built in the `/MD` dynamic CRT model.
- An earlier VC-LTL integration that forcibly injected static C++ runtime libraries produced a linker mismatch such as `MD_DynamicRelease` versus `MT_StaticRelease` (`libcpmt.lib`).
- Therefore do not solve Win7 compatibility by blindly forcing the static CRT into the existing Firefox `/MD` world.
- YY-Thunks/VC-LTL experiments should be evaluated by the final PE imports and runtime behavior, not merely by whether the linker accepted them.

Current experiment family uses:

- Rust nightly `nightly-2026-08-20`;
- YY-Thunks 1.2.2 in the newest experiments;
- VC-LTL 5.2.2;
- thunk-rs 0.3.5 for provisioning in the dedicated smoke workflow.

Recent experiment commits include:

- `09546d605e73fd32e72eb49edb6a9abbd026617f` — add YY-Thunks Rust Win7 smoke test;
- `9a66088635d2d2b1a5876d37ea2499c6d9afbb7a` — test YY-Thunks API-set import library before Rust `libstd`;
- `a76bb469be18daa135e4d477cd092b9713d98140` — use YY-Thunks synchronization import library;
- `a73f18e823c083c970eea649ce305da648640e2f` — link YY-Thunks sync and kernel32 libs before `gkrust`;
- `1b2c329589d8a256ea5615bf2eb15027b0624787` — test YY-Thunks 1.2.2 in Rust smoke;
- `79061580dabae72a03f78e66fe8b90d1f1cb1ee7` — combine VC-LTL 5.2.2 provisioning with YY-Thunks 1.2.2 smoke variants;
- `c898f1ae8a693c764a30b59d7eadc06638982b65` — reproduce the `LockResource` collision class in the dedicated Rust smoke;
- `517950bb31d232a0a5173c01c47c9c171e9b242d` — add the single-hypothesis narrow `ProcessPrng` closing smoke;
- `83208f74718cc70ad8c65081d2771b5babe60f09` — correct the closing smoke to recognize YY's COFF weak-alias records;
- `d32ef97dac1faa5d51fe7e2b4d2ace9c6b47ec11` — fix the probe rlib filename so the representative Rust final link can run;
- `fd925b1780fa3470a2cfba743a7374f7d7e644d6` — parse exact PE import names instead of substring-matching the dump text.

### Current Win7 linker status

Full-build Actions run `32623108290`, job `97162633898`, at commit `a73f18e823c083c970eea649ce305da648640e2f` remains the retained negative result for broad interposition. It failed while linking `xul.dll` because placing the complete YY `kernel32.lib` before `gkrust.lib` exposed an ordinary `LockResource` definition that collided with Rust's raw-dylib import object:

```text
lld-link: error: duplicate symbol: LockResource
>>> defined at gkrust.lib(48d3f1b29a630f4c-gl.o)
>>> defined at kernel32.lib(kernel32.dll)
```

Therefore the complete YY `kernel32.lib` must not be placed ahead of the Rust archive in the Firefox link.

The narrow closing-smoke strategy is now formally confirmed at representative Rust-link scale by Actions run `32644291202`, job `97207125757`, commit `fd925b1780fa3470a2cfba743a7374f7d7e644d6`. Diagnostics artifact `9494650310` shows:

1. all provider-construction, representative-Rust, single-link, and exact PE-import audit gates passed;
2. `ProcessPrng` and `YY_Thunks_ProcessPrng` resolve to the same address in the final map;
3. the complete YY `kernel32.lib` path is not supplied to the final linker;
4. the full YY Lib directory is not supplied through final `LIBPATH`;
5. parsed DLL imports are only `KERNEL32.dll`, `msvcrt.dll`, and `ntdll.dll`;
6. parsed API imports retain the `LockResource` positive control but contain none of `ProcessPrng`, `WaitOnAddress`, `WakeByAddressAll`, or `WakeByAddressSingle`;
7. `bcryptprimitives.dll` and `api-ms-win-core-synch-l1-2-0.dll` are absent.

The passing strategy consists of YY-Thunks 1.2.2 `synchronization.lib` plus a physically narrow `yy-processprng.lib` built from `ProcessPrng.obj`, `ProcessPrng.obi`, and `YY_Thunks_for_6.1.7600.0.obj`. It preserves the Firefox `/MD` CRT model and does not use the complete YY `kernel32.lib` as an interposed library.

The remaining Windows-compatibility question has therefore moved from **finding a narrow strategy** to **testing whether that exact proven strategy scales to Firefox's real `xul.dll` link and final packaged binaries**.

This does **not** change the independent GOST runtime blocker; it is a separate Win7/toolchain result.

### Next Win7 experiment

Transfer the exact passing strategy into `.github/workflows/gost-poc-build-thunk.yml` as one full-scale experiment:

1. update the experiment to YY-Thunks 1.2.2;
2. construct the same narrow ProcessPrng provider from `ProcessPrng.obj`, `ProcessPrng.obi`, and `YY_Thunks_for_6.1.7600.0.obj`;
3. keep YY `synchronization.lib` for `WaitOnAddress` / `WakeByAddress*`;
4. remove complete YY `kernel32.lib` interposition;
5. do not place the full YY Lib directory in final `LIBPATH` merely to solve ProcessPrng;
6. preserve Firefox's existing `/MD` CRT model;
7. keep exactly one linker strategy in the full build, with no A/B order variants;
8. replace raw substring scanning in the `xul.dll` audit with the exact parsed DLL/API-name logic proven by the closing smoke;
9. require the full Firefox link/package to succeed and then audit the produced `xul.dll` for the known forbidden imports.

A successful full build plus clean `xul.dll` import audit would confirm that the smoke strategy scales to Firefox. It would still not by itself prove complete Windows 7 runtime compatibility; actual execution on Windows 7 remains a later validation step.

## Separation of conclusions

Keep these statements distinct:

- **Build success** means the selected source/toolchain combination compiled and packaged.
- **Win7 compatibility success** additionally requires a clean import audit and preferably execution on the target OS.
- **GOST transport success** means MSSPI can exchange bytes through the NSPR layer.
- **GOST TLS success** requires the complete TLS handshake and usable HTTPS traffic.

At present the NSPR transport exchange is working, but the GOST TLS handshake is not yet complete because SSPI rejects the server flight with `SEC_E_INVALID_TOKEN`.

## Maintenance rule

After each meaningful test:

1. append the run/SHA, hypothesis, observation, and conclusion to `TEST_LOG.md`;
2. update this file only if the current blocker, architecture, pinned dependency, confirmed behavior, or next experiment changed;
3. mark speculative interpretations explicitly as hypotheses;
4. never overwrite historical failures just because a later experiment superseded them.
