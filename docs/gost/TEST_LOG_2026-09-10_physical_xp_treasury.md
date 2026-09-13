# Physical Windows XP Firefox 153 / Treasury runtime evidence — 2026-09-10

Track: deliberately combined physical runtime observation. Keep the Windows XP browser-compatibility conclusion and the GOST TLS conclusion separate.

## Exact build identity

- repository: `syncguy/r3dfox-gost`;
- branch: `agent/winrt-source-poc`;
- source-under-test: `88453be37a7f39f690c504078f6f9434e2547ab6` (`ci: trigger WinRT source PoC x86 for XP known-folder fixes`);
- workflow: `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build XP x32`;
- run: `34459906476`, attempt 1;
- job: `102815008544` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- Actions aggregate conclusion: **completed / failure / RED**. Do not call this run GREEN.

The full Firefox build, packaging, physical-test runtime archive creation, PE audit and artifact uploads completed successfully; the final aggregate summary gate failed. The runtime results below are independent physical evidence and must not be inferred from the Actions aggregate conclusion.

Fresh artifact metadata from the run:

- package artifact `10150743461` (`r3dfox-gost-xp-x32-package`), digest `sha256:8373ec0199e681117fa82c8d541269cd0cf58f98374e1caec4391d871053d0c9`;
- runtime artifact `10150744314` (`r3dfox-gost-xp-x32-runtime`), digest `sha256:444510cb88c4b05732c6f89630995dbc309d2ea489b890436783e84097935e06`;
- diagnostics artifact `10150778254` (`r3dfox-gost-xp-x32-diagnostics`), digest `sha256:b657c9f7d76e7fb9046f63586485e88d1961aa8f2dc88caeb058ac54f697ddd0`.

## Physical XP binary identity — independently matched to Actions artifact

Tester-reported hashes from the exact physical test directory `D:\2026\09\10\r3dfox-v153.0.3.win32.portable` using Windows XP `certutil -hashfile`, which reports SHA-1 in this environment:

- `r3dfox.exe` SHA-1 `351ac2a4017c22c9c2a800efd98a3a6e06d6ed28`;
- `xul.dll` SHA-1 `47efea21a563940ad14886063a564f27d22d73e4`;
- `xpcompat\dwrite\DWrite.dll` SHA-1 `a72f49accb58a5dc894a9735ccd470fd7f89845d`.

The exact Actions runtime artifact `10150744314` was subsequently downloaded and its nested runtime archive was independently extracted. The extracted files have exactly the same SHA-1 values:

- artifact `r3dfox.exe` -> `351ac2a4017c22c9c2a800efd98a3a6e06d6ed28`;
- artifact `xul.dll` -> `47efea21a563940ad14886063a564f27d22d73e4`;
- artifact `xpcompat\dwrite\DWrite.dll` -> `a72f49accb58a5dc894a9735ccd470fd7f89845d`.

Therefore the physical runtime binary identity is now independently bound to run `34459906476` / job `102815008544` / source-under-test `88453be37a7f39f690c504078f6f9434e2547ab6`, not merely attributed by directory naming.

## Physical XP browser-runtime capture

The first successful physical XP session used:

```bat
set MOZ_GFX_CRASH_MOZ_CRASH=
set MOZ_FORCE_DISABLE_E10S=1
set MOZ_LOG=timestamp,sync,ipc:5,nsDocShell:5,nsHttp:5,cache2:5,nsSocketTransport:5,nsHostResolver:5,console:5
set MOZ_LOG_FILE=C:\TEMP\DrWatson\r3dfox-startup.log

set "R3DFOX_GOST_HOSTS=fzs.roskazna.ru,lk-fzs.roskazna.ru,pay.gov.ru,portalgisgmp.login.roskazna.ru,portalgisgmp.cert.roskazna.ru"
set "R3DFOX_GOST_CLIENT_CERT_THUMBPRINT="
set "R3DFOX_GOST_CLIENT_AUTH_MODE="
set "R3DFOX_GOST_CIPHERS="

r3dfox.exe https://fzs.roskazna.ru/
```

`set MOZ_GFX_CRASH_MOZ_CRASH=` removes that variable from the `cmd.exe` environment. `MOZ_FORCE_DISABLE_E10S=1` is part of the exact runtime conditions; this result must not be generalized to the default multiprocess/e10s configuration.

The supplied sanitized evidence archive `GOST_TLS_XP.zip` has SHA-256 `350f04adc3a4d26d19d59fba7670cdf6db97fe455f3c0848f0b0449ee275e685`.

