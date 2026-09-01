# r3dfox GOST TLS — Project State

Last updated: 2026-09-01

This file is the authoritative current technical synthesis. Detailed evidence is in `TEST_LOG.md` and immutable dated `TEST_LOG_*.md` volumes; forward work is in `TODO.md`; closed milestones are in `DONE.md`; the restart-safe runtime sequence is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP branch is in `STAGE2_GIS_GMP.md`; the primary source-level WinRT-removal experiment is documented in `WINRT_SOURCE_POC.md`; Windows XP compatibility architecture and import triage are in `XP_COMPATIBILITY_STRATEGY.md`; the mandatory XP x86 dependency/build contract is in `XP_BUILD_CONTRACT.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default / active branch: `agent/gost-tls-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the working branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer r3dfox baseline.

## Architecture

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication.

Current constraints and behavior:

- allowlist: `R3DFOX_GOST_HOSTS`;
- TLS 1.2 / HTTP/1.1 PoC path;
- default GOST ciphers: `C100:C101:C102:FF85:0081`;
- coordinated Firefox client-auth picker is default;
- `R3DFOX_GOST_CLIENT_AUTH_MODE=legacy` remains a same-binary diagnostic fallback;
- explicit local certificate thumbprint selection remains diagnostic only;
- `Session` is the GOST picker default;
- a positive Session choice is process-local, reused for matching client-auth decisions in the running browser process, isolated from a different GOST mTLS host, and cleared by browser-process restart;
- explicit `Once` remains available and uses the positive-only 5-second idle fanout lease; each successful reuse refreshes the idle expiry;
- explicit client-certificate Cancel is attempt-local: it is consumed as a declined decision and is not stored as reusable negative state;
- an unanswered picker abandoned by navigation/tab/load teardown remains unresolved and is removed through phase-0 lifecycle cleanup rather than being converted into Declined state;
- client-certificate discovery from `CurrentUser\MY` is distinct from live private-key availability: a certificate can remain picker-discoverable while its CryptoPro private-key medium/container is unavailable;
- if that medium is unavailable before first key acquisition, provider refusal fails only the current MSSPI attempt with `SEC_E_NO_CREDENTIALS`; the positive Firefox Session decision remains intact and can be reused after the medium returns;
- on the current CryptoPro/SSPI environment, removing the private-key medium **after** successful Session mTLS does not necessarily invalidate the already-acquired provider/credential context: a later fresh Treasury socket can still perform a new client-auth TLS exchange using the remembered Session decision;
- long synchronous CryptoPro/provider key access currently runs on the shared Firefox Socket Thread: T9 measured a `74.742 s` provider wait with a responsive browser UI but zero Socket Thread `GostTLS` activity; queued `pay.gov.ru`/GIS GMP network work started immediately when provider Cancel returned, so global network starvation during provider UI is a confirmed concurrency limitation while coordinator/Session state remains safe;
- detailed T10 picker presentation is confirmed usable in Russian: human-readable owner and issuer, correct Cyrillic and localized expiry, readable details, serial details-only, all `Once` / `Session` / `Permanent` choices visible, and `Session` visibly selected by default;
- `Issued by` uses the human-facing issuer common name when available, with the full issuer DN only as fallback;
- current source still routes every non-`Once` positive choice through the same process-local remember store, so true persistent `Permanent` semantics are not yet implemented/proven.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

## Current authoritative GOST runtime browser

Session-default source/build:

- source-under-test `afbdad307f63e594d3715169d6e34235280dddaf` (`fix(gost): mark Session picker default in runtime logs`);
- short SSL compile run `33073577249`, job `98521835147`, success;
- authoritative main full build run `33073577269`, job `98521835354`, success;
- release artifact `9652941006` (`r3dfox-gost-win64-release`);
- Win7 import-audit artifact `9652941552`;
- independent thunk-rs full build run `33073577260`, job `98521835116`, success; browser artifact `9652182123`, diagnostics `9652183604`.

Exact binary identity for main artifact `9652941006`:

- `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`;
- `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`.

