# r3dfox GOST TLS — Windows XP compatibility strategy

Last updated: 2026-08-30

This document records the architectural policy for the Windows XP x86 compatibility track. It is intentionally separate from the GOST TLS runtime/handshake track: making Firefox/r3dfox start and browse on XP or Win7 does not prove any MSSPI/CryptoPro GOST behavior.

The goal is **not** to reproduce every Vista/7/8/10 API on Windows XP. The goal is to preserve useful Firefox behavior with the smallest maintainable compatibility surface, choosing an XP-native implementation, a bounded compatibility library, an intentional legacy fallback, or feature removal according to the semantics of each subsystem.

## Core policy

For every API or DLL that is absent on stock Windows XP SP3 x86, classify the dependency before writing compatibility code.

Preferred order:

1. **Remove the unsupported modern feature from the XP build when the feature itself has no useful XP meaning.** The dependency must become absent from the final PE rather than emulated.
2. **Replace the implementation with a real XP-native path when the useful operation exists on XP through older APIs.** Preserve the Firefox-facing contract, not the exact modern Windows call.
3. **Use YY-Thunks or another bounded compatibility layer for small, stable, low-level Win32 gaps with known semantics.** Do not expand a narrow provider into a reconstructed modern Windows runtime.
4. **Allow a vetted third-party XP compatibility implementation when it provides a cleaner and more complete boundary than source rewrites.** It must pass license, provenance, ABI/export, security, packaging, and physical-XP runtime review before adoption.
5. **Write a project-specific shim only as a last resort**, when the behavior is required, no natural XP implementation exists, and no suitable maintained compatibility implementation is available.

A missing API count is therefore an **inventory**, not an implementation backlog.

## Inherited r3dfox x86 sandbox baseline

The upstream fork baseline matters before treating any sandbox-enabled failure as a project blocker.

Official `Eclipse-Community/r3dfox` release `v153.0.3` targets `win-153` and explicitly states that the **32-bit build is built with `--disable-sandbox`**. The release note links issue `Eclipse-Community/r3dfox#11` and explains that with sandbox enabled on Vista the browser fails to open multiple processes, breaking normal operation; the 64-bit build is described as unaffected.

Issue #11 records the maintainer's deliberate policy choice: the x86 browser does not spawn child processes correctly with the sandbox enabled, `MOZ_DISABLE_CONTENT_SANDBOX=1` mostly mitigates it, and the maintainer chose to ship the 32-bit build without sandbox rather than require that runtime workaround. The issue is closed as `not_planned`.

Therefore the project must treat **sandbox-disabled x86 as the inherited r3dfox release baseline**, not as a regression introduced by the XP/GOST work.

For the XP port:

- a sandbox-enabled Win7/Vista x86 pass is **not** a prerequisite for continuing XP loader/import/source-compatibility work;
- the normal XP product experiment may use build-time `--disable-sandbox`, matching upstream r3dfox x86, instead of relying on an environment variable at runtime;
- historical sandbox-on experiments remain useful evidence and possible future hardening work, but they are not on the default XP critical path;
- restoring an XP/Vista/Win7 x86 restricted-token sandbox is a separate security-hardening project and should be explicitly reprioritized before consuming new full-build cycles.

This does not claim that disabling sandbox is security-equivalent to a working sandbox. It is a compatibility-baseline decision inherited from the maintained fork we are porting.

## Proven examples of the policy

### WinRT: remove/fallback, do not emulate

The physical Win7 failure from source `982d6529a707c6feecad97c725feed8a3cd21c81`, run `33141004769`, job `98751650853`, runtime artifact `9676549576`, proved a later parent-process crash caused by `xul.dll` delay-loading the absent WinRT API-set and reaching `RoGetActivationFactory`.

The project already retired broad YY-Thunks expansion as the primary answer to that blocker. The experimental branch `agent/winrt-source-poc` instead removes or replaces nonessential WinRT consumers at the feature boundary: WinRT toast support becomes a stub/XUL fallback, InputPane becomes a legacy path, and selected Rust/UI/package-manager WinRT consumers are removed or made unsupported for the legacy build.

For the XP target, WinRT activation/HSTRING APIs belong in the classification **MUST_BE_ABSENT**, not `THUNK_REQUIRED`.

If a future XP artifact again contains reachable imports such as `RoGetActivationFactory`, `RoActivateInstance`, `WindowsCreateString`, or the WinRT API-set DLLs, treat that as a source-selection regression/leak first.

### OS RNG: preserve the operation with a real XP implementation

The `agent/legacy-rng-poc` line demonstrates the preferred source-level adaptation model.

Experimental source:

- branch `agent/legacy-rng-poc`;
- source `19c82e7eec160dab761083d454d084515060f808`;
- underlying source change `7f84f7b4d083b1ea068b86910a90fabebb7524e1` (`fix(xp): use CryptoAPI for Windows OS RNG`).

`mozilla::GenerateRandomBytesFromOS()` keeps the same Firefox-facing contract and uses real Windows CryptoAPI:

`CryptAcquireContextW -> CryptGenRandom -> CryptReleaseContext`.

This remains a useful example of source-level semantic replacement. Its separate Win7 sandbox-on runtime experiment did **not** establish that this per-call CryptoAPI lifecycle works after modern sandbox lockdown, and sandbox-on behavior is no longer an XP acceptance gate because upstream r3dfox x86 itself ships without sandbox.

## Sandbox-enabled Win7 experiment — historical/optional hardening evidence

The CryptoAPI-RNG full build was:

- workflow run `33298304132`;
- job `99221664596` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- branch `agent/legacy-rng-poc`;
- source-under-test `19c82e7eec160dab761083d454d084515060f808`.

The browser build/package completed successfully; the Actions job became red only at the broad XP import audit. Artifacts were:

- package `9729515763`, digest SHA-256 `5434c8b61a8351761b514653136133aa026081824d6694d59031df6baedf4be9`;
- runtime `9729516268`, digest SHA-256 `7fbc6b3977b1910dc3087424233726cecbc6b4e6564bff4bdfbb336f61cc8de7`;
- diagnostics `9729516770`, digest SHA-256 `309e63e4dc0369cb84431a6ed024578438e5562dbdbbd056f5fbfab7d9570b3f`.

On physical Win7 x32 with the content sandbox enabled, the parent browser started but ordinary pages still produced `Gah. Your tab just crashed.`. This is a valid FAIL for that **sandbox-enabled experimental configuration**, but it is not an XP port blocker after accounting for the official r3dfox x86 `--disable-sandbox` release policy.

Do not spend another full Firefox build on retained CryptoAPI provider state, RNG pre-warm, `LowerToken`, or related sandbox-on work unless sandbox restoration is explicitly made a goal again. If that happens, reuse the existing WinDbg/RNG evidence instead of restarting diagnosis from zero.

## Import inventory baseline

The most useful current import inventory was produced by the earlier full-build experiment:

- branch `agent/winrt-source-poc`;
- source `4c982371a53a5d03cfcfe1d4107d1a40cc99c3f9`;
- run `33264392080`;
- job `99131766920`;
- diagnostics artifact `9719920434`.

That run successfully built, packaged, staged the runtime, and then failed only at `GATE - Audit XP x32 PE floor and direct imports`.

### What the current workflow gate actually reports

The checked-in audit is still based on a manually curated forbidden-API/DLL list, not a complete XP SP3 export manifest.

Its exact result for run `33264392080` is:

- 112 violation rows total;
- 110 API rows;
- 2 DLL rows;
- 27 unique API names;
- 15 affected PE files;
- the DLL-level violations are `bcrypt.dll` imports in `mozglue.dll` and `xul.dll`;
- `xul.dll` contributes 20 rows: 19 listed APIs plus `bcrypt.dll`.

The 27 unique API names in this current hard-coded gate are:

`AcquireSRWLockExclusive`, `AcquireSRWLockShared`, `CancelIoEx`, `CompareStringOrdinal`, `FlsAlloc`, `FlsFree`, `FlsGetValue`, `FlsSetValue`, `GetCurrentProcessorNumber`, `GetFileInformationByHandleEx`, `GetFinalPathNameByHandleW`, `GetLocaleInfoEx`, `GetTickCount64`, `GetUserDefaultLocaleName`, `InitializeConditionVariable`, `InitializeCriticalSectionEx`, `InitializeSRWLock`, `LCIDToLocaleName`, `LocaleNameToLCID`, `ReleaseSRWLockExclusive`, `ReleaseSRWLockShared`, `SetFileInformationByHandle`, `SleepConditionVariableCS`, `SleepConditionVariableSRW`, `TryAcquireSRWLockExclusive`, `WakeAllConditionVariable`, `WakeConditionVariable`.

This list is useful as a regression gate but **must not be interpreted as the complete XP compatibility surface**.

### Expanded XP SP3 estimate

A broader comparison of the same diagnostic import tables against the stock XP SP3 x86 system-export surface produced the following planning estimate:

- `xul.dll`: approximately **57 unique direct imported functions absent from stock XP SP3**;
- the full scanned `dist/bin` PE set: approximately **73 unique direct imported functions absent from stock XP SP3**.

These are planning numbers, not a frozen requirement list. They should be regenerated by a deterministic exhaustive import audit before individual implementation work is scheduled.

