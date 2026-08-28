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

The exact run is successful and is the authoritative full-browser build/package candidate for the Session-default regression.

Exact binary identity for artifact `9652941006`:

- `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`;
- `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`.

These hashes were independently checked against the official `r3dfox-v153.0.3.win64.zip` contained in GitHub Actions artifact `9652941006` and match the user's local `certutil -hashfile ... SHA256` preflight. The GOST coordinator is linked into `xul.dll`, so its hash is decisive when binary identity is uncertain.

## Mandatory runtime preflight — REQUIRED before every SD/T result

A runtime result is valid only after the preflight below has passed. If any required item is missing or mismatched, do not interpret the runtime log as evidence for the named test.

### Binary identity

Before starting a new independent runtime test sequence, verify the launched files:

```bat
certutil -hashfile r3dfox.exe SHA256
certutil -hashfile xul.dll SHA256
```

For the current authoritative artifact `9652941006`, they must equal:

- `r3dfox.exe` — `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`;
- `xul.dll` — `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`.

Any mismatch makes the test invalid until the correct browser is launched.

### GOST environment

Use this baseline environment unless a named test explicitly requires a different override:

```bat
set "R3DFOX_GOST_HOSTS=fzs.roskazna.ru,lk-fzs.roskazna.ru,pay.gov.ru,portalgisgmp.login.roskazna.ru,portalgisgmp.cert.roskazna.ru"
set "R3DFOX_GOST_CLIENT_CERT_THUMBPRINT="
set "R3DFOX_GOST_CLIENT_AUTH_MODE="
set "R3DFOX_GOST_CIPHERS="
```

The empty diagnostic variables are intentional: the default coordinated client-auth path and default GOST cipher configuration must be exercised unless the test explicitly says otherwise.

### Profile isolation and launch

Start each **independent** test sequence from a new clean profile path that has not previously been used, for example `C:\Temp\r3dfox\profile-SD1` or another profile named for the exact test/sequence. Do not silently reuse an old profile.

Use the matching per-test log path:

```bat
r3dfox.exe -no-remote ^
  -profile C:\Temp\r3dfox\profile-SDx ^
  --MOZ_LOG=timestamp,sync,GostTLS:5 ^
  --MOZ_LOG_FILE=C:\Temp\r3dfox\SDx ^
  https://fzs.roskazna.ru/
```

A dependent test whose purpose is to observe state continuity must intentionally reuse the required process/profile instead of creating a new one. In particular:

- SD1 -> SD2 must remain in the same running browser process/profile;
- SD3 must fully terminate that browser process and relaunch the same exact artifact with the **same SD1/SD2 profile**, otherwise a fresh-profile launch would not test the Session restart boundary;
- SD4 must preserve one process/profile across the initial `Once` choice, compatible fanout, idle expiry, and the independent post-expiry attempt;
- SD5 must establish Treasury Session state and test GIS GMP cross-host isolation in the same running process/profile.

For other independent SD/T tests, begin with a new clean test-specific profile unless the test definition explicitly requires continuity.

### Evidence identity rule

Every recorded SD/T result must state or be recoverably bound to:

- source-under-test SHA;
- Actions run ID and job ID;
- browser artifact ID;
- exact `r3dfox.exe` and `xul.dll` SHA-256 values;
- test/profile identity;
- whether the baseline environment above was used or which explicit override the test required;
- sanitized runtime capture/log hash when a capture is retained.

Do not publish client-certificate identifiers, credential/provider/container data, PIN/passwords, private-key material, account data or unsanitized captures.

## Completed historical baseline tests — do not repeat

### T1 old baseline — DONE

Source `860de8e38deed326b7fcd1c547e928c5b48c72a9`, run `32951903026` attempt 2, job `98130275465`, artifact `9606431408`.

Real coordinated Treasury mTLS and concurrent single-flight work, but one logical login required three sequential certificate pickers.

### T2 old baseline — DONE, defect reproduced

Same old artifact. Unanswered picker teardown allowed `msspi_shutdown()` to create an orphan coordinated decision; later requests consumed `selected=0` and failed with `0x80090326` until browser restart.

Do not rerun this old defect reproduction.

## T2R — PASS / F1 CLOSED

