# Windows XP x86 — KERNEL32 source-remediation status

Last updated: 2026-09-04

Track: Windows XP SP3 x86 compatibility only. This document does not describe or prove GOST TLS runtime behavior.

Canonical documentation location: `agent/gost-tls-poc:docs/gost/`.

Working implementation branch: `agent/winrt-source-poc`.

For the broader physical-XP startup/runtime-closure investigation, also read `XP_RUNTIME_COMPATIBILITY_STATUS.md`.

## Current conclusion

The KERNEL32 source-remediation quartet is now classified as:

**CURRENT SOURCE REMEDIATED / FINAL-BINARY REVALIDATION IN PROGRESS / 0/4 NOT YET PROVEN.**

Predecessor final `xul.dll` evidence still proves:

- `GetApplicationRestartSettings` — ordinary import present;
- `RegisterApplicationRestart` — absent;
- `UnregisterApplicationRestart` — absent;
- `GetNamedPipeServerProcessId` — ordinary import present.

The two predecessor survivors have since received additional source/build remediation on `agent/winrt-source-poc`. Current implementation HEAD/source-under-test is:

`1a86821ccf50ac07204d1bec438e375ece4e84d6`

Current production revalidation identity:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `33831005002`;
- job `100893816677`;
- source-under-test `1a86821ccf50ac07204d1bec438e375ece4e84d6`;
- status at documentation time: **IN PROGRESS**;
- build had reached the full release browser build after bootstrap/configure/export/security-manager object gates passed;
- quartet diagnostic, final all-PE audit and uploads had not yet executed;
- therefore there are no new package/runtime/diagnostics artifact IDs yet and no final `xul.dll` proof of quartet closure.

Do not mark the quartet closed from source grep, source guards, successful object compilation or aggregate run progress. Acceptance remains exact final `xul.dll` evidence showing all four names absent.

## Predecessor production evidence — two names survived

