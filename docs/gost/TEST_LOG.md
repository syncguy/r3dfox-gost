# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-01_pre_bcrypt_closure.md`](./TEST_LOG_2026-09-01_pre_bcrypt_closure.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-04 — full XP x32 Firefox integrates `NtCancelIoFileEx` YY closure; aggregate RED only on DXGI

Track: Windows XP SP3 x86 compatibility / full Firefox 153 x32 integration and static dependency closure only. This is not physical-XP browser runtime proof and not GOST TLS runtime/handshake evidence.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `622a87625036e9c45a8650264336eceeb9be8753` (`fix(xp): restore Rust target expression`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33864176444`, attempt `1`;
- job `100995134125` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate job conclusion: **failure** only at final `GATE - Summarize XP x32 full build` after evidence collection.

Exact artifacts:

- package artifact `9937354583`, `327799880` bytes, digest `sha256:9457e3d5102bd60caa4f1cdf23a432fa21444efdd34054e688c1a8f507dc5e98`;
- runtime artifact `9937355457`, `74916090` bytes, digest `sha256:5f60d06985e20282bf4a231a28e2bc5d8945c71ba6e92739ee162b510fda91dd`;
- diagnostics artifact `9937356676`, `5960909` bytes, digest `sha256:88b416d3042522a2284c33617267878bb035dd750f5275aa6de98deacd8e55f6`.

All substantive boundaries before the aggregate RED completed successfully, including pinned msvcr14x, narrow YY provider build/activation, Firefox configure/export/SSL target-object gate, full release build, strict quartet gate, `mozglue` DPI delay-import gate, production core-browser direct-import gate, CRT/D3DCompiler/bcrypt staging and package-survival gates, package creation, runtime archive creation, final PE/import audit, and all three artifact uploads.

Exact diagnostics from artifact `9937356676` establish the full Firefox transfer of the focused `NtCancelIoFileEx` solution. `diagnostics/yy-ntcancel-capability.txt` records:

```text
capability=PASS
evidence_run=33861819326
evidence_job=100987750213
evidence_sha=be122cfc36d84e3144b73bcbaa2a2f46ff45f1a2
```

The final direct-import inventory contains:

```text
xul.dll|API|NtCancelIoFile
```

and contains no `NtCancelIoFileEx`. Therefore the XP-incompatible native import is no longer present in final production `xul.dll`; the integrated narrow YY path leaves the XP-present `NtCancelIoFile` boundary instead. This is the full-Firefox integration proof that was deliberately left open by focused run `33861819326`.

Other exact regression evidence remains green:

```text
xp-x32-source-remediation-quartet/result.txt
result=PASS|surviving=none

xp-x32-dpi-delay-import/result.txt
result=PASS|direct=0|delay_user32=1
```

The broad forbidden-direct-import report has improved from the predecessor run's two rows (`PROPSYS + DXGI`) to exactly one row:

```text
libGLESv2.dll|DLL|dxgi.dll
```

The matching direct-import inventory records `CreateDXGIFactory1`. There is no `xul.dll|DLL|PROPSYS.dll` row in this run, so the prior PROPSYS ordinary-dependency blocker is closed/superseded at current final-binary static-import level.

Conclusion: **FULL-INTEGRATION PASS FOR `NtCancelIoFileEx` YY CLOSURE / PROPSYS STATIC GAP CLOSED / AGGREGATE STATIC-CLOSURE RED ONLY ON `libGLESv2.dll -> dxgi.dll`.** The overall Actions result remains correctly RED because the final summary promotes the surviving DXGI finding. It is not a compile, link, package, `NtCancelIoFileEx`, quartet, DPI, CRT, bcrypt, or PROPSYS regression.

Evidence boundary: this run proves full-build/final-PE integration only. Runtime artifact `9937355457` has not by this evidence been accepted on physical Windows XP, so it does not prove browser startup, ordinary browsing, ANGLE path behavior, or any GOST TLS handshake. The next current broad static blocker is the separately linked `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1` line and must be treated at the ANGLE/graphics component boundary rather than through the `xul.dll` linker.

---

## 2026-09-04 — focused `NtCancelIoFileEx` XP x86 probe passes through narrow YY-Thunks provider

Track: Windows XP SP3 x86 compatibility / focused KERNEL32 import closure only. This is not full Firefox integration, physical-XP browser runtime proof, or GOST TLS runtime/handshake evidence.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `be122cfc36d84e3144b73bcbaa2a2f46ff45f1a2` (`test(xp): fix NtCancelIoFileEx import gate`);
- workflow `.github/workflows/xp-core-kernel32-cluster-smoke.yml` / `XP x86 core KERNEL32 cluster smoke`;
- Actions run `33861819326`, attempt `1`;
- job `100987750213`;
- aggregate run/job conclusion: **success**.

The exact job completed all YY provider preparation/link/import-gate steps successfully, including:

- `Download YY-Thunks 1.2.2 XP x86 libraries` — **success**;
- `Build physically narrow YY provider` — **success**;
- `GATE - PE contract and direct imports` — **success**;
- dedicated `Build and run NtCancelIoFileEx YY probe` — **success**;
- physical XP runtime-bundle construction and diagnostics upload — **success**.

Conclusion: **PASS / FOCUSED `NtCancelIoFileEx` YY-THUNKS CLOSURE PROVEN.** For XP x86, the project's narrow YY provider can satisfy the dedicated `NtCancelIoFileEx` probe without reopening or adopting full YY `kernel32.lib` interposition. This closes the question of whether YY-Thunks provides a viable focused implementation path for this API.

Evidence boundary: this focused smoke does **not** prove that a later full Firefox `xul.dll` no longer carries an unresolved XP-incompatible `NtCancelIoFileEx` import, does not prove full-browser startup on physical XP, and does not prove any GOST TLS behavior. That full-integration boundary is now superseded by the immediately preceding entry for source `622a876...`, run `33864176444`, job `100995134125`.

---

## 2026-09-04 — DPI functional-remediation full build/packages produced; aggregate RED only on two known clean-XP DLL dependencies

Track: Windows XP SP3 x86 compatibility / full Firefox 153 x32 build and static dependency closure only. This is not physical-XP runtime proof and not GOST TLS runtime/handshake evidence.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `424708f1d8e754f752e108259b331fcd2ec3615b`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33842067157`, attempt `1`;
- job `100926221307` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate job conclusion: **failure** at the final `GATE - Summarize XP x32 full build`.

Exact artifacts:

- package artifact `9927581628`, `327758670` bytes, digest `sha256:ba0e7d77368e1503288902854ab8542a4aa5beda0f307f4aafffff5ee9200bc7`;
- runtime artifact `9927582490`, `74916467` bytes, digest `sha256:03d099306dd2632eabc604e1333001eca3b149c4b7b798e0f2c88269139c70a6`;
- diagnostics artifact `9927583461`, `5953888` bytes, digest `sha256:c85c7a837b7772d89bd5bef1cf750b889165e73fc6f4755b89bcd9bda5068483`.

All substantive build/package/upload boundaries before the aggregate RED completed successfully, including the DPI source guard, pinned msvcr14x contract, narrow YY provider, Firefox configure/export and SSL target-object gate, full release build, strict source-remediation quartet gate, `mozglue` DPI import-mode gate, production core-browser direct-import gate, D3DCompiler/CRT/bcrypt staging and package-survival gates, portable package, physical-test runtime archive, final PE/import inventory collection, and all three artifact uploads.

Exact diagnostics from artifact `9927583461` establish:

```text
xp-x32-source-remediation-quartet/result.txt
result=PASS|surviving=none

xp-x32-dpi-delay-import/result.txt
result=PASS|direct=0|delay_user32=1

xp-x32-dpi-delay-import/setprocessdpiaware-import-mode.txt
delay|USER32.dll|... SetProcessDPIAware
```

Thus the hardened quartet remains closed at 0/4 in the final `xul.dll`, and `SetProcessDPIAware` is not an ordinary `mozglue.dll` import; the expected USER32 delay-load entry remains present. The source-level pre-Vista DPI guard also passed before the build.

The broad clean-XP import inventory is the reason this otherwise build-complete run is aggregate RED. Its exact `xp-x32-forbidden-direct-imports.txt` contains only two rows:

```text
libGLESv2.dll|DLL|dxgi.dll
xul.dll|DLL|PROPSYS.dll
```

These are the already identified static clean-XP dependency gaps: shipped `libGLESv2.dll -> dxgi.dll` and final `xul.dll -> PROPSYS.dll`. They are not evidence that either path is the next physical startup failure; that requires runtime evidence from the exact artifact.

Important evidence boundary: this run tests the functional pre-Vista DPI remediation present through `fad9ec0b5a09c50f6cff39a00a3ea4cedd99cdf2` plus the hardened workflow gates in source `424708f...`. It does **not** test the later project-ownership refinements `a784a7660b23f8270179f5464c2ac3033d7e0652` (`#ifdef MOZ_XP_COMPAT`) and `a3ede2576cbc7e92ffae58ba0c49d2c38e580335` (source-local `-DMOZ_XP_COMPAT`). Do not attribute this run or its artifacts to those later commits.

Conclusion: **FUNCTIONAL DPI REMEDIATION FULL-BUILD/PACKAGE PASS; AGGREGATE STATIC-CLOSURE RED ON EXACTLY PROPSYS + DXGI.** This historical status is superseded for current static closure by run `33864176444`, which removes the PROPSYS row and leaves only DXGI. No GOST TLS conclusion follows.

---

## 2026-09-04 — first final production `xul.dll` 0/4 closure for the KERNEL32 source-remediation quartet

Track: Windows XP SP3 x86 compatibility / final Firefox binary import closure only. This is not physical-XP runtime proof and not GOST TLS runtime/handshake evidence.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `1a86821ccf50ac07204d1bec438e375ece4e84d6` (`client_win.cc avoid a hard GetNamedPipeServerProcessId import on Windows XP`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33831005002`, attempt `1`;
- job `100893816677`;
- aggregate run/job conclusion: **success**.

Exact artifacts:

- package artifact `9924336481`, digest `sha256:60b6cdd1c87344d467531d4541b6ec0d5ca955dae942f5b7165bd773ec2906f0`;
- runtime artifact `9924337378`, digest `sha256:abaecbfedae0adce9f819b2f1ad05c36ed027a340c5d245a71b5fe9b8bc82e67`;
- diagnostics artifact `9924338342`, digest `sha256:aca17ca427c5f55ccb1a7f838a9d82ae1e07bc68b12cd1061173fb81699a3b09`.

The exact diagnostics artifact contains:

```text
xp-x32-source-remediation-quartet/result.txt
result=PASS|surviving=none
```

The matching final `xul.dll` ordinary-import dump contains none of the four source-remediation names:

```text
GetApplicationRestartSettings
RegisterApplicationRestart
UnregisterApplicationRestart
GetNamedPipeServerProcessId
```

This is the first recorded final-production `0/4` binary evidence in the current remediation lineage. The predecessor full-build diagnostics from source `2b1cf7e1b59881b935c7f695a54edd6b92c8066e`, run `33757305364`, job `100654730312`, still had exactly two survivors: `GetApplicationRestartSettings` and `GetNamedPipeServerProcessId`.

Gate-history distinction: on source `1a86821...`, the quartet step was still informational (`DIAG - Check source-remediation quartet absent from xul.dll`). Starting with later workflow commit `424708f1d8e754f752e108259b331fcd2ec3615b`, the same quartet condition became an evidence-preserving final gate: artifacts may still upload, but any survivor makes the final verdict RED. Therefore run `33831005002` establishes the first recorded final-binary closure; later runs, including `33864176444`, establish hardened regression-gate behavior and unrelated subsequent remediation.

Conclusion: **PASS / FINAL PRODUCTION `xul.dll` QUARTET CLOSED AT 0/4 ORDINARY IMPORTS.** This closes only this static import-remediation line. It does not prove full clean-XP dependency closure, physical Windows XP startup, or any GOST TLS behavior.

---

## 2026-09-04 — WinDbg `DelayLoadInfo` proves the immediate XP crash is `USER32.dll!SetProcessDPIAware` procedure-not-found

Track: Windows XP SP3 x86 compatibility / physical startup diagnosis only. This is not GOST TLS runtime/handshake evidence.

Exact failing browser identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `2b1cf7e1b59881b935c7f695a54edd6b92c8066e`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33757305364`;
- job `100654730312`;
- runtime artifact `9899304858`;
- diagnostics artifact `9899307128`;
- physical runtime directory `D:\2026\09\04\r3dfox-v153.0.3.win32.portable`.

Debugger environment:

```text
Microsoft (R) Windows Debugger Version 6.12.0002.633 X86
```

The exact browser was launched from process start under WinDbg. At the first-chance delay-load exception WinDbg reported:

```text
Unknown exception - code c06d007f (first chance)
```

`.exr -1` at that exact break produced:

```text
ExceptionAddress: 7c812afb (kernel32!RaiseException+0x53)
ExceptionCode: c06d007f
ExceptionFlags: 00000000
NumberParameters: 1
Parameter[0]: 001bfb70
```

`Parameter[0]` was then decoded as the x86 `DelayLoadInfo` structure. Raw memory:

```text
0:000> dd 001bfb70 L9
001bfb70  00000024 1008a5c4 100943cc 1008ab72
001bfb80  00000001 1008aaf4 7e410000 00000000
001bfb90  0000007f
```

String fields:

```text
0:000> da 1008ab72
1008ab72  "USER32.dll"

0:000> da 1008aaf4
1008aaf4  "SetProcessDPIAware"
```

Decoded values:

```text
cb              = 00000024
szDll           = "USER32.dll"
fImportByName   = 00000001
szProcName      = "SetProcessDPIAware"
hmodCur         = 7e410000
pfnCur          = 00000000
dwLastError     = 0000007f
```

Interpretation:

- `USER32.dll` is successfully loaded in the failing process (`hmodCur=7e410000`);
- the delayed import is being resolved by name;
- the exact requested procedure is `SetProcessDPIAware`;
- resolution failed (`pfnCur=0`);
- the last error is `0x7f`, `ERROR_PROC_NOT_FOUND`;
- the delay-load helper raises `0xC06D007F` as observed by Dr. Watson and WinDbg.

This is independently consistent with the physical XP export check: the actual `USER32.dll` contains `DefWindowProcW` and `PeekMessageW` but does not export `SetProcessDPIAware`.

Exact source/build evidence for the same path remains:

- `browser/app/nsBrowserApp.cpp` invokes `mozilla::WindowsDpiInitialization()` before `InitXPCOMGlue(...)` / XUL startup;
- `mozglue/misc/WindowsDpiInitialization.cpp` sends pre-Windows-8.1 systems to a fallback that directly calls `SetProcessDPIAware()`;
- XP therefore attempts a Vista+ API because no explicit pre-Vista guard exists;
- `mozglue/build/moz.build` places `user32.dll` in `DELAYLOAD_DLLS`;
- diagnostics artifact `9899307128` proves final `mozglue.dll` delay-imports `USER32.dll!SetProcessDPIAware`.

The complete current root-cause chain for runtime artifact `9899304858` is therefore confirmed:

```text
r3dfox.exe startup
  -> WindowsDpiInitialization()
  -> XP enters the pre-Win8.1 fallback
  -> SetProcessDPIAware()
  -> mozglue USER32 delay-load thunk
  -> USER32.dll loads
  -> SetProcessDPIAware is absent
  -> ERROR_PROC_NOT_FOUND (0x7f)
  -> C06D007F
  -> kernel32!RaiseException
```

An earlier debugger attempt allowed the delay-load exception to continue and then observed a secondary `C0000005` with `EIP=00000000`. That later access violation is classified as downstream of the unhandled confirmed delay-load failure, not as the primary blocker, unless it remains after the root cause is removed.

Conclusion: **CONFIRMED ROOT CAUSE for the immediate physical-XP startup failure of exact runtime artifact `9899304858`: `USER32.dll!SetProcessDPIAware` delay-load procedure-not-found.** The previous status `exact DelayLoadInfo confirmation pending` is superseded.

Next experiment: review the current `agent/winrt-source-poc` implementation of `mozglue/misc/WindowsDpiInitialization.cpp` and apply the narrowest pre-Vista no-op guard using the existing Windows-version helpers, conceptually `if (!IsVistaOrLater()) return Success;`. Do not add a USER32 shim, broad YY provider or global `MOZ_XP_COMPAT` change. Rebuild under a new exact source SHA and bind the next physical-XP result to that new run/artifact before interpreting the next startup boundary.

---

## 2026-09-04 — Dr. Watson identifies `0xC06D007F`; XP startup contains a proven `USER32.dll!SetProcessDPIAware` delay-load defect

Track: Windows XP SP3 x86 compatibility / physical startup diagnosis only. This is not GOST TLS runtime/handshake evidence.

Exact failing browser identity remains:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `2b1cf7e1b59881b935c7f695a54edd6b92c8066e`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33757305364`;
- job `100654730312`;
- runtime artifact `9899304858`;
- diagnostics artifact `9899307128`;
- physical runtime directory used for the reproduced launch: `D:\2026\09\04\r3dfox-v153.0.3.win32.portable`.

After `drwtsn32 -i` had installed Dr. Watson as the default application debugger, the same stable XP startup failure produced an additional Application log record at `2026-09-04 10:48:56.815`:

```text
The application, D:\2026\09\04\r3dfox-v153.0.3.win32.portable\r3dfox.exe,
generated an application error ...
The exception generated was c06d007f at address 7C812AFB
(kernel32!RaiseException)
```

This supersedes the earlier classification `RaiseException with unknown exception code`. `0xC06D007F` is the MSVC delay-load **procedure-not-found** exception class: the target DLL can be loaded but a requested delayed import cannot be resolved by name/ordinal.

Physical XP system-DLL baseline recorded before any compatibility changes:

```text
%SystemRoot%\System32\propsys.dll          absent
%SystemRoot%\System32\dxgi.dll             absent
%SystemRoot%\System32\UIAutomationCore.dll present, 158048 bytes, 2010-03-18 10:09
%SystemRoot%\System32\ncrypt.dll           absent
```

The user additionally inspected the physical XP `USER32.dll` export surface and confirmed:

```text
DefWindowProcW      present
PeekMessageW        present
SetProcessDPIAware  absent
```

Exact source/build evidence for the DPI path on source `2b1cf7e...`:

- `browser/app/nsBrowserApp.cpp` calls `mozilla::WindowsDpiInitialization()` very early in the default browser process, before `InitXPCOMGlue(...)` / XUL startup;
- `mozglue/misc/WindowsDpiInitialization.cpp` branches to the final `else` for systems older than Windows 8.1 and directly calls `SetProcessDPIAware()`; there is no XP-specific guard before that call;
- the same source already contains `IsVistaOrLater()` / `IsXPSP3OrLater()` helpers through `WindowsVersion.h`, so the OS distinction is available without inventing a new detection mechanism;
- `mozglue/build/moz.build` deliberately places `user32.dll` in `DELAYLOAD_DLLS`;
- exact predecessor PE diagnostics show `mozglue.dll` delay-imports `USER32.dll!SetProcessDPIAware` along with XP-present `DefWindowProcW` and `PeekMessageW`.

Therefore a real XP-incompatible early-startup path is now **PROVEN**:

```text
r3dfox.exe startup
  -> WindowsDpiInitialization()
  -> XP takes pre-Win8.1 else branch
  -> SetProcessDPIAware()
  -> mozglue USER32 delay-load thunk
  -> USER32.dll loads on XP
  -> SetProcessDPIAware export is absent
  -> procedure resolution cannot succeed
```

This path matches the observed `0xC06D007F` exception class exactly and is the current leading explanation of the physical startup crash. However the exact association of the recorded exception instance with `USER32.dll!SetProcessDPIAware` is intentionally left for the next debugger capture: WinDbg should stop on `c06d007f` and expose `DelayLoadInfo` / the native stack before any source patch is committed.

The absence of `PROPSYS.dll`, `dxgi.dll`, and `ncrypt.dll` remains separate compatibility evidence. PROPSYS was an ordinary `xul.dll` clean-XP dependency in this older artifact; DXGI remains a proven ordinary dependency of shipped `libGLESv2.dll`; NCRYPT remains a potential delay-load surface. They are not reclassified as the cause of this particular `c06d007f` event merely because they are absent.

Next experiment was debugger-first; that sequence has since been completed by the WinDbg `DelayLoadInfo` entry above.

Conclusion: **EXCEPTION CLASS CONFIRMED (`C06D007F`) / EARLY `SetProcessDPIAware` XP DEFECT PROVEN / SUPERSEDED BY EXACT DELAYLOADINFO CONFIRMATION ABOVE.**

---

## 2026-09-04 — XP runtime-closure review proves PROPSYS/DXGI static gaps; physical XP debugger path prepared

Track: Windows XP SP3 x86 compatibility / runtime closure and startup-crash diagnosis only. This is not GOST TLS runtime/handshake evidence.

Exact predecessor binary/evidence identity used for the static closure review:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `2b1cf7e1b59881b935c7f695a54edd6b92c8066e`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33757305364`;
- job `100654730312`;
- runtime artifact `9899304858`;
- diagnostics artifact `9899307128`.

Static closure findings from exact diagnostics artifact `9899307128` established older-artifact PROPSYS and DXGI gaps; the current static state is superseded by run `33864176444`, which closes PROPSYS and leaves DXGI as the sole broad forbidden-direct-import row. The physical XP debugger preparation recorded here led to the exact `SetProcessDPIAware` confirmation above.

Conclusion: **HISTORICAL STATIC/RUNTIME HANDOFF / SUPERSEDED FOR CURRENT STATIC CLOSURE BY RUN `33864176444`.**

---

## 2026-09-04 — first full-workflow GREEN browser fails physical XP startup at `kernel32!RaiseException`; same build starts on Win7 x86

Track: Windows XP SP3 x86 compatibility / physical browser runtime only. This is not GOST TLS runtime/handshake evidence.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `2b1cf7e1b59881b935c7f695a54edd6b92c8066e` (`ci(xp): add residual YY KERNEL32 providers`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33757305364`, attempt `1`;
- job `100654730312`;
- runtime artifact `9899304858`, digest `sha256:7d6eff6a4af1b1358f17ed1db9f9194d03702298def5708542a6510aa10029e0`.

Physical runtime observation supplied by the user:

- Windows XP SP3 x86: the browser does not start successfully; the failure is stable across repeated launches;
- Application log reports `Faulting application r3dfox.exe, version 153.0.3.3, faulting module kernel32.dll, version 5.1.2600.5781, fault address 0x00012afb`;
- no ordinary missing-entry-point/linker dialog is observed;
- the same build starts successfully on Windows 7 x86 and passes the user's basic/primary runtime checks.

Address classification:

- for XP `kernel32.dll` in this version family, module offset `0x12afb` maps to `kernel32!RaiseException+0x53` in public symbolized crash records;
- therefore the Application log identifies the exception-raising site, not the underlying failing caller/API;
- the exception code and a stack are still required before assigning the crash to a specific subsystem;
- possible classes include an uncaught C++ exception and MSVC delay-load failure, both of which can surface through `RaiseException`.

Important import evidence from the exact diagnostics artifact `9899307128` remains historical: the final `xul.dll` ordinary KERNEL32 import table still contained two Vista+ APIs, `GetApplicationRestartSettings` and `GetNamedPipeServerProcessId`. Those were later closed by subsequent source-remediation runs.

Conclusion: **PHYSICAL XP FAIL / WIN7 X86 PASS / HISTORICAL EARLY STARTUP EXCEPTION.** The exact root cause was later confirmed as `USER32.dll!SetProcessDPIAware` delay-load procedure-not-found. No GOST TLS conclusion follows.

---

## 2026-09-03 — first fully GREEN XP x32 full-build workflow; prior three GMP imports closed, two xul quartet imports still diagnostic WARN

Track: Windows XP SP3 x86 compatibility / full Firefox 153 x32 integration only. This is not GOST TLS runtime/handshake evidence and is not physical-Windows-XP runtime proof.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `2b1cf7e1b59881b935c7f695a54edd6b92c8066e` (`ci(xp): add residual YY KERNEL32 providers`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33757305364`, attempt `1`;
- job `100654730312`;
- aggregate run/job conclusion: **success**.

Exact artifacts:

- package artifact `9899302735`, `327770380` bytes, digest `sha256:baeb2aaa2c31599da56c2b1c767bdd969914e034ab2c94826c0dd18db36d394b`;
- runtime artifact `9899304858`, `74919909` bytes, digest `sha256:7d6eff6a4af1b1358f17ed1db9f9194d03702298def5708542a6510aa10029e0`;
- diagnostics artifact `9899307128`, `5945299` bytes, digest `sha256:cb08028e3518d8834b50d50b9b68a98e3166a2c25a0177397214a8dabd6b3132`.

All hard workflow boundaries are GREEN, including:

- pinned msvcr14x XP runtime contract;
- narrow YY XP x86 provider build and all-target-link activation while the full YY `kernel32.lib` remains prohibited;
- Firefox configure/export/security-manager object gate;
- full release Firefox x86 build;
- production core-browser direct-import gate;
- D3DCompiler_47 retarget/package-survival contract;
- staged and packaged msvcr14x CRT contract;
- staged and packaged physically proven `xp-bcrypt-v1` contract;
- runtime-test archive creation;
- final inventory-driven `GATE - Audit XP x32 PE floor and direct imports`;
- package/runtime/diagnostics uploads;
- final `GATE - Summarize XP x32 full build`.

The exact diagnostics show that the previous three broad-audit rows from run `33738262420` are gone: neither `FlsGetValue` nor `TryAcquireSRWLockExclusive` survives in the audited GMP fake/test DLL import dumps. Thus the narrow YY provider transfer for those two residual API names is proven at full-Firefox integration scale, not merely by the earlier focused smoke.

However, GREEN did **not** mean complete XP hard-import closure. The source-remediation quartet diagnostic recorded two surviving hard imports in `xul.dll`: `GetApplicationRestartSettings` and `GetNamedPipeServerProcessId`. Those are later closed and this status is historical.

Conclusion: **FIRST FULL WORKFLOW GREEN / HISTORICAL CHECKPOINT.** Subsequent runs supersede its current static-import state. No GOST TLS handshake conclusion follows from this compatibility build.

---

## 2026-09-03 — broad XP x32 import inventory reduced from 69 findings to three test-GMP imports

Track: Windows XP SP3 x86 compatibility / full Firefox 153 x32 integration only. This is not GOST TLS runtime/handshake evidence.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `f602df1b2f3c9b85a4b938a4ea57b07373ac9a95`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33738262420`, attempt `1`;
- job `100593897593`;
- aggregate run/job conclusion: **failure** at final summary after evidence collection.

Exact artifacts:

- package artifact `9891436211`, `327757708` bytes, digest `sha256:277f4584bc95a8b425c640db01d18078cdd9ab307caa33bbc8fc2940457ed362`;
- runtime artifact `9891437190`, `74914750` bytes, digest `sha256:a9f8d9598f431f757fcc63c3796dcc600af48371236cf0586e18f5bd9e323cf3`;
- diagnostics artifact `9891438460`, `5947148` bytes, digest `sha256:a421a0cabbfcb151120842e4525b2296011c2c1bc127808e1cfaf52d0e1f612a`.

Passed boundaries before the aggregate RED:

- full Firefox x86 build — **PASS**;
- production core-browser direct-import gate — **PASS**;
- D3DCompiler_47 retarget/package-survival gates — **PASS**;
- packaged CRT contract — **PASS**;
- packaged `xp-bcrypt-v1` contract — **PASS**;
- package and physical-test runtime archive creation — **PASS**;
- package/runtime/diagnostics uploads — **PASS**.

The final broad all-PE audit is the only diagnostic RED promoted by `GATE - Summarize XP x32 full build`. Its exact `xp-x32-forbidden-direct-imports.txt` contains only three rows:

- `gmp-fake/1.0/fake.dll` -> `FlsGetValue`;
- `gmp-fake/1.0/fake.dll` -> `TryAcquireSRWLockExclusive`;
- `gmp-fakeopenh264/1.0/fakeopenh264.dll` -> `FlsGetValue`.

This is a material reduction from the 69 findings in run `33718674533`. The curated production core-browser gate remains GREEN.

Conclusion: **FULL BUILD + PACKAGE + RUNTIME ARCHIVE GREEN; HISTORICAL BROAD INVENTORY RED ONLY ON THREE GMP TEST DLL IMPORTS.** Those findings were closed by later runs. No physical-XP startup and no GOST TLS handshake conclusion follows from this CI run.

---

## 2026-09-03 — full XP x32 package dependency closure GREEN; broad distribution import inventory remains RED

Track: Windows XP SP3 x86 compatibility / full Firefox 153 x32 integration only. This is not GOST TLS runtime/handshake evidence.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `4949a16e730cc15fc85b128fd62dac2a27c4d9c5` (`ci(xp): preserve artifacts across diagnostic reds`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33718674533`, attempt `1`;
- job `100533128424`;
- aggregate run/job conclusion: **failure**, intentionally propagated by the final evidence summary after non-fatal diagnostic collection.

Exact artifacts:

- package artifact `9883134667`, `327699666` bytes, digest `sha256:64b9537376b72a9e38728236b666b929e84e9c6895a022a1dd66338b9a645582`;
- runtime artifact `9883135451`, `74911275` bytes, digest `sha256:9a5380bfec2b05a8460f6dfef99c85a1c053e1b31f9f18f101d6a7fc5563127b`;
- diagnostics artifact `9883136547`, `5912540` bytes, digest `sha256:b7fb3503a258d78fec927cd0f81413d5124f6f9b4a61cd27a034ec6092607f1c`.

Passed boundaries before the aggregate RED:

- full Firefox x86 compile/build — **PASS**;
- production core-browser import gate — **PASS**;
- pinned msvcr14x staging — **PASS**;
- legacy `D3DCompiler_47.dll` staging/retarget/package survival — **PASS**;
- exact `xp-bcrypt-v1` staging/package survival — **PASS**;
- `mach package` / portable package production — **PASS**;
- msvcr14x portable-package survival contract — **PASS**;
- physical-test runtime archive creation — **PASS**;
- package, runtime and diagnostics artifact uploads — **PASS**.

The previous CRT packaging blocker is closed. The aggregate RED is not a compile or packaging failure; the broad all-PE import audit produced 69 known post-XP findings in auxiliary/media/test PEs, later reduced and closed in subsequent runs.

Conclusion: **HISTORICAL FULL BUILD + CRT/BCRYPT PACKAGE + RUNTIME ARCHIVE GREEN; BROAD DISTRIBUTION IMPORT INVENTORY RED.** No GOST TLS handshake conclusion follows from this run.

---

## 2026-09-02 — full XP x32 Firefox build and package pass; portable msvcr14x survival gate remains red

Track: Windows XP SP3 x86 compatibility / full Firefox build and packaging only. This is not GOST TLS runtime/handshake evidence.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `17cdb459ec4f115a209fd50ac225cf867b9f3a2f`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33638897692`, attempt `1`;
- job `100276666021` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- overall run/job conclusion: **failure**, localized after successful build/package to the portable CRT-survival gate.

Passed boundaries before the red flag included the pinned msvcr14x runtime contract, narrow YY provider, Firefox build, early core import gate, D3DCompiler staging, and package production. The exact portable CRT-survival gate failed because the produced archive did not contain the exact staged `ucrtbase.dll` and `msvcp140.dll`; that blocker was closed by later full-build runs.

Conclusion: **HISTORICAL major full-build progress / packaging-contract RED, later superseded.**

---

## 2026-09-02 — repaired final Russian localization Gate D passes the full ru + en-US package workflow

Track: bundled extensions / localization / package behavior only. This is not GOST TLS runtime/handshake evidence and not old-Windows runtime evidence.

Exact project/build identity:

- branch `agent/gost-tls-poc`;
- source-under-test `3e2c32386f373d4693db52b32c05aa2000878def`;
- workflow `CryptoPro Mozilla packaging smoke`;
- Actions run `33520207057`;
- job `99897230730` (`Windows x64 / CryptoPro real Firefox packaging / ru + en-US`);
- run/job conclusion: **success**;
- pinned `firefox-l10n` source SHA remains `4273d99ccdc4a516ec6abd742a272ad1d385ddf4`.

Exact artifacts:

- packaged browser artifact `9812333220` (`r3dfox-cryptopro-mozilla-packaging-ru-en-US`), digest `sha256:c8e62704fcc2cd1b99c78cf6cf90b405b653a9aeba5272d132bcda4eaed5edd8`;
- packaging evidence artifact `9812333789` (`cryptopro-mozilla-packaging-evidence`), digest `sha256:fdcb6a34ed5625532af86413330b5c2d4453be046f3d6419d49d2d45c7a143dc`.

Every relevant localization/package boundary is green. The repair commit changes only the final `browser/omni.ja` representative-resource suffix used by Gate D. The successful rerun closes the CI false negative.

Conclusion: **PASS / localization package gate CLOSED.** No GOST TLS conclusion follows.

---

## 2026-09-01 — physically proven single-DLL bcrypt published as reusable raw release asset

Track: Windows XP x86 dependency distribution/integration only. This does not add new bcrypt runtime evidence and is not GOST TLS handshake evidence.

Binary identity remains the already physically proven implementation:

- binary source-under-test `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- source-build workflow run `33513084915`, job `99873297193`;
- runtime artifact `9802703271`;
- `bcrypt.dll` size `520704` bytes;
- SHA-1 `ae021f44edc48b03bb4d67cb5773b62bdf60cb67`;
- SHA-256 `f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`;
- physical Windows XP 5.1.2600 dynamic + linked/IAT PASS already recorded below.

Publication identity is separate from binary source identity:

- publication workflow source `76225fcf95e4e484f0cec30c8e25a235119b0256`;
- publication workflow `Publish proven XP bcrypt release`;
- Actions run `33518189052`;
- job `99890447193`;
- conclusion **success**;
- tag `xp-bcrypt-v1` points directly to binary source-under-test `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- technical prerelease ID `380563342`, title `XP bcrypt primitive v1`;
- raw release asset ID `539647946`, name `bcrypt.dll`, size `520704`, GitHub digest `sha256:f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`.

Conclusion: **PASS / reusable binary distribution established.** `xp-bcrypt-v1` is the canonical cross-branch binary input for the selected physically proven bcrypt primitive.

---

## 2026-09-01 — single-DLL source-built One-Core bcrypt with embedded mbedTLS passes physical Windows XP through dynamic and linked consumers

Track: Windows XP x86 binary compatibility only. This is not GOST TLS runtime/handshake evidence.

Exact project/build identity:

- branch `agent/gost-tls-poc`;
- source-under-test `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- workflow `One-Core bcrypt source XP x86 smoke`;
- Actions run `33513084915`;
- job `99873297193`;
- run/job conclusion: **success**;
- pinned upstream `shorthorn-project/One-Core-API-Source@9eb3c31de9460c1ccce3f6a10c9c4a704f032514`;
- build environment RosBE 2.1.6 i386.

Exact artifacts:

- runtime artifact `9802703271` (`onecore-bcrypt-source-xp-x86-runtime`), digest `sha256:e6ea796ef5f7dfb67e346630cd6432c9659e6d90d39ce90b8f44a1b3632edc8f`;
- diagnostics artifact `9802704126` (`onecore-bcrypt-source-xp-x86-diagnostics`), digest `sha256:d989ce72af60185cb16b0ff99d156ed39170beab00055e776b881ee2cc54e6de`.

The adopted runtime closure is a single deployable DLL with embedded mbedTLS. On physical Windows XP SP3 x86 both exact-local dynamic loading and ordinary linked/IAT resolution passed required exports, RNG and SHA-256, with no runtime `mbedtls.dll`.

Conclusion: **PASS / SELECTED / CLOSED at focused dependency-runtime level.**

---

## 2026-09-01 — single-DLL source-built One-Core bcrypt with embedded mbedTLS passes CI; physical XP confirmation pending

Track: Windows XP x86 binary compatibility only. This is not GOST TLS runtime/handshake evidence.

Exact project identity:

- branch `agent/gost-tls-poc`;
- source-under-test `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- workflow `One-Core bcrypt source XP x86 smoke`;
- Actions run `33513084915`;
- job `99873297193`;
- run/job conclusion: **success**.

Conclusion at that time: **CI PASS / preferred single-DLL candidate / PHYSICAL XP PENDING.** This status is superseded by the physical-XP PASS recorded immediately above for the same exact artifact.

---

## 2026-09-01 — source-built One-Core bcrypt closure passes CI and physical Windows XP through dynamic and linked consumers

Track: Windows XP x86 binary compatibility only. This is not GOST TLS runtime/handshake evidence.

Exact project identity:

- branch `agent/gost-tls-poc`;
- source-under-test `fdd4d4dac5a7d9611ec71975ae800437f45c47dd`;
- workflow `One-Core bcrypt source XP x86 smoke`;
- Actions run `33493625367`;
- job `99810642354`;
- run/job conclusion: **success**.

Exact artifacts:

- runtime artifact `9794971087` (`onecore-bcrypt-source-xp-x86-runtime`), digest `sha256:03627eb494b604d3a84a9473cad8c0928b13ec458c20cee9e63bfc0ca10d75f1`;
- diagnostics artifact `9794971830` (`onecore-bcrypt-source-xp-x86-diagnostics`), digest `sha256:832563a5618d52f061fcc55efea463e618b4212aea12236ef7bf015cd39e93fe`.

Conclusion: **PASS / CLOSED at focused dependency-runtime level / SUPERSEDED AS SELECTED IMPLEMENTATION.** The later physically proven single-DLL embedded-mbedTLS implementation from run `33513084915` is selected for Firefox integration.

---

## 2026-09-01 — full ru + en-US package is substantively localized; Gate D fails on a path-shape assertion

Track: bundled extensions / localization / package behavior only. This is not GOST TLS runtime/handshake evidence and not old-Windows runtime evidence.

Exact project identity:

- branch `agent/gost-tls-poc`;
- source-under-test `e4f9f775d82ff14a75708e11043211e7259eed9b`;
- documentation HEAD observed after the run: `3ca8f1ff3ad33c8957b3757a2efffad80733d112`;
- workflow `CryptoPro Mozilla packaging smoke`;
- Actions run `33489331410`;
- job `99796818515`;
- run/job conclusion: **failure** at final Gate D only.

The uploaded final browser artifact `9798517225` was independently inspected after the failed job and proved substantive Russian localization survived into both final `omni.ja` files. Root cause of the red Gate D was the gate predicate path shape, not missing Russian UI content.

Conclusion: **LOCALIZATION PACKAGE CONTENT PASS / CI GATE FALSE NEGATIVE.** This historical status is superseded by successful repair run `33520207057` above.