# r3dfox GOST TLS — Project State

Last updated: 2026-08-30

This file is the authoritative current technical synthesis. Detailed evidence is in `TEST_LOG.md` and immutable dated `TEST_LOG_*.md` volumes; forward work is in `TODO.md`; closed milestones are in `DONE.md`; the restart-safe runtime sequence is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP branch is in `STAGE2_GIS_GMP.md`; the primary source-level WinRT-removal experiment is documented in `WINRT_SOURCE_POC.md`; Windows XP compatibility architecture and import triage are in `XP_COMPATIBILITY_STRATEGY.md`.

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
- explicit client-certificate Cancel is attempt-local: it is consumed as a declined decision and is not stored as reusable negative state;
- an unanswered picker abandoned by navigation/tab/load teardown remains unresolved and is removed through phase-0 lifecycle cleanup rather than being converted into Declined state;
- client-certificate discovery from `CurrentUser\MY` is distinct from live private-key availability: a certificate can remain picker-discoverable while its CryptoPro private-key medium/container is unavailable;
- if that medium is unavailable before first key acquisition, provider refusal fails only the current MSSPI attempt with `SEC_E_NO_CREDENTIALS`; the positive Firefox Session decision remains intact and can be reused after the medium returns;
- on the current CryptoPro/SSPI environment, removing the private-key medium **after** successful Session mTLS does not necessarily invalidate the already-acquired provider/credential context: a later fresh Treasury socket can still perform a new client-auth TLS exchange using the remembered Session decision;
- long synchronous CryptoPro/provider key access currently runs on the shared Firefox Socket Thread: T9 measured a `74.742 s` provider wait with a responsive browser UI but zero Socket Thread `GostTLS` activity; queued `pay.gov.ru`/GIS GMP network work started immediately when provider Cancel returned, so global network starvation during provider UI is a confirmed concurrency limitation while coordinator/Session state remains safe;
- detailed T10 picker presentation is confirmed usable in Russian: human-readable owner and issuer, correct Cyrillic and localized expiry, readable details, serial details-only, all `Once` / `Session` / `Permanent` choices visible, and `Session` visibly selected by default;
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

Do not repeat those historical tests on unchanged source merely for confirmation. Detailed captures and counts remain in the test logs and `DONE.md`.

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

### T3 explicit Cancel / no certificate — COMPLETE

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Capture `T3 — explicit Cancel.zip` has SHA-256 `32c3e844e85c1997f57bc682d193c91c9fbcfa2c9b0dc91d939a9e82eeec293c`; inner log SHA-256 `d6174d335074904da2e6bbbddfe2b22e582a805292c81e518c72be8a85bfa38b`.

In one browser process (`Parent 1544`):

- four deliberate picker Cancels resolve as `selected=0`, waiter removal `reason=declined-consume`, decision phase `2`;
- no positive Session state or `Once` lease is created by a decline;
- every subsequent attempt creates a fresh decision/picker rather than consuming sticky negative state;
- a fifth picker left unanswered is removed after `30.276 s` from pending phase `0` by `close-pre`; closing callback re-entry and the later stale UI callback are safely rejected;
- `Try again` creates fresh decision `6`, which resolves positively as `selected=1 remember=2`;
- recovery then completes 12 Treasury TLS 1.2 / `0xFF85` mTLS handshakes with `client_cert_loaded=1` and successful protected-cabinet authorization in the same process.

The four deliberate no-certificate attempts naturally produce current-attempt `selected=0`, `0x80090326`, and `0x0000054f` markers. They are **not** sticky-failure evidence: after positive decision `6` there are zero further `E/GostTLS` and zero further `selected=0` markers. Future negative tests must distinguish intentional per-attempt failure markers from unsolicited errors on recovery attempts.

### T4 involuntary tab/load Abort — COMPLETE

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Capture `T4 involuntary Abort.zip` has SHA-256 `bfa51cc1d45c35c8c94cae6a7eb8fc32c6490d30782cdb256a1aefb24078d2f1`; inner log SHA-256 `f921c42d5e7b0299a40f79a5a707d5da93990018fb535edf529aef94a3d82f65`.

In one browser process (`Parent 6184`):

