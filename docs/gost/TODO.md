# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog. Current synthesis is in `PROJECT_STATE.md`; exact runtime test sequencing/recovery is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP multi-host mTLS branch is in `STAGE2_GIS_GMP.md`; the WinRT source-removal alternative is in `WINRT_SOURCE_POC.md`; Windows XP compatibility architecture/import triage is in `XP_COMPATIBILITY_STRATEGY.md`; the mandatory XP x86 build/dependency contract is in `XP_BUILD_CONTRACT.md`; experiment evidence is in `TEST_LOG.md` and dated volumes.

## GOST TLS runtime — immediate

F1 close/shutdown lifecycle, F2 positive `Once` fanout/scope, F3 generic GOST mTLS host scope, GIS-G4 cross-host decision isolation, explicit positive `Session` lifetime, the SD1-SD6 Session-default exact-artifact regression, T3 explicit Cancel/no-certificate semantics, T4 involuntary tab/load Abort semantics, T7/T8 missing-medium/provider recovery, the T9 long-provider-wait characterization, and T10 detailed Russian picker presentation are closed as experiments.

Current Session-default runtime evidence is source `afbdad307f63e594d3715169d6e34235280dddaf`, main run `33073577269`, job `98521835354`, artifact `9652941006`. Do not repeat closed tests on unchanged source merely for confirmation.

### 1. Continue client-decision / provider semantics

Immediate next:

1. **T6 — real Permanent semantics.** Implement and prove persistence distinct from the current process-local non-Once store, including intended process-restart persistence and the intended forget/change behavior.
2. **T11/T12 — discovery boundary.** Verify dynamic `CurrentUser\MY` re-enumeration and determine whether provider/removable-media-only identities are discoverable without browser restart or interactive provider/PIN/media UI during candidate enumeration.

**T5 — Session failure-boundary regression is DEFERRED, not closed.** The 2026-08-28 T5 probe showed that removing the key medium *after* a successful Treasury Session mTLS does not create a provider failure: CryptoPro/SSPI retains an already-acquired credential context, and a fresh Treasury socket about 192 seconds later still receives a new CertificateRequest, reuses `scope=session`, emits a client-auth flight and completes TLS 1.2 / `0xFF85` mTLS. Therefore post-login medium removal is not a valid T5 fault injection in the current environment. Resume T5 only when there is a safe deterministic way to invalidate an already-acquired provider/private-key credential inside the same browser process; do not invent an invasive synthetic invalidation merely to force the test.

T7/T8 prove the complementary pre-acquisition boundary on the current artifact: with the certificate still discoverable from `CurrentUser\MY` but the key medium unavailable before first private-key acquisition, provider refusal produces `SEC_E_NO_CREDENTIALS` only for that MSSPI attempt; the positive Firefox `Session` decision survives, and after the medium returns the next request in the same browser process reuses `scope=session`, completes GOST mTLS and resumes protected application traffic without another picker.

T9 now proves the long-wait concurrency boundary. A positive Treasury Session selection entered the synchronous CryptoPro/SSPI provider path for `74.742 s`. The Firefox UI remained responsive by user observation, but the shared Firefox Socket Thread produced no `GostTLS` activity during that interval. When the provider action was cancelled, `SEC_E_NO_CREDENTIALS` returned and queued network work resumed immediately: `pay.gov.ru` began on the same timestamp and completed GOST TLS `291 ms` later. The later Treasury flow still reused `scope=session` and recovered successfully. Thus timeout/coordinator state remains safe, but **global Socket Thread network starvation during synchronous provider UI is a confirmed behavior**.

T10 closes the detailed picker presentation on the current artifact: human-readable owner/issuer presentation, correct Cyrillic and localized expiry, readable details, serial details-only, all three remember choices visible, and `Session` visibly selected by default. The successful post-inspection Treasury login is only a functional smoke; T10 does not imply real `Permanent` persistence.

T3/T4 establish the negative-decision split on the current artifact: explicit picker Cancel is consumed as Declined/phase `2`, while an unanswered picker abandoned by tab/load teardown remains unresolved phase `0` and is removed by lifecycle cleanup. Neither path poisons later recovery.

The current source routes every non-`Once` positive choice through the same in-memory remember store. Therefore real persistent `Permanent` semantics remain unproven; do not assume the current `Permanent` UI choice survives process restart.

