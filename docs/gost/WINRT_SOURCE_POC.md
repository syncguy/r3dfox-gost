# WinRT source-removal PoC for legacy Windows

Status: **primary active WinRT-remediation experiment**; not merged into the main implementation and not yet validated by a successful target build/runtime.

Last reviewed: 2026-08-29.

This document records the architectural idea and current evidence from the separate branch `agent/winrt-source-poc`. It belongs exclusively to the **Windows Vista/7/XP binary/runtime compatibility track**. It does not change or prove anything about the independent GOST TLS runtime/handshake track.

## Why this experiment exists

Physical Win7 x32 testing of the full Firefox 153 build from source `982d6529a707c6feecad97c725feed8a3cd21c81`, Actions run `33141004769`, job `98751650853`, runtime artifact `9676549576`, proved a later parent/browser crash caused by a `xul.dll` WinRT delay-load:

`xul.dll` -> `api-ms-win-core-winrt-l1-1-0.dll` -> `RoGetActivationFactory` -> module missing on Win7 -> `ERROR_MOD_NOT_FOUND (0x7e)` -> MSVC delay-load exception `0xc06d007e`.

The exact diagnostics also show the adjacent delay-load groups:

- `api-ms-win-core-winrt-l1-1-0.dll`: `RoActivateInstance`, `RoGetActivationFactory`;
- `api-ms-win-core-winrt-string-l1-1-0.dll`: `WindowsCompareStringOrdinal`, `WindowsCreateString`, `WindowsCreateStringReference`, `WindowsDeleteString`, `WindowsGetStringRawBuffer`.

An initial remediation line tried to keep Firefox's WinRT consumers intact and progressively expose the needed WinRT surface through the project's narrow YY-Thunks provider. That approach has now been experimentally retired **for this WinRT blocker** after its run/change history showed an expanding transitive dependency boundary rather than convergence. The detailed evidence is recorded in `TEST_LOG.md`.

`agent/winrt-source-poc` therefore asks the project's current primary WinRT-remediation question:

> Instead of emulating the growing WinRT/transitive runtime surface required by Firefox 153, can we remove or replace the nonessential Firefox WinRT consumers at source level so the legacy build does not carry those WinRT dependencies at all?

This is a compatibility strategy, not an extension of the GOST TLS transport.

## Why YY-Thunks expansion was retired for this blocker

This decision must not be generalized beyond WinRT.

YY-Thunks remains useful for bounded old-Windows Win32 gaps. In particular, the representative XP x86 coexistence line at source `d78137a931145af877dc458b01e494ad0467723d`, run `33138244191`, job `98743029100`, runtime artifact `9673057839`, completed three physical Windows XP SP3 x86 executions with `ExitCode=0`.

What is retired is the attempt to make YY-Thunks the **primary carrier for Firefox's WinRT feature/runtime surface**.

The dedicated WinRT YY smoke began at commit `90067edba48fd4e8bb986ced02a47ae2189e9fb3` (`ci(win7): add WinRT YY-Thunks delay-load smoke`) and reached `3ebfef1ddbb70b0d2b29f160dabcaa8fbef4fab5` (`ci(win7): link OLE32 in WinRT smoke`) about 3 h 26 min later. Between those points:

- 26 additional commits accumulated;
- `.github/workflows/msvcr14x-rust-yy-xp-x86-coexistence-smoke.yml` alone saw 345 changed lines (171 additions / 174 deletions);
- the compatibility harness expanded from WinRT aliases into CRT/runtime stubs and MASM glue;
- system-library dependencies were added sequentially through `ADVAPI32`, `GDI32`, `USER32`, `VERSION`, `NTDLL`, `OLEAUT32`, and `OLE32`.

The final reviewed run is exact source `3ebfef1ddbb70b0d2b29f160dabcaa8fbef4fab5`, run `33186862417`, job `98901994671`, workflow run number `31`. It still failed in the synthetic closing link, now on another newly exposed dependency:

`__imp__StrCmpLogicalW@8`

The problem is therefore not that one particular YY alias was missing. The experiment demonstrated a moving transitive boundary: every apparent closure pulled in another part of the Windows/WinRT support environment before the strategy had even reached successful full `xul.dll` closure plus physical Win7 runtime proof.

**Policy for this blocker:** do not continue by blindly adding the next YY alias, CRT stub, system import library or hand-written harness dependency. Source-level WinRT removal/fallback is the primary active direction. A small residual YY shim may be reconsidered only if source removal later leaves one or a few unavoidable imports with narrow, stable and evidence-bounded semantics.

## Exact branch identity reviewed

At review time:

- main/default branch: `agent/gost-tls-poc`;
- main comparison base: `3ebfef1ddbb70b0d2b29f160dabcaa8fbef4fab5`;
- experimental branch: `agent/winrt-source-poc`;
- experimental HEAD: `f1c55320f77a9ff932fa3e6cca2bc2443c20ec45`;
- relation to that main base: 8 commits ahead, 0 behind;
- changed files: 11;
- aggregate file statistics from the GitHub compare API: 336 additions, 989 deletions.

The experiment is deliberately isolated from the default branch. Do not treat its source changes as merged merely because this design note exists on `agent/gost-tls-poc`.

## What the branch changes

### 1. Replace the Windows ToastNotification WinRT implementation with an ABI-compatible stub

Changed files:

- `widget/windows/ToastNotification.cpp`;
- `widget/windows/ToastNotification.h`;
- `widget/windows/moz.build`.

The large WinRT-backed toast implementation is replaced by a compact implementation that retains the XPCOM/interface surface but does not instantiate Windows Runtime notification APIs.

Important behavior of the stub:

- `ToastNotification::Init()` returns `NS_ERROR_NOT_IMPLEMENTED`;
- `ShowAlert()` returns `NS_ERROR_NOT_IMPLEMENTED`;
- WinRT-specific XML/tag/install-notification operations return `NS_ERROR_NOT_IMPLEMENTED`;
- `CloseAlert()` and teardown-style methods remain harmless successful operations where appropriate;
- `WindowsAlertNotification` retains the existing interface-facing image placement/path fields;
- the intent is ABI/interface continuity without carrying the WinRT activation/string dependency into `xul.dll`.

`widget/windows/moz.build` selects `ToastNotification.cpp` for the clang-cl legacy build and deliberately does not compile `ToastNotificationHandler.cpp` on this path.

This is not equivalent to preserving native Windows toast functionality. It intentionally sacrifices the modern WinRT notification backend on the legacy target.

### 2. Restore an existing XUL alerts fallback when the platform backend is absent

Changed file:

- `toolkit/components/alerts/nsAlertsService.cpp`.

The branch changes alert routing so a missing platform/system backend falls through to `nsXULAlerts::GetInstance()` rather than making the absence of the Windows system backend fatal to normal notification delivery.

The intended user-visible behavior is therefore:

`WinRT system toast unavailable` -> `use Firefox XUL alert fallback`.

This is an important part of the design: the PoC does not merely delete notification functionality; it attempts to degrade to Firefox's non-WinRT notification implementation.

### 3. Replace the WinRT InputPane path with a legacy no-op implementation

Changed files:

- new `widget/windows/OSKInputPaneManagerLegacy.cpp`;
- `widget/windows/moz.build`.

The legacy implementation keeps the `OSKInputPaneManager` methods available but implements `ShowOnScreenKeyboard()` and `DismissOnScreenKeyboard()` as no-ops.

The purpose is to avoid compiling/linking the Windows Runtime `InputPane` implementation while preserving the C++ call surface expected by the rest of the widget code.

Functional cost: WinRT-driven on-screen-keyboard/InputPane behavior is intentionally absent on this legacy path.

### 4. Remove the `windows` / `windows-core` dependency from the Windows widget Rust crate

Changed files:

- `widget/windows/rust/Cargo.toml`;
- `widget/windows/rust/src/lib.rs`;
- `widget/windows/rust/src/permission_monitor.rs`.

`Cargo.toml` intentionally contains no Windows Runtime dependency on this branch. The broad windows-rs feature set used by the normal Firefox Windows widget crate is removed.

The Rust library then preserves only the interfaces needed by Firefox while eliminating the WinRT-backed implementations:

- Windows toast history is represented by an `nsIAlertsServiceRust` implementation that returns an empty history;
- WinRT notification/taskbar/UI helper modules are no longer part of the crate on this path;
- `PermissionMonitor` remains constructible through XPCOM but `StartMonitoring()` returns `NS_ERROR_NOT_IMPLEMENTED` because `AppCapability` is a WinRT facility without an XP-equivalent implementation in this PoC.

The architectural point is important: this branch is not merely patching one C++ call to `RoGetActivationFactory`; it removes a larger source-level WinRT dependency surface from the Windows widget Rust crate.

### 5. Force selected existing non-WinRT/MinGW source paths under clang-cl

Changed files include:

- `toolkit/system/windowsPackageManager/moz.build`;
- `widget/windows/moz.build`.

For `nsWindowsPackageManager.cpp`, the PoC adds the per-source flag `-D__MINGW32__`. `WindowsUIUtils.cpp` is similarly compiled with `-D__MINGW32__` in the experimental widget build configuration.

The purpose is to reuse source paths that already avoid the problematic WinRT code instead of creating a second implementation immediately.

This is acceptable as a **PoC mechanism**, but it is not a preferred permanent design. `__MINGW32__` describes a compiler/toolchain environment; clang-cl is still the actual toolchain. Using that macro as a proxy for "legacy Windows build without WinRT" can accidentally select unrelated MinGW-specific behavior.

