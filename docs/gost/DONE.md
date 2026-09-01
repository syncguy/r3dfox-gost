# r3dfox GOST TLS — Done / Closed Work

Last updated: 2026-09-01

This file is the compact registry of project milestones, blockers, and research conclusions that are formally closed. Detailed run history and failures remain in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes; current synthesis is in `PROJECT_STATE.md`; open work is in `TODO.md`.

## GOST TLS runtime

### Phase 1 GOST HTTPS transport baseline — COMPLETE

Established for the tested Treasury environment:

- Firefox/Necko HTTP proxy CONNECT lifecycle works with the tested ASUGATE environment;
- allowlisted GOST sessions complete TLS 1.2 with `fzs.roskazna.ru` and suite `0xFF85`;
- protected HTTP application traffic works over the MSSPI-backed GOST transport;
- Treasury pages render and tested interactive workflows operate normally.

Detailed transport evidence remains in the test logs and `PROJECT_STATE.md`.

### Stage 1 Treasury client-certificate mTLS — COMPLETE

Exact Stage 1 source `f5d04896e17f91f58b6a137af823360f4718eb29`.

Authoritative main build/runtime evidence: run `32751967162`, job `97510763210`. A locally designated client certificate can be loaded by MSSPI/CryptoPro and completes real Treasury GOST TLS 1.2 / `0xFF85` mutual TLS plus authenticated protected application traffic. The concrete certificate identifier remains private.

Stage 1 used an explicit local selector as a diagnostic mechanism; it did not close Stage 2 browser-facing selection, negative-path, issuer-policy, or final server-trust work.

### Stage 2.1 trust observability and verifier diagnosis — COMPLETE

Diagnostic source `c62022a5530a61124b756648293113187b8e5b8b`; main run `32810337957`, job `97688347771`; thunk run `32810337879`, job `97688347489`; short SSL run `32810337880`, job `97688347363`.

Closed diagnosis:

- acceptable-issuer collection/deduplication works;
- active SSPI/CryptoPro returns `0x80090302` for `SECPKG_ATTR_REMOTE_CERT_CHAIN`;
- missing MSSPI `peercert` explains the then-observed internal verification failure;
- next implementation path is remote leaf context plus Windows chain construction.

Final fail-closed server verification remains open separately.

### Stage 2 F1 close/shutdown client-auth lifecycle — COMPLETE

Exact fixing source/runtime browser:

- source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- main run `33039013849`, job `98408139479`;
- artifact `9636591432`.

T2R proves unanswered-picker teardown no longer creates a replacement/orphan decision during `msspi_shutdown()`. Across three timeout cycles, active waiters/decisions are removed, shutdown-time callback re-entry is rejected because the handle is closing, abandoned UI callbacks are stale-safe, and retries receive fresh pickers without browser restart. The capture contains zero automatic `selected=0`, `0x80090326`, `0x0000054f`, or `MSSPI_X509_LOOKUP`.

### Stage 2 F2 positive default-`Once` fanout/scope — COMPLETE

Exact source/runtime browser:

- source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- main run `33039013849`, job `98408139479`;
- artifact `9636591432`.

T1R proves one positive Firefox `Once` choice feeds the complete Treasury login across compatible sequential connection waves without additional UI: one picker, one lease store, seven lease reuses, eight successful `lk-fzs.roskazna.ru` TLS 1.2 / `0xFF85` mTLS handshakes, and successful protected personal-cabinet use.

T1R-B proves the scope boundary in the same browser process/context. Generation 1 is last reused at `09:07:13.004 UTC` and nominally expires at `09:07:18.004`; a real independent client-auth request at `09:09:44.169` creates fresh `decision=2` and a new Firefox picker rather than reusing generation 1. The new positive choice creates generation 2 and mTLS succeeds again.

T1R-B capture identity:

- `T1R-B-current.zip` SHA-256 `c2d018b8637467b4c1368bfa66399dd042d73b88c39c6de7bf07368c7524ea65`;
- inner log SHA-256 `c30c9f61e008d8bdb321570373c1c5cf6f3bc9eaa9e980564d463d03e307686e`.

Therefore default `Once` has the intended attempt-local positive fanout semantics for the tested Treasury flow: compatible sockets inside the idle window reuse the positive choice, while an independent post-expiry attempt asks again.