These hashes were independently checked against the official GitHub Actions artifact and match the local runtime preflight. Every subsequent GOST runtime conclusion must pass the mandatory binary/environment/profile preflight in `STAGE2_RUNTIME_TEST_PLAN.md`.

## Confirmed GOST milestones

### Basic Treasury GOST HTTPS — COMPLETE

- source `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`;
- main run `32710363486`, job `97380247020`, artifact `9518011746`.

Real Treasury HTTP CONNECT, GOST TLS 1.2 / `0xFF85`, protected HTTP application traffic and browser rendering are proven.

### Stage 1 explicit-selector Treasury mTLS — COMPLETE

- source `f5d04896e17f91f58b6a137af823360f4718eb29`;
- main run `32751967162`, job `97510763210`.

A locally designated client certificate can be loaded by MSSPI/CryptoPro and completes real Treasury GOST TLS 1.2 / `0xFF85` mutual TLS plus authenticated protected application traffic. The concrete certificate identifier remains private.

### Stage 2 coordinated-client-auth baseline — COMPLETE

Runtime-proven source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`, main run `33039013849`, job `98408139479`, artifact `9636591432` closed:

- F1 close/shutdown lifecycle;
- F2 positive `Once` fanout and post-expiry scope boundary;
- F3 generic GOST mTLS host scope;
- GIS-G4 cross-host remembered-decision isolation;
- explicit positive Session browser-process lifetime S1/S1-B/S1-C.

Do not repeat those historical tests on unchanged source merely for confirmation. Detailed captures and counts remain in the test logs and `DONE.md`.

### Session-default exact-artifact regression SD1-SD6 — COMPLETE

Exact source/run/artifact: `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

The mandatory preflight passed with the exact hashes above and the baseline environment containing the five Treasury/GIS GMP GOST hosts, with diagnostic thumbprint/mode/cipher overrides cleared.

Confirmed on the exact artifact:

- **SD1:** default picker choice resolves as Session (`remember=2`); one Treasury picker feeds successful TLS 1.2 / `0xFF85` mTLS and later matching requests use `scope=session` without a second picker;
- **SD2:** same browser process continues using the Session decision across later matching requests/browser context without another picker;
- **SD3:** after complete browser-process restart, the first matching Treasury request creates a fresh decision/picker; the prior Session state does not survive the process boundary;
- **SD4:** explicit `Once` still creates short positive fanout leases and independent post-expiry attempts create fresh picker decisions/new lease generations rather than silently becoming Session;
- **SD5:** an active Treasury Session decision does not leak to `portalgisgmp.cert.roskazna.ru`; GIS GMP receives its own fresh decision/picker and completes GOST mTLS independently;
- **SD6:** user-visible picker presentation is confirmed correct: Session is visibly selected by default and `Issued by` is human-readable as intended.

All supplied SD1-SD5 captures contain zero `E/GostTLS`, `selected=0`, `0x80090326`, `0x0000054f`, and `MSSPI_X509_LOOKUP`. Successful recorded GOST handshakes use TLS 1.2 / `0xFF85`, state `0x00000000`; completed mTLS proves real client private-key use.

### T3 explicit Cancel / no certificate — COMPLETE

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Capture `T3 — explicit Cancel.zip` has SHA-256 `32c3e844e85c1997f57bc682d193c91c9fbcfa2c9b0dc91d939a9e82eeec293c`; inner log SHA-256 `d6174d335074904da2e6bbbddfe2b22e582a805292c81e518c72be8a85bfa38b`.

In one browser process (`Parent 1544`):

- four deliberate picker Cancels resolve as `selected=0`, waiter removal `reason=declined-consume`, decision phase `2`;
- no positive Session state or `Once` lease is created by a decline;
- every subsequent attempt creates a fresh decision/picker rather than consuming sticky negative state;
- a fifth picker left unanswered is removed after `30.276 s` from pending phase `0` by `close-pre`; closing callback re-entry and the later stale UI callback are safely rejected;
- `Try again` creates fresh decision `6`, which resolves positively as `selected=1 remember=2`;
- recovery then completes 12 Treasury TLS 1.2 / `0xFF85` mTLS handshakes with `client_cert_loaded=1` and successful protected-cabinet authorization in the same process.

