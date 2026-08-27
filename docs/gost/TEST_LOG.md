# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-27_2026-08-27.md`](./TEST_LOG_2026-08-27_2026-08-27.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. For current technical synthesis, see [`PROJECT_STATE.md`](./PROJECT_STATE.md). For forward work, see [`TODO.md`](./TODO.md). The restart-safe Stage 2 runtime sequence is [`STAGE2_RUNTIME_TEST_PLAN.md`](./STAGE2_RUNTIME_TEST_PLAN.md); the GIS GMP multi-host mTLS branch is [`STAGE2_GIS_GMP.md`](./STAGE2_GIS_GMP.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-08-27 — T2R passes: timeout teardown no longer creates an orphan client-auth decision

**Track:** GOST TLS runtime / Stage 2 coordinated Firefox client-auth lifecycle  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea` (`fix(gost): harden coordinated client auth lifecycle`)  
**Actions run:** `33039013849`  
**Job:** `98408139479`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9636591432` (`r3dfox-gost-win64-release`)  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru`  
**Runtime capture:** user-provided `t2r_timeout.zip`, SHA-256 `88053089499fee19edf7506d4fe257567dcc688740741313ff9430749e84bba7`; inner `t2r.moz_log`, SHA-256 `261ddf9a4008c212f1ee5b5ec2213ab0fb3ee6e6a244e586987ff04a8de8d5`

The raw capture is not committed. It contains detailed certificate-authority diagnostics that may identify organizations; only sanitized lifecycle/count/timing facts are recorded here.

### User-visible procedure and result

A clean profile was launched in coordinated mode with the Treasury public and personal-cabinet hosts explicitly allowlisted and the diagnostic thumbprint/mode/cipher overrides cleared.

The user performed three unanswered-picker timeout cycles in one browser process:

1. first picker was left unanswered until Firefox showed `The connection has timed out`; F5 produced a fresh picker;
2. second picker was left unanswered until the same timeout page; `Try again` produced a fresh picker;
3. third picker was again left unanswered until the timeout page.

This directly reverses the old artifact's externally visible failure, where the first timeout poisoned later attempts until browser restart.

### Exact lifecycle evidence

The capture contains exactly three coordinated decisions for `lk-fzs.roskazna.ru` and exactly three visible picker requests.

Cycle 1:

- decision `1` / waiter created and dialog requested: `07:27:06.242 UTC`;
- closing begins, waiter removed with `reason=close-pre`, `waiters=0`, and decision removed with `reason=no-waiters phase=0`: `07:27:38.818 UTC`;
- `msspi_shutdown()` re-enters the client-cert callback, which is rejected with `reason=closing` at the same timestamp;
- post-close waiter cleanup is a no-op and the handle is recorded closed;
- abandoned UI callback later arrives and is rejected as stale at `07:27:39.099 UTC`;
- picker-to-close interval: **32.576 s**.

Cycle 2:

- decision `2` / waiter created and dialog requested: `07:27:47.687 UTC`;
- waiter removed and decision removed: `07:28:25.107 UTC`;
- shutdown re-entry is rejected with `reason=closing`: `07:28:25.123 UTC`;
- stale UI callback rejected: `07:28:25.312 UTC`;
- picker-to-close interval: **37.420 s**.

Cycle 3:

- decision `3` / waiter created and dialog requested: `07:28:32.720 UTC`;
- waiter removed, decision removed and shutdown re-entry rejected with `reason=closing`: `07:29:03.050 UTC`;
- stale UI callback rejected: `07:29:03.206 UTC`;
- picker-to-close interval: **30.330 s**.

Across all three cycles:

- exactly `3` client-auth decisions are created and exactly `3` are removed;
- exactly `3` active waiters are removed before shutdown and each reaches `waiters=0`;
- exactly `3` shutdown-time client-cert callback re-entries are rejected because the handle is closing;
- exactly `3` abandoned picker callbacks are later rejected as stale;
- no extra decision or waiter is created during shutdown;
- `selected=0`: **0 occurrences**;
- `0x80090326`: **0 occurrences**;
- `0x0000054f`: **0 occurrences**;
- `MSSPI_X509_LOOKUP`: **0 occurrences**.

This is the exact invariant that failed on source `860de8e...`: the old close path removed the original waiter and then allowed `msspi_shutdown()` to create a new orphan decision. On the fixing source, the re-entrant callback is now stopped before decision lookup/create/join.

### Polling / timeout observation

`GostPoll client-auth wait quiescent` occurs `10,880` times in the capture:

- cycle 1: `10,825` calls over `32.576 s` (~`332/s`);
- cycle 2: `34` calls over `37.420 s` (~`0.91/s`);
- cycle 3: `21` calls over `30.330 s` (~`0.69/s`).

The first cycle still shows substantial poll churn while the later two are near one call per second. This inconsistency is worth a separate efficiency/timeout-attribution investigation, but it does not corrupt decision lifecycle and is not a blocker for continuing the Stage 2 runtime matrix.

The unanswered-picker lifetime is also not a fixed 45-second boundary: the three measured intervals are `32.576 s`, `37.420 s`, and `30.330 s`. Do not infer a hard timeout constant from the earlier ~45.005-second artifact. Attribute the actual Firefox/Necko timer/lifecycle source separately before changing timeout policy.

### Conclusion

**T2R PASS. F1 is formally closed for the tested fixing artifact.**

The close/shutdown re-entrancy blocker is fixed at runtime: a closing MSSPI handle cannot create/join a coordinated client-auth decision, teardown removes the current waiter/decision cleanly, stale UI callbacks are harmless, and later attempts recover without browser restart or sticky `selected=0` state.

Status: current; F1 lifecycle blocker closed.

---

## 2026-08-27 — First supplied T1R capture was invalid because an older browser build was launched

**Track:** GOST TLS runtime / Stage 2 positive `Once` fanout  
**Intended browser:** source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`, main run `33039013849`, job `98408139479`, artifact `9636591432`  
**Runtime capture:** user-provided `t1r_error.zip`, SHA-256 `e42416dd8199a85e3faec5dbcab84d09f425ee3a39dd9bcc67ccff8a4ea39236`; inner `t1r.moz_log`, SHA-256 `80bf7e4062636df669799bba740d6ab423208e958d758cdf02d26cd9f1b5eab7`

