# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-27_2026-08-28.md`](./TEST_LOG_2026-08-27_2026-08-28.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. For current technical synthesis, see [`PROJECT_STATE.md`](./PROJECT_STATE.md). For forward work, see [`TODO.md`](./TODO.md). For formally closed milestones, see [`DONE.md`](./DONE.md). The restart-safe Stage 2 runtime sequence is [`STAGE2_RUNTIME_TEST_PLAN.md`](./STAGE2_RUNTIME_TEST_PLAN.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-08-28 — T3 passes: repeated explicit Cancel is attempt-local; timeout and later positive recovery remain clean

**Track:** GOST TLS runtime / explicit client-certificate decline and recovery  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `afbdad307f63e594d3715169d6e34235280dddaf` (`fix(gost): mark Session picker default in runtime logs`)  
**Actions run:** `33073577269`  
**Job:** `98521835354`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9652941006` (`r3dfox-gost-win64-release`)  
**Campaign binary identity:** `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`; `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru`  
**Runtime capture:** user-provided `T3 — explicit Cancel.zip`, SHA-256 `32c3e844e85c1997f57bc682d193c91c9fbcfa2c9b0dc91d939a9e82eeec293c`; inner `SDx.moz_log`, SHA-256 `d6174d335074904da2e6bbbddfe2b22e582a805292c81e518c72be8a85bfa38b`

The raw capture is not committed because it contains detailed certificate-authority diagnostics. Only sanitized lifecycle/protocol facts are recorded.

The run stays in one browser process, `Parent 1544`, and uses the current coordinated picker with `picker_default=session`.

### Four explicit Cancel decisions

The user intentionally opened and cancelled the Firefox client-certificate picker four times. Each cancellation is represented consistently as an explicit decline, not teardown:

- decision `1`: picker `03:20:20.472 UTC`, resolved `selected=0 remember=2` at `03:20:23.609`, waiter removed with `reason=declined-consume`, decision removed with `phase=2`;
- decision `2`: picker `03:20:26.684`, resolved `selected=0` at `03:20:32.322`, `reason=declined-consume`, `phase=2`;
- decision `3`: picker `03:20:37.621`, resolved `selected=0` at `03:20:39.762`, `reason=declined-consume`, `phase=2`;
- decision `4`: picker `03:20:41.704`, resolved `selected=0` at `03:20:43.267`, `reason=declined-consume`, `phase=2`.

No positive Session remember hit or `Once` lease is created by any declined decision. Every later attempt receives a fresh coordinated decision/picker rather than consuming a sticky negative decision.

Each deliberate no-certificate attempt naturally causes the current TLS attempt to fail. Across the four cancelled attempts the log contains four `0x80090326` handshake failures and their follow-on `0x0000054f` failure state. These markers are expected consequences of the explicit no-certificate choice in the **current attempt**; they are not automatic/sticky failures because they do not appear after the later positive recovery decision.

### Unanswered picker timeout remains distinct from Declined

Decision `5` is created at `03:20:45.710 UTC` and the picker is left unanswered. It is never resolved as `selected=0` and never reaches the explicit decline phase.

At `03:21:15.986 UTC`, after **30.276 s**, teardown removes its waiter with `reason=close-pre` and removes the still-pending decision with `phase=0`. Shutdown-time callback re-entry is ignored with `reason=closing`, and the abandoned UI callback arriving at `03:21:16.272` is rejected as stale.

This corroborates the intended semantic separation: explicit user Cancel follows `declined-consume` / phase `2`; an unanswered timeout/teardown remains an unresolved pending decision that is removed by lifecycle cleanup. This timeout observation is useful evidence for Abort separation, but it does not replace the still-planned T4 navigation/tab/load-teardown test.

### Try again and positive recovery

After the timeout page, `Try again` creates fresh decision `6` and a fresh picker at `03:21:19.050 UTC`. The user selects the intended certificate without changing the default Session choice:

- decision `6` resolves at `03:21:21.561 UTC` as `selected=1 remember=2`;
- waiter removal is `reason=selected-consume`, decision phase `1`;
- the first recovered Treasury mTLS handshake completes at `03:21:22.029 UTC`;
- eleven later matching client-auth requests are served from `scope=session` without more picker UI;
- the capture contains **12 successful** `lk-fzs.roskazna.ru` TLS 1.2 / `0xFF85` mTLS handshakes, all state `0x00000000`, `client_cert_loaded=1`;
- all 12 recovered handshakes reach `DriveHandshake verify ... ok=1 status=0x00000000` under the current verification path;
- after decision `6` resolves positively there are **zero** `E/GostTLS` and **zero** further `selected=0` markers.

The user confirms successful authorization into the Treasury personal cabinet in the same browser process after the repeated Cancels and timeout.

### Conclusion

**T3 PASS / CLOSED.**

Explicit Firefox client-certificate Cancel is attempt-local: four deliberate declines are consumed as `declined-consume` / phase `2`, are not remembered as a reusable negative decision, and each later attempt receives a fresh picker. A subsequent unanswered-picker timeout is cleaned through the separate pending/teardown path, and `Try again` then recovers in the same process to a fresh positive Session decision and successful Treasury GOST mTLS/application login.

The `selected=0`, `0x80090326`, and `0x0000054f` entries produced by the four deliberate Cancel attempts are expected per-attempt failure evidence, not sticky-failure evidence. Future negative tests must distinguish these intentional current-attempt markers from unsolicited occurrences on later recovery attempts.

**NEXT:** T4 involuntary Abort via navigation/tab/load teardown without a user picker decision. The timeout segment above is corroborating lifecycle evidence only; do not close T4 until its specified teardown scenario is exercised.

Status: current; T3 explicit decline semantics closed, T4 next.

---

## 2026-08-28 — XP x86 representative coexistence smoke passes on physical Windows XP SP3

**Track:** Windows compatibility / Windows XP SP3 x86  
**Experiment branch:** `agent/msvcr14x-win7-smoke`  
**Source-under-test:** `d78137a931145af877dc458b01e494ad0467723d` (`ci: thunk remaining XP x86 Rust imports`)  
**Actions run:** `33138244191`  
**Job:** `98743029100`  
**Workflow:** `msvcr14x Rust YY XP x86 coexistence smoke`  
**Runtime artifact:** `9673057839` (`msvcr14x-rust-yy-xp-x86-runtime`), artifact digest SHA-256 `3b9e1c2643cafee89061c3ce260b0b075c60a772d8cbcedb96cb90161a3c4970`  
**Diagnostics artifact:** `9673058689`, artifact digest SHA-256 `6775abf4048e12bddcafe3f842be8b23af9c0669190772d0dee04c8e56aac323`  
**Runtime target:** physical Windows XP SP3 x86, `Microsoft Windows XP [Version 5.1.2600]`

The exact Actions run is green through the representative C++ `/MD` + modern Rust/libstd + pinned msvcr14x + narrow YY-Thunks link, runtime dependency closure, XP x86 PE floor gate, direct post-XP import rejection gate, Windows 2022 sanity execution, and artifact publication.

The runtime artifact contains the probe plus the two selected compatibility runtime DLLs:

- `msvcr14x-rust-yy-xp-x86-smoke.exe` — 149,504 bytes;
- `msvcp140.dll` — 423,936 bytes;
- `ucrtbase.dll` — 908,800 bytes.

On the physical XP SP3 x86 machine the user executed the exact probe three consecutive times from that bundle. Each run returned normally to `cmd.exe`, produced no loader/runtime error or crash dialog, and `echo ExitCode=%ERRORLEVEL%` reported `ExitCode=0` on all three runs. The machine had active current antivirus protection and no antivirus detection or execution block occurred during the test.

The representative workload intentionally exercises modern Rust/libstd and C++ runtime paths including `RandomState`, `Once`, `RwLock`, `Mutex`/`Condvar`, thread creation/join, timing, ordinary `/MD` C++ STL use, and the selected YY-Thunks-backed compatibility surface. Therefore this is real runtime proof, not only PE/import analysis.

### Conclusion

**XP x86 representative coexistence milestone PASS / CLOSED.**

For this exact representative workload, pinned msvcr14x + modern `i686-pc-windows-msvc` Rust/libstd + narrow YY-Thunks 1.2.2 works on real physical Windows XP SP3 x86 with the bundled compatible `ucrtbase.dll` and `msvcp140.dll` and returns exit code 0 repeatedly.

This does **not** prove Firefox 153/xul can be built or run on XP and does not establish any GOST TLS behavior on XP. The next Windows-compatibility experiment is to scale the proven x86 runtime/linker scheme to a full 32-bit Firefox/xul build, then audit its actual PE/runtime dependency closure before attempting real browser startup on XP.

Status: current; representative XP x86 runtime question closed, Firefox-scale XP x86 integration next.

---

## 2026-08-28 — T4 passes: closing the picker-owning tab aborts the pending decision and recovery succeeds in another tab

**Track:** GOST TLS runtime / involuntary client-auth abandonment via tab close  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `afbdad307f63e594d3715169d6e34235280dddaf` (`fix(gost): mark Session picker default in runtime logs`)  
**Actions run:** `33073577269`  
**Job:** `98521835354`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9652941006` (`r3dfox-gost-win64-release`)  
**Campaign binary identity:** `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`; `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru`  
**Runtime capture:** user-provided `T4 involuntary Abort.zip`, SHA-256 `bfa51cc1d45c35c8c94cae6a7eb8fc32c6490d30782cdb256a1aefb24078d2f1`; inner `SDx.moz_log`, SHA-256 `f921c42d5e7b0299a40f79a5a707d5da93990018fb535edf529aef94a3d82f65`

