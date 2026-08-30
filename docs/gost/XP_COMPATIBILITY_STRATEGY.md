# r3dfox GOST TLS — Windows XP compatibility strategy

Last updated: 2026-08-31

This document records the architectural policy for the Windows XP x86 compatibility track. It is intentionally separate from the GOST TLS runtime/handshake track: making Firefox/r3dfox start and browse on XP or Win7 does not prove any MSSPI/CryptoPro GOST behavior.

The goal is **not** to reproduce every Vista/7/8/10 API on Windows XP. The goal is to preserve useful Firefox behavior with the smallest maintainable compatibility surface, choosing an XP-native implementation, a bounded compatibility library, an intentional legacy fallback, a separately rebuilt dependency, or feature removal according to the semantics and ownership of each subsystem.

## Core policy

For every API or DLL that is absent on stock Windows XP SP3 x86, classify the dependency **before** writing compatibility code.

Preferred order:

1. **Remove the unsupported modern feature from the XP build when the feature itself has no useful XP meaning.** The dependency must become absent from the final PE rather than emulated.
2. **Replace the implementation with a real XP-native path when the useful operation exists on XP through older APIs.** Preserve the Firefox-facing contract, not the exact modern Windows call.
3. **Use an existing subsystem-level legacy backend when one replacement can remove a family of modern imports.** Prefer one maintainable XP implementation of a Firefox abstraction over dozens of API-name shims.
4. **Use YY-Thunks or another bounded compatibility layer for small, stable, unavoidable low-level Win32 gaps with known semantics.** Do not expand a narrow provider into a reconstructed modern Windows runtime.
5. **Allow a vetted third-party XP compatibility implementation when it provides a cleaner and more complete boundary than source rewrites.** It must pass license, provenance, ABI/export, security, packaging, and physical-XP runtime review before adoption.
6. **Write a project-specific shim only as a last resort**, when the behavior is required, no natural XP implementation exists, and no suitable maintained compatibility implementation is available.

A missing API count is therefore an **inventory**, not an implementation backlog. A successful YY coverage smoke means an API *can* be thunked; it does not mean that thunking it is the preferred project design.

## Inherited r3dfox x86 sandbox baseline

Official `Eclipse-Community/r3dfox` release `v153.0.3` explicitly states that the 32-bit build is built with `--disable-sandbox`. `Eclipse-Community/r3dfox#11` records the same policy decision: sandbox-enabled Vista x86 fails to create the expected multi-process browser, `MOZ_DISABLE_CONTENT_SANDBOX=1` mostly mitigates it, and the maintainer chose to ship x86 without the sandbox. The issue is closed `not_planned`.

Therefore the project treats **sandbox-disabled x86 as the inherited r3dfox release baseline**.

For the XP port:

- a sandbox-enabled Win7/Vista x86 pass is not a prerequisite for XP loader/import/source work;
- the normal XP product experiment uses build-time `--disable-sandbox`, not a runtime environment-variable workaround;
- historical sandbox-on RNG/`LowerToken` experiments remain optional hardening evidence only;
- restoring an XP/Vista/Win7 x86 restricted-token sandbox is a separate future security project.

This is a compatibility-baseline decision, not a claim that disabling sandbox is security-equivalent to a working sandbox.

## Current authoritative full-build import baseline

The current import-triage baseline is the sandbox-disabled full build:

- experiment branch: `agent/winrt-source-poc`;
- source-under-test: `1635d28360ee35d47c1d8237bcf8f5864cc1144f`;
- Actions run: `33310150314`;
- job: `99253613546`;
- workflow: `.github/workflows/gost-poc-build-xp-x32.yml`;
- diagnostics artifact: `9733280937`, SHA-256 `19da7173e51ad207358778d37caa23706408be24669d8a8b77b2e209259c7de7`;
- runtime artifact: `9733280458`, SHA-256 `0bfdd6643dfa9fdb4ebf9e90f610b0307ac60cce83b31845b5e040cb89feadd9`;
- package artifact: `9733280086`, SHA-256 `bc4ab405f49e6666e35ebd7e0b76c03fb5acbf8246adb22099a2f21eda0f0c9e`.

The full Firefox build, runtime staging, PE retargeting, packaging and artifact upload all succeeded. The run is red only at `GATE - Audit XP x32 PE floor and direct imports`.

The manually curated gate reports:

- 103 violation rows;
- 101 API rows + 2 DLL rows;
- 26 unique forbidden API names;
- 15 affected PE files;
- `xul.dll`: 19 API rows + direct `bcrypt.dll`;
- `mozglue.dll`: 11 API rows + direct `bcrypt.dll`.

The two DLL-level violations are the `bcrypt.dll` dependencies in `xul.dll` and `mozglue.dll`.

### Important change from the old physical-XP blocker

The earlier physical XP artifact from run `33141004769` failed before UI startup on hard `KERNEL32!CloseThreadpoolWork` resolution.

In the complete direct-import diagnostics for run `33310150314`, `CloseThreadpoolWork` is **absent**. It is also absent from the raw per-PE import tables generated by that run.

Therefore the old `CloseThreadpoolWork` loader blocker is no longer an import blocker in the current artifact. This is binary evidence only: the current artifact still requires a physical XP startup test before the blocker can be called runtime-closed. The next physical XP run may expose a different loader/runtime dependency.

## Current curated PE distribution

The 103 current gate rows are not one homogeneous Firefox problem.

### Core browser PEs

`xul.dll` contributes 19 API violations plus `bcrypt.dll`:

- `AcquireSRWLockExclusive`;
- `CancelIoEx`;
- `CompareStringOrdinal`;
- `GetCurrentProcessorNumber`;
- `GetFileInformationByHandleEx`;
- `GetFinalPathNameByHandleW`;
- `GetLocaleInfoEx`;
- `GetTickCount64`;
- `InitializeConditionVariable`;
- `InitializeCriticalSectionEx`;
- `InitializeSRWLock`;
- `LCIDToLocaleName`;
- `LocaleNameToLCID`;
- `ReleaseSRWLockExclusive`;
- `SetFileInformationByHandle`;
- `SleepConditionVariableCS`;
- `SleepConditionVariableSRW`;
- `WakeAllConditionVariable`;
- `WakeConditionVariable`;
- plus direct `bcrypt.dll`.

`mozglue.dll` contributes 11 API violations plus `bcrypt.dll`:

- `AcquireSRWLockExclusive`;
- `AcquireSRWLockShared`;
- `GetTickCount64`;
- `InitializeConditionVariable`;
- `InitializeCriticalSectionEx`;
- `ReleaseSRWLockExclusive`;
- `ReleaseSRWLockShared`;
- `SleepConditionVariableCS`;
- `SleepConditionVariableSRW`;
- `WakeAllConditionVariable`;
- `WakeConditionVariable`;
- plus direct `bcrypt.dll`.

`r3dfox.exe` and `plugin-container.exe` each currently contribute the same four synchronization imports:

- `AcquireSRWLockExclusive`;
- `ReleaseSRWLockExclusive`;
- `SleepConditionVariableSRW`;
- `WakeAllConditionVariable`.

### Other shipped/feature PEs that require separate ownership decisions

The current broad `dist/bin` audit also reports post-XP imports in:

- `libGLESv2.dll`;
- `mozavcodec.dll`;
- `mozavutil.dll`;
- `gkcodecs.dll`;
- `mozinference.dll`;
- `d3dcompiler_47.dll`;
- `gmp-clearkey/0.1/clearkey.dll`.

These cannot automatically be treated as `xul.dll` linker problems. A compatibility library linked only into `xul.dll` does not rewrite the import table of a separately linked DLL.

For every separately linked PE, choose explicitly among:

- rebuild that PE with the bounded compatibility layer;
- select a legacy-compatible source/configuration/version;
- provide a component-specific XP-native implementation;
- remove/disable the optional component on XP if its functionality is not required;
- replace the component with a vetted compatible dependency.

### `d3dcompiler_47.dll`: prefer a legacy-compatible build of the same ABI

The current Firefox package from run `33310150314` contains Microsoft `D3DCompiler_47` version `10.0.26100.7705`, SHA-256 `38078c09a4980c0d234ede9b36b11f59517be3248524ca9aa031312a5a2652b7`. Its XP gate rows are:

- `FlsAlloc`;
- `FlsFree`;
- `FlsGetValue`;
- `FlsSetValue`;
- `InitializeCriticalSectionEx`.

A `d3dcompiler_47.dll` taken from a Firefox installation that is known to run on the user's physical Windows XP system was inspected separately. It is an unpatched Microsoft `D3DCompiler_47` version `10.0.14393.33`, SHA-256 `3a010ee7186086a7f77b6aec3644e05f8495a84895b90572cab8d4f14efa088e`. Its external D3DCompiler ABI is the same 29-export `D3DCompiler_47` surface used by the current build, while its internal Windows dependencies use older XP-era mechanisms and do **not** import the five Vista+ functions above.

