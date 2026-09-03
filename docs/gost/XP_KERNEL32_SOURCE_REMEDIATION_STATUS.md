# Windows XP x86 — KERNEL32 source-remediation plan

Last updated: 2026-09-03

Track: Windows XP SP3 x86 compatibility only. This document does not describe or prove GOST TLS runtime behavior.

Canonical documentation location: `agent/gost-tls-poc:docs/gost/`.

Working implementation branch for the current XP line: `agent/winrt-source-poc`.

## Purpose

This document records the current analysis and production plan for the remaining source-remediation KERNEL32 quartet:

- `GetApplicationRestartSettings`;
- `RegisterApplicationRestart`;
- `UnregisterApplicationRestart`;
- `GetNamedPipeServerProcessId`.

It is a planning/status document, not a declaration that these imports are closed in the final Firefox binary or on physical Windows XP.

The already-proven SRW/condition-variable family, the closed `CreateWaitableTimerExA` source fallback, and the focused residual-3 YY proof (`InitOnceExecuteOnce`, `GetThreadPreferredUILanguages`, `QueryFullProcessImageNameA`) are outside this stage and must not be reopened without new contradictory evidence.

The governing remediation order remains the project XP strategy:

1. remove a modern feature from the XP build when it has no useful XP meaning;
2. use an XP-native/source fallback when useful semantics exist;
3. prefer an owned subsystem-level legacy backend when appropriate;
4. use bounded YY-Thunks only for unavoidable low-level Win32 gaps with known semantics;
5. use a project-specific shim only as a last resort.

## Current evidence identity

Focused strategy proof:

- branch: `agent/winrt-source-poc`;
- workflow: `.github/workflows/xp-kernel32-source-remediation-smoke.yml` (`XP KERNEL32 source remediation smoke`);
- source-under-test: `0450fd8f2b22b9e0263e0755e0ea52f4dd6e2aa4`;
- Actions run: `33720100459`;
- job: `100537300030` (`Application Restart + named pipe / XP x86`);
- result: **success**;
- diagnostics artifact: `9879912839` (`xp-kernel32-source-remediation-diagnostics`);
- artifact digest: `sha256:29f742d11f584a07695fcb5cfa87d5f7046e5a22d54470f3b97acb065b85b886`.

The smoke verifies the exact source ownership/call-path anchors, builds an x86 positive control and a representative remediation variant, requires the control to retain all four direct imports, requires the remediation variant to contain none of the four imports, verifies x86/subsystem 5.01, and performs hosted runtime sanity for the dynamic-lookup path.

The preceding run `33719991764`, job `100536981774`, source `95f6a680d3be006a9c9224934562e732b3e2039b`, was RED only because the `dumpbin` parser expected a bare API-name row. Its diagnostics already showed the intended import result. Commit `0450fd8f...` fixed only the parser shape; it did not change the proposed remediation semantics.

## 1. Application Restart trio — treat as one feature

### Exact owner and startup location

File: `toolkit/xre/nsAppRunner.cpp`.

Function: `RegisterApplicationRestartChanged`.

The callback registration is inside `XREMain::XRE_mainRun()`, after XPCOM/profile/preferences initialization and before the application enters its normal run loop. `Preferences::RegisterCallbackAndCall` both registers the preference callback and invokes it immediately during startup.

The function uses all three Vista+ APIs as one logical Windows Application Restart feature:

- `GetApplicationRestartSettings`;
- `RegisterApplicationRestart`;
- `UnregisterApplicationRestart`.

When enabled and not already registered, Firefox constructs its restart command line and registers with `RESTART_NO_CRASH | RESTART_NO_HANG`. When registration exists while the preference is disabled, Firefox unregisters it.

The surrounding `XP_WIN` block also initializes independent Windows facilities such as altered DLL prefetch, Launcher Process preferences, Skeleton UI/default-browser-agent preferences, and related registry state. Those adjacent facilities are **not** part of this remediation and must not be disabled merely to remove Application Restart.

### Required semantics

This integration supports Windows-driven automatic application relaunch/session restoration after relevant OS/update restart scenarios. It is not required for:

- initial Firefox process startup;
- normal profile opening;
- page loading/network operation;
- ordinary IPC;
- ordinary user-initiated browser shutdown/startup.

For the XP compatibility target, reproducing a Vista-era Application Restart facility is not a product requirement.

### Selected production remediation

**Decision accepted 2026-09-03: use dedicated `MOZ_XP_COMPAT` source guards.**

The selected production shape is deliberately narrow and has two source boundaries inside the existing Windows code:

1. wrap the complete definition of `RegisterApplicationRestartChanged` in `#  ifndef MOZ_XP_COMPAT` / `#  endif`;
2. independently wrap only its `Preferences::RegisterCallbackAndCall(...)` registration in `XREMain::XRE_mainRun()` in the same guard.

Conceptually:

```cpp
#ifdef XP_WIN
...
#  ifndef MOZ_XP_COMPAT
static void RegisterApplicationRestartChanged(const char* aPref, void* aData) {
  ...
}
#  endif
...
#endif
```

and:

```cpp
#ifdef XP_WIN
#  ifndef MOZ_XP_COMPAT
      Preferences::RegisterCallbackAndCall(
          RegisterApplicationRestartChanged,
          PREF_WIN_REGISTER_APPLICATION_RESTART);
#  endif
      SetupAlteredPrefetchPref();
      ...
#endif
```

This removes the whole optional Application Restart leaf from an XP-compatible translation unit without changing `XRE_mainRun()` itself and without touching the neighboring Windows startup integrations.

Do not implement three independent YY thunks and do not emulate a Windows facility that XP does not provide.

### Current implementation state

The source design is **settled but not yet landed**.

During the 2026-09-03 edit attempt, the available GitHub direct `update_file` operation required complete replacement contents for the very large `toolkit/xre/nsAppRunner.cpp`. Two attempted full-file writes were detected as truncated before being accepted as work. In both cases the work branch was immediately restored to the exact pre-edit HEAD `10e055bacbfb5f955b1fd3b6e986c841f08797b1`; the authoritative source blob was verified restored as `8f85b5323cda4a6444e04c8d370ff1871ad16793`.

Therefore **no production-source change is currently claimed** for `nsAppRunner.cpp`. The two guard insertions remain the accepted next edit, but must be applied through a safe exact-file editing path and then verified by a minimal diff before any build evidence is attached to them.

`MOZ_XP_COMPAT` is the accepted dedicated legacy-XP source guard. Existing `MOZ_NO_WINRT` remediations do not need to be rewritten merely to adopt the new name; new XP-specific exclusions can converge on `MOZ_XP_COMPAT` as appropriate. Wiring/defining the macro in the actual XP build configuration remains a separate implementation step and must be verified rather than assumed.

## 2. `GetNamedPipeServerProcessId` — preserve modern security semantics

### Exact owner

File: `accessible/windows/msaa/CompatibilityUIA.cpp`.

Call site: `GetUiaClientPidsWin11::QueryThreadProc`.

`Compatibility::GetUiaClientPids` selects this implementation only for `IsWin11OrLater()`; older supported Windows follows `GetUiaClientPidWin10()`.

The Win11 path enumerates candidate handles, obtains the named-pipe server PID, inspects pipe identity, and recognizes the UI Automation pipe family.

### What this is not

This call is part of accessibility / UI Automation client-detection compatibility logic.

It is not Firefox sandbox IPC validation, and `--disable-sandbox` does not remove the static source reference.

On XP the Win11 code path is semantically unreachable, but a direct static call still creates a loader-visible hard KERNEL32 import and therefore blocks XP before reachability matters.

### Required semantics

On Windows versions where this path is active, the code must continue to obtain the **real server PID from the OS**. Returning a manufactured PID, a constant success, or another fake compatibility answer would weaken the meaning of the UIA detection logic.

### Proposed remediation

**Preferred class: dynamic runtime resolution.**

Resolve `GetNamedPipeServerProcessId` from `kernel32.dll` at runtime using `GetModuleHandleW` / `GetProcAddress` (or an equivalent existing Mozilla Windows helper if one is clearly preferable after production-source review).

Behavior:

- export present: invoke the real native API with the current arguments and preserve current semantics;
- export absent: report failure for that candidate; do not fabricate a PID;
- XP: no hard import remains, and the Win11-only branch remains unreachable in normal execution.

Do not add a mechanical YY thunk or a fake server-PID implementation for this optional modern branch.

## 3. What the focused GREEN proves

Run `33720100459` is sufficient evidence that the proposed **mechanisms** can remove the four hard imports in a representative x86/XP-floor link while preserving the intended dynamic native-call behavior.

It proves:

- all four direct imports exist in the positive-control build;
- all four are absent from the representative remediation build;
- the resulting probe is x86 with subsystem 5.01;
- the dynamic lookup variant executes successfully on the hosted Windows runner;
- the exact Firefox source ownership/call-path assumptions used by the probe matched source at `0450fd8f...`.

It does **not** prove:

- the production Firefox source has been changed;
- the exact Firefox objects compile with `MOZ_XP_COMPAT`;
- the actual XP build defines `MOZ_XP_COMPAT` at the required owners;
- final `xul.dll` has lost the four imports;
- another owner/toolchain path does not reintroduce them;
- the browser starts on physical Windows XP.

Therefore these APIs are **strategy-GREEN, production-open**.

## 4. Proposed work sequence

### Step A — land and wire `MOZ_XP_COMPAT`

The source boundary is now decided. Apply the two exact Application Restart guards in `agent/winrt-source-poc/toolkit/xre/nsAppRunner.cpp` and ensure the XP build configuration defines `MOZ_XP_COMPAT` for this translation unit.

Acceptance criteria:

- minimal source diff: only definition guard + registration guard for Application Restart;
- neighboring Windows startup facilities unchanged;
- normal non-XP Windows behavior unchanged;
- the XP translation unit does not compile the three Application Restart API references.

### Step B — integrate named-pipe runtime resolution

Replace the direct `GetNamedPipeServerProcessId` call in the Win11 UIA path with bounded runtime resolution.

Acceptance criteria:

- modern Windows still calls the real `GetNamedPipeServerProcessId` export;
- missing export is a normal negative result for that candidate;
- no fake PID or weakened validation semantics;
- XP object/link has no hard `GetNamedPipeServerProcessId` import.

### Step C — exact affected-target proof before another heavy build

Do **not** request another multi-hour full Firefox build solely to learn whether these source edits compile or whether the four symbols remain referenced.

First run the cheapest production-representative proof available for the exact affected Firefox targets/objects.

The proof should establish at minimum:

- exact branch and source-under-test SHA;
- exact compiler configuration used by the XP build;
- successful compilation of the affected production translation units/targets;
- symbol/import inspection sufficient to show the four direct KERNEL32 references are absent from the affected production output;
- no regression of the existing narrow XP compatibility provider/link setup.

If build-system structure makes an isolated final-PE import proof impractical, use the narrowest target build that actually links the relevant object into its real owner. Do not replace a meaningful target proof with another synthetic-only probe: the synthetic strategy proof is already GREEN.

### Step D — consume the result in the next necessary full Firefox build

Only after the exact production-target proof is GREEN should these changes ride the next full XP Firefox validation that is already technically justified by the broader compatibility queue.

That full run must retain the project’s inventory-driven PE audit. A curated four-name gate may be retained as a regression check, but it is not the final compatibility proof.

Acceptance for this quartet at full-browser level requires the exact produced `xul.dll` / package inventory to contain none of the four hard imports.

### Step E — physical XP progression

Even a GREEN full-browser import audit does not prove runtime closure.

The exact resulting artifact must be launched on physical Windows XP and the runtime result must be bound to its source SHA, Actions run/job, artifact identity, and binary hashes where applicable.

The current physical loader edge remains `InitOnceExecuteOnce` until a newer exact physical-XP artifact advances beyond it. Do not claim this quartet as the physical loader blocker or as physically closed without such evidence.

## 5. Deliberately excluded work

This stage must not be mixed with:

- PROPSYS (`VariantCompare`, `PropVariantToString`);
- WinRT delayed-import/source-removal work;
- BCrypt/One-Core changes;
- GOST TLS / MSSPI / SSPI / CryptoPro / handshake work;
- Firefox 153 -> 154 base migration;
- reopening the already-proven SRW/condition-variable family;
- rebuilding already approved `xp-bcrypt-v1`;
- broad YY `kernel32.lib` interposition.

Those have separate ownership/evidence tracks.

## 6. Remaining discussion points

The Application Restart architecture is now settled. Remaining design questions for this quartet are:

1. where `MOZ_XP_COMPAT` should be defined in the XP build configuration so both current and future XP-specific source exclusions receive it intentionally;
2. whether the named-pipe resolver should be local to `CompatibilityUIA.cpp` or use an existing Mozilla helper if an equivalent bounded helper already exists;
3. what the cheapest exact production target is that gives meaningful compile/symbol/import evidence for both source owners.

## Recommended decision

Proceed with the accepted architecture:

- Application Restart trio -> two narrow `MOZ_XP_COMPAT` compile-time guards, around the callback definition and its registration only;
- leave the surrounding Windows startup integrations untouched;
- `GetNamedPipeServerProcessId` -> native API preserved through bounded runtime lookup;
- then exact production-target compilation/symbol proof;
- then inclusion in the next otherwise-justified full XP build;
- finally physical-XP validation as part of the broader loader progression.

This preserves the project rule that an API inventory is not an automatic YY backlog and avoids spending compatibility surface on modern facilities that XP either does not need or cannot execute.