The four deliberate no-certificate attempts naturally produce current-attempt `selected=0`, `0x80090326`, and `0x0000054f` markers. They are **not** sticky-failure evidence: after positive decision `6` there are zero further `E/GostTLS` and zero further `selected=0` markers. Future negative tests must distinguish intentional per-attempt failure markers from unsolicited errors on recovery attempts.

### T4 involuntary tab/load Abort — COMPLETE

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Capture `T4 involuntary Abort.zip` has SHA-256 `bfa51cc1d45c35c8c94cae6a7eb8fc32c6490d30782cdb256a1aefb24078d2f1`; inner log SHA-256 `f921c42d5e7b0299a40f79a5a707d5da93990018fb535edf529aef94a3d82f65`.

In one browser process (`Parent 6184`):

- the first Treasury client-auth request creates `decision=1`, `browser_id=14`, and a picker at `03:43:37.496 UTC`;
- closing that tab while the picker is unanswered removes the waiter after only `4.059 s` via `reason=close-pre`, removes decision `1` unresolved in phase `0`, rejects shutdown callback re-entry as `reason=closing`, and rejects the late picker callback as stale;
- decision `1` has no resolution record, no `selected=0`, no `declined-consume`, and no phase `2`, proving the tab/load abandonment is observably distinct from T3 explicit Cancel;
- the remaining tab in the same process uses `browser_id=15` and creates a fresh `decision=2` / picker at `03:43:54.093 UTC`;
- decision `2` resolves positively at `03:44:04.399 UTC` as `selected=1 remember=2`;
- recovery adds eight `scope=session` remembered hits and 9 successful Treasury TLS 1.2 / `0xFF85` mTLS handshakes with `client_cert_loaded=1` and successful personal-cabinet authorization.

Whole T4 capture: two decisions, two picker requests, one positive decision resolution, zero `declined-consume`, zero `selected=0`, zero `E/GostTLS`, zero `0x80090326`, zero `0x0000054f`, and zero `MSSPI_X509_LOOKUP`.

Together T3/T4 close the intended negative-decision split on the current artifact: explicit picker Cancel is Declined/phase `2`; involuntary navigation/tab/load abandonment remains unresolved phase `0` and is removed by lifecycle teardown. Neither path poisons later recovery.

### T5 post-login media-removal probe — METHODOLOGY FINDING; T5 DEFERRED

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Capture `T5 — Session failure-boundary regression.zip` has SHA-256 `ede5279115bb6fb80ddae7f40df1c87918a226ffedf6f16979ea30220d218076`; inner log SHA-256 `c9d63066b298bb127ad01060dc3428bcc1171535bd348950d0a3c067040d79c4`.

In one browser process (`Parent 644`), a normal positive Session decision is established and the initial Treasury flow completes. The user then makes the private-key medium unavailable and independently observes missing-container/provider-refusal behavior on the official CryptoPro CAdES demo. That CAdES/native CSP path is outside `GostTLS` transport logging, so the exact removal/provider-refusal event itself is external procedure evidence.

The Treasury log nevertheless proves that post-login media removal does not invalidate the already-acquired MSSPI credential in this environment:

- the initial Treasury burst ends at `04:12:30.946 UTC`;
- at `04:15:42.644 UTC`, `191.698 s` later, a fresh `lk-fzs.roskazna.ru` socket is created;
- at `04:15:42.864`, the new socket receives a fresh client-certificate request, consumes `selected=1 scope=session`, and emits a `redacted=client-auth` TLS flight;
- at `04:15:43.160`, that fresh connection completes TLS 1.2 / `0xFF85`, state `0x00000000`, `client_cert_loaded=1`;
- whole capture contains 10 Treasury client-certificate requests, 9 Session remembered hits and 10 successful Treasury mTLS handshakes, with zero `E/GostTLS`, `selected=0`, `0x80090326`, `0x0000054f`, `MSSPI_X509_LOOKUP`, or `SEC_E_NO_CREDENTIALS`.

