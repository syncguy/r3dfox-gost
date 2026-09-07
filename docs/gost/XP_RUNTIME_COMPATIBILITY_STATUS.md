# Windows XP SP3 x86 — runtime compatibility status

Last updated: 2026-09-07

Track: Windows XP SP3 x86 runtime compatibility only. This document does not describe or prove GOST TLS / NSS / MSSPI / CryptoPro handshake behavior and does not authorize a Firefox/r3dfox 153 -> 154 base update.

Canonical documentation branch: `agent/gost-tls-poc`.

Implementation branch: `agent/winrt-source-poc`.

Frozen baseline: `win-153`; do not modify, merge, rebase or push to it without explicit user instruction.

This is the current handoff for the physical-XP startup and static-runtime-closure line. Read it together with `PROJECT_STATE.md`, the newest XP entries in `TEST_LOG.md`, `TODO.md`, `XP_BUILD_CONTRACT.md`, `XP_MOZ_XP_COMPAT_CONTRACT.md`, and `XP_KERNEL32_SOURCE_REMEDIATION_STATUS.md` before proposing runtime-compatibility changes. When identities differ, the newest exact source/run/job/artifact record in `PROJECT_STATE.md` / `TEST_LOG.md` is authoritative.

## Latest completed build/static boundary — GREEN

The latest completed full XP x32 build/static candidate is:

- branch `agent/winrt-source-poc`;
- source-under-test `b386b7f4ba8fd20619a2b7ee541a6b8fe609e278`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34038288272`, attempt `1`;
- job `101500284497` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate conclusion: **success**;
- package artifact `9992439692`, `327779922` bytes, digest `sha256:d38cee9081debcab2beedab3b8254574bbc85e6cc135f52839a6ec2bb58db651`;
- runtime artifact `9992440155`, `74923409` bytes, digest `sha256:33731607bbef1e01cfe8b9063be56dd17f149bb9aae547349e7e5b6f5d8c32f4`;
- diagnostics artifact `9992440699`, `6007435` bytes, digest `sha256:0820af3fdfc031ca10dc21546c5f4caee6080da7477aac4109c8e5a3be9fdc6f`.

Relative to the preceding GREEN source `176eb94b503e773334593508df408fa491faa45f`, the only repository file changed in the two-commit compare is `.github/workflows/gost-poc-build-xp-x32.yml`. Commit `87f09e31b24157af44b3068480295da66e054405` adds the scoped YY-Thunks DLL/TLS entry-point contract for `xul.dll`, and commit `b386b7f4ba8fd20619a2b7ee541a6b8fe609e278` fixes the generated `toolkit/library/moz.build` indentation so the contract is applied under the intended `xul-real` / `WINNT` scope:

```text
-ENTRY:DllMainCRTStartupForYY_Thunks
-alternatename:_YY_ThunksOriginalDllMainCRTStartup@12=__DllMainCRTStartup@12
```

The exact job completed the full Firefox compile/link, packaging, source-remediation gates, ADVAPI32 compatibility gate, DPI delay-import gate, core XP direct-import rejection, PE retarget/audit gates, all artifact uploads and final summary successfully.

## Physical XP result — old xul critical-section blocker CLOSED

The exact runtime artifact `9992440155` has been physically executed on Windows XP SP3 x86. User-reported extracted-file identities are:

- `r3dfox.exe` SHA-1 `a2a64f6eb719d632b6264d48984de9e85a82acb7`;
- `xul.dll` SHA-1 `7ef46570af15390fa1c431c9d1b93ff985d79c22`.

On this exact browser the previous startup access violation in `ntdll!RtlpWaitForCriticalSection` from `xul.dll` is no longer observed. Therefore the old critical-section blocker is physically closed for source `b386b7f4...` / run `34038288272` / job `101500284497` / runtime artifact `9992440155`.

The preceding physical failure remains historical evidence for a different exact browser:

- source `176eb94b503e773334593508df408fa491faa45f`;
- run `34027798932`, job `101471779766`;
- runtime artifact `9989657830`, digest `sha256:64b0f5a0ccf94900fa882069369e26d3beaf46fa128f7b6b650c44d1e87c2c2f`;
- diagnostics artifact `9989658809`, digest `sha256:9e3e9e2e6fac3f0a33a17d94bdf0460edd1020c61c388307a2f8ccd78e2f50fb`.

That older artifact failed with:

```text
Exception: C0000005
ntdll!RtlpWaitForCriticalSection
  -> ntdll!RtlEnterCriticalSection
  -> xul.dll
  -> xul!XRE_GetBootstrap
