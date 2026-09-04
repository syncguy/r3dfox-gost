# r3dfox GOST TLS — Project State

Last updated: 2026-09-04

This file is the authoritative current technical synthesis and handoff for new chats. Detailed experiment evidence belongs in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes; closed milestones are in `DONE.md`; pending work is in `TODO.md`; workflow roles are in `WORKFLOWS.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default GOST development branch and canonical documentation source: `agent/gost-tls-poc`.
- Windows XP SP3 x86 compatibility implementation branch: `agent/winrt-source-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the active work branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer base.

For Windows XP work, read `XP_BUILD_CONTRACT.md` and `XP_MOZ_XP_COMPAT_CONTRACT.md` before proposing build/configuration changes. For the current physical-XP startup/runtime-closure investigation, also read `XP_RUNTIME_COMPATIBILITY_STATUS.md` and the newest XP entries in `TEST_LOG.md`.

## Separation of conclusions

Keep these tracks independent unless a deliberately combined experiment tests both:

1. GOST TLS runtime / NSS / NSPR / MSSPI / SSPI / CryptoPro / handshake.
2. Windows Vista/7/XP compatibility / Rust / msvcr14x / YY-Thunks / linker / PE imports / physical runtime.
3. Bundled government-system extensions and localization/package behavior.

A successful build is not a successful GOST handshake. A hosted compatibility probe is not physical-XP proof. Win7 x86 runtime success is not XP import closure. A documentation commit is never the source-under-test SHA for an earlier artifact.

# GOST TLS runtime

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

Current GOST runtime constraints and open work remain independent of XP compatibility:

- TLS 1.2 / HTTP/1.1 PoC path;
- coordinated Firefox client-auth picker as default;
- `Session` is the current default positive certificate choice and remains process-local;
- true persistent `Permanent` semantics remain open;
- final fail-closed server verification remains open;
- synchronous provider/key access can still block the shared Firefox Socket Thread during long CryptoPro waits.

Current authoritative Session-default browser source is `afbdad307f63e594d3715169d6e34235280dddaf`, full build run `33073577269`, job `98521835354`, release artifact `9652941006`.

# Windows XP SP3 x86 compatibility

This track is independent of GOST TLS runtime. Active implementation work is on `agent/winrt-source-poc`; documentation remains on `agent/gost-tls-poc`.

Detailed current runtime/debugger handoff: `XP_RUNTIME_COMPATIBILITY_STATUS.md`.

## Closed compatibility families — do not reopen without contradictory evidence

- SRW / condition-variable family: source `d65b464c74caadace97995f07a4919363c41a0ea`, run `33470957048`, job `99740439208`.
- `CreateWaitableTimerExA`: source-level fallback closure, source `17cdb459ec4f115a209fd50ac225cf867b9f3a2f`, run `33638897692`, job `100276666021`.
- selected single-DLL `bcrypt.dll`: source `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`, run `33513084915`, job `99873297193`, physically proven on Windows XP and published as `xp-bcrypt-v1`.
- legacy `D3DCompiler_47.dll` staging/packaging: source `b77b22ef1e35564dfe76997d3d393d45ee697e49`, run `33349340069`, job `99359475336`.
- narrow YY residual KERNEL32 line including `TryAcquireSRWLockExclusive` and `FlsGetValue`: focused run `33741674218`, job `100604798167`, then full integration run `33757305364`, job `100654730312`.
- the workflow's curated broad forbidden-import progression `69 -> 3 -> 0` is closed for its historical list on run `33757305364`; this is not an exhaustive XP API/DLL proof and the current audit list is broader.

Full YY `kernel32.lib` interposition remains prohibited. Keep per-PE/provider ownership narrow.

## Exact physically failing browser

The physical-XP startup root-cause investigation is bound to:

- branch `agent/winrt-source-poc`;
- source-under-test `2b1cf7e1b59881b935c7f695a54edd6b92c8066e`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `33757305364`;
- job `100654730312`;
- package artifact `9899302735`, digest `sha256:baeb2aaa2c31599da56c2b1c767bdd969914e034ab2c94826c0dd18db36d394b`;
- runtime artifact `9899304858`, digest `sha256:7d6eff6a4af1b1358f17ed1db9f9194d03702298def5708542a6510aa10029e0`;
- diagnostics artifact `9899307128`, digest `sha256:cb08028e3518d8834b50d50b9b68a98e3166a2c25a0177397214a8dabd6b3132`.

