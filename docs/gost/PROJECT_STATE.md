# r3dfox GOST TLS — Project State

Last updated: 2026-09-01

This file is the authoritative current technical synthesis. Detailed evidence is in `TEST_LOG.md` and immutable dated `TEST_LOG_*.md` volumes; forward work is in `TODO.md`; closed milestones are in `DONE.md`; the restart-safe runtime sequence is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP branch is in `STAGE2_GIS_GMP.md`; the primary source-level WinRT-removal experiment is documented in `WINRT_SOURCE_POC.md`; Windows XP compatibility architecture and import triage are in `XP_COMPATIBILITY_STRATEGY.md`; the mandatory XP x86 dependency/build contract is in `XP_BUILD_CONTRACT.md`.

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

T8 is closed: restoring the key medium allows the existing positive Session decision to recover in the same Firefox process, complete real GOST mTLS, and resume protected application traffic without another picker or browser restart.

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

### Physically proven XP x86 dependency build contract

The physically proven dependency/runtime reference remains source `b19ba4ff3eebd2f323743d92110241fc9d4ce399`, run `33387080767`, job `99472017220`, runtime artifact `9756275917`. Its restored/pinned msvcr14x x86 runtime closure is PE subsystem 5.1, avoids the FLS/SRW hard imports that caused the earlier fresh-CRT regression, and the exact runtime artifact was executed successfully on physical Windows XP.

The synchronization capability proof has since been expanded from five APIs to ten:

- source-under-test `d65b464c74caadace97995f07a4919363c41a0ea` on `agent/gost-tls-poc`;
- workflow `msvcr14x Rust YY XP x86 SRW smoke`;
- run `33470957048`, job `99740439208`, **success**;
- runtime artifact `9786702687`, digest `sha256:6b931856c9e4e31b067b5684d3c49fd9028c2c9aaf7f2566be79c910ad353571`;
- diagnostics artifact `9786703244`, digest `sha256:57c67a45a30b94a854f00e358c528c1ffe4129dc7dc615de19c1ed725e89c530`.

The proven ten-API set is `AcquireSRWLockExclusive`, `AcquireSRWLockShared`, `ReleaseSRWLockExclusive`, `ReleaseSRWLockShared`, `InitializeSRWLock`, `InitializeConditionVariable`, `SleepConditionVariableCS`, `SleepConditionVariableSRW`, `WakeAllConditionVariable`, and `WakeConditionVariable`. The focused smoke directly references all ten from ordinary C++ `/MD`, selects all ten `YY_Thunks_*` implementations in the final linker map, rejects all ten final direct imports, passes the XP PE-floor gate, and runs on the hosted Windows runner.

This is a **capability proof**, not yet a full-Firefox proof. `InitializeCriticalSectionEx` remains separately classified for XP-native/source fallback analysis. Full YY `kernel32.lib` interposition remains prohibited.

### Current full Firefox XP x32 blocker and exact artifact

The current exact full-browser failure evidence is:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `99fac0b869c4c0a4638f4e076d77547d90e146cb`;
- run `33396056005`, job `99500729287`;
- workflow `GOST TLS PoC build XP x32`;
- package artifact `9764345117`;
- diagnostics artifact `9764346755`;
- run conclusion: failure after successful build/package at the post-package msvcr14x CRT-survival gate.

The user-tested physical-XP files are exactly the package artifact files: `r3dfox.exe` SHA-1 `562195fb0dfb9b6032069fd050ee8995efe74e62` and `xul.dll` SHA-1 `194184fd716ec9d916230fed087da4ea2c5ba28f`. Physical XP fails at `KERNEL32!AcquireSRWLockExclusive`; this is a real import failure, not a wrong-download incident.

The failed full workflow exposed two independent integration defects:

1. its narrow YY provider omitted the already-proven SRW members, so provider availability in a focused smoke never reached the actual Firefox link;
2. the compatibility linker input was injected only into libxul, even though `r3dfox.exe`, `mozglue.dll`, and `plugin-container.exe` are separately linked and can retain their own direct synchronization imports.

The run also proved an independent packaging blocker: the portable package did not retain the app-local XP-compatible CRT closure (`ucrtbase.dll` / `msvcp140.dll`), and a later broad import audit never executed because that earlier CRT-survival gate failed. Therefore successful compilation, PE-header retargeting or package creation did not imply XP loader compatibility.