The current narrow YY diagnostic catalog contains implementation symbols for approximately:

- **49 of the 57** estimated `xul.dll` direct gaps;
- **65 of the 73** estimated whole-scanned-set direct gaps.

Eight direct-import candidates from that comparison were not found in the YY implementation-symbol catalog:

- `GetApplicationRestartSettings`;
- `GetNamedPipeServerProcessId`;
- `PropVariantToString`;
- `RegisterApplicationRestart`;
- `RtlDosPathNameToNtPathName_U_WithStatus`;
- `UnregisterApplicationRestart`;
- `WSASendMsg`;
- `WSCGetProviderInfo`.

**YY implementation-symbol availability does not prove that the final PE is correctly thunked.** The run still has direct imports because the required weak-alias/archive members are not necessarily extracted into every consumer. This distinction is central: much of the remaining work is linkage/source-selection/integration, not writing dozens of new API implementations.

## Why the whole-`dist/bin` number is an overestimate of browser work

The current audit scans every PE under `dist/bin`. That includes real browser/runtime components, but also test/developer/helper binaries such as fake GMP modules, `logalloc-replay.exe`, `xpcshell.exe`, and similar artifacts.

Do not spend compatibility engineering effort on a test-only binary merely because it appears in the broad audit.

Future reports must classify each PE as at least:

- required browser startup/runtime;
- optional browser feature/plugin/media component;
- command-line/developer utility;
- test/fake-only artifact.

Only the first two categories belong in the primary XP browser compatibility budget. Optional components may instead be omitted from the XP package when their modern Windows dependency surface has no acceptable legacy value.

## Remediation classes

### 1. MUST_BE_ABSENT / feature removal

Use when the imported API represents a modern Windows feature that is not meaningful or not required on XP.

Examples include:

- WinRT activation/string paths;
- native WinRT toast/InputPane/AppCapability integrations;
- modern shell/application-restart behavior where XP has no equivalent requirement;
- DXGI/D3D11-only paths when the XP build can use a legacy/software graphics path;
- optional modern subsystems whose cost exceeds their value on the legacy target.

Success criterion: the final required XP PE no longer imports or reaches that feature surface.

### 2. XP_NATIVE_REPLACEMENT

Use when Firefox needs the operation but XP provides an older real mechanism.

The CryptoAPI RNG experiment is one example of the intended source-level pattern, independent of the optional sandbox-on experiment.

Other likely candidates should be evaluated semantically, for example older registry, locale, path, process-query, socket or time-zone APIs. Do not mechanically implement a Vista API under the same name if changing one internal Firefox implementation can preserve the behavior more cleanly.

### 3. YY_COVERED

Use YY-Thunks for bounded low-level Win32 compatibility gaps with stable semantics, especially synchronization/time/system helpers shared by many unrelated Firefox components.

This remains valid project policy despite the retired WinRT YY experiment. The rejected strategy was broadening YY into an expanding WinRT/transitive runtime, not using YY for ordinary compatibility thunks.

### 4. THIRD_PARTY_COMPAT

The project may include external compatibility work when it is technically and legally better than reimplementing the same API surface.

The SourceForge `bcrypt-xp-dll` package was inspected directly. The supplied archive contains only prebuilt x64/x86 `bcrypt.dll` binaries and no corresponding source tree, `LICENSE`/`COPYING` file, or written source offer. The x86 binary exposes a broad BCrypt surface, but it is an opaque cryptographic binary and also brings additional CRT/API-set dependencies.

Therefore that binary is **not an acceptable vendored/distributed project dependency in its current form**. It may remain useful as a reference/probe binary for ABI and physical-XP experiments, but not as the foundation of the shipped compatibility layer unless corresponding source/provenance becomes available and licensing can be satisfied.

A better third-party-backed design may be an open, reproducible compatibility facade built from source. Mbed TLS is one candidate cryptographic backend because its source is public and it offers an Apache-2.0/GPL-2.0-or-later licensing choice. Such a facade should still implement only the BCrypt subset actually required by the Firefox XP runtime; it must not replace NSS or the MSSPI GOST TLS stack.

Before adopting any third-party compatibility implementation, require:

1. inspect source provenance and maintenance state;
2. verify license compatibility with distribution in this project;
3. inventory the exact exports required by the final XP runtime;
4. compare calling convention, structures, constants, status codes and edge-case semantics;
5. review crypto implementation/dependencies and security implications;
6. build/package x86 deterministically from source rather than trusting an opaque binary;
7. run focused API tests and the exact browser on physical XP SP3 x86;
8. document the pinned source/version/hash and keep it independently replaceable.

