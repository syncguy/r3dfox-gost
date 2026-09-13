# Windows XP x86 — SHELL32 compatibility cluster

Last updated: 2026-09-07

Track: Windows XP SP3 x86 compatibility only. This document does not describe or prove GOST TLS runtime behavior.

Canonical documentation branch: `agent/gost-tls-poc`.

Implementation branch: `agent/winrt-source-poc`.

## Purpose

This document records the current `SHELL32.dll` compatibility cluster discovered while progressing the Firefox 153 / r3dfox XP x86 runtime. It separates:

- physically proven XP runtime failures;
- source-integrated `MOZ_XP_COMPAT` remediations;
- proactively identified neighboring post-XP Shell APIs;
- the exact full-build and physical-runtime validation still required.

Do not treat a delay-import entry by itself as a physical XP failure. The relevant question is whether the XP build can reach the call without a source guard or native XP replacement.

## Physically proven boundary

The authoritative physical failure was observed with the exact previously GREEN XP browser:

- source-under-test: `0a18ba85b3f493b17c5a62742e869788ca3f2f6b`;
- Actions run `34079480996`, attempt `1`;
- job `101611911453`;
- runtime artifact `10005434852`;
- physical Windows XP SP3 x86;
- `drwtsn32.log` SHA-256 `f54366c0787cc53962f3300cbd84ddab0fdf507cf9d3a613901f2f6879144a36`;
- `user.dmp` SHA-256 `0e3cb1e3e4822729145bcc4f6d6e799ead772321fc018cb1c9fb648c97efbb38`.

The decoded MSVC delay-load exception was:

```text
exception      C06D007F
DLL            SHELL32.dll
procedure      SHGetKnownFolderPath
pfnCur         0
last error     0x0000007f / ERROR_PROC_NOT_FOUND
```

The physically reached owner was `toolkit/xre/nsXREDirProvider.cpp`. Its existing registry fallback could not run because the MSVC delay-loader raised before `SHGetKnownFolderPath` could return a failing `HRESULT`.

This is the only Shell32 member in this cluster that currently has direct physical-XP failure evidence.

## Source-integrated `MOZ_XP_COMPAT` remediations

Current implementation HEAD:

`cd5e7155b0f227a22b7c35a0a44e2e24f69456d4` — `fix(xp): use legacy ProgramData shell folder`.

The current HEAD contains three source-owned Shell32 remediations.

### 1. `toolkit/xre/nsXREDirProvider.cpp`

Physical motivation: the proven `C06D007F` failure above.

Under `MOZ_XP_COMPAT`:

```text
FOLDERID_LocalAppData   -> CSIDL_LOCAL_APPDATA
FOLDERID_RoamingAppData -> CSIDL_APPDATA
SHGetKnownFolderPath    -> SHGetFolderPathW
```

The existing registry fallback remains available if `SHGetFolderPathW` fails. Normal non-XP Windows builds retain the original Known Folder path.

Relevant implementation lineage:

- `b5db4a4312ccf66a245d47dbc0464c11781cf620` — source ownership / ordinary `SOURCES` integration;
- `50ca390932f0be83309b905226e2e9fea0fe1e75` — XP-era AppData shell-folder implementation.

### 2. `xpcom/io/SpecialSystemDirectory.cpp`

This owner was found proactively while auditing the same `SHGetKnownFolderPath` API family.

The existing source already intended XP Downloads to fall back to Desktop, but the fallback was runtime-based and therefore could not protect XP from a delay-load exception raised before the call returned.

Under `MOZ_XP_COMPAT`:

```text
Win_Downloads -> GetWindowsFolder(CSIDL_DESKTOP)
```

The `GetKnownFolder(...)` helper containing the direct `SHGetKnownFolderPath` call is excluded from the XP translation unit. Non-XP Windows builds retain the Known Folder Downloads path.

Relevant implementation commits:

- `e8c3ce7ae9979ef368e066eb593edf0a258f74a5` — move `SpecialSystemDirectory.cpp` out of unified compilation and make the TU source-owned by `MOZ_XP_COMPAT`;
- `494cda6893282858240976a13e5e8f0af1a0901f` — compile-time XP Downloads fallback / Known Folder exclusion.

### 3. `toolkit/mozapps/update/common/commonupdatedir.cpp`

This owner was also found proactively in the same Shell32 audit. The modern path obtains ProgramData through `SHGetKnownFolderPath(FOLDERID_ProgramData, ...)`.

Under `MOZ_XP_COMPAT` the XP-native equivalent is:

```cpp
SHGetFolderPathW(nullptr,
                 CSIDL_COMMON_APPDATA | CSIDL_FLAG_CREATE,
                 nullptr,
                 SHGFP_TYPE_CURRENT,
                 baseDirParentPath);
```

Normal non-XP Windows builds retain `SHGetKnownFolderPath(FOLDERID_ProgramData, ...)`.

Relevant implementation commits:

- `76c447d142751676908b5837ef3609617a5c7cb8` — move `commonupdatedir.cpp` out of unified compilation and make the TU source-owned by `MOZ_XP_COMPAT`;
- `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4` — XP-era ProgramData path.

## Net implementation boundary

The net compare from the preceding implementation point
`b59e957015544fa7761abf07fedde3c5d259104c`
to current HEAD
`cd5e7155b0f227a22b7c35a0a44e2e24f69456d4`
contains only four expected files:

```text
toolkit/mozapps/update/common/commonupdatedir.cpp
toolkit/xre/moz.build
xpcom/io/SpecialSystemDirectory.cpp
xpcom/io/moz.build
```

The two new production owners were moved from `UNIFIED_SOURCES` to ordinary `SOURCES` before applying source-local `-DMOZ_XP_COMPAT`, as required by `XP_MOZ_XP_COMPAT_CONTRACT.md`.

## Current validation build

A full XP x32 validation build was explicitly started from the exact current implementation HEAD:

- workflow: `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34107793132`, attempt `1`;
- job `101696721232` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- branch `agent/winrt-source-poc`;
- source-under-test `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4`;
- trigger `workflow_dispatch`;
- current state when documented: **in progress**.

Do not record this run as GREEN until the job and aggregate gates complete. Do not attribute results from the older PDB/YY inventory run `34095425319` / job `101657910987` / source `a15dcd738edda4ab810fc9f92289170f115519e4` to these Shell32 remediations.

## Remaining Shell32 candidates discovered in the same audit

These are not yet physically proven XP blockers and are intentionally not included in the current build experiment.

### `SHCreateItemFromParsingName`

Known source owner: `toolkit/components/downloads/DownloadPlatform.cpp`.

The modern path creates an `IShellItem` and uses AppUserModelID-aware recent-document behavior. The same source already has a simpler `SHAddToRecentDocs(SHARD_PATHW, ...)` fallback.

XP risk: on XP the missing delay-loaded export can raise before the current `SUCCEEDED(...)` fallback logic is reached.

Planned direction if/when this edge is addressed:

```text
MOZ_XP_COMPAT -> use the existing SHARD_PATHW recent-document path directly
non-XP        -> retain the modern IShellItem/AppUserModelID path
```

Do not fold this into the current Shell32 build before the exact `cd5e715...` candidate is classified; keeping it separate preserves experimental attribution.

### `SHOpenWithDialog`

The API appears in the Shell32 delay-import family of the previously inspected exact `xul.dll`, but its current production source owner and runtime reachability still need to be localized before any change is justified.

Planned action: locate the exact owner/call path first, then decide whether XP has a meaningful native fallback or the feature should be excluded under `MOZ_XP_COMPAT`.

### `GetCurrentProcessExplicitAppUserModelID`

This Windows 7-era API was present in the earlier Shell32 inventory, but at least one current Firefox owner (`WinTaskbar.cpp`) already performs dynamic `GetProcAddress` resolution and supplies a fallback AppUserModelID when the export is absent.

Planned action: audit the final rebuilt `xul.dll` and source ownership before changing anything. Presence in an old delay-import table is not enough to justify a remediation when the reachable owner is already dynamically guarded.

## Next experiment order

1. Finish run `34107793132` / job `101696721232` and bind every conclusion to source `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4`.
2. Confirm full build/package/static gates and inspect the final `xul.dll` Shell32 delay-import inventory, especially residual `SHGetKnownFolderPath` ownership.
3. Physically run the exact resulting artifact on Windows XP SP3 x86.
4. If startup advances, record the next actual runtime boundary before broadening the Shell32 patch set.
5. Handle `SHCreateItemFromParsingName` as the next known feature-path candidate, preferably as a separate `MOZ_XP_COMPAT` experiment.
6. Localize `SHOpenWithDialog` before changing it.
7. Keep the unresolved Wasm `MOZ_RELEASE_ASSERT(map)` investigation separate; a Shell32 build outcome does not by itself close or prove the Wasm/TLS/init-order line.

## Acceptance boundary

The current Shell32 cluster is **source-integrated, not runtime-closed**.

Closure requires a full build from the exact remediated source, static evidence from its final binaries, and physical Windows XP validation of that exact artifact. A successful build does not prove XP runtime success, and XP runtime success does not prove a GOST TLS handshake.
