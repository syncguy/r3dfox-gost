# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

Historical experiments through 2026-08-24 are preserved unchanged in [`TEST_LOG_2026-08-22_2026-08-24.md`](./TEST_LOG_2026-08-22_2026-08-24.md). For current technical synthesis, see [`PROJECT_STATE.md`](./PROJECT_STATE.md). For planned and deferred work, see [`TODO.md`](./TODO.md).

For each completed experiment, record:

- exact date;
- branch and commit SHA;
- GitHub Actions run/job when applicable;
- hypothesis/change;
- sanitized observation;
- conclusion;
- whether the finding is current, superseded, or still open.

Do not silently rewrite a failed experiment into a successful one. Add a new entry when understanding changes. Client-certificate and user-originated test data must follow the sanitization rules in `/AGENTS.md`.

---

## 2026-08-25 — Stage 1 Treasury mTLS succeeds in the main full build

**Track:** GOST TLS runtime / client-certificate authentication  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `f5d04896e17f91f58b6a137af823360f4718eb29` (`feat(gost): add stage1 mTLS client cert selection`)  
**Actions run:** `32751967162`  
**Job:** `97510763210`  
**Workflow:** `GOST TLS PoC build`  
**CI result:** success  
**Runtime target:** `lk-fzs.roskazna.ru` through the configured system HTTP proxy / ASUGATE

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32751967162>

### Purpose

Test the Stage 1 explicit client-certificate selection path against the real Treasury mTLS endpoint after the previous baseline proved that the server sends `CertificateRequest` but the wrapper sent an empty client Certificate.

The local test used both exact Treasury hosts in `R3DFOX_GOST_HOSTS` and supplied one known-good certificate through `R3DFOX_GOST_CLIENT_CERT_THUMBPRINT`. The concrete selector value remained local and is intentionally not recorded.

### Sanitized runtime observation

The user-provided runtime captures show repeated successful client-certificate authentication on the main full build. Across the successful captures:

- `lk-fzs.roskazna.ru` reaches the GOST MSSPI path after the proxy tunnel;
- MSSPI reaches the client-certificate lookup path;
- the wrapper selects the intended certificate from `CurrentUser\\MY`;
- the selected certificate reports `private_key_binding=1`;
- completed handshakes report `client_cert_loaded=1`;
- completed handshakes negotiate TLS 1.2 (`0x0303`) and suite `0xFF85`;
- the previous mTLS failure `0x80090326` does not recur;
- no `E/GostTLS` entry is present in the successful captures;
- the user confirmed successful authenticated Treasury use after the handshake.

One successful capture used the explicit configured GOST cipher list; another successful capture used MSSPI native-default cipher selection. Both completed mTLS successfully.

Raw client Certificate / CertificateVerify bytes and the concrete local certificate selector were not published.

### Conclusion

**Stage 1 Treasury client-certificate mTLS success is confirmed for the main full build.**

The blocker established at source SHA `4887e07d...` — absence of wrapper-side client-certificate loading after `MSSPI_X509_LOOKUP` — is closed by the explicit-selector Stage 1 implementation at `f5d04896...` for the tested environment and endpoint.

This result does **not** close mTLS integration as a whole. The mandatory Stage 2 security/UX work in `TODO.md`, especially fail-closed server-certificate verification, remains open.

---

## 2026-08-25 — Stage 1 Treasury mTLS also succeeds in the thunk-rs experimental full build

**Track:** GOST TLS runtime / cross-build mTLS validation  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `f5d04896e17f91f58b6a137af823360f4718eb29`  
**Actions run:** `32751967189`  
**Job:** `97510762742`  
**Workflow:** `GOST TLS PoC build - thunk-rs experiment`  
**CI result:** success  
**Runtime target:** `lk-fzs.roskazna.ru` through the configured system HTTP proxy / ASUGATE

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32751967189>

### Purpose

