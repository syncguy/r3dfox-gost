# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-26_2026-08-27.md`](./TEST_LOG_2026-08-26_2026-08-27.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. For current technical synthesis, see [`PROJECT_STATE.md`](./PROJECT_STATE.md). For forward work, see [`TODO.md`](./TODO.md). The restart-safe Stage 2 runtime sequence is [`STAGE2_RUNTIME_TEST_PLAN.md`](./STAGE2_RUNTIME_TEST_PLAN.md); the GIS GMP multi-host mTLS branch is [`STAGE2_GIS_GMP.md`](./STAGE2_GIS_GMP.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-08-27 — Unanswered coordinated picker times out and shutdown re-entrancy leaves a sticky orphan decision

**Track:** GOST TLS runtime / Stage 2 coordinated Firefox client-auth lifecycle  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `860de8e38deed326b7fcd1c547e928c5b48c72a9`  
**Actions run:** `32951903026`  
**Run attempt:** 2  
**Job:** `98130275465`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9606431408` (`r3dfox-gost-win64-release`)  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru` through the configured HTTP proxy  
**Runtime capture:** user-provided `gost_timeout_260827.zip`, SHA-256 `92f19f308bcc57394ad8f40d285d2e4934a5ee7d1707568d5c2507d2458909d9`; inner `gost.moz_log`, SHA-256 `8dd16505df8095806d60eddcb1d92844b87c04e5caa253b1003a3010f640cda5`

### Purpose

Exercise the unanswered-picker timeout/teardown path on the exact coordinated browser already proven to complete real Treasury mTLS. Determine whether the new coordinator survives involuntary load/socket teardown and whether F5 / `Try again` / a fresh login attempt can show a new picker without restarting r3dfox.

The raw capture is not committed. Only sanitized lifecycle/error/count/timing facts are recorded.

### User-visible observation

The Firefox certificate picker opened during transition to the Treasury personal cabinet and was left unanswered. After waiting, the picker disappeared and Firefox showed:

`The connection has timed out`

for `lk-fzs.roskazna.ru`.

Without restarting the browser, the user tried:

- F5;
- the `Try again` button;
- returning to the main Treasury page;
- initiating the personal-cabinet login again.

None of those actions displayed another client-certificate picker.

### Timeline / sanitized runtime observation

The first coordinated picker is requested at `02:56:22.161 UTC`.

At `02:57:07.166 UTC`, approximately `45.005 s` later, the socket enters `GostClose()` with the MSSPI state still in client-certificate wait. Therefore this exact coordinated artifact does **not** reproduce the previously assumed exact 30-second boundary. The observed boundary is approximately 45 seconds and the concrete timeout source must be attributed before any timeout-policy change.

During the `45.005 s` wait:

- `GostPoll client-auth wait quiescent` occurs `13,107` times, approximately `291/s` average;
- there are zero `MSSPI_X509_LOOKUP` markers;
- the old repeated client-certificate handshake re-entry is absent while the picker is simply waiting.

The critical failure occurs during close:

1. outer coordinated `GostClose()` removes the current waiter;
2. it calls the preserved legacy close path;
3. legacy close enters `msspi_shutdown()` on the same MSSPI handle;
4. while that handle is already closing, MSSPI/SSPI invokes the client-certificate callback again;
5. at `02:57:07.182 UTC`, that re-entrant callback sees no active decision because the original waiter/decision was already removed;
6. it enumerates candidates and creates a **new coordinated decision + picker/waiter** for the handle that is in the process of being destroyed;
7. the first/original dialog callback later arrives at `02:57:07.480 UTC` and is correctly rejected as stale;
8. the shutdown-created decision is left with an orphan waiter because the outer pre-close cleanup already ran and there is no equivalent post-legacy-close cleanup for the newly-created waiter.

When the shutdown-created dialog later resolves without a certificate, that surviving decision becomes terminal `Declined`. It is not a remembered-cache entry; it is a still-live coordinated decision object with an orphan waiter.

Subsequent real connections use the same compatible decision key, find that stale terminal decision, and immediately consume:

`client certificate dialog completed ... selected=0 mode=coordinated`

instead of opening a fresh picker.

The capture contains ten such later `selected=0` attempts. Each reaches primary MSSPI failure `0x80090326`; twenty secondary `0x0000054f` diagnostics follow against already-failed MSSPI state.

### Source interpretation

The current coordinated wrapper removes the waiter before delegating to the legacy close path. The preserved legacy close performs `msspi_shutdown()`. Therefore a client-cert callback re-entered from shutdown can run **after the pre-close removal** but **before the MSSPI handle is destroyed**, creating state that the existing outer cleanup never sees.

