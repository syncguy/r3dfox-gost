# Stage 2 GOST TLS — Runtime Test Plan and Recovery Checkpoint

Last updated: 2026-08-28

Purpose: make the runtime campaign restart-safe. If a chat/session is lost, do **not** restart testing from the beginning. Read `AGENTS.md`, `PROJECT_STATE.md`, this file, and the active/relevant `TEST_LOG*` evidence. Resume at the first `NEXT` item below.

`STAGE2_PLAN.md` remains the security/architecture contract. `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes remain the detailed evidence record; `DONE.md` is the compact closure registry.

## Fixed runtime identity

Current authoritative GOST runtime-test browser:

- source `afbdad307f63e594d3715169d6e34235280dddaf` (`fix(gost): mark Session picker default in runtime logs`);
- main run `33073577269`, attempt 1;
- job `98521835354`;
- artifact `9652941006` (`r3dfox-gost-win64-release`);
- Win7 import-audit artifact `9652941552`.

Exact binary identity for artifact `9652941006`:

- `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`;
- `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`.

These hashes were independently checked against the official GitHub Actions artifact and match the local `certutil` preflight.

## Mandatory runtime preflight — REQUIRED before every named result

A runtime result is valid only after the preflight below passes. A mismatch or missing item invalidates the result for the named test.

### Binary identity

```bat
certutil -hashfile r3dfox.exe SHA256
certutil -hashfile xul.dll SHA256
```

For artifact `9652941006`, require the exact hashes above.

### Baseline GOST environment

Use this environment unless the named test explicitly requires a different override:

```bat
set "R3DFOX_GOST_HOSTS=fzs.roskazna.ru,lk-fzs.roskazna.ru,pay.gov.ru,portalgisgmp.login.roskazna.ru,portalgisgmp.cert.roskazna.ru"
set "R3DFOX_GOST_CLIENT_CERT_THUMBPRINT="
set "R3DFOX_GOST_CLIENT_AUTH_MODE="
set "R3DFOX_GOST_CIPHERS="
```

The empty diagnostic variables are intentional: default coordinated client auth and default GOST cipher configuration must be exercised unless the test explicitly says otherwise.

### Profile isolation and evidence identity

Start each independent test sequence from a new clean test-specific profile. Reuse a process/profile only when continuity is part of the test semantics.

Example:

```bat
r3dfox.exe -no-remote ^
  -profile C:\Temp\r3dfox\profile-Tx ^
  --MOZ_LOG=timestamp,sync,GostTLS:5 ^
  --MOZ_LOG_FILE=C:\Temp\r3dfox\Tx ^
  https://fzs.roskazna.ru/
