# r3dfox GOST TLS — Project State

Last updated: 2026-09-03

This file is the authoritative **current technical synthesis**. Detailed experiment evidence belongs in `TEST_LOG.md` and immutable dated `TEST_LOG_*.md` volumes; forward work is in `TODO.md`; formally closed milestones are in `DONE.md`; workflow roles and evidence levels are in `WORKFLOWS.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default GOST development branch: `agent/gost-tls-poc`.
- Windows XP SP3 x86 compatibility work branch: `agent/winrt-source-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the working branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer r3dfox baseline.

## Separation of conclusions

The project has independent evidence tracks. Never promote evidence from one track into another without a deliberately combined experiment.

- GOST TLS runtime / handshake: NSS/NSPR/MSSPI/SSPI/CryptoPro, proxy lifecycle, server verification, client authentication and protected application traffic.
- Windows compatibility: Rust, msvcr14x, YY-Thunks, VC-LTL/thunk closure, linker/CRT behavior, PE imports and physical old-Windows runtime.
- Bundled government-system extensions: updater/fallback, build staging, package contents and Firefox extension runtime.

A successful build is not a successful GOST handshake. A hosted compatibility probe is not physical-XP proof. A later docs commit is never the source-under-test SHA for an earlier binary.

## GOST TLS architecture and current runtime checkpoint

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication.

Current runtime constraints and behavior:

- allowlist: `R3DFOX_GOST_HOSTS`;
- TLS 1.2 / HTTP/1.1 PoC path;
- default GOST ciphers: `C100:C101:C102:FF85:0081`;
- coordinated Firefox client-auth picker is default;
- `R3DFOX_GOST_CLIENT_AUTH_MODE=legacy` remains diagnostic only;
- `Session` is the picker default and is process-local;
- explicit `Once` uses the positive-only short fanout lease;
- explicit Cancel is attempt-local negative state and is not remembered;
- involuntary tab/load abandonment remains unresolved phase `0` and is lifecycle-cleaned;
- candidate discovery from `CurrentUser\MY` is distinct from live private-key availability;
- pre-acquisition provider failure is attempt-local and a positive Session choice survives recovery;
- post-login medium removal is not a deterministic invalidation of an already-acquired CryptoPro/SSPI credential;
- long synchronous provider/key access can starve the shared Firefox Socket Thread while the browser UI remains responsive;
- true persistent `Permanent` semantics remain open;
- final fail-closed server verification remains open.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

Current authoritative Session-default browser:

- source `afbdad307f63e594d3715169d6e34235280dddaf`;
- main run `33073577269`, job `98521835354`, artifact `9652941006`;
- `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`;
- `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`.

Closed GOST runtime groups include basic Treasury GOST HTTPS, Stage 1 explicit-selector Treasury mTLS, coordinated client-auth F1/F2/F3, GIS-G4 isolation, Session lifetime, SD1-SD6 Session-default regression, T3 Cancel, T4 Abort, T7/T8 provider recovery, T9 provider-wait characterization and T10 picker presentation. Exact evidence remains in `DONE.md` and the test logs. Current forward work is authoritative in `TODO.md`.

## Windows XP SP3 x86 compatibility — current authoritative synthesis

### Evidence rule: proven baseline is immutable

The canonical XP x86 SRW/Rust/CRT/YY baseline is already proven and must not be reconstructed or independently re-proved for each new API.

- source SHA `d65b464c74caadace97995f07a4919363c41a0ea`;
- workflow `msvcr14x Rust YY XP x86 SRW smoke`;
- run `33470957048`;
- job `99740439208`;
- runtime artifact `9786702687`, digest `sha256:6b931856c9e4e31b067b5684d3c49fd9028c2c9aaf7f2566be79c910ad353571`;
- diagnostics artifact `9786703244`, digest `sha256:57c67a45a30b94a854f00e358c528c1ffe4129dc7dc615de19c1ed725e89c530`.

It proves the tested coexistence of pinned msvcr14x Release x86, Rust `i686-pc-windows-msvc`, YY-Thunks 1.2.2 XP x86, the physically narrow provider, CRT/link closure, x86/XP PE gates, checked synchronization import closure and hosted runtime.

**Rule:** every new XP compatibility experiment extends this exact proven closure and tests only its new delta. A later experiment that fails at a weaker evidence level does not revoke an earlier equivalent-or-stronger GREEN unless an actual regression is demonstrated.

### Firefox synchronization closure and physical XP progression

The earlier full Firefox line is tied to:

- source SHA `d2f15ee8f0cef8112855c4306014865e422319d3`;
- run `33479649627`;
- job `99766203250`;
- physical-XP package artifact `9793231118`;
- Firefox PE/import evidence artifact `9793232359`.

This evidence closes the earlier synchronization blocker. On physical Windows XP SP3 x86 the loader progressed beyond that cluster and stopped at the concrete dependency:

`mozglue.dll -> KERNEL32!CreateWaitableTimerExA`

Therefore `CloseThreadpoolWork` and the synchronization family are historical blockers, not the current XP edge.