### Ten-API transfer prepared for the next full build

The proven synchronization mechanism has now been transferred to the full XP x32 workflow lineage used by run `33396056005`:

- branch `agent/winrt-source-poc`;
- transfer commit `8d76efba59fd7d4c04df3f0d3fe82e1c4e08a3ce`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml`.

The transfer:

- extracts the direct/import YY members for all ten synchronization APIs into the existing physically narrow provider;
- verifies every required `YY_Thunks_*` symbol before the expensive Firefox build;
- retains the invariant that full YY `kernel32.lib` never reaches final browser links;
- injects the narrow provider at the separate link boundaries for `xul.dll`, `r3dfox.exe`, `mozglue.dll`, and `plugin-container.exe`;
- adds `GATE - Reject core browser synchronization direct imports` immediately after the Firefox build and before CRT staging, legacy D3DCompiler staging, PE retargeting and package/CRT-survival gates;
- uploads per-PE synchronization import evidence even if a later independent packaging gate fails.

Therefore the active synchronization blocker is no longer whether YY-Thunks can cover the family. The blocker is whether the exact full Firefox links at transfer commit `8d76efba...` (or an explicitly identified descendant) actually consume those aliases so that all four core PEs pass the new ten-API import gate.

The CRT portable-packaging defect from run `33396056005` remains a separate subsequent blocker. It must not be conflated with synchronization interposition.

### Inherited x86 baseline

Official `Eclipse-Community/r3dfox` `v153.0.3` ships the 32-bit build with `--disable-sandbox`; issue `Eclipse-Community/r3dfox#11` records the intentional decision. Therefore a sandbox-enabled Win7/Vista x86 pass is not an XP prerequisite. The XP/x86 product path uses build-time sandbox disablement unless sandbox restoration is explicitly reprioritized as optional hardening. This inherited choice is physically confirmed on Windows 7 x32 for the XP-oriented full-browser artifact: build-time sandbox disablement removes the need for the `MOZ_DISABLE_CONTENT_SANDBOX=1` runtime workaround and avoids the prior restricted-sandbox notification while preserving normal browser operation.

### Current remediation policy

Do not treat the broad XP import inventory as a production YY backlog.

Caller/owner classification remains mandatory before implementation:

1. for project-built or pinned-source dependencies under our control, first remove post-XP dependencies at their source/build/dependency boundary and keep a dedicated fail-fast contract gate;
2. remove modern-only features/paths where XP has no useful equivalent;
3. prefer XP-native source replacements where older APIs preserve the required operation;
4. prefer one owned legacy backend when several imports belong to a common Firefox abstraction;
5. use physically narrow YY only for unavoidable stable low-level gaps after caller analysis;
6. solve separately linked DLLs at their own build/dependency boundary;
7. use vetted source-available third-party compatibility boundaries where appropriate;
8. reserve custom shims for the residual set.

PE subsystem retargeting is explicitly **header-only remediation**. It can correct the loader floor of an otherwise XP-safe PE but cannot make a binary compatible when its import/dependency closure still requires post-XP APIs or DLLs.

The current `xul.dll` imports that require source/caller analysis before YY assignment include `CancelIoEx`, `CompareStringOrdinal`, `GetCurrentProcessorNumber`, `GetFileInformationByHandleEx`, `GetFinalPathNameByHandleW`, `GetLocaleInfoEx`, `LCIDToLocaleName`, `LocaleNameToLCID`, `GetTickCount64`, `SetFileInformationByHandle`, and `InitializeCriticalSectionEx`.

Other feature/shipping PEs in the broad audit include `libGLESv2.dll`, `mozavcodec.dll`, `mozavutil.dll`, `gkcodecs.dll`, `mozinference.dll`, `d3dcompiler_47.dll`, and `gmp-clearkey`. A core-browser linker change cannot rewrite their independent import tables. Test/developer/fake PEs (`gmp-fake`, `gmp-fakeopenh264`, `logalloc-replay.exe`, `xpcshell.exe`) must not automatically count as XP product blockers.

Focused `D3DCompiler_47.dll` replacement is separately proven at source `b77b22ef1e35564dfe76997d3d393d45ee697e49`, run `33349340069`, job `99359475336`: the pinned legacy Firefox XP DLL is prepared and staged successfully, passes the retargeted legacy-D3DCompiler gate, and survives packaging under its dedicated post-package gate. The overall run still failed later at the broad XP audit, so the D3DCompiler boundary is closed independently of the synchronization/CRT work.

