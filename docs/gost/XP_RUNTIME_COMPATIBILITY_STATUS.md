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

### Dr. Watson result — exception class identified

The user ran `drwtsn32 -i` and installed Dr. Watson as the default application debugger. The same startup failure then produced an Application log record at `2026-09-04 10:48:56.815`:

```text
The application, D:\2026\09\04\r3dfox-v153.0.3.win32.portable\r3dfox.exe,
generated an application error ...
The exception generated was c06d007f at address 7C812AFB
(kernel32!RaiseException)
```

This superseded the earlier state `RaiseException with unknown exception code`.

`0xC06D007F` is the MSVC delay-load **procedure-not-found** exception class: the DLL load can succeed while the requested delayed procedure cannot be resolved.

### WinDbg result — exact delay-load target identified

The exact same runtime artifact was launched from process start under:

```text
Microsoft (R) Windows Debugger Version 6.12.0002.633 X86
```

WinDbg stopped on the first-chance exception:

```text
Unknown exception - code c06d007f (first chance)
```

At that break, `.exr -1` reported:

```text
ExceptionAddress: 7c812afb (kernel32!RaiseException+0x53)
ExceptionCode: c06d007f
NumberParameters: 1
Parameter[0]: 001bfb70
```

The x86 `DelayLoadInfo` at `001bfb70` decoded as:

```text
cb              = 00000024
szDll           = "USER32.dll"
fImportByName   = 00000001
szProcName      = "SetProcessDPIAware"
hmodCur         = 7e410000
pfnCur          = 00000000
dwLastError     = 0000007f
```

Raw debugger commands/results included:

```text
dd 001bfb70 L9
001bfb70  00000024 1008a5c4 100943cc 1008ab72
001bfb80  00000001 1008aaf4 7e410000 00000000
001bfb90  0000007f

da 1008ab72
1008ab72  "USER32.dll"

da 1008aaf4
1008aaf4  "SetProcessDPIAware"
```

Therefore the exact recorded `C06D007F` instance is debugger-bound to:

```text
USER32.dll!SetProcessDPIAware
```

with the DLL already loaded (`hmodCur=7e410000`), no resolved target (`pfnCur=0`), and `ERROR_PROC_NOT_FOUND` (`dwLastError=0x7f`).

## Confirmed current root cause — early `USER32!SetProcessDPIAware` delay-load failure

The source, PE and physical-XP evidence all converge on the same path.

### Exact source path

`browser/app/nsBrowserApp.cpp` invokes:

```text
mozilla::WindowsDpiInitialization()
```

very early in the default browser process, before `InitXPCOMGlue(...)` / XUL startup.

`mozglue/misc/WindowsDpiInitialization.cpp` dispatches approximately as:

```text
Win10 Anniversary+  -> SetProcessDpiAwarenessContext
Win8.1+             -> Shcore!SetProcessDpiAwareness
otherwise           -> SetProcessDPIAware()
```

Windows XP reaches the final fallback and attempts `SetProcessDPIAware()` because there is no explicit pre-Vista guard.

`WindowsVersion.h` already provides helpers including `IsVistaOrLater()` and `IsXPSP3OrLater()`. No new OS-version mechanism is needed for the minimal remediation.

### Exact link/import mode

`mozglue/build/moz.build` places `user32.dll` in `DELAYLOAD_DLLS`.

Exact PE diagnostics from artifact `9899307128` show `mozglue.dll` delay-imports:

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

### Root-cause chain

The currently observed immediate XP startup failure for runtime artifact `9899304858` is therefore **confirmed** as:

```text
r3dfox.exe startup
  -> WindowsDpiInitialization()
  -> XP takes the pre-Win8.1 fallback
  -> SetProcessDPIAware()
  -> mozglue USER32 delay-load thunk
  -> USER32.dll loads successfully
  -> SetProcessDPIAware is absent
  -> procedure resolution fails with ERROR_PROC_NOT_FOUND (0x7f)
  -> MSVC delay helper raises C06D007F
  -> kernel32!RaiseException
```

No further debugger proof is needed for this same edge before source remediation.

A secondary `C0000005` at `EIP=00000000` was observed only after the original delay-load exception was allowed to continue in an earlier debugger attempt. That access violation is classified as downstream/secondary evidence, not the primary blocker, unless it survives after the confirmed delay-load root cause is removed.

## Next stage — minimal source remediation

The next experiment is now source-first for this one confirmed edge.

Preferred direction in `mozglue/misc/WindowsDpiInitialization.cpp`:

```cpp
if (!IsVistaOrLater()) {
  return WindowsDpiInitializationResult::Success;
}
```

The guard should execute before the Vista+ DPI-awareness APIs are attempted, leaving Vista and later behavior unchanged.

Before editing, re-read the exact current implementation-branch file and its build ownership. Then:

1. implement only the narrow pre-Vista no-op guard;
2. do not add a USER32 compatibility DLL;
3. do not route the API through broad YY interposition;
4. do not globalize `MOZ_XP_COMPAT` merely for this fix;
5. build a new exact source SHA;
6. bind the resulting run/job/artifacts and PE diagnostics;
7. retest on physical XP and follow the next actual runtime boundary.

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
- `ncrypt.dll` absence keeps the NCRYPT delay-load surface unresolved, but module-not-found is a different delay-load failure class from the confirmed USER32 procedure-not-found event.
- `UIAutomationCore.dll` presence eliminates the simplest missing-module hypothesis for UIA, but exact required exports/version behavior remain separate.

These remain necessary compatibility-closure findings but are not the cause of the confirmed current startup exception.

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

This is mandatory clean-XP static closure work because PROPSYS is absent on the current physical XP machine. It is not the current `C06D007F` cause; that event is now bound specifically to USER32/SetProcessDPIAware.

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

# Acceptance boundary

A future browser is not accepted as XP-compatible merely because the workflow is GREEN. Acceptance still requires:

1. exact source-under-test SHA;
2. exact run/job identity;
3. inventory-driven ordinary/delay import evidence for the shipped/runtime-required PE closure;
4. exact package/runtime/diagnostics artifact IDs and hashes;
5. physical Windows XP startup and representative browser use.

Likewise, successful XP startup does not establish any GOST TLS handshake result.