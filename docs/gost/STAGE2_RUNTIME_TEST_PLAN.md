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

Important correction: do not assume the coordinated picker timeout is exactly 30 seconds. The tested artifact closes at about 45 seconds. Attribute the concrete timer before changing timeout policy.

## Current implementation work before more user testing

### F1 — close/shutdown re-entrancy fix — BLOCKED ON CODE

Required behavior:

- mark handle/socket closing before `msspi_shutdown()`;
- client-cert callback for closing handle returns without decision lookup/create/join and without UI;
- defensive waiter cleanup after legacy close;
- no orphan decision after close;
- stale callback remains harmless;
- add concise lifecycle logs sufficient to prove this sequence.

### F2 — positive `Once` fanout/lease — BLOCKED ON CODE

Required behavior:

- concurrent single-flight already remains;
- one positive `Once` decision also covers compatible follow-on waves of the same logical login/navigation;
- next independent login asks again;
- no negative/abort/failure state enters the lease;
- explicit `Session` / `Permanent` remain separate user-selected policies.

F1 and F2 should be implemented as separable changes/commits. They may be present in one final full-build candidate to avoid wasting full-build time, provided logs/tests can still attribute each behavior independently.

### B1 — short compile gate — NEXT AFTER F1/F2

Run `GOST SSL compile check` against the exact final candidate source. Do not proceed if SSL target compilation fails.

### B2 — authoritative main full build — NEXT AFTER B1

Run `GOST TLS PoC build` and record exact run/attempt/job/artifact. Runtime testing uses the main artifact. The thunk-rs workflow is a separate Win7 line and is not a substitute for this gate.

## Regression tests on the next fixing artifact

### T2R — timeout teardown must recover — FIRST RUNTIME TEST

Purpose: prove F1 before spending time on the broader matrix.

Procedure:

1. fresh browser process using the standard environment above;
2. enter Treasury login until the certificate picker opens;
3. do not choose a certificate;
4. wait until the picker/load is torn down by the observed timeout mechanism; do not assume an exact duration, but record it;
5. record the timeout page/result;
6. without restarting the browser, use F5 or `Try again`;
7. if needed, return to the main Treasury page and enter the personal cabinet again.

Pass criteria:

- no client-cert decision is created from a closing MSSPI handle;
- no orphan waiter/decision survives teardown;
- any callback from the abandoned dialog is stale/aborted and cannot create negative reusable state;
- next real attempt opens a **fresh picker**;
- no automatic `selected=0` reuse;
- no sticky `0x80090326` sequence caused by the abandoned decision.

Also measure:

- actual unanswered-picker lifetime;
- total/rate of `GostPoll client-auth wait quiescent`;
- any `MSSPI_X509_LOOKUP` recurrence;
- whether timeout accounting needs a further stock-compatible integration fix.

If T2R fails, stop and fix lifecycle before asking for unrelated tests.

### T1R — one logical successful login should need one picker — SECOND RUNTIME TEST

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

After a successful T1R, start an **independent** new login attempt according to the implemented lease-generation boundary.

Pass criteria:

- a fresh picker appears for the independent attempt;
- previous `Once` selection is not treated as Session/Permanent.

The exact independent-attempt trigger (navigation generation, completed-login boundary, or other explicit lifecycle token) must match the implemented design and be documented with the fixing source.

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

Hold the CryptoPro media/PIN/provider UI beyond the ordinary picker timeout scale (use at least the currently observed ~45 s scale; record actual duration rather than assuming a hard boundary), then complete or cancel as planned.

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
