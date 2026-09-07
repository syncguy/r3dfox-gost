# r3dfox GOST TLS — Project State

Last updated: 2026-09-07

This file is the authoritative current technical synthesis and handoff for new chats. Detailed experiment evidence belongs in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes; closed milestones are in `DONE.md`; pending work is in `TODO.md`; workflow roles are in `WORKFLOWS.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default GOST development branch and canonical documentation source: `agent/gost-tls-poc`.
- Windows XP SP3 x86 compatibility implementation branch: `agent/winrt-source-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the active work branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer base.

For Windows XP work, read `XP_BUILD_CONTRACT.md` and `XP_MOZ_XP_COMPAT_CONTRACT.md`. For the current Shell32 cluster read `XP_SHELL32_COMPATIBILITY.md`. For workflow maintenance read `XP_WORKFLOW_REFACTOR.md`. For the newest refactor/PDB/YY evidence read `TEST_LOG_2026-09-07_refactor-pdb-yy.md`. For physical-XP startup/runtime work also read `XP_RUNTIME_COMPATIBILITY_STATUS.md` and the newest XP entries in `TEST_LOG.md`.

## Separation of conclusions

Keep these tracks independent unless a deliberately combined experiment tests both:

1. GOST TLS runtime / NSS / NSPR / MSSPI / SSPI / CryptoPro / handshake.
2. Windows Vista/7/XP compatibility / Rust / msvcr14x / YY-Thunks / linker / PE imports / physical runtime.
3. Bundled government-system extensions and localization/package behavior.

A successful build is not a successful GOST handshake. A hosted compatibility probe is not physical-XP proof. Win7 x86 runtime success is not XP runtime success. Documentation HEADs never replace the exact source-under-test SHA for an earlier artifact.

# GOST TLS runtime

No GOST-runtime conclusion changes as a result of the XP work described below.

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

Current GOST runtime constraints/open work remain:

- TLS 1.2 / HTTP/1.1 PoC path;
- coordinated Firefox client-auth picker as default;
- `Session` is the current default positive certificate choice and remains process-local;
- true persistent `Permanent` semantics remain open;
- final fail-closed server verification remains open;
- synchronous provider/key access can still block the shared Firefox Socket Thread during long CryptoPro waits.

Current authoritative Session-default browser source is `afbdad307f63e594d3715169d6e34235280dddaf`, full build run `33073577269`, job `98521835354`, release artifact `9652941006`.

# Windows XP SP3 x86 compatibility

This track is independent of GOST TLS runtime. Active implementation work is on `agent/winrt-source-poc`; canonical documentation remains on `agent/gost-tls-poc`.

## Latest completed build/static baseline — GREEN

