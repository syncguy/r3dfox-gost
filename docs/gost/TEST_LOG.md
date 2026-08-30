# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-30_2026-08-30.md`](./TEST_LOG_2026-08-30_2026-08-30.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); the Windows XP compatibility architecture and import-triage policy are in [`XP_COMPATIBILITY_STRATEGY.md`](./XP_COMPATIBILITY_STRATEGY.md); the source-level WinRT experiment is in [`WINRT_SOURCE_POC.md`](./WINRT_SOURCE_POC.md); formally closed milestones are in [`DONE.md`](./DONE.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-08-30 — Build-time `--disable-sandbox` removes real x86 import baggage but leaves the curated `xul.dll` XP blocker set unchanged

**Track:** Windows XP x86 compatibility / compile-time sandbox removal and PE import inventory  
**Experimental branch:** `agent/winrt-source-poc`  
**Sandbox-enabled comparison source:** `4c982371a53a5d03cfcfe1d4107d1a40cc99c3f9`  
**Sandbox-enabled comparison run/job:** `33264392080` / `99131766920`  
**Sandbox-enabled diagnostics artifact:** `9719920434`  
**Sandbox-disabled source-under-test:** `1635d28360ee35d47c1d8237bcf8f5864cc1144f`  
**Sandbox-disabled run/job:** `33310150314` / `99253613546`  
**Workflow:** `.github/workflows/gost-poc-build-xp-x32.yml`  
**Configuration change:** `ac_add_options --disable-sandbox`

### CI result

The sandbox-disabled build completed the actual Firefox build and packaging stages successfully. The overall run is red only because the post-build `GATE - Audit XP x32 PE floor and direct imports` still finds unresolved XP-incompatible imports.

Successful stages include:

- full release r3dfox XP x32 build;
- runtime DLL staging;
- PE subsystem retargeting;
- package creation;
- physical-test runtime archive creation;
- package/runtime/diagnostics uploads.

Sandbox-disabled artifacts:

- package `9733280086` (`r3dfox-gost-xp-x32-package`), digest SHA-256 `bc4ab405f49e6666e35ebd7e0b76c03fb5acbf8246adb22099a2f21eda0f0c9e`;
- runtime `9733280458` (`r3dfox-gost-xp-x32-runtime`), digest SHA-256 `0bfdd6643dfa9fdb4ebf9e90f610b0307ac60cce83b31845b5e040cb89feadd9`;
- diagnostics `9733280937` (`r3dfox-gost-xp-x32-diagnostics`), digest SHA-256 `19da7173e51ad207358778d37caa23706408be24669d8a8b77b2e209259c7de7`.

### Curated forbidden-import gate A/B

Baseline `4c982371...` / run `33264392080`:

- 112 violation rows;
- 110 API rows + 2 DLL rows;
- 27 unique forbidden API names;
- 15 affected PE files;
- `xul.dll`: 19 forbidden API rows + `bcrypt.dll`.

Sandbox-disabled `1635d283...` / run `33310150314`:

- 103 violation rows;
- 101 API rows + 2 DLL rows;
- 26 unique forbidden API names;
- 15 affected PE files;
- `xul.dll`: still exactly the same 19 forbidden API rows + `bcrypt.dll`.

The A/B delta is exactly 9 removed curated rows and zero added rows. The removed rows are the same three APIs in each of `r3dfox.exe`, `plugin-container.exe`, and `xpcshell.exe`:

- `GetCurrentProcessorNumber`;
- `GetUserDefaultLocaleName`;
- `InitializeCriticalSectionEx`.

`GetUserDefaultLocaleName` disappears from the complete direct-import inventory entirely in the sandbox-disabled build. `GetCurrentProcessorNumber` and `InitializeCriticalSectionEx` remain imported elsewhere, including `xul.dll`, so they remain part of the XP compatibility inventory.

### Full `xul.dll` direct-import delta

The normalized direct-import inventory for `xul.dll` changes from 18 DLL / 1615 API-symbol rows to 18 DLL / 1603 API-symbol rows. No direct DLL dependency is removed from `xul.dll`, but 12 function imports disappear and no new function import appears:

- `BuildTrusteeWithSidW`;
- `DuplicateToken`;
- `GetAce`;
- `GetModuleFileNameA`;
- `GetSecurityInfo`;
- `GetSystemWindowsDirectoryW`;
- `NtQueryInformationProcess`;
- `ReadProcessMemory`;
- `RevertToSelf`;
- `RtlDosPathNameToNtPathName_U_WithStatus`;
- `SetSecurityInfo`;
- `SetThreadToken`.

