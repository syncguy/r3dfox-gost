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

## Completed tests — do not repeat on the old artifact

### T1 — coordinated successful Treasury login — DONE

Build identity:

- source `860de8e38deed326b7fcd1c547e928c5b48c72a9`;
- main run `32951903026`, attempt 2;
- job `98130275465`;
- artifact `9606431408`.

Capture:

- `gost_main_test_connect.zip` SHA-256 `0756fe71a15ecd56a1576b026888b0a504fb941ab3958f1fda93653fc74c620b`;
- inner log SHA-256 `f77e68a5a2c1673500ef8542f12b5db46f6b93d5160e8203fe189eb1913eed89`.

User action/result:

- transition from `fzs.roskazna.ru` to the personal cabinet;
- default picker option `Once`;
- same intended certificate selected on all three visible prompts;
- personal cabinet visibly loaded.

Engineering result:

- real coordinated GOST mTLS works;
- 11 login-host TLS 1.2 / `0xFF85` handshakes complete with client certificate installed;
- two five-socket bursts each share one active decision/picker: concurrent single-flight is proven;
- no old `MSSPI_X509_LOOKUP` tight re-entry;
- defect: one logical login creates three sequential connection waves, and `Once` is discarded between waves, causing three sequential pickers.

Action: **do not rerun T1 on artifact `9606431408`**. T1 becomes T1R only after the positive `Once` fanout/lease fix.

### T2 — unanswered picker / timeout / retry — DONE, defect reproduced

Same build identity as T1.

Capture:

- `gost_timeout_260827.zip` SHA-256 `92f19f308bcc57394ad8f40d285d2e4934a5ee7d1707568d5c2507d2458909d9`;
- inner log SHA-256 `8dd16505df8095806d60eddcb1d92844b87c04e5caa253b1003a3010f640cda5`.

User action/result:

1. open login picker and make no choice;
2. picker eventually closes;
3. browser displays `The connection has timed out`;
4. F5 -> no picker;
5. `Try again` -> no picker;
6. return to main page and enter personal cabinet again -> still no picker.

Engineering result:

- picker request `02:56:22.161 UTC`;
- close begins `02:57:07.166 UTC`, ~45.005 s later;
- 13,107 nominally quiescent `GostPoll` calls (~291/s average) during the wait;
- zero `MSSPI_X509_LOOKUP` markers;
- close path removes the old waiter, then `msspi_shutdown()` re-enters the client-cert callback on the closing MSSPI handle;
- re-entrant callback creates a fresh decision/picker/waiter after the old decision has been removed;
- original callback is later correctly ignored as stale;
- shutdown-created waiter becomes orphaned;
- the orphan decision later becomes `Declined`;
- subsequent connections consume `selected=0` without opening a picker;
- ten later attempts receive primary `0x80090326` plus secondary `0x0000054f` diagnostics.

Action: **do not rerun T2 on artifact `9606431408`**. T2 becomes T2R only after the close/shutdown re-entrancy fix.

Important correction: do not assume the coordinated picker timeout is exactly 30 seconds. The tested old artifact closes at about 45 seconds. Attribute concrete timer behavior from the exact artifact being tested before changing timeout policy.

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

Build gates are complete. Runtime validation is in progress.

## T2R checkpoint — USER-VISIBLE PASS, LOG REVIEW PENDING

T2R was executed on the exact main artifact above using a newly created clean profile and the standard Treasury environment.

Observed in one browser process:

1. first picker left unanswered for approximately 30 seconds -> `The connection has timed out`;
2. F5 -> a fresh client-certificate picker appears;
3. second picker left unanswered for approximately 30 seconds -> timeout;
4. `Try again` -> another fresh client-certificate picker appears;
5. third picker left unanswered for approximately 30 seconds -> timeout.

This passes the user-visible F1 recovery criterion twice consecutively after two separate teardown cycles. The old sticky behavior where no later picker appeared without browser restart is gone at the UX level.

The exact `C:\Temp\r3dfox\t2r*` runtime capture has not yet been supplied. Therefore do **not** mark F1/T2R formally complete yet.

### NEXT — inspect the existing T2R capture

Do not rerun T2R merely to recreate the same UX result. Preserve and inspect the existing log from this exact session.

Required log-level pass criteria:

- closing MSSPI handle is marked before legacy `msspi_shutdown()`;
- any re-entrant client-cert callback for that closing handle is ignored before decision lookup/create/join;
- pre/post close waiter cleanup leaves no orphan waiter/decision;
- abandoned dialog callback is stale/harmless;
- later real requests create/join fresh decisions rather than consuming stale automatic `selected=0`;
- no old `MSSPI_X509_LOOKUP` tight re-entry returns;
- measure current `GostPoll client-auth wait quiescent` rate;
- record exact picker-to-close timings for all observed cycles.

The user's approximate ~30-second observation differs from the old exact ~45.005-second capture. Treat the new exact timestamps as authoritative for this artifact; do not infer a timer change before the log is read.

If the log-level criteria pass, formally close F1/T2R and proceed directly to T1R. If they fail despite the good UX result, preserve the discrepancy and fix the internal lifecycle before broadening the matrix.

## Regression tests on the fixing artifact

### T1R — one logical successful login should need one picker — NEXT AFTER T2R LOG CLOSURE

Purpose: prove F2 and re-prove real mTLS after F1/F2.

Procedure:

1. fresh browser process;
2. enter personal cabinet;
3. at the first picker leave default `Once`;
4. select the intended certificate once;
5. do not make additional manual selections unless a second picker unexpectedly appears;
6. observe complete cabinet load.

Pass criteria:

- one visible picker for the logical login attempt;
- compatible parallel and sequential waves reuse the same attempt-local positive `Once` decision safely;
- no queued/stale dialogs;
- all relevant mTLS handshakes succeed;
- protected application flow reaches the personal cabinet;
- after the logical attempt ends, the `Once` lease does not become browser-session remembered state.

If a second picker appears during the same login, capture the log and stop; do not manually work through many prompts unless specifically needed for diagnosis.

### T1R-B — `Once` must not become Session

After a successful T1R, start an **independent** new login attempt after the implemented positive lease is no longer active. Current candidate uses a 5-second idle lease, so allow a clear idle margin and document the actual sequence.

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

Run only after T2R and T1R pass.

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

Hold the CryptoPro media/PIN/provider UI beyond the ordinary picker timeout scale. Use the exact timing established by the current artifact's T2R capture rather than assuming the old ~45-second value; record actual duration. Then complete or cancel as planned.

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
