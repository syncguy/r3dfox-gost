# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-25_2026-08-26.md`](./TEST_LOG_2026-08-25_2026-08-26.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. For current technical synthesis, see [`PROJECT_STATE.md`](./PROJECT_STATE.md). For planned and deferred work, see [`TODO.md`](./TODO.md), and for formally closed milestones see [`DONE.md`](./DONE.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-08-26 — Firefox client-cert picker timeout poisons the session decision and exposes a busy wait

**Track:** GOST TLS runtime / Stage 2 Firefox-facing client-certificate selection  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e` (`fix(gost): use Firefox thread-safe refcounting`)  
**Actions run:** `32844083378`  
**Job:** `97789764275`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9567881847` (`r3dfox-gost-win64-release`)  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru` through the configured HTTP proxy  
**Runtime capture:** user-provided `gost_timeout.zip` / inner `gost.moz_log`, SHA-256 `cab8233fc519b5b642a5997eebcc26180f3ae0dea781e3410f73a1575cb136cc`

### Purpose

Exercise the new Firefox-facing client-certificate picker with `R3DFOX_GOST_CLIENT_CERT_THUMBPRINT` unset, deliberately leave the picker unanswered until the browser times out the load, then use `Try Again` / reload to observe retry behavior in the same browser process.

The raw runtime log is not committed because it contains verbose TLS/issuer diagnostics. Only sanitized protocol and lifecycle facts are recorded here.

### Sanitized observation

The ordinary Treasury host establishes the repaired server-certificate acquisition path successfully in this build. The capture contains repeated completed TLS 1.2 / `0xFF85` handshakes for `fzs.roskazna.ru`; the completed verification diagnostics report `verify ok=1 status=0x00000000`, with peer certificate and built chain available. This is positive evidence for the `SECPKG_ATTR_REMOTE_CERT_CONTEXT` acquisition change, but it is not yet the required negative/fail-closed verification proof.

For the first `lk-fzs.roskazna.ru` mTLS connection:

- the server-provided acceptable-CA list is available;
- candidate filtering produces exactly one Firefox-UI candidate;
- `client certificate dialog requested ... mode=firefox-ui` occurs at `04:22:05.949 UTC`;
- MSSPI enters `0x00000008` (`MSSPI_X509_LOOKUP`) and the callback returns pending while the user makes no selection;
- the GOST socket is closed at `04:22:36.324 UTC`, exactly `30.375 s` after the dialog request, still in `MSSPI_X509_LOOKUP`;
- no `client certificate dialog completed` line occurs before that socket close.

While the dialog is waiting, the socket thread does not become quiescent. Between the dialog request and the first socket close the capture contains roughly 75.7k repeated `DriveHandshake` / `msspi_connect` / issuer-list calls in about 30.4 seconds. This is a separate busy-wait/polling defect in the asynchronous picker wait state and explains the disproportionate 225 MB log size for a short session.

The browser then closes the picker together with the failed load. The current Firefox dialog service starts with `cert=null` and `rememberDuration=Session`; the GOST callback therefore records the no-certificate result as a remembered session decline even though the original MSSPI/socket state has already been removed by `GostClose`.

Two subsequent `lk-fzs.roskazna.ru` connection attempts in the same process confirm the resulting session poisoning:

- each new connection reaches the real server `CertificateRequest` path;
- each immediately logs `client certificate remembered ... selected=0 scope=session`;
- no new Firefox certificate dialog is requested;
- no client certificate is loaded;
- the server returns TLS fatal `handshake_failure`, surfaced by SSPI as `0x80090326`, followed by the expected error-state retries/closure.

The user independently confirmed the lifecycle boundary: completely terminating and restarting r3dfox clears the in-memory remembered decision, after which the certificate picker appears again and a timely selection can successfully enter the Treasury personal cabinet.

### Conclusion

**The new Firefox-facing picker is runtime-reachable and can complete a real Treasury mTLS login when the user selects the certificate in time, but the unanswered-dialog path has three confirmed integration defects at source SHA `5e8c8821...`:**

1. the underlying network/TLS load times out while the asynchronous certificate dialog is still awaiting user input;
2. automatic dialog destruction after that timeout is misclassified as a session-level user decline, suppressing all later picker prompts for the host until browser restart;
3. the `MSSPI_X509_LOOKUP` wait state busy-polls the socket/handshake instead of remaining dormant until the UI callback resumes it.

The stale-callback lifetime guard itself appears to prevent resuming the already-closed MSSPI state: there is no old-socket `dialog completed`/continued handshake after `GostClose`. The bug is that the callback still mutates the process-wide remembered-decision cache before the inactive-state check prevents the wakeup.

Do not fix only the visible timeout symptom. The final design must distinguish an explicit user choice/cancel from dialog destruction caused by request/socket teardown, must define deliberate remember semantics for a real Cancel, and must make the asynchronous wait state non-spinning. The exact source of the approximately 30-second underlying network timeout still requires localization against Firefox/Necko lifecycle behavior before choosing the final mechanism.

Status: current; Stage 2 client-auth UX/lifecycle blocker localized, no code fix applied yet.
