# Windows XP SP3 x86 — runtime compatibility status

Last updated: 2026-09-04

Track: Windows XP SP3 x86 runtime compatibility only. This document does not describe or prove GOST TLS / NSS / MSSPI / CryptoPro handshake behavior and does not authorize a Firefox/r3dfox 153 -> 154 base update.

Canonical documentation branch: `agent/gost-tls-poc`.

Implementation branch: `agent/winrt-source-poc`.

Frozen baseline: `win-153`; do not modify, merge, rebase or push to it without explicit user instruction.

This file is the current handoff for the transition from a full XP x86 workflow that can be GREEN to a browser that actually starts on physical Windows XP. Read it together with `PROJECT_STATE.md`, `TEST_LOG.md`, `XP_BUILD_CONTRACT.md`, and `XP_MOZ_XP_COMPAT_CONTRACT.md` before proposing runtime-compatibility changes.

## Current branch/build identity

At documentation time:

- default/canonical documentation branch `agent/gost-tls-poc` HEAD: `fd54ef9afd4cf611f253e07a502a57fb7cb9602f`;
- XP implementation branch `agent/winrt-source-poc` HEAD: `1a86821ccf50ac07204d1bec438e375ece4e84d6`;
- current full-build workflow: `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- current run: `33831005002`;
- current job: `100893816677`;
- source-under-test: `1a86821ccf50ac07204d1bec438e375ece4e84d6`;
- run state at documentation time: **IN PROGRESS**;
- the build had passed bootstrap/configure/export/security-manager object compilation and was in `Build release r3dfox XP x32`;
- quartet diagnostics, final all-PE audit, packaging uploads and artifact IDs had not yet been produced.

Therefore there is currently **no final-binary proof of 0/4 quartet closure for source `1a86821...`** and no new runtime artifact ID suitable for physical-XP conclusions. Do not substitute source grep, source guards or successful object compilation for the final `xul.dll` import result.

Current source-under-test contains the targeted follow-up remediation for the two survivors from the predecessor build:

- `widget/windows/nsWindow.cpp::GetQuitType()` excludes `GetApplicationRestartSettings` under `MOZ_XP_COMPAT`, with `nsWindow.cpp` isolated from unified compilation and given source-local XP compatibility ownership;
- `third_party/content_analysis_sdk/browser/src/client_win.cc` keeps the pipe connection but excludes the optional `GetNamedPipeServerProcessId` PID/path metadata path under `MOZ_XP_COMPAT`, and that source is likewise isolated from `UNIFIED_SOURCES` and given source-local `-DMOZ_XP_COMPAT`.

These source changes are necessary cleanup, not yet final import closure.

## Last completed and physically tested browser

The last completed exact full-browser result remains:

- source-under-test `2b1cf7e1b59881b935c7f695a54edd6b92c8066e`;
- run `33757305364`;
- job `100654730312`;
- package artifact `9899302735`;
- runtime artifact `9899304858`;
- diagnostics artifact `9899307128`.

Run `33757305364` is the first fully GREEN full XP x32 workflow in the current lineage. Its exact runtime artifact `9899304858` has separate physical results:

- Windows 7 x86: browser starts and passes the user's basic/primary checks;
- Windows XP SP3 x86: browser fails stably immediately after launch.

XP Application Event Log for this exact runtime artifact reports:

```text
Faulting application r3dfox.exe, version 153.0.3.3,
faulting module kernel32.dll, version 5.1.2600.5781,
fault address 0x00012afb.
```

For this XP `kernel32.dll` family the offset corresponds approximately to `kernel32!RaiseException+0x53`. This is the exception-raising site, not proof that `kernel32.dll` itself is defective and not proof of any specific missing API.

The current root cause remains **UNCONFIRMED** because no exact launch-bound `ExceptionCode`, first/second-chance context or native faulting-thread stack has yet been captured.

Do not assign the crash to `e06d7363`, `c06d007e`, `c06d007f`, `c0000005`, PROPSYS, DXGI, UIA, WinRT or any other subsystem without the corresponding runtime evidence.

## KERNEL32 source-remediation quartet

Predecessor final `xul.dll` diagnostics from artifact `9899307128` proved:

- `GetApplicationRestartSettings` — ordinary import present;
- `RegisterApplicationRestart` — absent;
- `UnregisterApplicationRestart` — absent;
- `GetNamedPipeServerProcessId` — ordinary import present.

The current run `33831005002` exists specifically after source-level remediation of the two survivors. Acceptance for this line is the later exact final `xul.dll` result:

```text
GetApplicationRestartSettings    absent
RegisterApplicationRestart       absent
UnregisterApplicationRestart     absent
GetNamedPipeServerProcessId      absent
```

That is **0/4 surviving ordinary imports**. Until the exact run finishes and its final diagnostics prove this, keep the quartet status provisional.

## PROPSYS.dll — proven ordinary `xul.dll` dependency, root-cause status unknown

Exact predecessor diagnostics artifact `9899307128` shows `PROPSYS.dll` as an **ordinary import descriptor** of final `xul.dll`, before the delay-load section. The imported exports are:

```text
PROPSYS.dll
    PropVariantToString
    VariantCompare