The stale-callback guard is working for the original abandoned dialog. It is not sufficient because the bug creates a new current decision during shutdown rather than merely receiving an obsolete callback after teardown.

### Conclusions

1. **The coordinated unanswered-picker path currently has a deterministic close/shutdown lifecycle defect.** A client-cert callback during `msspi_shutdown()` may create a new decision for a handle that is already closing.
2. **The post-timeout “never asks again” behavior is not caused by the custom remembered positive/negative cache.** It is caused by an orphan coordinated decision/waiter surviving the close and later becoming `Declined`.
3. **F5 / `Try again` / new navigation cannot recover while that orphan decision remains.** New connections consume its terminal `selected=0` result and fail with `0x80090326`.
4. **The old `MSSPI_X509_LOOKUP` tight spin is gone in this test.** The new poll path still has substantial periodic churn (`13,107` calls / `45.005 s`) and is not fully event-quiescent, but this is secondary to the lifecycle corruption.
5. **Do not assume an exact 30-second picker timeout for the coordinated artifact.** The observed close occurs around 45 seconds; first identify the timer/lifecycle source.
6. **Do not ask the user to repeat this test on artifact `9606431408`.** The evidence is complete for the defect. Repeat only as T2R after a fixing source/build exists.

### Required fix / next experiment

Before `msspi_shutdown()`:

- mark the relevant MSSPI/socket as closing;
- refuse certificate-selection callbacks for a closing handle before decision lookup/create/join or dialog dispatch;
- preserve handle identity and perform defensive waiter removal after the legacy close returns;
- add decision/waiter/closing lifecycle diagnostics;
- preserve stale-callback rejection.

After the fix passes the short SSL compile gate and an authoritative main full build, the **first** runtime regression is T2R:

unanswered picker -> timeout/teardown -> without browser restart F5 / `Try again` / new login -> a fresh picker must appear, with no orphan decision and no automatic `selected=0`.

The separate successful-login defect from the preceding T1 experiment (three sequential `Once` pickers across one logical login) remains a second independent lifecycle issue. It requires a positive-only attempt-local `Once` fanout/lease and is tested as T1R after the relevant fix.

Full restart-safe ordering is recorded in `STAGE2_RUNTIME_TEST_PLAN.md`.

Status: current blocker; shutdown-created orphan decision must be fixed before further client-auth runtime matrix work.

---

## 2026-08-27 — GIS GMP certificate login exposes Treasury-only client-auth host scope

**Track:** GOST TLS runtime / Stage 2 multi-host client-auth coverage  
**Branch:** `agent/gost-tls-poc`  
**Code audited:** `860de8e38deed326b7fcd1c547e928c5b48c72a9`  
**Surrounding runtime browser:** main run `32951903026`, attempt 2, job `98130275465`, artifact `9606431408`  
**Runtime target:** `pay.gov.ru` -> `portalgisgmp.login.roskazna.ru` -> `portalgisgmp.cert.roskazna.ru`  
**Runtime capture:** initially not supplied with this exploratory observation; superseded by the runtime-capture entry below

### User-visible exploratory observation

The browser was launched with all three GIS GMP hosts explicitly in `R3DFOX_GOST_HOSTS`, with the explicit thumbprint selector, legacy mode selector and cipher override cleared.

The user reports:

1. `pay.gov.ru` is successfully handled through GOST TLS;
2. the flow reaches `portalgisgmp.login.roskazna.ru`, also through GOST TLS, and displays the password-login page;
3. the page contains an alternative login-by-certificate action expected to use `portalgisgmp.cert.roskazna.ru` as a GOST mTLS endpoint;
4. activating that path produces neither the expected visible transition nor a Firefox client-certificate picker.

The initial hypothesis was that GIS GMP may advertise an acceptable-CA list different from the Treasury personal-cabinet endpoint.

### Exact-source audit

The current source has a deterministic earlier restriction which prevents the acceptable-CA hypothesis from being exercised.

`nsGostSSLIOLayerLegacy.inc` still defines:

`kStage1MtlsHost = "lk-fzs.roskazna.ru"`.

Socket setup registers:

`msspi_set_cert_cb(secret->msspi, SelectStage1ClientCertificate)`

only when `aHost` equals that one Stage-1 host. Therefore a GOST MSSPI socket for `portalgisgmp.cert.roskazna.ru` does not have our Firefox client-certificate callback registered.