The log records parent process `PID 3132` navigating to `https://fzs.roskazna.ru/`, receiving `HTTP/1.1 200 OK`, processing the response through `nsHttpChannel`, writing content to cache, and subsequently loading Treasury application resources and API requests including `/api/settings`, `/api/settings/smev-info`, `/api/settings/currentversion`, and `/api/users/info` plus CSS/JS/favicon traffic.

This is not a window-flash or startup-only observation. It establishes that the exact Firefox/r3dfox 153 artifact can execute a real browser workload on physical Windows XP SP3 x86, render/use a remote HTTPS application, and continue application traffic after initial navigation.

Later in that first capture, the parent process terminates/disappears and child/auxiliary processes report `OnChannelErrorFromLink`. Therefore **stable/sustained XP acceptance remains OPEN**. The earlier physical `0xC06D007F` / `USER32!RegisterPowerSettingNotification` startup boundary is nevertheless physically advanced beyond by this exact successor artifact because the browser reaches rendered remote application traffic.

## `GostTLS:5` follow-up capture — direct physical MSSPI/GOST handshake proof

A second physical XP capture used the same exact binary set and the same forced non-e10s condition, but enabled the dedicated transport telemetry:

```bat
set MOZ_GFX_CRASH_MOZ_CRASH=
set MOZ_FORCE_DISABLE_E10S=1
set MOZ_LOG=timestamp,sync,GostTLS:5,ipc:5,nsDocShell:5,nsHttp:5,cache2:5,nsSocketTransport:5,nsHostResolver:5,console:5
set MOZ_LOG_FILE=C:\TEMP\DrWatson\r3dfox-gost-xp.log

set "R3DFOX_GOST_HOSTS=fzs.roskazna.ru,lk-fzs.roskazna.ru,pay.gov.ru,portalgisgmp.login.roskazna.ru,portalgisgmp.cert.roskazna.ru"
set "R3DFOX_GOST_CLIENT_CERT_THUMBPRINT="
set "R3DFOX_GOST_CLIENT_AUTH_MODE="
set "R3DFOX_GOST_CIPHERS="

r3dfox.exe https://fzs.roskazna.ru/
```

Evidence identity:

- uploaded archive `GOST_TLS_XP_2.zip`: SHA-256 `3f88a6f6917cc304ceec113e2e4b55fe053e5f7bcababcf23fddb93e8b3194f9`;
- parent log `r3dfox-gost-xp.log.moz_log`: SHA-1 `dc017903ea54d7287ed5b78e1cabaa3e692e10d4`, SHA-256 `f259d2b0bf770b699d82039d70d75d0acde21b560a3f10705b7a82eb8ca1e6f2`;
- parent process in this capture: `PID 6216`;
- captured interval: approximately `2026-09-10 14:19:58.198 UTC` through `14:20:52.525 UTC`.

The dedicated `GostTLS` telemetry proves the selected transport path, not merely successful generic HTTPS:

1. `fzs.roskazna.ru` matches the explicit allowlist (`allowlist matched ... token=fzs.roskazna.ru`).
2. The browser configures the MSSPI path as TLS 1.2 and the default GOST cipher list `C100:C101:C102:FF85:0081`.
3. The browser attaches the custom layer (`attached MSSPI GOST layer host=fzs.roskazna.ru port=443 TLS=1.2 ...`).
4. There are **six completed MSSPI handshakes** for `fzs.roskazna.ru` in the parent-process log. Every completion reports `TLS=0x0303`, `cipher=0xff85`, `state=0x00000000`, and `client_cert_loaded=0`.
5. Each of those six completed handshakes is preceded by a successful server-verification result: `DriveHandshake verify host=fzs.roskazna.ru ok=1 status=0x00000000 ...`.
6. Server-certificate diagnostics on those connections report a peer certificate, a three-certificate peer chain, and `peernames_ok=1` before the successful verification result.
7. The custom layer then carries application I/O through successful `msspi_write` / `msspi_read` operations. Immediately after the first completed handshake the HTTP stack receives `HTTP/1.1 200 OK`, and the browser proceeds to Treasury application resources/API traffic.
8. The parent log contains no `E/GostTLS` or `W/GostTLS` entries and no `handshake failed` record. Some negative read return values are ordinary nonblocking/pending operations (`WSAEWOULDBLOCK`) and are followed by continued successful encrypted I/O; they are not transport handshake failures.

