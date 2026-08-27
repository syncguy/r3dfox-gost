# Stage 2 GOST TLS — Runtime Test Plan and Recovery Checkpoint

Last updated: 2026-08-27

Purpose: make the runtime campaign restart-safe. If a chat/session is lost, do **not** restart testing from the beginning. Read `AGENTS.md`, `PROJECT_STATE.md`, this file, and the active/relevant `TEST_LOG*` evidence. Resume at the first `NEXT` item below.

`STAGE2_PLAN.md` remains the security/architecture contract. `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes remain the detailed evidence record.

## Fixed runtime identity

Current authoritative GOST runtime browser:

- source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- main run `33039013849`, attempt 1;
- job `98408139479`;
- artifact `9636591432` (`r3dfox-gost-win64-release`);
- `r3dfox.exe` SHA-256 `ccd3ed44bc57345eb7821a949dd96a6b3c45c71b47f3a577da26fc1265481187`;
- `xul.dll` SHA-256 `8cee03269e18dff2bc48d5c25bef34a6c62c520908d937e3b3e4a03031d0ab68`.

The GOST coordinator is linked into `xul.dll`; when binary identity is uncertain, the local `xul.dll` hash is decisive.

Every runtime conclusion must record exact source SHA, run/attempt/job, browser artifact, sanitized capture hashes, user-visible result and sanitized protocol/lifecycle result. Never publish client-certificate identifiers, credential/provider/container data, PIN/passwords, private-key material, account data or unsanitized captures.

Standard Treasury launch environment remains:

```bat
set "R3DFOX_GOST_HOSTS=fzs.roskazna.ru,lk-fzs.roskazna.ru"
set "R3DFOX_GOST_CLIENT_CERT_THUMBPRINT="
set "R3DFOX_GOST_CLIENT_AUTH_MODE="
set "R3DFOX_GOST_CIPHERS="

r3dfox.exe -no-remote ^
  -profile C:\Temp\r3dfox\profile ^
  --MOZ_LOG=timestamp,sync,GostTLS:5 ^
  --MOZ_LOG_FILE=C:\Temp\r3dfox\gost ^
  https://fzs.roskazna.ru/
