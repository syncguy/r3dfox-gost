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
5. **CryptoPro interactive private-key UI currently blocks Mozilla's Socket Thread.** Unlike the Firefox picker bug, which currently busy-polls while waiting asynchronously, the provider prompt is entered synchronously inside `msspi_connect()` and holds the socket-thread call for roughly 14 s in the cancelled attempt and 27 s in the successful recovery attempt. At the time of this runtime-only conclusion, Stage 2 treated that as a potential independent lifecycle blocker; the source audit below later narrows that interpretation by identifying a stock Firefox synchronous token-prompt analogue.
6. Candidate discovery should not proactively trigger interactive CryptoPro provider UI merely to populate the Firefox certificate list. If stronger key-usability filtering is added, it must use a non-interactive/silent probe or defer actual private-key acquisition until the user has selected a certificate.

The final agreed GOST UX remains: the Firefox picker defaults to `Once`, scoped only to the GOST invocation. The global Firefox `security.client_auth_certificate_default_remember_setting` must remain unchanged. With that final default, a retry after the first provider cancellation will show the Firefox picker again unless the user explicitly chose `Session` or `Permanent`; this is intentional. If the user explicitly chose `Session`, retaining the positive selection across a temporary missing-container failure is also intentional.

Direct discovery of a certificate that exists only on removable/provider media and is absent from `CurrentUser\\MY` remains a separate open experiment.

Status: current runtime evidence; provider-blocking severity reclassified by the source audit below.

---

## 2026-08-26 — Firefox/NSS client-auth source audit narrows the CryptoPro Socket-Thread concern

**Track:** GOST TLS runtime / Stage 2 client-auth lifecycle source audit  
**Branch:** `agent/gost-tls-poc`  
**Firefox source audited:** `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`  
**Pinned MSSPI source audited:** `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`

### Purpose

Determine whether the stock Firefox client-auth lifecycle that should replace the GOST picker busy-spin also automatically solves the later CryptoPro insert-media wait, and whether synchronous provider/token UI on the Socket Thread is necessarily a GOST-specific defect.

### Source observation

`security/manager/ssl/TLSClientAuthCertSelection.cpp` documents the stock NSS client-auth sequence explicitly: `SSLGetClientAuthDataHook` runs on the Socket Thread, records that a certificate was requested and returns would-block; after server verification, certificate selection is dispatched to the main thread; the selected/no-certificate result is dispatched back to the Socket Thread so TLS can continue.

`NSSSocketControl::SetClientAuthCertificateRequest()` stores the request and invokes `mTlsHandshakeCallback->ClientAuthCertificateRequested()`. The exact source comment says this lets Happy Eyeballs pause other racers before PSM may show a certificate dialog. `nsAHttpTransaction.h` likewise describes the requested/selected hooks as no-op by default with Happy Eyeballs overriding them to pause around the certificate dialog.

This proves that the stock lifecycle is the correct architectural model for the **certificate-choice wait** and that the current GOST busy-spin should be replaced by a true event-driven would-block/resume path. It does not by itself prove that the callback pair suspends `nsHttpConnection`'s 30-second TLS-handshake timeout accounting. The timeout source still checks unfinished TLS elapsed time, so final GOST integration must verify the exact stock-compatible timeout behavior rather than assume the requested/selected notifications alone disable the timer.

Separately, `security/manager/ssl/nsNSSCallbacks.cpp` shows that stock PSM's `PK11PasswordPrompt()` creates a main-thread password/token prompt runnable and calls `SyncRunnable::DispatchToThread(GetMainThreadSerialEventTarget(), runnable)`, synchronously waiting for the result on the originating thread. During NSS TLS work this establishes a stock Firefox precedent for synchronous interactive token/PIN waiting after certificate selection.

Pinned MSSPI documentation states that the library is not thread-safe per handle: each handle should be used by a single thread, although multiple separate handles may run concurrently on different threads. Its `msspi_connect()` API returns `-1` for transport I/O or certificate-selection waiting, but the observed CryptoPro insert-media UI occurs inside a synchronous SSPI/provider call and therefore cannot be made event-driven merely by adding the Necko requested/selected callbacks.

### Conclusion

The two waits must be distinguished:

1. **Firefox certificate picker:** current GOST spin is an integration defect. Reuse the stock would-block/main-thread-selection/socket-thread-resume lifecycle, plus single-flight coordination and correct timeout accounting.
2. **CryptoPro media/PIN provider UI after selection:** the stock client-auth lifecycle does not make the synchronous SSPI call nonblocking. However, synchronous token UI has a stock Firefox PSM analogue, so the CryptoPro wait is no longer classified as an independently proven Stage 2 blocker solely because it holds the Socket Thread.

