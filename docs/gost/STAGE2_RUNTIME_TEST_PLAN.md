# Stage 2 GOST TLS — Runtime Test Plan and Recovery Checkpoint

Last updated: 2026-08-27

Purpose: make the runtime campaign restart-safe. If a chat/session is lost, do **not** restart testing from the beginning. Read `AGENTS.md`, `PROJECT_STATE.md`, this file, and the active/relevant dated `TEST_LOG`. Resume at the first `NEXT` / `BLOCKED` item whose prerequisite fix/build exists.

This document is the operational runtime-test sequence. `STAGE2_PLAN.md` remains the security/architecture contract; `TEST_LOG*` files remain the evidence record.

## Fixed test identity rules

Every runtime conclusion must record:

- exact source-under-test SHA;
- exact Actions run ID / attempt / job ID;
- exact browser artifact ID/name;
- runtime target;
- sanitized capture filename + SHA-256 and inner log SHA-256;
- user-visible result;
- sanitized protocol/lifecycle result.

Never publish client-certificate fingerprint/thumbprint, serial, identifying subject/issuer DN, provider/container identifier, PIN/password, private-key material, account data or raw personal-cabinet traffic.

For Windows `cmd.exe`, clear test variables with quoted syntax:

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

No unquoted `set NAME =` forms: the space becomes part of the environment-variable name in `cmd.exe`.

## Completed old-baseline tests — do not repeat

### T1 — coordinated successful Treasury login — DONE

Build identity:

- source `860de8e38deed326b7fcd1c547e928c5b48c72a9`;
- main run `32951903026`, attempt 2;
- job `98130275465`;
- artifact `9606431408`.

Capture:

- `gost_main_test_connect.zip` SHA-256 `0756fe71a15ecd56a1576b026888b0a504fb941ab3958f1fda93653fc74c620b`;
- inner log SHA-256 `f77e68a5a2c1673500ef8542f12b5db46f6b93d5160e8203fe189eb1913eed89`.

Engineering result:

- real coordinated GOST mTLS works;
- 11 login-host TLS 1.2 / `0xFF85` handshakes complete with client certificate installed;
- concurrent single-flight is proven;
- defect: one logical login creates three sequential connection waves and asks three times with default `Once`.

Action: do not rerun T1 on artifact `9606431408`; use T1R on the fixing artifact.

### T2 — unanswered picker / timeout / retry — DONE, old defect reproduced

Same old build identity as T1.

Capture:

- `gost_timeout_260827.zip` SHA-256 `92f19f308bcc57394ad8f40d285d2e4934a5ee7d1707568d5c2507d2458909d9`;
- inner log SHA-256 `8dd16505df8095806d60eddcb1d92844b87c04e5caa253b1003a3010f640cda5`.

Old engineering result:

- picker closed after ~45.005 s;
- close removed the original waiter, then `msspi_shutdown()` re-entered the client-cert callback;
- re-entry created a fresh decision/waiter for a closing handle;
- that waiter became orphaned and later terminal `Declined`;
- later requests consumed `selected=0` and failed with `0x80090326` until browser restart.

Action: do not repeat T2 on the old artifact. F1 is now closed by T2R below.

## Current fixing candidate / build identity

Current source-under-test:

- source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea` (`fix(gost): harden coordinated client auth lifecycle`);
- short SSL compile run `33039013892`, job `98408139567`, success;
- authoritative main full build run `33039013849`, attempt 1, job `98408139479`, success;
- main runtime artifact `9636591432` (`r3dfox-gost-win64-release`);
- separate thunk-rs run `33039013822`, job `98408139313`, success, browser artifact `9636047031`.

The main artifact is the only artifact used for the GOST runtime conclusions below. The thunk-rs artifact belongs to the independent Windows compatibility line.

Candidate source contains:

- **F1:** close/shutdown closing-handle guard and defensive waiter cleanup;
- **F2:** positive-only default-`Once` fanout lease with a 5-second idle lifetime;
- **F3:** generic GOST mTLS client-cert callback registration/dispatch for already-selected GOST sockets rather than Treasury-only normal coordinated reachability.

## T2R — PASS / F1 CLOSED

Runtime capture:

- `t2r_timeout.zip` SHA-256 `88053089499fee19edf7506d4fe257567dcc688740741313ff9430749e84bba7`;
- inner `t2r.moz_log` SHA-256 `261ddf9a4008c212f1ee5b5ec2213ab0fb3ee6e6a244e586987ff04a8de8d5`.

Three unanswered-picker cycles were exercised in one browser process. F5 after cycle 1 and `Try again` after cycle 2 each produced a fresh picker.

Exact picker-to-close intervals:

- cycle 1: `32.576 s`;
- cycle 2: `37.420 s`;
- cycle 3: `30.330 s`.

Exact lifecycle proof across all three cycles:

- 3 decisions created, 3 decisions removed;
- 3 active waiters removed pre-close, each reaching `waiters=0`;
- 3 shutdown-time client-cert callbacks rejected with `reason=closing` before decision creation/join;
- 3 abandoned picker callbacks later rejected as stale;
- no shutdown-created replacement decision or orphan waiter;
- `selected=0`: 0;
- `0x80090326`: 0;
- `0x0000054f`: 0;
- `MSSPI_X509_LOOKUP`: 0.

`GostPoll client-auth wait quiescent` counts were `10,825`, `34`, and `21` for the three cycles. The first cycle still has substantial poll churn while later cycles are near one call per second. Timeout/poll attribution remains separate non-blocking work; it does not reopen F1.

**Do not repeat T2R on this source merely for confirmation.** F1 is formally closed for the tested path.

## Regression tests on the fixing artifact

### T1R — one logical successful login should need one picker — NEXT

Purpose: prove F2 and re-prove real mTLS after F1/F2.

Procedure:

1. start a fresh browser process using the standard Treasury environment;
2. enter the personal cabinet;
3. at the first Firefox certificate picker leave the default `Once` behavior;
4. select the intended certificate exactly once;
5. do not make additional manual selections if another picker unexpectedly appears; preserve the log instead;
6. observe whether the protected personal cabinet completes loading.

Pass criteria:

- exactly one visible picker for the logical login attempt;
- compatible parallel and sequential waves reuse the same attempt-local positive `Once` decision safely;
- no queued/stale dialogs;
- all relevant GOST mTLS handshakes succeed;
- protected application flow reaches the personal cabinet;
- no negative/abort/failure result becomes a positive lease.

If a second picker appears during the same login, capture the log and stop; do not manually work through repeated prompts unless specifically needed for diagnosis.

### T1R-B — `Once` must not become Session — IMMEDIATELY AFTER T1R PASS

After the successful T1R network activity is quiet, allow a clear margin beyond the current 5-second idle lease (for example about 8–10 seconds), then start an independent new login attempt in the same browser process.

Pass criteria:

- a fresh picker appears for the independent attempt;
- previous `Once` selection is not treated as Session/Permanent.

### GIS-G1 — generic GIS GMP mTLS reachability — AFTER T1R/T1R-B

Use the GIS GMP sequence in `STAGE2_GIS_GMP.md`.

Pass for F3 reachability:

- certificate host gets the GOST layer;
- generic client-cert callback is registered for the real certificate host;
- real server `CertificateRequest` reaches our callback;
- acceptable-CA collection records an explicit current count;
- candidate enumeration records an explicit count;
- host no longer sends an empty client Certificate merely because it differs from `lk-fzs.roskazna.ru`.

If candidate count > 0, continue GIS-G2. If candidate count == 0, stop and diagnose issuer/chain/name matching before changing policy.

## Client decision semantics

Run after T1R/T1R-B and the immediate GIS-G1 branch as appropriate.

### T3 — explicit no-certificate / Cancel

Procedure: open picker, explicitly decline/no-certificate using the supported UI action, then initiate a new login.

Pass:

- current attempt may fail/continue without client auth as appropriate;
- no negative choice poisons later attempts;
- next login shows a fresh picker;
- distinguish explicit `Declined` from involuntary `Aborted` in logs/state.

### T4 — involuntary Abort

Exercise navigation/tab/load teardown without a user certificate decision.

Pass:

- state is `Aborted`, not reusable `Declined`;
- later attempt shows a fresh picker;
- stale callback cannot mutate current state.

### T5 — explicit Session

Choose certificate with `Session`.

Pass:

- compatible later logins in the same browser process reuse only the positive selected certificate as intended;
- no repeated picker in-session for matching policy;
- temporary provider failure does not overwrite the positive decision;
- browser process restart clears session-only behavior.

### T6 — explicit Permanent

Choose certificate with `Permanent`.

Pass:

- positive decision persists according to Firefox permanent remember semantics for the same profile;
- process restart does not unexpectedly lose it;
- user/Firefox forget/change action removes it correctly;
- no negative/provider failure overwrites it.

## Provider/private-key media

Run after coordinator lifecycle/remember semantics are stable.

### T7 — missing key medium + provider Cancel

Precondition: client certificate remains discoverable but referenced CryptoPro private-key medium/container is absent.

Procedure:

1. select the certificate;
2. CryptoPro requests the key medium;
3. Cancel provider UI;
4. start a new login in the same browser.

Pass:

- only current TLS attempt fails with the provider/no-credentials class;
- no negative Firefox/GOST certificate decision is created;
- default `Once` asks again on the next independent attempt;
- explicit Session/Permanent, when separately tested, retains the positive certificate decision.

### T8 — provider recovery without browser restart

After T7, retry and make the key medium available when CryptoPro asks.

Pass:

- handshake resumes and completes;
- mTLS proves actual private-key use;
- cabinet/login succeeds without restarting r3dfox.

### T9 — long provider wait

Hold the CryptoPro media/PIN/provider UI beyond the ordinary picker-timeout scale. T2R observed `30.330–37.420 s`, but this is not a proven fixed timer; use a deliberate longer wait and record actual duration rather than treating any one value as policy.

Observe:

- whether synchronous provider UI causes global network starvation;
- timeout corruption;
- connection teardown;
- behavior materially worse than Firefox's stock synchronous token/PIN precedent.

Only promote async MSSPI/provider redesign to a blocker if this test proves a concrete regression. Do not move one live MSSPI handle between threads casually.

## Picker presentation

### T10 — Russian UI presentation

Verify in the real Russian UI:

- compact row uses human owner display name;
- localized expiration date;
- `issuerCommonName` renders Cyrillic correctly;
- `Issued to` shows the human-facing display name;
- serial number remains details-only.

Do not copy identifying certificate values into repository documentation; record only rendering correctness.

## Candidate discovery / policy

### T11 — dynamic `CurrentUser\MY`

With browser still running, remove/restore or otherwise change an eligible certificate in a controlled way.

Pass:

- candidate discovery is re-evaluated on new attempts;
- zero-candidate result is not sticky;
- restored eligible certificate appears without browser restart.

### T12 — token/removable-media-only discovery

Focused test:

- certificate absent from `CurrentUser\MY`;
- only provider/removable medium contains/exposes the identity.

Outcome:

- if current store view discovers it, no direct CSP/KSP enumeration is required for that environment;
- if not, implement provider discovery and later rerun;
- deduplicate identical certificates across sources;
- candidate enumeration itself must not trigger interactive provider/PIN/media UI.

### T13 — issuer/validity/KU/EKU/private-key suitability

Use safe available test identities where possible.

Verify candidate policy for:

- server acceptable-CA list;
- expired/not-yet-valid;
- unsuitable KU/EKU;
- missing/unavailable private-key binding;
- wrong certificate.

No unsafe credential data goes into logs/docs.

## Negative matrix

### T14 — no acceptable certificate

Pass: no sticky negative decision; later candidate restoration can recover.

### T15 — private-key/PIN failure

Pass: failure is attempt/provider-local and does not poison future client-cert selection.

### T16 — server rejects client identity

Pass: server rejection is surfaced as the real TLS/auth failure and does not become remembered no-certificate state.

## Server-trust closure

This is mandatory before Stage 2 is complete.

### T17 — valid Treasury server

With final fail-closed verifier/override/cache implementation, valid Treasury hostname/chain succeeds.

### T18 — wrong hostname

Must fail closed. No client private-key operation may occur before server trust.

### T19 — invalid/untrusted chain

Must fail closed. No positive session trust cache entry may be created.

### T20 — Firefox certificate override

Verify intended temporary/permanent override integration and exact server-identity scoping.

## Final regression

### T21 — final Treasury mTLS acceptance

Use the final candidate source/build and a sanitized capture.

Must prove together:

- server trust accepted by the final policy;
- one correct Firefox client-certificate UX interaction per logical attempt under default `Once`;
- concurrent/sequential compatible sockets safely receive the positive selection;
- actual private-key use via completed mTLS;
- TLS 1.2 / expected GOST suite;
- authenticated protected application traffic;
- no sticky negative state after retries;
- no sensitive data published.

Record exact source SHA, main Actions run/attempt/job, artifact ID, capture hashes and sanitized conclusion.

## Stop / escalation rules

- Do not ask the user to repeat an already-proven old-artifact test unless it is explicitly a regression test for a new source.
- On failure, preserve the capture and stop the dependent branch of the matrix; do not continue generating noisy downstream failures.
- Build success never substitutes for runtime proof.
- Main and thunk-rs artifacts are not interchangeable for GOST conclusions.
- Do not mix Win7 and extension testing into the Stage 2 GOST runtime matrix.
- After every meaningful runtime experiment, append evidence to `TEST_LOG.md` and update `PROJECT_STATE.md` / this plan if the blocker or next step changes.