```

and the fault shape was:

```text
mov eax,[esi]
inc dword ptr [eax+0x10]
```

with `EAX == 0`, consistent with a null `RTL_CRITICAL_SECTION.DebugInfo` in the contended wait path. This is no longer the current runtime blocker and must not be projected onto later artifacts.

The old disassembly finding also remains historical: YY-Thunks' selected `InitializeCriticalSectionEx` XP fallback ignored the third `Flags` argument and called `InitializeCriticalSectionAndSpinCount`, so direct forwarding of `CRITICAL_SECTION_NO_DEBUG_INFO` was not supported as the explanation. The separate DLL/TLS entry-point integration variable was then changed by `b386b7f4...`, and the exact successor browser advanced physically beyond the failure.

## Current compatibility line — IP Helper API

After the critical-section closure, active XP work moved to IP Helper API ownership in `xul.dll` and its source components.

Current implementation lineage after `b386b7f4...`:

- `97ad36ef0322f307ccb43bc4dd5fdcc744a22f16` — `nsNotifyAddrListener.cpp` adds the XP `NotifyAddrChange` monitoring path and excludes the Vista+ `NotifyIpInterfaceChange` callback path under `MOZ_XP_COMPAT`;
- `9ea33a7b2972e231c95157db416fe866e6f6c667` — `netwerk/system/win32/moz.build` compiles `nsNotifyAddrListener.cpp` with `-DMOZ_XP_COMPAT`;
- `7e4965bc2057f6f0a75d043f0711fefbcfddff68` — vendored `third_party/rust/mtu/src/windows.rs` uses an XP legacy adapter-enumeration path instead of `GetIpInterfaceTable` / `FreeMibTable` / `if_indextoname`;
- `bc37171160d9cad9b81b81da681626b0dd9dcd2d` — refreshes the corresponding vendored `mtu` checksum;
- current implementation HEAD `0a18ba85b3f493b17c5a62742e869788ca3f2f6b` — adds a non-blocking final-`xul.dll` IPHLPAPI import diagnostic.

The current diagnostic expects these post-XP/modern paths to be absent from final `xul.dll`:

```text
NotifyIpInterfaceChange
CancelMibChangeNotify2
GetIpInterfaceTable
FreeMibTable
if_indextoname
```

and explicitly records these intended legacy IP Helper imports:

```text
GetAdaptersAddresses
GetBestInterfaceEx
```

This diagnostic is evidence collection, not an acceptance gate by itself.

### Current validation run — provisional

- source-under-test `0a18ba85b3f493b17c5a62742e869788ca3f2f6b`;
- workflow `GOST TLS PoC build  XP x32`;
- run `34079480996`, attempt `1`;
- job `101611911453`;
- state at last check: **in progress**.

At that check, setup through configure/export and the SSL target-object gate had passed, while `Build release r3dfox XP x32` was still running. The new IPHLPAPI diagnostic and all later final/static/package gates were still pending. Do not record them as passed until the exact run completes.

## Historical loader/runtime progression — closed evidence

### `SetProcessDPIAware`

The historical browser source `2b1cf7e1b59881b935c7f695a54edd6b92c8066e`, run `33757305364`, job `100654730312`, runtime artifact `9899304858` failed on physical XP with delay-load exception `0xC06D007F` because `USER32.dll!SetProcessDPIAware` is absent on XP.

Classic x86 WinDbg decoded the delay-load target as:

```text
szDll           = "USER32.dll"
szProcName      = "SetProcessDPIAware"
dwLastError     = 0000007f
```

That root cause is closed. The pre-Vista source guard and current DPI delay-import gate remain part of the full-build regression contract.

### `NtCancelIoFileEx`

Focused capability:

- source `be122cfc36d84e3144b73bcbaa2a2f46ff45f1a2`;
- workflow `XP x86 core KERNEL32 cluster smoke`;
- run `33861819326`, job `100987750213`;
- dedicated `NtCancelIoFileEx` YY probe: PASS.

Full Firefox integration later removed `NtCancelIoFileEx` from final production `xul.dll`, leaving the XP-side native boundary at `NtCancelIoFile`. This line remains closed unless contradictory final-PE or physical-runtime evidence appears.

### ADVAPI32 ETW family

The physical browser from source `622a87625036e9c45a8650264336eceeb9be8753`, run `33864176444`, job `100995134125`, runtime artifact `9937355457` advanced past earlier failures and stopped at missing `ADVAPI32.dll!EventRegister`. The final `xul.dll` owned the four-name family:

```text
EventRegister
EventUnregister
EventWrite
EventWriteTransfer
```

Focused YY capability for all four names passed at source `53971dcfdf12e7bcd7f35692ff2c02fb3360d792`, run `33882235341`, job `101053403554`. Later full-build integration closed the production ETW imports; the latest completed full build keeps the dedicated ADVAPI32 compatibility gate GREEN. Do not leave ETW as current backlog.

### ANGLE / DXGI

The earlier broad static blocker:

```text
libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1
```

was owned by separately linked `libGLESv2.dll`, not by `xul.dll`. Later compatibility work removed this XP-incompatible static edge while preserving the intended D3D9 fallback path. Do not reopen this line merely because physical XP lacks `dxgi.dll`.

### WS2_32

The observed WS2_32 family, including focused capability for `WSAIoctl` / `inet_ntop` and later integration work for `WSASendMsg` / `WSCGetProviderInfo`, is incorporated into the current GREEN lineage. Reopen only on contradictory exact import/runtime evidence.

## Current physical XP system-DLL baseline

The current physical XP machine has previously reported:

```text
%SystemRoot%\System32\propsys.dll          absent
%SystemRoot%\System32\dxgi.dll             absent
%SystemRoot%\System32\UIAutomationCore.dll present, 158048 bytes, 2010-03-18 10:09
%SystemRoot%\System32\ncrypt.dll           absent
```

Interpretation under the current lineage:

- `propsys.dll` absence is historical context because production `xul.dll` no longer carries the ordinary PROPSYS dependency;
- `dxgi.dll` absence is historical context because the static `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1` edge was removed;
- `ncrypt.dll` absence matters only if exact runtime or mandatory static evidence reaches that surface; it is not currently promoted to a blocker;
- `UIAutomationCore.dll` presence eliminates the simplest missing-module hypothesis but does not prove every required UIA export/path is XP-compatible.

## Planned NCRYPT source-level remediation if evidence reaches it

Status: **pre-agreed plan only.** There is no exact current run/artifact proving NCRYPT as the next startup or ordinary-browsing blocker, so do not implement this merely because the physical XP system lacks `ncrypt.dll`.

Firefox 153 already contains both Windows private-key paths in `security/manager/ssl/osclientcerts/src/backend_windows.rs`:

```text
KeyHandle::NCrypt
  -> NCryptSignHash
  -> NCryptFreeObject

