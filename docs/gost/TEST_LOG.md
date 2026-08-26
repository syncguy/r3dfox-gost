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

Do not fix only the visible timeout symptom. The final design must distinguish an explicit user choice/cancel from dialog destruction caused by request/socket teardown, must define deliberate remember semantics for a real Cancel, and must make the asynchronous wait state non-spinning.

Status: current; Stage 2 client-auth UX/lifecycle blocker localized, no code fix applied yet.

---

## 2026-08-26 — The picker timeout is Firefox's built-in 30-second TLS-handshake timeout

**Track:** GOST TLS runtime / Stage 2 client-auth lifecycle source audit  
**Branch:** `agent/gost-tls-poc`  
**Source audited:** `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`

### Observation

The exact source-under-test defines `nsHttpHandler::mTLSHandshakeTimeout` as `30000` milliseconds. In `nsHttpConnection`, while the TLS handshaker is not complete, the connection measures elapsed TLS time and, once it exceeds `TLSHandshakeTimeout()`, sets close reason `TLS_TIMEOUT` and closes the transaction with `NS_ERROR_NET_TIMEOUT`. That source behavior matches the runtime capture's `30.375 s` interval from Firefox picker request to GOST socket closure.

Therefore the unanswered picker is not being terminated by a Treasury or HTTP-proxy idle timeout in this capture. Firefox's own HTTP/TLS connection lifecycle closes the still-incomplete TLS handshake after approximately 30 seconds.

The same `nsHttpConnection` source exposes explicit `OnClientAuthCertificateRequested()` and `OnClientAuthCertificateSelected()` notifications into the HTTP transaction. The current MSSPI picker path opens the Firefox dialog directly from the GOST SSL layer and does not yet participate in that normal Necko client-auth lifecycle. Before changing the timeout value, the correct follow-up is to understand and reuse the existing client-auth request/selection lifecycle where applicable, rather than globally weakening the TLS timeout.

### Conclusion

**The 30-second timer itself is now localized and is not the primary bug.** The integration problem is that the custom MSSPI asynchronous client-auth wait is still seen by Necko as an ordinary unfinished TLS handshake. The design investigation should focus on the stock Firefox/NSS client-auth lifecycle and on making `MSSPI_X509_LOOKUP` suspend/resume cleanly, while separately fixing stale-dialog/session-memory semantics.

Status: current; timeout source localized, implementation decision intentionally deferred until the remaining picker UX nuances are collected.

---

## 2026-08-26 — Zero eligible CurrentUser\\MY candidates are re-scanned on every mTLS attempt

**Track:** GOST TLS runtime / Stage 2 Firefox-facing client-certificate selection  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`  
**Actions run:** `32844083378`  
**Job:** `97789764275`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9567881847` (`r3dfox-gost-win64-release`)  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru` through the configured HTTP proxy  
**Runtime capture:** user-provided `gost_nocertinmy.zip`, SHA-256 `6bcfebe68c9e62d2648cdac616ba1abe5ba15f7460c09dca08c2f6657a8a9e3b`; inner `gost.moz_log`, SHA-256 `c74b81af1c8191e4cccec40368a0d7cb1e88841ffd466c4ce7ff7ac1da0e26ea`

### Purpose

Exercise the Firefox-facing client-auth path while no usable client certificate is available through the current `CurrentUser\\MY` discovery path, and determine whether the no-candidate result is cached or re-evaluated on later connections in the same browser process.

The raw runtime log is not committed. Only sanitized lifecycle/protocol facts are recorded.

### Sanitized observation

The ordinary Treasury host remains healthy in the same capture: ten `fzs.roskazna.ru` connections complete TLS 1.2 / `0xFF85`, and their completed verifier diagnostics report `verify ok=1 status=0x00000000`.

For `lk-fzs.roskazna.ru`, the capture contains five separate mTLS connection attempts between `06:57:18.269 UTC` and `06:57:27.060 UTC`.

Every attempt shows the same sequence:

- the real server acceptable-CA list is available with 34 entries;
- candidate discovery logs `client certificate candidates ... count=0 mode=firefox-ui`;
- no `client certificate dialog requested` event occurs;
- no `client certificate remembered` event occurs;
- the current callback path returns control to MSSPI without loading a client certificate;
- the Treasury server quickly returns TLS fatal `handshake_failure`, surfaced by SSPI as `0x80090326`, and the socket closes in MSSPI error state.

The capture does not expose the outbound client-auth handshake bytes because they are deliberately redacted, so the log alone is not used to claim the exact empty-Certificate wire encoding. The observed result is nevertheless consistent with the known no-client-certificate Treasury baseline: no client certificate is loaded and the server rejects the mTLS attempt.

Most importantly, all five attempts independently re-run candidate discovery and report `count=0`. The zero-candidate result is therefore **not** stored in the process-wide remembered-choice cache. Unlike the unanswered-picker timeout path, this scenario does not poison later prompts for the rest of the browser session.

There is no 30-second picker timeout or `MSSPI_X509_LOOKUP` UI busy-wait in this capture because the dialog is never opened when the candidate list is empty.

### Conclusion

**The current no-candidate path is non-sticky and recoverable in principle:** a later TLS attempt in the same browser process re-enumerates candidate sources. If a usable certificate becomes visible through the current discovery path before the next attempt, the browser can proceed to the picker without requiring a browser restart.

The runtime evidence proves only zero **eligible candidates returned by the current `CurrentUser\\MY` discovery/filtering code**, not that every Windows/CryptoPro certificate source is empty. The current source does not directly enumerate removable key media/CryptoPro provider containers. A focused follow-up should therefore keep the browser process alive, insert or expose a certificate on the key medium without manually installing a separate copy into `CurrentUser\\MY`, and retry the login. If the picker appears, the active provider stack projects the token certificate into the current Windows-store discovery sufficiently for this path. If candidate count remains zero, direct CSP/KSP/provider/media enumeration becomes justified Stage 2 work.

Status: current; zero-candidate retry behavior confirmed, removable-media discovery remains open.

---

## 2026-08-26 — Live CurrentUser\\MY reappearance works, then concurrent picker requests race with remembered decisions

**Track:** GOST TLS runtime / Stage 2 Firefox-facing client-certificate selection  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`  
**Actions run:** `32844083378`  
**Job:** `97789764275`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9567881847` (`r3dfox-gost-win64-release`)  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru` through the configured HTTP proxy  
**Runtime capture:** user-provided `gost_addcertinmy.zip`, SHA-256 `3b4a44d5d270c143ab0eae63531df7888892dc837cc67cf68173b2b4c79b09fa`; inner `gost.moz_log`, SHA-256 `dbf9294e589fb80744d4c028af0c64e3a6c58978a39e37ed98269e43a78632d8`