`bcrypt.dll` remains directly imported by core browser PEs and is an independent compatibility boundary. Its selected One-Core-API replacement now has focused immutable evidence at source `9be3a933c3eac2defec24df4826fded48ead02f4`, workflow `bcrypt XP x86 smoke`, run `33475562495`, job `99753970359`. The candidate is pinned to upstream commit `6c3b3b372d46dace7ba729dcd16b316b0acf664c`, blob `0b7d83ddbae62142ee6fca69208d77a8a5d3b0f7`, size `279552`, SHA-256 `ada28a011cf08d9e10780fde09966899f5f40e08c4f5abb05eaa38dbc2f0cfc5`. Its recursive local closure is only `bcrypt.dll` (adjacent `bcryptprimitives.dll` is not imported); required BCrypt exports are present and the current audit finds no obvious post-XP hard import in the closure.

The exact candidate is x86 but carries PE OS/image/subsystem version `6.00`, `Check integrity`, no Certificate Directory, and no Authenticode signature. Accordingly the exact-local dynamic probe on hosted Windows Server 2022 fails at `LoadLibraryW(.\bcrypt.dll)` with `ERROR_INVALID_IMAGE_HASH` (`577` / `0x241`). The ordinary linked probe passes there only through `C:\Windows\System32\bcrypt.dll`, so neither hosted result is physical-XP proof. Runtime artifact `9788031922` preserves the exact upstream DLL plus both XP-floor (`5.01`) x86 probes and is the next decisive physical Windows XP SP3 x86 experiment. Do not mutate the candidate merely to satisfy modern Code Integrity and do not mark it physically XP-verified before that artifact passes on real XP.

### YY coverage smoke — capability proof only

The representative XP x86 msvcr14x/Rust/YY workload at source `d78137a931145af877dc458b01e494ad0467723d`, run `33138244191`, job `98743029100`, remains physically proven on Windows XP SP3 x86.

A later broad coverage smoke at source `39ce8453be32557dfb709bce8ee412c16f78a72f`, run `33316988353`, job `99272141403`, successfully selected all 26 then-current forbidden API names plus previously proven Rust/libstd entries into a physically narrow YY provider and passed its representative PE/import/runtime gates.

This proves **technical YY coverage only**. It does not define production provider membership. The ten synchronization APIs are now separately justified by focused evidence and observed core-browser imports; other broad inventory members still require caller-level classification.

### WinRT direction

The physical Win7 crash from source `982d6529a707c6feecad97c725feed8a3cd21c81`, run `33141004769`, remains localized to `xul.dll` delay-loading the missing WinRT API-set and `RoGetActivationFactory`. Broad YY expansion for WinRT is retired. Source removal/fallback on `agent/winrt-source-poc` remains the primary architecture because WinRT has no XP meaning.

### Immediate Windows compatibility order

1. Run the full XP x32 workflow from exact transfer commit `8d76efba59fd7d4c04df3f0d3fe82e1c4e08a3ce` or an explicitly identified descendant containing the same transfer.
2. Require the new early ten-API synchronization gate to pass for `r3dfox.exe`, `xul.dll`, `mozglue.dll`, and `plugin-container.exe`. If it fails, diagnose the specific PE/link boundary before touching packaging or broad API coverage.
3. If synchronization passes, continue to the independent staged/portable CRT identity gate and fix the known portable-package CRT closure if it remains red.
4. Regenerate the surviving broad PE/import inventory only after the synchronization and CRT boundaries are separately proven; do not plan from violations already removed by those contracts.
5. Continue component-by-component source/backend/dependency remediation for the remaining core and separately linked shipping PEs.
6. Rebuild and run the exact resulting artifact on physical XP; only then close full-browser startup/browsing.
7. Keep GOST TLS on old Windows as a later separate exact-artifact milestone.

Detailed synchronization evidence is in `XP_SYNC_IMPORT_STATUS.md`; general rules and the component matrix are in `XP_COMPATIBILITY_STRATEGY.md`; the mandatory dependency contract is in `XP_BUILD_CONTRACT.md`; exact experiments are in `TEST_LOG.md`.