```

## Completed historical baseline tests — do not repeat

### T1 old baseline — DONE

Source `860de8e38deed326b7fcd1c547e928c5b48c72a9`, run `32951903026` attempt 2, job `98130275465`, artifact `9606431408`.

Real coordinated Treasury mTLS and concurrent single-flight work, but one logical login required three sequential certificate pickers.

### T2 old baseline — DONE, defect reproduced

Same old artifact. Unanswered picker teardown allowed `msspi_shutdown()` to create an orphan coordinated decision; later requests consumed `selected=0` and failed with `0x80090326` until browser restart.

Do not rerun this old defect reproduction.

## T2R — PASS / F1 CLOSED

Current artifact `9636591432`.

Capture:

- `t2r_timeout.zip` SHA-256 `88053089499fee19edf7506d4fe257567dcc688740741313ff9430749e84bba7`;
- inner `t2r.moz_log` SHA-256 `261ddf9a4008c212f1ee5b5ec2213ab0fb3ee6e6a244e586987ff04a8de8d5`.

Three unanswered-picker cycles prove closing handles are rejected before decision create/join, waiters/decisions are cleaned up, stale UI callbacks are harmless, retries recover without browser restart, and the old sticky `selected=0` / `0x80090326` path is gone. F1 is formally closed.

## Invalid first T1R attempt — HISTORICAL TEST-IDENTITY ERROR

`t1r_error.zip` was later confirmed by the user to have been produced while accidentally running an older browser build. It is not evidence for or against current F2 and does not reopen F1.

## T1R — PASS

Current artifact `9636591432`, exact local binary hashes verified before launch.

Capture:

- `t1r-current.zip` SHA-256 `1c75f484607a6e3eb95439275e2698098a04551689619f95f93f13ca890b248e`;
- inner `t1r-current.moz_log` SHA-256 `9f77de380e9ebf9b98f2e7cf2d3c0d6eb03233eb7afed0d103b2ecbf49bc78c7`.

Pass result:

- one Firefox client-certificate picker for one complete Treasury login;
- one positive default-`Once` lease store;
- seven lease reuses across sequential follow-on waves without additional UI;
- eight successful `lk-fzs.roskazna.ru` TLS 1.2 / `0xFF85` mTLS handshakes with `client_cert_loaded=1`;
- protected personal cabinet loads and behaves normally;
- zero sticky negative/failure markers.

This closes the original repeated-picker symptom within one logical login.

## T1R-B — PASS / F2 CLOSED

Capture:

- `T1R-B-current.zip` SHA-256 `c2d018b8637467b4c1368bfa66399dd042d73b88c39c6de7bf07368c7524ea65`;
- inner `t1r-current.moz_log` SHA-256 `c30c9f61e008d8bdb321570373c1c5cf6f3bc9eaa9e980564d463d03e307686e`.

Same browser process (`Parent 6204`) and same browser context (`browser_id=14`) contain two independent logical client-auth attempts.

First attempt:

- decision 1 / picker at `09:07:05.459 UTC`;
- generation 1 stored at `09:07:07.998`;
- generation 1 reused 11 times;
- final reuse `09:07:13.004`;
- nominal idle expiry `09:07:18.004`.

Independent post-expiry attempt:

- real client-auth request at `09:09:44.169 UTC`, 151.165 s after final generation-1 reuse and 146.165 s after nominal expiry;
- fresh `decision=2` created;
- fresh Firefox certificate picker requested;
- no automatic generation-1 reuse occurs for the new request;
- new positive choice stores generation 2 at `09:09:46.616`;
- new attempt completes TLS 1.2 / `0xFF85` mTLS with `client_cert_loaded=1`.

Whole capture: 2 decisions, 2 picker requests, 2 lease stores, 11 generation-1 reuses, 14 successful login-host mTLS handshakes, zero `selected=0`, `0x80090326`, `0x0000054f`, `MSSPI_X509_LOOKUP`, stale callbacks or `E/GostTLS`.

**F2 is formally closed.** Default `Once` is positive attempt-local fanout, not Session/Permanent: compatible waves reuse within the idle lease; an independent post-expiry request asks again.

Do not repeat T1R/T1R-B on unchanged source merely for confirmation.

## GIS-G1 — NEXT / F3 CURRENT BLOCKER

Use `STAGE2_GIS_GMP.md` and the same authoritative artifact `9636591432`.

Old artifact `9606431408` already proved the GIS GMP path reaches `portalgisgmp.cert.roskazna.ru`, which sends a real TLS 1.2 `CertificateRequest`; the old Treasury-only callback scope then caused an empty client Certificate and server `handshake_failure` / `0x80090326`.

Current source contains the F3 generic callback-registration/dispatch candidate. GIS-G1 must prove on the real certificate endpoint:

- GOST layer attaches;
- generic client-cert callback is registered;
- the real server `CertificateRequest` reaches issuer collection;
- record current acceptable-CA count; do not assume the old value 36;
- record current local candidate count.

Branch:

- if candidate count > 0, continue GIS-G2 real mTLS/application login;
- if candidate count == 0, stop and diagnose server CA identities, local chain matching, Windows chain/cross-sign selection, name comparison and provider/private-key filtering before changing issuer policy.

## Remaining client-decision semantics

Run after the immediate GIS branch is stable.

### T3 — explicit no-certificate / Cancel

Current attempt may fail/continue as appropriate; later independent attempt must show a fresh picker. Distinguish explicit `Declined` from involuntary `Aborted`.

### T4 — involuntary Abort

Exercise navigation/tab/load teardown without a user decision. State must be `Aborted`, not reusable `Declined`; later attempt must recover.

### T5 — explicit Session

Compatible later logins in the same browser process should reuse the positive selected certificate without repeated picker; browser process restart must clear session-only behavior.

### T6 — explicit Permanent

Positive choice should persist according to Firefox permanent remember semantics and be removable by the intended user/Firefox forget/change action. Negative/provider failures must not overwrite it.

## Provider/private-key media

### T7 — missing key medium + provider Cancel

Certificate remains discoverable but CryptoPro private-key medium/container is unavailable. Cancel provider UI. Only the current attempt should fail; no negative certificate decision may poison later attempts.

### T8 — provider recovery without browser restart

Make the key medium available on retry. Handshake and protected login should succeed without restarting r3dfox.

### T9 — long provider wait

Hold provider/PIN/media UI beyond the ordinary picker-timeout scale. Record actual duration and check for network starvation, timeout corruption or teardown materially worse than stock synchronous token/PIN behavior. Do not redesign MSSPI threading without a concrete regression.

## Picker presentation

### T10 — Russian UI presentation

Verify human owner display name, localized expiry, Cyrillic issuer rendering, human-facing `Issued to`, and serial remaining details-only. Do not publish actual certificate identity values.

## Candidate discovery / policy

### T11 — dynamic `CurrentUser\MY`

Candidate discovery must be re-evaluated on new attempts; zero-candidate results cannot be sticky; restored eligible certificate must reappear without browser restart.

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

Final exact source/build must prove together final server trust, one correct default-`Once` UX interaction per logical attempt, safe compatible fanout, completed mTLS/private-key use, expected GOST suite, authenticated protected application traffic, retry recovery and no sensitive data publication.

## Separate non-blocking investigation

T2R observed non-uniform picker timeout/poll behavior (`32.576`, `37.420`, `30.330 s`; quiescent poll counts `10,825`, `34`, `21`). Attribute the actual Firefox/Necko/load timer and first-cycle poll churn before changing timeout policy. This does not reopen F1/F2 and does not block GIS-G1.

## Stop / escalation rules

- Do not repeat already-proven old-artifact tests unless explicitly regression-testing a changed source.
- On failure, preserve the capture and stop the dependent branch rather than generating downstream noise.
- Build success never substitutes for runtime proof.
- Main and thunk-rs artifacts are not interchangeable for GOST conclusions.
- Keep Windows compatibility and bundled-extension testing separate from the GOST runtime matrix.
- After every meaningful runtime experiment, append `TEST_LOG.md` and update `PROJECT_STATE.md` / `TODO.md` / this checkpoint when the blocker or next step changes.