The raw capture is not committed because it contains detailed certificate-authority diagnostics. Only sanitized lifecycle/protocol facts are recorded.

The user started from a clean profile, opened `fzs.roskazna.ru`, kept a second blank tab available, invoked Treasury personal-cabinet login in the first tab, and closed that tab with its close button while the Firefox client-certificate picker was still unanswered. The browser process remained alive. In the remaining tab the user navigated to `fzs.roskazna.ru`, invoked login again, selected the intended certificate and successfully entered the Treasury personal cabinet.

### Pending decision is abandoned by tab teardown, not declined

The whole sequence stays in one browser process, `Parent 6184`.

The first `lk-fzs.roskazna.ru` client-auth request creates `decision=1`, `browser_id=14`, and requests the picker at `03:43:37.496 UTC`.

At `03:43:41.555 UTC`, only **4.059 s** later, closing the owning tab tears down that pending handshake:

- waiter `decision=1` is removed with `reason=close-pre`, reaching `waiters=0`;
- decision `1` is removed with `reason=no-waiters phase=0` while still unresolved;
- shutdown-time client-certificate callback re-entry is rejected with `reason=closing`;
- the abandoned picker callback arriving at `03:43:41.571 UTC` is rejected as stale.

There is no `client auth decision resolved` record for decision `1`, no `selected=0`, no `declined-consume`, and no phase `2`. The user-driven tab/load teardown is therefore observably distinct from T3 explicit Cancel. The implementation does not currently emit a literal `Aborted` label; its runtime representation is removal of the still-pending phase-0 decision during lifecycle teardown.