For initial parity, keep `ClientAuthCertificateRequested/Selected` scoped to the browser certificate-choice phase, as Firefox does. Do not delay `Selected` until CryptoPro media/private-key acquisition completes unless later source/runtime evidence requires that semantic change.

After the picker lifecycle fix, rerun missing-media authentication with a CryptoPro wait longer than 30 seconds and observe browser/network behavior. Only promote provider waiting to a separate asynchronous-MSSPI architecture problem if the real runtime shows a concrete regression such as unacceptable global network starvation, broken timeout state, or other behavior materially worse than stock Firefox token-auth semantics. Do not casually move a live MSSPI handle between threads because the pinned library's documented per-handle threading contract forbids treating it as generally thread-safe.

Status: current; stock picker lifecycle confirmed, provider Socket-Thread blocking reclassified from mandatory blocker to parity/performance question pending runtime evidence.

---

## 2026-08-26 — Coordinated Firefox client-auth implementation passes the short SSL compile gate

**Track:** GOST TLS runtime / Stage 2 client-auth implementation compile validation  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `860de8e38deed326b7fcd1c547e928c5b48c72a9`  
**Actions run:** `32951902976`  
**Job:** `98124948374`  
**Workflow:** `GOST SSL compile check`  
**Result:** success

### Purpose

Compile the first coordinated Stage 2 client-auth implementation before spending full-browser build time and before treating any lifecycle change as runtime-proven.

The source-under-test adds the new coordinated path while retaining the previously working per-socket implementation as an optional same-binary fallback. The default path is coordinated; setting `R3DFOX_GOST_CLIENT_AUTH_MODE=legacy` selects the legacy picker path. The explicit diagnostic thumbprint path remains separate and unchanged.

### Actions observation

GitHub Actions run `32951902976`, job `98124948374`, is bound to exact source SHA `860de8e38deed326b7fcd1c547e928c5b48c72a9` and completed with `conclusion=success`.

All preparatory gates completed successfully, including MSSPI source preparation, GOST/MSSPI `moz.build` registration, configure and export prerequisites. Most importantly, step `Compile security manager SSL target objects` completed successfully.

The compile-validated source contains the first implementation of:

- coordinated/single-flight Firefox client-certificate decisions with multiple live MSSPI waiters;
- a same-binary `legacy` mode for A/B comparison against the previously proven per-socket path;
- GOST-scoped `Once` as the initial remember choice without changing Firefox's global client-auth remember default;
- positive-only GOST remembered selections, so a null/no-certificate callback is not persisted as a negative GOST session decision;
- stale-callback/lifetime checks for coordinated decisions;
- `ClientAuthCertificateRequested()` / `ClientAuthCertificateSelected()` forwarding through `GostSocketControl` toward the existing Necko client-auth lifecycle;
- a coordinated picker-wait poll path intended to become quiescent instead of repeatedly re-entering `MSSPI_X509_LOOKUP`;
- the agreed human-facing certificate row/detail formatting changes.

### Scope of the conclusion

This run proves that the new Stage 2 source compiles through the project's dedicated Windows `security/manager/ssl` gate. It does **not** prove any of the following runtime properties:

- that the coordinated picker actually stays single-flight under Treasury's parallel login requests;
- that the new poll behavior eliminates the previously measured busy-spin;
- that Necko's 30-second TLS-handshake timeout is suspended or otherwise handled correctly while the picker is open;
- that an involuntary dialog teardown is distinguishable from an explicit user decline at the full UI/lifecycle contract level;
- that selection/remember semantics work correctly for `Once`, `Session` and `Permanent` in runtime;
- that the updated picker text/localization renders correctly in the installed Russian UI;
- that Treasury mTLS still completes successfully through the coordinated path;
- that a full Firefox browser build/package succeeds.

The two full-build runs automatically created during the preceding multi-commit push series do not provide source conclusions: main run `32951903026`, job `98124948716`, and thunk-rs run `32951903069`, job `98124948880`, were cancelled during checkout before their build gates. They must be rerun from the stable final source SHA or superseded by later full-build runs tied to the exact source tested.

### Conclusion