- the first Treasury client-auth request creates `decision=1`, `browser_id=14`, and a picker at `03:43:37.496 UTC`;
- closing that tab while the picker is unanswered removes the waiter after only `4.059 s` via `reason=close-pre`, removes decision `1` unresolved in phase `0`, rejects shutdown callback re-entry as `reason=closing`, and rejects the late picker callback as stale;
- decision `1` has no resolution record, no `selected=0`, no `declined-consume`, and no phase `2`, proving the tab/load abandonment is observably distinct from T3 explicit Cancel;
- the remaining tab in the same process uses `browser_id=15` and creates a fresh `decision=2` / picker at `03:43:54.093 UTC`;
- decision `2` resolves positively at `03:44:04.399 UTC` as `selected=1 remember=2`;
- recovery adds eight `scope=session` remembered hits and 9 successful Treasury TLS 1.2 / `0xFF85` mTLS handshakes with `client_cert_loaded=1` and successful personal-cabinet authorization.

Whole T4 capture: two decisions, two picker requests, one positive decision resolution, zero `declined-consume`, zero `selected=0`, zero `E/GostTLS`, zero `0x80090326`, zero `0x0000054f`, and zero `MSSPI_X509_LOOKUP`.

Together T3/T4 close the intended negative-decision split on the current artifact: explicit picker Cancel is Declined/phase `2`; involuntary navigation/tab/load abandonment remains unresolved phase `0` and is removed by lifecycle teardown. Neither path poisons later recovery.

### T5 post-login media-removal probe — METHODOLOGY FINDING; T5 DEFERRED

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Capture `T5 — Session failure-boundary regression.zip` has SHA-256 `ede5279115bb6fb80ddae7f40df1c87918a226ffedf6f16979ea30220d218076`; inner log SHA-256 `c9d63066b298bb127ad01060dc3428bcc1171535bd348950d0a3c067040d79c4`.

In one browser process (`Parent 644`), a normal positive Session decision is established and the initial Treasury flow completes. The user then makes the private-key medium unavailable and independently observes missing-container/provider-refusal behavior on the official CryptoPro CAdES demo. That CAdES/native CSP path is outside `GostTLS` transport logging, so the exact removal/provider-refusal event itself is external procedure evidence.

The Treasury log nevertheless proves that post-login media removal does not invalidate the already-acquired MSSPI credential in this environment:

- the initial Treasury burst ends at `04:12:30.946 UTC`;
- at `04:15:42.644 UTC`, `191.698 s` later, a fresh `lk-fzs.roskazna.ru` socket is created;
- at `04:15:42.864`, the new socket receives a fresh client-certificate request, consumes `selected=1 scope=session`, and emits a `redacted=client-auth` TLS flight;
- at `04:15:43.160`, that fresh connection completes TLS 1.2 / `0xFF85`, state `0x00000000`, `client_cert_loaded=1`;
- whole capture contains 10 Treasury client-certificate requests, 9 Session remembered hits and 10 successful Treasury mTLS handshakes, with zero `E/GostTLS`, `selected=0`, `0x80090326`, `0x0000054f`, `MSSPI_X509_LOOKUP`, or `SEC_E_NO_CREDENTIALS`.

This is stronger than an already-open HTTP/TLS session surviving: a later new socket performs a new client-auth TLS exchange successfully. The current interpretation is that CryptoPro/SSPI retains an already-acquired provider/private-key credential context after the medium is removed. That behavior is acceptable and should not be treated as a failure.

The capture therefore **does not pass or fail T5**. It invalidates post-login medium removal as the planned T5 fault injection. T5 is deferred until a safe deterministic way exists to invalidate an already-acquired provider credential inside the same browser process.

### T7/T8 missing-medium/provider recovery — COMPLETE

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Capture `T7-T8.zip` has SHA-256 `bd3fdf5bd73a2c7a6331235fe4f7bddb155698cdb6daaa5ef95f6fada1fae32c`; inner log SHA-256 `8692ca7043f256d9673767a01e368d935c3f6df664ed814424b0abbeacf971a7`.

In one browser process (`Parent 7056`, `browser_id=14`):

