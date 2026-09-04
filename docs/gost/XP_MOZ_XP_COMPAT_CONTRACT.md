# Windows XP x86 — MOZ_XP_COMPAT build contract

Last updated: 2026-09-04

Track: Windows XP SP3 x86 compatibility only. This document does not describe or prove GOST TLS runtime behavior.

Canonical documentation branch: `agent/gost-tls-poc`.

Implementation branch for the current XP line: `agent/winrt-source-poc`.

## Purpose

`MOZ_XP_COMPAT` is the project-owned compile-time signal for source-level removal of Windows functionality which has no useful Windows XP semantic equivalent and must not remain in the XP browser binary merely to preserve behavior for newer Windows versions.

It is part of the mandatory XP build contract whenever production source contains an `#ifdef MOZ_XP_COMPAT` / `#ifndef MOZ_XP_COMPAT` compatibility boundary.

`MOZ_XP_COMPAT` is not evidence that the resulting browser is XP-compatible by itself. Final PE/import audit and physical Windows XP runtime validation remain separate acceptance boundaries.

## Mandatory rule

The full XP x32 build workflow is an explicit initiator of XP compatibility mode. When `.github/workflows/gost-poc-build-xp-x32.yml` creates the XP mozconfig, it MUST pass both project compatibility defines to C and C++ compilation:

```sh
export CFLAGS="$CFLAGS -DMOZ_NO_WINRT -DMOZ_XP_COMPAT"
export CXXFLAGS="$CXXFLAGS -DMOZ_NO_WINRT -DMOZ_XP_COMPAT"
```

This requirement is implemented on `agent/winrt-source-poc` by commit `762b24dc849bf7d16181ff57d60a1ce49b0d8455` (`build(xp): enable XP source guards in full build`).

The workflow-level defines establish the build identity: a build initiated by the canonical XP full-build workflow is intentionally an XP compatibility build and all accepted `MOZ_NO_WINRT` / `MOZ_XP_COMPAT` source boundaries are active.

Source-local ownership remains required for production files which introduced dedicated compatibility boundaries. The owning `moz.build` should continue to make the dependency explicit:

```python
SOURCES["Owner.cpp"].flags += ["-DMOZ_XP_COMPAT"]
```

These source-local flags are therefore defense-in-depth and owner documentation, while the canonical full XP workflow supplies the build-wide XP mode. Do not remove them merely because the full workflow also defines the macro globally.

If an affected file is currently listed in `UNIFIED_SOURCES` and requires source-specific flags, it must be moved to ordinary `SOURCES` before assigning those flags. A unified source is compiled as part of a generated combined translation unit and cannot safely be treated as an independently configured production source.

Normal non-XP Windows builds MUST remain unchanged: workflows/build configurations which are not XP initiators must not add these XP compatibility defines merely for convenience.

## Current production owners

### `toolkit/xre/nsAppRunner.cpp`

Source remediation commits on `agent/winrt-source-poc`:

- `194496e76559e1d86e7e3f920fb3f1fc0e46c2d7` — `fix(xp): disable Windows Application Restart under MOZ_XP_COMPAT`;
- `20f00258ac59296782fbaffbf0131d636c0d3c00` — `build(xp): define MOZ_XP_COMPAT for nsAppRunner`.

The XP build excludes the complete `RegisterApplicationRestartChanged` callback definition and its `Preferences::RegisterCallbackAndCall(...)` registration while preserving the surrounding Windows startup code.

This removes the XP build's source references to:

- `GetApplicationRestartSettings`;
- `RegisterApplicationRestart`;
- `UnregisterApplicationRestart`.

The owning build rule remains source-local:

```python
SOURCES["nsAppRunner.cpp"].flags += ["-DMOZ_XP_COMPAT"]
```

### `accessible/windows/msaa/CompatibilityUIA.cpp`

Source remediation commits on `agent/winrt-source-poc`:

- `561bded451638e599fae2d57285446261f9a0035` — `fix(xp): disable modern UIA client detection under MOZ_XP_COMPAT`;
- `ebe325ad87232f68ca01d7e4c63be14f9c4ee74b` — `build(xp): define MOZ_XP_COMPAT for CompatibilityUIA`.

The XP build excludes the modern UI Automation client-detection implementations (`GetUiaClientPidsWin11` and `GetUiaClientPidWin10`) and makes `Compatibility::GetUiaClientPids` a no-op for the XP translation unit.

This removes the XP build's source reference to `GetNamedPipeServerProcessId` and intentionally does not preserve Win10/Win11-only UIA detection features in the XP release.

Because `CompatibilityUIA.cpp` originally belonged to `UNIFIED_SOURCES`, the build integration moves it to ordinary `SOURCES` and then applies:

```python
SOURCES["CompatibilityUIA.cpp"].flags += ["-DMOZ_XP_COMPAT"]
```

### `mozglue/misc/WindowsDpiInitialization.cpp`

