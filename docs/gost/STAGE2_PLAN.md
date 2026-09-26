# r3dfox GOST TLS — Stage 2 plan

Last updated: 2026-08-26

This document defines the mandatory Stage 2 security/UX closure after the proven Stage 1 Treasury mTLS result. `PROJECT_STATE.md` is the current synthesis, `TODO.md` is the backlog, and `TEST_LOG.md` / dated volumes are the evidence trail.

Current Firefox-facing implementation under test:

- source SHA `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`;
- main run `32844083378`;
- job `97789764275`;
- artifact `9567881847`.

## Security invariants

1. A GOST connection may continue only after server trust is established by a matching Firefox certificate override, a valid positive browser-session verification cache entry for the exact server identity, or successful full verification on the current connection.
2. The positive server-verification cache is browser-session/process scoped only and is keyed by normalized host, normalized port, OriginAttributes and SHA-256 identity of the exact server leaf certificate.
3. Verification failure or internal verifier failure is never cached as trust.
4. No client certificate, `CertificateVerify`, private-key proof or protected application data may be disclosed before server trust is established.
5. Client-certificate negative outcomes are attempt-local. Only an explicit positive certificate selection may be remembered.
6. Client-certificate identifiers, subject/issuer identifying DN, provider/container identifiers, PIN/password/PFX/user data and raw sensitive captures must not be committed.

## Current server-verification state

Windows MSSPI peer-certificate acquisition in the current source uses `SECPKG_ATTR_REMOTE_CERT_CONTEXT` rather than unsupported `SECPKG_ATTR_REMOTE_CERT_CHAIN`; the existing Windows `CertGetCertificateChain` path remains responsible for chain construction.

Positive Treasury runtime now reports peer certificate/chain availability and `verify ok=1 status=0x00000000`. Final Stage 2 work must still:

- fail closed when `verifyOk == 0`;
- fail closed on any nonzero verification status;
- check Firefox temporary/permanent overrides before full verification;
- use the exact-identity positive session cache only after successful verification;
- prove the real Treasury host/chain positive case;
- prove wrong-hostname and invalid/untrusted-chain negative cases;
- prevent all client private-key operations until the server-trust gate passes.

## Firefox client-certificate picker — final UX contract

Use the stock Firefox client-auth UI rather than introducing a separate GOST-only window. GOST-specific behavior should be supplied through invocation/lifecycle state where necessary without globally changing normal NSS client-auth defaults.

### Certificate presentation

The dropdown row format is fixed as:

```js
`${cert.displayName}, действителен до ${date} [ ${cert.issuerCommonName} ]`
```

Requirements:

- `date` is the certificate expiration date formatted for the UI locale;
- `cert.displayName` is the human-facing owner label;
- the details field `Issued to` uses `cert.displayName` instead of full `cert.subjectName`, because the tested full Subject DN renders as mojibake while the structured display name is correct;
- `cert.issuerCommonName` is the compact issuer label; its Cyrillic rendering must be confirmed in runtime;
- certificate serial number remains details-only information.

### Remember policy

Firefox 153 defines:

- `Once = 0`;
- `Permanent = 1`;
- `Session = 2`.

The stock Firefox preference currently defaults to `Session`. **Do not change the global Firefox preference.**

For the GOST picker invocation only:

- initial remember choice is `Once` / do not remember;
- `Session` and `Permanent` apply only when the user explicitly chooses them;
- only a positive `Selected` certificate result may be written to remembered state;
- no negative, abort or provider-failure result may overwrite a remembered positive certificate.

### Attempt states

Keep attempt state separate from remember scope:

- `Pending` — a user certificate decision is outstanding;
- `Selected` — the user explicitly chose a certificate;
- `Declined` — the user explicitly chose to continue the current attempt without a certificate;
- `Aborted` — dialog/load/socket/navigation was torn down without a user decision;
- `NoUsableCertificate` — discovery produced no currently usable candidate;
- `Failed` — internal picker/certificate/provider operation failed.

`Declined`, `Aborted`, `NoUsableCertificate` and `Failed` are current-attempt outcomes only. A later attempt must be able to re-enumerate candidates and ask again.

## Clean asynchronous Firefox/Necko lifecycle

The current implementation opens the Firefox picker asynchronously but does not fully participate in normal Necko client-auth lifecycle. Confirmed consequences are a busy-spin in `MSSPI_X509_LOOKUP` and Firefox's ordinary 30-second TLS-handshake timeout destroying an unanswered GOST picker.

The exact Firefox 153 source confirms the intended stock selection architecture:

- `SSLGetClientAuthDataHook` runs on the Socket Thread, records the client-certificate request and returns a would-block indication;
- after server-certificate verification, certificate selection is dispatched to the main thread;
- the selected/no-certificate result is dispatched back to the Socket Thread to resume TLS;
- `NSSSocketControl::SetClientAuthCertificateRequest()` calls `mTlsHandshakeCallback->ClientAuthCertificateRequested()`; the source comment states that this lets Happy Eyeballs pause other racers before PSM may show a certificate dialog;
- `nsHttpConnection` forwards the requested/selected notifications to the HTTP transaction, whose abstract contract says Happy Eyeballs overrides these notifications to pause around the certificate dialog.

Do **not** overstate the scope of those notifications. They are proven to coordinate stock client-auth/Happy-Eyeballs behavior, but the source audit has not yet proven that the notifications alone suspend `nsHttpConnection`'s 30-second TLS-handshake timeout accounting. The final GOST integration must reuse the stock lifecycle and then verify the exact timeout behavior rather than assume the callback pair automatically disables the timer.

Final behavior must:

- signal/participate in the normal client-auth requested/selected lifecycle where applicable;
- put `MSSPI_X509_LOOKUP` into a truly quiescent wait while the Firefox picker is open;
- wake/resume only from a valid current decision callback;
- verify with runtime evidence that an active GOST picker is not destroyed by ordinary unfinished-handshake timeout handling; if additional stock-compatible timeout accounting is required, implement that explicitly rather than globally increasing or disabling the TLS timeout;
- treat load/socket/dialog teardown as `Aborted`, never as a remembered user decline.

## Concurrent client-auth requests — single-flight broker

Real Treasury runtime proves that a page transition can create several simultaneous mTLS handshakes and that the current per-socket implementation can request several Firefox dialogs within milliseconds. The user visibly received a second picker after already choosing a certificate.

Compatible requests must therefore share one in-flight selection decision.

The broker must:

- key compatibility at least by normalized host, port, OriginAttributes and exact acceptable-CA/issuer-list identity;
- never silently merge requests whose server issuer constraints materially differ;
- allow at most one active Firefox picker per compatible decision key/generation;
- attach later compatible MSSPI handshakes as waiters;
- on `Selected`, distribute the selected DER to every still-live compatible waiter;
- apply positive remember semantics once for the owning decision generation;
- resolve negative/aborted/failed generations without writing negative remembered state;
- reject obsolete/stale callbacks before they can mutate remembered state or current waiters;
- remove a closed socket from the waiter set without cancelling an unrelated live decision for other sockets.

Single-flight in-flight coordination and the positive remembered-choice cache are different layers. The former coordinates simultaneous handshakes; the latter may bypass a future picker only after an explicit positive remembered user decision.

## Candidate discovery and removable media

The current implementation enumerates `CurrentUser\\MY`, requires `CERT_KEY_PROV_INFO_PROP_ID`, builds local chains and filters candidates against the server acceptable-CA DER names.

Confirmed runtime semantics:

- zero candidates are rescanned on every later connection and are not negatively cached;
- restoring a certificate to `CurrentUser\\MY` while r3dfox remains running is detected on the next attempt;
- `CERT_KEY_PROV_INFO_PROP_ID` proves that a certificate has provider/container binding metadata, not that the private-key container is currently reachable;
- a certificate can therefore remain a picker candidate while its physical key medium is absent.

Direct token-only discovery is still open. Run a focused test with the certificate absent from `CurrentUser\\MY` and only the key medium/provider source present. If the certificate becomes visible through the normal store view, no direct provider enumeration is needed for that environment. If it remains invisible, add a CSP/KSP/CryptoPro provider discovery layer.

If multiple discovery sources expose the same certificate:

- deduplicate by certificate identity;
- do not show duplicate rows merely because one identity is visible through both MY and provider/media enumeration;
- prefer a currently usable hardware/removable private-key binding where that distinction is real and can be determined without interactive prompting.

Candidate enumeration itself must not trigger CryptoPro PIN/media/provider UI. Any key-usability probe used before selection must be silent/non-interactive.

## Private-key provider lifecycle

The latest confirmed runtime scenario keeps the client certificate in `CurrentUser\\MY` but removes the actual private-key container.

Observed behavior on the exact current artifact:

- the certificate remains eligible and can be supplied through `msspi_set_mycert()`;
- cancelling CryptoPro's insert-media notification fails the current `msspi_connect()` with `0x8009030E` (`SEC_E_NO_CREDENTIALS`);
- this provider failure does not become a negative Firefox certificate decision;
- a later attempt in the same browser process succeeds after the user inserts the key container;
- after recovery, repeated Treasury login-host TLS 1.2 / `0xFF85` mTLS handshakes complete and the user enters the personal cabinet.

Important interpretation: current `client_cert_loaded=1` means that `msspi_set_mycert()` accepted the certificate DER. It is not proof that the private key was acquired. Successful completion of the client-auth TLS handshake is the proof that SSPI/CryptoPro actually obtained and used the private key.

### Provider failure and remembered positive choice

If the user explicitly chose `Session` or `Permanent`, a temporary provider failure such as:

- missing key media;
- provider Cancel;
- `SEC_E_NO_CREDENTIALS`;
- PIN/private-key acquisition failure;

must not automatically erase or replace the positive certificate choice with a negative decision. The next attempt may retry the same selected certificate and allow CryptoPro to obtain the key again.

With the default GOST `Once`, no positive selection is retained automatically; a new login attempt asks for the certificate again. This is intentional.

### Provider UI / Socket Thread parity question

The confirmed CryptoPro insert-media UI is synchronous within the current `msspi_connect()` call on Mozilla's Socket Thread: one call remained inside the provider path for about 14.1 seconds until Cancel and the successful retry for about 27.0 seconds until media insertion.

This behavior is technically different from the GOST Firefox-picker busy-spin, but **synchronous token/provider waiting is not automatically a GOST-specific defect**. Exact Firefox 153 PSM source shows that `PK11PasswordPrompt()` creates a main-thread prompt runnable and calls `SyncRunnable::DispatchToThread(GetMainThreadSerialEventTarget(), runnable)`, synchronously waiting for the token/password UI result on the originating thread. During NSS TLS work that originating work is normally driven from the Socket Thread. Therefore stock Firefox itself permits a synchronous token/PIN interaction pattern after certificate selection.

Accordingly, do not require a custom worker-thread MSSPI redesign merely because the CryptoPro prompt blocks a `msspi_connect()` call. First preserve stock-like semantics and test whether the observed provider wait causes an actual regression beyond what Firefox accepts for interactive token authentication.

Additional constraints:

- pinned MSSPI documents that one handle is not thread-safe and should be used by a single thread; do not blindly move a live MSSPI/Schannel handle between Socket Thread and worker threads;
- `msspi_connect()` can return `-1` for transport I/O or certificate-selection waiting, but an external CryptoPro provider dialog is currently inside a synchronous SSPI call and cannot be converted into event-driven would-block behavior by Necko callbacks alone;
- if later runtime evidence shows unacceptable global-network starvation, timeout corruption or another concrete regression during long CryptoPro UI waits, investigate an asynchronous credential/provider architecture as a separate hardening step;
- candidate discovery must still never trigger invasive provider UI before the user has selected a certificate.

For stock parity, `ClientAuthCertificateRequested/Selected` should initially retain their natural meaning: the browser certificate-choice phase. Do not delay `Selected` until private-key media becomes available unless source/runtime evidence shows that Firefox's own lifecycle treats token/PIN acquisition that way.

## Issuer-aware policy

Continue using the real server acceptable-CA list as binary DER/X.500 policy input, not display-string heuristics.

Final work:

- compare each candidate certificate chain against the actual server issuer constraints;
- determine the correct match rule for Treasury and broader GOST endpoints;
- enforce validity, key-usage/EKU and private-key/provider requirements appropriate for client TLS auth;
- keep detailed issuer diagnostics deduplicated and sanitized in permanent documentation.

## Negative-path matrix

Before Stage 2 closure, exercise at least:

- no acceptable certificate;
- explicit no-certificate choice;
- dialog/load/navigation abort;
- unanswered picker beyond the former timeout boundary;
- concurrent mTLS requests during one page transition;
- certificate present but private-key media absent;
- provider media prompt Cancel;
- media inserted on retry without browser restart;
- long provider-media wait crossing 30 seconds;
- PIN/private-key acquisition failure where safely testable;
- wrong/unsuitable/expired certificate where safely available;
- server rejection;
- stale callback after socket teardown.

No negative case may poison future certificate prompts. Any explicitly remembered positive certificate should remain a positive choice unless the user changes/forgets it or the remembered identity is no longer valid under final policy.

## Ordered implementation / validation sequence

1. Implement GOST-scoped `Once` default, positive-only remember semantics and explicit attempt states.
2. Add generation-safe single-flight selection for compatible simultaneous mTLS requests.
3. Integrate the pending picker with the stock Firefox/Necko client-auth lifecycle, make the wait quiescent, and verify rather than assume the correct timeout behavior.
4. Re-run the Treasury picker/login scenario and prove a single user selection resumes all compatible live sockets without duplicate/queued dialogs, negative remembered state or the earlier application-500 symptom.
5. Re-run missing-media/provider interaction after the picker lifecycle fix, including a provider wait longer than 30 seconds. Treat synchronous provider waiting as stock-parity behavior unless it produces a concrete browser/network regression; only then investigate an async MSSPI/provider redesign.
6. Complete fail-closed server-verification/override/session-cache handling and positive + negative server trust tests.
7. Complete issuer-aware client-certificate filtering and direct token-only discovery decision.
8. Run the full negative client-auth matrix.
9. Run final real Treasury mTLS regression and record exact run/job/source SHA plus sanitized runtime evidence proving server trust, client selection, private-key use and authenticated application traffic.

Chromium-Gost remains a reference implementation for useful MSSPI patterns, not an authority over Firefox architecture.