- with the key medium unavailable before first GOST key acquisition, Treasury candidate enumeration still reports one certificate from `CurrentUser\MY`;
- exactly one Firefox decision/picker is created and resolves positive at `04:57:20.614 UTC` as `selected=1 remember=2`;
- provider/container refusal then causes the current MSSPI attempt to fail at `04:57:22.379` with `0x8009030e` (`SEC_E_NO_CREDENTIALS`); there is no `selected=0`, `declined-consume`, or negative remembered decision;
- a new Treasury attempt in the same process receives another CertificateRequest at `04:57:28.516` and reuses `selected=1 scope=session` without another picker;
- after the medium is restored, the provider/key path emits the outbound client-auth flight at `04:57:55.829` and completes TLS 1.2 / `0xFF85` mTLS at `04:57:56.095`, state `0x00000000`, `client_cert_loaded=1`;
- protected MSSPI application writes/reads resume immediately, and the capture finishes with 12 successful recovered Treasury mTLS handshakes and 12 Session remembered uses after the initial failed attempt.

T7 is closed: discovery of a certificate identity from `MY` is independent of live private-key availability, and a missing-medium/provider refusal is attempt-local rather than sticky Firefox certificate state.

T8 is closed: restoring the key medium allows the existing positive Session decision to recover in the same Firefox process, complete real Treasury GOST mTLS, and resume protected application traffic without another picker or browser restart.

### T9 long provider wait / Socket Thread starvation — CHARACTERIZED

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Capture `T9 — долгий provider wait.zip` has SHA-256 `2f06aeb4dae884cfd4b6f973bcce21de42dc092d907575a798b361e4f7c48bac`; inner log SHA-256 `25a32e6bcd1c1b01d08c6624a429315f2eddefd97e81021dbc990c4b18b7b264`.

In one browser process (`Parent 788`, Treasury `browser_id=14`):

- Treasury client auth resolves positively as Session; the Socket Thread logs dialog completion at `05:36:46.482 UTC`;
- synchronous provider/private-key access then produces no `GostTLS` event for `74.742 s`;
- user observation confirms the browser UI remains responsive and can initiate new tabs/navigation during the wait;
- provider Cancel returns at `05:38:01.224 UTC` as `0x8009030e` (`SEC_E_NO_CREDENTIALS`) without `selected=0` or `declined-consume`;
- queued `pay.gov.ru` networking begins on the same timestamp and completes GOST TLS 1.2 / `0xFF85` at `05:38:01.515`, only `291 ms` later, with `client_cert_loaded=0`;
- `portalgisgmp.login.roskazna.ru` begins at `05:38:01.586` and also completes normally;
- later Treasury requests in the same process reuse `scope=session`, with 12 successful recovered TLS 1.2 / `0xFF85` mTLS handshakes.

T9 therefore closes the long-wait measurement but reveals a concrete concurrency limitation: synchronous CryptoPro/provider key access occupies the shared Firefox Socket Thread, so other network work queues even while the browser UI/event loop remains responsive. Provider Cancel releases the queue immediately, and the long wait does not corrupt Session/coordinator state.

Whether this is materially worse than stock Firefox token/PIN/client-certificate behavior remains unproven; compare before redesigning MSSPI threading. If offloading is attempted, preserve NSPR/MSSPI state ownership, client-auth lifecycle/cancellation and proxy/CONNECT sequencing.

### T10 detailed Russian picker presentation — COMPLETE

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

T10 closes the full user-visible picker presentation beyond the earlier SD6 smoke. Sanitized user confirmation establishes that the owner/name is human-readable, `Issued by` is human-readable, Cyrillic renders correctly, expiry presentation is normal/localized, `Session` is visibly selected by default, `Once` / `Session` / `Permanent` are all visible, details are readable, and certificate serial is confined to details rather than the main candidate row. After the inspection, choosing `Session` still allows successful Treasury login.

No screenshot or raw certificate identity is retained because those fields may contain sensitive identity data. T10 therefore closes presentation/UX only; it does not add new protocol claims beyond the already-proven current-artifact Treasury mTLS baseline and does not imply real `Permanent` persistence.

## Immediate runtime / implementation order