Cross-check the successful Stage 1 mTLS runtime behavior using the alternative ordinary-Rust + narrow-YY-Thunks full browser build while keeping the exact same GOST/mTLS source SHA.

### Sanitized runtime observation

The user-provided capture `gost_first_mTLS_ok_thunk-rs_experiment.zip` shows:

- 12 successful client-certificate selections;
- all 12 selections report `private_key_binding=1`;
- 12 completed MSSPI mTLS handshakes on `lk-fzs.roskazna.ru`;
- all completed handshakes report `client_cert_loaded=1`;
- all completed handshakes negotiate TLS 1.2 (`0x0303`) and suite `0xFF85`;
- no `0x80090326` failure;
- no `E/GostTLS` error entries;
- the user confirmed the artifact was successfully tested end to end.

No concrete certificate thumbprint, identifying certificate metadata, PIN, private-key/container identifier, or private application data is recorded here.

### Conclusion

**Stage 1 Treasury mTLS success is confirmed across both current full-build strategies at the exact same GOST source SHA `f5d04896e17f91f58b6a137af823360f4718eb29`.**

The main build (`32751967162`) and the experimental thunk-rs/YY-Thunks build (`32751967189`) both successfully perform client-certificate GOST mTLS. Therefore the Stage 1 client-auth result is not specific to either current Windows build strategy.

The next GOST TLS work is the mandatory Stage 2 closure already defined in `TODO.md`; successful Stage 1 runtime is not production-readiness evidence for server verification, certificate-selection UX, issuer policy, or negative paths.

---

## 2026-08-25 — Stage 2.1 trust diagnostics first compile fails in SSL gate

**Track:** GOST TLS runtime / Stage 2.1 observability  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `6d1b21d282b7653e4d55c533439f0da212f3ab2c` (`feat(gost): add stage2 trust diagnostics`)  
**Actions run:** `32808471365`  
**Job:** `97683129980`  
**Workflow:** `GOST SSL compile check`  
**CI result:** failure at `Compile security manager SSL target objects`

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32808471365>

### Purpose

Compile the first Stage 2.1 diagnostic implementation that adds server-verification observability and one-per-session detailed acceptable-issuer-list decoding without changing the Stage 1 trust decision.

### Observation

The build reached the SSL target-object compile gate and failed only in the newly added `nsGostSSLIOLayer.cpp` diagnostics:

1. Two calls to Windows `CertRDNValueToStrW` passed `&attr.Value` from a `const CERT_RDN_ATTR&`. The Windows SDK signature requires a mutable `PCERT_RDN_VALUE_BLOB`, so clang-cl rejected the const qualification.
2. One `MOZ_LOG` call in the new server-certificate diagnostics block had one extra closing parenthesis and failed parsing.

No MSSPI, NSPR, proxy, cipher-policy, or previously proven Stage 1 client-certificate logic failure was reached or indicated by this run.

### Conclusion

**This is a compile-only defect in the first Stage 2.1 diagnostics patch, not a runtime regression.**

The minimal compile-fix descendant is `c62022a5530a61124b756648293113187b8e5b8b` (`fix(gost): repair stage2 diagnostics compile`): it copies `attr.Value` into a local mutable `CERT_RDN_VALUE_BLOB` before calling `CertRDNValueToStrW` and removes the extra `MOZ_LOG` parenthesis. The Stage 2.1 diagnostic design is otherwise unchanged.

Status: superseded by the compile-fix descendant; that descendant still requires CI proof before runtime testing.

---

## 2026-08-25 — Stage 2.1 compile-fix passes the short SSL gate

**Track:** GOST TLS runtime / Stage 2.1 observability  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `c62022a5530a61124b756648293113187b8e5b8b` (`fix(gost): repair stage2 diagnostics compile`)  
**Actions run:** `32810337880`  
**Job:** `97688347363`  
**Workflow:** `GOST SSL compile check`  
**CI result:** success

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32810337880>

### Purpose

