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

Status: current methodology finding; T5 deferred/open.

---

## 2026-08-28 — T7/T8 pass: missing medium fails the first key acquisition and same Session recovers after medium return

**Track:** GOST TLS runtime / CryptoPro private-key medium failure and same-process recovery  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `afbdad307f63e594d3715169d6e34235280dddaf` (`fix(gost): mark Session picker default in runtime logs`)  
**Actions run:** `33073577269`  
**Job:** `98521835354`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9652941006` (`r3dfox-gost-win64-release`)  
**Campaign binary identity:** `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`; `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`  
**Runtime target:** `fzs.roskazna.ru` -> `lk-fzs.roskazna.ru`  
**Runtime capture:** user-provided `T7-T8.zip`, SHA-256 `bd3fdf5bd73a2c7a6331235fe4f7bddb155698cdb6daaa5ef95f6fada1fae32c`; inner `SDx.moz_log`, SHA-256 `8692ca7043f256d9673767a01e368d935c3f6df664ed814424b0abbeacf971a7`

The raw capture is not committed because it contains detailed certificate-authority diagnostics. Only sanitized lifecycle/protocol facts are recorded.

### Procedure

The test begins before any successful GOST private-key acquisition in the browser process. The client certificate remains discoverable in `CurrentUser\MY` even though its private-key container/medium is unavailable. The user selects that certificate in the Firefox picker with the default Session choice. When CryptoPro requests access to the unavailable key/container, the user declines the provider/container action. For the recovery half, the private-key container/medium is restored on the machine while the same Firefox process/profile remains alive.

The entire capture stays in `Parent 7056`, `browser_id=14`.

### T7 — current-attempt provider failure is separate from certificate decision

The first Treasury client-auth request arrives at `04:57:15.805 UTC`:

- candidate enumeration reports `count=1` despite the unavailable key medium, confirming the certificate itself remains discoverable from `MY`;
- exactly one coordinated `decision=1` and one Firefox certificate dialog are created;
- at `04:57:20.614 UTC`, the decision resolves positively as `selected=1 remember=2`;
- there is no Firefox `selected=0`, `declined-consume`, or negative remembered decision.

At `04:57:22.379 UTC`, the first attempt to continue MSSPI client authentication after that positive selection fails with `error=0x8009030e` (`SEC_E_NO_CREDENTIALS`) and enters terminal state `0x40000000`. Follow-on calls on that already-failed connection report `0x0000054f`; they are repetitions of the same failed attempt, not separate certificate decisions.

The failed socket then closes cleanly. No positive mTLS completion occurs for that first attempt.

### T8 — same-process Session reuse and provider recovery

A new independent Treasury attempt begins at `04:57:28.360 UTC`, only about six seconds after the failed socket, with the same browser process/profile.

At `04:57:28.516 UTC` the server issues a fresh client-certificate request. The coordinator does **not** create another decision or picker. Instead it applies the existing positive choice directly:

- `selected=1 scope=session mode=coordinated`;
- no `selected=0` or Declined state exists;
- no browser restart occurs.

While the key medium/container is being restored, that request remains inside provider/key acquisition. At `04:57:55.829 UTC`, `27.313 s` after the remembered Session hit, MSSPI emits the outbound `redacted=client-auth` TLS flight. The handshake then completes at `04:57:56.095 UTC` as TLS `0x0303` / cipher `0xFF85`, state `0x00000000`, `client_cert_loaded=1`.

Protected application traffic resumes immediately after the recovered handshake: the first successful `msspi_write` occurs at `04:57:56.095 UTC`, followed by successful decrypted reads at `04:57:56.376 UTC`. The remaining Treasury fanout succeeds normally.

Whole capture:

- coordinated decisions created/resolved: `1` / `1`;
- Firefox certificate dialogs requested/completed: `1` / `1`;
- Treasury client-certificate requests: `13`;
- Session remembered uses after the first failed attempt: `12`;
- successful Treasury TLS 1.2 / `0xFF85` mTLS handshakes after recovery: `12`;
- underlying provider/key failure class: `0x8009030e` (`SEC_E_NO_CREDENTIALS`);
- `selected=0`: `0`;
- `declined-consume`: `0`;
- `0x80090326`: `0`;
- `MSSPI_X509_LOOKUP`: `0`;
- `Once` lease use: `0`.

### Conclusion

**T7 PASS / CLOSED.** The certificate remains discoverable from `CurrentUser\MY` while its private-key medium is unavailable. A positive Firefox Session selection can therefore be made independently of live key availability. Provider/container refusal fails only that current MSSPI attempt with `SEC_E_NO_CREDENTIALS`; it is not converted into a reusable Firefox no-certificate decision and does not poison the remembered Session choice.

**T8 PASS / CLOSED.** Restoring the key medium in the same running browser process allows the next independent Treasury client-auth request to reuse the existing `scope=session` decision without another Firefox picker. MSSPI then acquires/uses the key, completes real Treasury TLS 1.2 / `0xFF85` mTLS, and protected application traffic resumes without browser restart.

This current-artifact result reproduces and strengthens the older missing-medium/provider-recovery evidence while proving compatibility with the current coordinated Session-default client-auth implementation.

T5 remains separate and deferred: T7/T8 begin with the medium unavailable before first key acquisition, whereas T5 requires failure of an already-acquired live provider credential.

**NEXT:** T6 real `Permanent` semantics. T9 long provider wait remains a later runtime test; the approximately 27-second provider wait in this capture does not exceed the existing ordinary picker-timeout scale and does not close T9.

Status: current; T7/T8 provider/media recovery closed on the Session-default exact artifact.

---

## 2026-08-27 — Russian-first ru + en-US packaging run fails only at final portable-archive verification

**Track:** bundled government-system extensions / CryptoPro Mozilla packaging and localization  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `07c7c48419ca39952a57a53967c1bcabaa8384c1` (`ci(packaging): add Russian-first multi-locale build`)  
**Actions run:** `33076347741`  
**Job:** `98531418338` (`Windows x64 / CryptoPro real Firefox packaging / ru + en-US`)  
**Workflow:** `CryptoPro Mozilla packaging smoke`  
**Run attempt:** `1`  
**Result:** failure  
**User-supplied packaging evidence archive:** SHA-256 `c933efb49c723af0a96881507940928f2aec7b6d7ccf534824403af749cf65dc`

### Proven successful boundary

The red workflow result is not a compiler or full-build failure. The exact job completed successfully through all of the following relevant stages:

- Russian-first packaging configuration;
- CryptoPro XPI selection and working-tree preparation;
- SpiderMonkey style gate;
- Win7 Rust build-std preflight and Mozilla Rust target gate;
- `security/manager/ssl` compilation gate;
- full release `r3dfox` build;
- verification of the selected CryptoPro XPI in the real `obj-gost-win64/dist/bin` tree;
- `mach package` for the intended `ru + en-US` multi-locale package.

The subsequent browser and evidence artifact upload steps also completed successfully.

### Failure boundary

The only failed step is step 31, `GATE - Verify CryptoPro XPI and ru/en-US UI in final portable archive`.

Therefore the failure is localized to verification of the final produced portable archive: after a successful build, successful real `dist/bin` XPI check, and successful packaging command, the workflow's final gate did not accept the portable archive as satisfying the combined CryptoPro-extension plus `ru`/`en-US` UI expectations.

The supplied `cryptopro-mozilla-packaging-evidence.zip` contains selection/configuration diagnostics (`cryptopro-extension-selection.json`, Rust/vendor/configure evidence) but does not contain the failing step-31 portable-archive verification output itself. Accordingly, this entry does not infer which individual subcondition inside that combined final gate failed; the exact evidence supports only the failure boundary above.

### Conclusion

Run `33076347741`, job `98531418338`, source `07c7c48419ca39952a57a53967c1bcabaa8384c1` is a **failed final portable-package verification experiment**, not a failed Firefox compilation or failed CryptoPro `dist/bin` staging experiment. The result belongs to the bundled-extension/localization packaging track and does not change the established GOST TLS runtime/handshake or Windows Vista/7 compatibility conclusions.

Status: failed at final portable-archive verification; exact failing subcondition is not established by the available evidence.

---

## 2026-08-28 — T9 long provider wait: UI remains responsive but synchronous provider access starves the Firefox Socket Thread

**Track:** GOST TLS runtime / long CryptoPro provider wait and networking concurrency  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `afbdad307f63e594d3715169d6e34235280dddaf` (`fix(gost): mark Session picker default in runtime logs`)  
**Actions run:** `33073577269`  
**Job:** `98521835354`  
**Workflow:** `GOST TLS PoC build`  
**Runtime artifact:** `9652941006` (`r3dfox-gost-win64-release`)  
**Campaign binary identity:** `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`; `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`  
**Runtime capture:** user-provided `T9 — долгий provider wait.zip`, SHA-256 `2f06aeb4dae884cfd4b6f973bcce21de42dc092d907575a798b361e4f7c48bac`; inner `SDx.moz_log`, SHA-256 `25a32e6bcd1c1b01d08c6624a429315f2eddefd97e81021dbc990c4b18b7b264`

The raw capture is not committed because it contains detailed certificate-authority diagnostics. Only sanitized lifecycle/protocol facts are recorded.

### Long provider wait

The entire sequence remains in one browser process, `Parent 788`, with the Treasury client-auth decision associated with `browser_id=14`.

At `05:36:43.610 UTC`, `lk-fzs.roskazna.ru` issues a client-certificate request. Candidate enumeration reports one certificate, coordinated `decision=1` is created, and the Firefox certificate dialog is requested. The decision resolves positively at `05:36:46.420 UTC` as `selected=1 remember=2`; the Socket Thread consumes it and logs `client certificate dialog completed ... selected=1` at `05:36:46.482 UTC`.

From that point the Socket Thread enters the synchronous MSSPI/CryptoPro provider/private-key path. The next `GostTLS` record of any kind does not occur until `05:38:01.224 UTC`: there are **zero logged events during the intervening 74.742 seconds**.

The user independently confirms that the Firefox UI itself remains responsive during this provider wait: new tabs/windows can be opened and navigation can be initiated. Those UI actions cannot be timestamped from this `GostTLS`-only capture because the network Socket Thread is the component that is blocked. The absence of Socket Thread activity and the queued-network release below are consistent with those navigations waiting behind the provider call rather than with a frozen browser event loop.

At `05:38:01.224 UTC`, provider Cancel returns from the blocked MSSPI call as `error=0x8009030e` (`SEC_E_NO_CREDENTIALS`) and the Treasury connection enters terminal state `0x40000000`. Three immediate follow-on calls on that already-terminal connection log `0x0000054f`; they are consequences of the same failed provider attempt, not separate client-certificate decisions. There is no `selected=0` and no `declined-consume`.

### Queued networking resumes immediately

The first queued GOST network work appears on the **same timestamp** as the provider failure:

- `05:38:01.224 UTC`: `allowlist matched` / `NewSocket begin` for `pay.gov.ru`;
- `05:38:01.515 UTC`: `pay.gov.ru` completes GOST TLS 1.2 / `0xFF85`, state `0x00000000`, `client_cert_loaded=0`, only **291 ms** after the blocked provider call returned;
- `05:38:01.586 UTC`: a new socket for `portalgisgmp.login.roskazna.ru` begins;
- `05:38:02.970 UTC`: that GIS GMP login endpoint also completes GOST TLS 1.2 / `0xFF85` without a client certificate.

The capture therefore proves a shared Socket Thread serialization boundary: while the synchronous provider/private-key operation is blocked, other GOST network work queues even though the browser UI remains usable. Once provider Cancel returns, queued network connections start immediately.

### Later Session recovery remains clean

The long wait and provider failure do not corrupt the positive Treasury Session decision. Later in the same `Parent 788` process, a fresh Treasury client-auth request at `05:39:40.174 UTC` consumes `selected=1 scope=session`; the first recovered TLS 1.2 / `0xFF85` mTLS handshake completes at `05:39:40.534 UTC`, and the capture contains **12 successful recovered Treasury mTLS handshakes** through `05:39:44.335 UTC`.

Whole-capture state relevant to T9:

- one positive coordinated Firefox decision (`selected=1 remember=2`);
- long synchronous provider wait after Firefox decision: `74.742 s`;
- first provider failure: `0x8009030e` (`SEC_E_NO_CREDENTIALS`);
- `selected=0`: `0`;
- `declined-consume`: `0`;
- Session remembered uses: `12`;
- successful later Treasury mTLS handshakes: `12`;
- `MSSPI_X509_LOOKUP`: `0`.

### Conclusion

**T9 characterization is COMPLETE, with a failed no-network-starvation subcriterion.**

The long provider wait is lifecycle-safe: Firefox UI remains responsive, the positive Session decision is not converted into negative state, provider Cancel terminates the current attempt cleanly, queued network work resumes immediately, and later same-process Treasury mTLS recovery succeeds.

However, the synchronous MSSPI/CryptoPro provider call **does globally occupy the Firefox Socket Thread** for the observed `74.742 s`. Other network operations initiated from usable browser tabs/windows wait until that call returns. This is now a concrete runtime limitation rather than a hypothetical threading concern.

The experiment alone does not establish whether this is materially worse than stock Firefox synchronous token/PIN/client-certificate behavior. A separate comparison/design decision is required before changing MSSPI threading. If offloading is attempted, it must preserve NSPR/MSSPI state ownership, cancellation, client-auth coordination, proxy/CONNECT sequencing and the already-proven recovery semantics.

**NEXT runtime:** T10 detailed Russian picker presentation. **NEXT implementation:** T6 real `Permanent` semantics.

Status: current; T9 measured and closed as a characterization, global Socket Thread starvation remains an open performance/concurrency follow-up.

---

## 2026-08-28 — Full XP x32 Firefox build: physical XP loader blocker and Win7 sandbox/RNG content-process failure localized

**Track:** Windows compatibility / full Firefox 153 x86 runtime  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `982d6529a707c6feecad97c725feed8a3cd21c81` (`ci: add XP x32 full Firefox build workflow`)  
**Actions run:** `33141004769`  
**Job:** `98751650853` (`Windows x86 / r3dfox GOST / XP SP3 full build`)  
**Workflow:** `GOST TLS PoC build XP x32`  
**Package artifact:** `9676548553` (`r3dfox-gost-xp-x32-package`), artifact digest SHA-256 `1010a84c571ad78ff7757ccdadd27f0cb6a15e1ef437673970f583e7173bb503`  
**Physical-test runtime artifact:** `9676549576` (`r3dfox-gost-xp-x32-runtime`), artifact digest SHA-256 `f0287c7917d7d08756acf57ed8cd2eeed9b8d397ea8416fbf2f166308e89f4f5`  
**Diagnostics artifact:** `9676550507` (`r3dfox-gost-xp-x32-diagnostics`), artifact digest SHA-256 `ecec3fe35df412c77c217ed5ed27f2a628d9bc3a931876a171cffa1b41c64862`

The Actions run is red because the post-build XP PE/direct-import audit gate failed. The full Firefox x86 compilation, runtime staging, PE subsystem retargeting, packaging, physical-test runtime archive construction and all three artifact uploads completed successfully. This build result is not itself proof of XP runtime compatibility.

### Physical Windows XP x32

Launching the exact build on a physical Windows XP x32 machine fails before browser UI startup with the loader dialog:

`The procedure entry point CloseThreadpoolWork could not be located in the dynamic link library KERNEL32.dll.`

This converts the static import concern into a real physical loader blocker. The dialog title alone does not identify which startup-loaded PE module owns the hard import, so the exact importing module remains to be established before changing the compatibility layer.

### Physical Windows 7 x32 with sandbox enabled

The same build starts the browser parent/UI on physical Windows 7 x32, but tabs initially show `Gah. Your tab just crashed.`. `about:crashes` does not render as a usable internal page, the profile `minidumps` directory remains empty, no `crashes` directory is created, and Windows Event Viewer contains no corresponding Application/System fault record.

Diagnostic capture identities:

- initial `r3dfox-xp32-win7.log.moz_log.zip`: SHA-256 `fb72c03976471913de47cb173f5361eeb5c8c8e7848048c1377b0e48a24839fd`;
- narrow `r3dfox-win7-child.log.moz_log.zip`: SHA-256 `403163d390df74a9fd578737efbfcf6d9ffb1233dc5a1db3385d43a684ab7776`;
- ProcMon + narrow Mozilla log archive `r3dfox-win7-child.log.zip`: SHA-256 `0f298b1bfd413f51c58074797fd7da6f82693524ca53f5bf540276dbe5787d90`;
- inner `Logfile.PML`: SHA-256 `5351fb46acfa00ecb62586603b04ff76f5c431e8b1f04afb3b245e7c72b0c4b6`;
- inner `r3dfox-win7-child.log.moz_log`: SHA-256 `5ea9fd576997bfaf4949e3a37a9678db3d3ef4f0637f5925796b377f27cc2e96`.

Mozilla process logging proves `tab` content processes are created and then die very early. ProcMon refines this: affected `tab` processes repeatedly exit with NTSTATUS `0x80000003` (`STATUS_BREAKPOINT`), while other child-process classes such as socket/GPU/RDD/utility can remain alive. Therefore the failure is not a generic inability to spawn any Firefox child process.

WinDbg then captures the decisive first-chance exception in an affected content process:

`mozglue!mozilla::RandomUint64OrDie+0x4a: int 3`

The disassembly shows the boolean result of the random-byte helper tested immediately before the failure branch; on false it stores `gMozCrashReason` and executes `int 3`. The exact source-under-test implementation of `RandomUint64OrDie()` uses `MOZ_RELEASE_ASSERT(GenerateRandomBytesFromOS(...))`, and on Windows `GenerateRandomBytesFromOS()` calls `RtlGenRandom` / `SystemFunction036`. The observed `EAX/AL == 0` is consistent with the random-byte call returning failure and the release assertion deliberately terminating the process.

### Sandbox-off A/B test

With the same binary and physical Win7 x32 machine but `MOZ_DISABLE_CONTENT_SANDBOX=1`, the immediate content-process failure disappears. The browser creates a fresh profile, loads the policy-enabled uBlock extension, and successfully opens multiple ordinary web pages. The browser later crashes after some use; that later whole-browser failure is not yet diagnosed and must not be conflated with the now-localized immediate tab-startup failure.

### Conclusion

The first physical Win7 x32 tab-startup blocker is now causally localized to the **content-sandbox-dependent RNG startup path**: sandbox enabled -> deterministic `RandomUint64OrDie` / `STATUS_BREAKPOINT` tab death; content sandbox disabled -> profile/extension startup and real page browsing work. This is stronger than the earlier generic "content process crashes" observation and rules out a simple global Win7 loader/import failure for the immediate tab crash.

The Windows compatibility line therefore has two separate current runtime blockers on this exact build:

1. **XP x32:** loader startup is blocked by an unresolved hard dependency on `KERNEL32!CloseThreadpoolWork`; identify the exact importing module and redirect/remove that hard import.
2. **Win7 x32:** normal sandboxed content startup fails because OS random-byte generation returns failure inside the sandboxed process and triggers `RandomUint64OrDie`; sandbox-off browsing proves the browser/content runtime can otherwise operate, but a later browser crash remains a separate open issue.

No GOST TLS handshake/runtime conclusion is drawn from either old-Windows test.

Status: current physical-runtime evidence; XP loader blocker open, Win7 immediate sandbox/RNG blocker localized, later Win7 crash open.

---

## 2026-08-28 — Win7 sandbox RNG follow-up: legacy RNG lazy initialization identified and pre-lockdown warm-up implemented

**Track:** Windows compatibility / Win7 x32 content sandbox  
**Branch:** `agent/gost-tls-poc`  
**Runtime build under diagnosis:** source `982d6529a707c6feecad97c725feed8a3cd21c81`, run `33141004769`, job `98751650853`, runtime artifact `9676549576`  
**Candidate-fix source:** `27bf83a679ec26b93bc72a0ec7635fb26f821782` (`fix(win7): warm legacy RNG before content sandbox lockdown`)

A follow-up WinDbg session on the same failing physical Win7 x32 configuration caught another manifestation of the deliberate Mozilla crash path. The affected content process raised first- and then second-chance `0xC0000005` at a `mov dword ptr [0], ecx` null write; the stack directly contained `mozglue!mozilla::RandomUint64OrDie+0x55`. The nearby exported symbol name (`WindowsOleAut32Initialization+...`) is only symbol-resolution noise around the internal crash primitive and does not implicate OLE automation. This does not contradict the earlier ProcMon/WinDbg `0x80000003` / `int 3` observation: both are release-assert termination paths reached from `RandomUint64OrDie`, and the precise crash instruction is not the root cause.

The same debugger session disassembled Win7 `ADVAPI32!SystemFunction036`. Its entry path performs one-time initialization through `ntdll!RtlRunOnceExecuteOnce`; the cached call target used afterward resolves to `cryptbase!SystemFunction036`. Combined with the exact Firefox source (`GenerateRandomBytesFromOS()` -> `RtlGenRandom` / `SystemFunction036`) and the sandbox-off A/B pass, this identifies the relevant compatibility boundary as **lazy legacy RNG initialization before versus after content sandbox lockdown**.

Source comparison confirms that this Firefox/r3dfox baseline's `SandboxTarget::LowerContentSandbox()` reached `TargetServices::LowerToken()` without warming the OS RNG path first. Modern Chromium's renderer sandbox path explicitly calls `WarmupRandomnessInfrastructure()` immediately before `LowerToken()`. A maintained Win7 Chromium compatibility backport implements that warm-up with `RtlGenRandom`, specifically so the legacy `advapi32 -> cryptbase` RNG state is initialized before the renderer is locked down.

Candidate fix `27bf83a679ec26b93bc72a0ec7635fb26f821782` adds the narrow equivalent in Mozilla-owned sandbox code rather than modifying the imported Chromium sandbox library: on pre-Win8 systems, `LowerContentSandbox()` calls the existing `GenerateRandomBytesFromOS()` helper before `LowerToken()`. Win8+ behavior is unchanged and the content sandbox remains enabled.

### Conclusion

The diagnosis/implementation step is complete: there is now a concrete, minimal fix aligned with the observed Win7 call path and Chromium's established sandbox warm-up ordering. **Runtime validation is still open.** No build or physical Win7 result exists yet for `27bf83a...`, so the sandbox RNG blocker is not closed.

Next evidence required: build the exact full x86 browser from source containing `27bf83a...`, then run it on physical Win7 x32 with normal content sandboxing enabled. Passing requires content tabs to survive startup and ordinary pages to load without the immediate `RandomUint64OrDie` termination.

Status: candidate fix committed; exact x86 build/physical Win7 sandbox-on validation pending.

---

## 2026-08-28 — T10 Russian picker presentation pass

**Track:** GOST TLS runtime / coordinated client-certificate picker UX and Russian presentation  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `afbdad307f63e594d3715169d6e34235280dddaf` (`fix(gost): mark Session picker default in runtime logs`)  
**Actions run:** `33073577269`  
**Job:** `98521835354`  
**Runtime artifact:** `9652941006` (`r3dfox-gost-win64-release`)  
**Campaign binary identity:** `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`; `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`

T10 is a presentation/UX checkpoint. Raw certificate screenshots or identity fields are intentionally not retained because they may expose sensitive certificate data; the runtime plan explicitly permits sanitized user confirmation for the visible presentation.

The user confirms all intended visible properties on the current Session-default campaign:

- owner/name presentation is human-readable;
- `Issued by` is human-readable and identifies the issuing CA without exposing raw technical DN presentation in the normal row;
- Cyrillic text renders correctly;
- certificate expiry is readable/localized correctly;
- `Session` is visibly selected by default;
- `Once`, `Session`, and `Permanent` choices are all present;
- certificate details are readable;
- serial is confined to details rather than polluting the main candidate presentation;
- after choosing the normal `Session` path, Treasury login completes successfully.

The successful login is recorded as a functional smoke confirming that the presentation inspection did not break the established current-artifact flow. This entry does not claim new protocol properties beyond the already-established TLS 1.2 / `0xFF85` Treasury mTLS evidence for this exact artifact.

**T10 PASS / CLOSED.** The detailed Russian coordinated-client-certificate picker presentation is suitable for the tested workflow and preserves the intended Session-default behavior. `Permanent` is only confirmed as a visible option here; its real cross-process persistence semantics remain T6 and are not implied by T10.

**NEXT runtime:** T11/T12 discovery boundary. **NEXT implementation:** T6 real `Permanent` semantics.

Status: current; T10 presentation milestone closed on the current Session-default artifact.

---

## 2026-08-28 — Win7 later parent/browser crash: xul WinRT delay-load failure proven; YY-Thunks narrow-provider gap identified

**Track:** Windows compatibility / Win7 x32 parent/browser runtime  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `982d6529a707c6feecad97c725feed8a3cd21c81` (`ci: add XP x32 full Firefox build workflow`)  
**Actions run:** `33141004769`  
**Job:** `98751650853` (`Windows x86 / r3dfox GOST / XP SP3 full build`)  
**Workflow:** `GOST TLS PoC build XP x32`  
**Runtime artifact:** `9676549576` (`r3dfox-gost-xp-x32-runtime`), artifact digest SHA-256 `f0287c7917d7d08756acf57ed8cd2eeed9b8d397ea8416fbf2f166308e89f4f5`  
**Diagnostics artifact:** `9676550507` (`r3dfox-gost-xp-x32-diagnostics`), artifact digest SHA-256 `ecec3fe35df412c77c217ed5ed27f2a628d9bc3a931876a171cffa1b41c64862`  
**ProcMon capture:** user-provided `Logfile_Fileop.zip`, SHA-256 `7a77464a3e2564f7e46ce1c3084f61c25ae3302497e6799c8604feb4ef6ed27b`; inner `Logfile.PML`, SHA-256 `86961864565d5d13997046a673aa0481675395747f037b722f5c7db230dccea9`

The raw PML is not committed because it contains user filesystem paths. Only sanitized process/loader/debugger facts and non-sensitive capture hashes are recorded.

### ProcMon and exact PE evidence

This is the later whole-browser crash observed after the same binary was run with `MOZ_DISABLE_CONTENT_SANDBOX=1`. It is separate from the earlier sandboxed-content `RandomUint64OrDie` blocker.

The parent/browser process remains alive long enough to browse ordinary pages, then near the end of the capture begins a loader search for `api-ms-win-core-winrt-l1-1-0.dll`. The search fails in the browser directory, `System32`, Windows directories and PATH locations; no successful load occurs.

The exact diagnostics artifact independently identifies the owner. `xp-x32-import-audit/xul.dll-imports.txt` contains these `xul.dll` delay-load groups:

- `api-ms-win-core-winrt-l1-1-0.dll`: `RoActivateInstance`, `RoGetActivationFactory`;
- `api-ms-win-core-winrt-string-l1-1-0.dll`: `WindowsCompareStringOrdinal`, `WindowsCreateString`, `WindowsCreateStringReference`, `WindowsDeleteString`, `WindowsGetStringRawBuffer`.

Therefore the missing WinRT dependency belongs to the `xul.dll` delay-import surface, not to `r3dfox.exe` or an unidentified third-party DLL.

### First-chance WinDbg proof

WinDbg was configured with `sxe c06d007e` and stopped on the first relevant exception:

`Unknown exception - code c06d007e (first chance)` at `KERNELBASE!RaiseException+0x54`.

`.exr -1` reports `ExceptionCode: c06d007e`, one parameter, and a pointer to the MSVC delay-loader information structure. Decoding that structure in the still-stopped process gives:

- DLL: `api-ms-win-core-winrt-l1-1-0.dll`;
- procedure: `RoGetActivationFactory`;
- last error: `0x0000007e` (`ERROR_MOD_NOT_FOUND`).

The stack immediately enters `xul.dll` delay-load frames after `KERNELBASE!RaiseException`. Because no xul PDB is available, nearest exported names printed by WinDbg are not reliable function identities and are not used as source attribution.

This directly proves the runtime failure chain:

`xul.dll` delay import -> `api-ms-win-core-winrt-l1-1-0.dll` unavailable on Win7 -> `RoGetActivationFactory` cannot be resolved -> `ERROR_MOD_NOT_FOUND (0x7e)` -> MSVC delay-load exception `0xc06d007e` -> unhandled parent/browser crash.

`KERNELBASE.dll` is the exception-raising site, not the root dependency owner.

A machine-code search found multiple `xul.dll` call sites targeting the delay slot for `RoGetActivationFactory`, but without xul symbols/map this does not safely identify the failing C++ caller. Several obvious exact-source WinRT users were checked and are already OS-gated (`WindowsUIUtils` on Win10+, `WindowsSMTCProvider` on Win8.1+, and the relevant `nsWindowsPackageManager` paths on Win10+), so none is claimed as the actual caller without further evidence.

### YY-Thunks integration gap

YY-Thunks 1.2.2 already implements pre-Win8 `RoGetActivationFactory`. If the real WinRT API is absent, its thunk clears the output factory and returns `CLASS_E_CLASSNOTAVAILABLE` instead of raising a loader exception. YY-Thunks also has the corresponding WinRT API-set module definitions and WinRT string thunk surface.

The exact XP/x32 build does use YY-Thunks 1.2.2, but only through the project's deliberately narrow provider strategy. The workflow extracts selected alias/import members for `ProcessPrng`, `GetSystemTimePreciseAsFileTime`, FLS/fiber/stack-guarantee APIs plus the common `YY_Thunks_for_5.1.2600.0.obj`, and links `synchronization.lib`. It does **not** select a `RoGetActivationFactory` alias/import member. Consequently the common implementation being present is insufficient to redirect this xul delay import, and the runtime still enters the MSVC delay-loader.

### Conclusion and next step

The previously generic later Win7 crash is now localized to a concrete `xul.dll` WinRT delay-load blocker. The current evidence does not yet constitute a fix.

Next implementation experiment:

1. identify the exact YY-Thunks 1.2.2 archive/member names that expose `RoGetActivationFactory` to the linker;
2. identify and include only the companion WinRT string alias/import members actually required by the adjacent xul delay-import group;
3. add those members to the existing narrow YY provider rather than injecting broad YY libraries;
4. rebuild the exact full x86 browser and validate on physical Win7.

Do not ship a fake `api-ms-win-core-winrt-l1-1-0.dll`. Do not replace the narrow strategy with broad complete-YY `kernel32.lib` interposition. A successful compatibility rebuild/runtime does not prove GOST TLS behavior.

Status: current; parent/browser Win7 later crash localized, narrow YY-Thunks implementation direction identified, fix and physical runtime validation open.