In addition, the current `SelectStage1ClientCertificate()` wrapper obtains the actual host and explicitly rejects any host other than `lk-fzs.roskazna.ru` before issuer logging, coordinated decision handling, candidate enumeration or dialog dispatch.

Thus the current browser cannot reach the Firefox client-auth picker on the GIS GMP certificate endpoint regardless of which acceptable certificate authorities the server sends.

### Existing generic issuer/candidate path

After the host restriction is removed, the existing code is already mostly host-neutral:

- `CollectGostCANames()` obtains the MSSPI `CertificateRequest` CA distinguished names;
- `CollectGostClientCertCandidates()` enumerates `CurrentUser\MY`;
- certificates without `CERT_KEY_PROV_INFO_PROP_ID` are excluded;
- Windows certificate chains are built;
- every chain element Subject/Issuer is compared with the server CA names;
- an empty CA list currently permits candidates rather than filtering them all out.

The current `GostCertNameEquals()` implementation uses equal DER length plus raw `memcmp`. This is a possible second compatibility boundary for differently encoded/cross-signed PKI paths, but there is no GIS GMP runtime evidence yet that it is the failing layer. Do not change it speculatively.

### Conclusions

1. **The immediate GIS GMP failure is explained by a Stage-1 Treasury-only client-auth host gate.** GOST transport is already multi-host via the allowlist, but GOST client-auth callback registration/dispatch is not.
2. **The acceptable-CA hypothesis remains open, not disproven.** It becomes testable only after generic callback reachability exists for `portalgisgmp.cert.roskazna.ru`.
3. **Do not ask the user to repeat the same GIS GMP test on artifact `9606431408`.** Source audit already proves this build cannot open the generic Firefox picker on that host.
4. **Add F3 to the next fixing candidate:** generic GOST mTLS client-auth capability for every already-selected/allowlisted GOST socket that actually receives a client-cert request, while keeping backend selection and credential remember policy scoped normally.
5. **Keep the explicit thumbprint selector narrow/diagnostic.** Generalizing the Firefox UI path must not silently turn one locally configured Treasury thumbprint into a cross-site automatic credential choice.
6. The coordinated decision key already includes host/port/OriginAttributes/acceptable-CA identity, so multi-host client-auth must preserve that isolation and never reuse a Treasury decision at GIS GMP.

### Next experiment

F3 is included with F1/F2 in the next candidate build, but remains separately attributable.

After short SSL compile and authoritative main full build:

1. first run T2R and T1R to prove coordinator lifecycle regressions;
2. run GIS-G1: `pay.gov.ru` -> login host -> certificate endpoint and prove callback registration, issuer collection and candidate enumeration;
3. if candidate count is nonzero, continue to GIS-G2 real GOST mTLS/application login;
4. if candidate count is zero, stop and analyze the actual server CA list against the local chain, including cross-signed path selection and raw-DER-name comparison, before changing issuer policy.

Full GIS GMP recovery/test plan is preserved in `STAGE2_GIS_GMP.md`.

Status: source-proven multi-host client-auth blocker; superseded as the highest evidence by the runtime capture below.

---

## 2026-08-27 — GIS GMP runtime confirms real CertificateRequest, empty client certificate, and server handshake failure

