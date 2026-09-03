# XP KERNEL32 source-remediation status

Last updated: 2026-09-03

Track: Windows XP SP3 x86 compatibility only. This document does not describe GOST TLS runtime behavior.

## Scope

This status covers the remaining source-remediation KERNEL32 quartet after the focused-proven residual-3 cluster:

- `GetApplicationRestartSettings`
- `RegisterApplicationRestart`
- `UnregisterApplicationRestart`
- `GetNamedPipeServerProcessId`

The SRW/condition-variable baseline, `CreateWaitableTimerExA`, and the focused residual-3 YY proof are not reopened here.

## Application Restart trio

Exact owner: `toolkit/xre/nsAppRunner.cpp`, function `RegisterApplicationRestartChanged`.

The function is registered through `Preferences::RegisterCallbackAndCall` for `PREF_WIN_REGISTER_APPLICATION_RESTART` (`toolkit.winRegisterApplicationRestart`). It first calls `GetApplicationRestartSettings` to determine whether the process is already registered. If the preference is enabled and Firefox is not registered, it constructs a restart command line and calls `RegisterApplicationRestart` with `RESTART_NO_CRASH | RESTART_NO_HANG`. If registration exists while the preference is disabled, it calls `UnregisterApplicationRestart`.

Semantics: this is Windows Application Restart / restart-after-update-or-OS-restart integration. It is not required for ordinary browser process startup, page loading, IPC, profile access, or normal shutdown. Disabling it on the XP-target legacy configuration only removes automatic OS-driven relaunch/session-resume integration.

Chosen remediation: **source-level removal/fallback for the legacy XP configuration**. The preferred production change is to make `RegisterApplicationRestartChanged` a no-op under the legacy XP build define so none of the three Vista+ APIs contribute hard imports. Do not add three YY thunks for an optional integration feature.

## `GetNamedPipeServerProcessId`

Exact owner: `accessible/windows/msaa/CompatibilityUIA.cpp`.

Call site: `GetUiaClientPidsWin11::QueryThreadProc`. The Windows 11 UIA compatibility detector enumerates candidate handles, treats Firefox as the named-pipe client, calls `GetNamedPipeServerProcessId` to obtain the remote UIA server PID, then checks pipe names and returns matching client PIDs. `Compatibility::GetUiaClientPids` selects this path only when `IsWin11OrLater()` is true; older Windows uses `GetUiaClientPidWin10`.

This is accessibility/UI Automation client-detection compatibility logic. It is **not Firefox sandbox IPC**, and `--disable-sandbox` does not remove its source reference. On Windows XP the Win11 path is semantically unreachable, but a normal static call still creates a loader-visible hard KERNEL32 import.

Chosen remediation: **dynamic runtime lookup**, not a stub and not a YY thunk. Resolve `GetNamedPipeServerProcessId` from `kernel32.dll` with `GetProcAddress` at the Win11 call site. On Win11 the same OS API and security semantics are preserved. If the export is unavailable, return failure for that candidate instead of manufacturing a PID. This removes the XP loader dependency while preserving modern behavior.

## Focused proof — GREEN

Workflow: `.github/workflows/xp-kernel32-source-remediation-smoke.yml` (`XP KERNEL32 source remediation smoke`).

Branch: `agent/winrt-source-poc`.

Source-under-test: `0450fd8f2b22b9e0263e0755e0ea52f4dd6e2aa4` (`ci(xp): fix dumpbin import parser in remediation smoke`).

Actions run: `33720100459`.

Job: `100537300030` (`Application Restart + named pipe / XP x86`).

Result: **success**.

Diagnostics artifact: `9879912839` (`xp-kernel32-source-remediation-diagnostics`), digest `sha256:29f742d11f584a07695fcb5cfa87d5f7046e5a22d54470f3b97acb065b85b886`.

The smoke is intentionally low-cost and fail-closed. It sparse-checks out the two exact Firefox source owners, verifies the expected call-path anchors, builds x86 representative positive-control and remediation variants, requires the control to retain all four direct hard imports, requires the remediation variant to contain none of the four imports, verifies PE x86/subsystem 5.01, and runs the dynamic-lookup variant on the hosted Windows runner.

The immediately preceding run `33719991764`, job `100536981774`, source `95f6a680d3be006a9c9224934562e732b3e2039b`, was RED only because the gate parser expected a bare dumpbin API row. Its uploaded diagnostics already showed the intended semantic result: the control imported all four APIs while the remediation probe imported none. Commit `0450fd8f...` corrected the parser to accept dumpbin's ordinal/name row shape; no remediation semantics changed between those runs.

## Evidence boundary and next integration step

This GREEN closes the **representative source-remediation strategy proof** for the quartet. It does not yet prove that Firefox production objects or final `xul.dll` are free of the imports, and hosted Windows runtime is not physical Windows XP proof.

Next production integration should therefore be:

1. make `RegisterApplicationRestartChanged` a legacy-XP compile-time no-op as one unit for the three Application Restart APIs;
2. convert the Win11 UIA `GetNamedPipeServerProcessId` call to runtime resolution while preserving native behavior when the export exists;
3. compile the exact affected Firefox targets/objects and inspect symbols/imports before requesting another full Firefox build solely for this quartet;
4. later require the existing inventory-driven full-browser PE audit and physical XP startup progression to confirm closure.

Do not use broad YY `kernel32.lib`, do not add mechanical stubs, and do not interpret this focused GREEN as full-browser or physical-XP closure.