The implementation phase has advanced from source-only design to a **compile-validated coordinated client-auth checkpoint** at `860de8e38deed326b7fcd1c547e928c5b48c72a9`. The next evidence must come from full-browser builds and then a sanitized exact-build Treasury runtime matrix. Busy-spin, single-flight behavior, timeout handling and final UX semantics remain open until that runtime evidence exists.

Status: current compile evidence; runtime validation pending.

---

## 2026-08-26 — Coordinated Stage 2 source passes the authoritative main full-browser build/package gate

**Track:** GOST TLS runtime / Stage 2 full-browser build validation  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `860de8e38deed326b7fcd1c547e928c5b48c72a9`  
**Actions run:** `32951903026`  
**Run attempt:** 2  
**Job:** `98130275465`  
**Workflow:** `GOST TLS PoC build`  
**Release artifact:** `9606431408` (`r3dfox-gost-win64-release`)  
**Win7 import-audit artifact:** `9606431864` (`r3dfox-gost-win64-win7-import-audit`)  
**Result:** success

### Purpose

Close the main full-browser build/package gate for the exact coordinated Stage 2 source after attempt 1 of the same Actions run was cancelled during checkout before any meaningful build gate executed.

### Actions observation

GitHub Actions run `32951903026` is bound to exact source SHA `860de8e38deed326b7fcd1c547e928c5b48c72a9`. Attempt 2 completed with overall `conclusion=success`; job `98130275465` also completed with `conclusion=success`.

The job passed the preparatory Rust/build-std and SSL gates, then completed the full browser pipeline:

- `Build release r3dfox` — success;
- `Audit xul.dll Win7 imports` — success;
- `Package release r3dfox` — success;
- `Upload release package` — success;
- `Upload Win7 import audit` — success;
- `GATE - Reject known Win8+ imports after artifacts are uploaded` — success.

The resulting release artifact is `9606431408`. The separate audit artifact is `9606431864`.

Attempt-1 job `98124948716` from this same run had been cancelled during checkout. Because attempt 2 tests the same exact run head SHA and reaches the complete pipeline successfully, the earlier cancellation is superseded for build-validity conclusions and must not be treated as a source failure.

The separate thunk-rs workflow run `32951903069`, job `98124948880`, remained a cancelled checkout-only result at the time of this main-workflow entry; it was later superseded by the successful attempt-2 thunk result recorded below.

### Conclusion

The coordinated Stage 2 implementation at source SHA `860de8e38deed326b7fcd1c547e928c5b48c72a9` is now **full-browser build/package validated in the authoritative main GOST workflow**. The earlier short compile result is no longer the highest build-level evidence for this source.

This success does **not** prove any GOST TLS runtime or client-auth behavior. In particular it does not prove single-flight picker behavior, busy-spin removal, timeout semantics, remember behavior, Russian picker rendering, server-verification closure or successful Treasury mTLS. Those remain runtime/security gates.

Release artifact `9606431408` is the exact coordinated-source browser artifact to use for the next Stage 2 Treasury runtime matrix.

The successful Win7 import gate is evidence only for the import policy exercised by this main job. It does not prove Windows 7 runtime compatibility and does not establish GOST TLS behavior on Windows 7.

Status: current full-build evidence; coordinated Stage 2 runtime validation is now the immediate next experiment.

---

## 2026-08-26 — Legacy Gosuslugi IFCPlugin Firefox XPI baseline is vendored and validation-proven

**Track:** bundled government-system extensions / legacy Gosuslugi IFCPlugin  
**Branch:** `agent/gost-tls-poc`  
**Final validation source SHA:** `39f59bb954eb0fe047ef2a1b506ccddc3116f988`  
**Actions run:** `32972186494`  
**Job:** `98188295189`  
**Workflow:** `Bundled extensions smoke`  
**Evidence artifact:** `9608046113` (`bundled-extensions-smoke`)  
**Result:** success

### Purpose

Vendor and independently validate the user-supplied legacy Gosuslugi Firefox extension required by some Gosuslugi services, without depending on availability of the vendor download endpoint and without yet spending a full Firefox build/package cycle.

### Failed bootstrap/harness history

The failed runs in this sequence are preserved because they describe delivery/harness limitations rather than defects in the extension:

- run `32965953164`, job `98168356957`, source SHA `4c7e2fc13a8b805f9e0db77fa948a2c3d35cc9dd`: the initial bootstrap failed at `Invoke-WebRequest`; the GitHub-hosted Windows runner could not connect to `ds-plugin.gosuslugi.ru`, so SHA/ZIP/manifest validation was never reached;
- run `32970562907`, job `98183048135`, source SHA `93177619ce682400d4c19e7123296ea2708bb7d0`: CryptoPro validation passed, while the first manually transferred legacy XPI blob failed ZIP seeking, proving that the repository copy had been corrupted during binary transport rather than proving an upstream XPI defect;
- run `32970754844`, job `98183671594`, source SHA `109e4b6299be7ef8ef066cb3f69037de4e3d1988`: the alternative official URL was also unreachable from the hosted runner;
- run `32971692284`, job `98186694570`, source SHA `2a6b120faa5badd811973b9cb0785dc3cf8cab10`: the offline reconstruction gate deliberately stopped on an incorrect aggregate base64 length before replacing the fallback, protecting the repository from another corrupt binary.

The corrected offline reconstruction ran as `32971970880`, job `98187592267`, source SHA `3043fe92f8779391f899061a863d387a43b6d2c6`. It reconstructed exactly `20232` bytes, required SHA-256 `72916b4ed2adefd91049fbd93aff5e028c423c971c2e0012603a2dae343bdc80`, validated the XPI structure/manifest/native host, and committed the exact binary in commit `948a27194dd36f1d30b291f06c64d647d1d62f88` (`fix(extensions): restore exact legacy Gosuslugi XPI`). Temporary reconstruction files/workflow were then removed.

### Final validation observation

Final generic smoke run `32972186494`, job `98188295189`, source SHA `39f59bb954eb0fe047ef2a1b506ccddc3116f988` completed successfully. It independently validated both committed baselines and the registry hashes.

For the legacy Gosuslugi XPI it proved:

- repository path `r3dfox/extensions/pbafkdcnd@ngodfeigfdgiodgnmbgcfha.ru.xpi`;
- extension ID `pbafkdcnd@ngodfeigfdgiodgnmbgcfha.ru`;
- version `1.2.8`;
- size `20232` bytes;
- SHA-256 `72916b4ed2adefd91049fbd93aff5e028c423c971c2e0012603a2dae343bdc80`;
- valid ZIP/manifest and Mozilla signature structure;
- COSE signature structure present;
- Manifest V2;
- `nativeMessaging` permission present;
- native host reference `ru.rtlabs.ifcplugin` present;
- no `update_url` in the manifest.

The same run also revalidated the existing CryptoPro v1.2.14 fallback and its registry SHA. Both known official legacy-Gosuslugi URLs timed out from the hosted runner; this live check is intentionally non-fatal because the exact committed baseline is authoritative when the vendor endpoint is unavailable.

### Conclusion

The legacy Gosuslugi/IFCPlugin Firefox XPI baseline is now **vendored and short-validation-proven**. The earlier red runs are network/bootstrap/binary-delivery harness history and must not be interpreted as extension failures.

This result does **not** yet prove Mozilla `FINAL_TARGET_FILES` staging, final portable-archive packaging, clean-profile Firefox discovery, or functional communication with an installed `ru.rtlabs.ifcplugin` native host. Those remain separate extension-track integration/runtime gates.

Status: current baseline evidence; next step is real Mozilla packaging integration through the shared bundled-extension full-build workflow.

---

## 2026-08-26 — Three-extension government bundle passes real Firefox build/package and portable inspection

**Track:** bundled government-system extensions / shared Mozilla packaging  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `b3d097de20b7a5711f161199a727bcfe9468bcc8`  
**Companion short run:** `32976571124`  
**Companion short job:** `98202642893`  
**Companion evidence artifact:** `9609725660` (`bundled-extensions-smoke`)  
**Full Actions run:** `32976571122`  
**Full job:** `98202641607`  
**Workflow:** `CryptoPro Mozilla packaging smoke` (historical/transitional name)  
**Packaged-browser artifact:** `9614275050` (`r3dfox-cryptopro-mozilla-packaging`)  
**Packaging evidence artifact:** `9614275551` (`cryptopro-mozilla-packaging-evidence`)  
**Result:** success

### Purpose

Move from individual extension baselines to one real Firefox package containing the complete intended browser-side government-extension set while preserving the already-learned two-stage Mozilla packaging boundary. The same source also makes Russian the first website/content language preference for the produced browser bundle.

The three intended XPI baselines are:

- CryptoPro CAdES `ru.cryptopro.nmcades@cryptopro.ru`, version `1.2.14`;
- legacy Gosuslugi/IFCPlugin `pbafkdcnd@ngodfeigfdgiodgnmbgcfha.ru`, version `1.2.8`;
- Gosplugin `gosuslugi@plugin`, version `1.3.43.0`.