```

Every recorded result must be bound to source SHA, Actions run/job, artifact ID, binary hashes, test/profile identity, environment state, and sanitized capture/log hash when retained. Never publish client-certificate identifiers, private credential/provider/container metadata, PIN/passwords, private-key material, account data, or unsanitized captures.

## Closed runtime checkpoints — do not repeat on unchanged source

Detailed capture identities and event-level evidence are in `TEST_LOG.md`, dated test-log volumes, and `DONE.md`.

- **T2R / F1 CLOSED:** close/shutdown re-entry cannot create orphan client-auth decisions; timeout retries recover without restart.
- **T1R/T1R-B / F2 CLOSED:** explicit `Once` provides positive 5-second idle fanout and re-prompts after expiry.
- **GIS-G1/G2/G3 / F3 CLOSED:** generic coordinated client auth reaches real GIS GMP mTLS; non-mTLS GOST hosts do not show spurious picker UI.
- **S1/S1-B/S1-C + GIS-G4 CLOSED:** explicit Session is process-local, reusable for matching requests, isolated cross-host, and cleared by process restart.
- **SD1-SD6 CLOSED:** exact artifact `9652941006` runtime-proves default Session, same-process reuse, restart boundary, explicit Once regression, cross-host isolation, and intended picker presentation.
- **T3 CLOSED:** explicit Firefox picker Cancel is Declined/phase `2`, attempt-local, and does not poison later recovery.
- **T4 CLOSED:** closing the tab that owns an unanswered picker removes the still-unresolved decision through phase-0 lifecycle cleanup, not Declined state; another tab in the same browser process receives a fresh picker and successfully recovers.
- **T7/T8 CLOSED:** a certificate remaining in `CurrentUser\MY` is still picker-discoverable while its key medium is unavailable; provider refusal fails the current MSSPI attempt with `SEC_E_NO_CREDENTIALS`, leaves the positive Session decision intact, and same-process recovery after the medium returns reuses `scope=session` and completes Treasury GOST mTLS/application traffic without another picker.

## T5 probe — POST-LOGIN MEDIA REMOVAL DOES NOT EXERCISE T5

Capture:

- `T5 — Session failure-boundary regression.zip` SHA-256 `ede5279115bb6fb80ddae7f40df1c87918a226ffedf6f16979ea30220d218076`;
- inner `SDx.moz_log` SHA-256 `c9d63066b298bb127ad01060dc3428bcc1171535bd348950d0a3c067040d79c4`.

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

The user established a positive Treasury Session and then made the key medium/container unavailable. Separate CryptoPro CAdES signing activity showed the missing-medium/provider behavior externally, but that path is outside `GostTLS` logging.

The Treasury capture shows why this is not a valid T5 fault injection:

- one positive Session decision is created/resolved;
- the initial Treasury burst completes through `04:12:30.946 UTC`;
- at `04:15:42.644 UTC`, `191.698 s` later, a fresh `lk-fzs.roskazna.ru` socket is created;
- at `04:15:42.864`, that new socket receives a fresh client-certificate request and consumes `selected=1 scope=session`;
- the outgoing TLS flight is `redacted=client-auth`;
- at `04:15:43.160`, the new connection completes TLS 1.2 / `0xFF85`, state `0x00000000`, `client_cert_loaded=1`;
- whole capture has 10 Treasury client-certificate requests, 9 Session remembered uses, 10 successful Treasury mTLS handshakes, and zero `E/GostTLS`, `selected=0`, `0x80090326`, `0x0000054f`, `MSSPI_X509_LOOKUP`, or `SEC_E_NO_CREDENTIALS`.

Interpretation: once CryptoPro/SSPI has already acquired a usable provider/private-key credential context, removing the medium does not necessarily invalidate that context. This is acceptable runtime behavior and is stronger than ordinary HTTP keep-alive: a later fresh socket performs a new client-auth TLS exchange successfully.

**T5 remains DEFERRED / OPEN.** Resume it only if a safe deterministic mechanism exists to invalidate an already-acquired provider/private-key credential inside the same browser process. Do not repeat post-login medium removal expecting a provider fault and do not invent an invasive synthetic invalidation merely to force T5.

## T7/T8 — CLOSED on current exact artifact

Capture:

- `T7-T8.zip` SHA-256 `bd3fdf5bd73a2c7a6331235fe4f7bddb155698cdb6daaa5ef95f6fada1fae32c`;
- inner `SDx.moz_log` SHA-256 `8692ca7043f256d9673767a01e368d935c3f6df664ed814424b0abbeacf971a7`.

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

In one process (`Parent 7056`, `browser_id=14`), the private-key medium is unavailable before first GOST key acquisition while the certificate remains present in `CurrentUser\MY`:

- first Treasury request at `04:57:15.805 UTC` enumerates one candidate, creates exactly one coordinated decision/picker, and resolves at `04:57:20.614` as positive `selected=1 remember=2`;
- the first private-key/provider attempt fails at `04:57:22.379` with `0x8009030e` (`SEC_E_NO_CREDENTIALS`); follow-on calls on the same terminal connection report `0x0000054f`;
- there is no `selected=0`, `declined-consume`, or negative remembered decision;
- a new Treasury attempt starts at `04:57:28.360`; its `CertificateRequest` at `04:57:28.516` consumes `selected=1 scope=session` without a new picker;
- after the medium is restored, the blocked provider/key path emits the client-auth flight at `04:57:55.829` and completes TLS 1.2 / `0xFF85` mTLS at `04:57:56.095`, state `0x00000000`, `client_cert_loaded=1`;
- protected application writes/reads resume immediately and the remaining fanout succeeds;
- whole capture has one decision/picker, 13 Treasury client-certificate requests, 12 Session remembered uses after the failed attempt, and 12 successful recovered Treasury mTLS handshakes.

**T7 PASS / CLOSED:** certificate discovery from `MY` is separate from live key availability; provider refusal is attempt-local and does not poison Firefox certificate state.

**T8 PASS / CLOSED:** returning the key medium permits same-process recovery using the existing Session decision, real Treasury mTLS, and protected application traffic without browser restart or another Firefox picker.

The approximately `27.313 s` provider wait between the recovery Session hit and outbound client-auth flight does not exceed the established ordinary picker-timeout scale and therefore does not close T9.

## NEXT — T6 real Permanent semantics

Current source routes every positive non-`Once` remember choice through the same process-local in-memory store. The `Permanent` UI choice therefore is not yet semantically distinct from `Session` and must not be treated as persistent merely because the UI exposes it.

Goal: implement and prove a real persistent positive client-certificate decision with explicit lifecycle/forget semantics, while retaining the already-proven behavior of `Once` and `Session`.

Required properties:

1. `Once` remains the positive-only 5-second idle fanout lease and re-prompts after expiry.
2. `Session` remains process-local, reusable only for matching client-auth scope, isolated cross-host, and cleared by process exit.
3. `Permanent` persists across browser-process restart for its intended exact decision scope.
4. Provider/private-key failures, Firefox picker Cancel, and lifecycle Abort must not overwrite a positive Permanent decision with negative state.
5. A defined user-facing or internal forget/change mechanism must remove or replace the Permanent decision without manually deleting arbitrary profile files.
6. Persistence must not contain or publish sensitive certificate identifiers in project logs/docs; local storage may hold the minimum identity key required by the implementation.
7. Runtime proof must use a new exact source/build after implementation; current artifact `9652941006` cannot close T6 because its non-`Once` store is process-local.

After implementation, define a compact T6 runtime sequence proving initial Permanent selection, same-process reuse, full process restart persistence, explicit forget/change behavior, and regression safety for Session/Once.

## Remaining client-decision semantics

### T5 — Session failure-boundary regression — DEFERRED

Requires a reproducible way to fail an already-acquired provider/private-key credential inside one live browser process after positive Session state exists. Post-login medium removal is proven insufficient in the current environment.

## Provider/private-key media

### T9 — long provider wait

Hold provider/PIN/media UI beyond the ordinary picker-timeout scale. Record actual duration and check for network starvation, timeout corruption, or teardown materially worse than stock synchronous token/PIN behavior. Do not redesign MSSPI threading without a concrete regression.

## Picker presentation / discovery / policy

### T10 — Russian UI presentation

Verify human owner display name, localized expiry, Cyrillic issuer rendering, human-facing `Issued to`, human-friendly `Issued by`, and serial remaining details-only. Do not publish actual certificate identity values.

### T11 — dynamic `CurrentUser\MY`

Candidate discovery must be re-evaluated on new attempts; zero-candidate results cannot be sticky; a restored eligible certificate must reappear without browser restart.

T7 adds one useful boundary fact but does not close T11: a certificate already present in `CurrentUser\MY` remains picker-discoverable when only its private-key medium/container is unavailable.

### T12 — token/removable-media-only discovery

Determine whether current store discovery finds identities exposed only by provider/removable media. If not, provider discovery becomes required. Candidate enumeration itself must not trigger interactive provider/PIN/media UI.

### T13 — issuer/validity/KU/EKU/private-key suitability

Verify acceptable-CA, validity, KU/EKU, private-key availability/binding and wrong-certificate filtering using safe test identities where possible.

## Negative matrix

### T14 — no acceptable certificate

No sticky negative decision; later candidate restoration can recover.

### T15 — private-key/PIN failure

T7 proves the unavailable-medium/provider-refusal variant is attempt-local on the current artifact. A distinct PIN/private-key failure path remains to be exercised before closing the broader T15 item.

### T16 — server rejects client identity

Surface the real TLS/auth failure; do not convert it into remembered no-certificate state.

## Server-trust closure — mandatory

### T17 — valid Treasury server

Final fail-closed verifier/override/cache implementation accepts valid Treasury hostname/chain.

### T18 — wrong hostname

Must fail closed. No client private-key operation before server trust.

### T19 — invalid/untrusted chain

Must fail closed. No positive server-trust cache entry.

### T20 — Firefox certificate override

Verify intended temporary/permanent override integration and exact server-identity scoping.

## Final regression

### T21 — final Treasury mTLS acceptance

Final exact source/build must prove together final server trust, intended default remember behavior, explicit `Once` short-fanout behavior, safe compatible fanout, completed mTLS/private-key use, expected GOST suite, authenticated protected application traffic, retry recovery and no sensitive data publication.

## Separate non-blocking investigation

T2R observed non-uniform picker timeout/poll behavior (`32.576`, `37.420`, `30.330 s`); T3 adds another unanswered-picker teardown at `30.276 s`. T4 is not another timeout sample: tab close removes its pending decision after `4.059 s`. Attribute the actual Firefox/Necko/load timer and historical first-cycle poll churn before changing timeout policy.

## Stop / escalation rules

- Do not repeat already-proven old-artifact tests unless explicitly regression-testing changed source.
- Mandatory preflight is required before every named runtime result.
- On failure, preserve the capture and stop the dependent branch rather than generating downstream noise.
- Build success never substitutes for runtime proof.
- Main and thunk-rs artifacts are not interchangeable for GOST conclusions.
- Keep Windows compatibility and bundled-extension testing separate from the GOST runtime matrix.
- After every meaningful runtime experiment, append `TEST_LOG.md` and update `PROJECT_STATE.md`, `TODO.md`, `DONE.md`, and this checkpoint when the blocker/current next step changes.