**Track:** GOST TLS runtime / Stage 2 multi-host client-auth coverage  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `860de8e38deed326b7fcd1c547e928c5b48c72a9`  
**Actions run:** `32951903026`  
**Run attempt:** 2  
**Job:** `98130275465`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9606431408` (`r3dfox-gost-win64-release`)  
**Runtime target:** `pay.gov.ru` -> `portalgisgmp.login.roskazna.ru` -> `portalgisgmp.cert.roskazna.ru`  
**Runtime capture:** user-provided `gost_pay.gov.ru.zip`, SHA-256 `2e9630e5d8048482ebc6a3d3ac0576db6af2c6b4e108c3c1de6ea4e30d99596b`; inner `gost.moz_log`, SHA-256 `f32fd8bf7067dd487e79121faf467f1038906d91ed958df87c572aff991bc5ed`

### Capture scope

The capture contains `51,925` log lines and spans `2026-08-27 03:28:19.547 UTC` through `03:28:55.898 UTC` (`36.351 s`). The raw capture is not committed; only sanitized protocol/lifecycle facts and non-sensitive artifact hashes are recorded.

### Positive GOST transport before certificate login

The runtime log independently confirms the user-visible path:

- `pay.gov.ru` matches the explicit allowlist, receives the MSSPI GOST layer, verifies with `ok=1 status=0x00000000`, and completes one TLS 1.2 / `0xFF85` handshake with `client_cert_loaded=0`;
- `portalgisgmp.login.roskazna.ru` also matches the allowlist and completes five TLS 1.2 / `0xFF85` handshakes in this capture, all with positive `verify ok=1 status=0x00000000` and `client_cert_loaded=0`.

Thus ordinary GOST transport for the public GIS GMP and password-login hosts is runtime-proven on this exact artifact.

### Certificate endpoint is reached and requests real mTLS

The browser does make the network transition to `portalgisgmp.cert.roskazna.ru`. The log contains three separate allowlist matches / GOST-layer attachments for that host, beginning at `03:28:45.657`, `03:28:50.793`, and `03:28:52.295 UTC`.

The first server handshake can be reconstructed from the logged TLS records without publishing any user credential. The server sends a TLS 1.2 `CertificateRequest` handshake message (type `13`) with body length `12,184` bytes. Its `certificate_authorities` vector is `12,143` bytes and contains **36 DER Distinguished Names**; all 36 decode as X.509 `Name` values.

Therefore the server acceptable-CA list is emphatically **not empty**. The earlier hypothesis that GIS GMP may use a different CA policy remains relevant only as a candidate-compatibility question after F3; absence of an advertised CA list is disproven.

### Current browser sends no client certificate

For all three `portalgisgmp.cert.roskazna.ru` attempts, the logged outbound TLS handshake contains the exact TLS `Certificate` prefix:

`0B 00 00 03 00 00 00`

This is a TLS 1.2 `Certificate` message whose `certificate_list` length is zero: the client explicitly sends an **empty client-certificate list**.

No `client certificate ...`, `issuer-list ...`, or `AddToSocket set_cert_cb ...` marker for `portalgisgmp.cert.roskazna.ru` appears in the capture. This matches the exact-source audit: the custom Firefox/MSSPI client-certificate callback is registered only for `lk-fzs.roskazna.ru`, so the GIS GMP mTLS request never reaches our coordinator/candidate path.

After the empty client certificate, the server returns TLS alert record `15 03 03 00 02 02 28`: alert level `fatal` (`2`), description `handshake_failure` (`0x28`, decimal 40). MSSPI then reports primary `0x80090326` on each of the three certificate-host attempts. Two later calls per failed handle produce the already-known secondary `0x0000054f` diagnostics.

No `MSSPI handshake complete` or final `DriveHandshake verify` marker exists for the certificate host because the handshake is rejected before completion.

### Conclusions

1. **The GIS GMP certificate-login button does reach `portalgisgmp.cert.roskazna.ru` at the network layer.** The missing visible navigation is a consequence of the mTLS failure, not failure to initiate the transition.
2. **`portalgisgmp.cert.roskazna.ru` really requests a client certificate.** This is now runtime-proven from the TLS `CertificateRequest`, not inferred from the site UX.
3. **The server advertises a substantial acceptable-CA list: 36 DER DNs.** The list itself is not absent.
4. **The current browser sends an empty client Certificate on every tested certificate-host attempt.** This explains why no Firefox picker appears and why the server immediately returns fatal `handshake_failure`.
5. **Runtime evidence now confirms the source-proven F3 blocker.** Treasury-only callback registration prevents GIS GMP's real `CertificateRequest` from reaching issuer collection, candidate enumeration, coordinator state, or the Firefox picker.
6. **Do not diagnose the user's certificate against the 36 CA DNs yet.** The current build never runs `CollectGostCANames()` / `CollectGostClientCertCandidates()` for this host. After F3, candidate count and sanitized chain matching become the authoritative evidence for whether an additional CA-policy fix is needed.
7. **Do not repeat this old-artifact GIS GMP test.** The failure mechanism is completely captured. Repeat only as GIS-G1 after F3 is built.

### Next experiment

Keep the planned order unchanged:

1. implement F1 close/shutdown lifecycle fix;
2. implement F2 positive `Once` logical-attempt fanout/lease;
3. implement F3 generic GOST mTLS callback registration/dispatch for already-selected GOST sockets;
4. short SSL compile -> authoritative main full build;
5. T2R -> T1R;
6. GIS-G1 on the new artifact.

GIS-G1 must now specifically prove that the same real server `CertificateRequest` reaches our callback, that the 36-entry CA list (or the server's then-current list) is collected through MSSPI, and that candidate enumeration produces an explicit count. If the count is zero, only then investigate chain-path / raw-DER-name matching and provider-binding filters.

Status: current runtime proof of F3; generic multi-host GOST mTLS client-auth remains blocked on code.