Run `33757305364` is the first fully GREEN full XP x32 workflow in the current lineage. Physical results for the exact runtime artifact are different:

- Windows 7 x86: starts and passes the user's basic/primary checks;
- Windows XP SP3 x86: fails stably immediately after launch.

The original XP Application log record was:

```text
Faulting application r3dfox.exe, version 153.0.3.3,
faulting module kernel32.dll, version 5.1.2600.5781,
fault address 0x00012afb.
```

`kernel32.dll+0x12afb` corresponds to the `RaiseException` site and by itself did not identify the cause.

## Confirmed physical-XP startup root cause — `USER32.dll!SetProcessDPIAware` delay-load failure

Dr. Watson is installed as the default application debugger on the physical XP machine. A reproduced launch of the exact failing browser produced an Application log record at `2026-09-04 10:48:56.815`:

```text
The exception generated was c06d007f at address 7C812AFB
(kernel32!RaiseException)
```

`0xC06D007F` is the MSVC delay-load **procedure-not-found** class.

The exact same runtime artifact was then launched from process start under classic x86 WinDbg `6.12.0002.633`. WinDbg stopped on the first-chance `C06D007F`; `.exr -1` reported:

```text
ExceptionCode: c06d007f
NumberParameters: 1
Parameter[0]: 001bfb70
```

`Parameter[0]` was decoded as the x86 `DelayLoadInfo` structure:

```text
cb              = 00000024
szDll           = "USER32.dll"
fImportByName   = 00000001
szProcName      = "SetProcessDPIAware"
hmodCur         = 7e410000
pfnCur          = 00000000
dwLastError     = 0000007f
```

The physical XP `USER32.dll` export baseline independently confirms `DefWindowProcW` and `PeekMessageW` are present while `SetProcessDPIAware` is absent.

The exact source/build path in the failing browser is established:

- `browser/app/nsBrowserApp.cpp` invokes `mozilla::WindowsDpiInitialization()` before `InitXPCOMGlue(...)` / XUL startup;
- the failing `mozglue/misc/WindowsDpiInitialization.cpp` sent systems older than Windows 8.1 to the fallback branch that directly called `SetProcessDPIAware()`;
- XP therefore reached this Vista+ call because that source had no pre-Vista guard;
- `mozglue/build/moz.build` delay-loads `user32.dll`;
- diagnostics artifact `9899307128` proves final `mozglue.dll` contains the `USER32.dll!SetProcessDPIAware` delay import.

Therefore the startup crash for runtime artifact `9899304858` is no longer a hypothesis:

```text
r3dfox.exe startup
  -> WindowsDpiInitialization()
  -> XP enters the pre-Win8.1 fallback branch
  -> SetProcessDPIAware()
  -> mozglue USER32 delay-load thunk
  -> USER32.dll loads successfully
  -> SetProcessDPIAware export is absent
  -> GetProcAddress/procedure resolution fails with ERROR_PROC_NOT_FOUND (0x7f)
  -> MSVC delay helper raises C06D007F
  -> kernel32!RaiseException
```

This is the **confirmed root cause of the observed immediate XP startup failure** for the exact artifact/run/source above.

When the original first-chance exception was allowed to continue before the exception filter was configured, the process later reached a secondary `C0000005` at `EIP=00000000`; that secondary access violation is not the primary blocker and should not be investigated independently unless it persists after the delay-load root cause is removed.

### Current DPI remediation chain and active build

The root-cause proof is complete. Source remediation is now implemented on `agent/winrt-source-poc`.

Implementation chain:

- `fad9ec0b5a09c50f6cff39a00a3ea4cedd99cdf2` — initial pre-Vista success/no-op in `WindowsDpiInitialization()`;
- `424708f1d8e754f752e108259b331fcd2ec3615b` — workflow evidence update: pre-build DPI guard check, strict quartet final gate, `mozglue` `SetProcessDPIAware` import-mode gate, separate delay-import inventory, and broader ordinary import audit including `PROPSYS.dll` / `DXGI.dll`;
- `a784a7660b23f8270179f5464c2ac3033d7e0652` — wrap the pre-Vista DPI no-op in `#ifdef MOZ_XP_COMPAT` so the compatibility change is explicitly project-owned;
- `a3ede2576cbc7e92ffae58ba0c49d2c38e580335` — add source-local `-DMOZ_XP_COMPAT` for `mozglue/misc/WindowsDpiInitialization.cpp` in `mozglue/misc/moz.build`.

Current implementation-branch HEAD at this handoff is `a3ede2576cbc7e92ffae58ba0c49d2c38e580335`.

A full build was deliberately started before the two ownership-refinement commits and is being allowed to continue:

- run `33842067157`;
- job `100926221307`;
- source SHA `424708f1d8e754f752e108259b331fcd2ec3615b`;
- branch `agent/winrt-source-poc`;
- status at the latest exact check: **IN PROGRESS**;
- its `GATE - Verify XP DPI pre-Vista source guard` already passed.

Evidence boundary: run `33842067157` tests the functional pre-Vista remediation present through `fad9ec0...` plus the workflow gates in `424708f...`. It **does not** test the later `#ifdef MOZ_XP_COMPAT` wrapper or the source-local owner rule from `a784a...` / `a3ede...`. Do not attribute its eventual artifacts to `a3ede...`.

The run remains useful: if it reaches packaging and physical XP advances past the former `SetProcessDPIAware` edge, it validates the functional remediation concept. Final acceptance of the project-owned implementation still requires a later exact build from `a3ede257...` or a descendant containing both ownership commits.

No `USER32.dll` shim, broad YY interposition, or replacement DPI API layer is part of this remediation.

## Physical XP dependency baseline recorded during the same investigation

The current physical XP machine has:

```text
%SystemRoot%\System32\propsys.dll          absent
%SystemRoot%\System32\dxgi.dll             absent
%SystemRoot%\System32\UIAutomationCore.dll present, 158048 bytes, 2010-03-18 10:09
%SystemRoot%\System32\ncrypt.dll           absent
```

Interpretation:

- `PROPSYS.dll` absence confirms that the already proven ordinary final-`xul.dll` PROPSYS dependency is incompatible with this clean-machine baseline unless source/build removes it or the project deliberately adopts an external prerequisite/app-local replacement.
- `dxgi.dll` absence confirms that shipped `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1` cannot resolve if that ANGLE path is loaded; startup criticality remains separate.
- `ncrypt.dll` absence keeps the NCRYPT delay-load surface unresolved, but a missing module would be a different failure class from the confirmed USER32 procedure-not-found event.
- `UIAutomationCore.dll` exists; its exact export/version compatibility is still a separate question.

These are necessary compatibility-closure findings but are not the cause of the confirmed `C06D007F` event above.

## KERNEL32 source-remediation quartet — source remediated, strict final 0/4 gate active

Predecessor final `xul.dll` diagnostics from artifact `9899307128` proved two surviving ordinary KERNEL32 imports:

- `GetApplicationRestartSettings`;
- `GetNamedPipeServerProcessId`.

`RegisterApplicationRestart` and `UnregisterApplicationRestart` were absent.

The implementation chain source-remediates the remaining owners:

- `widget/windows/nsWindow.cpp::GetQuitType()` excludes `GetApplicationRestartSettings` under source-local `MOZ_XP_COMPAT`;
- `third_party/content_analysis_sdk/browser/src/client_win.cc` preserves the pipe connection but excludes optional `GetNamedPipeServerProcessId` PID/path metadata under source-local `MOZ_XP_COMPAT`.

Starting with workflow commit `424708f1d8e754f752e108259b331fcd2ec3615b`, the quartet check is an evidence-preserving final gate: the step may continue so later artifacts are uploaded, but any survivor makes the final verdict RED. Required acceptance is strict `0/4` in final `xul.dll`.

Current active run `33842067157`, job `100926221307`, source `424708f...` will provide a new exact quartet result if it reaches the post-build gate. Until then, do not infer quartet closure from source guards alone.