KeyHandle::CryptoAPI
  -> CryptSignHashW
  -> CryptReleaseContext
```

If NCRYPT becomes a real boundary:

1. introduce one explicit project-owned Rust XP condition for the affected crate/build path;
2. under that condition, stop preferring NCrypt during `CryptAcquireCertificatePrivateKey` and select the existing CryptoAPI path;
3. compile out NCrypt-only code where required to remove hard `ncrypt.dll` imports;
4. keep non-XP Windows builds unchanged;
5. add a build/source gate proving the Rust XP condition is active;
6. add a strict final PE/import gate for the exact owner;
7. revalidate Firefox's ordinary OS client-certificate behavior on the exact rebuilt artifact if required.

Architecture rule: prefer source-level compile-time selection of Firefox's existing legacy CryptoAPI backend before any YY-Thunks solution for NCRYPT. Do not emulate the complete CNG/KSP subsystem on XP preemptively.

## Closed families — do not reopen without contradictory evidence

- pinned/restored msvcr14x XP runtime contract;
- SRW / condition-variable closure;
- `CreateWaitableTimerExA` fallback;
- exact app-local `xp-bcrypt-v1/bcrypt.dll`;
- legacy `D3DCompiler_47.dll` staging/package path;
- narrow YY residual KERNEL32 providers including `TryAcquireSRWLockExclusive` and `FlsGetValue`;
- focused + full-integration `NtCancelIoFileEx` narrow-YY closure;
- ADVAPI32 ETW focused + full Firefox integration closure for the observed four-name family;
- KERNEL32 source-remediation quartet at final-production 0/4;
- final-production `xul.dll -> PROPSYS.dll` ordinary-dependency closure;
- historical `SetProcessDPIAware` root-cause diagnosis and source/static DPI remediation;
- WS2_32 observed compatibility family integration;
- ANGLE/DXGI `CreateDXGIFactory1` static closure;
- YY-Thunks DLL/TLS entry-point integration for `xul.dll` at full-build/static level;
- physical closure of the old `xul.dll` `RtlpWaitForCriticalSection` startup failure on runtime artifact `9992440155`;
- historical curated broad-gate `69 -> 3 -> 0` progression.

A new family-specific contradiction is required to reopen any of them.

## Next experiment order

1. **Finish and classify run `34079480996`.** Bind the result to job `101611911453` and source `0a18ba85b3f493b17c5a62742e869788ca3f2f6b`; inspect the exact final IPHLPAPI diagnostic and preserve every already-closed regression gate.
2. **If the full build succeeds, physically test its exact runtime artifact on Windows XP SP3 x86.** Do not infer runtime closure from source or final imports alone.
3. **Use the complete final `xul.dll` IPHLPAPI inventory to close the family by owner rather than one loader error at a time.** Preserve only the intended XP-supported `GetAdaptersAddresses` / `GetBestInterfaceEx` path unless exact evidence requires a different owner-specific solution.
4. **If physical XP advances, capture the next actual runtime boundary and update `TEST_LOG.md` / `PROJECT_STATE.md` before starting another subsystem.**
5. **Investigate optional modern surfaces only when evidence reaches them.** WinRT API sets, UIAutomationCore, NCRYPT, AVRT, DWMAPI and similar paths remain hypotheses until exact runtime/static evidence promotes them.
6. **GOST TLS on XP remains later and separate.** A browser that starts and browses on XP still does not prove MSSPI/CryptoPro GOST TLS behavior.

# Acceptance boundary

A browser is not accepted as XP-compatible merely because the workflow is GREEN. Acceptance still requires:

1. exact source-under-test SHA;
2. exact run/job identity;
3. inventory-driven ordinary/delay import evidence for the shipped/runtime-required PE closure;
4. exact package/runtime/diagnostics artifact IDs and hashes;
5. physical Windows XP startup and representative browser use.

Likewise, successful XP startup does not establish any GOST TLS handshake result.