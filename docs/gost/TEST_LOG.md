# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-28_2026-08-28.md`](./TEST_LOG_2026-08-28_2026-08-28.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. For current technical synthesis, see [`PROJECT_STATE.md`](./PROJECT_STATE.md). For forward work, see [`TODO.md`](./TODO.md). For formally closed milestones, see [`DONE.md`](./DONE.md). The restart-safe Stage 2 runtime sequence is [`STAGE2_RUNTIME_TEST_PLAN.md`](./STAGE2_RUNTIME_TEST_PLAN.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-08-28 — T5 probe: removing the key medium after successful Session mTLS does not induce a provider failure

**Track:** GOST TLS runtime / Session credential lifetime and provider-fault methodology  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `afbdad307f63e594d3715169d6e34235280dddaf` (`fix(gost): mark Session picker default in runtime logs`)  
**Actions run:** `33073577269`  
**Job:** `98521835354`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9652941006` (`r3dfox-gost-win64-release`)  
**Campaign binary identity:** `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`; `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru`  
**Runtime capture:** user-provided `T5 — Session failure-boundary regression.zip`, SHA-256 `ede5279115bb6fb80ddae7f40df1c87918a226ffedf6f16979ea30220d218076`; inner `SDx.moz_log`, SHA-256 `c9d63066b298bb127ad01060dc3428bcc1171535bd348950d0a3c067040d79c4`

The raw capture is not committed because it contains detailed certificate-authority diagnostics. Only sanitized lifecycle/protocol facts are recorded.

### Procedure and external observation

The user established a normal Treasury login using the default positive `Session` choice. While the same browser process remained alive, the private-key medium/container was then made unavailable. In separate browser tabs/windows the user exercised the official CryptoPro CAdES signing demo and observed the expected missing-container/provider refusal behavior there. The Treasury personal cabinet itself remained usable.

The CryptoPro demo activity is intentionally **not** evidence from the GOST transport log: `cryptopro.ru` is not part of the project GOST allowlist and the CAdES/native CSP signing path is outside `GostTLS` transport logging. The capture contains no `cryptopro.ru`, provider/container diagnostic, or `SEC_E_NO_CREDENTIALS` record. Therefore the exact medium-removal/provider-refusal timestamp is user-procedure evidence, not independently timestamped by `GostTLS`.

### Treasury Session is stronger than an existing HTTP/TLS socket

The capture stays in one browser process, `Parent 644`.

Initial Treasury client authentication:

- first coordinated decision is created at `04:12:22.750 UTC`, `browser_id=14`;
- it resolves positively at `04:12:27.062 UTC` as `selected=1 remember=2`;
- the first Treasury TLS 1.2 / `0xFF85` mTLS handshake completes at `04:12:27.406 UTC`;
- compatible follow-on sockets consume `scope=session`; the last handshake of the initial burst completes at `04:12:30.946 UTC`.

A later event rules out the weak explanation that only an already-open keep-alive connection survived. At `04:15:42.644 UTC`, **191.698 s after the previous successful Treasury mTLS handshake**, the browser creates a fresh `lk-fzs.roskazna.ru` socket. On this new connection:

- a fresh server client-certificate request arrives at `04:15:42.864 UTC`, `ca_count=34`, `browser_id=14`;
- the coordinator applies the existing decision with `selected=1 scope=session` and shows no new Firefox picker;
- the outbound TLS flight is logged as `redacted=client-auth`, confirming a new client-auth exchange rather than ordinary application data reuse;
- at `04:15:43.160 UTC` the new connection completes TLS `0x0303` / cipher `0xFF85`, state `0x00000000`, `client_cert_loaded=1`.

Whole capture:

- coordinated decisions created/resolved: `1` / `1`;
- Treasury client-certificate requests: `10`;
- Session remembered uses: `9`;
- successful Treasury TLS 1.2 / `0xFF85` mTLS handshakes with `client_cert_loaded=1`: `10`;
- `E/GostTLS`: `0`;
- `selected=0`: `0`;
- `0x80090326`: `0`;
- `0x0000054f`: `0`;
- `MSSPI_X509_LOOKUP`: `0`;
- `SEC_E_NO_CREDENTIALS`: `0`.

### Interpretation

This result is consistent with CryptoPro/SSPI retaining an already-acquired provider/private-key credential context after the physical/logical medium becomes unavailable. Ordinary established TLS application traffic never needs to re-sign with the client private key, but this capture is stronger: a later **new socket receives a new CertificateRequest and emits a new client-auth TLS flight successfully**. Therefore post-login medium removal does not necessarily invalidate the already-acquired credential context used by MSSPI.

That behavior is acceptable and desirable for a stable authenticated browser session: removing the key medium should not gratuitously destroy an already-established usable credential context unless the provider itself invalidates it.

### Conclusion

**T5 is NOT passed or failed by this capture. The attempted fault injection is invalid for T5.**

The intended T5 question requires an actual provider/private-key failure on the GOST path after a positive Session decision has already been established. Removing the medium after the first successful mTLS does not create such a failure in this environment; the cached CryptoPro/SSPI credential remains usable even for a later fresh Treasury client-auth handshake.

Do not repeat this same post-login medium-removal procedure expecting `SEC_E_NO_CREDENTIALS`; it has now been experimentally shown not to exercise the desired boundary.

**Runtime next:** T7/T8 should be exercised with the key medium unavailable **before the first GOST private-key acquisition** in a clean browser process/profile, then restored for a same-process retry. T5 remains deferred until a safe deterministic way exists to invalidate an already-acquired provider/key credential context without restarting the browser. Do not invent an invasive synthetic invalidation merely to force T5.

Status: current methodology finding; T5 deferred/open, T7/T8 next runtime experiment.