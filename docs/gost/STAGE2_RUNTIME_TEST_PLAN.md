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

## T5 probe — POST-LOGIN MEDIA REMOVAL DOES NOT EXERCISE T5

Capture:

- `T5 — Session failure-boundary regression.zip` SHA-256 `ede5279115bb6fb80ddae7f40df1c87918a226ffedf6f16979ea30220d218076`;
- inner `SDx.moz_log` SHA-256 `c9d63066b298bb127ad01060dc3428bcc1171535bd348950d0a3c067040d79c4`.

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

The user established a positive Treasury Session and then made the key medium/container unavailable. Separate CryptoPro CAdES signing activity showed the missing-medium/provider behavior externally, but that path is outside `GostTLS` logging.

The Treasury capture shows why this is not a valid T5 fault injection:

- one positive Session decision is created/resolved;
- the initial Treasury burst completes through `04:12:30.946 UTC`;
- at `04:15:42.644 UTC`, `191.698 s` later, a **fresh** `lk-fzs.roskazna.ru` socket is created;
- at `04:15:42.864`, that new socket receives a fresh client-certificate request and consumes `selected=1 scope=session`;
- the outgoing TLS flight is `redacted=client-auth`;
- at `04:15:43.160`, the new connection completes TLS 1.2 / `0xFF85`, state `0x00000000`, `client_cert_loaded=1`;
- whole capture has 10 Treasury client-certificate requests, 9 Session remembered uses, 10 successful Treasury mTLS handshakes, and zero `E/GostTLS`, `selected=0`, `0x80090326`, `0x0000054f`, `MSSPI_X509_LOOKUP`, or `SEC_E_NO_CREDENTIALS`.

Interpretation: once CryptoPro/SSPI has already acquired a usable provider/private-key credential context, removing the medium does not necessarily invalidate that context. This is acceptable runtime behavior and is stronger than ordinary HTTP keep-alive: a later fresh socket performs a new client-auth TLS exchange successfully.

**T5 remains DEFERRED / OPEN.** Resume it only if a safe deterministic mechanism exists to invalidate an already-acquired provider/private-key credential inside the same browser process. Do not repeat post-login medium removal expecting a provider fault and do not invent an invasive synthetic invalidation merely to force T5.

## NEXT — T7/T8 missing-medium/provider Cancel and same-process recovery

Goal: prove the current exact artifact handles a provider/key failure when the medium is unavailable **before the first GOST private-key acquisition**, and recovers after the medium returns without sticky certificate state or browser restart.

Procedure on a new clean `profile-T7T8` after mandatory preflight:

1. Ensure the intended private-key medium/container is unavailable **before launching the first Treasury client-auth attempt**. Do not first complete a successful GOST mTLS in this browser process, because that may preload/cache a usable CryptoPro/SSPI credential and invalidate the test method.
2. Launch the exact authoritative artifact with the baseline environment and a dedicated `T7T8` log path.
3. Navigate to the Treasury personal-cabinet login until Firefox client-certificate selection occurs. Select the intended certificate normally if it remains discoverable.
4. Let CryptoPro/provider key access encounter the unavailable medium. If provider UI appears, exercise the planned provider Cancel path. Do **not** use Firefox picker Cancel; that is already T3.
5. Allow the failing attempt to settle. Record the actual provider/handshake error class. The failure must remain attempt/provider-local and must not create reusable Declined certificate state or an orphan/sticky coordinator decision.
6. Restore the key medium/container while keeping the **same browser process/profile** alive.
7. Start a new independent Treasury client-auth attempt.
8. Require recovery without browser restart: a usable certificate decision/picker must be available as appropriate, provider/key acquisition must succeed, and real TLS 1.2 / `0xFF85` Treasury mTLS plus protected application login must complete.

T7 pass criteria:

- the certificate may remain discoverable even though key use is unavailable;
- actual key/provider access fails or is cancelled in the current attempt;
- provider failure is not converted into reusable Firefox `Declined` state and does not poison later decisions;
- capture identifies the actual current-artifact failure class rather than assuming the historical `SEC_E_NO_CREDENTIALS` value.

T8 pass criteria:

- after restoring the medium, a later independent attempt in the same browser process/profile can acquire/use the private key;
- real Treasury TLS 1.2 / `0xFF85` mTLS completes with `client_cert_loaded=1`;
- protected application login succeeds;
- no browser restart is required.

If the certificate disappears entirely when the medium is absent, record that discovery behavior instead of forcing provider UI; that result becomes evidence for T11/T12/T14 and the T7/T8 procedure should be adjusted accordingly.

## Remaining client-decision semantics

### T5 — Session failure-boundary regression — DEFERRED

Requires a reproducible way to fail an already-acquired provider/private-key credential inside one live browser process after positive Session state exists. Post-login medium removal is proven insufficient in the current environment.

### T6 — real Permanent semantics

Implement/verify actual persistence distinct from the current process-local non-Once store. Positive choice should persist according to the intended Firefox permanent-remember behavior and be removable by the intended forget/change action. Negative/provider failures must not overwrite it.

## Provider/private-key media

### T9 — long provider wait

Hold provider/PIN/media UI beyond the ordinary picker-timeout scale. Record actual duration and check for network starvation, timeout corruption, or teardown materially worse than stock synchronous token/PIN behavior. Do not redesign MSSPI threading without a concrete regression.

## Picker presentation / discovery / policy

### T10 — Russian UI presentation

Verify human owner display name, localized expiry, Cyrillic issuer rendering, human-facing `Issued to`, human-friendly `Issued by`, and serial remaining details-only. Do not publish actual certificate identity values.

### T11 — dynamic `CurrentUser\MY`

Candidate discovery must be re-evaluated on new attempts; zero-candidate results cannot be sticky; a restored eligible certificate must reappear without browser restart.

### T12 — token/removable-media-only discovery

Determine whether current store discovery finds identities exposed only by provider/removable media. If not, provider discovery becomes required. Candidate enumeration itself must not trigger interactive provider/PIN/media UI.

### T13 — issuer/validity/KU/EKU/private-key suitability

Verify acceptable-CA, validity, KU/EKU, private-key availability/binding and wrong-certificate filtering using safe test identities where possible.

## Negative matrix

### T14 — no acceptable certificate

No sticky negative decision; later candidate restoration can recover.

### T15 — private-key/PIN failure

Failure remains attempt/provider-local and does not poison future certificate selection.

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