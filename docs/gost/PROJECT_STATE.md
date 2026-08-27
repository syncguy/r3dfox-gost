# r3dfox GOST TLS — Project State

Last updated: 2026-08-27

This file is the authoritative current technical synthesis. Detailed runtime/build evidence lives in `TEST_LOG.md` and immutable dated `TEST_LOG_*.md` volumes. Forward work is in `TODO.md`. The detailed Stage 2 contract is in `STAGE2_PLAN.md`; the exact user-facing runtime test sequence and recovery checkpoint is in `STAGE2_RUNTIME_TEST_PLAN.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default / active branch: `agent/gost-tls-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the working branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer r3dfox baseline.

## Architecture

Ordinary HTTPS remains on Firefox NSS. Allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after Necko has performed normal proxy resolution / HTTP CONNECT / proxy authentication.

Current GOST constraints:

- allowlist via `R3DFOX_GOST_HOSTS`;
- TLS 1.2 / HTTP/1.1 PoC path;
- default GOST cipher policy `C100:C101:C102:FF85:0081`;
- coordinated Firefox client-auth picker is default;
- `R3DFOX_GOST_CLIENT_AUTH_MODE=legacy` remains the same-binary diagnostic fallback;
- the explicit local thumbprint selector remains diagnostic only.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

## Confirmed GOST milestones

### Basic Treasury GOST HTTPS

Main end-to-end transport baseline:

- source `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`;
- main run `32710363486`, job `97380247020`, artifact `9518011746`;
- alternative build run `32710363484`, job `97388836234`, artifact `9519011295`.

Real Treasury HTTP CONNECT, GOST TLS 1.2 / `0xFF85`, protected application traffic and browser rendering are proven.

### Stage 1 explicit-selector Treasury mTLS

Known-good Stage 1 source:

- source `f5d04896e17f91f58b6a137af823360f4718eb29`;
- main run `32751967162`, job `97510763210`;
- SSL compile run `32751967187`, job `97510762872`;
- alternative full build run `32751967189`, job `97510762742`.

A local diagnostic client-certificate selector completes real Treasury mTLS and authenticated application workflows. The concrete client-certificate identifier remains private and must never be committed.

## Stage 2 coordinated implementation — build identity

Exact coordinated source under current runtime testing:

- source `860de8e38deed326b7fcd1c547e928c5b48c72a9`;
- short SSL compile run `32951902976`, job `98124948374`, success;
- authoritative main full build run `32951903026`, attempt 2, job `98130275465`, success;
- main release artifact `9606431408` (`r3dfox-gost-win64-release`);
- Win7 import-audit artifact `9606431864`.

The separate Windows-compatibility full-xul experiment at the same source also succeeded: run `32951903069`, attempt 2, job `98205801026`, browser artifact `9613443984`, diagnostics `9613444775`. That is Windows-compatibility evidence only and is not GOST runtime proof.

## Stage 2 coordinated runtime checkpoint

The authoritative runtime browser for the current picker work is main artifact `9606431408` from run `32951903026`, attempt 2, job `98130275465`, source `860de8e...`.

### Test T1 — successful coordinated Treasury login

Evidence is preserved in `TEST_LOG_2026-08-26_2026-08-27.md`.

Runtime capture:

- `gost_main_test_connect.zip` SHA-256 `0756fe71a15ecd56a1576b026888b0a504fb941ab3958f1fda93653fc74c620b`;
- inner `gost.moz_log` SHA-256 `f77e68a5a2c1673500ef8542f12b5db46f6b93d5160e8203fe189eb1913eed89`.

Confirmed behavior:

- coordinated mode is active;
- real Treasury mTLS succeeds;
- 11 `lk-fzs.roskazna.ru` handshakes complete as TLS 1.2 / `0xFF85` with `client_cert_loaded=1`;
- concurrent single-flight works inside a decision wave: the second and third waves each collapse five compatible sockets into one visible picker;
- the old repeated `MSSPI_X509_LOOKUP` tight re-entry is absent;
- default `Once` lifetime is too narrow: one logical login creates three sequential compatible connection waves, and a fresh picker appears for every wave because the completed decision is discarded and `Once` is intentionally not session-remembered.