This capture establishes an actual negotiated GOST TLS 1.2 session on physical XP, not merely selection of the GOST-host branch.

The positive server-verification result is evidence that verification succeeded for these observed sessions. It does **not** by itself close the project's separate fail-closed/negative-path server-verification work.

All six completed handshakes report `client_cert_loaded=0`, consistent with the deliberately empty `R3DFOX_GOST_CLIENT_CERT_THUMBPRINT` / `R3DFOX_GOST_CLIENT_AUTH_MODE` settings. Therefore this experiment does **not** establish client-certificate or mTLS success. Client-auth remains a separate acceptance line.

The second parent log stops at `14:20:52.525 UTC`; Socket/content/RDD/utility logs report `OnChannelErrorFromLink` at `14:20:52.635 UTC`. Thus the parent disappears roughly 110 ms after its final logged IPC activity. This preserves the separate late XP runtime blocker; the successful GOST handshake is already complete long before that boundary.

## Repeating late parent crash — exact `xul.dll` symbolization

The same physical build repeatedly reports:

```text
faulting application r3dfox.exe 153.0.3.3
faulting module xul.dll 153.0.3.3
fault address 0x0116fab3
```

Because the physical `xul.dll` SHA-1 is now independently matched to runtime artifact `10150744314`, the matching `xul.pdb` was extracted from diagnostics artifact `10150778254` from the same run and used to symbolize the module-relative fault RVA `0x0116fab3`.

Exact symbolization:

```text
MOZ_Crash
  ...\mozilla\Assertions.h:402

gfxFontGroup::GetDefaultFont(void)
  gfx\thebes\gfxTextRun.cpp:2242
```

The PE image base is `0x10000000`; RVA `0x0116fab3` corresponds to VA `0x1116fab3`. Disassembly of the exact `xul.dll` at that address is `0xCC` (`int 3`). Therefore the repeating fault is an intentional Mozilla crash breakpoint, not evidence of a random instruction-pointer corruption or an arbitrary access violation.

The exact source around `gfxFontGroup::GetDefaultFont()` shows the fatal path: `mDefaultFont` is absent; the last-ditch `gfxPlatformFontList::GetDefaultFontEntry()` / `FindOrMakeFont()` fallback does not produce a usable font; Firefox emits the `no fonts`/backend diagnostic and executes `MOZ_CRASH_UNSAFE("unable to find a usable font (...)")`.

This establishes the **current late physical XP boundary** for this build as a font/default-font failure. It is not the same crash site as the earlier Rust `dwrote` assertion `!dwrite_create_factory_ptr.is_null()`. The two failures may still share a DirectWrite-related underlying compatibility problem, but that relationship is a hypothesis, not yet proof. The Rust private-DWrite loader fix must therefore be tested independently on its successor artifact rather than assumed to close this late font crash.

For the next physical run, add `fontinit:5,fontlist:5` to `MOZ_LOG` so the Windows font-list initialization records DirectWrite system-family enumeration and family counts before any repeat of `gfxFontGroup::GetDefaultFont()`.

## Conclusion

Three distinct milestones/boundaries are now established for exact source/run `88453be37a7f39f690c504078f6f9434e2547ab6` / `34459906476` / `102815008544`:

- **PHYSICAL XP FULL-BROWSER RUNTIME MILESTONE UNDER FORCED NON-E10S:** Firefox/r3dfox 153 reaches and uses the Treasury application on physical Windows XP SP3 x86 and physically advances beyond the earlier battery startup boundary. Stable/sustained XP runtime remains open.
- **PHYSICAL GOST TLS SERVER-AUTH HANDSHAKE PASS UNDER FORCED NON-E10S:** `GostTLS:5` directly proves allowlist selection -> custom MSSPI GOST layer attachment -> successful server verification -> six successful TLS 1.2 handshakes negotiating `0xff85` -> encrypted MSSPI application I/O -> HTTP/Treasury traffic.
- **LATE XP CRASH OWNER LOCALIZED:** repeating `xul.dll + 0x0116fab3` resolves with exact matching symbols to the deliberate `MOZ_CRASH_UNSAFE` in `gfxFontGroup::GetDefaultFont()` when no usable/default font can be obtained.

Do not generalize the runtime or GOST result to default e10s/multiprocess operation. Do not treat this no-client-certificate run as an mTLS/client-auth PASS. Do not treat the positive observed server-verification result as closure of the separate fail-closed negative-path verification work. Do not attribute the late font crash to the Rust `dwrote` loader without new evidence from the successor build.