### 2. Provider-wait Socket Thread isolation follow-up

T9 failed the intended no-network-starvation subcriterion: while CryptoPro/provider key access was synchronously blocked for `74.742 s`, new network work from other browser windows/tabs queued behind the same Firefox Socket Thread and started only when the provider call returned.

Open follow-up:

- compare this behavior with stock Firefox synchronous client-certificate/token/PIN handling before declaring it an incompatibility;
- determine whether MSSPI/CryptoPro key-access can be moved off the shared Socket Thread without breaking NSPR/MSSPI state ownership, client-auth lifecycle, cancellation, or proxy/CONNECT sequencing;
- do not redesign threading merely from intuition: preserve the exact T9 capture as the concrete baseline and require a focused implementation experiment if offloading is attempted;
- treat this as a responsiveness/performance limitation, not as evidence of a failed GOST handshake or broken UI event loop.

### 3. Continue the remaining Stage 2 runtime matrix

Remaining groups include:

- T5 deterministic failure-boundary test once an already-acquired provider credential can be invalidated safely;
- dynamic `CurrentUser\MY` discovery and token-only/removable-media discovery;
- no acceptable cert / unsuitable cert / wrong cert / unavailable key / PIN-private-key failure / server rejection;
- issuer-aware validity/KU/EKU/private-key candidate policy;
- sensitive-log audit;
- final exact-build Treasury mTLS regression.

### 4. Attribute picker timeout and residual poll churn

T2R and the T3 timeout segment both show lifecycle-safe but non-fixed picker teardown timing. T2R measured `32.576 s`, `37.420 s`, `30.330 s`; T3 measured one additional unanswered-picker removal after `30.276 s`. T4 is deliberately different: closing the owning tab removed the pending decision after only `4.059 s`, confirming that its teardown was user/load driven rather than timeout driven.

T9 is also distinct from those Firefox-picker timeouts: after the Firefox certificate decision had already resolved, the Socket Thread remained synchronously inside provider/key acquisition for `74.742 s` until provider Cancel. No automatic ~30-second picker teardown occurred in that state.

Before changing timeout policy or calling the wait path fully quiescent:

- identify which Firefox/Necko/load timer actually tears down each timed-out *Firefox picker* attempt;
- keep that lifecycle separate from the T9 provider/key-access wait;
- explain why the first historical picker-timeout cycle polls much more aggressively than later cycles;
- preserve stock-compatible timeout semantics rather than introducing an arbitrary GOST-specific timeout.

## GOST TLS security — mandatory Stage 2 server-trust closure

Complete fail-closed server verification:

- reject `verifyOk == 0`;
- reject any nonzero verification status;
- integrate Firefox temporary/permanent certificate overrides;
- positive browser-session verification cache keyed by exact server identity;
- prove valid Treasury hostname/chain succeeds;
- prove wrong hostname and invalid/untrusted chain fail;
- prove client private-key operations cannot occur before server trust.

Do not use a production verification bypass.

## GOST network coverage — later

After Stage 2 security/runtime closure:

- direct connection without proxy;
- HTTPS proxy / nested TLS;
- SOCKS lifecycle;
- proxy authentication/reconnect edge cases beyond the currently exercised HTTP CONNECT path.

## Final UX polish — later

After core GOST TLS is stable, evaluate transparent one-shot GOST discovery:

- explicit allowlist still enters MSSPI immediately;
- unknown host starts with NSS;
- only `SSL_ERROR_NO_CYPHER_OVERLAP` may authorize one MSSPI retry;
- no retry loops;
- only a successful, normally verified GOST connection becomes session-confirmed;
- discovery cache is process/session scoped and never bypasses trust/client-auth policy.

## Windows compatibility — independent

The current mandatory Windows XP x86 build contract is defined in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md). Its physically proven reference is source `b19ba4ff3eebd2f323743d92110241fc9d4ce399`, run `33387080767`, job `99472017220`, runtime artifact `9756275917`: the newly generated app-local CRT + representative C++ `/MD` + Rust libstd + narrow YY/SRW runtime starts and executes successfully on a real Windows XP machine. Preserve this contract while remediating the full browser; do not regress a dependency family once it has been brought under the contract.

### Trusted project primitive — `bcrypt.dll`

