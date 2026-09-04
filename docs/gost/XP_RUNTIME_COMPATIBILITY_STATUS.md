# Windows XP SP3 x86 — runtime compatibility status

Last updated: 2026-09-04

Track: Windows XP SP3 x86 runtime compatibility only. This document does not describe or prove GOST TLS / NSS / MSSPI / CryptoPro handshake behavior and does not authorize a Firefox/r3dfox 153 -> 154 base update.

Canonical documentation branch: `agent/gost-tls-poc`.

Implementation branch: `agent/winrt-source-poc`.

Frozen baseline: `win-153`; do not modify, merge, rebase or push to it without explicit user instruction.

This is the current handoff for the physical-XP startup investigation. Read it together with `PROJECT_STATE.md`, `TEST_LOG.md`, `XP_BUILD_CONTRACT.md`, `XP_MOZ_XP_COMPAT_CONTRACT.md`, and `XP_KERNEL32_SOURCE_REMEDIATION_STATUS.md` before proposing runtime-compatibility changes.

## Exact failing browser identity

All current startup-crash conclusions are bound to this exact completed browser:

- branch `agent/winrt-source-poc`;
- source-under-test `2b1cf7e1b59881b935c7f695a54edd6b92c8066e`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `33757305364`;
- job `100654730312`;
- package artifact `9899302735`, digest `sha256:baeb2aaa2c31599da56c2b1c767bdd969914e034ab2c94826c0dd18db36d394b`;
- runtime artifact `9899304858`, digest `sha256:7d6eff6a4af1b1358f17ed1db9f9194d03702298def5708542a6510aa10029e0`;
- diagnostics artifact `9899307128`, digest `sha256:cb08028e3518d8834b50d50b9b68a98e3166a2c25a0177397214a8dabd6b3132`.

Physical results for this exact runtime artifact:

- Windows 7 x86: starts successfully and passes the user's basic/primary checks;
- Windows XP SP3 x86: fails stably immediately after launch.

The physical runtime directory used in the current XP investigation is:

```text
D:\2026\09\04\r3dfox-v153.0.3.win32.portable
```

## Startup-crash evidence progression

### Original Application Error record

```text
Faulting application r3dfox.exe, version 153.0.3.3,
faulting module kernel32.dll, version 5.1.2600.5781,
fault address 0x00012afb.
```

For this XP `kernel32.dll` family, `+0x12afb` is the `RaiseException` site. This record alone did not identify the exception class or caller.

### Dr. Watson result — exception class now known

The user ran:

```text
drwtsn32 -i
```

and received:

```text
---------------------------
Dr. Watson
---------------------------
Dr. Watson has been installed as the default application debugger
---------------------------
OK
---------------------------
```

After this, the same startup failure produced an additional Application log record at `2026-09-04 10:48:56.815`:

```text
The application, D:\2026\09\04\r3dfox-v153.0.3.win32.portable\r3dfox.exe,
generated an application error ...
The exception generated was c06d007f at address 7C812AFB
(kernel32!RaiseException)
```

Therefore the previous state `RaiseException with unknown exception code` is superseded.

`0xC06D007F` is the MSVC delay-load **procedure-not-found** exception class. It is consistent with a delay-loaded DLL being available while the requested export is absent.

## Current leading blocker — early `USER32!SetProcessDPIAware` delay-load defect

A concrete XP-incompatible startup path is now proven in the exact source and binary configuration.

### Exact source path

`browser/app/nsBrowserApp.cpp` invokes:

```text
mozilla::WindowsDpiInitialization()
```

very early in the default browser process, before `InitXPCOMGlue(...)` / XUL startup.

`mozglue/misc/WindowsDpiInitialization.cpp` contains the OS dispatch:

```text
Win10 Anniversary+  -> dynamically resolve SetProcessDpiAwarenessContext
Win8.1+             -> dynamically resolve Shcore!SetProcessDpiAwareness
otherwise           -> direct call SetProcessDPIAware()
```

Windows XP therefore reaches the final `else` and attempts `SetProcessDPIAware()` unless an explicit XP/Vista floor guard is added. The source currently has no such guard.

`WindowsVersion.h` already provides the necessary OS classification helpers including `IsVistaOrLater()` and `IsXPSP3OrLater()`. No new OS-version mechanism is required for a future minimal fix.

### Exact link/import mode

`mozglue/build/moz.build` deliberately includes:

```text
user32.dll
```

in `DELAYLOAD_DLLS`.

Exact PE diagnostics from artifact `9899307128` show `mozglue.dll` delay-imports at least:

```text
USER32.dll
    DefWindowProcW
    PeekMessageW
    SetProcessDPIAware
```

### Physical XP export baseline

The user inspected the actual XP `USER32.dll` and confirmed:

```text
DefWindowProcW      present
PeekMessageW        present
SetProcessDPIAware  absent
```

Therefore this source/runtime path is a **confirmed XP startup defect**:

```text
r3dfox.exe startup
  -> WindowsDpiInitialization()
  -> XP takes pre-Win8.1 branch
  -> SetProcessDPIAware()
  -> mozglue USER32 delay-load thunk
  -> USER32.dll loads successfully
  -> SetProcessDPIAware export is absent
  -> procedure resolution cannot succeed
```

This matches the observed `0xC06D007F` class exactly and is the current leading explanation of the stable startup crash.

### Evidence boundary before patching

Do not yet describe the individual recorded `C06D007F` event as debugger-proven `USER32!SetProcessDPIAware`. One final binding step remains: launch the application under WinDbg, break first-chance on `C06D007F`, and inspect the native stack / `DelayLoadInfo` to extract the exact DLL, procedure or ordinal, and last error.

The project intentionally chooses this debugger proof before source modification because it is cheap and prevents a coincidentally matching delay-load defect from being patched on inference alone.

No source fix has been applied yet.

## Physical XP DLL baseline

The current physical XP machine reports:

```text
%SystemRoot%\System32\propsys.dll
    File Not Found

%SystemRoot%\System32\dxgi.dll
    File Not Found

%SystemRoot%\System32\UIAutomationCore.dll
    present
    158048 bytes
    2010-03-18 10:09

%SystemRoot%\System32\ncrypt.dll
    File Not Found
```

Interpretation:

- `PROPSYS.dll` absence confirms that the already proven ordinary `xul.dll -> PROPSYS.dll` dependency is incompatible with this physical baseline unless source/build removes it or the project deliberately adopts a prerequisite/app-local replacement.
- `dxgi.dll` absence confirms that shipped `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1` cannot resolve if that PE/path is loaded.
- `ncrypt.dll` absence keeps the NCRYPT delay-load surface unresolved, but module-not-found is a different delay-load failure class from the currently observed procedure-not-found event.
- `UIAutomationCore.dll` presence eliminates the simplest missing-module hypothesis for UIA, but exact required exports/version behavior remain separate.

These are necessary compatibility-closure findings but are not automatically the current crash root cause.

## PROPSYS — proven ordinary `xul.dll` dependency

Exact diagnostics artifact `9899307128` shows final predecessor `xul.dll` has an ordinary import descriptor for:

```text
PROPSYS.dll
    PropVariantToString
    VariantCompare
```

Confirmed production owners include:

- `browser/components/shell/nsWindowsShellService.cpp` for `PropVariantToString`, with an explicit Windows `propsys` link;
- `accessible/windows/uia/UiaTextRange.cpp::CompareVariants` for `VariantCompare` on the MSVC path.

This is mandatory clean-XP static closure work because PROPSYS is absent on the current physical XP machine. It is not the current `C06D007F` explanation merely because the DLL is absent; an ordinary missing dependency and a delay-load procedure-not-found event are different boundaries.

Preferred remediation order remains source/build removal at the narrow owners before an app-local PROPSYS clone.

## `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1`

Exact diagnostics artifact `9899307128` proves shipped `libGLESv2.dll` has the ordinary dependency:

```text
dxgi.dll
    CreateDXGIFactory1
```

`dxgi.dll` is absent on the physical XP machine. This is a proven static closure defect in a separately linked shipped PE. Startup criticality is still unknown because ANGLE/GLES loading may occur dynamically and may have fallback behavior.

Do not attempt to repair this through `xul.dll` linking; `libGLESv2.dll` owns its own import table.

## Other delay/dynamic surfaces still unresolved

Raw predecessor diagnostics retain delay-load or optional modern surfaces including:

- WinRT API-set DLLs;
- `UIAutomationCore.dll` and several `Uia*` exports;
- `ncrypt.dll` with `NCryptFreeObject` / `NCryptSignHash`;
- `AVRT.dll`;
- `dwmapi.dll`;
- additional delayed post-XP exports inside otherwise present system DLLs.

