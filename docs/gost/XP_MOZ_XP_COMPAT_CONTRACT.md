# Windows XP x86 — MOZ_XP_COMPAT build contract

Last updated: 2026-09-03

Track: Windows XP SP3 x86 compatibility only. This document does not describe or prove GOST TLS runtime behavior.

Canonical documentation branch: `agent/gost-tls-poc`.

Implementation branch for the current XP line: `agent/winrt-source-poc`.

## Purpose

`MOZ_XP_COMPAT` is the project-owned compile-time signal for source-level removal of Windows functionality which has no useful Windows XP semantic equivalent and must not remain in the XP browser binary merely to preserve behavior for newer Windows versions.

It is part of the mandatory XP build contract whenever production source contains an `#ifdef MOZ_XP_COMPAT` / `#ifndef MOZ_XP_COMPAT` compatibility boundary.

`MOZ_XP_COMPAT` is not evidence that the resulting browser is XP-compatible by itself. Final PE/import audit and physical Windows XP runtime validation remain separate acceptance boundaries.

## Mandatory rule

For every production translation unit that contains an accepted XP-specific `MOZ_XP_COMPAT` source boundary, the XP build configuration MUST compile that exact translation unit with `MOZ_XP_COMPAT` defined.

The preferred project pattern is source-local definition in the owning `moz.build`:

```python
SOURCES["Owner.cpp"].flags += ["-DMOZ_XP_COMPAT"]
```

Do not add a global project-wide `MOZ_XP_COMPAT` define merely for convenience unless a later architectural review explicitly decides that the complete build should share identical XP conditional semantics. Source-local ownership keeps each compatibility decision explicit and prevents unrelated Windows code from silently changing behavior.

If an affected file is currently listed in `UNIFIED_SOURCES`, it must be moved to ordinary `SOURCES` before applying a source-specific `-DMOZ_XP_COMPAT` flag. The reason is build-system ownership: a unified source is compiled as part of a generated combined translation unit and cannot safely be treated as an independently configured production source.

Normal non-XP Windows builds MUST remain unchanged: without `MOZ_XP_COMPAT`, the original modern-Windows implementation is compiled.

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

The owning build rule is source-local:

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

## Relationship to `MOZ_NO_WINRT`

Existing `MOZ_NO_WINRT` source remediations remain valid and must not be rewritten merely for naming consistency.

The distinction is intentional:

- `MOZ_NO_WINRT` records existing narrowly scoped no-WinRT source selections already used by this branch;
- `MOZ_XP_COMPAT` is the preferred project signal for new source-level removal of functionality that the XP release does not need or cannot execute.

Future XP-specific source exclusions should normally use `MOZ_XP_COMPAT` unless a narrower existing subsystem flag is semantically more correct.

## Acceptance rules

A `MOZ_XP_COMPAT` remediation is considered source-integrated when all of the following are true:

1. the source boundary excludes the complete modern feature/reference which must not exist in the XP translation unit;
2. the owning production `moz.build` defines `MOZ_XP_COMPAT` for that exact source;
3. neighboring functionality outside the selected feature is not unintentionally disabled;
4. ordinary non-XP Windows compilation retains the original source path;
5. no broad YY-Thunks or global shim is introduced merely to preserve a feature which the XP release does not require.

Source integration does not by itself close final binary compatibility. The next otherwise-justified full XP browser build must still pass the inventory-driven PE/import audit, and the exact accepted artifact must still be exercised on physical Windows XP.

## Build-review checklist

When adding a new XP source remediation:

- identify the exact production owner and translation unit;
- determine whether the feature has meaningful XP semantics;
- if it does not, prefer compile-out under `MOZ_XP_COMPAT`;
- ensure the exact owner receives `-DMOZ_XP_COMPAT` in its production build configuration;
- if the owner is unified, move only that file from `UNIFIED_SOURCES` to `SOURCES` before assigning source-local flags;
- do not apply `MOZ_XP_COMPAT` globally without a separate architectural decision;
- preserve non-XP behavior;
- record the source commit(s) and build-config commit(s) separately;
- retain final PE/import and physical-XP gates.

This contract is mandatory for the XP line going forward.