This is stronger than an already-open HTTP/TLS session surviving: a later new socket performs a new client-auth TLS exchange successfully. The current interpretation is that CryptoPro/SSPI retains an already-acquired provider/private-key credential context after the medium is removed. That behavior is acceptable and should not be treated as a failure.

The capture therefore **does not pass or fail T5**. It invalidates post-login medium removal as the planned T5 fault injection. T5 is deferred until a safe deterministic way exists to invalidate an already-acquired provider credential inside the same browser process.

### T7/T8 missing-medium/provider recovery — COMPLETE

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Capture `T7-T8.zip` has SHA-256 `bd3fdf5bd73a2c7a6331235fe4f7bddb155698cdb6daaa5ef95f6fada1fae32c`; inner log SHA-256 `8692ca7043f256d9673767a01e368d935c3f6df664ed814424b0abbeacf971a7`.

In one browser process (`Parent 7056`, `browser_id=14`):

- with the key medium unavailable before first GOST key acquisition, Treasury candidate enumeration still reports one certificate from `CurrentUser\MY`;
- exactly one Firefox decision/picker is created and resolves positive at `04:57:20.614 UTC` as `selected=1 remember=2`;
- provider/container refusal then causes the current MSSPI attempt to fail at `04:57:22.379` with `0x8009030e` (`SEC_E_NO_CREDENTIALS`); there is no `selected=0`, `declined-consume`, or negative remembered decision;
- a new Treasury attempt in the same process receives another CertificateRequest at `04:57:28.516` and reuses `selected=1 scope=session` without another picker;
- after the medium is restored, the provider/key path emits the outbound client-auth flight at `04:57:55.829` and completes TLS 1.2 / `0xFF85` mTLS at `04:57:56.095`, state `0x00000000`, `client_cert_loaded=1`;
- protected MSSPI application writes/reads resume immediately, and the capture finishes with 12 successful recovered Treasury mTLS handshakes and 12 Session remembered uses after the initial failed attempt.

T7 is closed: discovery of a certificate identity from `MY` is independent of live private-key availability, and a missing-medium/provider refusal is attempt-local rather than sticky Firefox certificate state.

T8 is closed: restoring the key medium allows the existing positive Session decision to recover in the same Firefox process, complete real GOST mTLS, and resume protected application traffic without another picker or browser restart.

### T9 long provider wait / Socket Thread starvation — CHARACTERIZED

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Capture `T9 — долгий provider wait.zip` has SHA-256 `2f06aeb4dae884cfd4b6f973bcce21de42dc092d907575a798b361e4f7c48bac`; inner log SHA-256 `25a32e6bcd1c1b01d08c6624a429315f2eddefd97e81021dbc990c4b18b7b264`.

In one browser process (`Parent 788`, Treasury `browser_id=14`):

- Treasury client auth resolves positively as Session; the Socket Thread logs dialog completion at `05:36:46.482 UTC`;
- synchronous provider/private-key access then produces no `GostTLS` event for `74.742 s`;
- user observation confirms the browser UI remains responsive and can initiate new tabs/navigation during the wait;
- provider Cancel returns at `05:38:01.224 UTC` as `0x8009030e` (`SEC_E_NO_CREDENTIALS`) without `selected=0` or `declined-consume`;
- queued `pay.gov.ru` networking begins on the same timestamp and completes GOST TLS 1.2 / `0xFF85` at `05:38:01.515`, only `291 ms` later, with `client_cert_loaded=0`;
- `portalgisgmp.login.roskazna.ru` begins at `05:38:01.586` and also completes normally;
- later Treasury requests in the same process reuse `scope=session`, with 12 successful recovered TLS 1.2 / `0xFF85` mTLS handshakes.

T9 therefore closes the long-wait measurement but reveals a concrete concurrency limitation: synchronous CryptoPro/provider key access occupies the shared Firefox Socket Thread, so other network work queues even while the browser UI/event loop remains responsive. Provider Cancel releases the queue immediately, and the long wait does not corrupt Session/coordinator state.