Third-party code is an implementation option, not evidence by itself. It becomes a project dependency only after this review.

### 5. CUSTOM_SHIM_REQUIRED

Reserve for a small residual set where:

- the behavior is required for browser operation;
- source removal would break necessary functionality;
- no adequate XP-native path exists;
- YY-Thunks or another established compatibility library does not provide the required semantics;
- no acceptable third-party implementation exists.

Custom shims should be narrow, separately testable, and tied to exact importing subsystems.

## Current planning estimate after classification

The previous raw estimate of 57 direct `xul.dll` gaps does **not** imply 57 implementations.

Until the exhaustive manifest/classification report exists, use the following only as an order-of-magnitude planning estimate:

- roughly **10–15 source-level legacy adaptations**, often removing several imports at once;
- roughly **20–30 stable low-level imports** that are good YY-Thunks/compatibility-layer candidates;
- roughly **15–20 modern-feature imports** that should disappear with XP source selection/fallbacks rather than be emulated;
- only about **3–6 genuinely custom shim cases** as a conservative upper working estimate after source removal, XP-native replacements and reusable compatibility libraries are considered.

The custom-shim number may fall further after exact caller analysis and third-party compatibility review. Do not turn these ranges into fixed targets without the generated per-import report.

## Delay-load policy

Delay-loaded dependencies require separate treatment from ordinary/direct imports.

A missing ordinary import is normally a process/module loader blocker. A missing delay import is a runtime-path risk and may be harmless only if the path is provably unreachable on XP.

For modern feature families such as WinRT, UI Automation, DWM, touch/pointer/rotation, AVRT, NCRYPT, newer IP Helper, newer SetupAPI or AppUserModelID integrations, first ask whether the XP build should enter that path at all. Prefer legacy behavior or disabled feature selection over emulating a modern subsystem merely because Firefox 153 contains a delay import for it.

A final XP acceptance audit must retain raw delay-import tables and prove the parser handles MSVC `dumpbin` delay-import formatting correctly; an empty parsed delay API list is not evidence when the parser failed to recognize the row format.

## Required CI redesign

Replace the current hand-curated `forbiddenApis` model with a deterministic compatibility inventory based on an explicit stock Windows XP SP3 x86 DLL/export manifest.

For every shipped PE, report separately:

- normal/direct imports;
- delay imports;
- missing system DLLs;
- required runtime vs optional/test-only PE classification.

Each missing dependency should receive one project disposition:

- `YY_COVERED`;
- `XP_NATIVE_REPLACEMENT`;
- `THIRD_PARTY_COMPAT`;
- `MUST_BE_ABSENT`;
- `CUSTOM_SHIM_REQUIRED`;
- `OPTIONAL_COMPONENT_DISABLED`;
- `TEST_ONLY_IGNORE`;
- `UNCLASSIFIED`.

Suggested generated reports:

- `xp-x32-missing-direct-imports.tsv`;
- `xp-x32-missing-delay-imports.tsv`;
- `xp-x32-missing-dlls.tsv`;
- `xp-x32-compat-classification.tsv`.

The hard acceptance gate for required startup/runtime PEs should eventually be **zero unresolved `UNCLASSIFIED` direct imports/missing DLLs**. It should not require every optional/test artifact in `dist/bin` to become XP-compatible.

## Decision rules for future debugging

When a physical XP or Win7 runtime failure exposes a new API/DLL:

1. bind the failure to the exact artifact, Actions run/job and source SHA;
2. identify the exact importing PE and whether the import is direct or delay-load;
3. identify the Firefox subsystem/caller;
4. classify the feature before choosing a fix;
5. prefer source/fallback or XP-native behavior where appropriate;
6. use a compatibility library only when its boundary remains bounded;
7. re-run the exact focused test and then the physical browser test;
8. update `TEST_LOG.md` and current project state when the blocker changes.

Do not debug XP by waiting for one loader/runtime failure at a time when the same build can generate the full inventory in advance. Physical runtime remains the final arbiter, but the import/classification report should make the likely sequence visible before the next multi-hour build.

## Separation from GOST TLS

All work in this document belongs to the Windows compatibility track.

A successful XP/Win7 build, loader pass, ordinary browsing pass, BCrypt compatibility DLL test, or YY-Thunks closure does **not** prove:

- MSSPI/CryptoPro GOST handshake behavior;
- GOST server verification;
- GOST client-certificate selection or mTLS;
- protected GOST application traffic.

Sandbox restoration, if ever pursued, is a separate x86 hardening milestone and is not required to claim that the browser follows the inherited r3dfox x86 compatibility baseline.

Those GOST properties remain separate exact-artifact runtime tests after the old-Windows browser itself is sufficiently stable.