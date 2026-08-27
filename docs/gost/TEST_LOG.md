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