Whether this is materially worse than stock Firefox token/PIN/client-certificate behavior remains unproven; compare before redesigning MSSPI threading. If offloading is attempted, preserve NSPR/MSSPI state ownership, client-auth lifecycle/cancellation and proxy/CONNECT sequencing.

### T10 detailed Russian picker presentation — COMPLETE

Exact source/run/artifact remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

T10 closes the full user-visible picker presentation beyond the earlier SD6 smoke. Sanitized user confirmation establishes that the owner/name is human-readable, `Issued by` is human-readable, Cyrillic renders correctly, expiry presentation is normal/localized, `Session` is visibly selected by default, `Once` / `Session` / `Permanent` are all visible, details are readable, and certificate serial is confined to details rather than the main candidate row. After the inspection, choosing `Session` still allows successful Treasury login.

No screenshot or raw certificate identity is retained because those fields may contain sensitive identity data. T10 therefore closes presentation/UX only; it does not add new protocol claims beyond the already-proven current-artifact Treasury mTLS baseline and does not imply real `Permanent` persistence.

## Immediate runtime / implementation order

1. **T6 — real Permanent semantics — NEXT IMPLEMENTATION.** Implement and prove persistence distinct from the current process-local non-Once store, including restart persistence and intended forget/change behavior.
2. **T11/T12 — discovery boundary — NEXT RUNTIME.** Verify dynamic `CurrentUser\MY` re-enumeration and determine whether provider/removable-media-only identities are discoverable without browser restart or interactive provider UI during candidate enumeration.
3. **T9 follow-up — provider-wait Socket Thread isolation.** Compare against stock Firefox synchronous token/PIN behavior, then decide whether a focused off-thread MSSPI/provider experiment is warranted. The current behavior is a known performance/concurrency limitation, not a coordinator corruption or handshake blocker.
4. **T5 — Session failure-boundary regression — DEFERRED.** Resume only with a safe deterministic mechanism that actually invalidates an already-acquired provider/private-key credential in the live process; do not repeat post-login medium removal or invent an invasive synthetic invalidation merely to force the test.
5. Continue candidate-policy and negative matrix.
6. Complete mandatory fail-closed server-trust closure and final exact-build Treasury acceptance.

Keep Firefox-picker timeout-source/poll-churn attribution separate from the now-characterized provider-wait Socket Thread blockage.

## Mandatory server trust — OPEN

Positive `DriveHandshake verify ... ok=1 status=0x00000000` observations under the current verification path are useful diagnostics but do not close final server trust.

Required final behavior:

- reject `verifyOk == 0`;
- reject any nonzero verification status;
- integrate Firefox temporary/permanent certificate overrides;
- positive browser-session verification cache keyed by exact server identity;
- prove valid Treasury hostname/chain succeeds;
- prove wrong hostname and invalid/untrusted chain fail closed;
- prove client private-key operations cannot occur before server trust.

Do not use a production verification bypass.

## Provider/private-key media evidence

Earlier source `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`, run `32844083378`, job `97789764275`, artifact `9567881847` first established the missing-media behavior historically. The current exact artifact now revalidates the important parts under coordinated Session-default client auth:

- a certificate can remain in `CurrentUser\MY` and be picker-discoverable while its CryptoPro private-key medium/container is unavailable;
- `CERT_KEY_PROV_INFO_PROP_ID`/store presence is binding/discovery metadata, not proof of live key availability;
- provider refusal before first key acquisition fails only the current attempt with `SEC_E_NO_CREDENTIALS`;
- the positive Session decision survives that provider failure;
- a later attempt recovers in the same process after the medium returns and completes real GOST mTLS/application traffic;
- conversely, once a usable provider/credential context has already been acquired, later medium removal may not invalidate it, so that procedure is not a valid T5 fault injection;
- a long provider/key-access wait can synchronously block the shared Firefox Socket Thread while leaving the browser UI responsive; cancellation immediately releases queued network work and does not poison the Session decision.

## Windows compatibility — independent track

### Physically proven XP x86 dependency build contract