### Gosplugin bootstrap prerequisite / harness history

The current Gosplugin baseline was obtained through a short one-time AMO bootstrap before the shared integration commit. Preserve both runs because the first red result is a workflow-harness defect rather than an XPI defect:

- run `32974033522`, job `98194284032`, source SHA `339eb661782ab8b4cb5bcd1a02d930c37a862835`: step `Download and inspect signed AMO XPI` succeeded and validated ID `gosuslugi@plugin`, version `1.3.43.0`, size `1272459`, SHA-256 `f9a53a2fb4f33041676bf97d9ae9b061b67dde9ddbdc78221a06454381cd6cbc`, `nativeMessaging`, Mozilla signature structure and COSE. The workflow failed only afterward because `GOSPLUGIN_ID`, written to `GITHUB_ENV`, was incorrectly consumed in the same PowerShell step before GitHub Actions exposed it to the environment; the file was therefore copied as `r3dfox\extensions\.xpi`, and the subsequent commit step could not find `r3dfox\extensions\gosuslugi@plugin.xpi`. This is a harness environment-boundary failure, not an extension validation failure;
- corrected run `32974162330`, job `98194711292`, source SHA `9984e41623d675684eb1ad78a35b7830d1e024c0`: completed successfully. The validated signed XPI was vendored by bot commit `b98d04e204e6bd95d4cd532e1640642e7828b277`.

### Source-level integration observation

At source SHA `b3d097de20b7a5711f161199a727bcfe9468bcc8`, all three XPI paths are declared in `r3dfox/moz.build` under `FINAL_TARGET_FILES.distribution.extensions`, and all three are explicitly listed in `browser/installer/package-manifest.in`. This intentionally applies the lesson from the earlier CryptoPro failure: reaching `dist/bin` is not enough; installer/package staging is a separate boundary.

The same source stages `r3dfox/r3dfox-bundle.js` as a packaged default-pref file containing:

```js
pref("intl.accept_languages", "ru, en-US, en");
```

This preference controls website/content language negotiation order. It does not itself change the Firefox UI locale or install a Russian UI language pack.

Companion low-cost workflow `Bundled extensions smoke`, run `32976571124`, job `98202642893`, source SHA `b3d097de20b7a5711f161199a727bcfe9468bcc8`, completed successfully. It validated all three committed XPI baselines and registry hashes/versions, required the expected source/package manifest entries, and required the Russian-first language pref declaration. Evidence artifact: `9609725660`.

### Full Firefox build/package observation

Full workflow run `32976571122`, job `98202641607`, is bound to exact source SHA `b3d097de20b7a5711f161199a727bcfe9468bcc8` and completed with `conclusion=success`.

The job passed the full build/package path, including:

- `Build release r3dfox` — success;
- the historical CryptoPro `dist/bin` exact-XPI gate — success;
- `Package release r3dfox` — success;
- the historical CryptoPro final-portable exact-XPI gate — success;
- packaged-browser upload — success;
- packaging-evidence upload — success.

The run produced packaged-browser artifact `9614275050` and packaging evidence artifact `9614275551`.

Because the workflow still has CryptoPro-specific automated final gate names and assertions, the exact uploaded browser artifact was independently inspected after the run rather than treating CryptoPro's green gate as proof for the other two extensions.

### Exact portable-archive inspection

The `r3dfox-v153.0.3.win64.portable.7z` contained in artifact `9614275050` has SHA-256:

`8cdc8ee6ca304787a549bb6879db1f47510bde4d7b9fdc65a56a994bbefed66a`

Direct archive inspection confirms these exact entries:

- `distribution/extensions/gosuslugi@plugin.xpi` — size `1272459`, SHA-256 `f9a53a2fb4f33041676bf97d9ae9b061b67dde9ddbdc78221a06454381cd6cbc`, manifest ID `gosuslugi@plugin`, version `1.3.43.0`, Manifest V3;
- `distribution/extensions/pbafkdcnd@ngodfeigfdgiodgnmbgcfha.ru.xpi` — size `20232`, SHA-256 `72916b4ed2adefd91049fbd93aff5e028c423c971c2e0012603a2dae343bdc80`, manifest ID `pbafkdcnd@ngodfeigfdgiodgnmbgcfha.ru`, version `1.2.8`, Manifest V2;
- `distribution/extensions/ru.cryptopro.nmcades@cryptopro.ru.xpi` — size `76880`, SHA-256 `3df7ee8c7d655921abce942befc2bfd6e0ddcf9179e6173d72e35083844cc0e7`, manifest ID `ru.cryptopro.nmcades@cryptopro.ru`, version `1.2.14`, Manifest V2.