The user later confirmed that this test was accidentally run from one of the older browser builds. The capture was already independently identifiable as incompatible with `ef1a7...`: it contained none of the current decision/waiter/lease/closing diagnostics and reproduced the old post-timeout `selected=0` / `0x80090326` cascade.

This capture therefore remains historical evidence of a test-identity mistake only. It neither passes nor fails F2 and does not reopen F1.

Authoritative local binary hashes for artifact `9636591432` are:

- `r3dfox.exe` SHA-256 `ccd3ed44bc57345eb7821a949dd96a6b3c45c71b47f3a577da26fc1265481187`;
- `xul.dll` SHA-256 `8cee03269e18dff2bc48d5c25bef34a6c62c520908d937e3b3e4a03031d0ab68`.

Status: resolved test-identity error; superseded by the valid T1R below.

---

## 2026-08-27 — T1R passes: one picker feeds the complete Treasury login through the positive `Once` lease

**Track:** GOST TLS runtime / Stage 2 positive default-`Once` fanout  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea` (`fix(gost): harden coordinated client auth lifecycle`)  
**Actions run:** `33039013849`  
**Job:** `98408139479`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9636591432` (`r3dfox-gost-win64-release`)  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru`  
**Runtime capture:** user-provided `t1r-current.zip`, SHA-256 `1c75f484607a6e3eb95439275e2698098a04551689619f95f93f13ca890b248e`; inner `t1r-current.moz_log`, SHA-256 `9f77de380e9ebf9b98f2e7cf2d3c0d6eb03233eb7afed0d103b2ecbf49bc78c7`

The user verified the actual launched binaries before the run:

- `xul.dll` SHA-256 `8cee03269e18dff2bc48d5c25bef34a6c62c520908d937e3b3e4a03031d0ab68`;
- `r3dfox.exe` SHA-256 `ccd3ed44bc57345eb7821a949dd96a6b3c45c71b47f3a577da26fc1265481187`.

These exactly match authoritative artifact `9636591432`, so this capture is bound to the intended fixing source.

### User-visible result

The user entered the Treasury personal cabinet from the main page, received exactly one Firefox client-certificate picker, left the default `Once` behavior, selected the intended certificate once, and successfully entered the personal cabinet. No second picker appeared during the logical login and subsequent cabinet use behaved normally.

### Exact coordinator / lease evidence

- one coordinated decision and one picker are created at `08:43:56.467 UTC`;
- the positive `Once` choice is stored once at `08:43:58.650 UTC`, `browser_id=14`, lease generation `1`, `idle_ms=5000`;
- the initial waiter is consumed and the only active decision is removed with `phase=Selected` immediately after the positive choice;
- the first real mTLS handshake completes at `08:43:59.103 UTC`;
- the same positive lease is then reused without UI **7 times**.

The seven reuse events occur at:

- `08:43:59.635`;
- `08:43:59.645`;
- `08:43:59.653`;
- `08:43:59.662`;
- `08:43:59.669`;
- `08:44:02.577`;
- `08:44:02.588 UTC`.

This demonstrates two follow-on connection waves: five near-simultaneous reuses roughly one second after the original choice and two later reuses about 3.9 seconds after the choice. The latter wave is the important regression: it remains inside the 5-second idle lease and no new picker is opened.

### Protocol result

The capture contains **8 successful `lk-fzs.roskazna.ru` mTLS handshakes**. Every one completes as:

- TLS `0x0303` / TLS 1.2;
- GOST cipher `0xFF85`;
- MSSPI state `0x00000000`;
- `client_cert_loaded=1`.

Counts for the whole capture:

- client-cert dialogs: `1`;
- coordinated decisions: `1`;
- positive `Once` lease stores: `1`;
- positive lease reuses / leased certificate installs: `7`;
- successful login-host mTLS handshakes with client certificate loaded: `8`;
- `selected=0`: `0`;
- `0x80090326`: `0`;
- `0x0000054f`: `0`;
- `MSSPI_X509_LOOKUP`: `0`;
- `E/GostTLS`: `0`.

The last reuse is at `08:44:02.588 UTC`. Because every successful reuse refreshes the 5-second idle expiry, the nominal lease would become inactive around `08:44:07.588 UTC` if no later compatible request refreshed it. The log continues to `08:44:10.783 UTC`, but it contains no independent post-expiry client-auth request; therefore this capture does **not** by itself prove that a later independent login asks again.

### Conclusion

**T1R PASS.** The F2 positive fanout mechanism is runtime-proven for one complete logical Treasury login: a single user certificate choice supplies the initial connection and seven compatible follow-on connections across sequential waves, while real GOST mTLS and the protected application login succeed.

F2 is not yet formally closed because its negative scope boundary still requires **T1R-B**: after the 5-second idle lease has become inactive, an independent login in the same browser process must show a fresh picker. A positive `Once` choice must not silently become Session/Permanent.

Status: current; T1R complete, T1R-B is next.

---

## 2026-08-27 — T1R-B passes: expired default-`Once` lease asks again in the same browser process

**Track:** GOST TLS runtime / Stage 2 positive default-`Once` scope boundary  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea` (`fix(gost): harden coordinated client auth lifecycle`)  
**Actions run:** `33039013849`  
**Job:** `98408139479`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9636591432` (`r3dfox-gost-win64-release`)  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru`  
**Runtime capture:** user-provided `T1R-B-current.zip`, SHA-256 `c2d018b8637467b4c1368bfa66399dd042d73b88c39c6de7bf07368c7524ea65`; inner `t1r-current.moz_log`, SHA-256 `c30c9f61e008d8bdb321570373c1c5cf6f3bc9eaa9e980564d463d03e307686e`

