# Stage 2 GOST TLS — GIS GMP multi-host mTLS checkpoint

Last updated: 2026-08-27

Purpose: preserve the GIS GMP (`pay.gov.ru`) multi-host client-auth evidence and the remaining cross-host isolation work. This is a sub-plan of `STAGE2_RUNTIME_TEST_PLAN.md`; `STAGE2_PLAN.md` remains the security/architecture contract.

## Current authoritative browser

- source-under-test: `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea` (`fix(gost): harden coordinated client auth lifecycle`);
- main Actions run: `33039013849`, attempt 1;
- job: `98408139479`;
- artifact: `9636591432` (`r3dfox-gost-win64-release`);
- `r3dfox.exe` SHA-256 `ccd3ed44bc57345eb7821a949dd96a6b3c45c71b47f3a577da26fc1265481187`;
- `xul.dll` SHA-256 `8cee03269e18dff2bc48d5c25bef34a6c62c520908d937e3b3e4a03031d0ab68`.

Standard GIS GMP runtime command:

```bat
set "R3DFOX_GOST_HOSTS=pay.gov.ru,portalgisgmp.login.roskazna.ru,portalgisgmp.cert.roskazna.ru"
set "R3DFOX_GOST_CLIENT_CERT_THUMBPRINT="
set "R3DFOX_GOST_CLIENT_AUTH_MODE="
set "R3DFOX_GOST_CIPHERS="

r3dfox.exe -no-remote ^
  -profile C:\Temp\r3dfox\profile-gis ^
  --MOZ_LOG=timestamp,sync,GostTLS:5 ^
  --MOZ_LOG_FILE=C:\Temp\r3dfox\gis ^
  https://pay.gov.ru/
```

Never publish client-certificate identifying DNs, serials, fingerprints, provider/container identifiers, credentials or unsanitized runtime captures. The GIS logs contain detailed acceptable-CA diagnostics; repository docs record only sanitized counts/protocol facts.

## Historical old-artifact blocker — CLOSED

Old source `860de8e38deed326b7fcd1c547e928c5b48c72a9`, main run `32951903026` attempt 2, job `98130275465`, artifact `9606431408`.

Historical capture:

- `gost_pay.gov.ru.zip` SHA-256 `2e9630e5d8048482ebc6a3d3ac0576db6af2c6b4e108c3c1de6ea4e30d99596b`;
- inner `gost.moz_log` SHA-256 `f32fd8bf7067dd487e79121faf467f1038906d91ed958df87c572aff991bc5ed`.

That capture proved:

- `pay.gov.ru` and `portalgisgmp.login.roskazna.ru` already completed TLS 1.2 / `0xFF85` through the GOST transport;
- certificate login reached `portalgisgmp.cert.roskazna.ru`;
- the real certificate endpoint sent TLS 1.2 `CertificateRequest` with 36 acceptable-CA DER names;
- the old browser had no generic client-cert callback for that host, sent an empty TLS client Certificate, received fatal `handshake_failure`, and MSSPI reported `0x80090326`.

This isolated **F3 — generic GOST mTLS host scope**. The problem was not GIS routing or absence of a server certificate request; client authentication was still hard-coded to the Treasury Stage-1 hostname.

## F3 design implemented in the current source

Current source makes client-auth capability a property of an already-selected GOST TLS socket rather than a hard-coded hostname:

- MSSPI client-certificate callback can be registered on every applicable allowlisted GOST socket;
- normal coordinated dispatch is not rejected merely because the host differs from `lk-fzs.roskazna.ru`;
- backend selection remains controlled by the existing GOST allowlist/session policy;
- callback registration alone does not send a certificate or show UI; the remote server must actually request client authentication;
- coordinated decisions remain keyed by host/port/OriginAttributes/acceptable-CA identity;
- explicit diagnostic thumbprint and legacy paths remain separate diagnostic/reference mechanisms.

## 2026-08-27 current runtime — GIS-G1/G2/G3 PASS / F3 CLOSED

Passing capture:

- `gis-g1-g2-g3.zip` SHA-256 `8bb1fd3cfb6773739f0c9b05fd31555eef4180d65ce0518d54a63c85691558ce`;
- inner `gis-g1.moz_log` SHA-256 `451ed230a972b19ec35c1edc8952d1b234366ac5775c7252e8e67a92a289f1b1`;
- capture span `09:50:54.079–09:51:45.484 UTC` (`51.405 s`).

