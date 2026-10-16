# 2026-09-03 — MOZ_XP_COMPAT source-level KERNEL32 closure

Track: Windows XP SP3 x86 compatibility only. This is not GOST TLS runtime/handshake evidence and is not physical-Windows-XP proof.

Implementation branch: `agent/winrt-source-poc`.

Final source/config chain recorded for this experiment:

1. `194496e76559e1d86e7e3f920fb3f1fc0e46c2d7` — `fix(xp): disable Windows Application Restart under MOZ_XP_COMPAT`;
2. `20f00258ac59296782fbaffbf0131d636c0d3c00` — `build(xp): define MOZ_XP_COMPAT for nsAppRunner`;
3. `561bded451638e599fae2d57285446261f9a0035` — `fix(xp): disable modern UIA client detection under MOZ_XP_COMPAT`;
4. `ebe325ad87232f68ca01d7e4c63be14f9c4ee74b` — `build(xp): define MOZ_XP_COMPAT for CompatibilityUIA`.

The work branch reached exact HEAD `ebe325ad87232f68ca01d7e4c63be14f9c4ee74b` after these changes.

## Application Restart trio

Production owner: `toolkit/xre/nsAppRunner.cpp`.

The accepted XP behavior is compile-time removal of the Vista+ Windows Application Restart feature. Under `MOZ_XP_COMPAT`:

- the complete `RegisterApplicationRestartChanged` definition is excluded;
- its `Preferences::RegisterCallbackAndCall(...)` registration in `XREMain::XRE_mainRun()` is excluded;
- the surrounding Windows startup block remains intact.

The owning `toolkit/xre/moz.build` applies `-DMOZ_XP_COMPAT` specifically to `nsAppRunner.cpp`.

Source-level result: the XP translation unit no longer contains the project source references to:

- `GetApplicationRestartSettings`;
- `RegisterApplicationRestart`;
- `UnregisterApplicationRestart`.

## Modern UI Automation client detection

Production owner: `accessible/windows/msaa/CompatibilityUIA.cpp`.

The XP release does not preserve Win10/Win11-only UI Automation client-detection functionality. Under `MOZ_XP_COMPAT`:

- `GetUiaClientPidsWin11` is excluded;
- `GetUiaClientPidWin10` is excluded;
- `Compatibility::GetUiaClientPids` becomes a no-op.

`CompatibilityUIA.cpp` was moved from `UNIFIED_SOURCES` to ordinary `SOURCES` so the production build can apply a source-local `-DMOZ_XP_COMPAT` flag without affecting neighboring accessibility sources.

Source-level result: the XP translation unit no longer contains the project source reference to `GetNamedPipeServerProcessId`.

## Architecture decision

The project rule is now explicit: if a modern Windows feature has no useful XP semantic equivalent and is not required by the XP product, prefer source compile-out rather than dynamic API preservation, broad YY-Thunks, or emulation.

`MOZ_XP_COMPAT` is the preferred project-owned compile-time signal for new XP-specific source exclusions. Existing `MOZ_NO_WINRT` remediations remain valid and are not renamed merely for consistency.

The mandatory build/configuration contract is documented in `XP_MOZ_XP_COMPAT_CONTRACT.md`.

## Evidence boundary

Conclusion: **SOURCE-INTEGRATED / CONDITIONALLY CLOSED.** The four KERNEL32 source-remediation APIs are considered removed at the production source/build-configuration level for the current XP line.

This experiment intentionally did not run another isolated Mozilla production-object build because the project chose not to spend additional effort on a tightly coupled partial Firefox build merely to re-prove the source guards.

Therefore this entry does not claim:

- final `xul.dll` import-table closure;
- full Firefox XP build success for HEAD `ebe325ad...`;
- package-level absence of the four imports;
- physical Windows XP startup progression.

The next otherwise-justified full XP browser build must retain the inventory-driven final PE/import audit. Physical XP remains the final runtime acceptance boundary.