If the source-removal strategy is ultimately adopted, replace this macro spoofing with an explicit project/build feature such as a narrowly scoped `MOZ_NO_WINRT` / legacy-Windows capability define, and audit every conditional it controls.

## Architectural interpretation

The branch is now the project's **primary active strategy** for the Win7 `RoGetActivationFactory` crash, but it remains an experiment until exact build/import/runtime evidence passes.

### Retired primary strategy — expanding YY-Thunks across the WinRT surface

The YY route was attractive because it minimized Firefox source divergence and, in isolation, YY-Thunks provides sensible pre-Win8 fallbacks for APIs such as `RoGetActivationFactory`.

The dedicated run history, however, demonstrated that closing Firefox's WinRT activation/string imports did not remain a small fixed alias problem. The support surface expanded through import alias generation, shared implementation dependencies, CRT/runtime glue, assembly stubs and an increasing list of Windows import libraries, then ended on another unresolved `StrCmpLogicalW` dependency at run `33186862417` / job `98901994671` / SHA `3ebfef1...`.

For this blocker that scaling behavior is sufficient reason to stop. Do not spend additional project effort recursively reproducing the next transitive dependency unless later source-removal evidence reduces the problem to a genuinely bounded residual import.

### Primary active strategy — source-level WinRT removal/fallback (`agent/winrt-source-poc`)

Compile a legacy Firefox variant that does not include nonessential WinRT consumers, preserving interfaces with stubs or existing legacy fallbacks.

Advantages:

- attacks the cause at the feature boundary instead of accumulating loader/runtime shims;
- can completely remove some WinRT imports from `xul.dll` rather than only satisfying them at runtime;
- makes the unsupported-feature policy explicit: old Windows gets legacy behavior rather than pretending modern Windows facilities exist;
- gives a finite reviewable target: identify which WinRT-backed Firefox features are nonessential on the legacy OS, remove/replace them, then inspect final `xul.dll` imports.

Risks:

- larger source divergence from r3dfox/Firefox;
- easy to disable more functionality than necessary;
- windows-rs contains both WinRT and ordinary Win32 projections, so removing the entire dependency/feature set may be broader than the final solution requires;
- ABI-compatible stubs can still change semantics in subtle ways and require browser-level regression testing;
- spoofing `__MINGW32__` is too coarse for a final implementation.

The strategy preference does **not** constitute a validation pass. The source-removal PoC must still prove target compilation, final import closure and physical runtime.

## Functional cost currently accepted by the PoC

The experimental source intentionally gives up or degrades at least these modern Windows integrations on the legacy path:

- native Windows WinRT toast notifications;
- WinRT toast history/tag/XML operations;
- WinRT InputPane/on-screen-keyboard integration;
- WinRT `AppCapability` permission monitoring;
- Rust-side WinRT notification/taskbar/UI utility paths removed from the Windows widget crate;
- selected Windows package/UI paths are forced onto existing non-WinRT conditional implementations.

For the project's old-Windows browser goal, these losses may be acceptable if ordinary Firefox browsing remains stable. That acceptability must be proven by runtime tests rather than inferred from build success.

## Current CI evidence — not yet a validation pass

### Targeted WinRT source isolation workflow

- branch: `agent/winrt-source-poc`;
- source-under-test: `f6e87ba87919f999d2a3ec6c2b9ba103fea1d99e` (`xp: replace WinRT alerts with legacy fallbacks`);
- workflow: `WinRT source PoC x86`;
- run: `33242986136`;
- job: `99075394860` (`Firefox source WinRT isolation / x86`);
- result: failure.

The run passed checkout, identity recording, the intended-source-isolation gate, bootstrap and configure. It failed at step `Build export prerequisites`.

Consequently these later gates were skipped:

- `GATE - Compile WinRT-related target objects`;
- `GATE - Disabled legacy paths have no WinRT API references`.

Therefore run `33242986136` does **not** prove that the modified WinRT-related objects compile and does not prove that their object/import surface is free of WinRT references.

### Full XP x32 workflow dispatched from the PoC branch

- branch: `agent/winrt-source-poc`;
- source-under-test: `f1c55320f77a9ff932fa3e6cca2bc2443c20ec45` (`ci(xp): dispatch full build for WinRT legacy PoC`);
- workflow: `GOST TLS PoC build  XP x32`;
- run: `33243005271`;
- job: `99075448278` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- result: failure.

This run successfully completed the compatibility setup through:

- MozillaBuild/bootstrap preparation;
- pinned MSSPI preparation and source registration;
- x86 MSVC environment;
- pinned Rust x86 target;
- msvcr14x build;
- YY-Thunks 1.2.2 download;
- narrow YY XP x86 provider construction;
- libxul compatibility-layer linker patch;
- Firefox x86 configure.