1. **T6 — real Permanent semantics — NEXT IMPLEMENTATION.** Implement and prove persistence distinct from the current process-local non-Once store, including restart persistence and intended forget/change behavior.
2. **T11/T12 — discovery boundary — NEXT RUNTIME.** Verify dynamic `CurrentUser\MY` re-enumeration and determine whether provider/removable-media-only identities are discoverable without browser restart or interactive provider UI during candidate enumeration.
3. **T9 follow-up — provider-wait Socket Thread isolation.** Compare against stock Firefox synchronous token/PIN behavior, then decide whether a focused off-thread MSSPI/provider experiment is warranted. The current behavior is a known performance/concurrency limitation, not a coordinator corruption or handshake blocker.
4. **T5 — Session failure-boundary regression — DEFERRED.** Resume only with a safe deterministic mechanism that actually invalidates an already-acquired provider/private-key credential in the live process; do not repeat post-login medium removal or invent an invasive synthetic invalidation merely to force the test.
5. Continue candidate-policy and negative matrix.
6. Complete mandatory fail-closed server-trust closure and final exact-build Treasury acceptance.

Keep Firefox-picker timeout-source/poll-churn attribution separate from the now-characterized provider-wait Socket Thread blockage.

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

Earlier source `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`, run `32844083378`, job `97789764275`, artifact `9567881847` first established the missing-media behavior historically. The current exact artifact now revalidates the important parts under coordinated Session-default client auth:

- a certificate can remain in `CurrentUser\MY` and be picker-discoverable while its CryptoPro private-key medium/container is unavailable;
- `CERT_KEY_PROV_INFO_PROP_ID`/store presence is binding/discovery metadata, not proof of live key availability;
- provider refusal before first key acquisition fails only the current attempt with `SEC_E_NO_CREDENTIALS`;
- the positive Session decision survives that provider failure;
- a later attempt recovers in the same process after the medium returns and completes real GOST mTLS/application traffic;
- conversely, once a usable provider/credential context has already been acquired, later medium removal may not invalidate it, so that procedure is not a valid T5 fault injection;
- a long provider/key-access wait can synchronously block the shared Firefox Socket Thread while leaving the browser UI responsive; cancellation immediately releases queued network work and does not poison the Session decision.

## Windows compatibility — independent track

### Upstream r3dfox x86 sandbox baseline — sandbox disabled by design

Official `Eclipse-Community/r3dfox` release `v153.0.3` targets `win-153` and explicitly states that the **32-bit build is built with `--disable-sandbox`**. The release note says that with sandbox enabled under Vista, the browser fails to open multiple processes and breaks; the 64-bit build is described as fine.

`Eclipse-Community/r3dfox#11` records the same policy decision. The maintainer reports that the Vista x86 browser does not spawn processes outside the main browser process, `MOZ_DISABLE_CONTENT_SANDBOX=1` mostly mitigates it, and they chose to ship the 32-bit build without sandbox rather than require that workaround. The issue is closed `not_planned`.

This is part of the inherited r3dfox x86 baseline and predates this project's XP/GOST work. Therefore **a sandbox-enabled Win7/Vista x86 pass is not an XP compatibility prerequisite**. The XP/x86 product experiment may use build-time `--disable-sandbox`, matching upstream r3dfox x86. Restoring a working x86 sandbox is optional future security hardening and must be explicitly reprioritized before consuming additional full-build/debug cycles.

### Current full Firefox XP x32 experiment

The first full Firefox 153 x86 compatibility build is source-under-test `982d6529a707c6feecad97c725feed8a3cd21c81` (`ci: add XP x32 full Firefox build workflow`), Actions run `33141004769`, job `98751650853`, workflow `GOST TLS PoC build XP x32`.

The run's overall conclusion is red because the final XP PE/direct-import audit gate failed, but the build itself crossed the important integration boundary:

- full Firefox x86 compilation succeeded;
- msvcr14x XP runtime staging succeeded;
- `dist/bin` PE subsystem retargeting to XP x86 succeeded;
- package creation succeeded;
- the physical-test runtime archive was built from `dist/bin`;
- all package/runtime/diagnostics artifacts uploaded successfully.

Published artifacts:

- package artifact `9676548553` (`r3dfox-gost-xp-x32-package`), digest SHA-256 `1010a84c571ad78ff7757ccdadd27f0cb6a15e1ef437673970f583e7173bb503`;
- runtime artifact `9676549576` (`r3dfox-gost-xp-x32-runtime`), digest SHA-256 `f0287c7917d7d08756acf57ed8cd2eeed9b8d397ea8416fbf2f166308e89f4f5`;
- diagnostics artifact `9676550507` (`r3dfox-gost-xp-x32-diagnostics`), digest SHA-256 `ecec3fe35df412c77c217ed5ed27f2a628d9bc3a931876a171cffa1b41c64862`.

A later CryptoAPI-RNG full build also completed its browser/package stages at source `19c82e7eec160dab761083d454d084515060f808`, run `33298304132`, job `99221664596`; its sandbox-enabled Win7 content-tab test failed, but that result is now classified as optional sandbox-hardening evidence rather than an XP gate.

### Physical Windows XP x32 — current concrete loader blocker

The exact build from run `33141004769` fails on physical XP before browser UI startup with:

`The procedure entry point CloseThreadpoolWork could not be located in the dynamic link library KERNEL32.dll.`

This remains the first concrete physical-XP blocker. A startup-loaded module has a hard dependency on `KERNEL32!CloseThreadpoolWork`, which XP cannot resolve. The exact importing PE module must be identified from diagnostics/import tables before selecting a narrow source/compatibility remedy. The error-dialog title is not sufficient evidence that `r3dfox.exe` itself owns the import.

The immediate XP critical path is therefore loader/import/source compatibility, not repair of the upstream-disabled x86 sandbox.

### Win7 x32 sandbox/RNG experiments — historical evidence, not current XP blocker

When this project's x86 workflow enabled the modern content sandbox, physical Win7 x32 exposed a real sandbox-dependent content crash. Source `982d6529a707c6feecad97c725feed8a3cd21c81`, run `33141004769`, localized the early tab death to the `RandomUint64OrDie`/OS-RNG path, and disabling the content sandbox allowed ordinary browsing.

Commit `27bf83a679ec26b93bc72a0ec7635fb26f821782` added pre-lockdown RNG warm-up. A later experiment replaced the Windows OS RNG implementation with CryptoAPI; exact source `19c82e7eec160dab761083d454d084515060f808`, run `33298304132`, job `99221664596`, still produced `Gah. Your tab just crashed.` with sandbox enabled on physical Win7 x32.

Those observations remain technically valid and are preserved in `TEST_LOG.md`. They no longer justify spending build/debug cycles before XP startup, because official r3dfox v153.0.3 x86 itself ships with `--disable-sandbox`. If sandbox support is explicitly reopened later, reuse this evidence and design the desired XP/Vista/Win7 x86 sandbox semantics deliberately rather than treating the modern Win7 path as a prerequisite.

### Physical Windows 7 x32 — later parent/browser crash localized to WinRT delay-load

The later whole-browser failure observed with `MOZ_DISABLE_CONTENT_SANDBOX=1` is independently localized and is **not** the sandbox/RNG issue.

Evidence remains bound to exact source `982d6529a707c6feecad97c725feed8a3cd21c81`, run `33141004769`, job `98751650853`, runtime artifact `9676549576`, diagnostics artifact `9676550507`.

A user-supplied ProcMon capture shows the parent/browser process, after roughly 45 seconds of successful lifetime and ordinary browsing, beginning a loader search for `api-ms-win-core-winrt-l1-1-0.dll`. Every searched Win7 loader/PATH location returns not-found; no successful load occurs. The exact diagnostics artifact independently proves that `xul.dll` owns a delay-load import group for that module containing `RoActivateInstance` and `RoGetActivationFactory`. The adjacent `api-ms-win-core-winrt-string-l1-1-0.dll` delay-load group contains `WindowsCompareStringOrdinal`, `WindowsCreateString`, `WindowsCreateStringReference`, `WindowsDeleteString`, and `WindowsGetStringRawBuffer`.

WinDbg was then configured to stop on first-chance `0xc06d007e`. At the actual failure, `KERNELBASE!RaiseException` is followed by `xul.dll` delay-load frames. The exception record contains one parameter pointing to the MSVC delay-loader information structure. Reading that structure in the stopped process proves:

- DLL: `api-ms-win-core-winrt-l1-1-0.dll`;
- procedure: `RoGetActivationFactory`;
- last error: `0x0000007e` (`ERROR_MOD_NOT_FOUND`).