The current authoritative dependency-build reference is source `b19ba4ff3eebd2f323743d92110241fc9d4ce399` on `agent/gost-tls-poc`, Actions run `33387080767`, job `99472017220`, runtime artifact `9756275917`. The focused `msvcr14x + Rust libstd + YY-Thunks / XP x86 SRW` workflow is green, its app-local `ucrtbase.dll` and `msvcp140.dll` are x86 PE subsystem 5.1 and do not retain the FLS/SRW hard imports that caused the earlier regression, and the exact newly generated runtime artifact has now been executed successfully on a real Windows XP computer.

This physically closes the fresh-CRT regression from run `33373236602` / job `99428838270` / source `89b236ad3289fcb9dc65b4bcabdf39d41f7f3be7`. That older build produced a Win7+ CRT closure and failed on XP at `KERNEL32!FlsGetValue`. The current contract is not defined as “`-r` alone fixes XP”; it is the complete pinned/restored build and verified runtime-closure contract documented in `XP_BUILD_CONTRACT.md`.

The default-branch full XP workflow now uses the same pinned/restored msvcr14x build path and includes a fail-fast `GATE - Require proven XP x86 msvcr14x runtime contract` before the expensive Firefox build. It checks the app-local CRT closure for x86/XP PE floor, known FLS/SRW hard imports and forbidden modern DLL dependencies, and records hashes/headers/imports in diagnostics. This is the first dependency family migrated from “retarget later and inspect globally” to “build XP-compatible, prove locally, then stage”. The next full run must prove this gate on its own exact source SHA before the resulting broad import inventory becomes the new planning baseline.

### Inherited x86 baseline

Official `Eclipse-Community/r3dfox` `v153.0.3` ships the 32-bit build with `--disable-sandbox`; issue `Eclipse-Community/r3dfox#11` records the intentional decision. Therefore a sandbox-enabled Win7/Vista x86 pass is not an XP prerequisite. The XP/x86 product path uses build-time sandbox disablement unless sandbox restoration is explicitly reprioritized as optional hardening. This inherited choice is now physically confirmed on Windows 7 x32 for the current XP-oriented full-browser artifact: build-time sandbox disablement removes the need for the `MOZ_DISABLE_CONTENT_SANDBOX=1` runtime workaround and avoids the prior restricted-sandbox notification while preserving normal browser operation.

### Current authoritative full Firefox XP x32 import baseline

The current full-build compatibility baseline is:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `1635d28360ee35d47c1d8237bcf8f5864cc1144f`;
- run `33310150314`, job `99253613546`;
- workflow `GOST TLS PoC build XP x32`;
- package artifact `9733280086`;
- runtime artifact `9733280458`;
- diagnostics artifact `9733280937`.

The full Firefox build, msvcr14x runtime staging, PE retargeting, package creation, runtime archive creation, and artifact uploads all succeeded. The Actions run is red only at the broad XP direct-import gate.

Physical Windows 7 x32 runtime on this exact source/build is now confirmed: the browser starts and operates correctly with build-time `--disable-sandbox`, does not require `MOZ_DISABLE_CONTENT_SANDBOX=1`, and does not show the prior notification associated with runtime sandbox disabling. This is a Windows compatibility result only; it does not close the remaining physical-XP startup/import work or any GOST TLS runtime milestone.

The current curated gate reports 103 violation rows, 26 unique API names across 15 PEs. `xul.dll` contributes 19 API violations plus `bcrypt.dll`; `mozglue.dll` contributes 11 API violations plus `bcrypt.dll`.

The old physical-XP artifact from run `33141004769` failed before UI startup on hard `KERNEL32!CloseThreadpoolWork`. In run `33310150314`, `CloseThreadpoolWork` is absent from both the normalized direct-import inventory and the raw per-PE import diagnostics. Therefore that specific import blocker is no longer expected in the current artifact, but physical XP execution is still required before runtime closure.

### Current remediation policy

Do not treat the 26 current gate API names as a production YY backlog.

Caller/owner classification is now mandatory before implementation:

1. for project-built or pinned-source dependencies under our control, first remove post-XP dependencies at their source/build/dependency boundary and keep a dedicated fail-fast contract gate;
2. remove modern-only features/paths where XP has no useful equivalent;
3. prefer XP-native source replacements where older APIs preserve the required operation;
4. prefer one owned legacy backend when several imports belong to a common Firefox abstraction;
5. use physically narrow YY only for unavoidable stable low-level gaps after caller analysis;
6. solve separately linked DLLs at their own build/dependency boundary;
7. use vetted source-available third-party compatibility boundaries where appropriate;
8. reserve custom shims for the residual set.

PE subsystem retargeting is explicitly **header-only remediation**. It can correct the loader floor of an otherwise XP-safe PE but cannot make a binary compatible when its import/dependency closure still requires post-XP APIs or DLLs.

The current `xul.dll` imports that require source/caller analysis before YY assignment include `CancelIoEx`, `CompareStringOrdinal`, `GetCurrentProcessorNumber`, `GetFileInformationByHandleEx`, `GetFinalPathNameByHandleW`, `GetLocaleInfoEx`, `LCIDToLocaleName`, `LocaleNameToLCID`, `GetTickCount64`, `SetFileInformationByHandle`, and `InitializeCriticalSectionEx`.

The SRW/condition-variable family appears across `xul.dll`, `mozglue.dll`, the executables, and several other DLLs. Determine whether each occurrence belongs to Mozilla-owned abstractions, Rust/MSVC/toolchain code, or a separately linked dependency. An owned abstraction may justify one XP synchronization backend; unavoidable toolchain surfaces are strong narrow-YY candidates; separate DLLs require their own solution. The msvcr14x CRT-side FLS/SRW regression is now owned by the mandatory XP build contract and must not reappear in later full builds.

Other feature/shipping PEs in the broad audit include `libGLESv2.dll`, `mozavcodec.dll`, `mozavutil.dll`, `gkcodecs.dll`, `mozinference.dll`, `d3dcompiler_47.dll`, and `gmp-clearkey`. A `xul.dll` linker change cannot rewrite their independent import tables. Test/developer/fake PEs (`gmp-fake`, `gmp-fakeopenh264`, `logalloc-replay.exe`, `xpcshell.exe`) must not automatically count as XP product blockers.

Focused `D3DCompiler_47.dll` replacement is now separately proven at source `b77b22ef1e35564dfe76997d3d393d45ee697e49`, run `33349340069`, job `99359475336`: the pinned legacy Firefox XP DLL is prepared and staged successfully, passes the retargeted legacy-D3DCompiler gate, and survives packaging under its dedicated post-package gate. The overall run still fails at the later broad XP PE-floor/direct-import audit, so the D3DCompiler staging/packaging hypothesis is closed but the broader XP import blocker remains open.

`bcrypt.dll` remains directly imported by both `xul.dll` and `mozglue.dll` and is an independent compatibility boundary.

### YY coverage smoke — capability proof only

The representative XP x86 msvcr14x/Rust/YY workload at source `d78137a931145af877dc458b01e494ad0467723d`, run `33138244191`, job `98743029100`, remains physically proven on Windows XP SP3 x86.

A later coverage smoke at source `39ce8453be32557dfb709bce8ee412c16f78a72f`, run `33316988353`, job `99272141403`, successfully selected all 26 current forbidden API names plus previously proven Rust/libstd entries into a physically narrow YY provider and passed its representative PE/import/runtime gates.

This proves **technical YY coverage only**. It does not define production provider membership and does not authorize injecting the expanded set into the full Firefox build. Production YY membership must follow caller-level classification. Full YY `kernel32.lib` interposition remains prohibited.

### WinRT direction

The physical Win7 crash from source `982d6529a707c6feecad97c725feed8a3cd21c81`, run `33141004769`, remains localized to `xul.dll` delay-loading the missing WinRT API-set and `RoGetActivationFactory`. Broad YY expansion for WinRT is retired. Source removal/fallback on `agent/winrt-source-poc` remains the primary architecture because WinRT has no XP meaning.