Runtime-proven artifact `9636591432`, source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`, main run `33039013849`, job `98408139479`.

Capture:

- `t2r_timeout.zip` SHA-256 `88053089499fee19edf7506d4fe257567dcc688740741313ff9430749e84bba7`;
- inner `t2r.moz_log` SHA-256 `261ddf9a4008c212f1ee5b5ec2213ab0fb3ee6e6a244e586987ff04a8de8d5`.

Three unanswered-picker cycles prove closing handles are rejected before decision create/join, waiters/decisions are cleaned up, stale UI callbacks are harmless, retries recover without browser restart, and the old sticky `selected=0` / `0x80090326` path is gone. F1 is formally closed.

## Invalid first T1R attempt — HISTORICAL TEST-IDENTITY ERROR

`t1r_error.zip` was later confirmed by the user to have been produced while accidentally running an older browser build. It is not evidence for or against current F2 and does not reopen F1.

## T1R — PASS

Runtime-proven artifact `9636591432`, exact local binary hashes verified before launch.

Capture:

- `t1r-current.zip` SHA-256 `1c75f484607a6e3eb95439275e2698098a04551689619f95f93f13ca890b248e`;
- inner `t1r-current.moz_log` SHA-256 `9f77de380e9ebf9b98f2e7cf2d3c0d6eb03233eb7afed0d103b2ecbf49bc78c7`.

Pass result: one picker, one positive `Once` lease store, seven lease reuses across sequential waves, eight successful Treasury mTLS handshakes, protected application success, zero sticky failure markers.

## T1R-B — PASS / F2 CLOSED

Capture:

- `T1R-B-current.zip` SHA-256 `c2d018b8637467b4c1368bfa66399dd042d73b88c39c6de7bf07368c7524ea65`;
- inner `t1r-current.moz_log` SHA-256 `c30c9f61e008d8bdb321570373c1c5cf6f3bc9eaa9e980564d463d03e307686e`.

Same-process post-expiry login creates a fresh decision/picker rather than reusing the expired generation. F2 is formally closed. Do not repeat T1R/T1R-B on unchanged source merely for confirmation.

## GIS-G1/G2/G3 — PASS / F3 CLOSED

Capture:

- `gis-g1-g2-g3.zip` SHA-256 `8bb1fd3cfb6773739f0c9b05fd31555eef4180d65ce0518d54a63c85691558ce`;
- inner `gis-g1.moz_log` SHA-256 `451ed230a972b19ec35c1edc8952d1b234366ac5775c7252e8e67a92a289f1b1`.

Proven:

- generic callback reaches the real `portalgisgmp.cert.roskazna.ru` client-auth request;
- current acceptable-CA count `36`, candidate count `1`;
- one picker leads to real GIS GMP TLS 1.2 / `0xFF85` mTLS/application success;
- four compatible follow-on requests reuse the positive `Once` lease;
- non-mTLS GOST hosts do not show spurious picker UI.

F3 is formally closed. Do not repeat GIS-G1/G2/G3 on unchanged source merely for confirmation.

## S1/S1-B/S1-C — PASS / explicit Session process lifetime CLOSED

In-process capture:

- `session-current.zip` SHA-256 `6eccbf7d49e69a92d9634507b111759f096c4dee00a0313ec3d7c20017f5dec1`;
- inner `session-current.moz_log` SHA-256 `b3b2c8751e1f0cf66cfda73a1c068f609efb1692ade910b0d4ffcb42ff4905f8`;
- browser process `Parent 6200`.

Treasury result:

- decision `1` / first picker at `11:36:28.521 UTC`;
- explicit `Session` resolves at `11:36:33.382`, `remember=2`;
- ten later matching client-auth requests consume `scope=session` without a second Treasury picker;
- eleven Treasury TLS 1.2 / `0xFF85` mTLS handshakes complete with `client_cert_loaded=1`;
- user confirms the active Session remains usable across tabs and browser windows in the same running browser process.

The logged Treasury client-auth requests all carry `browser_id=14`; the raw log therefore proves process-level matching remembered reuse, while the tab/window topology is user-observed rather than separately represented by distinct browser IDs.

Restart-boundary capture:

- `session-current2.zip` SHA-256 `e32b71ca51d151e553ab82c321fd8f829270e09b6a8390f7fb3ea828af3a29e7`;
- inner `session-current.moz_log` SHA-256 `5b156cf0765c9aad3ceffeac6d1a845cea381f219ea168d59b318201b9f419b5`;
- restarted process `Parent 5112`.

The first Treasury client-auth in the restarted process at `12:05:43.453 UTC` receives no old Session remembered hit, creates fresh `decision=1`, candidate count `1`, and a fresh Firefox picker. After a new explicit Session choice at `12:05:47.363` (`remember=2`), five later matching requests consume `scope=session`, and six Treasury mTLS handshakes succeed. No `Once` lease or sticky failure marker appears.

**S1/S1-B/S1-C PASS.** Positive Session state is reusable throughout the running browser process and cleared by complete browser-process restart.

## GIS-G4 — PASS / cross-host decision isolation CLOSED

The `session-current.zip` capture proves stronger cross-host isolation using a live Treasury `Session` decision:

- Treasury Session is already active;
- later `portalgisgmp.cert.roskazna.ru` client-auth arrives with `browser_id=17`;
- fresh decision `2` and a fresh picker are created at `11:37:37.389 UTC`;
- Treasury Session is not silently applied to the different GOST mTLS host;
- after the user selects GIS `Once`, one lease plus four reuses feed five successful GIS mTLS handshakes.

Whole capture has zero `selected=0`, `0x80090326`, `0x0000054f`, `MSSPI_X509_LOOKUP`, stale callbacks, or `E/GostTLS`.

Do not repeat GIS-G4 on unchanged source merely for confirmation.

## NEXT — Session-default exact-artifact regression

The picker UX/default change is implemented and the authoritative main build is green on source `afbdad307f63e594d3715169d6e34235280dddaf`, run `33073577269`, job `98521835354`, artifact `9652941006`.

Run this targeted sequence on that exact artifact only after the mandatory preflight above has passed:

1. **SD1 — default Session first login.** Verify the picker visibly opens with `Session` selected by default, choose the intended certificate without changing the remember mode, and require successful Treasury GOST mTLS/application login. The runtime log must include `picker_default=session` and positive Session resolution rather than a `Once` lease store.
2. **SD2 — same-process Session reuse.** In the same running browser process, exercise later matching connections and user-visible tabs/windows. Require no second Treasury picker and require later matching client-auth requests to consume the Session-scoped remembered decision.
3. **SD3 — restart boundary.** Fully terminate the browser process and launch the same exact artifact again using the same SD1/SD2 profile. The first matching Treasury client-auth request must show a fresh picker; old Session state must not survive process restart.
4. **SD4 — explicit Once regression.** Start from a clean test-specific profile, explicitly switch the picker to `Once`, and require the already-proven short positive fanout behavior for compatible follow-on connections. After idle expiry, an independent attempt in the same process/profile must show a fresh picker.
5. **SD5 — cross-host isolation.** In one clean test sequence, establish an active Treasury Session decision and then visit the different GIS GMP GOST mTLS endpoint in the same process/profile. Require a fresh decision/picker there; the Treasury Session certificate must not be silently applied cross-host.
6. **SD6 — picker presentation smoke.** Verify the initial remember control shows `Session` as default and the `Issued by` primary details row is human-readable rather than a raw full issuer DN when a common name is available. Do not record real certificate identity values in repository documentation.

SD1-SD5 are exact-build regressions of already-proven mechanisms after the UI/default source change, not reopening the closed historical F1/F2/F3/S1/GIS-G4 conclusions. SD6 validates the new presentation behavior that build success cannot prove.

Current source treats all non-`Once` positive choices through the same process-local remember store. Therefore true persistent `Permanent` behavior is not yet established and remains a separate implementation/test item.

## Remaining client-decision semantics

### T3 — explicit no-certificate / Cancel

Current attempt may fail/continue as appropriate; later independent attempt must show a fresh picker. Distinguish explicit `Declined` from involuntary `Aborted`.

### T4 — involuntary Abort

Exercise navigation/tab/load teardown without a user decision. State must be `Aborted`, not reusable `Declined`; later attempt must recover.

### T5 — explicit Session

S1/S1-B/S1-C prove the basic positive process lifetime. Later matrix work should additionally prove temporary provider failures and matching-policy boundaries do not overwrite or leak the positive Session decision.

### T6 — explicit Permanent

Implement/verify actual persistent semantics distinct from the current process-local non-Once store. Positive choice should persist according to Firefox permanent remember semantics and be removable by the intended forget/change action. Negative/provider failures must not overwrite it.

## Provider/private-key media

### T7 — missing key medium + provider Cancel

Certificate remains discoverable but CryptoPro private-key medium/container is unavailable. Cancel provider UI. Only the current attempt should fail; no negative certificate decision may poison later attempts.

### T8 — provider recovery without browser restart

Make the key medium available on retry. Handshake and protected login should succeed without restarting r3dfox.

### T9 — long provider wait

Hold provider/PIN/media UI beyond the ordinary picker-timeout scale. Record actual duration and check for network starvation, timeout corruption or teardown materially worse than stock synchronous token/PIN behavior. Do not redesign MSSPI threading without a concrete regression.

## Picker presentation

### T10 — Russian UI presentation

Verify human owner display name, localized expiry, Cyrillic issuer rendering, human-facing `Issued to`, human-friendly `Issued by`, and serial remaining details-only. Do not publish actual certificate identity values.

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

Final exact source/build must prove together final server trust, the intended final default remember behavior, explicit `Once` short-fanout behavior, safe compatible fanout, completed mTLS/private-key use, expected GOST suite, authenticated protected application traffic, retry recovery and no sensitive data publication.

## Separate non-blocking investigation

T2R observed non-uniform picker timeout/poll behavior (`32.576`, `37.420`, `30.330 s`; quiescent poll counts `10,825`, `34`, `21`). Attribute the actual Firefox/Necko/load timer and first-cycle poll churn before changing timeout policy. This does not reopen F1/F2/F3.

## Stop / escalation rules

- Do not accept any SD/T runtime result unless the mandatory preflight above passed for the exact test sequence.
- Do not repeat already-proven old-artifact tests unless explicitly regression-testing a changed source.
- On failure, preserve the capture and stop the dependent branch rather than generating downstream noise.
- Build success never substitutes for runtime proof.
- Main and thunk-rs artifacts are not interchangeable for GOST conclusions.
- Keep Windows compatibility and bundled-extension testing separate from the GOST runtime matrix.
- After every meaningful runtime experiment, append `TEST_LOG.md` and update `PROJECT_STATE.md` / `TODO.md` / this checkpoint when the blocker or next step changes.