It then failed at `Build export prerequisites` before the SSL target gate, full browser compilation, packaging or final PE audit.

Therefore the current experimental HEAD has **not** produced a full Firefox artifact and has **not** demonstrated that the WinRT delay imports disappear from `xul.dll`.

## What is and is not proven

Currently proven:

- the experimental branch exists as a coherent source-level alternative to carrying the WinRT surface through YY-Thunks;
- its reviewed diff is based directly on main SHA `3ebfef1ddbb70b0d2b29f160dabcaa8fbef4fab5` and is 8 commits ahead / 0 behind at HEAD `f1c55320f77a9ff932fa3e6cca2bc2443c20ec45`;
- the source changes intentionally remove/stub several concrete WinRT consumers and preserve selected interface/fallback paths;
- both current CI attempts reach configure but stop at `Build export prerequisites` before the target proof gates;
- the prior YY WinRT-expansion experiment is no longer a competing primary strategy because its run history demonstrated non-converging transitive dependency growth.

Not proven:

- that the branch compiles the modified target objects successfully;
- that a full `xul.dll` links;
- that `api-ms-win-core-winrt-l1-1-0.dll` and the WinRT string API-set disappear from the final delay-import table;
- that `RoGetActivationFactory` is no longer reachable at runtime;
- that the resulting browser starts or remains stable on physical Win7/XP;
- that the functional fallbacks are sufficient for normal browsing;
- any GOST TLS handshake/runtime behavior.

## Required proof sequence before considering integration

Do not merge this PoC into `agent/gost-tls-poc` solely because it is now the preferred strategy.

Required evidence, in order:

1. Repair the current `Build export prerequisites` failure on the PoC branch without weakening the source-isolation intent.
2. Pass the targeted compile gate for the modified WinRT-related objects.
3. Inspect those objects/import references and confirm that disabled paths no longer introduce the targeted WinRT activation/string APIs.
4. Complete a full x86 Firefox/xul build and package from an exact PoC SHA.
5. Audit final `xul.dll` ordinary and delay imports. Require the specific WinRT API-set/imports involved in the proven Win7 crash to be absent or otherwise intentionally resolved by the selected architecture.
6. Run the exact artifact on physical Win7 with normal sandbox settings. Require normal startup, tabs, ordinary page browsing and sufficient soak time to cross the previously observed later-crash window.
7. Run the exact artifact on physical XP as a separate compatibility gate; new XP loader failures remain independent blockers.
8. Only after compatibility passes, separately validate GOST TLS on the exact old-Windows artifact. Loader/startup success is not GOST handshake evidence.

## Integration guidance if the PoC works

If the source-removal approach passes the proof sequence, do not merge the experimental branch mechanically. First reduce it to the smallest maintainable legacy-Windows compatibility layer:

- retain source-level removal only for WinRT features that are actually unavailable/nonessential on the supported legacy targets;
- preserve existing Firefox legacy fallbacks where possible rather than inventing new parallel implementations;
- replace `__MINGW32__` macro spoofing with explicit capability/build flags;
- re-evaluate whether the entire Rust `windows` dependency must be removed or whether only WinRT modules/features should be excluded;
- document each intentionally lost feature and its fallback behavior;
- keep the resulting patch independent from `nsGostSSLIOLayer`, NSS/NSPR/MSSPI and GOST handshake work.

If this reduced source-level design leaves a genuinely small residual old-Windows import gap, a narrow YY-Thunks shim may be used for that residual gap. Do not re-expand the retired WinRT-provider experiment by default.

## Decision rule

**Current project decision:** source-level removal/fallback of nonessential WinRT consumers is the primary active remedy for the proven Win7 WinRT delay-load blocker.

The previous strategy of progressively extending the narrow YY-Thunks provider across the Firefox WinRT activation/string/transitive support surface is **retired as unpromising for this blocker** based on exact workflow history ending with run `33186862417`, job `98901994671`, SHA `3ebfef1ddbb70b0d2b29f160dabcaa8fbef4fab5`, still failing on newly exposed `__imp__StrCmpLogicalW@8` after 31 workflow runs and 26 follow-up commits from the first dedicated WinRT smoke.

This decision does not assert that `agent/winrt-source-poc` already works. Its current runs fail before the target proof gates. The next job is to make the source-removal PoC reach the compile/import/full-build/runtime evidence chain, not to add another dependency to the YY WinRT harness.

YY-Thunks remains allowed for narrow, stable, evidence-bounded Win32 compatibility needs and for any later residual import proven to remain after source-level reduction.

Neither the strategy decision nor eventual old-Windows startup success proves GOST TLS runtime behavior.