# r3dfox GOST TLS — Project State

Last updated: 2026-09-11

This file is the authoritative current technical synthesis and handoff for new chats. Detailed experiment evidence belongs in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes; closed milestones are in `DONE.md`; pending work is in `TODO.md`; workflow roles are in `WORKFLOWS.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default GOST development branch and canonical documentation source: `agent/gost-tls-poc`.
- Windows XP SP3 x86 compatibility implementation branch: `agent/winrt-source-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the active work branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer base.

For Windows XP work, read `XP_BUILD_CONTRACT.md`, `XP_MOZ_XP_COMPAT_CONTRACT.md`, `XP_RUNTIME_COMPATIBILITY_STATUS.md`, and the newest XP entries in `TEST_LOG.md`.

## Separation of conclusions

Keep these tracks independent unless a deliberately combined experiment tests both:

1. GOST TLS runtime / NSS / NSPR / MSSPI / SSPI / CryptoPro / handshake.
2. Windows Vista/7/XP compatibility / Rust / msvcr14x / YY-Thunks / linker / PE imports / physical runtime.
3. Bundled government-system extensions and localization/package behavior.

A successful build is not a successful GOST handshake. A hosted compatibility probe is not physical-XP proof. Win7 x86 runtime success is not XP runtime success. Documentation HEADs never replace the exact source-under-test SHA for an earlier artifact.

# GOST TLS runtime

No GOST-runtime conclusion changes as a result of the XP work below.

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

## Latest integrated full build — build/package PASS; aggregate RED at final summary, cause not reclassified here

Exact current full-build evidence:

- branch `agent/winrt-source-poc`;
- source-under-test `71c7f135210030dde4ec9eeee04e6cb36a2cbffc` (`fix(xp): refresh dwrote checksum after import fix`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34485182943`, attempt `1`;
- job `102897550999` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate conclusion: **completed / failure / RED**.

Exact artifacts:

- package `10162565742`, digest `sha256:2c416478c8d57ed08f863f1506f5969980ff8b0c1e53845fe4de695f1727592d`;
- runtime `10162567956`, digest `sha256:99c67fac2074222371db284e57e0c78a75f617c7b5a3bc0b237bb95154d87fb8`;
- diagnostics `10162609423`, digest `sha256:a890ac3fc0b972dee2c0a396559cf82ce04f27ee13daa41f0b0ed2c631fd3513`.

This was not a Firefox build/package or artifact-upload failure. Full compile/link, the listed targeted xul/mozglue XP gates, private DWrite preparation/staging/retarget/package-survival gates, msvcr14x/bcrypt/D3DCompiler package checks, physical-test runtime archive creation, `GATE - Audit XP x32 PE floor and direct imports`, YY inventory and all three uploads completed `success`. The only failed Actions step is `GATE - Summarize XP x32 full build`.

This bookkeeping update deliberately does not inspect the job logs or diagnostics payload to classify the final summary's gate reason. Therefore do **not** automatically carry the preceding run's `gate:broad-import-audit=failure` / 22-row private-DWrite finding forward as the cause of run `34485182943`. The aggregate cause of this exact run remains unclassified until a separate focused analysis is performed.

Do not call this run GREEN. It also is not, by itself, physical-XP browser evidence or GOST TLS runtime evidence.

### Preceding analyzed integrated build — exact 22-row private-DWrite broad-audit evidence

Run `34439013068`, job `102749929410`, source-under-test `c0b5561dc58d588ecb970a333d49ac78fae84eb0` remains the latest integrated run whose final RED was explicitly localized from its diagnostics. Its `xp-x32-forbidden-direct-imports.txt` contained exactly 22 rows, all attributed to staged private `xpcompat/dwrite/DWrite.dll`, with no forbidden rows for `xul.dll`, `mozglue.dll`, another browser DLL or executable. That evidence remains valid for that exact run and must not be silently reattributed to later source `71c7f135...`.

## Private Supermium DWrite component — focused PHYSICAL XP PASS

The focused workflow `.github/workflows/xp-supermium-dwrite-closure.yml` does not checkout or build Firefox. Its source identity is the workflow plus pinned external assets; `firefox_source=NOT_APPLICABLE`.

Current authoritative focused DWrite result:

- workflow/head SHA `a42b144cbeeeac6a3765d132111208d600f1a3fc`;
- run `34317489430`;
- job `102356664699`;
- result **completed / success / GREEN**;
- candidate artifact `10090864697` (`xp-supermium-dwrite-dist-bin-34317489430`), digest `sha256:de0765b8ed2e28259420d9671c2b4e4a54b492555698724187a7f6ea2ee40a47`;
- diagnostics artifact `10090863781`, digest `sha256:549913f8ea9a92a87bc602bc486e627be25667cec66fe4ef917939fabd29a8ef`.

The selected layout uses project msvcr14x `ucrtbase.dll` at `dist/bin` and the pinned private DWrite subtree under `dist/bin/xpcompat/dwrite/`; Supermium `ucrtbase.dll` is not staged. Physical Windows XP SP3 x86 execution of the exact focused candidate reports `UCRT_STARTUP_LOAD_PASS`, `UCRT_STATIC_TLS_PASS`, `PWRP_LOAD_PASS`, `DWRITE_LOAD_PASS`, `DWRITE_FACTORY_PASS`, `DWRITE_FONT_COLLECTION_PASS`, and `DWRITE_SMOKE_PASS`.

Therefore the private DWrite architecture is physically viable at focused-component scale: the project msvcr14x UCRT is usable at process startup including static TLS, private `pwrp_k32.dll` and `DWrite.dll` load from the isolated subtree, `DWriteCreateFactory` succeeds, and `IDWriteFactory::GetSystemFontCollection()` succeeds. This focused physical proof is independent of the full-browser aggregate audit policy and does not itself prove Firefox startup.

The first full Firefox transfer was source `35c7482bc7e5f4a37427937ecbf4fdcb6daeffec`, run `34353829276`, job `102473382783`; it proved compile/link/staging/package integration. Run `34439013068` later supplied the explicit 22-row DWrite-only broad-audit classification. Run `34485182943` is now the latest integrated full-build identity, but its final-summary failure is intentionally not root-caused in the current bookkeeping pass.

## Current all-GREEN pre-DirectWrite-integrated build/static candidate

The latest completed all-GREEN full-build source-under-test remains:

- branch `agent/winrt-source-poc`;
- SHA `db334d39cf929de7a12ea2f74bea32ddc4f3e4e4`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml`;
- run `34213345771`, attempt `1`;
- job `102019253738`;
- aggregate conclusion: **success / GREEN**;
- package `10056086223`, digest `sha256:9135b55913dfcf49390d022b94c21520ed2f5852e8b846f4b117635696634949`;
- runtime `10056088395`, digest `sha256:2cf7cf6ca44c0d8abddb930564a65bdf57188f4a2ae0fd5a56b29d7c522ce57f`;
- diagnostics `10056127829`, digest `sha256:04d284ce8738a63b72508e00747576c56fb2dfb86233e6e460fc1803b4234b33`.

This remains the last all-GREEN build/static baseline, but it predates private DirectWrite integration. Do not use it as evidence for the integrated DWrite layout.

## SharedPrefMap child-HANDLE blocker — PHYSICALLY CLOSED on `897e1cdf...`

The old physical XP blocker at `modules/libpref/SharedPrefMap.cpp:25` / `MOZ_RELEASE_ASSERT(map)` / exception `0x80000003` was localized with matching WinDbg evidence to `MapViewOfFileEx(...) -> NULL`, `GetLastError() = 6 = ERROR_INVALID_HANDLE`, `LastStatusValue = 0xC0000008 = STATUS_INVALID_HANDLE`. The child received the numeric `-prefMapHandle`, but the corresponding kernel HANDLE had not been inherited.

The remediation in `ipc/chromium/src/base/process_util_win.cc` preserves the Vista+ selective attribute-list path and, under `MOZ_XP_COMPAT`, enables classic Windows handle inheritance when that API family is unavailable. Physical XP testing of exact source `897e1cdf98bcc091e13283fa8004177971d30f27` / run `34194737456` repeatedly advanced beyond the old boundary. User-reported identities were `r3dfox.exe` SHA-1 `dbfaed8d2d06d50195a572f8364186e4032f8a97` and `xul.dll` SHA-1 `fcc09439c4e36be056b5796303f7e433a7afe585`.

Conclusion: the SharedPrefMap invalid-child-HANDLE blocker is physically closed for that exact source/run. Do not reopen it without contradictory evidence. Newer build lineages retain the launcher remediation, but physical validation of an accepted newer integrated artifact remains separate.

## Physical `0xC06D007F` battery boundary — root cause localized; successor static fix remains GREEN

After the SharedPrefMap advance, exact source `897e1cdf...` reached physical exception `0xC06D007F`. Matching DrWatson/PDB evidence localized `__delayLoadHelper2` failure to `USER32!RegisterPowerSettingNotification`, owned by `hal/windows/WindowsBattery.cpp::EnableBatteryNotifications()`.

The successor source remediation uses XP-compatible `WM_POWERBROADCAST / PBT_APMPOWERSTATUSCHANGE` under C/C++ `MOZ_XP_COMPAT` and compiles out both `RegisterPowerSettingNotification` and `UnregisterPowerSettingNotification`. The dedicated final-`xul.dll` direct+delay gate passed in all-GREEN run `34213345771`, first integrated run `34353829276`, analyzed integrated run `34439013068`, and latest integrated run `34485182943`.

Therefore the exact old delayed-import edge remains statically removed. Do not call the physical `0xC06D007F` boundary closed until an accepted exact successor browser artifact advances beyond it on real XP.

## Rejected `Platform::Freeze()` access-mask override — removed

The earlier XP-only `GENERIC_READ | FILE_MAP_READ` -> `FILE_MAP_READ | SECTION_QUERY` experiment independently failed to advance SharedPrefMap and was removed by `dad33d25dddc060ee74d773dcc492d835a78fd1e`. Current lineages preserve the successful launcher fix without that rejected access-mask workaround.

## Latest YY DLL entry-point/TLS static coverage — 13/13 CLOSED

Run `34138054280`, job `101793510758`, source-under-test `6885135565f7262bb88c80c4751f4a6c4b93e3ef` expanded scoped YY-Thunks DLL/TLS startup coverage from 3/13 to 13/13 strong candidates. The aggregate job was RED only because a separate supplemental warm-relink experiment used incorrect generated-objdir assumptions; the static 13/13 closure itself is valid. Latest integrated run `34485182943` completes the YY inventory successfully and also passes `GATE - Verify committed xul.dll YY TLS entry-point contract`.

## Build-configuration identity

Keep the XP compatibility mechanisms distinct:

- C/C++ `MOZ_XP_COMPAT` is supplied through XP `CFLAGS` / `CXXFLAGS` as `-DMOZ_XP_COMPAT`;
- Rust uses separate job-global `RUSTFLAGS="--cfg moz_xp_compat"`;
- neither implies a `moz.build` `CONFIG["MOZ_XP_COMPAT"]` variable.

## Earlier physical/runtime boundaries closed or statically established in the current lineage

Do not reopen these without contradictory evidence on a later exact artifact:

- `SharedPrefMap.cpp:25` / invalid inherited preference HANDLE / `0x80000003` on `897e1cdf...`;
- `xul.dll` `ntdll!RtlpWaitForCriticalSection` startup failure;
- preceding IP Helper runtime boundary;
- `USER32!SetProcessDPIAware` delay-load boundary;
- `NtCancelIoFileEx`;
- ADVAPI32 ETW family;
- KERNEL32 restart/named-pipe source-remediation quartet;
- PROPSYS ordinary-import dependency;
- WS2_32 observed compatibility family;
- ANGLE/DXGI static `CreateDXGIFactory1` edge;
- 13/13 strong-candidate YY DLL entry-point/TLS static coverage;
- focused private DWrite component runtime contract on physical XP (`34317489430` / `10090864697`).

The `USER32!RegisterPowerSettingNotification` / `0xC06D007F` edge is not in the physically closed browser list yet: root cause and successor static removal are proven, but successor physical browser execution is pending. Full YY `kernel32.lib` interposition remains prohibited; keep compatibility ownership narrow by source/provider/PE.

## XP acceptance boundary

Final XP acceptance still requires one exact integrated candidate to start and sustain representative browser use on physical Windows XP. That boundary is **not yet met** by build evidence alone.

Current source `71c7f135210030dde4ec9eeee04e6cb36a2cbffc` / run `34485182943` proves full compile/link/package, runtime-archive creation, artifact publication and successful execution of the targeted browser/static gates listed above, but the aggregate workflow result remains RED at the final summary. Because this documentation pass intentionally did not inspect that summary's log reason or diagnostics payload, the remaining aggregate blocker for this run is not classified here. The previously established 22-row private-DWrite broad-audit result remains evidence for run `34439013068`, not automatically for this successor.

Before treating `71c7f135...` as an accepted static candidate, classify the exact final-summary failure in a separate focused pass. Physical XP runtime success, if later established for an exact artifact, would still not by itself prove a GOST TLS handshake.

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
- Runtime claims must stay bound to exact source SHA + Actions run/job + exact artifact/binary identity.