This is direct binary evidence that build-time `--disable-sandbox` really removes Windows Chromium sandbox/broker/target code from the linked browser rather than merely changing runtime behavior. It also removes `RtlDosPathNameToNtPathName_U_WithStatus`, one of the broader XP-inventory functions previously not found in the narrow YY implementation-symbol catalog.

### What did not change

The current curated `xul.dll` XP violations are unchanged:

`AcquireSRWLockExclusive`, `CancelIoEx`, `CompareStringOrdinal`, `GetCurrentProcessorNumber`, `GetFileInformationByHandleEx`, `GetFinalPathNameByHandleW`, `GetLocaleInfoEx`, `GetTickCount64`, `InitializeConditionVariable`, `InitializeCriticalSectionEx`, `InitializeSRWLock`, `LCIDToLocaleName`, `LocaleNameToLCID`, `ReleaseSRWLockExclusive`, `SetFileInformationByHandle`, `SleepConditionVariableCS`, `SleepConditionVariableSRW`, `WakeAllConditionVariable`, `WakeConditionVariable`, plus direct `bcrypt.dll`.

`bcrypt.dll` remains a direct dependency of both `mozglue.dll` and `xul.dll`; `BCryptGenRandom` remains present in the direct-import inventory for both. Therefore the BCrypt compatibility problem is independent of the process sandbox removal.

The source-level WinRT PoC already had no direct `api-ms-win-core-winrt-*` import rows in this diagnostic inventory before this A/B, so this experiment does not establish a new WinRT result. Delay-load declarations remain a separate source/linker concern.

### Conclusion

Build-time sandbox removal is still the correct inherited r3dfox x86 baseline and it measurably reduces the legacy-Windows import surface. However, it does **not** solve the main remaining `xul.dll` compatibility inventory: the current hand-curated xul forbidden set is unchanged.

The result strengthens the existing strategy rather than changing it:

- keep `--disable-sandbox` for the XP/x86 product path unless sandbox restoration is explicitly reprioritized;
- stop spending XP critical-path effort on modern sandbox implementation details;
- continue classifying the remaining non-sandbox `xul.dll` imports by XP-native fallback, bounded compatibility layer, vetted third-party implementation, or source-level feature removal;
- do not infer from the unchanged curated xul set that sandbox removal had no binary effect: the full direct-import diff proves 12 xul functions and substantial executable-side sandbox baggage were removed;
- improve the future XP import gate toward a stock-XP export manifest, because the curated forbidden list does not include several imports that this experiment demonstrably removed.

Status: completed A/B experiment; confirms sandbox-disabled x86 baseline and narrows the remaining XP import work to non-sandbox dependencies; no GOST TLS conclusion follows.

---

## 2026-08-30 — Current XP import set reclassified caller-first; broad YY smoke is coverage evidence only

**Track:** Windows XP x86 compatibility / import ownership and remediation classification  
**Authoritative full-build source:** `1635d28360ee35d47c1d8237bcf8f5864cc1144f`  
**Full-build run/job:** `33310150314` / `99253613546`  
**Diagnostics artifact:** `9733280937`, SHA-256 `19da7173e51ad207358778d37caa23706408be24669d8a8b77b2e209259c7de7`  
**Coverage-smoke source:** `39ce8453be32557dfb709bce8ee412c16f78a72f`  
**Coverage-smoke run/job:** `33316988353` / `99272141403`  
**Coverage-smoke workflow:** `.github/workflows/xp-required-yy-provider-smoke.yml`  
**Coverage-smoke result:** success

### New binary-level finding: old `CloseThreadpoolWork` blocker is absent

The old physical-XP artifact from run `33141004769` failed before UI startup on hard `KERNEL32!CloseThreadpoolWork` resolution.

The complete direct-import table and raw per-PE import diagnostics from run `33310150314` contain **no `CloseThreadpoolWork` import**. Thus that specific loader dependency has disappeared from the current sandbox-disabled/WinRT-source build.

This is not yet a physical-XP PASS. It means the next exact physical XP test should use the new runtime artifact `9733280458`; it may pass the old loader boundary or expose the next concrete blocker.

### Current gate distribution is component-specific

The 103 curated violation rows are distributed across 15 PEs and must not be treated as one `xul.dll`/YY problem.

Core browser surface:

- `xul.dll`: 19 API rows + `bcrypt.dll`;
- `mozglue.dll`: 11 API rows + `bcrypt.dll`;
- `r3dfox.exe`: 4 synchronization API rows;
- `plugin-container.exe`: the same 4 synchronization API rows.

