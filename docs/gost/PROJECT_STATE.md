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
- `NtCancelIoFileEx` YY-Thunks closure: focused source `be122cfc36d84e3144b73bcbaa2a2f46ff45f1a2`, run `33861819326`, job `100987750213`, proved the dedicated narrow-YY probe; full Firefox integration is then proven by source `622a87625036e9c45a8650264336eceeb9be8753`, run `33864176444`, job `100995134125`, diagnostics artifact `9937356676`, where final production `xul.dll` contains `NtCancelIoFile` and not `NtCancelIoFileEx`. Do not reopen the focused or full-integration capability without contradictory evidence.
- the workflow's curated broad forbidden-import progression `69 -> 3 -> 0` is closed for its historical list on run `33757305364`; this is not an exhaustive XP API/DLL proof and the current audit list is broader.
- KERNEL32 source-remediation quartet in final production `xul.dll`: first recorded strict `0/4` binary evidence is source `1a86821ccf50ac07204d1bec438e375ece4e84d6`, run `33831005002`, job `100893816677`, diagnostics artifact `9924338342`.
- final production `xul.dll -> PROPSYS.dll` ordinary dependency is closed at current full-build static-import level by source `622a87625036e9c45a8650264336eceeb9be8753`, run `33864176444`, job `100995134125`: the exact broad forbidden-import report contains no PROPSYS row. Historical predecessor evidence remains valid for the older binaries that did import it.

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

### DPI remediation chain and completed revalidation runs

The root-cause proof is complete. Source remediation is implemented on `agent/winrt-source-poc`.

Implementation chain relevant to the completed revalidation:

- `fad9ec0b5a09c50f6cff39a00a3ea4cedd99cdf2` — initial pre-Vista success/no-op in `WindowsDpiInitialization()`;
- `424708f1d8e754f752e108259b331fcd2ec3615b` — workflow evidence update: pre-build DPI guard check, strict quartet final gate, `mozglue` `SetProcessDPIAware` import-mode gate, separate delay-import inventory, and broader ordinary import audit including `PROPSYS.dll` / `DXGI.dll`;
- `a784a7660b23f8270179f5464c2ac3033d7e0652` — wrap the pre-Vista DPI no-op in `#ifdef MOZ_XP_COMPAT` so the compatibility change is explicitly project-owned;
- `a3ede2576cbc7e92ffae58ba0c49d2c38e580335` — add source-local `-DMOZ_XP_COMPAT` for `mozglue/misc/WindowsDpiInitialization.cpp` in `mozglue/misc/moz.build`.

The earlier full build is:

- run `33842067157`, attempt `1`;
- job `100926221307`;
- source-under-test `424708f1d8e754f752e108259b331fcd2ec3615b`;
- branch `agent/winrt-source-poc`;
- aggregate conclusion: **failure**, but only at final `GATE - Summarize XP x32 full build` after evidence collection;
- package artifact `9927581628`, digest `sha256:ba0e7d77368e1503288902854ab8542a4aa5beda0f307f4aafffff5ee9200bc7`;
- runtime artifact `9927582490`, digest `sha256:03d099306dd2632eabc604e1333001eca3b149c4b7b798e0f2c88269139c70a6`;
- diagnostics artifact `9927583461`, digest `sha256:c85c7a837b7772d89bd5bef1cf750b889165e73fc6f4755b89bcd9bda5068483`.

All decisive build/remediation boundaries before the final summary were GREEN. Its broad clean-XP import inventory contained exactly two rows:

```text
libGLESv2.dll|DLL|dxgi.dll
xul.dll|DLL|PROPSYS.dll
```

The later full integration build now advances this state:

- source-under-test `622a87625036e9c45a8650264336eceeb9be8753` (`fix(xp): restore Rust target expression`);
- branch `agent/winrt-source-poc`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `33864176444`, attempt `1`;
- job `100995134125`;
- aggregate conclusion: **failure** only at final `GATE - Summarize XP x32 full build` after evidence collection;
- package artifact `9937354583`, `327799880` bytes, digest `sha256:9457e3d5102bd60caa4f1cdf23a432fa21444efdd34054e688c1a8f507dc5e98`;
- runtime artifact `9937355457`, `74916090` bytes, digest `sha256:5f60d06985e20282bf4a231a28e2bc5d8945c71ba6e92739ee162b510fda91dd`;
- diagnostics artifact `9937356676`, `5960909` bytes, digest `sha256:88b416d3042522a2284c33617267878bb035dd750f5275aa6de98deacd8e55f6`.

All substantive steps through build, packaging, PE audit and all three uploads are GREEN. Exact diagnostics establish:

```text
xp-x32-source-remediation-quartet/result.txt
result=PASS|surviving=none

xp-x32-dpi-delay-import/result.txt
result=PASS|direct=0|delay_user32=1

xp-x32-direct-imports.txt
xul.dll|API|NtCancelIoFile

xp-x32-forbidden-direct-imports.txt
libGLESv2.dll|DLL|dxgi.dll
```

The same diagnostics contain `diagnostics/yy-ntcancel-capability.txt` with `capability=PASS` bound to focused evidence run `33861819326`, job `100987750213`, source `be122cfc...`. Therefore the focused `NtCancelIoFileEx` YY solution is now transferred successfully into the full Firefox build: final production `xul.dll` no longer carries `NtCancelIoFileEx` and instead retains the XP-present `NtCancelIoFile` import. The previous PROPSYS row is also absent. The aggregate RED is now **only** the separately linked ANGLE/DXGI ordinary DLL dependency.

This later build also contains the later project-owned DPI implementation descendants and revalidates the DPI source/import gates, but physical Windows XP execution remains a separate acceptance boundary. No GOST TLS conclusion follows.