### Fresh decision and same-process recovery

The second tab remains in the same `Parent 6184` but uses `browser_id=15`. Its independent Treasury client-auth request creates fresh `decision=2` and a fresh picker at `03:43:54.093 UTC`.

Decision `2` resolves positively at `03:44:04.399 UTC` as `selected=1 remember=2`; its waiter is consumed with `reason=selected-consume` and the decision is removed in phase `1`.

Recovery evidence after that positive selection:

- eight later matching client-auth requests are served from `scope=session` without another picker;
- **9** `lk-fzs.roskazna.ru` TLS 1.2 / `0xFF85` mTLS handshakes complete with state `0x00000000` and `client_cert_loaded=1`;
- all 9 recovered handshakes reach `DriveHandshake verify ... ok=1 status=0x00000000` under the current verification path;
- the user confirms successful Treasury personal-cabinet authorization.

Whole-capture safety counts: two coordinated decisions, two picker requests, one positive decision resolution, zero `declined-consume`, zero `selected=0`, zero `E/GostTLS`, zero `0x80090326`, zero `0x0000054f`, and zero `MSSPI_X509_LOOKUP`.

### Conclusion

**T4 PASS / CLOSED.**

Closing the tab that owns an unanswered Firefox client-certificate picker abandons the pending client-auth decision through lifecycle teardown rather than converting it into explicit Declined state. The pending decision is removed cleanly, closing/stale callbacks cannot create an orphan replacement decision, and another tab in the same browser process receives a fresh decision/picker and completes successful Treasury GOST mTLS/application login.

Together T3 and T4 now runtime-prove the intended semantic split on the exact Session-default artifact: explicit picker Cancel is `Declined`/phase `2`, while involuntary tab/load abandonment remains unresolved phase `0` and is removed by teardown. Neither path poisons a later independent positive recovery.

**NEXT:** T5 Session failure-boundary regression.

Status: current; T4 involuntary Abort semantics closed, T5 next.