Therefore T1 is **not to be repeated on the old artifact**. It becomes a regression test only after the positive `Once` fanout/lease fix.

### Test T2 — unanswered picker / timeout / retry

Exact same browser identity as T1.

Runtime capture:

- `gost_timeout_260827.zip` SHA-256 `92f19f308bcc57394ad8f40d285d2e4934a5ee7d1707568d5c2507d2458909d9`;
- inner `gost.moz_log` SHA-256 `8dd16505df8095806d60eddcb1d92844b87c04e5caa253b1003a3010f640cda5`.

User-visible result:

- first Firefox client-certificate picker was left unanswered;
- after about 45 seconds it disappeared and the browser showed `The connection has timed out`;
- F5, `Try again`, returning to the Treasury main page, and a fresh attempt to enter the personal cabinet no longer showed a certificate picker.

Sanitized runtime result:

- first picker request: `02:56:22.161 UTC`;
- timeout/close begins: `02:57:07.166 UTC`, about `45.005 s` later;
- during that wait there are `13,107` `GostPoll client-auth wait quiescent` calls (~291/s average), zero `MSSPI_X509_LOOKUP` markers, and no repeated MSSPI certificate-selection handshake loop;
- `GostClose()` removes the original waiter before entering legacy close;
- inside `LegacyGostClose()` / `msspi_shutdown()` the same closing MSSPI handle re-enters the client-certificate callback at `02:57:07.182 UTC`;
- because the old decision was already removed, that re-entrant callback creates a new coordinated decision and a second picker/waiter for a handle that is being destroyed;
- the original dialog callback later arrives as stale and is correctly ignored at `02:57:07.480 UTC`;
- the new shutdown-created decision is left with an orphan waiter;
- when its dialog later resolves with no certificate, the orphan decision becomes terminal `Declined`;
- subsequent real connections find that surviving decision and immediately consume `selected=0` instead of opening a new picker;
- ten later attempts show `dialog completed ... selected=0`; each receives primary `0x80090326`, followed by secondary `0x0000054f` diagnostics.

This proves the current immediate lifecycle blocker: **a client-auth callback must not be allowed to create/join a coordinated decision after the owning MSSPI/socket has entered close/shutdown**. The sticky retry failure is an orphan coordinated-decision bug, not the custom positive/negative remember cache.

The previously assumed exact 30-second boundary is not valid for this coordinated artifact. The observed unanswered-picker close occurs at ~45 seconds. The source of that concrete timeout must be attributed before changing any timeout policy.

T2 is **not to be repeated on the old artifact**. It becomes the first regression test after the shutdown/re-entrancy fix.

## Immediate implementation blockers

Keep the two bugs separate in design and evidence even if they are carried by one later build.

### Blocker A — close/shutdown re-entrant client-auth callback

Required design:

1. mark the MSSPI/socket as closing before calling legacy close / `msspi_shutdown()`;
2. reject any client-certificate callback for a closing handle before it can find/create/join a coordinated decision or open a picker;
3. preserve the MSSPI handle identity across legacy close and perform defensive coordinator waiter removal after legacy close returns;
4. add lifecycle diagnostics for decision create/remove, waiter add/remove, close state, and callback ignored because closing;
5. preserve stale-callback rejection;
6. never convert involuntary timeout/teardown into a reusable negative decision.

### Blocker B — `Once` lifetime across sequential waves

Concurrent single-flight is already proven. The remaining UX requirement is an **attempt-local positive fanout/lease**:

- one explicit positive `Once` selection may serve compatible follow-on connection waves belonging to the same logical login/navigation attempt;
- it must not silently become `Session` or `Permanent`;
- a later independent login must be able to ask again;
- only a positive `Selected` certificate may enter this lease;
- `Declined`, `Aborted`, `NoUsableCertificate`, internal failure, provider failure and server rejection must never enter it.