The capture is from the hash-bound current artifact already verified for T1R. Both logical logins occur in the same browser process (`Parent 6204`) and the same Firefox browser context (`browser_id=14`).

### First login / active `Once` lease

- coordinated decision `1` and the first picker are created at `09:07:05.459 UTC`;
- positive `Once` selection stores lease generation `1` at `09:07:07.998 UTC` with `idle_ms=5000`;
- generation `1` is reused without UI 11 times while the first logical login creates its compatible follow-on connections;
- the last generation-1 reuse is `09:07:13.004 UTC`;
- therefore, absent another compatible request, its nominal idle expiry is `09:07:18.004 UTC`.

The first logical login completes 12 `lk-fzs.roskazna.ru` GOST mTLS handshakes, all TLS 1.2 / `0xFF85`, state `0x00000000`, `client_cert_loaded=1`.

### Independent post-expiry login

A later independent client-auth request occurs in the same process/context at `09:09:44.169 UTC`:

- this is **151.165 s after the final generation-1 reuse**;
- it is **146.165 s after the nominal 5-second idle expiry**;
- the coordinator creates a fresh `decision=2`;
- Firefox requests a fresh client-certificate dialog for decision 2;
- there is no automatic reuse of generation 1 for this new request;
- after the user makes a new positive `Once` choice, the coordinator stores **generation `2`** at `09:09:46.616 UTC`;
- the new attempt then completes two additional TLS 1.2 / `0xFF85` mTLS handshakes with `client_cert_loaded=1`.

