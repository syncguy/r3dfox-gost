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

For Windows XP work, read `XP_BUILD_CONTRACT.md` and, for source compile-out rules, `XP_MOZ_XP_COMPAT_CONTRACT.md` before proposing build/configuration changes. For the current physical-XP startup/runtime-closure investigation, also read `XP_RUNTIME_COMPATIBILITY_STATUS.md`.

## Separation of conclusions

Keep these tracks independent unless a deliberately combined experiment tests both:

1. GOST TLS runtime / NSS / NSPR / MSSPI / SSPI / CryptoPro / handshake.
2. Windows Vista/7/XP compatibility / Rust / msvcr14x / YY-Thunks / linker / PE imports / physical runtime.
3. Bundled government-system extensions and localization/package behavior.

A successful build is not a successful GOST handshake. A hosted compatibility probe is not physical-XP proof. Win7 x86 runtime success is not XP import closure. A documentation commit is never the source-under-test SHA for an earlier artifact.

# GOST TLS runtime

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

Current runtime constraints include:

- TLS 1.2 / HTTP/1.1 PoC path;
- coordinated Firefox client-auth picker as default;
- `Session` is the current default positive certificate choice and remains process-local;
- true persistent `Permanent` semantics remain open;
- final fail-closed server verification remains open;
- synchronous provider/key access can still block the shared Firefox Socket Thread during long CryptoPro waits.

Current authoritative Session-default browser source is `afbdad307f63e594d3715169d6e34235280dddaf`, full build run `33073577269`, job `98521835354`, release artifact `9652941006`.

Current GOST runtime work remains: persistent `Permanent` semantics, provider-boundary testing, provider-wait comparison with stock Firefox, and final fail-closed server trust / certificate-override integration.

# Windows XP SP3 x86 compatibility

This track is independent of GOST TLS runtime. Active implementation work is on `agent/winrt-source-poc`; documentation remains on `agent/gost-tls-poc`.

Detailed current runtime-closure/debugger handoff: `XP_RUNTIME_COMPATIBILITY_STATUS.md`.

## Closed compatibility families

Do not reopen without new contradictory evidence:

- SRW / condition-variable family: source `d65b464c74caadace97995f07a4919363c41a0ea`, run `33470957048`, job `99740439208`;
- `CreateWaitableTimerExA`: source-level fallback closure, source `17cdb459ec4f115a209fd50ac225cf867b9f3a2f`, run `33638897692`, job `100276666021`;
- selected single-DLL `bcrypt.dll`: source `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`, run `33513084915`, job `99873297193`, physically proven on Windows XP and published as `xp-bcrypt-v1`;
- legacy `D3DCompiler_47.dll` staging/packaging: source `b77b22ef1e35564dfe76997d3d393d45ee697e49`, run `33349340069`, job `99359475336`.

Full YY `kernel32.lib` interposition remains prohibited. Keep per-PE/provider ownership narrow.

## Latest completed full XP x32 build/package evidence — first workflow GREEN, physical XP startup FAIL

The latest completed full-browser compatibility run is:

- experiment branch `agent/winrt-source-poc`;
- exact source-under-test `2b1cf7e1b59881b935c7f695a54edd6b92c8066e` (`ci(xp): add residual YY KERNEL32 providers`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33757305364`, job `100654730312`, attempt `1`;
- aggregate CI conclusion: **success** — the first fully GREEN run of the current XP x32 full-build workflow lineage.

Exact artifacts from this run:

- package artifact `9899302735`, digest `sha256:baeb2aaa2c31599da56c2b1c767bdd969914e034ab2c94826c0dd18db36d394b`;
- runtime artifact `9899304858`, digest `sha256:7d6eff6a4af1b1358f17ed1db9f9194d03702298def5708542a6510aa10029e0`;
- diagnostics artifact `9899307128`, digest `sha256:cb08028e3518d8834b50d50b9b68a98e3166a2c25a0177397214a8dabd6b3132`.

The complete hard-gate chain is GREEN: pinned msvcr14x contract, narrow YY provider construction and all-target-link activation, Firefox configure/export/security-manager compile gate, full Firefox release build, production core-browser import gate, D3D staging/retarget/package survival, CRT package survival, exact `xp-bcrypt-v1` package survival, runtime archive creation, inventory-driven PE/import audit, all three uploads, and final summary.

The source change adds `TryAcquireSRWLockExclusive` and `FlsGetValue` to the physically narrow YY KERNEL32 provider selection. Exact diagnostics confirm that the three residual rows from predecessor run `33738262420` are gone: neither API survives in the audited `gmp-fake` / `gmp-fakeopenh264` imports. This closes the previous **69 -> 3 -> 0** progression for the workflow's current broad forbidden-import hard-gate set without weakening or excluding the all-PE audit.

Physical runtime evidence now exists for exact runtime artifact `9899304858`:

- on Windows XP SP3 x86, startup fails stably across repeated launches;
- Application log: `Faulting application r3dfox.exe, version 153.0.3.3, faulting module kernel32.dll, version 5.1.2600.5781, fault address 0x00012afb`;
- the user observes no ordinary missing-entry-point/linker dialog;
- on Windows 7 x86, the same build starts successfully and passes the user's basic/primary checks.

For XP `kernel32.dll` in this version family, module offset `0x12afb` maps in public symbolized crash records to `kernel32!RaiseException+0x53`. Therefore the current physical-XP blocker is an early startup exception whose underlying exception code/caller is still unknown; the faulting module line alone does not identify the failing API.

This GREEN CI result still does **not** establish complete Windows XP import/runtime closure. The informational source-remediation quartet diagnostic reports `WARN` and finds two ordinary hard imports in the final `xul.dll` KERNEL32 import table:

- `GetApplicationRestartSettings`;
- `GetNamedPipeServerProcessId`.

Both are Windows Vista+ APIs and are absent on XP. `RegisterApplicationRestart` and `UnregisterApplicationRestart` are absent. The two surviving names are not currently promoted by the final forbidden-import hard gate, so the workflow can be GREEN while these known XP-invalid hard imports remain.

The two surviving source owners have now been remediated on `agent/winrt-source-poc`:

- `widget/windows/nsWindow.cpp::GetQuitType()` excludes `GetApplicationRestartSettings` under `MOZ_XP_COMPAT` and `nsWindow.cpp` is isolated for source-local XP flags;
- `third_party/content_analysis_sdk/browser/src/client_win.cc` excludes the optional `GetNamedPipeServerProcessId` PID/path metadata path under `MOZ_XP_COMPAT` while retaining the pipe connection, and the source is isolated for source-local XP flags.

Current implementation HEAD is `1a86821ccf50ac07204d1bec438e375ece4e84d6`. Full build run `33831005002`, job `100893816677`, source-under-test `1a86821...` is **IN PROGRESS** at documentation time. Its final quartet diagnostic, all-PE audit and artifacts do not yet exist, so **0/4 final-binary closure is not yet proven**.

Current compatibility next steps are separate and ordered:

1. let exact run `33831005002` finish and require final `xul.dll` evidence that all four quartet members are absent before closing that line;
2. independently capture the XP `ExceptionCode` and faulting-thread stack for exact physically failing runtime artifact `9899304858` / run `33757305364` / source `2b1cf7e...`;
3. the physical XP machine is now debugger-ready: `drwtsn32 -i` successfully installed Dr. Watson as the default application debugger, and `Debugging Tools for Windows (x86) v6.12.2.633` is available for classic WinDbg capture if Watson is insufficient;
4. record the physical XP DLL baseline and continue the static runtime-closure queue, starting with the proven `PROPSYS.dll` ordinary `xul.dll` dependency and separately the `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1` dependency;
5. do not call PROPSYS, DXGI, WinRT/UIA delay loads or any exception class the current crash root cause until exact runtime evidence identifies it.

Do not reopen already-proven msvcr14x, bcrypt, D3DCompiler, or narrow-YY families merely because the browser currently throws during XP startup. No GOST TLS runtime or handshake conclusion follows from this compatibility result.

## Current static/runtime closure findings beyond the KERNEL32 quartet

Exact predecessor diagnostics artifact `9899307128` proves that final `xul.dll` has an **ordinary** `PROPSYS.dll` import with at least:

- `PropVariantToString`;
- `VariantCompare`.

Confirmed production paths include `browser/components/shell/nsWindowsShellService.cpp` plus the explicit Windows `propsys` link in `browser/components/shell/moz.build`, and `accessible/windows/uia/UiaTextRange.cpp::CompareVariants` on the normal MSVC path. Clean XP SP3 is not guaranteed to provide Propsys merely because Microsoft exposes an XP-supported redistributable path through Windows Desktop Search 3.0. Treat PROPSYS as necessary clean-XP static closure work, but **not as the confirmed `RaiseException` root cause**.

The same exact diagnostics also prove shipped `libGLESv2.dll` has an ordinary dependency on `dxgi.dll!CreateDXGIFactory1`, a Windows 7+ surface. This is a proven separately linked PE closure defect; its startup criticality remains open because graphics/ANGLE loading may be dynamic/optional.

The raw `xul.dll` diagnostics retain delay-load surfaces including WinRT API-set DLLs, `UIAutomationCore.dll`, `ncrypt.dll`, `AVRT.dll` and `dwmapi.dll`. Missing delay-load DLL/procedure resolution is therefore a valid hypothesis for an exception raised through `RaiseException`, but no particular delay-load code such as `c06d007e`/`c06d007f` may be assigned without a debugger/Watson capture.

The current workflow's curated forbidden DLL/API lists are regression gates, not exhaustive clean-XP dependency proof; aggregate workflow GREEN did not reject PROPSYS or DXGI.

Detailed classification, source paths, debugger sequence and acceptance boundary are in `XP_RUNTIME_COMPATIBILITY_STATUS.md`.

## Residual low-level YY line

Focused proof exists for:

- `InitOnceExecuteOnce`;
- `GetThreadPreferredUILanguages`;
- `QueryFullProcessImageNameA`.

Evidence: source `ffb72c4ae6988a7c4f82b4e67a9027e41afb572b`, workflow `XP x86 core KERNEL32 cluster smoke`, run `33712987285`, job `100516220327`.

Focused proof also exists for the two API names that produced the last three broad hard-gate rows:

- `TryAcquireSRWLockExclusive`;
- `FlsGetValue`.

Focused evidence: source `d6391b43f6af91ed2548372a59fc7a5bfe26a5e9`, workflow `XP x86 core KERNEL32 cluster smoke`, run `33741674218`, job `100604798167`, result GREEN.

Full-Firefox integration evidence now also exists for these two APIs: source `2b1cf7e1b59881b935c7f695a54edd6b92c8066e`, run `33757305364`, job `100654730312`, result GREEN. The predecessor three GMP rows are absent from the exact diagnostics.

The previous physical-XP loader edge `KERNEL32!InitOnceExecuteOnce` is superseded for runtime artifact `9899304858`. The current exact physical-XP boundary is the stable startup exception reported at XP `kernel32.dll+0x12afb`, corresponding to `kernel32!RaiseException+0x53`; the underlying exception code/caller remains open.

## KERNEL32 source-remediation quartet — current source remediated, final import closure pending

The quartet:

- `GetApplicationRestartSettings`;
- `RegisterApplicationRestart`;
- `UnregisterApplicationRestart`;
- `GetNamedPipeServerProcessId`;

is **SOURCE-REMEDIATED ON THE CURRENT IMPLEMENTATION BRANCH / FINAL-BINARY REVALIDATION IN PROGRESS**.

Earlier implementation/configuration chain:

1. `194496e76559e1d86e7e3f920fb3f1fc0e46c2d7` — disable Windows Application Restart under `MOZ_XP_COMPAT` in `nsAppRunner.cpp`;
2. `20f00258ac59296782fbaffbf0131d636c0d3c00` — define `MOZ_XP_COMPAT` for `nsAppRunner.cpp`;
3. `561bded451638e599fae2d57285446261f9a0035` — disable modern UIA client detection under `MOZ_XP_COMPAT`;
4. `ebe325ad87232f68ca01d7e4c63be14f9c4ee74b` — define `MOZ_XP_COMPAT` for `CompatibilityUIA.cpp`.

The predecessor full build later proved two additional/redundant final-link paths. Current follow-up chain after source `2b1cf7...` is:

5. `50ae0e470bef93f341b9e512bd2d6d684c9aa812` — isolate `nsWindow.cpp` for source-local `MOZ_XP_COMPAT` ownership;
6. `5f6c95d0645e8bdfb2add54147bbb3a4da310f81` — exclude `GetApplicationRestartSettings` in `nsWindow.cpp::GetQuitType()` for XP;
7. `ad63965ee8e77bf624a201948e1213de2c16bbae` — isolate `client_win.cc` for source-local `MOZ_XP_COMPAT` ownership;
8. `1a86821ccf50ac07204d1bec438e375ece4e84d6` — keep the content-analysis pipe connection but exclude optional `GetNamedPipeServerProcessId` PID/path metadata for XP.

### Application Restart

Known production owners are now guarded for the XP build:

- `toolkit/xre/nsAppRunner.cpp` — earlier `MOZ_XP_COMPAT` remediation;
- `widget/windows/nsWindow.cpp::GetQuitType()` — current follow-up `MOZ_XP_COMPAT` remediation.

For XP, the Application Restart feature has no useful semantic equivalent and is compiled out at the actual owners while surrounding Windows startup/window facilities remain intact. Final closure still requires exact run `33831005002` to show the three Application Restart names absent from final `xul.dll` ordinary imports.

### Modern UIA/content-analysis named-pipe paths

`accessible/windows/msaa/CompatibilityUIA.cpp` remains source-remediated so Win10/Win11 UIA client-detection implementations are absent and `Compatibility::GetUiaClientPids` is a no-op for the XP translation unit.

The predecessor final build nevertheless retained `GetNamedPipeServerProcessId`; the additional owner was found in `third_party/content_analysis_sdk/browser/src/client_win.cc`. Current source `1a86821...` excludes only the optional agent PID/path metadata call under `MOZ_XP_COMPAT` while preserving the pipe connection. Final closure still requires the exact current full build to show `GetNamedPipeServerProcessId` absent from final `xul.dll` ordinary imports.

Detailed quartet status remains in `XP_KERNEL32_SOURCE_REMEDIATION_STATUS.md`.

## Mandatory `MOZ_XP_COMPAT` build rule

`MOZ_XP_COMPAT` is now the preferred project-owned compile-time signal for new XP-specific source removal where a modern Windows feature has no useful XP semantic equivalent.

For every production translation unit containing an accepted `MOZ_XP_COMPAT` boundary, the XP build MUST define `MOZ_XP_COMPAT` for that exact owner. Prefer source-local configuration:

```python
SOURCES["Owner.cpp"].flags += ["-DMOZ_XP_COMPAT"]
```

If the owner is in `UNIFIED_SOURCES`, move only that source to ordinary `SOURCES` before assigning the source-specific flag.

Do not make `MOZ_XP_COMPAT` a global Firefox define without a separate architectural decision. Existing `MOZ_NO_WINRT` remediations remain valid and do not need renaming merely for consistency.

Authoritative rules: `XP_MOZ_XP_COMPAT_CONTRACT.md`.

## Evidence boundary after first full workflow GREEN

Run `33757305364` proves that the full Firefox x32 build/package/runtime-archive pipeline and all current hard gates complete successfully with the established dependency/package contract, and that the previous three GMP hard-gate findings are absent. Physical XP now disproves startup compatibility for exact runtime artifact `9899304858`: the browser fails stably at an exception raised through XP `kernel32!RaiseException+0x53`. The same build's Windows 7 x86 success confirms that this is an XP-specific runtime boundary, not a general inability of the binary to start.

The current CI audit does not prove absence of every post-XP dependency. The predecessor quartet diagnostic exposed two surviving ordinary `xul.dll` KERNEL32 imports outside the hard-gate set, and the broader raw diagnostics additionally expose PROPSYS, DXGI and delay-load surfaces that require clean-XP classification.

Run `33831005002`, job `100893816677`, source `1a86821...` is a provisional source-remediation revalidation only until it finishes. Do not document pending quartet/final-audit gates as passed and do not assign artifact IDs before uploads exist.

Future full builds must retain the inventory-driven PE/import audit. Source removal, a GREEN curated core gate, or aggregate workflow GREEN does not by itself prove physical Windows XP startup.

Final XP acceptance remains:

1. exact source-under-test SHA;
2. successful full XP x32 build/package under the established build contract;
3. inventory-driven audit of the complete required PE closure, distinguishing hard imports from delay-loads and shipped/runtime-required PEs from test-only/non-shipped PEs;
4. exact artifact identity/hashes;
5. physical Windows XP execution through successful browser startup and representative runtime use.

A curated known-API list remains a regression gate, not exhaustive compatibility proof.

## XP dependency/build contract

- pinned/restored msvcr14x Release x86 remains mandatory; do not substitute host Win7+ redistributables;
- x86 PE subsystem must be 5.01 or lower for XP runtime PEs;
- `editbin` header retargeting alone is never compatibility proof;
- project-controlled modern dependencies should first be removed/remediated at source/build/subsystem boundary;
- separately linked PEs own separate import tables;
- successful focused/full build is not physical-XP runtime proof.

`XP_BUILD_CONTRACT.md` remains authoritative.

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