Confirm that the minimal compile-fix descendant of the first Stage 2.1 diagnostics patch builds the complete `security/manager/ssl` target-object set before consuming the full browser builds.

### Observation

All steps of the short SSL workflow completed successfully, including `Compile security manager SSL target objects`.

This proves that the Stage 2.1 diagnostics implementation, with the two compile-only defects repaired, is buildable at the SSL target level. It does not yet prove full-browser build success or runtime diagnostic behavior.

### Conclusion

**The Stage 2.1 compile blocker is closed for code SHA `c62022a5530a61124b756648293113187b8e5b8b`.**

The next evidence required is completion of the two full builds for the same exact code SHA, followed by runtime testing of the resulting artifact(s) to inspect server-verification diagnostics and the one-per-session detailed acceptable-issuer-list dump.

---

## 2026-08-25 — CryptoPro extension standalone update/fallback/package smoke passes

**Track:** bundled government-system extensions / packaging infrastructure  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `2ad7025ca300613d39a227b9e7582a341260d648` (`test(extensions): normalize expected failure exit`)  
**Actions run:** `32815118778`  
**Job:** `97701728235`  
**Workflow:** `CryptoPro extension packaging smoke`  
**CI result:** success  
**Evidence artifact:** `9551126137` (`cryptopro-extension-smoke`)

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32815118778>

### Purpose

Prove the CryptoPro CAdES Firefox-extension preparation pipeline independently of both full browser builds and independently of the real Firefox packaging graph before integrating it into production build workflows.

The committed fallback is `r3dfox/extensions/ru.cryptopro.nmcades@cryptopro.ru.xpi`, version `1.2.14`, SHA-256 `3df7ee8c7d655921abce942befc2bfd6e0ddcf9179e6173d72e35083844cc0e7`.

### Observation

All standalone gates passed:

- the committed fallback validates with exact ID `ru.cryptopro.nmcades@cryptopro.ru`, version `1.2.14`, expected SHA-256, valid ZIP integrity, required Mozilla signature structure, and COSE structure;
- a forced network failure selects the committed fallback;
- a deliberately invalid committed fallback is rejected as a hard error and produces no selected output;
- a deterministic structurally valid downloaded candidate is accepted and selected;
- a malformed download is rejected and the valid committed fallback is selected;
- a structurally valid candidate carrying the wrong extension ID is rejected and the fallback is selected;
- the live official CryptoPro URL successfully returned version `1.2.14` with the exact same SHA-256 as the committed fallback;
- the selected live XPI was staged as `distribution/extensions/ru.cryptopro.nmcades@cryptopro.ru.xpi`;
- the final smoke ZIP contains that exact path, preserves the selected XPI SHA-256, and re-validates the expected extension ID and version;
- evidence artifact `9551126137` contains the smoke metadata, selected XPI files, and final package ZIP.

The smoke validates signature-file/COSE structure but does not claim independent cryptographic verification of Mozilla's extension signature. Firefox remains the authority for signature enforcement when the XPI is actually installed.

### Harness history

Three earlier runs were intentionally left as evidence rather than rewritten:

- run `32814789390`, job `97700797664`, SHA `77a2398a018b35e28435b706c956d983c2694fbd`: fallback download and validation succeeded, but the one-time bootstrap commit step failed because Windows PowerShell promoted expected `git ls-files --error-unmatch` stderr to `NativeCommandError`;
- run `32814928877`, job `97701192432`, SHA `435d7947415ec8a693f849037b9b3b1f1614d8b8`: bootstrap commit succeeded and created `e2102e1c9771c0115060303206144ab343de9f0c` with the exact XPI, then a PowerShell `PathInfo` to `System.Uri` conversion bug stopped the deterministic candidate gate;
- run `32815019875`, job `97701450709`, SHA `d05d95841f2edaca39aae6f1e3ea1dda251ab0b8`: the updater correctly rejected an invalid fallback with exit code 2, but PowerShell propagated the expected nonzero native exit code as the step result; the harness was fixed by explicitly normalizing that expected negative test to success.