This is decisive proof that default `Once` did not become Session/Permanent. A real new client-auth handshake occurred after the old lease was inactive, and Firefox asked the user again before any new positive lease existed.

### Whole-capture safety result

- coordinated decisions: `2`;
- picker requests: `2`;
- positive `Once` lease stores: `2` (generations 1 and 2);
- generation-1 lease reuses: `11`;
- successful `lk-fzs.roskazna.ru` mTLS handshakes: `14`;
- `selected=0`: `0`;
- `0x80090326`: `0`;
- `0x0000054f`: `0`;
- `MSSPI_X509_LOOKUP`: `0`;
- stale client-auth callbacks: `0`;
- `E/GostTLS`: `0`.

### Conclusion

**T1R-B PASS. F2 is formally CLOSED for the tested current artifact.**

Together, T1R and T1R-B prove the intended default-`Once` semantics on the real Treasury flow: one positive choice fans out across compatible concurrent/sequential connection waves of one logical login, while a later independent client-auth attempt after the idle lease expires receives a new picker and a new lease generation rather than silently inheriting Session/Permanent behavior.

The next runtime blocker is **F3 / GIS-G1** on `portalgisgmp.cert.roskazna.ru` using the same authoritative artifact `9636591432`.

Status: current; F2 positive `Once` fanout/scope blocker closed.

---

## 2026-08-27 — GIS-G1/G2/G3 pass: generic coordinated client auth completes real GIS GMP GOST mTLS

**Track:** GOST TLS runtime / Stage 2 generic multi-host client authentication  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea` (`fix(gost): harden coordinated client auth lifecycle`)  
**Actions run:** `33039013849`  
**Job:** `98408139479`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9636591432` (`r3dfox-gost-win64-release`)  
**Runtime targets:** `pay.gov.ru`, `portalgisgmp.login.roskazna.ru`, `portalgisgmp.cert.roskazna.ru`  
**Runtime capture:** user-provided `gis-g1-g2-g3.zip`, SHA-256 `8bb1fd3cfb6773739f0c9b05fd31555eef4180d65ce0518d54a63c85691558ce`; inner `gis-g1.moz_log`, SHA-256 `451ed230a972b19ec35c1edc8952d1b234366ac5775c7252e8e67a92a289f1b1`

The capture spans `09:50:54.079–09:51:45.484 UTC` (`51.405 s`) in one browser process. The raw log is not committed because it contains detailed acceptable-CA DNs and certificate diagnostics; only sanitized counts/timings/protocol facts are recorded.

### GIS-G1 — generic decision point is reached

The generic coordinated client-certificate callback is registered successfully on all three allowlisted GOST hosts. On the real certificate endpoint:

- callback registration for `portalgisgmp.cert.roskazna.ru` succeeds at `09:51:17.694 UTC`;
- the real server client-certificate request reaches the callback at `09:51:17.959 UTC`;
- current acceptable-CA count is **36**;
- local candidate enumeration returns **1** policy-eligible candidate;
- coordinator creates `decision=1`, adds one waiter and requests exactly one Firefox picker.

Thus the old host-scope defect is reversed: the GIS GMP certificate host no longer bypasses the coordinator and no longer sends an empty client Certificate merely because it is not the Treasury Stage-1 hostname.

### GIS-G2 — real GIS GMP GOST mTLS succeeds

The user selected the intended certificate with default `Once`. At `09:51:20.626 UTC` the coordinator resolves `decision=1` positively (`remember=0`) and stores positive lease generation `1`, `idle_ms=5000`.

The certificate endpoint then completes **5 successful GOST mTLS handshakes**:

- first handshake: `09:51:21.421 UTC`;
- follow-on handshakes: `09:51:22.185`, `09:51:22.200` (two sockets), and `09:51:23.619 UTC`;
- all five negotiate TLS `0x0303` / TLS 1.2, cipher `0xFF85`, state `0x00000000`, `client_cert_loaded=1`;
- all five reach `verify ok=1 status=0x00000000` under the currently implemented verification path;
- four follow-on client-auth requests reuse the same positive `Once` lease without another picker.