## Physical XP dependency baseline recorded during the same investigation

The current physical XP machine has:

```text
%SystemRoot%\System32\propsys.dll          absent
%SystemRoot%\System32\dxgi.dll             absent
%SystemRoot%\System32\UIAutomationCore.dll present, 158048 bytes, 2010-03-18 10:09
%SystemRoot%\System32\ncrypt.dll           absent
```

Interpretation:

- `PROPSYS.dll` was absent on the physical baseline and was an ordinary dependency of older `xul.dll` artifacts, but the latest full-build static evidence from run `33864176444` no longer contains a PROPSYS forbidden-import row. Treat that old direct dependency as superseded/closed at current final-binary static level; do not infer physical-XP runtime success from static removal alone.
- `dxgi.dll` remains absent and the latest shipped `libGLESv2.dll` still ordinarily imports `dxgi.dll!CreateDXGIFactory1`; this is now the sole row in the current broad forbidden-direct-import report.
- `ncrypt.dll` absence keeps the NCRYPT delay-load surface unresolved, but a missing module would be a different failure class from the confirmed USER32 procedure-not-found event.
- `UIAutomationCore.dll` exists; its exact export/version compatibility is still a separate question.

## KERNEL32 source-remediation quartet — final production `xul.dll` 0/4 proven; strict regression gate revalidated

Predecessor final `xul.dll` diagnostics from artifact `9899307128` proved two surviving ordinary KERNEL32 imports:

- `GetApplicationRestartSettings`;
- `GetNamedPipeServerProcessId`.

`RegisterApplicationRestart` and `UnregisterApplicationRestart` were absent.

The implementation chain source-remediated the remaining owners:

- `widget/windows/nsWindow.cpp::GetQuitType()` excludes `GetApplicationRestartSettings` under source-local `MOZ_XP_COMPAT`;
- `third_party/content_analysis_sdk/browser/src/client_win.cc` preserves the pipe connection but excludes optional `GetNamedPipeServerProcessId` PID/path metadata under source-local `MOZ_XP_COMPAT`.

The first recorded final-production `0/4` proof in this remediation lineage is:

- source-under-test `1a86821ccf50ac07204d1bec438e375ece4e84d6`;
- run `33831005002`;
- job `100893816677`;
- aggregate run/job conclusion **success**;
- diagnostics artifact `9924338342`, digest `sha256:aca17ca427c5f55ccb1a7f838a9d82ae1e07bc68b12cd1061173fb81699a3b09`.

Inside that exact diagnostics artifact, `xp-x32-source-remediation-quartet/result.txt` reports:

```text
result=PASS|surviving=none
```

and the matching final `xul.dll` ordinary-import dump contains none of:

- `GetApplicationRestartSettings`;
- `RegisterApplicationRestart`;
- `UnregisterApplicationRestart`;
- `GetNamedPipeServerProcessId`.

Therefore the quartet is **closed at final-binary ordinary-import level for source `1a86821...`**. Run `33864176444`, job `100995134125`, source `622a876...` revalidates the hardened quartet gate as **PASS / surviving=none**. This is static/full-build evidence only; it does not prove physical-XP runtime success or any GOST TLS behavior.

Detailed quartet history: `XP_KERNEL32_SOURCE_REMEDIATION_STATUS.md`.

## Other proven static/runtime-closure defects

### PROPSYS — closed in latest full-build static evidence

Older exact diagnostics, including artifact `9927583461` from source `424708f...`, run `33842067157`, job `100926221307`, proved final `xul.dll` had an ordinary `PROPSYS.dll` dependency involving `PropVariantToString` and `VariantCompare`.

That finding is superseded for the latest final binary. Diagnostics artifact `9937356676` from source `622a876...`, run `33864176444`, job `100995134125` contains no PROPSYS row in `xp-x32-forbidden-direct-imports.txt`. Therefore PROPSYS is no longer an active current static direct-import blocker. Preserve the older evidence for historical binaries, but do not queue a new PROPSYS remediation cycle unless a later build regresses it or physical runtime evidence identifies a distinct PROPSYS path.

### `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1` — current broad static blocker

Diagnostics artifact `9937356676` from source `622a876...`, run `33864176444`, job `100995134125` contains exactly one broad forbidden direct-import row:

```text
libGLESv2.dll|DLL|dxgi.dll
```

The corresponding direct-import inventory records `CreateDXGIFactory1`. `dxgi.dll` is absent on the physical XP machine. This is a separately linked ANGLE/graphics PE closure defect and is now the only current broad ordinary-import blocker reported by this workflow. Its startup criticality is still a runtime question; remediate it at the `libGLESv2.dll`/ANGLE component boundary rather than through the `xul.dll` linker.

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

Current corrected Russian localization package gate is source `3e2c32386f373d4693db52b32c05aa2000878def`, workflow `CryptoPro Mozilla packaging smoke`, run `33520207057`, job `99897230730`, success. The previous mass-empty-Russian-payload defect and final path-shape false negative are closed.

Manual runtime evidence belongs to the exact artifact on which it was observed; do not reattribute it to later packaging-only correction builds.

# Global evidence rules

- Build success != GOST handshake success.
- GOST runtime success != final server-trust closure.
- Focused dependency/runtime success != full Firefox startup.
- Win7 x86 startup != XP startup.
- Source/build removal of a hard import != physical-XP runtime closure until the exact accepted artifact advances past that edge.
- Documentation HEADs never replace the exact source-under-test SHA for previously built or runtime-tested artifacts.
- For in-progress runs, record provisional state and never mark a pending gate as passed.