### Immediate Windows compatibility order

1. Run the current default-branch full XP workflow and require the new pre-Firefox msvcr14x XP contract gate to pass; bind the result to exact run/job/SHA.
2. Use that contract-compliant full-build diagnostics to regenerate the surviving component/import baseline; do not continue planning from CRT violations that the new build contract has already removed.
3. For each remaining project-built/Firefox-owned dependency family, identify its owner and remove post-XP dependencies at source/build/backend level where practical, then add a focused fail-fast gate before moving on.
4. Classify separately linked shipping/feature DLLs as required/optional and choose rebuild/legacy-version/replacement/disablement per component.
5. Keep YY physically narrow and use it only after caller/owner classification proves a residual low-level gap is unavoidable.
6. Rebuild and run the exact resulting artifact on physical XP; only then close full-browser startup/browsing.
7. Keep GOST TLS on old Windows as a later separate exact-artifact milestone.

Detailed rules and the component matrix are in `XP_COMPATIBILITY_STRATEGY.md`; the mandatory build contract is in `XP_BUILD_CONTRACT.md`; exact evidence is in `TEST_LOG.md`; forward tasks are in `TODO.md`.

## Bundled government-system extensions / localization — independent track

Current proven three-extension package checkpoint:

- source `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- full packaging run `32976571122`, job `98202641607`;
- packaged-browser artifact `9614275050`;
- evidence artifact `9614275551`.

That portable archive contains CryptoPro CAdES `1.2.14`, legacy Gosuslugi/IFCPlugin `1.2.8`, Gosplugin `1.3.43.0`, and the Russian-first content-language preference. Clean-profile discovery/enabled-state is proven for all three project extensions. Native-component behavior and version-to-version update behavior remain separate open work.

Current Russian-first full-browser packaging checkpoint:

- source-under-test `37846488e281b4c3a2df46e949b4f970a7343ed3` on `agent/gost-tls-poc`;
- workflow `CryptoPro Mozilla packaging smoke`;
- run `33403654068`, job `99525795309`, **success**;
- packaged-browser artifact `9768056691` (`r3dfox-cryptopro-mozilla-packaging-ru-en-US`), digest `sha256:29c6c09dfe61fa0fe51cad4a97f9235c71fe02b5bcd7530104cafafa8da40b9c`;
- evidence artifact `9768057338`, digest `sha256:9e88560db20a36f77311203453927d2c0232b6d80ef3ee5150eb7d187674a591`.

For this exact build, the full release build, CryptoPro XPI staging/final-package hash gate, `mach package`, `mach package-multi-locale --locales ru`, and final portable archive verification all pass. The final gate proves that `defaults/pref/r3dfox-bundle.js` is present inside packaged `omni.ja` with `pref("intl.locale.requested", "ru");`, and that both `ru` and `en-US` UI resources are present. This supersedes the false-negative packaging result from run `33076347741` / job `98531418338`, whose only failure was an incorrect gate expecting `r3dfox-bundle.js` as a loose file rather than inside `omni.ja`.

**Current boundary:** Russian-first multi-locale packaging is proven; actual first-start Russian UI, language switching/fallback, and general UI behavior of artifact `9768056691` remain runtime tests. Do not promote the packaging result to runtime UI success until those checks are completed. This checkpoint also does not prove CryptoPro native-component behavior, GOST TLS runtime, or old-Windows runtime compatibility.

## Separation of conclusions

- Build success != GOST handshake success.
- Coordinated runtime success != final server-trust closure.
- `client_cert_loaded=1` != private-key-use proof; completed mTLS is the proof.
- GOST runtime != Windows compatibility.
- Extension/localization packaging != extension runtime, UI runtime, GOST runtime, or old-Windows runtime.
- Upstream r3dfox x86 shipping with `--disable-sandbox` defines the inherited compatibility baseline; a future sandbox restoration would be an additional security-hardening milestone, not a prerequisite for XP startup/browsing.
- Documentation HEADs never replace the exact source-under-test SHA for a previously built/runtime-tested browser.