```

This is not merely a source reference and not merely a possible delay-loaded feature. The predecessor final `xul.dll` has a normal loader dependency on `PROPSYS.dll`.

### Production owners

`PropVariantToString` has a direct production owner in:

- `browser/components/shell/nsWindowsShellService.cpp`;
- the relevant code reads `PKEY_AppUserModel_ID` from a property store and converts the `PROPVARIANT` to text using `PropVariantToString`;
- `browser/components/shell/moz.build` explicitly links `propsys` on Windows through `OS_LIBS`.

`VariantCompare` has a direct production owner in:

- `accessible/windows/uia/UiaTextRange.cpp`;
- `CompareVariants(...)` calls `VariantCompare(...)` on the normal MSVC path;
- the MinGW-only alternative uses `VariantToPropVariant` / `PropVariantCompareEx`, but the XP full-build workflow uses MSVC and therefore follows the `VariantCompare` path;
- `accessible/windows/uia/moz.build` places this source into `FINAL_LIBRARY = "xul"`.

The resulting proven link paths are therefore:

```text
nsWindowsShellService.cpp
  -> PropVariantToString
  -> propsys import library
  -> ordinary PROPSYS.dll!PropVariantToString in xul.dll
```

and

```text
UiaTextRange.cpp::CompareVariants
  -> VariantCompare
  -> propsys import library
  -> ordinary PROPSYS.dll!VariantCompare in xul.dll
```

### XP classification

Do not describe these two exports themselves as strictly Vista-only. Microsoft documentation exposes XP support for this Property System surface through the Windows Desktop Search 3.0 redistributable. The important project distinction is that a clean XP SP3 installation is not guaranteed to contain the required `PROPSYS.dll` merely because the API documentation has an XP-supported redistributable path.

For the project's intended clean-XP runtime closure, `PROPSYS.dll` therefore remains a **known unresolved ordinary dependency** until one of the following is proven:

1. the project intentionally declares an external prerequisite and verifies it as part of the runtime contract; or
2. the exact XP product source/build removes the dependency from final `xul.dll`; or
3. a deliberately selected app-local compatibility DLL is built/staged and receives its own export, PE/import, provenance and physical-XP contract.

The preferred remediation order is source/build first. The already identified users are narrow enough that compile-out under the established XP source contract should be evaluated before introducing a project-owned `PROPSYS.dll` clone. In particular:

- shell/AUMID property-store logic should be isolated at the exact modern shell feature if XP does not need it;
- the modern UIA provider path should be classified as required vs optional on the XP product before preserving `VariantCompare` through a new compatibility DLL;
- if the final accepted source path no longer needs Propsys, remove the Windows `propsys` link dependency and require final `xul.dll` to prove `PROPSYS.dll` absent.

`PROPSYS.dll` is a proven static closure defect for the clean-XP baseline, but it is **not yet a proven explanation of the observed `RaiseException` crash**.

## Other proven/static closure defects

### `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1`

Exact predecessor diagnostics artifact `9899307128` also shows shipped `libGLESv2.dll` with an ordinary import path to:

```text
dxgi.dll
    CreateDXGIFactory1
