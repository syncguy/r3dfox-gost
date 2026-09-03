# Windows XP x86 residual import remediation

Last updated: 2026-09-03

This document records the current residual-import adaptation plan for the Windows XP SP3 x86 browser track. It is subordinate to `XP_BUILD_CONTRACT.md` and independent of GOST TLS runtime/handshake evidence.

The purpose is not to convert every post-XP API name into a YY-Thunks entry. For every residual import, first identify the importing PE and the owning source/dependency, then choose the narrowest maintainable remediation: source removal, XP-native fallback, legacy backend/component replacement, bounded YY-Thunks provider, or a project-specific shim only when the other options do not fit.

## Evidence identity for this review

The import review in this document is bound to the latest completed full XP x32 diagnostics available during the 2026-09-03 review:

- experiment branch: `agent/winrt-source-poc`;
- source-under-test: `17cdb459ec4f115a209fd50ac225cf867b9f3a2f`;
- workflow: `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run: `33638897692`, attempt `1`;
- job: `100276666021`;
- package artifact: `9855749298`;
- diagnostics artifact: `9855751471`;
- diagnostics artifact digest: `sha256:bce0bbdbc778b0114b9d33e670a9bf687e4699cfda7353efebc6b92650f03eed`.

The full release x86 Firefox compile/link and `mach package` succeeded in this run, but the run failed later at `GATE - Verify msvcr14x CRT survived portable packaging`. Because that gate is fail-fast, the final broad whole-package XP PE/import audit did **not** execute. Therefore the inventory below is a confirmed residual set from the diagnostics that do exist; it must not be described as the complete final package inventory.

## Important correction to the earlier planning model

The current early import gates are based on selected API lists. They prove that a known selected import disappeared, but they cannot prove that no other post-XP imports remain. `InitOnceExecuteOnce` demonstrated this failure mode: the project had already closed a ten-API SRW/condition-variable capability set, but `InitOnceExecuteOnce` was not in that selected set and remained a hard import in two core PEs.

Future acceptance must therefore be inventory-driven rather than name-list-driven:

1. enumerate ordinary/direct imports for every required product PE;
2. enumerate delay-load imports separately;
3. classify imported DLLs and APIs by XP availability;
4. associate each residual dependency with an exact importing PE and owning source/dependency;
5. classify every residual item as `YY_SUPPORTED`, `SOURCE_REMEDIATION`, `LEGACY_COMPONENT`, `PROJECT_SHIM`, `APP_LOCAL_REPLACEMENT`, `OPTIONAL_FEATURE`, or `UNRESOLVED`;
6. fail the final product gate on every unclassified or unresolved required hard dependency.

A curated `$forbiddenApis` list remains useful as a fail-fast regression gate for already-known families, but it is not an exhaustive XP compatibility proof.

## Controlled msvcr14x outputs

`ucrtbase.dll` and `msvcp140.dll` in this project are not opaque host redistributables. They are controlled build outputs from the pinned `Chuyu-Team/msvcr14x` source used by the XP workflow.

For the exact diagnostics artifact `9855751471`, the reviewed import tables for `ucrtbase.dll` and `msvcp140.dll` do not contain the residual API set documented below, including `InitOnceExecuteOnce`. This does **not** remove them from future import auditing. Every fresh msvcr14x build must continue to pass the full dependency/import contract because a source/toolset/configuration change can reintroduce FLS, SRW, InitOnce, or other post-XP imports.

The policy remains: because these DLLs are built from source under project control, prefer correcting their source/build/dependency boundary before hiding a regression behind broad interposition.

## Confirmed hard residual imports in core browser PEs

These are ordinary imports in the available diagnostics and therefore are loader/runtime-closure issues for XP, not merely optional delayed paths.

### `KERNEL32.dll`

| API | Importing PE(s) | YY-Thunks v1.2.2 | Current remediation class |
| --- | --- | --- | --- |
| `InitOnceExecuteOnce` | `mozglue.dll`, `xul.dll` | yes | `YY_SUPPORTED`; extend the existing physically narrow synchronization/Kernel32 provider rather than use complete YY `kernel32.lib` |
| `GetThreadPreferredUILanguages` | `xul.dll` | yes | `YY_SUPPORTED`; bounded locale fallback is available |
| `QueryFullProcessImageNameA` | `xul.dll` | yes (`QueryFullProcessImageNameW(A)`) | `YY_SUPPORTED`; bounded process-image-name fallback is available |
| `GetApplicationRestartSettings` | `xul.dll` | not found in the reviewed YY surface | `SOURCE_REMEDIATION` preferred; Windows Restart Manager/application-restart behavior has no required XP equivalent for browser startup |
| `RegisterApplicationRestart` | `xul.dll` | not found in the reviewed YY surface | `SOURCE_REMEDIATION` preferred; compile out or no-op the modern restart registration on XP if caller semantics allow |
| `UnregisterApplicationRestart` | `xul.dll` | not found in the reviewed YY surface | `SOURCE_REMEDIATION` preferred; pair with the registration removal/fallback |
| `GetNamedPipeServerProcessId` | `xul.dll` | not found in the reviewed YY surface | identify exact caller first; prefer source redesign/XP-native validation, otherwise consider a narrow project shim only if the semantics are required |

`InitOnceExecuteOnce` is explicitly implemented by YY-Thunks and uses its old-OS synchronization fallback. This should be treated as another member of the narrow synchronization closure, but not as proof that the existing ten-API physical baseline automatically covers it. It requires its own focused link/import/runtime proof before being promoted into the proven set.

A useful focused runtime smoke for `InitOnceExecuteOnce` is a concurrent once-initialization test: multiple threads call the same `INIT_ONCE`; the initialization callback must execute exactly once and all successful callers must observe the expected context. This tests semantics rather than merely proving that the symbol links.

### `PROPSYS.dll`

The exact `xul.dll` diagnostics contain an ordinary dependency on `PROPSYS.dll` with:

- `VariantCompare`;
- `PropVariantToString`.

This is especially important because XP does not merely lack one function: the DLL dependency itself is post-XP. Closing only one imported function is insufficient if the PE still retains the hard `PROPSYS.dll` dependency.

Classification:

| API | YY-Thunks v1.2.2 | Current remediation class |
| --- | --- | --- |
| `VariantCompare` | yes | `YY_SUPPORTED`, but useful only as part of a complete removal of the hard `PROPSYS.dll` dependency |
| `PropVariantToString` | not found in the reviewed YY surface | `SOURCE_REMEDIATION` or a narrow semantic implementation after caller analysis |

The preferred result is that `xul.dll` no longer has a hard `PROPSYS.dll` import on XP. Determine the Firefox caller and required variant-to-string semantics before deciding whether to replace the call in source or provide a tiny local implementation.

## Confirmed delay-load / deferred subsystem dependencies in `xul.dll`

The raw `xul.dll` diagnostics also contain delayed imports. These do not have the same loader priority as the hard imports above, but they are still runtime compatibility work: a path can fail when first exercised on XP.

### WinRT

Confirmed delayed symbols include:

- `RoActivateInstance`;
- `RoGetActivationFactory`;
- `WindowsCreateStringReference`;
- `WindowsDeleteString`;
- `WindowsGetStringRawBuffer`.

YY-Thunks v1.2.2 has fallbacks for this WinRT/WinRT-string family. Nevertheless, the project already has a separate WinRT source-removal line. **Source-level removal/fallback remains preferred over expanding the production YY surface for WinRT.** Do not merge the WinRT source-removal question into the synchronization-thunk problem.

### DWM

Confirmed delayed symbol:

- `DwmGetWindowAttribute`.

YY-Thunks provides a bounded fallback that reports composition disabled. This is a reasonable compatibility candidate if caller-level source handling does not already make DWM optional on XP.

### UI Automation

Confirmed delayed symbols:

- `UiaClientsAreListening`;
- `UiaGetReservedMixedAttributeValue`;
- `UiaGetReservedNotSupportedValue`;
- `UiaHostProviderFromHwnd`;
- `UiaRaiseAutomationEvent`;
- `UiaRaiseAutomationPropertyChangedEvent`;
- `UiaReturnRawElementProvider`.

YY-Thunks v1.2.2 contains bounded UIAutomationCore fallbacks for this family, generally reporting no listeners, `E_NOTIMPL`, or equivalent degraded behavior. This makes YY a plausible compatibility layer, but the feature must remain explicitly classified as an accessibility/runtime subsystem rather than mixed into the core Kernel32 synchronization provider.

### NCrypt

Confirmed delayed symbols:

- `NCryptFreeObject`;
- `NCryptSignHash`.

YY-Thunks v1.2.2 implements these through older CryptoAPI-compatible paths. They are technically thunkable, but NCrypt/security behavior needs semantic review before production adoption. Do not confuse this with the separate selected app-local `bcrypt.dll` closure.

### AVRT

Confirmed delayed symbols:

- `AvRevertMmThreadCharacteristics`;
- `AvSetMmThreadCharacteristicsA`.

No reviewed YY-Thunks v1.2.2 implementation was identified during this review. Prefer a source-level optional/no-op scheduling fallback on XP if the exact caller only uses MMCSS as a performance hint. Write a shim only if caller analysis proves that a binary compatibility boundary requires one.

## Remediation queues derived from the current diagnostics

### Queue A — ready for focused YY evaluation

These have upstream YY-Thunks implementations and fit the bounded compatibility model:

1. `InitOnceExecuteOnce` — `mozglue.dll`, `xul.dll`;
2. `GetThreadPreferredUILanguages` — `xul.dll`;
3. `QueryFullProcessImageNameA` — `xul.dll`;
4. `VariantCompare` — `xul.dll`, subject to removing the remaining hard `PROPSYS.dll` dependency as a whole.

Do not automatically add all four to one archive. Preserve per-PE link ownership and the existing prohibition on complete YY `kernel32.lib` interposition.

### Queue B — source/caller remediation first

These should be traced to exact callers before any new shim is written:

1. `GetApplicationRestartSettings`;
2. `RegisterApplicationRestart`;
3. `UnregisterApplicationRestart`;
4. `GetNamedPipeServerProcessId`;
5. `PropVariantToString`;
6. `AvSetMmThreadCharacteristicsA`;
7. `AvRevertMmThreadCharacteristics`.

For restart registration, DWM/MMCSS-style optional platform features, and similar modern OS integrations, compiling the feature out or returning a deliberate XP fallback is preferable to emulating a facility that XP does not provide.

### Queue C — subsystem closures, kept separate

- WinRT: continue source removal/fallback; do not expand YY merely because YY can emulate some WinRT symbols.
- UIAutomationCore: YY provides a plausible bounded degraded fallback; validate accessibility expectations and delayed-load behavior.
- DWM: YY composition-disabled fallback is available; validate caller behavior.
- NCrypt: YY provides CryptoAPI-based implementations; review security/algorithm semantics before using them.

## Relationship to the proven synchronization baseline

The existing representative synchronization capability proof covers ten APIs:

- `AcquireSRWLockExclusive`;
- `AcquireSRWLockShared`;
- `ReleaseSRWLockExclusive`;
- `ReleaseSRWLockShared`;
- `InitializeSRWLock`;
- `InitializeConditionVariable`;
- `SleepConditionVariableCS`;
- `SleepConditionVariableSRW`;
- `WakeAllConditionVariable`;
- `WakeConditionVariable`.

That result must not be reopened without contradictory evidence. The new `InitOnceExecuteOnce` finding is an **incremental uncovered synchronization member**, not evidence that the ten proven APIs are broken.

The correct next focused proof is therefore to extend coverage for the newly discovered residual APIs while preserving the existing successful narrow-link architecture.

## Required shape of the next broad audit

Once the current CRT package-survival blocker is repaired and the workflow reaches the final audit again, the audit must produce at least:

- complete list of required product PEs examined;
- PE subsystem version for each PE;
- ordinary imported DLLs and APIs for each PE;
- delay-load DLLs and APIs separately;
- classification of every DLL absent from stock XP;
- classification of every imported API absent from stock XP;
- importing PE and owner/component for every violation;
- explicit exclusion list for test/developer/fake artifacts;
- resolution class for each required residual dependency;
- a machine-readable unresolved set that is empty before physical-XP acceptance.

The audit should continue to retain focused regression gates for already closed families, including msvcr14x CRT, the proven synchronization set, legacy `D3DCompiler_47.dll`, and the selected app-local `xp-bcrypt-v1/bcrypt.dll`. Full inventory and focused regression gates are complementary; neither replaces the other.

## Current conclusion

The 2026-09-03 diagnostics review changes the planning model but does not change the current build blocker: run `33638897692` still stops at CRT package survival before the final whole-package audit. The important new conclusion is that selected known-import gates are insufficient for XP acceptance and that several residual hard and delayed dependencies are already visible in the available core-PE diagnostics.

The next compatibility work should therefore proceed in this order:

1. preserve/fix the exact msvcr14x runtime across packaging so the full workflow can reach its final audit;
2. add focused coverage for the newly identified bounded YY candidates, especially `InitOnceExecuteOnce`, without reopening the proven ten-API synchronization baseline;
3. trace and remove/replace the Queue B source-level dependencies;
4. keep WinRT, UIAutomation, DWM, NCrypt and AVRT as explicit subsystem decisions rather than one undifferentiated YY expansion;
5. run the complete inventory-driven final PE/direct+delay import audit;
6. only then test the exact resulting product package on physical Windows XP.