The newest completed refactored full XP x32 build/static baseline remains:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `a15dcd738edda4ab810fc9f92289170f115519e4` (`ci(xp): preserve matching xul PDB diagnostics`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34095425319`, attempt `1`;
- job `101657910987`;
- aggregate conclusion: **success**;
- package artifact `10013484854`, digest `sha256:d8764c7dbf0a2d2b47858554628aa009641589241e582eec9cb7d40199a89873`;
- runtime artifact `10013486539`, digest `sha256:daaed105abe6c9ce3a9afa9db4a17254c8520f2a6823dbc53e0e7bc6a4a8360b`;
- diagnostics artifact `10013519035`, digest `sha256:6fef7bf7e0122de7c5747e0923585123ea5753666fc6bd38ff1ac6be4cf20df9`.

All main steps and final gates completed successfully, including full Firefox build, packaging, runtime archive, PE/import gates, `DIAG - Record xul IPHLPAPI XP compatibility imports`, `DIAG - Inventory YY-Thunks DLL entry-point coverage`, all artifact uploads and the final summary.

This build **does not contain the later Shell32 source-remediation cluster**. It remains the authoritative refactor/PDB/YY-inventory baseline. The current Shell32 implementation has now also completed its own exact GREEN validation, recorded below under source `cd5e715...` / run `34107793132`.

The older source `0a18ba85b3f493b17c5a62742e869788ca3f2f6b`, run `34079480996`, job `101611911453`, remains the exact browser for the latest supplied physical-XP Shell32/Wasm observations. Do not transfer those physical observations to later GREEN builds merely because they compile and package successfully.

## XP full-build workflow refactor — first checkpoint GREEN

Between `0a18ba85...` and `a15dcd...`, only the XP workflow/refactor surface changed:

- `.github/scripts/xp/prepare-pinned-xp-bcrypt.ps1`;
- `.github/scripts/xp/verify-msvcr14x-xp-contract.ps1`;
- `.github/scripts/xp/diag-xul-iphlpapi.ps1`;
- `.github/scripts/xp/build-narrow-yy.ps1`;
- `.github/workflows/gost-poc-build-xp-x32.yml`.

No Firefox production source changed in that range.

The four-script structural checkpoint is `e9c8c766e20b0160094257d674ded1ea57aa82ee`. Source `a15dcd...` is exactly one commit later; that additional commit only enables debug symbols and includes matching `xul.pdb` in the diagnostics upload. Therefore run `34095425319` validates the first workflow-refactor checkpoint together with the PDB extension.

Detailed maintenance rules and the next allowed structure-only extraction batch are in `XP_WORKFLOW_REFACTOR.md`.

## Matching `xul.pdb` is now proven in diagnostics

Commit `a15dcd738edda4ab810fc9f92289170f115519e4` changed the XP mozconfig from `--disable-debug-symbols` to `--enable-debug-symbols` and added:

```text
obj-gost-xp-x32/**/xul.pdb
```

to the diagnostics artifact.

Exact `xul.pdb` from diagnostics artifact `10013519035`:

```text
r3dfox-gost/r3dfox-gost/obj-gost-xp-x32/toolkit/library/build/xul.pdb
```

- size: `1,864,486,912` bytes;
- SHA-256: `fb35a5e682fb5b0fab3039a2dc504339002d9e8932a0dae71933da44a35ada02`.

The corresponding `xul.dll` from the same build is recorded by the YY diagnostics with SHA-256 `c5dd98c21fe59640e56498c695808819fa5d5bbe26be324cb926cc7c2235aa8e`.

**Symbolization rule:** this PDB is valid only for the exact `xul.dll` from run `34095425319` / source `a15dcd...`. It must not be used for `0a18ba85...` or for the current `cd5e715...` Shell32 build. A physical failure from a later build must use that build's own matching PDB.

## YY DLL entry-point/TLS inventory — follow-up evidence

The exact GREEN `a15dcd...` build produced a successful non-blocking YY inventory with a valid positive control:

```text
xul_positive_control=true
strong_candidates=13
contracts_present=3
missing_contract_candidates=10
```

Strong candidates with the expected YY DLL/TLS contract:

- `xul.dll`;
- `ucrtbase.dll`;
- `msvcp140.dll`.

Heuristic strong candidates without that contract:

- `gkcodecs.dll`;
- `gmp-clearkey/0.1/clearkey.dll`;
- `gmp-fake/1.0/fake.dll`;
- `gmp-fakeopenh264/1.0/fakeopenh264.dll`;
- `libGLESv2.dll`;
- `mozavcodec.dll`;
- `mozavutil.dll`;
- `mozglue.dll`;
- `mozinference.dll`;
- `nss3.dll`.

This is **not proof of ten runtime blockers**. The inventory is deliberately heuristic/non-blocking. Any extension of the YY DLL/TLS contract must be tied to an exact runtime failure or stronger focused evidence first.

Detailed evidence is in `TEST_LOG_2026-09-07_refactor-pdb-yy.md`.

## Residual IPHLPAPI delayed edges in the newest completed baseline

The `a15dcd...` final-xul diagnostic reported these post-XP residual delay imports:

- `GetIpInterfaceTable`;
- `FreeMibTable`;
- `if_indextoname`.

`NotifyIpInterfaceChange` and `CancelMibChangeNotify2` were absent. `GetAdaptersAddresses` and `GetBestInterfaceEx` remained as expected XP-safe delayed imports.

The diagnostic classified the three survivors as `UNEXPECTED`, but it is non-blocking and only records import presence. Do **not** reopen the physically cleared IP Helper blocker solely from this static result. Localize source owners/runtime reachability before changing this line again.

## Current implementation HEAD and completed Shell32 validation build — GREEN

Current XP implementation HEAD is:

- branch `agent/winrt-source-poc`;
- HEAD `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4` (`fix(xp): use legacy ProgramData shell folder`).

This HEAD descends from the GREEN refactor/PDB source `a15dcd...` and adds the current Shell32 source-remediation lineage.

Exact completed validation build:

- workflow `XP Build`;
- run `34107793132`, attempt `1`;
- job `101696721232` (`build-windows-xp`);
- source-under-test `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4`;
- event `workflow_dispatch`;
- aggregate conclusion: **success**.

The build, build-driver log extraction, packaging, ZIP verification, Rust CRT import gate, direct XP-ready import diagnostics, hard direct XP-ready import gate and all three evidence uploads completed successfully. Exact artifacts:

- `r3dfox-xp-153.0.en-US.win64.zip`: artifact `5875778788`, digest `sha256:d5c51e686d6a59ac0146726234a6d02aec0c20b8e49bf0a8aa66b4864f8c405e`;
- `r3dfox-xp-build-logs`: artifact `5875778720`, digest `sha256:85500ade7ffc242edd3e03e2379ec30880874341b66697b6ab18ed883766d9d4`;
- `r3dfox-xp-compat-diagnostics`: artifact `5875778793`, digest `sha256:120238721588471833187ca565fff4171587cf3606f4b1c2091b4e7eebcb219b`.

This is the authoritative build/static validation for the current Shell32 source cluster. It proves that source `cd5e715...` compiles, packages and passes the current hard static import gates. It does **not** prove physical Windows XP startup/runtime acceptance and does **not** prove a GOST TLS handshake. Inspect the successful compatibility diagnostics before claiming that any specific residual Shell32 delay-import edge has disappeared.

## Physical XP runtime — inherited AutoConfig can force GFX critical failures to crash

The shipped/inherited `config.cfg` contains:

```js
// Added via patches/autoconfig-setEnv.patch
setEnv("MOZ_GFX_CRASH_MOZ_CRASH", 1);
```

On physical XP this can convert the expected no-D3D11 graphics failure into `MOZ_CRASH(GFX_CRASH)`. Removing the whole `config.cfg` was used only as a diagnostic isolation experiment and is not an accepted packaging fix.

## Most recently exposed config-free parent-process blocker — `SHELL32!SHGetKnownFolderPath`

The exact physical browser for this evidence remains source `0a18ba85b3f493b17c5a62742e869788ca3f2f6b`, run `34079480996`, job `101611911453`, runtime artifact `10005434852`.

The supplied config-free Dr. Watson capture decoded to:

```text
exception      C06D007F
DLL            SHELL32.dll
procedure      SHGetKnownFolderPath
pfnCur         0
last error     0x0000007f / ERROR_PROC_NOT_FOUND
```

Physical capture identity:

- `drwtsn32.log` SHA-256 `f54366c0787cc53962f3300cbd84ddab0fdf507cf9d3a613901f2f6879144a36`;
- `user.dmp` SHA-256 `0e3cb1e3e4822729145bcc4f6d6e799ead772321fc018cb1c9fb648c97efbb38`;
- PID `6184`;
- physical-XP local time `2026-09-07 15:12:04.957`.

The physically reached owner is `toolkit/xre/nsXREDirProvider.cpp`. Its previous runtime fallback could not catch the missing export because the MSVC delay-loader raised before `SHGetKnownFolderPath` could return a failing `HRESULT`.

## Current Shell32 `MOZ_XP_COMPAT` source cluster

Current implementation source `cd5e715...` contains three source-owned remediations:

1. `toolkit/xre/nsXREDirProvider.cpp`
   - XP: `SHGetFolderPathW` with `CSIDL_LOCAL_APPDATA` / `CSIDL_APPDATA`, then existing registry fallback;
   - non-XP: original `SHGetKnownFolderPath` / `FOLDERID_*`.
2. `xpcom/io/SpecialSystemDirectory.cpp`
   - XP `Win_Downloads`: direct `CSIDL_DESKTOP` fallback;
   - `GetKnownFolder(...)` direct call excluded from XP TU.
3. `toolkit/mozapps/update/common/commonupdatedir.cpp`
   - XP ProgramData: `SHGetFolderPathW(CSIDL_COMMON_APPDATA | CSIDL_FLAG_CREATE, ...)`;
   - non-XP retains `SHGetKnownFolderPath(FOLDERID_ProgramData, ...)`.

All dedicated owners are ordinary `SOURCES` entries with source-local `-DMOZ_XP_COMPAT`. The two newly added owners were removed from unified compilation before applying source-specific flags.

Only the first owner is backed by direct physical `C06D007F` evidence. The other two were found proactively in the same API family and remain build/runtime validation targets.

Detailed Shell32 state is in `XP_SHELL32_COMPATIBILITY.md`.

### Remaining Shell32 candidates

These are intentionally not yet source-fixed and are not physically proven blockers:

- `SHCreateItemFromParsingName` — owner `toolkit/components/downloads/DownloadPlatform.cpp`; likely XP direction is direct existing `SHAddToRecentDocs(SHARD_PATHW, ...)` under `MOZ_XP_COMPAT`;
- `SHOpenWithDialog` — present in prior Shell32 delay-import inventory; localize exact owner/runtime path before changing it;
- `GetCurrentProcessExplicitAppUserModelID` — Windows 7-era API; at least one owner already uses dynamic `GetProcAddress`, so audit final ownership before remediation.

## Unresolved parallel symptom — SpiderMonkey/Wasm `MOZ_RELEASE_ASSERT(map)`

The earlier physical `0a18ba85...` browser produced repeated `0x80000003` events at `xul.dll` RVA `0x00284926`, resolving to:

```text
MOZ_RELEASE_ASSERT(map)
```

Owner: `js/src/wasm/WasmProcess.cpp`, process-wide `sThreadSafeCodeBlockMap`; possible assertion sites include `wasm::RegisterCodeBlock`, `wasm::UnregisterCodeBlock`, and `wasm::ShutDown`.

This symptom remains unresolved and separate from the Shell32 line. Do not suppress the assertion as a fix.

The newly proven `a15dcd...` PDB enables exact symbolization only if a failure is reproduced with the exact `a15dcd...` xul. The current `cd5e715...` validation build inherits PDB generation; if it fails physically, use the matching PDB from that exact run instead.

## Physical XP progression — earlier blockers CLOSED

- `b386b7f4ba8fd20619a2b7ee541a6b8fe609e278`, run `34038288272`, job `101500284497`, runtime artifact `9992440155`: physical XP advanced beyond the old `ntdll!RtlpWaitForCriticalSection` startup crash after xul YY DLL/TLS entry-point integration.
- `0a18ba85b3f493b17c5a62742e869788ca3f2f6b`, run `34079480996`, job `101611911453`: physical XP advanced beyond the preceding IP Helper runtime boundary.

Do not reopen these closed boundaries without contradictory evidence on a later exact artifact.

## Compatibility work in the current implementation lineage

The lineage includes:

- SRW / condition-variable and narrow residual KERNEL32 compatibility;
- `CreateWaitableTimerExA` source fallback;
- selected XP-compatible `bcrypt.dll` packaging;
- legacy `D3DCompiler_47.dll` staging;
- `NtCancelIoFileEx` narrow YY-Thunks remediation;
- ADVAPI32 ETW/RegGetValueW compatibility;
- KERNEL32 restart/named-pipe source-remediation quartet;
- PROPSYS ordinary-import removal;
- DPI startup fix for `USER32.dll!SetProcessDPIAware`;
- WS2_32 narrow compatibility work;
- ANGLE/DXGI removal of the XP-incompatible static `CreateDXGIFactory1` edge while preserving D3D9 fallback;
- xul YY DLL/TLS entry-point integration;
- XP-era IP Helper source remediation;
- first GREEN structural refactor of the XP full-build workflow;
- matching xul PDB generation/upload and all-DLL YY contract inventory;
- current three-owner Shell32 `MOZ_XP_COMPAT` cluster.

Full YY `kernel32.lib` interposition remains prohibited. Keep compatibility ownership physically narrow by PE/provider/source owner.

## Next experiment order

1. Inspect run `34107793132` / job `101696721232` compatibility diagnostics for the exact final Shell32 delayed-import set and record whether the targeted ProgramData remediation changed the expected import surface.
2. Verify the successful diagnostics artifact contains the current build's own matching `xul.pdb` before using symbols from this build.
3. Physically test the exact `cd5e715...` artifact on XP; keep normal packaged startup distinct from any config-free diagnostic startup.
4. If the Wasm assert recurs, symbolize only with the matching PDB from the same exact failing build.
5. If startup advances, record the next actual runtime boundary before broadening Shell32 fixes. `SHCreateItemFromParsingName` is the next already-localized Shell32 candidate; `SHOpenWithDialog` must be localized first.
6. Treat the ten YY missing-contract DLL classifications from `34095425319` as follow-up candidates only; do not modify them en masse without runtime/focused evidence.
7. Workflow refactoring may proceed to another small structure-only batch because the first checkpoint is GREEN; keep extraction separate from linker-policy changes.

## XP acceptance boundary

Final XP acceptance still requires one exact candidate to start and sustain representative browser use on physical Windows XP. That boundary is **not yet met**.

The old critical-section and earlier IP Helper runtime boundaries are closed. The current Shell32 cluster is now build/static validated at source `cd5e715...` by run `34107793132`; physical-XP runtime validation remains pending. The Wasm assertion remains unresolved in parallel. A successful build is not physical-XP runtime proof, and XP runtime success is not a GOST TLS handshake result.

# Bundled government-system extensions / localization

Current proven three-extension packaging checkpoint remains source `b3d097de20b7a5711f161199a727bcfe9468bcc8`, run `32976571122`, job `98202641607`.

Current corrected Russian localization package gate is source `3e2c32386f373d4693db52b32c05aa2000878def`, workflow `CryptoPro Mozilla packaging smoke`, run `33520207057`, job `99897230730`, success.

Manual runtime evidence belongs to the exact artifact on which it was observed; do not reattribute it to later packaging-only correction builds.

# Global evidence rules

- Build success != GOST handshake success.
- GOST runtime success != final server-trust closure.
- Focused dependency/runtime success != full Firefox startup.
- Win7 x86 startup != XP startup.
- Source/build removal of a hard or delay-import runtime edge != physical-XP runtime closure until the exact accepted artifact advances past it.
- Documentation HEADs never replace the exact source-under-test SHA for previously built or runtime-tested artifacts.
- A PDB may symbolize only the exact matching binary from the same build.
- For in-progress runs, record provisional state and never mark pending gates as passed.
