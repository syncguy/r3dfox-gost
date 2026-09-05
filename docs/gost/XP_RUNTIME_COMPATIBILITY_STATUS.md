# Windows XP SP3 x86 — runtime compatibility status

Last updated: 2026-09-04

Track: Windows XP SP3 x86 runtime compatibility only. This document does not describe or prove GOST TLS / NSS / MSSPI / CryptoPro handshake behavior and does not authorize a Firefox/r3dfox 153 -> 154 base update.

Canonical documentation branch: `agent/gost-tls-poc`.

Implementation branch: `agent/winrt-source-poc`.

Frozen baseline: `win-153`; do not modify, merge, rebase or push to it without explicit user instruction.

This is the current handoff for the physical-XP startup and static-runtime-closure line. Read it together with `PROJECT_STATE.md`, `TEST_LOG.md`, `XP_BUILD_CONTRACT.md`, `XP_MOZ_XP_COMPAT_CONTRACT.md`, and `XP_KERNEL32_SOURCE_REMEDIATION_STATUS.md` before proposing runtime-compatibility changes.

## Current exact implementation/build boundary

The latest completed full XP x32 browser remains:

- branch `agent/winrt-source-poc`;
- source-under-test `622a87625036e9c45a8650264336eceeb9be8753` (`fix(xp): restore Rust target expression`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33864176444`, attempt `1`;
- job `100995134125` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate conclusion: **failure only at the final summary gate after all substantive build/package/audit/upload work completed**;
- package artifact `9937354583`, `327799880` bytes, digest `sha256:9457e3d5102bd60caa4f1cdf23a432fa21444efdd34054e688c1a8f507dc5e98`;
- runtime artifact `9937355457`, `74916090` bytes, digest `sha256:5f60d06985e20282bf4a231a28e2bc5d8945c71ba6e92739ee162b510fda91dd`;
- diagnostics artifact `9937356676`, `5960909` bytes, digest `sha256:88b416d3042522a2284c33617267878bb035dd750f5275aa6de98deacd8e55f6`.

All substantive steps through compile, link, packaging, runtime-archive construction, final PE/import inventory and all three uploads are GREEN. The run-level RED is deliberate evidence propagation from one remaining broad ordinary-import finding.

The implementation branch has since advanced with the focused ETW smoke source `53971dcfdf12e7bcd7f35692ff2c02fb3360d792`, but that source has not yet produced a new full Firefox browser. Do not reattribute focused evidence to the older full runtime artifact.

## Current full-build static result

Exact diagnostics artifact `9937356676` establishes:

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

The matching inventory also records `libGLESv2.dll|API|CreateDXGIFactory1`.

The broad static audit therefore has one known row:

```text
libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1
```

`dxgi.dll` is absent on the physical XP machine. This broad audit is not exhaustive: the subsequent physical startup proved that the same final `xul.dll` also has XP-incompatible ordinary ADVAPI32 ETW imports that were not included in that gate.

## `NtCancelIoFileEx` — focused YY proof transferred into production Firefox

The focused capability proof is:

- source `be122cfc36d84e3144b73bcbaa2a2f46ff45f1a2`;
- workflow `XP x86 core KERNEL32 cluster smoke`;
- run `33861819326`;
- job `100987750213`;
- dedicated `Build and run NtCancelIoFileEx YY probe` — PASS.

The full-build diagnostics contain `diagnostics/yy-ntcancel-capability.txt` with:

```text
capability=PASS
evidence_run=33861819326
evidence_job=100987750213
evidence_sha=be122cfc36d84e3144b73bcbaa2a2f46ff45f1a2
```

The final production `xul.dll` direct-import inventory contains `NtCancelIoFile` and contains no `NtCancelIoFileEx`.

Conclusion: **the narrow YY-Thunks `NtCancelIoFileEx` path is closed at both focused capability and full Firefox final-PE integration level.** The production linker no longer exposes the XP-incompatible native `NtCancelIoFileEx` import to the XP loader. Do not reopen this line without contradictory final-PE or physical-runtime evidence.

This does not mean that the YY implementation is proven to be a single direct call to `NtCancelIoFile`; final-PE evidence proves the resulting dependency boundary, while the thunk implementation may contain additional adaptation logic.

## PROPSYS — current final-production ordinary dependency closed

The predecessor full-build diagnostics from source `424708f1d8e754f752e108259b331fcd2ec3615b`, run `33842067157`, job `100926221307`, diagnostics artifact `9927583461`, contained exactly:

```text
libGLESv2.dll|DLL|dxgi.dll
xul.dll|DLL|PROPSYS.dll
```

The current exact run `33864176444` contains no `xul.dll|DLL|PROPSYS.dll` row in the broad forbidden-import report.

Conclusion: **the final-production `xul.dll -> PROPSYS.dll` ordinary dependency is closed at current full-build static-import level.** Historical diagnostics remain valid for older artifacts that contained it; do not project that old dependency onto source `622a876...`.

The physical XP machine still lacks `%SystemRoot%\System32\propsys.dll`, but that fact is no longer a current ordinary-import blocker for the latest production `xul.dll`.

## KERNEL32 source-remediation quartet — closed and regression-gated

The quartet is:

```text
GetApplicationRestartSettings
RegisterApplicationRestart
UnregisterApplicationRestart
GetNamedPipeServerProcessId
```

First recorded final-production 0/4 proof:

- source `1a86821ccf50ac07204d1bec438e375ece4e84d6`;
- run `33831005002`;
- job `100893816677`;
- diagnostics artifact `9924338342`;
- result `PASS|surviving=none`.

The strict gate is revalidated in current run `33864176444`, job `100995134125`, source `622a876...`: `result=PASS|surviving=none`.

This line is closed at final-production ordinary-import level. Do not repeat the old predecessor search for two survivors unless new diagnostics contradict the current gate.

## Historical physical-XP failure and confirmed root cause

The physical startup failure that drove the current remediation chain belongs to an older exact browser:

- source `2b1cf7e1b59881b935c7f695a54edd6b92c8066e`;
- run `33757305364`;
- job `100654730312`;
- runtime artifact `9899304858`, digest `sha256:7d6eff6a4af1b1358f17ed1db9f9194d03702298def5708542a6510aa10029e0`;
- diagnostics artifact `9899307128`, digest `sha256:cb08028e3518d8834b50d50b9b68a98e3166a2c25a0177397214a8dabd6b3132`.

Physical results for that exact runtime artifact:

- Windows 7 x86: startup/basic checks PASS;
- Windows XP SP3 x86: stable immediate startup failure.

Classic x86 WinDbg `6.12.0002.633` captured first-chance `0xC06D007F` and decoded the x86 `DelayLoadInfo` as:

```text
szDll           = "USER32.dll"
fImportByName   = 1
szProcName      = "SetProcessDPIAware"
hmodCur         = 7e410000
pfnCur          = 00000000
dwLastError     = 0000007f
```

The physical XP `USER32.dll` exports `DefWindowProcW` and `PeekMessageW` but not `SetProcessDPIAware`.

Therefore the exact historical crash is conclusively:

```text
r3dfox.exe startup
  -> WindowsDpiInitialization()
  -> XP takes the pre-Win8.1 fallback
  -> SetProcessDPIAware()
  -> USER32 delay-load resolution
  -> export absent
  -> ERROR_PROC_NOT_FOUND (0x7f)
  -> C06D007F
  -> kernel32!RaiseException
```

That root-cause investigation is closed. Do not return to generic `kernel32!RaiseException` speculation for artifact `9899304858`.

## DPI remediation — source/static integration closed; physical progression confirmed

The remediation chain is:

- `fad9ec0b5a09c50f6cff39a00a3ea4cedd99cdf2` — pre-Vista success/no-op in `WindowsDpiInitialization()`;
- `424708f1d8e754f752e108259b331fcd2ec3615b` — workflow source/import gates;
- `a784a7660b23f8270179f5464c2ac3033d7e0652` — explicit `#ifdef MOZ_XP_COMPAT` ownership;
- `a3ede2576cbc7e92ffae58ba0c49d2c38e580335` — source-local `-DMOZ_XP_COMPAT` ownership.

The full source `622a876...` contains descendants of this implementation and passes both the pre-build source guard and final `mozglue` import-mode gate:

```text
result=PASS|direct=0|delay_user32=1
```

Physical execution of runtime artifact `9937355457` no longer stops at the historical `SetProcessDPIAware` delay-load failure; it advances to the later `ADVAPI32!EventRegister` loader edge. This is physical progression evidence for the DPI remediation line, not full XP browser acceptance.

## Current physical startup blocker — production `xul.dll` ADVAPI32 ETW family

Physical execution of exact runtime artifact `9937355457` from source `622a876...`, run `33864176444`, job `100995134125` now stops with:

```text
r3dfox.exe - Entry Point Not Found
The procedure entry point EventRegister could not be located in the dynamic link library ADVAPI32.dll.
```

The matching final-production import inventory in diagnostics artifact `9937356676` identifies `xul.dll` as owner of four ordinary ADVAPI32 ETW entry points:

```text
EventRegister
EventUnregister
EventWrite
EventWriteTransfer
```

Treat the complete family as one production closure target rather than fixing only the first loader-reported symbol.

### Focused ETW YY capability — PASS

The dedicated focused proof is exact:

- source-under-test `53971dcfdf12e7bcd7f35692ff2c02fb3360d792` (`test(xp): add focused ADVAPI32 ETW YY probe`);
- workflow `.github/workflows/xp-core-kernel32-cluster-smoke.yml` / `XP x86 core KERNEL32 cluster smoke`;
- run `33882235341`;
- job `101053403554`;
- aggregate conclusion **success**;
- runtime artifact `9940665095`, `664101` bytes, digest `sha256:0fa3b523fb949bc364fc70abd1496b15f2e92590062077600135ff55bd731b01`;
- diagnostics artifact `9940665687`, `1059759` bytes, digest `sha256:e853d7128c092420c3d2e1da0184137fcd7ae42d0b439f5ead8acbc3e243964f`.

The dedicated `Build and run ADVAPI32 ETW YY probe` step is GREEN. Exact diagnostics prove one selected weak-alias `.obj/.obi` pair for each of the four APIs, reuse of the already-proven common `NARROW_YY_LIB` implementation, linker-map selection of all four `YY_Thunks_*` bodies, absence of all four direct imports from the focused executable, and hosted output `ADVAPI32 ETW family: PASS` with status `0` for each call.

Conclusion: **focused YY capability for all four observed production ETW imports is closed. Production Firefox integration is still open.** Do not rerun the capability question unless contradictory evidence appears; move the exact alias set into the full Firefox link and prove final `xul.dll` closure.

## Current physical XP DLL baseline

The current physical XP machine reports:

```text
%SystemRoot%\System32\propsys.dll          absent
%SystemRoot%\System32\dxgi.dll             absent
%SystemRoot%\System32\UIAutomationCore.dll present, 158048 bytes, 2010-03-18 10:09
%SystemRoot%\System32\ncrypt.dll           absent
```

Current interpretation:

- `propsys.dll` absence is historical context only for the latest build because current production `xul.dll` no longer carries the ordinary PROPSYS dependency;
- `dxgi.dll` absence matches the independent broad ordinary-import blocker `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1`;
- `ncrypt.dll` absence is relevant if/when runtime or mandatory static evidence reaches that surface; it is **not currently promoted to a blocker**;
- `UIAutomationCore.dll` presence eliminates the simplest missing-module hypothesis but does not prove every required UIA export/path is XP-compatible.

## Planned NCRYPT source-level remediation if evidence reaches it

Status: **pre-agreed plan only.** There is no exact current run/artifact proving NCRYPT as the next startup or ordinary-browsing blocker, so do not implement this merely because the physical XP system lacks `ncrypt.dll`.

Current Firefox 153 source on the XP implementation branch shows that `security/manager/ssl/osclientcerts/src/backend_windows.rs` already contains both Windows private-key paths in one backend:

```text
KeyHandle::NCrypt
  -> NCryptSignHash
  -> NCryptFreeObject

KeyHandle::CryptoAPI
  -> CryptSignHashW
  -> CryptReleaseContext
```

`KeyHandle::from_cert` currently calls `CryptAcquireCertificatePrivateKey` with `CRYPT_ACQUIRE_PREFER_NCRYPT_KEY_FLAG` and then chooses `NCrypt` versus `CryptoAPI` from the returned `key_spec`. The existing `CryptoAPI` branch is therefore the preferred XP implementation substrate; no new signing backend should be invented unless exact evidence proves it insufficient.

Current build-control facts:

- `security/manager/ssl/osclientcerts/Cargo.toml` has no ready-made XP / legacy-CryptoAPI-only feature;
- the Windows Rust backend is selected only by ordinary `target_os = "windows"` / architecture `cfg` conditions;
- `i686-pc-windows-msvc` does not encode XP versus Vista/7/modern Windows;
- the project's C/C++ `MOZ_XP_COMPAT` define does not automatically become a Rust `cfg`.

If NCRYPT becomes a real boundary, remediation order is:

1. **Introduce one explicit, project-owned Rust XP condition** for the affected crate/build path, e.g. a dedicated `cfg` such as `moz_xp_compat` or an equivalently narrow Cargo/build feature. Final naming is an implementation detail; ownership and scope are the requirement.
2. **Under that XP condition, stop preferring NCrypt during certificate private-key acquisition.** Use XP-supported `CryptAcquireCertificatePrivateKey` semantics without `CRYPT_ACQUIRE_PREFER_NCRYPT_KEY_FLAG` so legacy CSP/CryptoAPI keys naturally stay on the already-existing `CryptoAPI` path.
3. **Compile out the NCrypt-only branch from the XP binary where needed to eliminate hard imports.** Do not leave `NCryptSignHash` / `NCryptFreeObject` reachable only in dead source if the final PE still acquires a hard `ncrypt.dll` dependency.
4. **Keep normal Windows builds unchanged.** The XP condition must not silently force legacy CryptoAPI on Vista/7/modern Windows builds that are outside the XP compatibility configuration.
5. **Add a build/source gate proving the Rust XP condition is active in `osclientcerts`.** Do not accept the C/C++ define, target triple, or mozconfig intention as proof that rustc compiled the intended branch.
6. **Add a strict final PE/import gate for the exact owner.** For the XP artifact, require no ordinary `ncrypt.dll` dependency and no hard `NCryptSignHash` / `NCryptFreeObject` imports in the shipped/runtime-required PE closure attributable to this backend.
7. **Revalidate Firefox's ordinary OS client-certificate behavior on the exact rebuilt artifact** if that path is part of acceptance. Keep this evidence separate from the project's GOST MSSPI/SSPI/CryptoPro transport, which is a different runtime track.

Architecture rule for this surface: **prefer source-level compile-time selection of Firefox's existing legacy CryptoAPI backend before any YY-Thunks solution for NCRYPT.** Only consider a narrow YY probe if source-level removal is proven insufficient for a specific remaining owner/import. Do not attempt to emulate the complete CNG/KSP subsystem on XP merely because `ncrypt.dll` is absent.

## Independent broad static blocker — separately linked ANGLE/DXGI edge

The broad static audit still reports:

```text
libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1
```

This is a different ownership boundary from the current `xul.dll` ETW runtime blocker:

- `libGLESv2.dll` is a separately linked PE;
- changes to the `xul.dll` link line cannot remove this import;
- the preferred remediation is source/build/backend selection at the ANGLE / `libGLESv2.dll` component boundary;
- the physical loader currently stops first at `ADVAPI32!EventRegister`, so no runtime conclusion about DXGI startup criticality follows yet.

The static clean-XP gate must still be closed before final acceptance even if a later runtime proves the graphics PE optional during initial startup.

## Next experiment order

1. **Integrate the exact four proven ADVAPI32 weak-alias pairs into the full XP x32 Firefox target-link path.** Reuse the existing common narrow YY implementation; do not link full YY `advapi32.lib`.
2. **Add a strict final-`xul.dll` ETW gate.** Require `EventRegister`, `EventUnregister`, `EventWrite`, and `EventWriteTransfer` all absent as ordinary ADVAPI32 imports.
3. **Run a new full build under a new exact source SHA.** Bind source/run/job and package/runtime/diagnostics identities, while preserving `NtCancelIoFileEx`, PROPSYS, quartet, DPI, CRT, bcrypt and D3DCompiler closures.
4. **Test that exact new runtime artifact on physical XP.** Do not retest artifact `9937355457` expecting the focused smoke to alter it. If startup advances, capture the next actual boundary.
5. **Continue the separate ANGLE/DXGI static remediation.** Trace `CreateDXGIFactory1` ownership in the exact `libGLESv2.dll` build and choose the narrowest XP-compatible component-level path.
6. **Only after actual runtime or mandatory static evidence reaches other modern delay/dynamic surfaces**, investigate WinRT API sets, UIAutomationCore, NCRYPT, AVRT, DWMAPI or other optional paths. Do not mass-patch them preemptively. If the evidence reaches NCRYPT, execute the source-level Rust/legacy-CryptoAPI plan above before considering YY-Thunks.
7. **GOST TLS on XP remains later and separate.** A browser that starts and browses on XP still does not prove MSSPI/CryptoPro GOST TLS behavior.

## Closed families — do not reopen without contradictory evidence

- pinned/restored msvcr14x XP runtime contract;
- SRW / condition-variable closure;
- `CreateWaitableTimerExA` fallback;
- exact app-local `xp-bcrypt-v1/bcrypt.dll`;
- legacy `D3DCompiler_47.dll` staging/package path;
- narrow YY residual KERNEL32 providers including `TryAcquireSRWLockExclusive` and `FlsGetValue`;
- focused + full-integration `NtCancelIoFileEx` narrow-YY closure;
- focused ADVAPI32 ETW YY capability for `EventRegister`, `EventUnregister`, `EventWrite`, and `EventWriteTransfer` — focused closure only, production integration pending;
- KERNEL32 source-remediation quartet at final-production 0/4;
- current final-production `xul.dll -> PROPSYS.dll` ordinary-dependency closure;
- historical `SetProcessDPIAware` root-cause diagnosis and current source/static DPI remediation integration;
- historical curated broad-gate `69 -> 3 -> 0` progression.

A new family-specific contradiction is required to reopen them.

# Acceptance boundary

A future browser is not accepted as XP-compatible merely because the workflow is GREEN. Acceptance still requires:

1. exact source-under-test SHA;
2. exact run/job identity;
3. inventory-driven ordinary/delay import evidence for the shipped/runtime-required PE closure;
4. exact package/runtime/diagnostics artifact IDs and hashes;
5. physical Windows XP startup and representative browser use.

Likewise, successful XP startup does not establish any GOST TLS handshake result.