### Stage 2 F3 generic GOST mTLS host scope — COMPLETE

Exact source/runtime browser:

- source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- main run `33039013849`, job `98408139479`;
- artifact `9636591432`.

Passing GIS GMP runtime capture:

- `gis-g1-g2-g3.zip` SHA-256 `8bb1fd3cfb6773739f0c9b05fd31555eef4180d65ce0518d54a63c85691558ce`;
- inner `gis-g1.moz_log` SHA-256 `451ed230a972b19ec35c1edc8952d1b234366ac5775c7252e8e67a92a289f1b1`.

GIS-G1 proves the generic coordinated callback reaches the real `portalgisgmp.cert.roskazna.ru` `CertificateRequest`: current acceptable-CA count is `36`, candidate count is `1`, and one Firefox picker is produced.

GIS-G2 proves real GIS GMP GOST mTLS/application success: the selected certificate creates one positive `Once` lease, four follow-on requests reuse it, and five certificate-host TLS 1.2 / `0xFF85` handshakes complete with `client_cert_loaded=1`, state `0x00000000`, and positive current verification status. The user confirms the certificate-login/application flow succeeds.

GIS-G3 proves generic callback registration does not create spurious UI: `pay.gov.ru` and `portalgisgmp.login.roskazna.ru` register the capability but issue zero client-certificate requests and complete with `client_cert_loaded=0`; all client-auth requests/picker activity belong only to the certificate endpoint.

The old Treasury-host-specific empty-client-Certificate / `0x80090326` GIS failure is therefore closed.

### GIS-G4 cross-host remembered-decision isolation — COMPLETE

Exact source/runtime browser is the same `ef1a7...` / run `33039013849` / job `98408139479` / artifact `9636591432`.

Capture:

- `session-current.zip` SHA-256 `6eccbf7d49e69a92d9634507b111759f096c4dee00a0313ec3d7c20017f5dec1`;
- inner `session-current.moz_log` SHA-256 `b3b2c8751e1f0cf66cfda73a1c068f609efb1692ade910b0d4ffcb42ff4905f8`.

A positive Treasury `Session` decision is established first and reused for later matching `lk-fzs.roskazna.ru` handshakes. In the same running browser process, navigation to `portalgisgmp.cert.roskazna.ru` creates a fresh client-auth request with a different browser context (`browser_id=17`), a fresh coordinated decision, and a fresh Firefox picker. The Treasury Session certificate is not silently applied to the GIS GMP host. After an explicit GIS `Once` choice, GIS mTLS succeeds normally.

This closes the planned cross-host isolation regression.

### Stage 2 explicit positive `Session` browser-process lifetime — COMPLETE

Exact source/runtime browser remains `ef1a7...` / run `33039013849` / job `98408139479` / artifact `9636591432`.

In-process evidence:

- `session-current.zip` SHA-256 `6eccbf7d49e69a92d9634507b111759f096c4dee00a0313ec3d7c20017f5dec1`;
- inner log SHA-256 `b3b2c8751e1f0cf66cfda73a1c068f609efb1692ade910b0d4ffcb42ff4905f8`;
- explicit Treasury `Session` (`remember=2`) is reused for ten later matching client-auth requests without another Treasury picker;
- all eleven Treasury mTLS handshakes succeed;
- user-visible behavior remains usable across tabs/windows in the same running browser process.

Restart-boundary evidence:

- `session-current2.zip` SHA-256 `e32b71ca51d151e553ab82c321fd8f829270e09b6a8390f7fb3ea828af3a29e7`;
- inner log SHA-256 `5b156cf0765c9aad3ceffeac6d1a845cea381f219ea168d59b318201b9f419b5`;
- prior Session process is `Parent 6200`; restarted browser is `Parent 5112`;
- first Treasury client-auth in the restarted process creates a fresh decision and fresh picker rather than consuming old Session state;
- after a new explicit Session choice, five later matching requests are again served from `scope=session`, and six Treasury mTLS handshakes succeed.

Therefore the tested positive Session decision has the intended process lifetime: shared across matching handshakes/windows/tabs while the browser is running, isolated from another GOST mTLS host, and cleared when the browser process exits. True persistent `Permanent` semantics remain open separately.

### Stage 2 Session-default picker exact-artifact regression — COMPLETE

Exact source/runtime browser:

- source `afbdad307f63e594d3715169d6e34235280dddaf`;
- main run `33073577269`, job `98521835354`;
- artifact `9652941006`;
- local `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`;
- local `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`.

SD1-SD6 close the targeted regression after making Session the picker default. Exact evidence in the test logs proves default `remember=2` Session selection, same-process remembered reuse, a fresh decision after process restart, preserved explicit Once short-fanout/post-expiry re-prompt semantics, cross-host isolation from GIS GMP, and zero sticky/error markers in all supplied runtime captures. The user separately confirms the picker presentation is visually correct, including the default Session choice and human-readable `Issued by` field.

This closes the Session-default UX/runtime iteration. It does not close `Permanent`, Cancel/Abort/provider negative paths, candidate policy, or final fail-closed server trust.

### Stage 2 T3 explicit Cancel / no-certificate semantics — COMPLETE

Exact source/runtime browser remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Passing capture:

- `T3 — explicit Cancel.zip` SHA-256 `32c3e844e85c1997f57bc682d193c91c9fbcfa2c9b0dc91d939a9e82eeec293c`;
- inner log SHA-256 `d6174d335074904da2e6bbbddfe2b22e582a805292c81e518c72be8a85bfa38b`.

In one browser process, four deliberate Firefox picker Cancels resolve as `selected=0`, consume the waiter with `reason=declined-consume`, and remove the decision in phase `2`. None is stored as reusable negative state; every later attempt receives a fresh picker. An unanswered fifth picker is instead removed from pending phase `0` by teardown, with closing/stale callbacks safely rejected. `Try again` then creates a fresh positive decision (`selected=1 remember=2`) and the same process completes 12 Treasury TLS 1.2 / `0xFF85` mTLS handshakes plus successful personal-cabinet authorization.

Deliberate Cancel naturally produces current-attempt `selected=0` and `0x80090326`/`0x0000054f` failure markers; these are not sticky-failure evidence. The decisive invariant is that later independent attempts receive fresh decisions and, after positive recovery, there are no unsolicited recurrence markers.

T3 is closed.

### Stage 2 T4 involuntary tab/load Abort semantics — COMPLETE

Exact source/runtime browser remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Passing capture:

- `T4 involuntary Abort.zip` SHA-256 `bfa51cc1d45c35c8c94cae6a7eb8fc32c6490d30782cdb256a1aefb24078d2f1`;
- inner log SHA-256 `f921c42d5e7b0299a40f79a5a707d5da93990018fb535edf529aef94a3d82f65`.

In one browser process (`Parent 6184`), the first Treasury picker decision is created for `browser_id=14` and then the owning tab is closed only `4.059 s` later while the picker is unanswered. The waiter is removed by `close-pre`, the decision is removed unresolved in phase `0`, shutdown re-entry is rejected because the handle is closing, and the late picker callback is stale-safe. There is no resolution, `selected=0`, `declined-consume`, or phase `2` for the abandoned decision.

A different tab in the same process (`browser_id=15`) then creates a fresh decision/picker. The positive default Session choice resolves `selected=1 remember=2`; eight later requests use `scope=session`, nine Treasury TLS 1.2 / `0xFF85` mTLS handshakes succeed, and the user confirms successful personal-cabinet authorization. The whole capture contains zero `E/GostTLS`, `0x80090326`, `0x0000054f`, and `MSSPI_X509_LOOKUP`.

Together T3/T4 close the intended split: explicit picker Cancel is Declined/phase `2`; involuntary navigation/tab/load abandonment remains unresolved phase `0` and is removed by lifecycle teardown. Neither path poisons later recovery.

### Stage 2 T7/T8 missing-medium/provider recovery — COMPLETE

Exact source/runtime browser remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Passing capture:

- `T7-T8.zip` SHA-256 `bd3fdf5bd73a2c7a6331235fe4f7bddb155698cdb6daaa5ef95f6fada1fae32c`;
- inner `SDx.moz_log` SHA-256 `8692ca7043f256d9673767a01e368d935c3f6df664ed814424b0abbeacf971a7`.

With the private-key medium unavailable before first GOST key acquisition, the certificate remains discoverable as one candidate from `CurrentUser\MY`. The single Firefox decision resolves positively as `selected=1 remember=2`. CryptoPro/provider refusal then fails that current MSSPI attempt with `0x8009030e` (`SEC_E_NO_CREDENTIALS`) without creating `selected=0`, `declined-consume`, or reusable negative certificate state.