The user confirmed the certificate-login/application flow succeeds. Completed mTLS, rather than `client_cert_loaded=1` alone, proves real private-key use.

### GIS-G3 — no spurious picker on non-mTLS GOST hosts

Generic callback registration changes capability but does not force client authentication:

- `pay.gov.ru`: callback registered once; one successful TLS 1.2 / `0xFF85` handshake with `client_cert_loaded=0`; **zero** client-certificate requests;
- `portalgisgmp.login.roskazna.ru`: callback registered four times; four successful TLS 1.2 / `0xFF85` handshakes with `client_cert_loaded=0`; **zero** client-certificate requests;
- all five client-certificate requests in the capture belong only to `portalgisgmp.cert.roskazna.ru`;
- only one picker is shown for the entire GIS login flow.

Whole-capture negative/safety counts: `selected=0` = `0`, `0x80090326` = `0`, `0x0000054f` = `0`, `MSSPI_X509_LOOKUP` = `0`, `E/GostTLS` = `0`.

### Conclusion

**GIS-G1 PASS. GIS-G2 PASS. GIS-G3 PASS. F3 generic GOST mTLS host-scope blocker is formally CLOSED for the tested current artifact.**

The real GIS GMP certificate endpoint now reaches generic Firefox-coordinated client authentication, produces a valid candidate/picker, completes five real GOST mTLS handshakes, and proceeds successfully at application level. Non-mTLS GOST hosts do not show spurious certificate UI.

GIS-G4 cross-host decision isolation remains a separate semantic regression test; final fail-closed server-trust closure also remains open.

Status: current; F3 generic host-scope blocker closed.

---

## 2026-08-27 — Explicit Session is reused in-process and stays isolated from another GOST mTLS host

**Track:** GOST TLS runtime / explicit Session baseline + GIS-G4 cross-host isolation  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea` (`fix(gost): harden coordinated client auth lifecycle`)  
**Actions run:** `33039013849`  
**Job:** `98408139479`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9636591432` (`r3dfox-gost-win64-release`)  
**Runtime capture:** user-provided `session-current.zip`, SHA-256 `6eccbf7d49e69a92d9634507b111759f096c4dee00a0313ec3d7c20017f5dec1`; inner `session-current.moz_log`, SHA-256 `b3b2c8751e1f0cf66cfda73a1c068f609efb1692ade910b0d4ffcb42ff4905f8`

The raw capture is not committed. Only sanitized lifecycle/protocol counts are recorded.

### S1 / S1-B — Treasury explicit Session

The entire capture remains in one browser process (`Parent 6200`).

- first `lk-fzs.roskazna.ru` client-auth request is at `11:36:28.521 UTC`, `ca_count=34`, `browser_id=14`;
- coordinator creates `decision=1` and one Firefox picker;
- the user selects the intended certificate with explicit `Session`;
- decision resolves positively at `11:36:33.382 UTC` with `remember=2`;
- no Treasury `Once` lease is stored for this choice;
- ten later matching Treasury client-auth requests are served from `scope=session` with no additional Treasury picker;
- all **11** `lk-fzs.roskazna.ru` handshakes complete as TLS 1.2 / `0xFF85`, state `0x00000000`, `client_cert_loaded=1`.

The user confirms that the Session remains usable while working across tabs and browser windows in the same running browser. The Treasury client-auth requests visible in this log all carry `browser_id=14`; therefore the raw log itself proves process-level matching remembered reuse, while the tab/window topology is additional user-observed UX evidence rather than a distinct-browser-ID handshake proof.

### GIS-G4 — cross-host isolation

With the Treasury Session choice still active in the same process, the user navigates to the independent GIS GMP GOST route.

- `pay.gov.ru` completes one GOST handshake with `client_cert_loaded=0`;
- `portalgisgmp.login.roskazna.ru` completes five GOST handshakes with `client_cert_loaded=0`;
- `portalgisgmp.cert.roskazna.ru` issues a fresh client-auth request at `11:37:37.389 UTC`, `ca_count=36`, `browser_id=17`;
- candidate count is `1`;
- fresh `decision=2` and a fresh Firefox picker are created;
- the active Treasury Session certificate is **not** silently applied to the different GOST mTLS host.