The same portable archive contains `omni.ja`. Inside that archive, `defaults/pref/r3dfox-bundle.js` contains the exact `pref("intl.accept_languages", "ru, en-US, en");` line. Therefore the Russian-first content-language preference also crossed the real package boundary; its source declaration is not merely a staging-only change.

### Conclusion

The complete three-extension browser bundle is now **real-Firefox build/package proven** at exact source SHA `b3d097de20b7a5711f161199a727bcfe9468bcc8`. All three expected signed XPI baselines are present in the exact portable `.7z` with their expected hashes and manifest identities, and the Russian-first website/content language pref is present in the packaged preference payload.

This closes shared Mozilla staging and final portable-archive inclusion for the three-extension set. It does **not** prove clean-profile discovery or native-component functionality of the two Gosuslugi extensions. Those extensions depend on external native components, and packaging success must not be interpreted as nativeMessaging runtime success. The new three-extension artifact also does not prove GOST TLS runtime behavior or Windows Vista/7 compatibility.

The next extension experiment is clean-profile runtime validation of artifact `9614275050`: confirm all three extensions are discovered/enabled, re-check CryptoPro functionality, then test legacy IFCPlugin and Gosplugin with their installed native components. The still-CryptoPro-named full packaging workflow should later be generalized so its automated final gates assert all three XPI plus the packaged language pref in a single full build.

Status: current; three-extension portable packaging milestone closed, runtime discovery/functionality pending.

---

## 2026-08-26 — Coordinated source passes the experimental thunk-rs full Firefox/xul build/package gate

**Track:** Windows Vista/7 compatibility / full Firefox/xul narrow YY-Thunks strategy  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `860de8e38deed326b7fcd1c547e928c5b48c72a9`  
**Actions run:** `32951903069`  
**Run attempt:** 2  
**Job:** `98205801026`  
**Workflow:** `GOST TLS PoC build - thunk-rs experiment`  
**Browser artifact:** `9613443984` (`r3dfox-gost-win64-thunk-experiment`)  
**Diagnostics artifact:** `9613444775` (`r3dfox-gost-win64-thunk-diagnostics`)  
**Result:** success

### Purpose

Obtain a clean current full-scale build/package/direct-import result for the experimental Windows Vista/7 linker path at the same exact coordinated Stage 2 source already validated by the main GOST build. Attempt 1 of this workflow had been cancelled during checkout and therefore supplied no compatibility evidence.

### Actions observation

Run `32951903069` attempt 2 is bound to exact source SHA `860de8e38deed326b7fcd1c547e928c5b48c72a9` and completed with overall `conclusion=success`. Job `98205801026` passed the complete intended path, including:

- `GATE - Reconfirm thunk-rs Win7 behavior and provision VC-LTL` — success;
- `GATE - Build narrow YY ProcessPrng + precise-time provider` — success;
- `GATE - Compile security manager SSL target objects` — success;
- `Build release r3dfox with narrow YY-Thunks linker path` — success;
- `Package thunk experiment` — success;
- `Upload thunk experiment package` — success;
- `Audit thunked xul.dll Win7 imports` — success;
- `Upload thunk diagnostics` — success;
- `GATE - Reject known direct Win8+ imports after artifacts are uploaded` — success.

The produced browser artifact is `9613443984`; the diagnostics artifact is `9613444775`. The artifact metadata ties both to the same exact source SHA.

Attempt-1 job `98124948880` from the same run was cancelled during checkout. The successful attempt-2 job supersedes that cancellation as build evidence for this source and workflow.

### Conclusion

The retained narrow YY-Thunks/thunk-rs linker strategy is now **cleanly full-Firefox/xul build/package/direct-import validated** at coordinated Stage 2 source SHA `860de8e38deed326b7fcd1c547e928c5b48c72a9`.

This result does not prove that artifact `9613443984` starts or operates correctly on real Windows 7, does not prove the delay-load import side because that parser remains separately qualified, and does not prove any GOST TLS runtime or handshake behavior. GOST runtime validation should continue first on the authoritative main artifact `9606431408`; the thunk artifact remains a separate Windows-compatibility runtime candidate.

Status: current full-xul Windows-compatibility build evidence; real target-OS and GOST-on-Win7 runtime validation remain open.