These failures were smoke-harness defects, not failures of the committed CryptoPro XPI or of the final updater contract.

### Conclusion

**The standalone CryptoPro extension update/fallback/staging/package mechanism is proven at SHA `2ad7025ca300613d39a227b9e7582a341260d648`.**

This does not yet prove integration with Mozilla `FINAL_TARGET_FILES` or a real Firefox package. The next extension-track experiment is a minimal Mozilla build-system integration proof that connects the selected XPI to the real `r3dfox/moz.build` packaging graph without first modifying either full GOST browser workflow. Only after that proof should the already-tested preparation and package gates be transferred into the two full browser builds.

---

## 2026-08-25 — Stage 2.1 diagnostics build successfully in both full browser strategies

**Track:** GOST TLS runtime / Stage 2.1 observability  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `c62022a5530a61124b756648293113187b8e5b8b` (`fix(gost): repair stage2 diagnostics compile`)

### Main full build

- **Actions run:** `32810337957`
- **Job:** `97688347771`
- **Workflow:** `GOST TLS PoC build`
- **CI result:** success
- `GATE - Compile security manager SSL target objects`: success
- `Build release r3dfox`: success
- package/upload: success
- Win7 import audit and final known-Win8+ import gate: success

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32810337957>

### Experimental thunk-rs full build

- **Actions run:** `32810337879`
- **Job:** `97688347489`
- **Workflow:** `GOST TLS PoC build - thunk-rs experiment`
- **CI result:** success
- `GATE - Compile security manager SSL target objects`: success
- `Build release r3dfox with narrow YY-Thunks linker path`: success
- package/upload: success
- thunked `xul.dll` Win7 import audit and final known-Win8+ import gate: success

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32810337879>

### Conclusion

**Stage 2.1 observability code at exact SHA `c62022a5530a61124b756648293113187b8e5b8b` is proven buildable in both current full browser strategies.**

This closes the buildability prerequisite for Stage 2.1. The next experiment is runtime-only: use the resulting full browser artifact to collect the new server-verification diagnostics and the detailed acceptable-issuer-list dump, while confirming that the already-proven Stage 1 client-certificate mTLS path still succeeds. The experimental artifact should then repeat the same runtime scenario as a cross-build parity check.

---

## 2026-08-25 — Stage 2.1 main runtime localizes verifier failure and validates issuer-list dedup

**Track:** GOST TLS runtime / Stage 2.1 observability  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `c62022a5530a61124b756648293113187b8e5b8b`  
**Main build:** run `32810337957`, job `97688347771`  
**Runtime result:** browser-visible Treasury use succeeds without lag or visible errors

### Sanitized observation

The main-build runtime capture contains 12 completed GOST handshakes for `fzs.roskazna.ru` and 13 completed mTLS handshakes for `lk-fzs.roskazna.ru`. Login-host handshakes continue to report `client_cert_loaded=1`; the previous `0x80090326` failure does not recur and no `E/GostTLS` entry is present.

The acceptable-issuer diagnostics return 34 entries / 11,420 DER bytes. The complete list is decoded once (`already_logged=0`) and 13 later identical observations are suppressed with `already_logged=1`, confirming browser-session dedup. All 34 entries decode as X.500 names; identifying DN values are intentionally not recorded here.

Across completed connections, server peer-certificate acquisition fails consistently with `0x80090302` (`SEC_E_UNSUPPORTED_FUNCTION`) on pinned MSSPI's Windows request for `SECPKG_ATTR_REMOTE_CERT_CHAIN`. MSSPI therefore has no `peercert`, peer-chain/name helpers cannot produce data, and `msspi_get_verify_status()` returns its internal-failure form (`ok=0`). This localizes the current verifier blocker to peer-certificate acquisition rather than to a proved Treasury certificate-policy failure.

### Conclusion