The selected single-DLL One-Core bcrypt result is not an open implementation hypothesis anymore. Within this project, exact `xp-bcrypt-v1/bcrypt.dll` is an **approved/trusted XP x86 runtime primitive** and may be consumed directly by browser workflows and experiment branches without repeating the One-Core/mbedTLS build or the focused BCrypt research.

Trust identity:

- binary source-under-test `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- focused run `33513084915`, job `99873297193`, runtime artifact `9802703271`;
- physical Windows XP 5.1.2600 PASS through both exact-local dynamic loading and ordinary linked/IAT resolution;
- technical release/tag `xp-bcrypt-v1`, raw asset `bcrypt.dll`;
- size `520704` bytes;
- SHA-256 `f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`;
- no runtime `mbedtls.dll`; the required mbedTLS implementation is embedded in `bcrypt.dll`.

For future work, **do not rebuild or re-prove this library merely to use it in another branch or a heavy Firefox build**. Consume the raw `xp-bcrypt-v1` asset, optionally through an Actions cache, and require exact size/SHA-256 before staging. On cache miss, fetch the canonical Release asset; do not fall back to rebuilding One-Core. Reopen the focused bcrypt implementation only if the approved binary identity changes, a future replacement is intentionally being produced, or full-browser integration produces new evidence attributable to this exact DLL.

The full XP import audit must also distinguish an unresolved stock-XP dependency from an approved app-local replacement. `BCRYPT.dll` must not remain unconditionally forbidden by name once exact `xp-bcrypt-v1/bcrypt.dll` is staged: a browser PE import of `BCRYPT.dll` is acceptable only when the approved app-local DLL is present and hash/size verified. Missing or mismatched app-local `bcrypt.dll` remains a hard failure; `bcryptprimitives.dll` and unrelated post-XP dependencies remain forbidden. The official portable package and the direct `dist/bin` runtime archive must both preserve the same exact approved DLL.

The earlier two-DLL source-built result, source `fdd4d4dac5a7d9611ec71975ae800437f45c47dd`, run `33493625367`, job `99810642354`, runtime artifact `9794971087`, remains valid historical fallback/baseline evidence but is no longer the selected packaging contract.

The earlier representative Windows XP SP3 x86 coexistence question also remains closed for source `d78137a931145af877dc458b01e494ad0467723d`, run `33138244191`, job `98743029100`, runtime artifact `9673057839`: the exact probe with bundled msvcr14x `ucrtbase.dll` and `msvcp140.dll` ran three times on physical Windows XP SP3 x86 with `ExitCode=0`.

The current full Firefox import baseline is now the sandbox-disabled `agent/winrt-source-poc` build:

- source-under-test `1635d28360ee35d47c1d8237bcf8f5864cc1144f`;
- run `33310150314`;
- job `99253613546`;
- runtime artifact `9733280458`;
- diagnostics artifact `9733280937`;
- full browser build/package/runtime staging succeeded; the run is red only at the broad XP import gate.

The curated current gate reports 103 rows, 26 unique forbidden API names across 15 PEs, with `xul.dll` contributing 19 API rows + `bcrypt.dll` and `mozglue.dll` contributing 11 API rows + `bcrypt.dll`.

**Inherited x86 sandbox baseline:** official upstream r3dfox `v153.0.3` ships the 32-bit build with `--disable-sandbox`. A sandbox-enabled Win7/Vista x86 pass is not an XP-port prerequisite. Keep build-time sandbox disablement on the XP/x86 product path unless sandbox restoration is explicitly reprioritized.

**Old physical-XP `CloseThreadpoolWork` blocker:** the earlier exact artifact from run `33141004769` failed before UI startup on hard `KERNEL32!CloseThreadpoolWork`. The current run `33310150314` direct-import inventory and raw per-PE import diagnostics contain no `CloseThreadpoolWork`. Therefore that specific import blocker is no longer expected in the current artifact, but only an exact physical-XP launch can close the runtime boundary.

**Legacy `D3DCompiler_47.dll` packaging boundary — CLOSED.** Source `b77b22ef1e35564dfe76997d3d393d45ee697e49`, run `33349340069`, job `99359475336` passes preparation, staging, dedicated retarget validation, package creation, and the post-package survival gate for the pinned legacy Firefox XP `D3DCompiler_47.dll`. The run remains red only because the later broad XP PE-floor/direct-import audit reports independent compatibility violations. Do not schedule another full build merely to re-prove this packaging hypothesis on unchanged source.

Open work, in order:

1. **Prove the unified XP contract inside the full-build workflow.** The default-branch `gost-poc-build-xp-x32.yml` now builds pinned msvcr14x with restore/binlog and has a pre-Firefox `GATE - Require proven XP x86 msvcr14x runtime contract`. Run it from the current default-branch source, bind the run/job/SHA, and require the CRT gate to pass before accepting another multi-hour build. This is the first controlled dependency family migrated from post-build retargeting to build-time XP compatibility.
2. **Turn the broad audit into a component-by-component dependency-removal queue.** After the CRT contract is green in the full workflow, regenerate the surviving forbidden-import inventory and distinguish project-built/Firefox-owned PEs from separately built/shipped third-party PEs. For every dependency family we control, prefer source/build/dependency remediation and add a focused fail-fast gate so later work cannot regress it.
3. **Caller/owner classification for the core browser PEs.** Use diagnostics `9733280937` initially, then replace them with the next full-build diagnostics, to identify exact callers/owning abstractions for the surviving `xul.dll`, `mozglue.dll`, `r3dfox.exe`, and `plugin-container.exe` imports. Do not map all gate API names directly to YY.
4. **Prefer XP-native/source/backend solutions before YY.** For current candidates such as `CancelIoEx`, `CompareStringOrdinal`, `GetCurrentProcessorNumber`, `GetFileInformationByHandleEx`, `GetFinalPathNameByHandleW`, the locale-name/LCID family, `GetTickCount64`, `SetFileInformationByHandle`, and `InitializeCriticalSectionEx`, evaluate caller semantics and an XP-native implementation or owned legacy backend first. These are candidate directions, not pre-approved replacements.
5. **Classify the synchronization family by ownership.** SRW/condition-variable imports appear in multiple PEs. Mozilla-owned abstractions may justify one XP synchronization backend; unavoidable Rust/MSVC/toolchain surfaces are strong narrow-YY candidates; separately linked DLLs require their own build/dependency solution. The CRT-side SRW/FLS regression is already covered by the mandatory msvcr14x contract and must not be reintroduced.
6. **Classify separately linked shipping/feature DLLs independently.** `libGLESv2.dll`, `mozavcodec.dll`, `mozavutil.dll`, `gkcodecs.dll`, `mozinference.dll`, and `gmp-clearkey` cannot be fixed merely by adding an archive to the `xul.dll` link. Decide required vs optional, then rebuild/select legacy version/replace/disable per component. The legacy `d3dcompiler_47.dll` staging/packaging boundary is already closed by run `33349340069`; only reopen it if a later exact import/runtime result shows a D3DCompiler-specific regression.
7. **Exclude test/developer/fake artifacts from the product blocker budget.** `gmp-fake`, `gmp-fakeopenh264`, `logalloc-replay.exe`, and `xpcshell.exe` remain visible diagnostically but are not automatic XP product blockers.
8. **Regenerate the exhaustive XP SP3 inventory from the next contract-compliant full-build diagnostics.** The old ~57 `xul.dll` / ~73 whole-`dist/bin` estimates predate sandbox removal and the now-physical CRT contract and are no longer current planning counts.
9. **Keep YY physically narrow.** Run `33316988353`, job `99272141403`, source `39ce8453be32557dfb709bce8ee412c16f78a72f` successfully proved that YY 1.2.2 can cover the current 26-name API set at representative-link scale. Treat this only as upper-bound capability evidence; production YY membership must be derived after caller classification. Never reintroduce full YY `kernel32.lib` interposition.
10. **Consume the trusted `xp-bcrypt-v1` primitive in the full XP x32 browser.** Do not reproduce the One-Core/mbedTLS build in the heavy workflow. Obtain raw `bcrypt.dll` from the canonical `xp-bcrypt-v1` Release asset, optionally via cache; verify exact size `520704` and SHA-256 `f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`; stage only that DLL; adapt the broad import gate so `BCRYPT.dll` is accepted only when this approved app-local binary is present; require survival with the same hash in both `dist/bin` runtime output and the official portable package; then bind the resulting exact browser artifact to a physical-XP startup test. Treat the library itself as trusted project infrastructure unless new evidence specifically invalidates it.
11. **Focused smokes before each expensive full Firefox retry.** Prove each chosen source fallback, owned backend, component rebuild, and final narrow YY membership cheaply, then transfer the proven contract/gate to the full build.
12. **Physical XP startup/browsing.** Test the resulting exact artifact on physical XP. The current artifact `9733280458` may also be used as an intermediate runtime probe to confirm that the former `CloseThreadpoolWork` boundary has moved, but do not infer a browser pass from import tables alone.
13. **GOST TLS on old Windows — later exact-artifact milestone.** A browser that starts and browses ordinary pages on XP still does not prove MSSPI/CryptoPro GOST behavior.

Detailed classification policy and current component matrix are authoritative in [`XP_COMPATIBILITY_STRATEGY.md`](./XP_COMPATIBILITY_STRATEGY.md).

### Deferred optional hardening — restore x86 sandbox

The sandbox-on Win7/RNG work is preserved but removed from the XP critical path.

Historical evidence includes source `982d6529a707c6feecad97c725feed8a3cd21c81` / run `33141004769`, where sandbox-enabled Win7 x32 content tabs died in `RandomUint64OrDie`, and source `19c82e7eec160dab761083d454d084515060f808` / run `33298304132` / job `99221664596`, where the CryptoAPI RNG experiment still produced `Gah. Your tab just crashed.` with sandbox enabled.

Do **not** spend new full-build cycles on `LowerToken`, RNG pre-warm, persistent `HCRYPTPROV`, or other modern sandbox-on fixes unless the user explicitly chooses sandbox restoration as a security-hardening goal. If reopened, start from the existing exact WinDbg/runtime evidence and design specifically for the desired XP/Vista/Win7 x86 sandbox semantics rather than treating current Win7 behavior as an XP prerequisite.

## Bundled government-system extensions — independent

Current packaged three-extension artifact `9614275050` is packaging-proven and clean-profile discovery/enabled-state is proven for all three project extensions.

Next:

1. re-check CryptoPro basic functionality on this exact package;
2. test legacy IFCPlugin with installed native host;
3. test Gosplugin with its local/native component;
4. verify the Russian-first content-language preference in runtime if desired;
5. generalize the historically CryptoPro-named packaging workflow to assert all three XPI + language pref;
6. transfer only proven shared packaging gates into the two main browser workflows;
7. later prove real version-to-version update behavior where a valid older/newer signed extension is available.

## Firefox/NSS trust integration — product transfer only

The isolated two-root trust PoC on `agent/trust-integration-poc` is **COMPLETE**. Do not schedule another build or runtime test merely to re-prove it on unchanged source.

Open product-integration task:

1. transfer the minimal audited trust diff from `agent/trust-integration-poc` into `agent/gost-tls-poc`;
2. preserve exactly the two pinned RSA/GOST roots, `Certificates.ImportEnterpriseRoots=true`, both `Certificates.Install` entries, final-package survival entries and lexical `gost`-before-`rsa` staging order;
3. preserve the inherited AutoConfig defaults because exact clean-profile runtime evidence already proves `security.enterprise_roots.enabled=true` is locked by policy;
4. do not merge the experimental branch history wholesale;
5. after transfer, use ordinary regression gates as needed, but do not reopen the completed trust PoC absent new contradictory evidence.

## CI artifact ergonomics — project-wide

For every heavyweight workflow that performs a full browser compilation/package, add a dedicated portable artifact containing only the produced runnable `.7z` archive.

- Keep the existing package, runtime, diagnostics, import-audit, evidence, and other artifacts; the portable artifact is additional, not a replacement.
- Publish the exact `.7z` produced by the successful full compilation/package as its own artifact payload, without unrelated build trees or diagnostics in that artifact.
- Apply this consistently to the project's heavy full-build lines so a tester can retrieve the portable browser from every successful full compilation without downloading the much larger general package/runtime bundle.
- Treat this as a developer/test ergonomics requirement only; it does not change the evidentiary meaning of the existing build, runtime, packaging, or compatibility artifacts.

## Upstream base — deferred

Stay on r3dfox / Firefox 153. Do not migrate to Firefox 154 merely because upstream Mozilla has released it. Evaluate a newer base only after r3dfox itself publishes one and the user explicitly decides to upgrade.