### Purpose

Keep the browser process alive after repeated no-candidate Treasury mTLS attempts, restore the usable certificate to `CurrentUser\\MY`, and retry the personal-cabinet flow. Determine whether candidate discovery reacts dynamically and whether the resulting Firefox-facing selection remains stable under the site's parallel connection load.

The raw runtime log is not committed. Only sanitized lifecycle/protocol facts are recorded. The user reported that the browser-visible personal-cabinet flow eventually showed an HTTP/application error 500; the GostTLS-only capture does not contain decrypted HTTP status text, so that status is recorded as a user-visible observation rather than inferred from the transport log.

### Sanitized observation

The first three `lk-fzs.roskazna.ru` attempts at `07:11:02.396`, `07:11:04.102`, and `07:11:05.701 UTC` independently report `client certificate candidates ... count=0` and fail with the expected no-client-certificate `0x80090326` server rejection.

Without restarting r3dfox, the certificate is then made visible again in `CurrentUser\\MY`. At `07:11:14.614 UTC` the next attempt immediately changes to `count=1` and opens the Firefox client-certificate dialog. The user selection completes at `07:11:19.701 UTC`. At `07:11:20.262 UTC` the same connection reports:

- `verify ok=1 status=0x00000000`;
- TLS 1.2 / suite `0xFF85`;
- `client_cert_loaded=1`;
- completed MSSPI handshake.

Immediately after that handshake the log shows successful protected application-data writes and reads. Therefore the live reappearance of an eligible `CurrentUser\\MY` candidate is detected without browser restart, and the selected certificate is usable for a real successful Treasury mTLS connection.

The capture then exposes a separate concurrency defect. At `07:11:21.894` through `07:11:21.914 UTC`, five additional `count=1` client-auth attempts request five Firefox dialogs within roughly 20 ms. Only two `client certificate dialog completed ... selected=1` events are eventually processed in the capture, at `07:11:19.701` and `07:11:27.524 UTC`, while multiple other MSSPI states remain pending concurrently.

After the later positive selection, four connections at `07:11:30.411` through `07:11:30.442 UTC` report `client certificate remembered ... selected=1 scope=session`. Four corresponding mTLS handshakes complete successfully between `07:11:30.676` and `07:11:31.082 UTC`, all with `client_cert_loaded=1`, `verify ok=1 status=0`, TLS 1.2, and `0xFF85`.

The state then becomes inconsistent. Starting at `07:11:31.755 UTC`, later connections begin reporting `client certificate remembered ... selected=0 scope=session`, followed by repeated `0x80090326` no-client-certificate failures. There is no active-path `client certificate dialog completed ... selected=0` line before this transition. Combined with the source behavior already established in the timeout experiment — a closed/stale dialog callback can write a null/Session result before the active-state guard prevents handshake wakeup — this is strong evidence that outstanding parallel dialog lifecycles can inject negative remembered decisions after positive selections have already succeeded.

The log does not include the remember-cache key or OriginAttributes in these lines, so this experiment does **not** distinguish whether a late negative callback overwrote an identical decision key or populated a different host+OriginAttributes key used by later parallel requests. It does prove that positive and negative remembered outcomes are both being consumed during the same short page transition and that independent per-socket dialogs are not safely coordinated.

### Conclusion

Two conclusions are now confirmed for the exact runtime artifact:

1. **Dynamic `CurrentUser\\MY` recovery works.** A certificate restored to the Windows personal store becomes eligible on a later mTLS attempt in the same browser process; no browser restart is required.
2. **The picker needs a single-flight/coordinated concurrency model.** The real Treasury page can trigger multiple simultaneous client-auth handshakes for the same login flow. Opening one independent Firefox dialog per MSSPI socket allows queued/stale dialogs and callbacks to race with positive remembered selections and can leave later requests using a no-certificate decision.

This experiment does not prove direct token-only discovery because the certificate was explicitly restored to `CurrentUser\\MY`. The separate removable-media/provider-enumeration question remains open.

The browser-visible 500 occurred after at least one and then several transport-level mTLS successes, so it must not be classified as a basic GOST TLS/client-certificate handshake failure from this log. The current leading integration issue is coordination of concurrent client-auth requests and stale dialog callbacks; an application-layer status diagnosis would require appropriate HTTP/application logging if it still reproduces after the client-auth race is removed.

Status: current; live MY re-enumeration confirmed, concurrent picker/single-flight requirement added to the Stage 2 lifecycle blocker.