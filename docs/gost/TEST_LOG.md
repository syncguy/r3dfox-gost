# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-26_2026-08-26.md`](./TEST_LOG_2026-08-26_2026-08-26.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. For current technical synthesis, see [`PROJECT_STATE.md`](./PROJECT_STATE.md). For planned and deferred work, see [`TODO.md`](./TODO.md), and for the detailed Stage 2 design see [`STAGE2_PLAN.md`](./STAGE2_PLAN.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-08-26 — Missing private-key container is recoverable, but CryptoPro provider UI blocks the Socket Thread

**Track:** GOST TLS runtime / Stage 2 Firefox-facing client-certificate selection and private-key lifecycle  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`  
**Actions run:** `32844083378`  
**Job:** `97789764275`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9567881847` (`r3dfox-gost-win64-release`)  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru` through the configured HTTP proxy  
**Runtime capture:** user-provided `gost_notey_addkey.zip`, SHA-256 `e955abc1b623f51baba2844d77fa277580214fb10244f551fef9054397c6b385`; inner `gost.moz_log`, SHA-256 `6b297dedf58aab9d7f1c59fe090446d9817cea9aef1fbaccc0c2dc433891e070`

### Purpose

Exercise the case where the client certificate remains present in `CurrentUser\\MY` and carries private-key provider-binding metadata, but the actual CryptoPro private-key container/key medium is not available at the time of authentication. On the first attempt the user cancels CryptoPro's request to insert the key medium. On the second attempt, in the same browser process, the user inserts the required key container when CryptoPro asks again and then completes the Treasury login.

The raw runtime log is not committed. Only sanitized lifecycle/error/timing facts are recorded; no certificate, container, provider, PIN, or account identifiers are published.

### Sanitized observation

The certificate remains eligible for the Firefox picker even while its actual private-key container is unavailable. The current candidate filter verifies that `CERT_KEY_PROV_INFO_PROP_ID` exists, which establishes provider/container binding metadata but does not establish that the referenced private key is currently reachable.

The selected certificate is accepted by `msspi_set_mycert()`. In the current wrapper that success sets `clientCertLoaded=true`; therefore `client_cert_loaded=1` means that the certificate DER has been installed into MSSPI/Schannel, not that the associated private key has already been acquired or used successfully. The real private-key acquisition/use occurs later during `msspi_connect()` inside Schannel/CryptoPro.

#### First attempt: missing container, CryptoPro prompt cancelled

The first `lk-fzs.roskazna.ru` attempt starts at `07:18:47.964 UTC`. The Firefox certificate decision is available and the selected certificate is passed to MSSPI. At `07:18:50.959 UTC` the socket-thread path logs reuse of the positive selected certificate.

The following `msspi_connect()` invocation then remains inside the SSPI/CryptoPro provider path for approximately `14.1 s`, matching the period in which CryptoPro displays its external request to insert the key medium. After the user presses Cancel, `msspi_connect()` returns failure with `0x8009030E` (`SEC_E_NO_CREDENTIALS`) at `07:19:05.052 UTC`. The current TLS attempt closes. Follow-on calls against the already-failed MSSPI state produce secondary `0x0000054F` diagnostics; they are not treated as the primary cause.

This provider-level failure does not create a negative Firefox client-certificate decision and does not poison future login attempts.

#### Second attempt: container inserted when CryptoPro asks

A new `lk-fzs.roskazna.ru` connection begins at `07:19:17.963 UTC`. Because the current test build still uses Firefox's stock `Session` default and the previous certificate choice was positive, the same selected certificate is reused without opening another Firefox picker. At `07:19:18.118 UTC` the positive selected certificate is again passed to MSSPI.

The next `msspi_connect()` remains inside the SSPI/CryptoPro provider path for approximately `27.0 s` while CryptoPro waits for the private-key medium. The user inserts the required key container. The call then resumes normally; the client-auth handshake continues, the server Finished is received, and at `07:19:45.389 UTC` the connection reports:

- server verification `ok=1 status=0x00000000`;
- TLS 1.2 (`0x0303`);
- cipher suite `0xFF85`;
- `client_cert_loaded=1`;
- completed MSSPI handshake.

Protected application-data traffic follows immediately. The user confirmed browser-visible successful entry into the Treasury personal cabinet. After the key container became available, the capture contains additional successful `lk-fzs.roskazna.ru` mTLS connections; nine login-host handshakes complete successfully in total, with no `0x80090326` server no-certificate failure in this capture.

### Conclusions

1. **A missing private-key container is recoverable without restarting r3dfox.** Cancelling CryptoPro's insert-media prompt fails only the current TLS attempt with `SEC_E_NO_CREDENTIALS`; a later connection can reuse/reselect the certificate and succeed once the private key becomes available.
2. **`CERT_KEY_PROV_INFO_PROP_ID` is binding metadata, not a live-key availability check.** A certificate can remain a valid picker candidate while its referenced private-key container is temporarily absent.
3. **`client_cert_loaded=1` is not by itself proof that the private key was available.** In the current wrapper it is set after `msspi_set_mycert()` accepts the certificate. Successful completion of the subsequent mTLS handshake is the proof that CryptoPro/SSPI actually obtained and used the private key.
4. **Provider failure must not erase a positive user certificate choice.** If the user explicitly asked to remember a selected certificate, temporary `SEC_E_NO_CREDENTIALS`, missing media, cancelled provider UI, or similar private-key failures must remain attempt-local and must not be converted into a remembered no-certificate decision.
5. **CryptoPro interactive private-key UI currently blocks Mozilla's Socket Thread.** Unlike the Firefox picker bug, which currently busy-polls while waiting asynchronously, the provider prompt is entered synchronously inside `msspi_connect()` and holds the socket-thread call for roughly 14 s in the cancelled attempt and 27 s in the successful recovery attempt. Stage 2 must investigate how to prevent long interactive provider waits from monopolizing the global Socket Thread without breaking the Schannel/MSSPI context.
6. Candidate discovery should not proactively trigger interactive CryptoPro provider UI merely to populate the Firefox certificate list. If stronger key-usability filtering is added, it must use a non-interactive/silent probe or defer actual private-key acquisition until the user has selected a certificate.

The final agreed GOST UX remains: the Firefox picker defaults to `Once`, scoped only to the GOST invocation. The global Firefox `security.client_auth_certificate_default_remember_setting` must remain unchanged. With that final default, a retry after the first provider cancellation will show the Firefox picker again unless the user explicitly chose `Session` or `Permanent`; this is intentional. If the user explicitly chose `Session`, retaining the positive selection across a temporary missing-container failure is also intentional.

Direct discovery of a certificate that exists only on removable/provider media and is absent from `CurrentUser\\MY` remains a separate open experiment.

Status: current; missing-private-key recovery proven, provider-UI Socket Thread blocking added to the Stage 2 lifecycle blocker.