Other shipped/feature PEs in the broad audit include `libGLESv2.dll`, `mozavcodec.dll`, `mozavutil.dll`, `gkcodecs.dll`, `mozinference.dll`, `d3dcompiler_47.dll`, and `gmp-clearkey/0.1/clearkey.dll`.

Test/developer/fake artifacts also contribute rows: `gmp-fake/1.0/fake.dll`, `gmp-fakeopenh264/1.0/fakeopenh264.dll`, `logalloc-replay.exe`, and `xpcshell.exe`. These are not automatic product-runtime blockers.

`d3dcompiler_47.dll` demonstrates why PE ownership matters: it directly imports `FlsAlloc`, `FlsFree`, `FlsGetValue`, `FlsSetValue`, and `InitializeCriticalSectionEx`. A YY archive added only to the `xul.dll` link cannot change a separately linked DLL's import table.

### Corrected remediation policy

Do **not** map all 26 unique current forbidden API names directly to YY.

For every surviving core-browser import, first identify the exact caller/owning abstraction and required semantics. Prefer, in order:

1. feature/path removal when the modern capability has no XP value;
2. XP-native source fallback when an older Windows mechanism preserves the operation;
3. one owned XP legacy backend when several imports belong to one Firefox abstraction;
4. bounded YY only for unavoidable stable low-level gaps;
5. component-specific rebuild/replacement for separately linked DLLs;
6. vetted third-party implementation for clean independent boundaries such as a future open BCrypt facade;
7. custom project shim only for the residual set.

Current `xul.dll` imports that require XP-native/source analysis before assigning YY include `CancelIoEx`, `CompareStringOrdinal`, `GetCurrentProcessorNumber`, `GetFileInformationByHandleEx`, `GetFinalPathNameByHandleW`, `GetLocaleInfoEx`, `LCIDToLocaleName`, `LocaleNameToLCID`, `GetTickCount64`, `SetFileInformationByHandle`, and `InitializeCriticalSectionEx`.

These are candidate directions only; exact caller semantics still need source analysis.

The SRW/condition-variable family appears across several PEs. First determine whether each occurrence is owned by Mozilla abstractions, Rust/MSVC/toolchain code, or a separately linked dependency. A Mozilla-owned family may be better served by one XP synchronization backend; unavoidable Rust/toolchain surfaces remain strong YY candidates; separately linked DLLs must be fixed at their own boundary.

### Interpretation of run `33316988353`

The broad required-API smoke succeeded after selecting all 26 currently observed forbidden API names plus the previously proven Rust/libstd entries into a physically narrow YY provider. It preserved the representative msvcr14x `/MD` + Rust coexistence model, linked successfully, passed its XP PE/import gates, and ran on the Windows 2022 runner.

This result is intentionally reclassified as **upper-bound YY capability evidence**:

- it proves YY 1.2.2 can technically cover the current API-name set at representative-link scale;
- it does not prove all those APIs should be thunked in Firefox;
- it does not authorize injecting the expanded provider into the full Firefox build;
- production YY membership must be derived only after caller-level classification.

The full YY `kernel32.lib` remains prohibited; any future production provider must stay physically narrow.

### BCrypt remains independent

`bcrypt.dll` remains a direct dependency of both `xul.dll` and `mozglue.dll`. It was unaffected by `--disable-sandbox` and should not be folded into the general YY decision. Continue treating BCrypt as an independently reviewable XP compatibility facade/source-backend problem.

### Next experiment order

1. Use run `33310150314` / diagnostics `9733280937` as the current full-build baseline.
2. Classify exact callers/owners for `xul.dll`, `mozglue.dll`, `r3dfox.exe`, and `plugin-container.exe` before changing the production YY provider.
3. Classify each separately linked DLL as required/optional and choose rebuild/legacy-version/disablement independently.
4. Regenerate the broader stock-XP export comparison from the sandbox-disabled diagnostics; the old ~57/~73 estimates are no longer current planning counts.
5. Build the smallest resulting compatibility backends/provider and prove them in focused smoke tests before another multi-hour Firefox build.
6. Run the resulting exact artifact on physical XP; `CloseThreadpoolWork` is no longer expected to be the first direct-import loader blocker, but only runtime can establish the next actual boundary.

Status: current architectural correction and import-triage baseline; the broad YY smoke is successful but deliberately non-authoritative for production membership; no GOST TLS conclusion follows.
