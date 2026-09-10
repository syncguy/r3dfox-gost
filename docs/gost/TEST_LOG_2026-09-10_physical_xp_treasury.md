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

Artifacts from the run:

- package artifact `10150743461` (`r3dfox-gost-xp-x32-package`), digest `sha256:8373a80894553d084167fdf5a3b67a7cc0bc9b27296423918f3ba33aef7fe9af`;
- runtime artifact `10150744314` (`r3dfox-gost-xp-x32-runtime`), digest `sha256:4445b69944aba3a36e9cf9e45bc193d18fc3e9eda8670d12e7901014aca0d6a5`;
- diagnostics artifact `10150778254` (`r3dfox-gost-xp-x32-diagnostics`), digest `sha256:b65744451ee6bcdce975003fa14f1ce05e59caaa564442751fcdd1a83eed1bdc`.

## Physical XP binary identity

Tester-reported hashes from the exact physical test directory `D:\2026\09\10\r3dfox-v153.0.3.win32.portable` using Windows XP `certutil -hashfile`, which reports SHA-1 in this environment:

- `r3dfox.exe` SHA-1 `351ac2a4017c22c9c2a800efd98a3a6e06d6ed28`;
- `xul.dll` SHA-1 `47efea21a563940ad14886063a564f27d22d73e4`;
- `xpcompat\dwrite\DWrite.dll` SHA-1 `a72f49accb58a5dc894a9735ccd470fd7f89845d`.

The tester attributes these files to run `34459906476` / job `102815008544`. The Actions run/source/artifact identity above is independently verified. Independent extraction of the Actions runtime/package archive and byte-for-byte matching of these three SHA-1 values has not yet been recorded, so do not silently promote tester attribution into an independently matched artifact hash claim.

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

This is not a window-flash or startup-only observation. It establishes that the tester-attributed Firefox/r3dfox 153 artifact can execute a real browser workload on physical Windows XP SP3 x86, render/use a remote HTTPS application, and continue application traffic after initial navigation.

Later in that first capture, the parent process terminates/disappears and child/auxiliary processes report `OnChannelErrorFromLink`. Therefore **stable/sustained XP acceptance remains OPEN**. The earlier physical `0xC06D007F` / `USER32!RegisterPowerSettingNotification` startup boundary is nevertheless physically advanced beyond in this exact observed session because the browser reaches rendered remote application traffic. This does not identify the owner of the later termination.

## `GostTLS:5` follow-up capture — direct physical MSSPI/GOST handshake proof

A second physical XP capture used the same tester-attributed binary set and the same forced non-e10s condition, but enabled the dedicated transport telemetry:

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
7. Firefox then reports `TlsHandshaker::HandshakeDone`, and the custom layer carries application I/O through successful `msspi_write` / `msspi_read` operations. Immediately after the first completed handshake the HTTP stack receives `HTTP/1.1 200 OK`; later the session issues Treasury application requests including `/api/settings`, `/api/settings/smev-info`, `/api/settings/currentversion`, and `/api/users/info`.
8. The parent log contains no `E/GostTLS` or `W/GostTLS` entries and no `handshake failed` record. Some negative read return values are ordinary nonblocking/pending operations (`WSAEWOULDBLOCK`) and are followed by continued successful encrypted I/O; they are not recorded as transport handshake failures.

Cipher suite `0xff85` is `TLS_GOSTR341112_256_WITH_28147_CNT_IMIT`, a GOST TLS 1.2 suite. Therefore this capture establishes an actual negotiated GOST TLS session, not merely selection of the GOST-host branch.

The positive server-verification result is evidence that verification succeeded for these observed sessions. It does **not** by itself close the project's separate fail-closed/negative-path server-verification work.

All six completed handshakes report `client_cert_loaded=0`, consistent with the deliberately empty `R3DFOX_GOST_CLIENT_CERT_THUMBPRINT` / `R3DFOX_GOST_CLIENT_AUTH_MODE` settings. Therefore this experiment does **not** establish client-certificate or mTLS success. Client-auth remains a separate acceptance line.

This second log ends while the parent is still processing socket/compositor activity; it does not itself record the later parent termination seen in the first capture. It therefore neither closes nor contradicts the separate sustained-XP-runtime blocker.

## Conclusion

Two distinct milestones are now established for the tester-attributed build/run identity:

- **PHYSICAL XP FULL-BROWSER RUNTIME MILESTONE UNDER FORCED NON-E10S:** Firefox/r3dfox 153 reaches and uses the Treasury application on physical Windows XP SP3 x86 and advances beyond the earlier battery startup boundary. Sustained/stable XP runtime remains open because the first capture later loses the parent process.
- **PHYSICAL GOST TLS SERVER-AUTH HANDSHAKE PASS UNDER FORCED NON-E10S:** the `GostTLS:5` capture directly proves allowlist selection -> custom MSSPI GOST layer attachment -> successful server verification -> six successful TLS 1.2 handshakes negotiating `0xff85` (`TLS_GOSTR341112_256_WITH_28147_CNT_IMIT`) -> encrypted MSSPI application I/O -> HTTP/Treasury traffic.

Do not generalize either result to default e10s/multiprocess operation. Do not treat this no-client-certificate run as an mTLS/client-auth PASS. Do not treat the positive observed server-verification result as closure of the separate fail-closed negative-path verification work.