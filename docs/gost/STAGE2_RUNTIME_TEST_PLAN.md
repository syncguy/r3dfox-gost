# Stage 2 GOST TLS — Runtime Test Plan and Recovery Checkpoint

Last updated: 2026-08-27

Purpose: make the runtime campaign restart-safe. If a chat/session is lost, do **not** restart testing from the beginning. Read `AGENTS.md`, `PROJECT_STATE.md`, this file, and the active/relevant `TEST_LOG*` evidence. Resume at the first `NEXT` item below.

`STAGE2_PLAN.md` remains the security/architecture contract. `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes remain the detailed evidence record.

## Fixed runtime identity

Every runtime conclusion must record:

- exact source-under-test SHA;
- exact Actions run/attempt/job;
- exact browser artifact;
- runtime target;
- sanitized capture filename plus outer/inner SHA-256;
- user-visible result;
- sanitized protocol/lifecycle result.

Current authoritative GOST runtime browser:

- source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- main run `33039013849`, attempt 1;
- job `98408139479`;
- artifact `9636591432` (`r3dfox-gost-win64-release`);
- `r3dfox.exe` SHA-256 `ccd3ed44bc57345eb7821a949dd96a6b3c45c71b47f3a577da26fc1265481187`;
- `xul.dll` SHA-256 `8cee03269e18dff2bc48d5c25bef34a6c62c520908d937e3b3e4a03031d0ab68`.

The GOST coordinator is linked into `xul.dll`; when binary identity is uncertain, the local `xul.dll` hash is decisive.

Never publish client-certificate fingerprints/thumbprints, serials, identifying subject/issuer DNs, provider/container IDs, PIN/password data, private-key material, account data, raw personal-cabinet traffic or unsanitized captures.

Standard Treasury launch environment:

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

Real coordinated Treasury mTLS works and concurrent single-flight works, but one logical login required three sequential certificate pickers. Detailed hashes/timeline are in the historical test log.

### T2 old baseline — DONE, defect reproduced

Same old artifact. Unanswered picker teardown allowed `msspi_shutdown()` to create an orphan coordinated decision; later requests consumed `selected=0` and failed with `0x80090326` until browser restart.

Do not rerun this old defect reproduction.

## T2R — PASS / F1 CLOSED

Current artifact `9636591432`.

Capture:

- `t2r_timeout.zip` SHA-256 `88053089499fee19edf7506d4fe257567dcc688740741313ff9430749e84bba7`;
- inner `t2r.moz_log` SHA-256 `261ddf9a4008c212f1ee5b5ec2213ab0fb3ee6e6a244e586987ff04a8de8d5`.

Three unanswered-picker cycles prove:

- closing handles are rejected before coordinated decision create/join;
- each waiter/decision is cleaned up;
- stale UI callbacks are harmless;
- retries show fresh pickers without browser restart;
- no `selected=0`, `0x80090326`, `0x0000054f` or `MSSPI_X509_LOOKUP` recurrence.

F1 is formally closed. Do not repeat T2R on unchanged source.

## Invalid first T1R attempt — HISTORICAL TEST-IDENTITY ERROR

`t1r_error.zip` was later confirmed by the user to have been produced while accidentally running one of the older browser builds. It is not evidence for or against F2 and does not reopen F1.

Do not diagnose or change the current lease based on that capture.

## T1R — PASS

Current artifact `9636591432`, with exact local binary hashes verified before launch.

Capture:

- `t1r-current.zip` SHA-256 `1c75f484607a6e3eb95439275e2698098a04551689619f95f93f13ca890b248e`;
- inner `t1r-current.moz_log` SHA-256 `9f77de380e9ebf9b98f2e7cf2d3c0d6eb03233eb7afed0d103b2ecbf49bc78c7`.

User-visible result:

- one Firefox client-certificate picker on entry to the Treasury personal cabinet;
- default `Once` retained;
- intended certificate selected once;
- personal cabinet loads successfully;
- no second picker during the logical login; normal subsequent cabinet behavior.

Runtime result:

- 1 coordinated decision / 1 picker;
- 1 positive `Once` lease store (`idle_ms=5000`);
- 7 lease reuses without UI;
- reuse spans two follow-on waves: five requests around `08:43:59.635–08:43:59.669 UTC` and two at `08:44:02.577–08:44:02.588 UTC`;
- 8 successful `lk-fzs.roskazna.ru` TLS 1.2 / `0xFF85` mTLS handshakes, all with `client_cert_loaded=1`;
- 0 `selected=0`;
- 0 `0x80090326`;
- 0 `0x0000054f`;
- 0 `MSSPI_X509_LOOKUP`;
- 0 `E/GostTLS`.

The original repeated-picker symptom for one logical login is closed. Because every lease reuse refreshes its five-second idle expiry, expiry is measured from the **last** matching reuse, not from the initial picker.

## T1R-B — NEXT

Purpose: prove that default `Once` remains attempt-local and does not become Session/Permanent.

Precondition: same browser process/profile as a successful T1R whenever practical.

Procedure:

1. let all T1R GOST/network activity become quiet;
2. wait a clear margin beyond the 5-second idle lease, preferably about 10 seconds after the last matching GOST activity;
3. initiate an **independent** Treasury personal-cabinet login that causes a fresh client-auth handshake;
4. preserve a log for the attempt.

Pass criteria:

- a fresh Firefox certificate picker appears;
- the previous `Once` choice is not silently reused as Session/Permanent;
- a new positive choice, if selected, may create a new attempt-local lease normally;
- no negative/failure result becomes a lease.

If no picker appears, first prove that a new client-auth handshake actually occurred; an already-open/reused authenticated transport cannot by itself distinguish an expired lease from connection reuse.

If T1R-B passes, formally close F2, add it to `DONE.md`, and proceed to GIS-G1.

## GIS-G1 — AFTER T1R-B / F2 CLOSURE

Use `STAGE2_GIS_GMP.md`.

Pass for F3 reachability:

- GOST layer attaches to the real GIS GMP certificate host;
- generic client-cert callback is registered;
- the real server `CertificateRequest` reaches issuer collection;
- record the current acceptable-CA count;
- record candidate count.

If candidate count > 0, continue GIS-G2 real mTLS/application login. If candidate count == 0, stop and diagnose server CA identities, local chain matching, Windows chain/cross-sign selection, name comparison and provider/private-key filtering before changing issuer policy.

## Remaining client-decision semantics

Run after F2 and the immediate GIS branch are stable.

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

If the certificate is absent from `CurrentUser\MY` and exposed only by provider/removable media, determine whether current store discovery finds it. If not, provider discovery becomes required. Candidate enumeration itself must not trigger interactive provider/PIN/media UI.

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

Final exact source/build must prove together:

- final server trust succeeds;
- one correct Firefox client-cert UX interaction per logical default-`Once` attempt;
- compatible concurrent/sequential sockets safely receive the positive choice;
- completed mTLS proves private-key use;
- TLS 1.2 / expected GOST suite;
- authenticated protected application traffic;
- retry recovery without sticky negative state;
- no sensitive data published.

Record exact source SHA, run/attempt/job, artifact, capture hashes and sanitized conclusion.

## Separate non-blocking investigation

T2R observed non-uniform picker timeout/poll behavior (`32.576`, `37.420`, `30.330 s`; quiescent poll counts `10,825`, `34`, `21`). Attribute the actual Firefox/Necko/load timer and first-cycle poll churn before changing timeout policy. This does not reopen F1 and does not block T1R-B.

## Stop / escalation rules

- Do not repeat already-proven old-artifact tests unless explicitly regression-testing a changed source.
- On failure, preserve the capture and stop the dependent branch rather than generating downstream noise.
- Build success never substitutes for runtime proof.
- Main and thunk-rs artifacts are not interchangeable for GOST conclusions.
- Keep Windows compatibility and bundled-extension testing separate from the GOST runtime matrix.
- After every meaningful runtime experiment, append `TEST_LOG.md` and update `PROJECT_STATE.md` / `TODO.md` / this checkpoint when the blocker or next step changes.