## Bundled government-system extensions / localization — independent track

Current proven three-extension package checkpoint:

- source `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- full packaging run `32976571122`, job `98202641607`;
- packaged-browser artifact `9614275050`;
- evidence artifact `9614275551`.

That portable archive contains CryptoPro CAdES `1.2.14`, legacy Gosuslugi/IFCPlugin `1.2.8`, Gosplugin `1.3.43.0`, and the Russian-first content-language preference. Clean-profile discovery/enabled-state is proven for all three project extensions. Native-component behavior and version-to-version update behavior remain separate open work.

### Russian-first localization — current state

The previous full Windows x64 package checkpoint is source `37846488e281b4c3a2df46e949b4f970a7343ed3`, workflow `CryptoPro Mozilla packaging smoke`, run `33403654068`, job `99525795309`, packaged-browser artifact `9768056691`, evidence artifact `9768057338`. The workflow itself is green and proves the build/package mechanics, CryptoPro extension survival, `mach package`, `mach package-multi-locale --locales ru`, `intl.locale.requested=ru`, and registration of both `ru` and `en-US`.

That artifact is **not** a functional Russian-UI success. Exact-artifact runtime on Windows 7 x64 remains English on a clean profile/restart despite `Requested Locales=["ru"]`, `Available Locales=["ru","en-US"]`, and `App Locales=["ru","en-US"]`. Manually changing packaged `omni.ja!/default.locale` from `en-US` to `ru` does not change the visible UI. Artifact inspection explains why:

- root `omni.ja`: 100 Russian localization files, 97 zero-length;
- `browser/omni.ja`: 129 Russian localization files, 119 zero-length;
- corresponding en-US resources are populated.

Therefore locale negotiation and `default.locale` are not the primary localization blocker. The old directory-existence gate was too weak: it proved locale registration/path presence, not real translated payload.

A focused Firefox 153 l10n merge smoke establishes the upstream half of the path:

- source-under-test `91328ba86f050a7b64a5f344726548d22e599648` on `agent/gost-tls-poc`;
- workflow `Russian localization payload smoke`;
- run `33468459359`, job `99733112273`, **success**;
- `firefox-l10n` source SHA `4273d99ccdc4a516ec6abd742a272ad1d385ddf4`;
- evidence artifact `9785719216`, digest `sha256:e8cac1213a8bf7ffd39357f62673f0d1f20649866e8a3986d042ecfa97583d78`.

For that exact run, the source `ru` tree contains 245 Fluent files, all 245 non-empty and 244 containing Cyrillic. The exact Firefox 153 `moz.l10n.bin.build` merge produces 217 Fluent files, 216 non-empty and 215 containing Cyrillic. The one zero-length merged file is `.l10n/merge-dir/ru/toolkit/toolkit/about/aboutConfig.ftl`; representative browser, preferences, and netError resources are populated. This does not reproduce the mass-empty packaged-artifact failure.

**Current localization conclusion:** real Russian l10n source input is available and the standard Firefox 153 merge primitive works. The active blocker has moved downstream to full Windows multi-locale package/repack integration. The next experiment is to feed the proven l10n input into `cryptopro-mozilla-packaging-smoke.yml` through the normal l10n-base mechanism, record the exact l10n SHA, and hard-gate both root and browser `omni.ja` on zero-length counts/paths plus representative non-empty Cyrillic content. Only after that full-package gate passes should another clean-profile Russian UI runtime test be accepted. A primary `AB_CD=ru` build is not justified unless the correctly supplied en-US-base + l10n repack still fails.

Detailed localization evidence and the exact empty-file path are in `LOCALIZATION_RU_EN_US_FINDING_2026-09-01.md` and `TEST_LOG.md`.

## Separation of conclusions

- Build success != GOST handshake success.
- Coordinated runtime success != final server-trust closure.
- `client_cert_loaded=1` != private-key-use proof; completed mTLS is the proof.
- GOST runtime != Windows compatibility.
- Extension/localization packaging != extension runtime, UI runtime, GOST runtime, or old-Windows runtime.
- Upstream r3dfox x86 shipping with `--disable-sandbox` defines the inherited compatibility baseline; a future sandbox restoration would be an additional security-hardening milestone, not a prerequisite for XP startup/browsing.
- Documentation HEADs never replace the exact source-under-test SHA for a previously built/runtime-tested browser.