The absence of `InitializeCriticalSectionEx`, `Fls*`, or `VirtualProtect` from the legacy DLL is not an ABI deficiency for Firefox/ANGLE: those are internal Windows dependencies of a particular D3DCompiler implementation, not exports that Firefox expects from `d3dcompiler_47.dll`. `VirtualProtect` is itself available on XP and was never an XP blocker in this component.

The preferred remediation is therefore **legacy component-version selection**, not YY interposition and not binary import redirection:

- keep the DLL name and D3DCompiler 47 ABI unchanged;
- obtain the pinned legacy Microsoft DLL from a reproducible trusted source;
- verify exact version and source SHA before staging;
- replace only the build-produced `dist/bin/d3dcompiler_47.dll`;
- retarget its PE subsystem header to 5.1 together with the rest of the XP package;
- verify the five forbidden imports remain absent after retargeting and packaging;
- record the post-retarget hash because `editbin /SUBSYSTEM:...,5.01` legitimately changes the original file hash;
- require final import-audit and physical-XP browser validation before adopting the substitution as closed.

Reproducible provenance for the exact legacy binary is now confirmed. Setup run `33324633438`, job `99292485878`, source `53cb94bf7aa5ae6696c666bcf63a600c7ae11840` extracted `core/d3dcompiler_47.dll` from the official Mozilla Firefox `52.2.1esr` x86 installer on `archive.mozilla.org` and validated the exact SHA-256 `3a010ee7...`. That run then failed only when its `GITHUB_TOKEN` attempted to push a change under `.github/workflows`; GitHub rejected the self-modifying workflow because the token lacked workflow-update permission. This setup failure did not invalidate the binary provenance/hash result.

Renderer run `33325597050`, job `99295039973`, source `fcbf71dc5d5ab70925bcaa34e62adf08d4768a3b` then completed successfully and generated the verified full-build workflow change without attempting a forbidden self-update. The actual Firefox source-under-test for the live substitution experiment is commit `0096e6522475c95a52fad4413d43258e30cf6e8a`, which started full build run `33325676035`, job `99295249758`. At the time of this documentation update that run is still in progress: the pinned legacy-D3DCompiler preparation step has passed, and the full Firefox build is running. No package/import/runtime conclusion may be drawn until that exact run completes. A later workflow-only commit `ab700aac14ae9812c35c6594655c843c9d40bb07` merely restored the workflow to `workflow_dispatch`-only and is **not** the source-under-test for run `33325676035`.

This component is therefore provisionally classified as `LEGACY_COMPONENT_VERSION`; its five current gate rows should not be assigned to the production YY provider while the exact legacy-version A/B is active.

### Test/developer/fake PEs are not product blockers by default

The current broad audit also includes:

- `gmp-fake/1.0/fake.dll`;
- `gmp-fakeopenh264/1.0/fakeopenh264.dll`;
- `logalloc-replay.exe`;
- `xpcshell.exe`.

These must first be classified as test/developer/runtime artifacts. Do not spend compatibility effort on them merely to make the broad `dist/bin` number green. The final XP product gate must distinguish required startup/runtime PEs from optional and test-only artifacts.

## Caller-level classification before YY

The current 26 unique gate APIs must **not** be copied wholesale into a production YY provider.

The required sequence for every surviving core-browser import is:

1. identify exact importing PE;
2. identify exact Firefox/toolchain/third-party caller or owning abstraction;
3. determine the semantics actually required by that caller;
4. check whether the feature can be absent on XP;
5. check whether an XP-native API or existing legacy backend preserves those semantics;
6. only then decide whether YY or another compatibility layer is justified.

### Strong XP-native/source-fallback candidates pending caller proof

The following current `xul.dll` imports should be investigated for older XP mechanisms **before** assigning them to YY:

- `CancelIoEx` — evaluate whether the concrete caller can use XP `CancelIo` semantics or needs a different source design;
- `CompareStringOrdinal` — evaluate a source-level ordinal-comparison fallback;
- `GetCurrentProcessorNumber` — determine whether the caller merely uses a modern scheduling/CPU optimization that can degrade safely on XP;
- `GetFileInformationByHandleEx` — determine the requested information class and whether `GetFileInformationByHandle`, an older file API, or a narrow NT query is the correct semantic replacement;
- `GetFinalPathNameByHandleW` — evaluate legacy path-resolution behavior at the owning abstraction;
- `GetLocaleInfoEx`, `LCIDToLocaleName`, `LocaleNameToLCID` — prefer an XP LCID-based NLS path where possible;
- `GetTickCount64` — prefer an existing Mozilla time abstraction or an XP-native `GetTickCount`-based implementation with correct wrap handling when that preserves the caller contract;
- `SetFileInformationByHandle` — classify by the exact information class/action before choosing an older Win32 or NT mechanism;
- `InitializeCriticalSectionEx` — check whether the owning code can use XP `InitializeCriticalSection`/`InitializeCriticalSectionAndSpinCount` semantics.

These are **candidate directions, not yet proven replacements**. Caller-level source analysis is required before implementation.

### Synchronization family: investigate the abstraction boundary first

A large fraction of the remaining rows are SRW/condition-variable functions:

- `AcquireSRWLockExclusive` / `AcquireSRWLockShared`;
- `ReleaseSRWLockExclusive` / `ReleaseSRWLockShared`;
- `InitializeSRWLock`;
- `InitializeConditionVariable`;
- `SleepConditionVariableCS` / `SleepConditionVariableSRW`;
- `WakeAllConditionVariable` / `WakeConditionVariable`;
- `TryAcquireSRWLockExclusive` in some non-core/test PEs.

These appear across multiple core and separately linked PEs. Do **not** assume that one static YY archive linked into `xul.dll` solves the family everywhere.

First determine ownership:

- Mozilla-owned synchronization abstraction -> prefer one XP-native backend if a bounded backend can preserve the contract;
- Rust libstd/MSVC STL/toolchain surface that cannot reasonably be rewritten -> narrow YY is a strong candidate;
- separately linked third-party DLL -> solve at that DLL's own build/dependency boundary.

A single XP synchronization backend may remove several imports at once if the calls originate from a common owned abstraction. That is preferable to API-by-API thunking, but remains a hypothesis until exact callers are identified.

## YY-Thunks policy and the broad coverage smoke

YY-Thunks 1.2.2 remains a valid tool for bounded old-Windows Win32 gaps. The representative msvcr14x/Rust/YY XP x86 workload at source `d78137a931145af877dc458b01e494ad0467723d`, run `33138244191`, job `98743029100`, passed on physical XP SP3 x86.

A later **coverage-only** smoke intentionally tested an upper bound:

- branch: `agent/winrt-source-poc`;
- source: `39ce8453be32557dfb709bce8ee412c16f78a72f`;
- workflow: `.github/workflows/xp-required-yy-provider-smoke.yml`;
- run: `33316988353`;
- job: `99272141403`;
- result: success.

That smoke selected all 26 currently observed forbidden API names plus previously proven Rust/libstd compatibility entries into a physically narrow YY provider, preserved `/MD` msvcr14x/Rust coexistence, linked the representative probe, passed PE 5.01 and selected-import gates, and ran on the Windows 2022 runner.

**Interpretation:** this proves that YY 1.2.2 can technically cover the observed API-name set at representative-link scale. It does **not** authorize copying the full set into the Firefox production link. The smoke is an upper-bound capability/reference result only.

The production narrow provider must be generated **after caller-level classification** and should contain only APIs whose semantics are genuinely better handled by YY than by feature removal, XP-native source fallback, an owned subsystem backend, or separate-component rebuild.

Do not reintroduce full YY `kernel32.lib` interposition. Keep the physical narrow-provider invariant.

## WinRT: remove/fallback, do not emulate

The physical Win7 failure from source `982d6529a707c6feecad97c725feed8a3cd21c81`, run `33141004769`, job `98751650853`, runtime artifact `9676549576`, proved a parent-process crash from `xul.dll` delay-loading the missing WinRT API-set and reaching `RoGetActivationFactory`.

The broad YY WinRT expansion line is retired. The experimental branch `agent/winrt-source-poc` removes or replaces nonessential WinRT consumers at the feature boundary.

For XP, WinRT activation/HSTRING APIs are `MUST_BE_ABSENT`, not `YY_COVERED`.

## OS RNG: preserve the operation with a real XP implementation

The `agent/legacy-rng-poc` line remains the model for source-level semantic replacement. `mozilla::GenerateRandomBytesFromOS()` was experimentally changed from the modern path to real XP-compatible CryptoAPI:

`CryptAcquireContextW -> CryptGenRandom -> CryptReleaseContext`.