The same import inventory showed `mozglue.dll` directly importing `CreateWaitableTimerExA`, `GetThreadId`, `GetTickCount64`, `InitOnceExecuteOnce` and `InitializeCriticalSectionEx`. The larger `xul.dll` inventory contains additional legacy-Windows APIs; xul-only imports must not be automatically attributed to `mozglue.dll` or promoted to the current blocker.

### YY-Thunks capability boundary

Capability inventory from YY-Thunks 1.2.2 XP x86 is tied to source `0bd7774b89fb6ea8b734ba17c6e50bbb306714e9`, run `33495830486`, job `99817683629`.

`CreateWaitableTimerExA` has **no matching XP x86 YY capability**: no direct `.obj`, no `.obi`, no expected decorated x86 symbol and no `YY_Thunks_CreateWaitableTimerExA` capability.

Twenty-four other tested KERNEL32 APIs are capability-present:

`GetTickCount64`, `InitializeCriticalSectionEx`, `CompareStringOrdinal`, `GetCurrentProcessorNumber`, `GetFileInformationByHandleEx`, `GetFinalPathNameByHandleW`, `GetLocaleInfoEx`, `LCIDToLocaleName`, `LocaleNameToLCID`, `SetFileInformationByHandle`, `CancelIoEx`, `CreateWaitableTimerExW`, `CancelSynchronousIo`, `GetDynamicTimeZoneInformation`, `GetProcessIdOfThread`, `GetQueuedCompletionStatusEx`, `GetThreadId`, `GetTimeZoneInformationForYear`, `GetUserPreferredUILanguages`, `InitOnceBeginInitialize`, `InitOnceComplete`, `QueryFullProcessImageNameW`, `QueryProcessCycleTime`, `QueryThreadCycleTime`.

### 24-API KERNEL32 cluster — CLOSED GREEN

The representative/hosted closure is tied to:

- source SHA `0184985c2f0c5ab1c4c732a200cfbda07a6aefb4`;
- workflow `XP x86 core KERNEL32 cluster smoke`;
- run `33600786738`;
- job `100153789478`;
- runtime artifact `9835297933`, digest `sha256:5c6e9d81e8277dc8225c5e7e7f8fc7dbde66b56184df19e0774a264e1890020d`;
- diagnostics artifact `9835298737`, digest `sha256:92cc62ac5d452257a26fef13fa5b705277ece44c9df01cebd9ba4013403f179b`.

The run passes:

1. YY capability/inventory;
2. native x86 link with the proven msvcr14x/YY closure;
3. x86 PE / XP subsystem and direct-import gates;
4. hosted Windows 2022 functional runtime for all 24 capability-present APIs.

`CreateWaitableTimerExA` is intentionally `SKIP (YY capability missing)` and is not allowed to remain as a direct import merely to make the probe pass.

This GREEN is representative/hosted evidence. It is not aggregate physical-XP execution of the 24-API probe and it is not full Firefox integration proof.

### Later auxiliary RED — retained, but does not reopen the cluster

A later workflow attempted another baseline+delta formulation:

- source SHA `523601862d227da08819a0e4a74276cf3288fb56`;
- workflow `XP x86 KERNEL32 delta on proven SRW baseline`;
- run `33604407934`;
- job `100165018692`;
- diagnostics artifact `9836714005`, digest `sha256:163d410b8cf06d6641086c5fc21dcc2a093b1467b86c7f454fee3f8b3aab1df1`.

Provider construction, baseline helper, delta helper and representative Rust archive passed; native link failed and the later PE/import/runtime/package gates were skipped. Because this run reached a weaker evidence level than `33600786738`, it is auxiliary failure provenance, **not a regression of the closed 24-API GREEN and not the current blocker**.

The earlier `_ProcessPrng@8` diagnostic RED, run `33599812797` / job `100150793264` / source `80e42dd85a2c1902de5fdce402d4983becc2f77c`, is likewise closed as a test-provider internal dependency omission; run `33600786738` restores that closure and passes.

### Full Firefox checkpoint — `CreateWaitableTimerExA` removed at build/import level; CRT packaging is the immediate blocker

Current exact full-build evidence:

- branch `agent/winrt-source-poc`;
- source-under-test `17cdb459ec4f115a209fd50ac225cf867b9f3a2f`;
- workflow `GOST TLS PoC build  XP x32`;
- run `33638897692`;
- job `100276666021`;
- aggregate result **failure**;
- package artifact `9855749298`, digest `sha256:b8cd19fda1244a2f2f55ff08bbc35ca180e8d0cbf487ec67cb64d54586b9c6ad`;
- diagnostics artifact `9855751471`, digest `sha256:bce0bbdbc778b0114b9d33e670a9bf687e4699cfda7353efebc6b92650f03eed`.

The expensive Firefox boundary is now materially GREEN:

- pinned msvcr14x XP x86 contract gate passes;
- full Firefox 153 x86 configure/build/link passes;
- the four-core-PE gate reports zero surviving direct imports from the already-proven 34-name SRW + 24-API KERNEL32 set;
- `mach package` passes;
- legacy XP `D3DCompiler_47.dll` still survives packaging unchanged.