**Stage 2.1 observability succeeded and changed the leading blocker.** The next compatibility experiment uses the already-existing MSSPI `SECPKG_ATTR_REMOTE_CERT_CONTEXT` leaf-certificate path on Windows and lets `CertGetCertificateChain` build the chain. Detailed issuer diagnostics are also confirmed usable without browser-visible performance degradation.

---

## 2026-08-25 — Firefox-facing client-cert picker first compile fails on invalid refcount API

**Track:** GOST TLS runtime / Stage 2 Firefox-facing client-certificate selection  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `ef4007081ffe86ac3a6779327fddad67af2c8c44` (`feat(gost): add firefox client cert selection path`)  
**Actions run:** `32837093952`  
**Job:** `97768273059`  
**Workflow:** `GOST SSL compile check`  
**CI result:** failure at `Compile security manager SSL target objects`  
**Compile-fix source SHA:** `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e` (`fix(gost): use Firefox thread-safe refcounting`)

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32837093952>

### Observation

The new `GostClientCertState` was declared as `mozilla::RefCountedThreadSafe<GostClientCertState>`. Firefox 153 in this repository does not define `mozilla::RefCountedThreadSafe`, so clang-cl first reports the unknown template and then the expected secondary `RefPtr` errors because the class has no usable `AddRef` / `Release` methods.

The state object is intentionally shared between the socket-thread handshake path and the asynchronously dispatched Firefox client-certificate dialog path, so thread-safe reference counting is still required. The native Firefox 153 mechanism in this tree is `NS_INLINE_DECL_THREADSAFE_REFCOUNTING` from `nsISupportsImpl.h`.

### Fix

Source SHA `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`:

- adds the explicit `nsISupportsImpl.h` include;
- removes the nonexistent `mozilla::RefCountedThreadSafe` base class;
- declares `NS_INLINE_DECL_THREADSAFE_REFCOUNTING(GostClientCertState)` inside the native state object;
- removes the obsolete friend declaration;
- retains the private destructor and the existing cross-thread ownership model.

### Conclusion

**Run `32837093952` is a compile-only Firefox API mismatch in the newly added Stage 2 picker state object, not evidence of an MSSPI/SSPI runtime regression and not a Windows 7 compatibility failure.**

The exact reported `RefCountedThreadSafe` / `AddRef` / `Release` error cluster is repaired by source SHA `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`. CI validation of that exact source SHA is still required before treating the compile blocker as closed or drawing any runtime conclusion.

---

## 2026-08-25 — Firefox-facing client-cert refcount fix passes SSL compile gate

**Track:** GOST TLS runtime / Stage 2 Firefox-facing client-certificate selection  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e` (`fix(gost): use Firefox thread-safe refcounting`)  
**Actions run:** `32844083351`  
**Job:** `97789764135`  
**Workflow:** `GOST SSL compile check`  
**CI result:** success

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32844083351>

### Purpose

Validate the exact compile-fix descendant of failed run `32837093952` before using the Stage 2 Firefox-facing client-certificate picker code in a full browser build or runtime experiment.

### Observation

The workflow completed successfully. In particular, `Compile security manager SSL target objects` passed for the exact source SHA above, so the Firefox 153 native `NS_INLINE_DECL_THREADSAFE_REFCOUNTING` implementation provides the `AddRef` / `Release` surface required by `RefPtr<GostClientCertState>` and compiles with the intended cross-thread ownership model.

This is compile evidence only. The run does not exercise the Firefox certificate picker, MSSPI client authentication, server-certificate verification, or a GOST TLS handshake.

### Conclusion

**The `RefCountedThreadSafe` / `AddRef` / `Release` compile regression from run `32837093952` is closed at exact source SHA `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`.**

Stage 2 returns to its substantive runtime/integration work: peer-certificate acquisition/fail-closed server verification and the Firefox-facing client-certificate selection flow. No Windows Vista/7 compatibility conclusion is drawn from this SSL-only gate.