Its sandbox-enabled Win7 test did not solve the sandbox crash, but sandbox restoration is no longer an XP acceptance gate. The important architectural lesson remains: when XP already provides the required operation, prefer its native mechanism over emulating a newer API name.

## BCrypt boundary

`bcrypt.dll` remains a direct dependency of both `xul.dll` and `mozglue.dll` in run `33310150314`. Sandbox removal did not remove that dependency.

BCrypt is therefore a separate compatibility boundary, not a sandbox or general YY problem.

The previously inspected SourceForge `bcrypt-XP` archive is not acceptable as a shipped project dependency in its current form because it contains opaque prebuilt crypto DLLs without corresponding source/provenance material in the archive and brings additional modern CRT/API-set dependencies.

A cleaner direction is an open, reproducible XP-compatible BCrypt facade built from source and implementing only the subset actually required by the final Firefox runtime. Mbed TLS is one possible cryptographic backend for hashing/other primitives; OS RNG should prefer XP-native CryptoAPI where appropriate. Such a facade must not replace NSS or the MSSPI GOST TLS stack.

Before adoption require exact export inventory, ABI/status-code compatibility, licensing/provenance review, deterministic x86 build, dependency audit, focused API tests, packaging proof, and physical XP browser runtime validation.

## Expanded XP SP3 inventory remains broader than the hand gate

The workflow's current `forbiddenApis` list is a regression gate, not an exhaustive XP SP3 export manifest.

An earlier broader comparison estimated approximately:

- 57 unique direct imported functions absent from stock XP SP3 in `xul.dll`;
- 73 across the whole scanned `dist/bin` set.

Those numbers predate the current `--disable-sandbox` build and must be regenerated from diagnostics `9733280937` before they are used for planning. The sandbox-disabled build already proved that the full direct-import surface can shrink even when the curated `xul.dll` gate count stays unchanged.

The old estimate is therefore historical planning evidence, not the current target count.

## Remediation classes

Every missing dependency receives one disposition:

### `MUST_BE_ABSENT`

Modern feature/path has no useful XP meaning. Remove/select a legacy path so the dependency is absent from the required PE. WinRT is the canonical example.

### `XP_NATIVE_REPLACEMENT`

The useful operation exists on XP through older Win32/NT APIs or an existing legacy implementation. Preserve caller semantics at source level rather than cloning the newer API surface.

### `OWNED_LEGACY_BACKEND`

Several imports belong to one project-owned abstraction. Implement/select one XP backend for that abstraction when it is cleaner and semantically safer than multiple thunk aliases.

### `YY_COVERED`

Use only for bounded, unavoidable low-level Win32 gaps after caller analysis. Availability of a YY implementation symbol or a passing coverage smoke is necessary evidence for feasibility, not sufficient evidence for architectural selection.

### `THIRD_PARTY_COMPAT`

Use a source-available, license/provenance-reviewed compatibility implementation when it provides a clean independently testable boundary.

### `LEGACY_COMPONENT_VERSION`

A separately supplied component keeps the same public ABI/name, but an older trusted version has a strictly more compatible Windows dependency surface. Pin exact provenance/version/hash, verify export compatibility, and validate the exact staged binary through import audit and physical XP runtime. `d3dcompiler_47.dll` is the current canonical experiment for this class.

### `COMPONENT_REBUILD`

A separately linked DLL owns its own incompatible imports. Rebuild/select/replace that component; do not pretend a `xul.dll` linker change modifies another PE's import table.

### `OPTIONAL_COMPONENT_DISABLED`

Optional feature/component is not worth carrying on XP. Remove it from the XP configuration/package.

### `TEST_ONLY_IGNORE`

Test/developer/fake artifact is not required by the shipped browser. Exclude it from the product compatibility gate while retaining diagnostic visibility.

### `CUSTOM_SHIM_REQUIRED`

Reserve for the residual set where required semantics cannot be obtained by any cleaner mechanism.

## Delay-load policy

Delay-loaded dependencies require separate treatment from ordinary/direct imports.

A missing ordinary import is normally a process/module loader blocker. A missing delay import is a runtime-path risk and may be harmless only if the path is provably unreachable on XP.

For modern feature families such as WinRT, UI Automation, DWM, touch/pointer/rotation, AVRT, NCRYPT, newer IP Helper, newer SetupAPI or AppUserModelID integrations, first ask whether the XP build should enter that path at all. Prefer legacy behavior or disabled feature selection over emulating a modern subsystem merely because Firefox 153 contains a delay import for it.

