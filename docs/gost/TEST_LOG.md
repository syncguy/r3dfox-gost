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
