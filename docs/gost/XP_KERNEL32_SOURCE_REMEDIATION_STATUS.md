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

## Focused proof

Workflow: `.github/workflows/xp-kernel32-source-remediation-smoke.yml` (`XP KERNEL32 source remediation smoke`).

Source-under-test: `4e2140df7dd3f6618827f75a0f2235d3d7e02fee`.

Actions run: `33719833750`.

Job: `100536521230` (`Application Restart + named pipe / XP x86`).

Current status at this checkpoint: **in progress**.

The smoke is intentionally low-cost and fail-closed. It verifies the exact Firefox ownership/call-path anchors in the checked-out Firefox 153 source, builds x86 representative positive-control and remediation variants, requires the control to retain all four direct hard imports, requires the remediation variant to contain none of the four imports, verifies PE x86/subsystem 5.01, and runs the dynamic-lookup variant on the hosted Windows runner. Hosted runtime success is not physical Windows XP proof.

Do not promote this hypothesis to full Firefox closure until the focused smoke is GREEN and the production source change is later carried through the normal full-browser import inventory and physical-XP progression.