Exact completed full-build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `2b1cf7e1b59881b935c7f695a54edd6b92c8066e`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33757305364`, attempt `1`;
- job `100654730312`;
- aggregate workflow result: **success**;
- diagnostics artifact `9899307128`.

The intentionally informational step `DIAG - Check source-remediation quartet absent from xul.dll` reported:

```text
result=WARN|surviving=GetApplicationRestartSettings,GetNamedPipeServerProcessId
```

The corresponding `surviving-quartet-imports.txt` contained exactly:

```text
GetApplicationRestartSettings
GetNamedPipeServerProcessId
```

Both names are also visible in the raw predecessor `xul.dll` ordinary import dump. `RegisterApplicationRestart` and `UnregisterApplicationRestart` are absent.

This predecessor evidence remains authoritative for source `2b1cf7...`; it does not describe the unfinished binary from source `1a86821...`.

## Complete source/configuration remediation chain

Earlier accepted chain:

1. `194496e76559e1d86e7e3f920fb3f1fc0e46c2d7` — `fix(xp): disable Windows Application Restart under MOZ_XP_COMPAT` in `toolkit/xre/nsAppRunner.cpp`;
2. `20f00258ac59296782fbaffbf0131d636c0d3c00` — `build(xp): define MOZ_XP_COMPAT for nsAppRunner`;
3. `561bded451638e599fae2d57285446261f9a0035` — `fix(xp): disable modern UIA client detection under MOZ_XP_COMPAT` in `accessible/windows/msaa/CompatibilityUIA.cpp`;
4. `ebe325ad87232f68ca01d7e4c63be14f9c4ee74b` — `build(xp): define MOZ_XP_COMPAT for CompatibilityUIA`.

The later full build exposed two additional/redundant final-link ownership paths. Follow-up chain after source `2b1cf7...`:

5. `50ae0e470bef93f341b9e512bd2d6d684c9aa812` — isolate `widget/windows/nsWindow.cpp` from unified compilation and give it source-local `MOZ_XP_COMPAT` ownership;
6. `5f6c95d0645e8bdfb2add54147bbb3a4da310f81` — exclude `GetApplicationRestartSettings` from `nsWindow.cpp::GetQuitType()` for XP;
7. `ad63965ee8e77bf624a201948e1213de2c16bbae` — isolate `third_party/content_analysis_sdk/browser/src/client_win.cc` from unified compilation and give it source-local `MOZ_XP_COMPAT` ownership;
8. `1a86821ccf50ac07204d1bec438e375ece4e84d6` — keep the content-analysis pipe connection but exclude the optional agent PID/path metadata path that calls `GetNamedPipeServerProcessId` on XP.

## Application Restart trio

The XP release does not intend to emulate the Vista+ Windows Application Restart facility.

Known production ownership is now handled at both identified paths:

### `toolkit/xre/nsAppRunner.cpp`

Under `MOZ_XP_COMPAT`:

- the complete `RegisterApplicationRestartChanged` definition is excluded;
- its `Preferences::RegisterCallbackAndCall(...)` registration is excluded;
- neighboring Windows startup facilities remain unchanged.

The source-local build rule remains:

```python
SOURCES["nsAppRunner.cpp"].flags += ["-DMOZ_XP_COMPAT"]
```

### `widget/windows/nsWindow.cpp`

Predecessor diagnostics showed that `GetApplicationRestartSettings` survived even after `nsAppRunner.cpp` was guarded. The remaining direct production owner was found in:

`nsWindow.cpp::GetQuitType()`.

Current source excludes that Application Restart query under `MOZ_XP_COMPAT` while preserving the ordinary quit-type fallback behavior.

Because `nsWindow.cpp` required source-local compatibility ownership, it was removed from `UNIFIED_SOURCES`, added as an ordinary source and assigned the XP compatibility define in `widget/windows/moz.build`.

The Application Restart trio must remain classified as **final-import pending** until run `33831005002` proves all three names absent from final `xul.dll` ordinary imports.

## `GetNamedPipeServerProcessId`

### Previously remediated UIA owner

`accessible/windows/msaa/CompatibilityUIA.cpp` remains XP-remediated:

- `GetUiaClientPidsWin11` is excluded;
- `GetUiaClientPidWin10` is excluded;
- `Compatibility::GetUiaClientPids` is a no-op in the XP translation unit.

Because the source originally belonged to `UNIFIED_SOURCES`, it was moved to ordinary `SOURCES` before receiving source-local `-DMOZ_XP_COMPAT`.

### Additional owner found after the predecessor full build

The predecessor final `xul.dll` still imported `GetNamedPipeServerProcessId`, proving the UIA owner was not the only final-link path.

The additional production owner was identified in:

`third_party/content_analysis_sdk/browser/src/client_win.cc`.

The call was used after successful named-pipe connection to obtain the server process ID and derive optional agent binary-path metadata.

For the XP build, current source `1a86821...` keeps the actual `ConnectToPipe(...)` connection path but excludes the optional `GetNamedPipeServerProcessId`/agent-path metadata block under `MOZ_XP_COMPAT`. This preserves the core pipe connection while removing the XP-unavailable metadata API.

The owning `toolkit/components/contentanalysis/moz.build` moves only `client_win.cc` from unified compilation to ordinary `SOURCES` and applies source-local `-DMOZ_XP_COMPAT`; neighboring `utils_win.cc` remains unified.

This source remediation is architecturally narrow and matches the established `MOZ_XP_COMPAT` contract. Final closure still requires the exact current full build to prove `GetNamedPipeServerProcessId` absent from final `xul.dll` ordinary imports.

## Focused strategy evidence retained

The earlier representative mechanism proof remains valid historical evidence:

- workflow `.github/workflows/xp-kernel32-source-remediation-smoke.yml` (`XP KERNEL32 source remediation smoke`);
- source-under-test `0450fd8f2b22b9e0263e0755e0ea52f4dd6e2aa4`;
- Actions run `33720100459`;
- job `100537300030`;
- diagnostics artifact `9879912839`;
- artifact digest `sha256:29f742d11f584a07695fcb5cfa87d5f7046e5a22d54470f3b97acb065b85b886`;
- result: **success**.

That smoke established the representative compile/link/import strategy. It did not prove that all real production owners had already been found; predecessor run `33757305364` correctly superseded that assumption by exposing the additional paths.

## Mandatory `MOZ_XP_COMPAT` contract

`MOZ_XP_COMPAT` remains the preferred project-owned compile-time signal for XP-specific source exclusions when the modern Windows feature has no useful XP semantic equivalent.

For every production translation unit containing an accepted `MOZ_XP_COMPAT` boundary, the XP build must define the macro for that exact owner. Source-local ownership remains preferred/required for the accepted boundaries recorded here.

If an affected file is in `UNIFIED_SOURCES` and needs source-specific flags, move only that source to ordinary `SOURCES` before assigning `-DMOZ_XP_COMPAT`.

Existing `MOZ_NO_WINRT` source remediations remain valid and do not need renaming merely for consistency.

Full rules are authoritative in `XP_MOZ_XP_COMPAT_CONTRACT.md`.

## Acceptance for current run

For exact run `33831005002`, job `100893816677`, source `1a86821...`, the quartet line closes only if final production `xul.dll` diagnostics prove:

```text
GetApplicationRestartSettings    absent
RegisterApplicationRestart       absent
UnregisterApplicationRestart     absent
GetNamedPipeServerProcessId      absent
```

That is **0/4 surviving ordinary imports**.

If any name survives, locate the exact remaining owner/link path rather than weakening the diagnostic or substituting a broad shim. If all four are absent, record exact package/runtime/diagnostics artifact IDs and then keep physical-XP startup as a separate acceptance boundary.

## Relationship to the current XP startup crash

Physical Windows XP startup of exact runtime artifact `9899304858` from predecessor run `33757305364` still fails at an exception raised through approximately `kernel32!RaiseException+0x53`. This static quartet cleanup remains necessary, but the fault site alone does not prove that one of these quartet names caused the observed exception.

The physical XP debugger path is now prepared: Dr. Watson is installed as the default application debugger and Debugging Tools for Windows (x86) v6.12.2.633 is available. Root-cause work should proceed independently by capturing the exact `ExceptionCode` and stack for artifact `9899304858`.

Broader static closure findings such as the ordinary `PROPSYS.dll` dependency, `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1`, and unresolved delay-load/WinRT/UIA surfaces are documented in `XP_RUNTIME_COMPATIBILITY_STATUS.md` and are not part of this quartet's acceptance verdict.

## Out of scope for this closure

This source-remediation line does not resolve or reclassify:

- residual YY-owned KERNEL32 APIs already handled by the separate narrow-provider line;
- PROPSYS (`VariantCompare`, `PropVariantToString`);
- DXGI/ANGLE separately linked PE closure;
- bcrypt/One-Core work;
- GOST TLS / MSSPI / SSPI / CryptoPro / handshake work;
- Firefox 153 -> 154 base migration;
- already closed SRW/condition-variable and `CreateWaitableTimerExA` work.

Those remain separate evidence lines.