# r3dfox GOST TLS — Project State

Last updated: 2026-09-02

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

The later full Firefox line is tied to:

- source SHA `d2f15ee8f0cef8112855c4306014865e422319d3`;
- run `33479649627`;
- job `99766203250`;
- physical-XP package artifact `9793231118`;
- Firefox PE/import evidence artifact `9793232359`.

This evidence closes the earlier synchronization blocker. On physical Windows XP SP3 x86 the loader progresses beyond that cluster and stops at the concrete dependency:

`mozglue.dll -> KERNEL32!CreateWaitableTimerExA`

Therefore `CloseThreadpoolWork` and the synchronization family are historical blockers, not the current XP edge.

The same import inventory shows `mozglue.dll` directly imports `CreateWaitableTimerExA`, `GetThreadId`, `GetTickCount64`, `InitOnceExecuteOnce` and `InitializeCriticalSectionEx`. The larger `xul.dll` inventory contains additional legacy-Windows APIs; xul-only imports must not be automatically attributed to `mozglue.dll` or promoted to the current blocker.

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

### Full Firefox XP x32 build and portable packaging — BUILD/PACKAGE GREEN

The integrated full-Firefox milestone is tied to:

- source-under-test SHA `6998ba51b1052b08d8b0b2a221d63b896eccd219`;
- workflow `XP x32` (`.github/workflows/xp-x32.yml`);
- run `33610933602`;
- job `100185641911`;
- package artifact `5701777195` (`r3dfox-gost-xp-x32-package`), digest `sha256:999a6276856771eb4629020d366fbcf4e696b2928de8bfb6e2b024b12b0406d8`;
- diagnostics artifact `5701777490` (`r3dfox-gost-xp-x32-diagnostics`), digest `sha256:741a517b7065a60b581567cb45bc83b4d1ca79b1277a3871e757554991236977`.

The exact run proves:

- `Build release r3dfox XP x32` — PASS;
- build-time compile/import gates — PASS;
- XP runtime staging — PASS;
- XP PE subsystem retargeting — PASS;
- packaged D3DCompiler gate — PASS;
- `Package XP x32 experiment` — PASS;
- package and diagnostics artifacts — uploaded successfully.

The aggregate job remains RED only because the later `GATE - Verify msvcr14x CRT survived portable packaging` failed. That gate found no `msvcr14*.dll` next to packaged `r3dfox.exe`.

This result must therefore be classified as **successful full Firefox XP x32 build and portable package with a failed post-package CRT validation**, not as a failed Firefox build.

### Current XP blocker and acceptance path — packaged CRT, then physical XP runtime

The immediate CI/package blocker is now to preserve the required msvcr14x CRT in the runnable portable package so that `msvcr14*.dll` is present next to packaged `r3dfox.exe` and the post-package CRT gate passes.

After that gate is GREEN, run the exact package on physical Windows XP SP3 x86 and continue loader/runtime validation. The previously observed `mozglue.dll -> KERNEL32!CreateWaitableTimerExA` dependency remains a runtime semantic risk until this new package is actually executed on XP; the successful hosted build/package does not by itself prove that dependency is solved at physical-XP runtime.

Acceptance path:

1. fix/stage/preserve the required msvcr14x CRT into the portable package;
2. rerun `xp-x32` and require build + package + CRT post-package gate all GREEN;
3. bind the produced package and diagnostics to exact source SHA + run + job + artifact digests;
4. execute that exact package on physical Windows XP SP3 x86;
5. record the first concrete loader/runtime result, including whether `CreateWaitableTimerExA` is still observable;
6. only then choose any additional narrow runtime remediation based on evidence.

Do not return to re-proving the already closed SRW/Rust/CRT/YY baseline or the 24 capability-present KERNEL32 cluster merely because the aggregate run `33610933602` is red. Its red status is post-package CRT validation, not a regression of the compiled Firefox integration.

No GOST TLS conclusion follows from this XP compatibility build/package milestone.

## Windows 7 x86 compatibility — separate evidence

Two independently observed Win7 issues remain separate from the XP package/runtime target:

- content-sandbox RNG/`RandomUint64OrDie` line, including the candidate pre-lockdown RNG warm-up; exact runtime proof with sandbox enabled remains required before calling that fix closed;
- later parent/browser WinRT delay-load line where `xul.dll` attempts missing `api-ms-win-core-winrt-l1-1-0.dll` / `RoGetActivationFactory`; narrow YY WinRT exposure remains the intended compatibility direction.

Neither line is evidence about the current XP package/runtime edge and neither should displace the packaged-CRT gate as the immediate XP target.

## Bundled government-system extensions — independent track

Current proven three-extension package checkpoint:

- source `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- full packaging run `32976571122`, job `98202641607`;
- packaged-browser artifact `9614275050`;
- evidence artifact `9614275551`.

The portable archive contains CryptoPro CAdES `1.2.14`, legacy Gosuslugi/IFCPlugin `1.2.8`, Gosplugin `1.3.43.0`, and the Russian-first content-language preference. Clean-profile discovery/enabled-state is proven for all three project extensions. Native-component behavior and version-to-version update behavior remain separate open work.