Detailed quartet history: `XP_KERNEL32_SOURCE_REMEDIATION_STATUS.md`.

## Other proven static/runtime-closure defects

### PROPSYS

Exact diagnostics artifact `9899307128` proves final predecessor `xul.dll` has an **ordinary** `PROPSYS.dll` import with at least:

- `PropVariantToString`;
- `VariantCompare`.

Confirmed production ownership includes `browser/components/shell/nsWindowsShellService.cpp` plus the Windows `propsys` link and `accessible/windows/uia/UiaTextRange.cpp::CompareVariants` on the MSVC path.

Treat PROPSYS as mandatory clean-XP static closure work. Prefer narrow source/build removal before introducing an app-local PROPSYS clone. It is not reclassified as the confirmed `C06D007F` root cause merely because the DLL is absent.

### `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1`

Exact diagnostics artifact `9899307128` proves this ordinary import in shipped `libGLESv2.dll`. `dxgi.dll` is absent on the physical XP machine. This is a separately linked PE closure defect whose startup criticality remains to be classified after the current early startup edge is remediated.

### Remaining delay/dynamic surfaces

Raw diagnostics retain delay-load or optional modern surfaces including WinRT API-set DLLs, `UIAutomationCore.dll`, `ncrypt.dll`, `AVRT.dll` and `dwmapi.dll`. Continue through them only when the physical runtime reaches them or a static required-closure rule makes them independently blocking.

## Mandatory `MOZ_XP_COMPAT` build rule

`MOZ_XP_COMPAT` remains the preferred project-owned compile-time signal where an XP release intentionally removes or bypasses a modern Windows feature/runtime edge with no useful XP semantic equivalent.

The canonical XP full-build workflow intentionally supplies build-wide XP identity:

```sh
export CFLAGS="$CFLAGS -DMOZ_NO_WINRT -DMOZ_XP_COMPAT"
export CXXFLAGS="$CXXFLAGS -DMOZ_NO_WINRT -DMOZ_XP_COMPAT"
```

In addition, every production translation unit containing a dedicated accepted `MOZ_XP_COMPAT` boundary must record source-local ownership where practical:

```python
SOURCES["Owner.cpp"].flags += ["-DMOZ_XP_COMPAT"]
```

The source-local rule is defense-in-depth and owner documentation; it does not replace the workflow-wide XP build identity. If the owner is in `UNIFIED_SOURCES`, move only that source to ordinary `SOURCES` before assigning the source-specific flag. Do not add XP compatibility defines to ordinary non-XP build configurations merely for convenience.

Authoritative rules and current owners: `XP_MOZ_XP_COMPAT_CONTRACT.md`.

## XP acceptance boundary

A future browser is not accepted as XP-compatible merely because the workflow is GREEN. Acceptance still requires:

1. exact source-under-test SHA;
2. exact run/job identity;
3. inventory-driven ordinary/delay import evidence for shipped/runtime-required PEs;
4. exact package/runtime/diagnostics artifact IDs and hashes;
5. physical Windows XP startup and representative browser use.

A curated known-API list is a regression gate, not exhaustive compatibility proof. A successful XP startup is also not a GOST TLS handshake result.

# Bundled government-system extensions / localization

Current proven three-extension packaging checkpoint remains source `b3d097de20b7a5711f161199a727bcfe9468bcc8`, run `32976571122`, job `98202641607`.

Current corrected Russian localization package gate is source `3e2c32386f373d4693db52b32c05aa2000878def`, workflow `CryptoPro Mozilla packaging smoke`, run `33520207057`, job `99897230730`, success. The previous mass-empty Russian payload defect and final path-shape false negative are closed.

Manual runtime evidence belongs to the exact artifact on which it was observed; do not reattribute it to later packaging-only correction builds.

# Global evidence rules

- Build success != GOST handshake success.
- GOST runtime success != final server-trust closure.
- Focused dependency/runtime success != full Firefox startup.
- Win7 x86 startup != XP startup.
- Source/build removal of a hard import != physical-XP runtime closure until the exact accepted artifact advances past that edge.
- Documentation HEADs never replace the exact source-under-test SHA for previously built or runtime-tested artifacts.
- For in-progress runs, record provisional state and never mark a pending gate as passed.
