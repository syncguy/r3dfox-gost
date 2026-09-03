# Windows XP x86 — KERNEL32 source-remediation status

Last updated: 2026-09-03

Track: Windows XP SP3 x86 compatibility only. This document does not describe or prove GOST TLS runtime behavior.

Canonical documentation location: `agent/gost-tls-poc:docs/gost/`.

Working implementation branch: `agent/winrt-source-poc`.

## Current conclusion

The KERNEL32 source-remediation quartet is now **source-integrated** in the production tree for the current XP line:

- `GetApplicationRestartSettings`;
- `RegisterApplicationRestart`;
- `UnregisterApplicationRestart`;
- `GetNamedPipeServerProcessId`.

Exact implementation/configuration chain:

1. `194496e76559e1d86e7e3f920fb3f1fc0e46c2d7` — `fix(xp): disable Windows Application Restart under MOZ_XP_COMPAT`;
2. `20f00258ac59296782fbaffbf0131d636c0d3c00` — `build(xp): define MOZ_XP_COMPAT for nsAppRunner`;
3. `561bded451638e599fae2d57285446261f9a0035` — `fix(xp): disable modern UIA client detection under MOZ_XP_COMPAT`;
4. `ebe325ad87232f68ca01d7e4c63be14f9c4ee74b` — `build(xp): define MOZ_XP_COMPAT for CompatibilityUIA`.

The implementation branch reached exact HEAD `ebe325ad87232f68ca01d7e4c63be14f9c4ee74b` after these changes.

This is a source/build-configuration closure. It is not yet final `xul.dll` import proof and is not physical Windows XP runtime proof.

## Focused strategy evidence retained

The earlier representative mechanism proof remains valid historical evidence:

- workflow `.github/workflows/xp-kernel32-source-remediation-smoke.yml` (`XP KERNEL32 source remediation smoke`);
- source-under-test `0450fd8f2b22b9e0263e0755e0ea52f4dd6e2aa4`;
- Actions run `33720100459`;
- job `100537300030`;
- diagnostics artifact `9879912839`;
- artifact digest `sha256:29f742d11f584a07695fcb5cfa87d5f7046e5a22d54470f3b97acb065b85b886`;
- result: **success**.

That smoke established the representative compile/link/import strategy, but the current production source closure is defined by the later four commits above.

## Application Restart trio

Production owner: `toolkit/xre/nsAppRunner.cpp`.

The XP release does not emulate the Vista+ Windows Application Restart facility.

Under `MOZ_XP_COMPAT`:

- the complete `RegisterApplicationRestartChanged` definition is excluded;
- its `Preferences::RegisterCallbackAndCall(...)` registration in `XREMain::XRE_mainRun()` is excluded;
- neighboring Windows startup facilities remain unchanged.

The source-local build rule is in `toolkit/xre/moz.build`:

```python
SOURCES["nsAppRunner.cpp"].flags += ["-DMOZ_XP_COMPAT"]
```

This is the accepted production remediation for:

- `GetApplicationRestartSettings`;
- `RegisterApplicationRestart`;
- `UnregisterApplicationRestart`.

## Modern UIA client detection / `GetNamedPipeServerProcessId`

Production owner: `accessible/windows/msaa/CompatibilityUIA.cpp`.

The previous idea of preserving this Win11 API through runtime lookup is superseded. The project rule is to remove modern-Windows-only functionality from the XP release when it has no useful XP semantic equivalent.

Under `MOZ_XP_COMPAT`:

- `GetUiaClientPidsWin11` is excluded;
- `GetUiaClientPidWin10` is excluded;
- `Compatibility::GetUiaClientPids` is a no-op.

Because `CompatibilityUIA.cpp` originally belonged to `UNIFIED_SOURCES`, it is moved to ordinary `SOURCES` so a source-local compatibility define can be applied without changing neighboring accessibility translation units.

The owning build rule is:

```python
SOURCES["CompatibilityUIA.cpp"].flags += ["-DMOZ_XP_COMPAT"]
```

This is the accepted production remediation for `GetNamedPipeServerProcessId`.

## Mandatory `MOZ_XP_COMPAT` contract

`MOZ_XP_COMPAT` is now the preferred project-owned compile-time signal for new XP-specific source exclusions.

For every production translation unit containing an accepted `MOZ_XP_COMPAT` boundary, the XP build MUST define the macro for that exact owner. Prefer source-local ownership rather than a global define.

If the owner is in `UNIFIED_SOURCES`, move only that source to ordinary `SOURCES` before assigning its source-specific `-DMOZ_XP_COMPAT` flag.

Existing `MOZ_NO_WINRT` source remediations remain valid and do not need to be renamed merely for consistency.

Full rules are authoritative in `XP_MOZ_XP_COMPAT_CONTRACT.md`.

## Evidence boundary and next acceptance step

The project intentionally does not require another isolated Mozilla partial build merely to re-prove these guards. Mozilla's build graph is tightly coupled, and the source/configuration changes are accepted for the next otherwise-justified full XP build.

The quartet is therefore classified as:

**SOURCE-INTEGRATED / CONDITIONALLY CLOSED**.

The next full XP browser build must still retain the inventory-driven PE/import audit. Full-browser acceptance requires the resulting production package to contain no hard imports of the quartet. Physical Windows XP startup of the exact resulting artifact remains a separate final runtime boundary.

Do not reopen this quartet merely because an older synthetic smoke or older full-build artifact predates the source changes. Reopen only on new contradictory evidence from the current or later production source lineage.

## Out of scope for this closure

This source-remediation closure does not resolve or reclassify:

- residual YY-owned KERNEL32 APIs such as `InitOnceExecuteOnce`, `GetThreadPreferredUILanguages`, `QueryFullProcessImageNameA`;
- PROPSYS (`VariantCompare`, `PropVariantToString`);
- bcrypt/One-Core work;
- GOST TLS / MSSPI / SSPI / CryptoPro / handshake work;
- Firefox 153 -> 154 base migration;
- already closed SRW/condition-variable and `CreateWaitableTimerExA` work.

Those remain separate evidence lines.