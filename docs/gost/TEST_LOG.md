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

Next runtime test is **T1R** on the same main artifact `9636591432`: perform a successful Treasury login with default `Once` and verify that the positive 5-second fanout lease collapses the logical login to one visible picker while all relevant GOST mTLS handshakes succeed. Then run T1R-B to prove that an independent login asks again after the lease is inactive.

Status: current; F1 lifecycle blocker closed, F2 runtime validation is next.

---

## 2026-08-27 — Supplied T1R capture is invalid for F2 because the runtime binary is not the current fixing source

**Track:** GOST TLS runtime / Stage 2 positive `Once` fanout  
**Branch:** `agent/gost-tls-poc`  
**Intended browser:** source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`, main run `33039013849`, job `98408139479`, artifact `9636591432`  
**Actual browser identity:** unresolved; the runtime log is incompatible with the intended source and therefore cannot be bound to that build  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru`  
**Runtime capture:** user-provided `t1r_error.zip`, SHA-256 `e42416dd8199a85e3faec5dbcab84d09f425ee3a39dd9bcc67ccff8a4ea39236`; inner `t1r.moz_log`, SHA-256 `80bf7e4062636df669799bba740d6ab423208e958d758cdf02d26cd9f1b5eab7`

The raw capture is not committed. Only sanitized protocol/lifecycle facts are recorded.

### User-visible procedure

The user attempted the planned T1R flow: entered the Treasury personal cabinet, selected the intended certificate in the first picker with default `Once`, then immediately received a second picker. The second picker was deliberately left unanswered; after timeout the personal-cabinet page displayed an HTTP 500 error. A separate exploratory run in which the user accepted three successive picker dialogs eventually reached the personal cabinet, but that run was outside the planned T1R procedure and has no capture bound here.

### Sanitized timeline from the supplied capture

- first picker requested: `08:19:18.129 UTC`;
- first picker resolved positively: `08:19:20.393 UTC`;
- first real Treasury mTLS handshake completed with `client_cert_loaded=1`: `08:19:20.814 UTC`;
- five follow-on sockets register the client-cert callback beginning at `08:19:21.126 UTC`;
- second picker requested: `08:19:21.275 UTC`, only **0.461 s** after the completed first mTLS handshake;
- the second decision collapses four additional concurrent sockets through the old `joined existing decision` path;
- first close associated with the unanswered second picker begins at `08:20:00.590 UTC`, about **39.315 s** after that picker opened.

If this had actually been the current `ef1a7...` binary, the 5-second positive lease would at minimum have executed its store/reuse instrumentation during this 0.461-second follow-on wave. It did not.

### Binary/source fingerprint mismatch

The current fixing source contains mandatory diagnostics for the code paths exercised by this test, including decision IDs/waiter lifecycle and positive-`Once` lease storage/reuse. In the supplied log the following current-source markers all occur **zero** times:

- `client auth waiter added`;
- `client auth decision resolved`;
- `client certificate once lease stored`;
- `client certificate once lease reused`;
- `client certificate leased`;
- `client auth handle closing` / `reason=closing`;
- any `decision=` lifecycle marker.

After the second picker times out, the capture instead reproduces the pre-F1 failure fingerprint:

- `selected=0`: `37` occurrences;
- `0x80090326`: `74` occurrences;
- `0x0000054f`: `148` occurrences;
- no `MSSPI_X509_LOOKUP` recurrence.

This cannot be reconciled with the already-proven T2R behavior of artifact `9636591432`, where shutdown-time callbacks are rejected with `reason=closing` and the entire three-cycle capture contains zero `selected=0`, `0x80090326`, and `0x0000054f`.

The log shape is consistent with a pre-`ef1a7...` coordinated binary, including the known source `860de8e...` baseline, but the exact old artifact cannot be asserted from the log alone. Per project evidence rules, F2 must not be judged from an unbound runtime binary.

### Exact artifact hashes for the T1R preflight

The authoritative artifact `9636591432` was downloaded and independently inspected:

- Actions artifact ZIP SHA-256: `e18c8d2bc43ffa00318f7f3b82e585312cb251cd7ad5d1542f99df634846673f`;
- packaged `r3dfox-v153.0.3.win64.zip` SHA-256: `ac9a36b541b24df2c782deef7b60014994162d036db8a1c049fd2b1936d9d757`;
- `r3dfox/r3dfox.exe` SHA-256: `ccd3ed44bc57345eb7821a949dd96a6b3c45c71b47f3a577da26fc1265481187`;
- **`r3dfox/xul.dll` SHA-256: `8cee03269e18dff2bc48d5c25bef34a6c62c520908d937e3b3e4a03031d0ab68`**.

The GOST coordinator implementation is in `xul.dll`; therefore the `xul.dll` hash is the decisive local preflight. For comparison, exact old baseline artifact `9606431408` contains:

- `r3dfox.exe` SHA-256 `7fd0e624b81ed5e973de37778e9a5959e8a101b4c1e7c6378ed14a224b2beb41`;
- `xul.dll` SHA-256 `7cb152dedd17ad96871c46bef796da250aeac517b35002f34360d2c81b03b393`.

### Conclusion / next experiment

**This capture does not fail F2. It is an invalid T1R because the actual runtime binary is not the intended `ef1a7...` fixing build.** F1 remains closed; do not reopen it from this unbound capture.

Before repeating T1R, hash the local `r3dfox.exe` and especially `xul.dll` from the directory being launched. Proceed only when they exactly match artifact `9636591432` above. Then rerun the original T1R procedure unchanged and preserve the new log. Only that bound capture may pass or fail the 5-second positive-`Once` lease.

Status: current; F2 remains runtime-unproven, next step is exact-binary preflight followed by T1R rerun.