### GIS-G1 — PASS: real certificate host reaches the coordinator

On `portalgisgmp.cert.roskazna.ru`:

- generic callback registration succeeds at `09:51:17.694 UTC`;
- real server client-certificate request reaches the callback at `09:51:17.959 UTC`;
- current acceptable-CA count is **36**;
- current local candidate count is **1**;
- coordinator creates one decision and one waiter;
- Firefox shows exactly one certificate picker.

No issuer-policy change was needed: the existing current candidate machinery finds the intended eligible certificate against the real GIS GMP CA list.

### GIS-G2 — PASS: real GIS GMP GOST mTLS/application login succeeds

The user selects the intended certificate with default `Once`.

- decision resolves positively at `09:51:20.626 UTC`;
- positive lease generation 1 is stored with `idle_ms=5000`;
- first certificate-host mTLS handshake completes at `09:51:21.421 UTC`;
- four follow-on client-auth requests reuse the same lease without another picker;
- five total `portalgisgmp.cert.roskazna.ru` handshakes complete successfully;
- all five are TLS 1.2 / `0xFF85`, MSSPI state `0x00000000`, `client_cert_loaded=1`;
- all five reach `verify ok=1 status=0x00000000` under the currently implemented verification path;
- the user confirms the certificate-login/application flow proceeds successfully.

Completed mTLS, not merely `client_cert_loaded=1`, is the proof of actual private-key use.

### GIS-G3 — PASS: no spurious picker on non-mTLS GOST hosts

Generic registration changes capability, not behavior:

- `pay.gov.ru`: callback registered, zero client-certificate requests, one successful TLS 1.2 / `0xFF85` handshake with `client_cert_loaded=0`;
- `portalgisgmp.login.roskazna.ru`: callback registered on its sockets, zero client-certificate requests, four successful TLS 1.2 / `0xFF85` handshakes with `client_cert_loaded=0`;
- all five client-certificate requests in the capture belong only to `portalgisgmp.cert.roskazna.ru`;
- only one picker is shown for the complete GIS certificate-login flow.

Whole-capture safety counts:

- `selected=0`: `0`;
- `0x80090326`: `0`;
- `0x0000054f`: `0`;
- `MSSPI_X509_LOOKUP`: `0`;
- `E/GostTLS`: `0`.

**Conclusion: F3 generic GOST mTLS host-scope blocker is formally closed for artifact `9636591432`.** Do not repeat GIS-G1/G2/G3 on unchanged source merely for confirmation.

## GIS-G4 — NEXT GIS-specific semantic regression

Cross-host remember/decision isolation remains open even though host-scope reachability is closed.

Required minimum proof:

- a positive Treasury `Once` choice must never silently apply to `portalgisgmp.cert.roskazna.ru`;
- the decision key must remain isolated by actual host, port, OriginAttributes and acceptable-CA identity;
- if the same local certificate is eligible for both systems, each independent host still follows its own explicit remember policy;
- when Session/Permanent behavior is tested, do not infer cross-host reuse merely because the same certificate identity is valid at both sites.

GIS-G4 may be combined efficiently with the broader Session/remember matrix, but its conclusion must remain explicitly cross-host.

## Candidate-policy fallback if a future server change produces zero candidates

The current live server returned CA count `36` and candidate count `1`, so no issuer-matching fix is justified now. If a future exact-build regression returns zero candidates, investigate in this order:

1. current server acceptable-CA count/binary identities;
2. whether the intended local certificate chain contains an advertised authority;
3. Windows chain path/cross-sign selection;
4. raw DER-name equality versus Windows name comparison (`CertCompareCertificateName` as a candidate primitive);
5. provider/private-key binding filter.

Do not broaden issuer matching speculatively while the current real server/certificate combination already passes.

## Stop / recovery rules

- Do not repeat the old GIS failure on artifact `9606431408`.
- Do not repeat current GIS-G1/G2/G3 on `9636591432` unless source/runtime conditions change or a targeted regression requires it.
- If a future candidate count is zero, stop before GIS-G2 and preserve the capture.
- Keep GIS GMP inside the GOST runtime track; it is independent of Windows compatibility and bundled-extension testing.
- Record every meaningful new GIS experiment in `TEST_LOG.md` with exact source/run/job/artifact/capture hashes and update `PROJECT_STATE.md` / `TODO.md` when the blocker changes.