```

`CreateDXGIFactory1` is a Windows 7+ API. This is therefore another proven static XP closure defect in a separately linked shipped PE.

Do not automatically call it the current startup root cause. `xul.dll` does not prove that `libGLESv2.dll` is part of the initial mandatory loader set, and Firefox/ANGLE graphics loading may occur dynamically with fallback behavior. The next classification question is whether this PE is startup-critical on physical XP or an optional graphics path that can be disabled/rebuilt/replaced without affecting initial browser process creation.

Keep this line separate from `xul.dll` source remediation: a link fix in `xul.dll` cannot remove an ordinary import owned by `libGLESv2.dll`.

## Known delay-load / optional modern surfaces in `xul.dll`

The raw predecessor import diagnostics also retain real delay-load surfaces, including at least:

- `api-ms-win-core-winrt-string-l1-1-0.dll` with `WindowsCreateStringReference`, `WindowsDeleteString`, `WindowsGetStringRawBuffer`;
- `api-ms-win-core-winrt-l1-1-0.dll` with `RoActivateInstance`, `RoGetActivationFactory`;
- `UIAutomationCore.dll` with multiple `Uia*` exports;
- `ncrypt.dll` with `NCryptFreeObject` and `NCryptSignHash`;
- additional delay-loaded Windows feature DLLs such as `AVRT.dll` and `dwmapi.dll`.

These are not equivalent to ordinary PE imports. Classify each path as:

1. ordinary import;
2. delay import;
3. explicit `LoadLibrary` / `GetProcAddress`;
4. COM/WinRT activation;
5. optional feature path;
6. actual startup-critical path on physical XP.

A missing delay-load module/procedure can be raised through the MSVC delay-load helper and surface through `RaiseException`, which is why `c06d007e` and `c06d007f` are important exception codes to capture. They remain hypotheses until an exact debugger/Watson record says so.

The current workflow's curated fatal DLL patterns do not by themselves reject every XP-absent dependency. In particular, predecessor workflow GREEN did not prove that `PROPSYS.dll` or `dxgi.dll` were safe. The all-PE inventory remains useful evidence, but the fatal policy is a regression list, not exhaustive clean-XP compatibility proof.

## Closed compatibility families — do not reopen without contradictory evidence

The current startup crash is not a reason to restart already-proven work on:

- pinned/restored msvcr14x Release x86 runtime contract;
- narrow YY provider strategy and the closed SRW/condition-variable family;
- `CreateWaitableTimerExA` source fallback;
- exact app-local `xp-bcrypt-v1/bcrypt.dll`;
- legacy `D3DCompiler_47.dll` staging/packaging;
- the previous broad curated forbidden-import progression `69 -> 3 -> 0` for the gate's existing API list.

Successful CI for these families is not proof of browser startup, but the browser startup crash also does not invalidate them without new family-specific evidence.

## Physical XP debugger readiness

The physical Windows XP SP3 x86 machine is now prepared for the next root-cause experiment.

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

Therefore Dr. Watson is now registered as the default application debugger on that XP system.

The same physical XP computer also already has:

```text
Debugging Tools for Windows (x86) v6.12.2.633
```

available. This gives the project a suitable classic x86 WinDbg/debugger path for a second-stage capture if Dr. Watson does not expose enough context.

## Next runtime-debugging sequence — ordered by cost

Use the exact physically failing predecessor browser `runtime artifact 9899304858` first when the goal is to identify the already observed `RaiseException` crash. Keep all captured evidence bound to source `2b1cf7e1...`, run `33757305364`, job `100654730312`, artifact `9899304858`.

### 1. Record the physical XP DLL baseline

Before changing the machine, record presence/version/hash where practical for at least:

```text
%SystemRoot%\System32\propsys.dll
%SystemRoot%\System32\dxgi.dll
%SystemRoot%\System32\UIAutomationCore.dll
%SystemRoot%\System32\ncrypt.dll
```

Absence of a DLL is useful closure evidence, but still does not by itself prove that the observed exception came from that exact path.

### 2. Capture one Dr. Watson crash for exact artifact `9899304858`

Configure Dr. Watson to retain the application error log and crash dump/thread context, reproduce one clean launch, and preserve:

- `drwtsn32.log` or the configured application error log;
- generated user dump if enabled;
- corresponding Application Event Log entry/timestamp;
- exact launched browser directory/artifact identity.

Required result from this experiment:

- `ExceptionCode`;
- faulting thread;
- native stack if present;
- loaded module list or enough addresses to reconstruct it.

### 3. If Watson is insufficient, use classic WinDbg from Debugging Tools v6.12.2.633

Catch the first relevant exception rather than only the final second-chance `RaiseException` site. High-value exception classes are:

```text
0xC06D007E  MSVC delay-load module-not-found class
0xC06D007F  MSVC delay-load procedure-not-found class
0xE06D7363  MSVC C++ exception class
0xC0000005  access violation
```

Do not assume any one of them in advance.

At the first useful break preserve at minimum:

```text
.exr -1
.ecxr
kv
lm
```

If the exception is a delay-load failure, extract the associated `DelayLoadInfo`/last-error data far enough to identify the exact DLL and function/ordinal. That converts the current generic `RaiseException` observation into a concrete runtime blocker.

### 4. Procmon only if module-resolution history is still ambiguous

Use an XP-compatible Procmon version to capture the module/file lookup sequence around the crash. Focus on `r3dfox.exe`, image loads and failed DLL/procedure-related filesystem lookups. Procmon is complementary evidence; it does not replace the debugger's exception code and stack.

### 5. Loader snaps/gflags only after a loader/delay-load path is indicated

Do not start with loader snaps. Enable them only if the previous evidence points at module resolution and ordinary debugger output still cannot identify the failing dependency. This avoids unnecessary startup noise.

## Decision order from this point

Do not mass-patch every modern Windows reference at once.

The next decisions are ordered:

1. let run `33831005002` finish and require exact final quartet evidence of **0/4 ordinary imports** before closing that source-remediation line;
2. independently capture the `ExceptionCode` and stack for exact physical failure artifact `9899304858` using the now-ready Dr. Watson/WinDbg setup;
3. record whether the physical XP machine actually has `PROPSYS.dll` and the other named compatibility DLLs;
4. if debugger evidence identifies a concrete startup dependency/API, remediate that exact root cause first;
5. regardless of root cause, treat `PROPSYS.dll` as necessary clean-XP static-closure work and prefer narrow source/build removal before an app-local shim;
6. separately classify `libGLESv2.dll -> dxgi!CreateDXGIFactory1` by startup criticality and feature ownership;
7. only then continue through unresolved delay-load, COM/WinRT, dynamic-load and separately linked PE surfaces one evidence-backed dependency at a time.

Keep three categories explicit in every follow-up:

- **confirmed root cause** — requires exact runtime exception/stack/module evidence;
- **necessary compatibility cleanup** — a proven XP-invalid or non-baseline static dependency even if it did not cause the current crash;
- **hypothesis** — a possible delay/dynamic/optional path not yet observed as the failing runtime path.

## Acceptance boundary

A future browser is not accepted as XP-compatible merely because the workflow is GREEN. Acceptance still requires:

1. exact source-under-test SHA;
2. exact run/job identity;
3. final ordinary and delay-import evidence for the shipped/runtime-required PE closure;
4. exact package/runtime/diagnostics artifact IDs and hashes;
5. physical Windows XP startup and representative browser use;
6. no inference from Windows 7 x86 success alone.

Likewise, successful XP startup will not establish any GOST TLS handshake result.