Do not mass-patch them. Continue one evidence-backed runtime boundary at a time.

## KERNEL32 quartet revalidation remains separate

Predecessor final `xul.dll` diagnostics proved two ordinary survivors:

- `GetApplicationRestartSettings`;
- `GetNamedPipeServerProcessId`.

`RegisterApplicationRestart` and `UnregisterApplicationRestart` were absent.

Current XP implementation HEAD:

```text
1a86821ccf50ac07204d1bec438e375ece4e84d6
```

contains source-local `MOZ_XP_COMPAT` remediation for the remaining owners in `nsWindow.cpp` and `client_win.cc`.

Current revalidation build:

- run `33831005002`;
- job `100893816677`;
- source-under-test `1a86821...`;
- latest checked status: **IN PROGRESS**.

Do not mark the quartet closed until final `xul.dll` diagnostics from this exact run show all four names absent.

## Closed families — do not reopen for this crash

Do not restart work on these families merely because the browser is not yet starting:

- pinned/restored msvcr14x XP runtime contract;
- SRW / condition-variable closure;
- `CreateWaitableTimerExA` fallback;
- exact app-local `xp-bcrypt-v1/bcrypt.dll`;
- legacy `D3DCompiler_47.dll` package path;
- narrow YY residual KERNEL32 providers including `TryAcquireSRWLockExclusive` and `FlsGetValue`;
- the existing curated broad-gate `69 -> 3 -> 0` progression.

A new family-specific contradiction is required to reopen them.

# Next stage — step-by-step classic WinDbg session

The physical XP computer already has:

```text
Debugging Tools for Windows (x86) v6.12.2.633
```

The next chat should **start from launching the application in debug mode**, not from writing a patch.

Use exact failing runtime artifact `9899304858` / its extracted `r3dfox.exe` first so the debugger experiment is bound to the same crash already characterized by Dr. Watson.

## Step 1 — launch from the beginning under WinDbg

Open classic x86 WinDbg from Debugging Tools v6.12.2.633 and launch:

```text
D:\2026\09\04\r3dfox-v153.0.3.win32.portable\r3dfox.exe
```

Do not start by attaching after the crash. We want the earliest first-chance delay-load exception and startup stack.

## Step 2 — configure the first-chance exception break

Before continuing normal startup, configure WinDbg to stop on:

```text
0xC06D007F
```

The exact WinDbg command sequence should be worked through interactively in the next chat, one step at a time, because the old classic debugger UI/command behavior can differ from modern WinDbg documentation.

## Step 3 — capture the first relevant break

At the first `C06D007F` break, preserve at minimum:

```text
.exr -1
kv
lm
```

Then inspect the exception parameter / `DelayLoadInfo` far enough to obtain:

- DLL name;
- procedure name or ordinal;
- `dwLastError`;
- caller frames showing the startup path.

Expected high-confidence result from the current evidence is `USER32.dll!SetProcessDPIAware`, but treat the debugger output as authoritative.

## Step 4 — only after debugger proof, design the minimal source fix

If WinDbg confirms `USER32.dll!SetProcessDPIAware`, the likely source-level direction is an XP/Vista floor guard in `WindowsDpiInitialization()` so XP returns success/no-op before attempting the Vista+ DPI API.

Do not implement before the debugger capture. When implemented, prefer existing Windows-version helpers and preserve Vista+ behavior. Do not add a USER32 compatibility DLL and do not route this API through broad YY interposition.

## Step 5 — rebuild, bind exact identity, retest

Any source fix must produce a new exact source SHA, run/job, artifact IDs/hashes, final import evidence and physical XP launch result. Do not attribute the old `C06D007F` result to the new artifact.

After the DPI edge is removed, the next observed runtime boundary may be PROPSYS, DXGI, another delay-load surface, or something unrelated. Follow the actual next failure rather than assuming the queue order.

# Acceptance boundary

A future browser is not accepted as XP-compatible merely because the workflow is GREEN. Acceptance still requires:

1. exact source-under-test SHA;
2. exact run/job identity;
3. inventory-driven ordinary/delay import evidence for the shipped/runtime-required PE closure;
4. exact package/runtime/diagnostics artifact IDs and hashes;
5. physical Windows XP startup and representative browser use.

Likewise, successful XP startup does not establish any GOST TLS handshake result.