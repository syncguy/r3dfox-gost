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
- **T3 CLOSED:** explicit Firefox picker Cancel is Declined/phase `2`, attempt-local, and does not poison later recovery. The same capture also corroborates timeout cleanup from unresolved phase `0`.
- **T4 CLOSED:** closing the tab that owns an unanswered picker removes the still-unresolved decision through phase-0 lifecycle cleanup, not Declined state; another tab in the same browser process receives a fresh picker and successfully recovers.

T4 capture identity:

- `T4 involuntary Abort.zip` SHA-256 `bfa51cc1d45c35c8c94cae6a7eb8fc32c6490d30782cdb256a1aefb24078d2f1`;
- inner `SDx.moz_log` SHA-256 `f921c42d5e7b0299a40f79a5a707d5da93990018fb535edf529aef94a3d82f65`.

T4 decisive lifecycle facts: `decision=1` / `browser_id=14` is created at `03:43:37.496 UTC`; closing the owning tab removes it only `4.059 s` later via `close-pre`, `phase=0`, with closing/stale callbacks safely rejected and no `selected=0`/`declined-consume`. Same `Parent 6184`, new `browser_id=15`, fresh `decision=2` at `03:43:54.093`; positive `selected=1 remember=2` recovery then produces eight Session remembered hits and nine successful Treasury TLS 1.2 / `0xFF85` mTLS handshakes.

## NEXT — T5 Session failure-boundary regression

Goal: prove that an already-established positive Session decision cannot be erased, broadened, converted into a negative decision, or otherwise poisoned by a later attempt-local private-key/provider failure.

Preferred concrete experiment uses the missing-key-medium/provider-Cancel scenario already proven on an older source, now repeated on exact artifact `9652941006` **after Session state has first been established**.

Procedure on a new clean `profile-T5` after mandatory preflight:

1. Launch the exact authoritative artifact with the baseline environment and a dedicated `T5` log path.
2. Complete one normal Treasury login using the default Session choice. Keep the same browser process/profile alive.
3. Confirm at least one later matching client-auth request is served from `scope=session`; this establishes that the positive Session decision is active before fault injection.
4. Without changing the Firefox certificate decision, induce one controlled private-key/provider failure on a later matching Treasury attempt. Preferred method, when available in the current setup: make the private-key medium/container unavailable and/or cancel the provider key-access UI. **Do not use the Firefox certificate-picker Cancel**; that is T3.
5. Allow the failing attempt to settle. Record the provider/handshake failure class, but do not treat an expected current-attempt provider failure as sticky-state evidence by itself.
6. Restore the key medium/provider availability while keeping the same browser process/profile.
7. Start a new independent matching Treasury attempt.
8. Require the original Session decision to remain usable: ideally no fresh Firefox certificate picker appears, the coordinator records `scope=session`, and real TLS 1.2 / `0xFF85` Treasury mTLS plus protected application login succeeds.

Pass criteria:

- positive Session state is demonstrably active before fault injection;
- the controlled provider/key failure does not store Declined state, erase the Session decision, broaden it to another host/policy, or replace it with a different identity decision;
- failure remains local to the failing provider/private-key attempt;
- after provider/key availability returns, a later matching request in the same process/profile reuses the existing Session decision and completes real GOST mTLS;
- no browser restart is required for recovery;
- if the chosen fault is missing medium + provider Cancel and restoration/retry satisfies the older T7/T8 criteria, the same capture may close T5 plus T7/T8 together. Record the scopes explicitly rather than assuming combined closure.

If the current certificate/setup cannot produce a controlled provider/private-key failure safely, do not invent a synthetic failure mechanism merely to force T5. Preserve T5 as open and proceed only after a reproducible provider/key boundary is available.

## Remaining client-decision semantics

### T6 — real Permanent semantics

Implement/verify actual persistence distinct from the current process-local non-Once store. Positive choice should persist according to the intended Firefox permanent-remember behavior and be removable by the intended forget/change action. Negative/provider failures must not overwrite it.

## Provider/private-key media

### T7 — missing key medium + provider Cancel

Certificate remains discoverable but CryptoPro private-key medium/container is unavailable. Cancel provider UI. Only the current attempt should fail; no negative certificate decision may poison later attempts. May be closed together with T5 if T5 uses this exact fault after an active Session decision is established.

### T8 — provider recovery without browser restart

Make the key medium available on retry. Handshake and protected login should succeed without restarting r3dfox. May be closed together with T5 if the same capture proves Session-state preservation and provider recovery.

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