The user then selects `Once` for GIS GMP:

- positive lease generation `1` is stored at `11:37:49.897 UTC` (`remember=0`);
- four compatible requests reuse it;
- five GIS GMP certificate-host TLS 1.2 / `0xFF85` mTLS handshakes complete with `client_cert_loaded=1`.

Whole-capture safety counts:

- client-cert dialogs: `2` total, one Treasury and one GIS GMP;
- Treasury Session remembered hits: `10`;
- GIS `Once` lease stores: `1`;
- GIS `Once` lease reuses: `4`;
- successful mTLS handshakes: Treasury `11`, GIS certificate host `5`;
- `selected=0`: `0`;
- `0x80090326`: `0`;
- `0x0000054f`: `0`;
- `MSSPI_X509_LOOKUP`: `0`;
- stale client-auth callbacks: `0`;
- `E/GostTLS`: `0`.

### Conclusion

**S1 PASS. S1-B in-process positive Session reuse PASS. GIS-G4 PASS / CLOSED.**

The process-local Session remember path supplies later matching Treasury client-auth handshakes without another picker, while a different GOST mTLS host receives an independent decision/picker and cannot inherit the Treasury credential decision.

This capture does not close **S1-C** because it contains only one browser process. The remaining Session baseline test is a complete r3dfox process restart using the same profile; the next matching Treasury client-auth flow must show a fresh picker.

Status: current; S1/S1-B pass, GIS-G4 closed, S1-C next.

---

## 2026-08-27 — S1-C passes: explicit Session is cleared by browser-process restart

**Track:** GOST TLS runtime / explicit Session process lifetime  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea` (`fix(gost): harden coordinated client auth lifecycle`)  
**Actions run:** `33039013849`  
**Job:** `98408139479`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9636591432` (`r3dfox-gost-win64-release`)  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru`  
**Runtime capture:** user-provided `session-current2.zip`, SHA-256 `e32b71ca51d151e553ab82c321fd8f829270e09b6a8390f7fb3ea828af3a29e7`; inner `session-current.moz_log`, SHA-256 `5b156cf0765c9aad3ceffeac6d1a845cea381f219ea168d59b318201b9f419b5`

This is the requested restart-boundary follow-up to the prior `session-current.zip` baseline. The earlier Session test ran as `Parent 6200`; this capture is a new browser process, `Parent 5112`, and spans `12:05:29.014–12:05:53.567 UTC`.

### Restart boundary

The first new `lk-fzs.roskazna.ru` client-auth request occurs at `12:05:43.453 UTC`, with `ca_count=34` and `browser_id=2`.

- no old `scope=session` remembered hit occurs before this request is resolved;
- coordinator creates fresh `decision=1`;
- candidate enumeration returns `1` eligible certificate;
- Firefox requests a fresh client-certificate picker at the same timestamp.

Therefore the Session decision established in the previous browser process did not survive process termination/restart.

### New-process Session behavior

The user again selects the intended certificate with explicit `Session`:

- decision `1` resolves positively at `12:05:47.363 UTC` with `remember=2`;
- no `Once` lease is created;
- five subsequent matching client-auth requests at `12:05:48.290–12:05:48.322 UTC` are served from `scope=session` without more UI;
- six `lk-fzs.roskazna.ru` TLS 1.2 / `0xFF85` mTLS handshakes complete with state `0x00000000`, `client_cert_loaded=1`, and positive current verification status.

Whole-capture safety counts: one decision, one picker, five Session remembered hits, zero `Once` lease events, zero `selected=0`, zero `0x80090326`, zero `0x0000054f`, zero `MSSPI_X509_LOOKUP`, and zero `E/GostTLS`.

### Conclusion

**S1-C PASS. The explicit Session baseline is complete.**

Together S1/S1-B/S1-C prove the intended lifetime: a positive Session choice is reusable across matching handshakes throughout the running browser process, user-visible behavior spans tabs/windows, it remains isolated from a different GOST mTLS host, and it is cleared when the browser process exits. A new process receives a fresh picker and may establish a new Session independently.

The next planned code iteration is now the picker UX/default change: make `Session` the default remember duration, preserve explicit `Once` and its proven 5-second positive fanout lease, and render `Issued by` in a human-friendly form analogous to `Issued to`. True persistent `Permanent` semantics remain separate open work.

Status: current; S1/S1-B/S1-C complete, explicit Session process lifetime closed.