The physical-XP startup failure of runtime artifact `9899304858` from run `33757305364` was debugger-confirmed as the MSVC delay-load exception `C06D007F` for `USER32.dll!SetProcessDPIAware`, with `pfnCur == 0` and `dwLastError == ERROR_PROC_NOT_FOUND (0x7f)`.

Current implementation commits on `agent/winrt-source-poc`:

- `fad9ec0b5a09c50f6cff39a00a3ea4cedd99cdf2` — initial pre-Vista success/no-op source remediation;
- `a784a7660b23f8270179f5464c2ac3033d7e0652` — `fix(xp): scope DPI startup guard to MOZ_XP_COMPAT`;
- `a3ede2576cbc7e92ffae58ba0c49d2c38e580335` — `build(xp): mark WindowsDpiInitialization as XP-owned`.

The project-owned boundary is intentionally visible in source:

```cpp
#ifdef MOZ_XP_COMPAT
  if (!IsVistaOrLater()) {
    return WindowsDpiInitializationResult::Success;
  }
#endif
```

`WindowsDpiInitialization.cpp` is already an ordinary `SOURCES` entry, so no unified-source extraction is required. Its owner rule is:

```python
SOURCES["WindowsDpiInitialization.cpp"].flags += ["-DMOZ_XP_COMPAT"]
```

The source-local flag is retained even though the canonical XP workflow also supplies the build-wide macro. This makes the exact translation unit visibly project-owned and protects the compatibility boundary from becoming dependent only on an external workflow definition.

Normal non-XP builds retain the upstream DPI path because the pre-Vista no-op is compiled only under `MOZ_XP_COMPAT`.

## Relationship to `MOZ_NO_WINRT`

Existing `MOZ_NO_WINRT` source remediations remain valid and must not be rewritten merely for naming consistency.

The distinction is intentional:

- `MOZ_NO_WINRT` records existing no-WinRT source selections already used by this branch;
- `MOZ_XP_COMPAT` is the preferred project signal for new source-level removal of functionality that the XP release does not need or cannot execute.

The canonical full XP x32 workflow activates both macros because both classes of source remediation belong to the XP release configuration.

Future XP-specific source exclusions should normally use `MOZ_XP_COMPAT` unless a narrower existing subsystem flag is semantically more correct.

## Evidence-preserving quartet gate

The canonical XP full-build workflow checks final `dist/bin/xul.dll` for the source-remediation quartet:

- `GetApplicationRestartSettings`;
- `RegisterApplicationRestart`;
- `UnregisterApplicationRestart`;
- `GetNamedPipeServerProcessId`.

Starting with workflow commit `424708f1d8e754f752e108259b331fcd2ec3615b`, this is no longer merely informational. The step remains `continue-on-error: true` so packaging and diagnostics can still be collected, but a surviving quartet member makes that gate fail and is included in the final RED verdict. The required accepted result is strict `0/4` in final `xul.dll`.

The same workflow revision also records delay-import inventory separately from ordinary imports and checks the `mozglue.dll` `SetProcessDPIAware` import mode independently. Delay-import presence alone is not an XP failure; runtime reachability and source guards remain separate acceptance facts.

## Acceptance rules

A `MOZ_XP_COMPAT` remediation is considered source-integrated when all of the following are true:

1. the source boundary excludes the complete modern feature/reference or runtime edge which must not execute in the XP build;
2. the owning production `moz.build` records `MOZ_XP_COMPAT` for that exact source where a source-local boundary was introduced;
3. the canonical full XP workflow activates both `MOZ_NO_WINRT` and `MOZ_XP_COMPAT` for C/C++ compilation;
4. neighboring functionality outside the selected compatibility boundary is not unintentionally disabled;
5. ordinary non-XP Windows compilation retains the original source path;
6. no broad YY-Thunks or global shim is introduced merely to preserve a feature which the XP release does not require.

Source integration does not by itself close final binary compatibility. The next full XP browser build must still pass the relevant PE/import evidence gates, and the exact accepted artifact must still be exercised on physical Windows XP.

## Build-review checklist

When adding a new XP source remediation:

- identify the exact production owner and translation unit;
- determine whether the feature has meaningful XP semantics;
- if it does not, prefer compile-out or runtime no-op under `MOZ_XP_COMPAT`;
- ensure the exact owner records `-DMOZ_XP_COMPAT` in its production build configuration when it has a dedicated boundary;
- if the owner is unified and requires source-specific flags, move only that file from `UNIFIED_SOURCES` to `SOURCES` before assigning them;
- preserve the canonical full XP workflow's global `MOZ_NO_WINRT` + `MOZ_XP_COMPAT` build mode;
- do not add these defines to ordinary non-XP Windows workflows without a separate decision;
- preserve non-XP behavior;
- record the source commit(s) and build-config commit(s) separately;
- retain final PE/import and physical-XP gates.

This contract is mandatory for the XP line going forward.
