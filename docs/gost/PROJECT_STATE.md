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
- `79061580dabae72a03f78e66fe8b90d1f1cb1ee7` — combine VC-LTL 5.2.2 provisioning with YY-Thunks 1.2.2 smoke variants.

Actions run `32623108290` is associated with `a73f18e...`, not with the later `79061580...` commit. At the time this state was written it was still in progress on the main full-build step, after its prerequisite and SSL-object gates had passed. Do not record a final conclusion for that run until its terminal status and import audit are checked.

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