Exact lease expiry/generation ownership must be designed against Firefox/Necko lifecycle rather than by an unbounded arbitrary cache.

## Runtime test execution order

The authoritative detailed matrix is `STAGE2_RUNTIME_TEST_PLAN.md`. Recovery rule: do not restart the test campaign from T1/T2. Resume at the first item marked `NEXT` or `BLOCKED` in that file.

Immediate sequence:

1. implement Blocker A and Blocker B in separable code changes with explicit diagnostics;
2. run the short SSL compile gate;
3. after the final candidate source is stable, run the authoritative main full-browser build; do not use the thunk artifact as GOST runtime proof;
4. first runtime regression: T2R timeout -> retry must open a fresh picker;
5. second runtime regression: T1R successful Treasury login -> one logical login must need one picker while compatible concurrent/sequential sockets safely receive the selected certificate;
6. only then continue Cancel/abort, remember semantics, provider/media, UI, discovery, negative matrix, server-trust closure and final regression.

## Server trust — still mandatory

Positive Treasury `verify ok=1 status=0x00000000` and peer certificate acquisition are proven on the earlier runtime baseline, but final server trust is not closed.

Required:

- fail closed if verification fails or status is nonzero;
- integrate Firefox temporary/permanent certificate overrides;
- positive browser-session verification cache keyed by exact server identity;
- valid Treasury positive case;
- wrong-hostname and untrusted/invalid-chain negative cases;
- no client private-key operation before server trust.

## Earlier provider/media evidence

Earlier exact source `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`, run `32844083378`, job `97789764275`, artifact `9567881847` proves:

- a certificate may remain in `CurrentUser\MY` while the CryptoPro private-key container is absent;
- `CERT_KEY_PROV_INFO_PROP_ID` is binding metadata, not live-key availability;
- provider Cancel can fail only the current attempt with `SEC_E_NO_CREDENTIALS`;
- a later attempt can succeed after the key medium becomes available;
- provider UI is synchronous inside the MSSPI/SSPI call and remains a stock-parity/performance question until a concrete regression is shown.

These scenarios still need revalidation after the coordinator lifecycle fixes.

## Windows Vista/7 compatibility track

Independent from GOST runtime.

Current evidence:

- original real-Win7 startup package: source `ae3d52f42b8b6b509c1263418bead8bb9324dd00`, run `32695496647`, job `97336702701`, artifact `9512347999`;
- current full-xul narrow YY/thunk-rs revalidation: source `860de8e...`, run `32951903069`, attempt 2, job `98205801026`, browser artifact `9613443984`, diagnostics `9613444775`;
- representative modern Rust + narrow YY + pinned msvcr14x coexistence: source `1abf867307ca56b97b7f2fb41e5e58e86ee08463`, run `32713958570`, job `97391163925`.

Still open: full-Firefox msvcr14x integration, final direct/delay-load PE audit, real Win7 runtime without the copied compatibility bundle, broader Win7 runtime, and a separate exact GOST-on-Win7 milestone.

## Bundled government-system extensions track

Independent from GOST runtime and Win7 compatibility.

Current packaged three-extension checkpoint:

- source `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- short run `32976571124`, job `98202642893`;
- full packaging run `32976571122`, job `98202641607`;
- packaged-browser artifact `9614275050`;
- evidence artifact `9614275551`.

The portable archive contains CryptoPro CAdES `1.2.14`, legacy Gosuslugi/IFCPlugin `1.2.8`, Gosplugin `1.3.43.0`, and the Russian-first website/content-language pref. Runtime discovery/functionality of this exact three-extension package remains open.

## Separation of conclusions

- Build success != GOST handshake success.
- Coordinated runtime success != final server trust closure.
- `client_cert_loaded=1` != private-key-use proof; completed mTLS is the proof.
- GOST runtime != Windows compatibility.
- Extension packaging != extension runtime, GOST runtime, or Win7 runtime.
- Docs HEAD != source-under-test SHA for an earlier binary.