A new Treasury request in the same `Parent 7056` consumes the existing `selected=1 scope=session` choice with no second picker. After the key medium is restored, the provider/key path proceeds, a new client-auth TLS flight is emitted, and Treasury TLS 1.2 / `0xFF85` mTLS completes with state `0x00000000` and `client_cert_loaded=1`. Protected application writes/reads resume immediately. The capture contains 13 Treasury client-certificate requests, 12 Session remembered uses after the failed attempt, and 12 successful recovered mTLS handshakes.

T7 closes the missing-medium/provider-Cancel boundary: identity discovery from `MY` is independent of live private-key availability, and the provider failure is attempt-local rather than a sticky Firefox decline.

T8 closes same-process provider recovery: returning the medium allows the original positive Session choice to complete real GOST mTLS/application traffic without browser restart or another Firefox picker.

The separate T5 already-acquired-credential failure boundary remains deferred; post-login medium removal is experimentally insufficient to invalidate the live provider credential in this environment.

### Stage 2 T9 long provider wait characterization — COMPLETE WITH CONCURRENCY LIMITATION

Exact source/runtime browser remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Passing/characterization capture:

- `T9 — долгий provider wait.zip` SHA-256 `2f06aeb4dae884cfd4b6f973bcce21de42dc092d907575a798b361e4f7c48bac`;
- inner `SDx.moz_log` SHA-256 `25a32e6bcd1c1b01d08c6624a429315f2eddefd97e81021dbc990c4b18b7b264`.

After a positive Treasury Session decision, the shared Firefox Socket Thread enters synchronous MSSPI/CryptoPro provider/private-key access. From dialog completion at `05:36:46.482 UTC` until provider Cancel returns at `05:38:01.224 UTC`, the capture contains no `GostTLS` event at all: a measured `74.742 s` Socket Thread stall. The user confirms the browser UI remains responsive and can open tabs/initiate navigation during the wait.

Provider Cancel returns `0x8009030e` (`SEC_E_NO_CREDENTIALS`) for the current Treasury attempt without creating `selected=0` or `declined-consume`. On the exact same timestamp, queued `pay.gov.ru` networking begins; its GOST TLS 1.2 / `0xFF85` handshake completes `291 ms` later with `client_cert_loaded=0`. GIS GMP login networking starts immediately afterward. Later Treasury traffic in the same process reuses `scope=session` and completes 12 successful recovered mTLS handshakes.

This closes T9 as a characterization: long provider wait/cancel is lifecycle-safe and does not corrupt Session/coordinator state, but the intended no-network-starvation expectation is false on the current architecture. Synchronous provider access monopolizes the shared Firefox Socket Thread and queues unrelated networking while the UI remains responsive.

Whether that concurrency limitation is materially worse than stock Firefox synchronous token/PIN/client-certificate behavior remains open in `TODO.md`. Any off-thread MSSPI/provider experiment must preserve the already-proven NSPR/MSSPI lifecycle, cancellation, client-auth decision semantics and proxy/CONNECT ordering.

### Stage 2 T10 detailed Russian picker presentation — COMPLETE

Exact source/runtime browser remains `afbdad307...` / run `33073577269` / job `98521835354` / artifact `9652941006`.

Sanitized user confirmation closes the detailed Russian picker UX beyond SD6: owner/name and issuer are human-readable, Cyrillic and expiry render correctly, `Session` is visibly selected by default, `Once` / `Session` / `Permanent` are all present, details are readable, and certificate serial remains details-only. A normal `Session` choice still leads to successful Treasury login after the inspection.

No raw screenshot or certificate identity is retained. T10 closes presentation only; it does not prove or imply real `Permanent` persistence, which remains T6.

## Windows compatibility

### Single-DLL source-built One-Core bcrypt with embedded mbedTLS XP x86 runtime — COMPLETE / SELECTED

Exact focused source/runtime evidence:

- branch `agent/gost-tls-poc`;
- project source-under-test `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- pinned upstream `shorthorn-project/One-Core-API-Source` commit `9eb3c31de9460c1ccce3f6a10c9c4a704f032514`;
- workflow `One-Core bcrypt source XP x86 smoke`;
- Actions run `33513084915`, job `99873297193`;
- runtime artifact `9802703271`, digest `sha256:e6ea796ef5f7dfb67e346630cd6432c9659e6d90d39ce90b8f44a1b3632edc8f`;
- diagnostics artifact `9802704126`, digest `sha256:d989ce72af60185cb16b0ff99d156ed39170beab00055e776b881ee2cc54e6de`;
- CI result: success.

The pinned active mbedTLS C modules are compiled directly into `bcrypt.dll`; no runtime `mbedtls.dll` is required. On physical Windows XP 5.1.2600, the exact runtime artifact contains only one DLL, `bcrypt.dll` (`520704` bytes), and both the exact-local dynamic consumer and the ordinary linked/IAT consumer load that app-local DLL, report `EXPORTS PASS`, `RNG PASS`, `SHA256 PASS`, and exit with code `0`. User-recorded SHA-1 for the proven `bcrypt.dll` is `ae021f44edc48b03bb4d67cb5773b62bdf60cb67`.

This closes the focused bcrypt implementation/runtime problem in the selected one-DLL form. Full Firefox startup remains separate: the next bcrypt work is to transfer this exact source/build/provenance contract into the full XP x32 package and require package survival plus physical-XP browser startup/browsing.

### Source-built One-Core bcrypt + mbedtls XP x86 runtime closure — COMPLETE / HISTORICAL BASELINE

Exact focused source/runtime evidence:

- branch `agent/gost-tls-poc`;
- project source-under-test `fdd4d4dac5a7d9611ec71975ae800437f45c47dd`;
- pinned upstream `shorthorn-project/One-Core-API-Source` commit `9eb3c31de9460c1ccce3f6a10c9c4a704f032514`;
- workflow `One-Core bcrypt source XP x86 smoke`;
- Actions run `33493625367`, job `99810642354`;
- runtime artifact `9794971087`, digest `sha256:03627eb494b604d3a84a9473cad8c0928b13ec458c20cee9e63bfc0ca10d75f1`;
- diagnostics artifact `9794971830`, digest `sha256:832563a5618d52f061fcc55efea463e618b4212aea12236ef7bf015cd39e93fe`;
- CI result: success.

The exact source-built runtime closure is `bcrypt.dll -> mbedtls.dll -> XP system DLLs`. On physical Windows XP SP3 x86, both dynamic and linked consumers load the local source-built `bcrypt.dll`, report `EXPORTS PASS`, `RNG PASS`, `SHA256 PASS`, and exit with code `0`.

This remains valid historical fallback/baseline evidence, but it is superseded as the selected packaging implementation by the later physically proven single-DLL embedded-mbedTLS result from source `a30a701...`, run `33513084915`.

### YY-Thunks WinRT expansion as the primary blocker strategy — RETIRED

This research line is formally closed as unpromising for the current Firefox 153 WinRT startup blocker. It does **not** retire YY-Thunks from the project as a whole.

The dedicated WinRT expansion sequence started at source `90067edba48fd4e8bb986ced02a47ae2189e9fb3` (`ci(win7): add WinRT YY-Thunks delay-load smoke`) and was reviewed through final source `3ebfef1ddbb70b0d2b29f160dabcaa8fbef4fab5` (`ci(win7): link OLE32 in WinRT smoke`). Across the sequence, the representative harness repeatedly advanced only by adding further YY aliases, CRT/runtime stubs, system import libraries, MASM glue, or harness isolation work.

Final exact evidence:

- source `3ebfef1ddbb70b0d2b29f160dabcaa8fbef4fab5`;
- run `33186862417`;
- job `98901994671`;
- workflow run number `31`;
- final unresolved transitive dependency: `__imp__StrCmpLogicalW@8`.

The sequence had already expanded through WinRT/runtime aliases and dependencies including `RoActivateInstance`, `RoGetActivationFactory`, WinRT string APIs, `_purecall`, operator delete, `atexit`, `wcsrchr`, `free`, `malloc`, and additional `ADVAPI32`, `GDI32`, `USER32`, `VERSION`, `NTDLL`, `OLEAUT32`, and `OLE32` linkage before reaching the next unresolved dependency. This showed that the approach was not converging toward a small, stable WinRT compatibility shim; it was reconstructing an increasingly broad transitive Windows/WinRT/CRT support surface before reaching real full-`xul.dll` or physical-Win7 proof.

Closed conclusion:

- do not continue solving the WinRT blocker by blindly adding the next YY alias, CRT stub, import library, system library, or harness workaround;
- retain YY-Thunks for narrow, stable, evidence-bounded Win32 compatibility gaps where it has already proved useful;
- residual surgical YY interposition may be reconsidered later if source-level WinRT reduction leaves only one or a few bounded imports;
- the primary active direction for this blocker is source-level WinRT removal/fallback, tracked in `WINRT_SOURCE_POC.md`, `PROJECT_STATE.md`, `TEST_LOG.md`, and `TODO.md`.

This closure is about the Windows compatibility line only and has no bearing on GOST TLS handshake correctness.

### Windows XP SP3 x86 representative msvcr14x + Rust/libstd + YY runtime — COMPLETE

Exact representative source/run:

- experiment branch `agent/msvcr14x-win7-smoke`;
- source `d78137a931145af877dc458b01e494ad0467723d`;
- run `33138244191`, job `98743029100`;
- runtime artifact `9673057839` (`msvcr14x-rust-yy-xp-x86-runtime`), artifact SHA-256 `3b9e1c2643cafee89061c3ce260b0b075c60a772d8cbcedb96cb90161a3c4970`;
- diagnostics artifact `9673058689`, artifact SHA-256 `6775abf4048e12bddcafe3f842be8b23af9c0669190772d0dee04c8e56aac323`.

The Actions workflow passed representative C++ `/MD` + modern `i686-pc-windows-msvc` Rust/libstd + pinned msvcr14x + narrow YY-Thunks linking, actual runtime dependency closure, XP x86 PE-floor/import gates, modern-host sanity execution, and runtime-bundle publication. The bundle contains the probe plus compatible `ucrtbase.dll` and `msvcp140.dll`.

The exact artifact was then executed three consecutive times on a physical Windows XP SP3 x86 machine reporting `Microsoft Windows XP [Version 5.1.2600]`; all three runs returned `ExitCode=0` without loader/runtime errors or antivirus intervention.

This closes representative XP x86 runtime viability for the tested workload. It does not prove Firefox 153/xul startup on XP or GOST TLS behavior on XP; full 32-bit Firefox/xul integration remains the next separate compatibility milestone.

## Bundled government-system extensions

### CryptoPro standalone updater/fallback/package mechanism — COMPLETE

Source `2ad7025ca300613d39a227b9e7582a341260d648`, run `32815118778`, job `97701728235`, evidence artifact `9551126137`.

Proven: committed fallback validation, network-failure fallback, invalid-fallback hard failure, downloaded-candidate validation, malformed/wrong-ID rejection, live CryptoPro endpoint exercise, synthetic staging and final synthetic package verification.

### CryptoPro real Mozilla portable-packaging integration — COMPLETE

Source `17b8d9762b489ed8fc9c3a8e1595802065dd7188`, run `32847887872`, job `97801745453`, evidence artifact `9569388324`, packaged-browser artifact `9569387758`.

Proven in one exact run: updater/selection, full Firefox build, real `dist/bin` extension verification, `mach package`, and final portable-archive exact extension path/hash/manifest-ID verification.

### CryptoPro clean-profile discovery and basic functional runtime — COMPLETE

Using packaged-browser artifact `9569387758`, a fresh profile automatically discovers/enables CryptoPro CAdES extension version `1.2.14`, and normal CryptoPro signature-verification functionality works. Version-to-version automatic update remains open separately.

### Three-extension government bundle real portable packaging — COMPLETE

Source `b3d097de20b7a5711f161199a727bcfe9468bcc8`; short validation run `32976571124`, job `98202642893`; full packaging run `32976571122`, job `98202641607`; packaged-browser artifact `9614275050`; evidence artifact `9614275551`.

The portable package contains CryptoPro CAdES `1.2.14`, legacy Gosuslugi/IFCPlugin `1.2.8`, Gosplugin `1.3.43.0`, and Russian-first `intl.accept_languages` packaging.

### Three-extension clean-profile discovery/enabled state — COMPLETE

On the exact packaged browser from source `b3d097de...`, run `32976571122`, artifact `9614275050`, a fresh dedicated profile shows all three bundled project extensions enabled. Native functionality of IFCPlugin/Gosplugin and update behavior remain open separately.