The final XP acceptance audit must retain raw delay-import tables and prove the parser handles MSVC `dumpbin` delay-import formatting correctly.

## Required CI redesign

Replace the hand-curated `forbiddenApis` model with a deterministic compatibility inventory based on an explicit stock Windows XP SP3 x86 DLL/export manifest.

For every shipped PE, report separately:

- normal/direct imports;
- delay imports;
- missing system DLLs;
- PE role: required startup/runtime, optional feature, developer utility, or test/fake-only;
- owning subsystem/caller when known;
- selected remediation class.

Suggested dispositions:

- `MUST_BE_ABSENT`;
- `XP_NATIVE_REPLACEMENT`;
- `OWNED_LEGACY_BACKEND`;
- `YY_COVERED`;
- `THIRD_PARTY_COMPAT`;
- `LEGACY_COMPONENT_VERSION`;
- `COMPONENT_REBUILD`;
- `OPTIONAL_COMPONENT_DISABLED`;
- `TEST_ONLY_IGNORE`;
- `CUSTOM_SHIM_REQUIRED`;
- `UNCLASSIFIED`.

Suggested generated reports:

- `xp-x32-missing-direct-imports.tsv`;
- `xp-x32-missing-delay-imports.tsv`;
- `xp-x32-missing-dlls.tsv`;
- `xp-x32-compat-classification.tsv`.

The hard acceptance gate for required startup/runtime PEs should eventually be zero unresolved `UNCLASSIFIED` direct imports/missing DLLs. It should not require every optional/test artifact in `dist/bin` to become XP-compatible.

## Immediate next sequence

1. Keep run `33310150314` / diagnostics `9733280937` as the last completed authoritative full-build import baseline until the current legacy-D3DCompiler A/B completes.
2. Complete exact run `33325676035` / job `99295249758` / source `0096e6522475c95a52fad4413d43258e30cf6e8a` and compare its final `d3dcompiler_47.dll` plus full import audit against run `33310150314`. Do not count the renderer/setup runs as Firefox build evidence.
3. Perform caller/owner classification for the `xul.dll`, `mozglue.dll`, `r3dfox.exe`, and `plugin-container.exe` gaps before expanding the production YY provider.
4. In parallel classify the remaining separately linked DLLs as required/optional and decide rebuild/legacy-version/disablement per component; keep `d3dcompiler_47.dll` on the `LEGACY_COMPONENT_VERSION` path unless run `33325676035` disproves it.
5. Regenerate the broader stock-XP export comparison from the sandbox-disabled diagnostics rather than using the old 57/73 estimates as current numbers.
6. Build the **smallest resulting** production compatibility provider/backends after classification.
7. Rebuild Firefox only after the focused source/YY/component smokes prove those choices.
8. Run the exact new runtime artifact on physical XP. Because `CloseThreadpoolWork` is absent from the current direct-import inventory, expect the physical test either to pass that old loader boundary or expose the next concrete blocker; do not claim closure before the runtime test.
9. Keep GOST TLS runtime validation as a later separate exact-artifact milestone.

## Decision rules for future debugging

When a physical XP or Win7 runtime failure exposes a new API/DLL:

1. bind the failure to exact artifact, Actions run/job and source SHA;
2. identify the exact importing PE and direct vs delay-load status;
3. identify the owning subsystem/caller;
4. classify feature semantics before choosing a fix;
5. prefer removal, XP-native behavior or an owned legacy backend where appropriate;
6. use YY only when the boundary remains bounded and caller semantics justify it;
7. solve separately linked DLLs at their own build/dependency boundary;
8. re-run the focused test and then the physical browser test;
9. update `TEST_LOG.md`, `PROJECT_STATE.md`, and `TODO.md` when the blocker or next experiment changes.

Do not debug XP solely by waiting for one loader failure at a time when the same build can generate the complete likely inventory in advance. Physical runtime remains the final arbiter.

## Separation from GOST TLS

All work in this document belongs to the Windows compatibility track.

A successful XP/Win7 build, loader pass, ordinary browsing pass, BCrypt facade test, component rebuild, or YY-Thunks closure does **not** prove MSSPI/CryptoPro GOST handshake behavior, GOST server verification, GOST client-certificate selection/mTLS, or protected GOST application traffic.

Those remain separate exact-artifact runtime tests after the old-Windows browser itself is sufficiently stable.