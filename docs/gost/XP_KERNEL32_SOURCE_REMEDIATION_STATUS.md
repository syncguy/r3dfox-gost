# Windows XP x86 — KERNEL32 source-remediation status

Last updated: 2026-09-04

Track: Windows XP SP3 x86 compatibility only. This document does not describe or prove GOST TLS runtime behavior.

Canonical documentation location: `agent/gost-tls-poc:docs/gost/`.

Working implementation branch: `agent/winrt-source-poc`.

## Current conclusion

The KERNEL32 source-remediation quartet is **source-integrated, but not final-import closed** in the current XP line:

- `GetApplicationRestartSettings` — **OPEN in final `xul.dll` diagnostics**;
- `RegisterApplicationRestart` — absent in the latest focused quartet diagnostic;
- `UnregisterApplicationRestart` — absent in the latest focused quartet diagnostic;
- `GetNamedPipeServerProcessId` — **OPEN in final `xul.dll` diagnostics**.

Exact implementation/configuration chain remains:

1. `194496e76559e1d86e7e3f920fb3f1fc0e46c2d7` — `fix(xp): disable Windows Application Restart under MOZ_XP_COMPAT`;
2. `20f00258ac59296782fbaffbf0131d636c0d3c00` — `build(xp): define MOZ_XP_COMPAT for nsAppRunner`;
3. `561bded451638e599fae2d57285446261f9a0035` — `fix(xp): disable modern UIA client detection under MOZ_XP_COMPAT`;
4. `ebe325ad87232f68ca01d7e4c63be14f9c4ee74b` — `build(xp): define MOZ_XP_COMPAT for CompatibilityUIA`.

The source/configuration work remains valid, but the latest production full-build evidence is contradictory to complete import closure and therefore reopens two names.

## Latest production evidence — two names survive

Exact full-build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `2b1cf7e1b59881b935c7f695a54edd6b92c8066e`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33757305364`, attempt `1`;
- job `100654730312`;
- aggregate workflow result: **success**.

The run is the first fully GREEN XP x32 full-build workflow, but step `DIAG - Check source-remediation quartet absent from xul.dll` is intentionally informational. Its exact diagnostics report:

```text
result=WARN|surviving=GetApplicationRestartSettings,GetNamedPipeServerProcessId
```

The corresponding `surviving-quartet-imports.txt` contains exactly:

```text
GetApplicationRestartSettings
GetNamedPipeServerProcessId
```

Both names are also visible in the raw `xul.dll` import dump. `RegisterApplicationRestart` and `UnregisterApplicationRestart` are not reported as survivors.

Therefore aggregate workflow GREEN must not be interpreted as quartet closure. These two imports are not currently promoted by the final forbidden-import hard gate, which explains how the workflow can pass while the quartet diagnostic remains WARN.

## Focused strategy evidence retained

The earlier representative mechanism proof remains valid historical evidence:

- workflow `.github/workflows/xp-kernel32-source-remediation-smoke.yml` (`XP KERNEL32 source remediation smoke`);
- source-under-test `0450fd8f2b22b9e0263e0755e0ea52f4dd6e2aa4`;
- Actions run `33720100459`;
- job `100537300030`;
- diagnostics artifact `9879912839`;
- artifact digest `sha256:29f742d11f584a07695fcb5cfa87d5f7046e5a22d54470f3b97acb065b85b886`;
- result: **success**.

That smoke established the representative compile/link/import strategy, but it does not override contradictory evidence from the later production full build.

## Application Restart trio

Production owner: `toolkit/xre/nsAppRunner.cpp`.

The XP release does not intend to emulate the Vista+ Windows Application Restart facility.

Under `MOZ_XP_COMPAT`:

- the complete `RegisterApplicationRestartChanged` definition is intended to be excluded;
- its `Preferences::RegisterCallbackAndCall(...)` registration in `XREMain::XRE_mainRun()` is intended to be excluded;
- neighboring Windows startup facilities remain unchanged.

The source-local build rule is in `toolkit/xre/moz.build`:

```python
SOURCES["nsAppRunner.cpp"].flags += ["-DMOZ_XP_COMPAT"]
```

Latest full-build evidence means the accepted remediation is only partially reflected in the final binary: `RegisterApplicationRestart` and `UnregisterApplicationRestart` are absent, but `GetApplicationRestartSettings` still survives in `xul.dll`. Its actual remaining owner/link path must be identified before this trio is marked closed.

## Modern UIA client detection / `GetNamedPipeServerProcessId`

Production owner previously identified: `accessible/windows/msaa/CompatibilityUIA.cpp`.

The project rule remains to remove modern-Windows-only functionality from the XP release when it has no useful XP semantic equivalent.

Under `MOZ_XP_COMPAT`:

- `GetUiaClientPidsWin11` is intended to be excluded;
- `GetUiaClientPidWin10` is intended to be excluded;
- `Compatibility::GetUiaClientPids` is intended to be a no-op.

Because `CompatibilityUIA.cpp` originally belonged to `UNIFIED_SOURCES`, it was moved to ordinary `SOURCES` so a source-local compatibility define could be applied without changing neighboring accessibility translation units.

The owning build rule is:

```python
SOURCES["CompatibilityUIA.cpp"].flags += ["-DMOZ_XP_COMPAT"]
```

Nevertheless `GetNamedPipeServerProcessId` survives in the latest final `xul.dll`. The next investigation must locate the remaining call/import owner instead of assuming this previously identified translation unit is the only source.

## Mandatory `MOZ_XP_COMPAT` contract

`MOZ_XP_COMPAT` remains the preferred project-owned compile-time signal for new XP-specific source exclusions.

For every production translation unit containing an accepted `MOZ_XP_COMPAT` boundary, the XP build MUST define the macro for that exact owner. Prefer source-local ownership rather than a global define.

If the owner is in `UNIFIED_SOURCES`, move only that source to ordinary `SOURCES` before assigning its source-specific `-DMOZ_XP_COMPAT` flag.

Existing `MOZ_NO_WINRT` source remediations remain valid and do not need to be renamed merely for consistency.

Full rules are authoritative in `XP_MOZ_XP_COMPAT_CONTRACT.md`.

## Evidence boundary and next acceptance step

The quartet is now classified as:

**SOURCE-INTEGRATED / PARTIAL FINAL-BINARY CLOSURE / TWO IMPORTS OPEN.**

Do not mark the quartet fully closed until a later exact production full build shows all four names absent from the final `xul.dll` import evidence, or the project deliberately changes the acceptance classification with explicit evidence.

The immediate source-remediation investigation is limited to:

1. `GetApplicationRestartSettings` — find the remaining final-link owner/path;
2. `GetNamedPipeServerProcessId` — find the remaining final-link owner/path.

Physical Windows XP startup of runtime artifact `9899304858` from run `33757305364` remains a separate runtime boundary and should proceed independently; a successful startup would not by itself erase these static-import findings.

## Out of scope for this closure

This source-remediation line does not resolve or reclassify:

- residual YY-owned KERNEL32 APIs already handled by the separate narrow-provider line;
- PROPSYS (`VariantCompare`, `PropVariantToString`);
- bcrypt/One-Core work;
- GOST TLS / MSSPI / SSPI / CryptoPro / handshake work;
- Firefox 153 -> 154 base migration;
- already closed SRW/condition-variable and `CreateWaitableTimerExA` work.

Those remain separate evidence lines.