Thus the failure chain is proven directly: `xul.dll` delay-load -> missing WinRT API-set on Win7 -> `RoGetActivationFactory` resolution cannot begin because the module is absent -> MSVC delay-load helper raises `0xc06d007e` -> unhandled parent/browser crash. `KERNELBASE.dll` is the exception-raising site, not the defective dependency owner.

For XP this evidence remains useful because WinRT has no XP meaning either. The project strategy is source removal/fallback, not reconstructing the WinRT runtime.

### YY-Thunks WinRT expansion — RETIRED FOR THIS BLOCKER

YY-Thunks 1.2.2 remains a valid project tool for **bounded old-Windows Win32 compatibility gaps**. The representative XP x86 coexistence workload at source `d78137a931145af877dc458b01e494ad0467723d`, run `33138244191`, job `98743029100`, runtime artifact `9673057839`, passed three physical XP SP3 x86 runs with `ExitCode=0`.

However, using the narrow YY provider as the primary mechanism for carrying Firefox's **WinRT activation/string feature surface** onto Win7/XP is retired as unpromising.

The dedicated WinRT YY smoke began at `90067edba48fd4e8bb986ced02a47ae2189e9fb3` and reached `3ebfef1ddbb70b0d2b29f160dabcaa8fbef4fab5` after 26 additional commits and about 3 h 26 min. The dependency boundary repeatedly expanded through aliases, shared YY objects, CRT/harness stubs, MASM glue and additional Windows libraries. Final run `33186862417`, job `98901994671`, source `3ebfef1ddbb70b0d2b29f160dabcaa8fbef4fab5`, still failed in the synthetic closing link on `__imp__StrCmpLogicalW@8`.

Do not continue that line by mechanically adding the next alias/stub/library. A narrow YY shim remains acceptable for small stable residual Win32 gaps.

### WinRT source-removal/fallback — primary architectural direction

A separate branch, `agent/winrt-source-poc`, explores removal/replacement of nonessential WinRT consumers at source level. Detailed design is in [`WINRT_SOURCE_POC.md`](./WINRT_SOURCE_POC.md).

The PoC intentionally replaces/stubs modern Windows integrations while keeping legacy interfaces/fallbacks: native WinRT toast backend -> stub/XUL fallback, InputPane -> legacy path, selected Rust/package/UI WinRT consumers -> removed or unsupported for the legacy target.

This direction has architectural priority for XP because the unsupported feature should disappear rather than be emulated. Exact build/import/runtime validation remains evidence-driven; do not infer an XP runtime pass from source design alone.

### Windows XP SP3 x86 representative runtime — COMPLETE

The isolated XP x86 coexistence line has a real physical-machine runtime PASS:

- experiment branch `agent/msvcr14x-win7-smoke`;
- source-under-test `d78137a931145af877dc458b01e494ad0467723d`;
- run `33138244191`, job `98743029100`, success;
- runtime artifact `9673057839` (`msvcr14x-rust-yy-xp-x86-runtime`), artifact SHA-256 `3b9e1c2643cafee89061c3ce260b0b075c60a772d8cbcedb96cb90161a3c4970`;
- diagnostics artifact `9673058689`, artifact SHA-256 `6775abf4048e12bddcafe3f842be8b23af9c0669190772d0dee04c8e56aac323`.

The exact artifact was executed three consecutive times on a physical Windows XP SP3 x86 machine reporting `Microsoft Windows XP [Version 5.1.2600]`; every run returned `ExitCode=0` without loader/runtime errors or antivirus intervention. This closes representative XP x86 runtime viability for the tested workload.

It does not prove Firefox 153/xul compatibility or GOST TLS on XP; the full Firefox path remains blocked by concrete loader/import/source compatibility work above.

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
- Extension packaging != extension runtime, GOST runtime, or old-Windows runtime.
- Upstream r3dfox x86 shipping with `--disable-sandbox` defines the inherited compatibility baseline; a future sandbox restoration would be an additional security-hardening milestone, not a prerequisite for XP startup/browsing.
- Documentation HEADs never replace the exact source-under-test SHA for a previously built/runtime-tested browser.