The `CreateWaitableTimerExA` source-cut implementation is also validated at the **full build/import** level. The workflow's 34-name gate does not itself list `CreateWaitableTimerExA`, so the conclusion is bound to independent inspection of diagnostics artifact `9855751471`: the exact `mozglue.dll`, `xul.dll`, `r3dfox.exe`, and `plugin-container.exe` import inventories contain no direct `CreateWaitableTimerExA`. Thus the historical production dependency

`mozglue.dll -> KERNEL32!CreateWaitableTimerExA`

is removed from the exact source `17cdb459...` build.

This does **not** yet close `CreateWaitableTimerExA` as a physical-XP runtime milestone. The package accepted for the next XP test must first satisfy the app-local CRT packaging contract.

The current immediate RED is `GATE - Verify msvcr14x CRT survived portable packaging`. Before `mach package`, exact staged identities are:

- `ucrtbase.dll` SHA-256 `1d4d54cf0d59d2911367d533a6e252316c7c6f53c862de574af1701c20eed6e5`;
- `msvcp140.dll` SHA-256 `61815cf338d36d7ccec21997e693d37ea7a2042b66b49926b64789961e0796b6`.

The post-package diagnostics contain those pre-package hashes but no successful `archive=...` record. The gate checks every produced `.7z`/`.zip` and requires exactly one matching copy of each DLL; no produced archive satisfies that contract. Independent inspection of `r3dfox-v153.0.3.win32.zip` confirms that both custom CRT DLLs are absent while `d3dcompiler_47.dll` is present.

The packaging mechanism is now identified: the XP workflow stages the pinned msvcr14x DLLs into `dist/bin`, but the package manifest did not require those exact files for this configuration. Source `3e9e3596dc82ee6108d1910ae9912ccf2a8e3e38` changes only `browser/installer/package-manifest.in`, adding `@BINPATH@/ucrtbase.dll` and `@BINPATH@/msvcp140.dll` directly under the existing `#ifdef XP_WIN` block. This deliberately moves the current experiment from implicit Mozilla CRT predicates to an explicit `dist/bin -> package staging` contract for the two pinned app-local XP runtimes. The post-package hash/uniqueness gate is unchanged and remains fail-closed.

Validation of this manifest change is currently in progress in workflow `GOST TLS PoC build  XP x32`, run `33708144139`, job `100501664342`, source-under-test `3e9e3596dc82ee6108d1910ae9912ccf2a8e3e38`, attempt 1. Do not treat the patch as package-closure GREEN until that exact run reaches `GATE - Verify msvcr14x CRT survived portable packaging` and the resulting package/diagnostics artifacts confirm one matching copy of each DLL.

The same post-package CRT red existed in run `33610933602`; its earlier `TEST_LOG.md` interpretation has been corrected because `packaged-crt-contract.txt` from diagnostics artifact `9843568460` also contains only pre-package hashes and no successful archive record.

Because the current CRT survival gate fails, the dedicated runtime archive and broad final XP PE/import audit are skipped. Therefore source `17cdb459...` is **not yet the accepted physical-XP browser artifact** and no new broad surviving-import inventory may be inferred from this run.

Immediate acceptance path:

1. validate in exact run `33708144139` that the explicitly listed `ucrtbase.dll` + `msvcp140.dll` survive Mozilla packaging with unchanged recorded hashes;
2. require the runtime-archive and broad PE/import gates to execute and pass far enough to produce the next accepted runtime candidate;
3. launch that exact accepted package/runtime artifact on physical Windows XP SP3 x86;
4. only after physical XP advances beyond the old timer loader edge may `CreateWaitableTimerExA` be closed in `DONE.md`; any next loader/runtime failure becomes the new blocker.

No GOST TLS runtime conclusion follows from this compatibility work.

## Windows 7 x86 compatibility — separate evidence

Two independently observed Win7 issues remain separate from the XP package-closure target:

- content-sandbox RNG/`RandomUint64OrDie` line, including the candidate pre-lockdown RNG warm-up; exact runtime proof with sandbox enabled remains required before calling that fix closed;
- later parent/browser WinRT delay-load line where `xul.dll` attempts missing `api-ms-win-core-winrt-l1-1-0.dll` / `RoGetActivationFactory`; narrow YY WinRT exposure remains the intended compatibility direction.

Neither line is evidence about the current physical-XP loader progression and neither should displace the CRT package-survival boundary as the immediate XP target.

## Bundled government-system extensions — independent track

Current proven three-extension package checkpoint:

- source `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- full packaging run `32976571122`, job `98202641607`;
- packaged-browser artifact `9614275050`;
- evidence artifact `9614275551`.

The portable archive contains CryptoPro CAdES `1.2.14`, legacy Gosuslugi/IFCPlugin `1.2.8`, Gosplugin `1.3.43.0`, and the Russian-first content-language preference. Clean-profile discovery/enabled-state is proven for all three project extensions. Native-component behavior and version-to-version update behavior remain separate open work.