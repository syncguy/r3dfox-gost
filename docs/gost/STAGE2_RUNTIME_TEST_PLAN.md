# Stage 2 GOST TLS — Runtime Test Plan and Recovery Checkpoint

Last updated: 2026-08-28

Purpose: make the runtime campaign restart-safe. If a chat/session is lost, do **not** restart testing from the beginning. Read `AGENTS.md`, `PROJECT_STATE.md`, this file, and the active/relevant `TEST_LOG*` evidence. Resume at the first `NEXT` item below.

`STAGE2_PLAN.md` remains the security/architecture contract. `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes remain the detailed evidence record.

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

## Mandatory runtime preflight — REQUIRED before every SD/T result

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

### Profile isolation and launch

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

## Closed historical baselines — do not repeat on unchanged source

### T2R — PASS / F1 CLOSED

Source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`, run `33039013849`, job `98408139479`, artifact `9636591432`.

Three unanswered-picker timeout cycles prove closing handles cannot create/join replacement client-auth decisions, teardown removes waiters/decisions safely, stale UI callbacks are harmless, and retries recover without browser restart. The old sticky `selected=0` / `0x80090326` path is gone.

### T1R/T1R-B — PASS / F2 CLOSED

Same `ef1a7...` artifact. One positive `Once` choice feeds compatible connection waves, while an independent post-expiry attempt in the same browser process receives a new picker and new lease generation.

### GIS-G1/G2/G3 — PASS / F3 CLOSED

Same `ef1a7...` artifact. Generic coordinated client auth reaches `portalgisgmp.cert.roskazna.ru`, completes real TLS 1.2 / `0xFF85` GOST mTLS/application flow, and does not produce spurious client-auth UI on `pay.gov.ru` or `portalgisgmp.login.roskazna.ru`.

### S1/S1-B/S1-C + GIS-G4 — PASS / CLOSED

Same `ef1a7...` artifact. Positive explicit Session state is reused for matching Treasury handshakes within the process, remains isolated from a different GOST mTLS host, and is cleared by browser-process restart.

Detailed historical capture identities remain in `TEST_LOG.md` and `DONE.md`.

## Session-default exact-artifact regression — SD1-SD6 PASS / CLOSED

