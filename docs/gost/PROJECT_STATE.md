# r3dfox GOST TLS — Project State

Last updated: 2026-08-28

This file is the authoritative current technical synthesis. Detailed evidence is in `TEST_LOG.md` and immutable dated `TEST_LOG_*.md` volumes; forward work is in `TODO.md`; closed milestones are in `DONE.md`; the restart-safe runtime sequence is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP branch is in `STAGE2_GIS_GMP.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default / active branch: `agent/gost-tls-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the working branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer r3dfox baseline.

## Architecture

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication.

Current constraints and behavior:

- allowlist: `R3DFOX_GOST_HOSTS`;
- TLS 1.2 / HTTP/1.1 PoC path;
- default GOST ciphers: `C100:C101:C102:FF85:0081`;
- coordinated Firefox client-auth picker is default;
- `R3DFOX_GOST_CLIENT_AUTH_MODE=legacy` remains a same-binary diagnostic fallback;
- explicit local certificate thumbprint selection remains diagnostic only;
- `Session` is the GOST picker default;
- a positive Session choice is process-local, reused for matching client-auth decisions in the running browser process, isolated from a different GOST mTLS host, and cleared by browser-process restart;
- explicit `Once` remains available and uses the positive-only 5-second idle fanout lease; each successful reuse refreshes the idle expiry;
- `Issued by` uses the human-facing issuer common name when available, with the full issuer DN only as fallback;
- current source still routes every non-`Once` positive choice through the same process-local remember store, so true persistent `Permanent` semantics are not yet implemented/proven.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

## Current authoritative GOST runtime browser

Session-default source/build:

- source-under-test `afbdad307f63e594d3715169d6e34235280dddaf` (`fix(gost): mark Session picker default in runtime logs`);
- short SSL compile run `33073577249`, job `98521835147`, success;
- authoritative main full build run `33073577269`, job `98521835354`, success;
- release artifact `9652941006` (`r3dfox-gost-win64-release`);
- Win7 import-audit artifact `9652941552`;
- independent thunk-rs full build run `33073577260`, job `98521835116`, success; browser artifact `9652182123`, diagnostics `9652183604`.

Exact binary identity for main artifact `9652941006`:

- `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`;
- `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`.

These hashes were independently checked against the official GitHub Actions artifact and match the local runtime preflight. Every subsequent GOST runtime conclusion must pass the mandatory binary/environment/profile preflight in `STAGE2_RUNTIME_TEST_PLAN.md`.

## Confirmed GOST milestones

### Basic Treasury GOST HTTPS — COMPLETE

- source `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`;
- main run `32710363486`, job `97380247020`, artifact `9518011746`.

Real Treasury HTTP CONNECT, GOST TLS 1.2 / `0xFF85`, protected HTTP application traffic and browser rendering are proven.

### Stage 1 explicit-selector Treasury mTLS — COMPLETE

- source `f5d04896e17f91f58b6a137af823360f4718eb29`;
- main run `32751967162`, job `97510763210`.

A locally designated client certificate can be loaded by MSSPI/CryptoPro and completes real Treasury GOST TLS 1.2 / `0xFF85` mutual TLS plus authenticated protected application traffic. The concrete certificate identifier remains private.

### Stage 2 coordinated-client-auth baseline — COMPLETE

Runtime-proven source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`, main run `33039013849`, job `98408139479`, artifact `9636591432` closed:

- F1 close/shutdown lifecycle;
- F2 positive `Once` fanout and post-expiry scope boundary;
- F3 generic GOST mTLS host scope;
- GIS-G4 cross-host remembered-decision isolation;
- explicit positive Session browser-process lifetime S1/S1-B/S1-C.

Do not repeat those historical tests on unchanged source merely for confirmation. Detailed captures and counts remain in `TEST_LOG.md` and `DONE.md`.

### Session-default exact-artifact regression SD1-SD6 — COMPLETE

Exact source/run/artifact: `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

The mandatory preflight passed with the exact hashes above and the baseline environment containing the five Treasury/GIS GMP GOST hosts, with diagnostic thumbprint/mode/cipher overrides cleared.

Confirmed on the exact artifact:

- **SD1:** default picker choice resolves as Session (`remember=2`); one Treasury picker feeds successful TLS 1.2 / `0xFF85` mTLS and later matching requests use `scope=session` without a second picker;
- **SD2:** same browser process continues using the Session decision across later matching requests/browser context without another picker;
- **SD3:** after complete browser-process restart, the first matching Treasury request creates a fresh decision/picker; the prior Session state does not survive the process boundary;
- **SD4:** explicit `Once` still creates short positive fanout leases and independent post-expiry attempts create fresh picker decisions/new lease generations rather than silently becoming Session;
- **SD5:** an active Treasury Session decision does not leak to `portalgisgmp.cert.roskazna.ru`; GIS GMP receives its own fresh decision/picker and completes GOST mTLS independently;
- **SD6:** user-visible picker presentation is confirmed correct: Session is visibly selected by default and `Issued by` is human-readable as intended.

All supplied SD1-SD5 captures contain zero `E/GostTLS`, `selected=0`, `0x80090326`, `0x0000054f`, and `MSSPI_X509_LOOKUP`. Successful recorded GOST handshakes use TLS 1.2 / `0xFF85`, state `0x00000000`; completed mTLS proves real client private-key use.

This closes the Session-default UX/runtime iteration. It does **not** close true persistent `Permanent` semantics, Cancel/Abort/provider negative paths, candidate-policy work, or final fail-closed server verification.

## Immediate runtime / implementation order

1. **T3 — explicit Cancel / no certificate — NEXT.** A deliberate user decline must remain attempt-local; a later independent attempt must receive a fresh picker. Distinguish explicit `Declined` from involuntary `Aborted`.
2. **T4 — involuntary Abort.** Exercise navigation/tab/load teardown without a user decision. State must be `Aborted`, not reusable `Declined`, and a later attempt must recover.
3. **T5 — Session failure-boundary regression.** Verify temporary provider failures and matching-policy boundaries cannot overwrite or leak an established positive Session decision.
4. **T6 — real Permanent semantics.** Implement/prove persistence distinct from the current process-local non-Once store, including intended forget/change behavior.
5. Continue provider/media, picker/localization, dynamic discovery, candidate-policy and negative matrix.
6. Complete mandatory fail-closed server-trust closure and final exact-build Treasury acceptance.

Keep timeout-source/poll-churn attribution as separate non-blocking work.

## Mandatory server trust — OPEN

Positive `DriveHandshake verify ... ok=1 status=0x00000000` observations under the current verification path are useful diagnostics but do not close final server trust.

Required final behavior:

- reject `verifyOk == 0`;
- reject any nonzero verification status;
- integrate Firefox temporary/permanent certificate overrides;
- positive browser-session verification cache keyed by exact server identity;
- prove valid Treasury hostname/chain succeeds;
- prove wrong hostname and invalid/untrusted chain fail closed;
- prove client private-key operations cannot occur before server trust.

Do not use a production verification bypass.

## Provider/private-key media evidence

Earlier source `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`, run `32844083378`, job `97789764275`, artifact `9567881847` proves:

- a certificate may remain in `CurrentUser\MY` while its CryptoPro private-key medium/container is unavailable;
- `CERT_KEY_PROV_INFO_PROP_ID` is binding metadata, not proof of live key availability;
- provider Cancel can fail only the current attempt with `SEC_E_NO_CREDENTIALS`;
- a later attempt can recover when the medium becomes available.

These scenarios still require revalidation after the current client-decision/UX work.

## Windows Vista/7 compatibility — independent track

Current full-xul narrow YY/thunk-rs build evidence for the Session-default source:

- source `afbdad307f63e594d3715169d6e34235280dddaf`;
- run `33073577260`, job `98521835116`;
- browser artifact `9652182123`;
- diagnostics `9652183604`.

This is build/package/direct-import evidence only. Still open: real Win7 runtime, delay-load parser/runtime-path closure, full-Firefox msvcr14x integration, broader Win7 runtime, and a separate exact GOST-on-Win7 milestone.

## Bundled government-system extensions — independent track

Current proven three-extension package checkpoint:

- source `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- full packaging run `32976571122`, job `98202641607`;
- packaged-browser artifact `9614275050`;
- evidence artifact `9614275551`.

The portable archive contains CryptoPro CAdES `1.2.14`, legacy Gosuslugi/IFCPlugin `1.2.8`, Gosplugin `1.3.43.0`, and the Russian-first content-language preference. Clean-profile discovery/enabled-state is proven for all three project extensions. Native-component behavior and version-to-version update behavior remain separate open work.

## Separation of conclusions

- Build success != GOST handshake success.
- Coordinated runtime success != final server-trust closure.
- `client_cert_loaded=1` != private-key-use proof; completed mTLS is the proof.
- GOST runtime != Windows compatibility.
- Extension packaging != extension runtime, GOST runtime, or Win7 runtime.
- Docs HEAD != source-under-test SHA for an earlier binary.