Exact source/run/artifact: `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Capture identities:

- `SD1.zip` SHA-256 `c0a1159c3e8d0869e54e2a07ddca1814dea24ff83677f2a201a8299b11f77f04`; inner log `19dc6a8c1ed0902c59e156e746df431b81e3fd77259c9a61209d73f86c1bceca`;
- `SD2.zip` SHA-256 `d399664ea66369ae3993d263ab625ede77030000f280ba59f5dca4d76f8d2656`; inner log `ec64a13a38bd1dc8d96088d7f25c879a91e8798d1d23e1bf2caeeed0a772236e`;
- `SD3.zip` SHA-256 `522de1961c9b1c906df1ab43117578e1a9816fa1bc8882898ab5a2ff3cbc69d9`; inner log `52424d90bc039782f455d9ded1d2cb40eecf4938b964d7272bea7cbdc2b51bcc`;
- `SD4.zip` SHA-256 `f9c47763a17e334a20ea941c0fb675bf012c1076c33fc69e382941611ceb9d1d`; inner log `e20a570fcc0cd07420c06c2b4d9efb1f40348ccf078ba531ede7189c5840ec99`;
- `SD5.zip` SHA-256 `9350a2a8b73011c5059f45a4d37835fbcb55c2473c1b80e05eb490b796d2d6d0`; inner log `1fdfc5477186df585ccfd7db7d7bdbc6becb11e5c2bad64793553755293421ed`.

Confirmed:

- **SD1 PASS:** default positive choice is Session (`remember=2`); one picker feeds successful Treasury mTLS and later matching requests use `scope=session`;
- **SD2 PASS:** same-process continuation adds no new picker/decision and later matching requests continue to use the Session decision;
- **SD3 PASS:** new browser process creates a fresh first decision/picker; old Session state does not cross the process boundary;
- **SD4 PASS:** explicit `Once` (`remember=0`) retains positive 5-second fanout and independent post-expiry requests create fresh decisions/new lease generations;
- **SD5 PASS:** active Treasury Session state does not leak to GIS GMP; the certificate endpoint creates its own fresh decision/picker and completes GOST mTLS independently;
- **SD6 PASS:** user visually confirms Session is selected by default and `Issued by` is human-readable as intended.

Every supplied SD1-SD5 capture has zero `E/GostTLS`, `selected=0`, `0x80090326`, `0x0000054f`, and `MSSPI_X509_LOOKUP`.

Do not repeat SD1-SD6 on unchanged source merely for confirmation.

## NEXT — T3 explicit Cancel / no certificate

Goal: prove a deliberate user decline is attempt-local and does not poison a later independent client-auth attempt.

Procedure on a new clean `profile-T3` after mandatory preflight:

1. Launch the exact authoritative artifact with the baseline GOST environment and a dedicated `T3` log path.
2. Navigate into the Treasury flow until the Firefox client-certificate picker appears.
3. Explicitly choose the picker action that declines/cancels client-certificate selection. Do not kill the process and do not simulate provider/media failure in T3.
4. Allow the current attempt to fail/continue naturally and preserve the resulting log state.
5. In the **same running browser process/profile**, start a new independent Treasury client-auth attempt after the first attempt has settled.
6. Require a **fresh picker** on that later attempt. A deliberate decline must not become a reusable sticky negative decision.
7. For the recovery half, select the intended certificate normally with the default Session choice and require successful Treasury GOST mTLS/application flow without restarting r3dfox.

Pass criteria:

- first user action is represented as explicit `Declined`/no-certificate semantics rather than involuntary `Aborted`;
- no positive Session or `Once` lease is stored from the declined decision;
- after the first attempt settles, a later independent request creates/receives a fresh decision/picker;
- recovery can complete real TLS 1.2 / `0xFF85` Treasury mTLS in the same browser process after a positive selection;
- no stale/orphan decision, sticky automatic `selected=0`, or unrelated GOST error poisons the recovery attempt.

If the first decline does not map cleanly to the expected explicit-decline state, stop and preserve the capture before proceeding to T4; do not reinterpret navigation teardown as a T3 pass.

## Remaining client-decision semantics

### T4 — involuntary Abort

Exercise navigation/tab/load teardown without a user decision. State must be `Aborted`, not reusable `Declined`; a later attempt must receive a fresh picker and recover.

### T5 — Session failure-boundary regression

S1/SD1-SD3 already prove positive Session process lifetime. Verify temporary provider failures and matching-policy boundaries do not overwrite, broaden, or leak an established positive Session decision.

### T6 — real Permanent semantics

Implement/verify actual persistence distinct from the current process-local non-Once store. Positive choice should persist according to the intended Firefox permanent-remember behavior and be removable by the intended forget/change action. Negative/provider failures must not overwrite it.

## Provider/private-key media

### T7 — missing key medium + provider Cancel

Certificate remains discoverable but CryptoPro private-key medium/container is unavailable. Cancel provider UI. Only the current attempt should fail; no negative certificate decision may poison later attempts.

### T8 — provider recovery without browser restart

Make the key medium available on retry. Handshake and protected login should succeed without restarting r3dfox.

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

T2R observed non-uniform picker timeout/poll behavior (`32.576`, `37.420`, `30.330 s`; quiescent poll counts `10,825`, `34`, `21`). Attribute the actual Firefox/Necko/load timer and first-cycle poll churn before changing timeout policy. This does not reopen F1/F2/F3 or SD1-SD6.

## Stop / escalation rules

- Do not repeat already-proven old-artifact tests unless explicitly regression-testing changed source.
- Mandatory preflight is required before every named runtime result.
- On failure, preserve the capture and stop the dependent branch rather than generating downstream noise.
- Build success never substitutes for runtime proof.
- Main and thunk-rs artifacts are not interchangeable for GOST conclusions.
- Keep Windows compatibility and bundled-extension testing separate from the GOST runtime matrix.
- After every meaningful runtime experiment, append `TEST_LOG.md` and update `PROJECT_STATE.md`, `TODO.md`, `DONE.md`, and this checkpoint when the blocker/current next step changes.