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

The full Firefox build, packaging, physical-test runtime archive creation, PE audit and artifact uploads completed successfully; the final aggregate summary gate failed. The runtime result below is independent physical evidence and must not be inferred from the Actions aggregate conclusion.

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

## Launch state

The successful physical XP session used:

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

## Physical runtime observation

The log records parent process `PID 3132` navigating to `https://fzs.roskazna.ru/`, receiving `HTTP/1.1 200 OK`, processing the response through `nsHttpChannel`, writing content to cache, and subsequently loading Treasury application resources and API requests including `/api/settings`, `/api/settings/smev-info`, `/api/settings/currentversion`, and `/api/users/info` plus CSS/JS/favicon traffic.

This is not a window-flash or startup-only observation. It establishes that the exact tester-attributed Firefox/r3dfox 153 artifact can execute a real browser workload on physical Windows XP SP3 x86, render/use a remote HTTPS application, and continue application traffic after initial navigation.

Later, the parent process terminates/disappears and child/auxiliary processes report `OnChannelErrorFromLink`. Therefore **stable/sustained XP acceptance remains OPEN**. The next physical compatibility task is to localize the later parent failure with matching DrWatson/WinDbg/PDB evidence rather than reopening earlier closed blockers without contradictory evidence.

The earlier physical `0xC06D007F` / `USER32!RegisterPowerSettingNotification` startup boundary is necessarily advanced beyond in this exact observed session: the browser reaches rendered remote application traffic. This does not identify the owner of the later termination.

## GOST TLS interpretation

`fzs.roskazna.ru` was explicitly present in `R3DFOX_GOST_HOSTS`, and protected Treasury application traffic was observed under that configured GOST-host selection. This is strong combined physical XP/GOST runtime evidence.

However, this particular `MOZ_LOG` configuration omitted `GostTLS:5`. It therefore does **not** directly record the custom `nsGostSSLIOLayer` MSSPI/SSPI handshake state, negotiated GOST cipher, client-certificate state, or other `GostTLS` telemetry. Do not use this capture alone as strict direct proof of the exact MSSPI/SSPI negotiated-handshake details.

For strict GOST TLS handshake evidence on physical XP, repeat the same successful conditions with `GostTLS:5` added to `MOZ_LOG`, preserving exact binary identity. Ordinary HTTPS and XP browser stability conclusions remain separate from that handshake proof.

## Conclusion

**PHYSICAL XP FULL-BROWSER RUNTIME MILESTONE ESTABLISHED UNDER FORCED NON-E10S.** Firefox/r3dfox 153 from the tester-attributed run `34459906476` lineage reaches and uses the Treasury web application on physical Windows XP SP3 x86. The browser later terminates, so sustained XP runtime remains open. Treasury traffic occurred with the host explicitly selected for the project GOST path, but direct `GostTLS:5` MSSPI/SSPI handshake telemetry is still required for the strict transport-layer GOST handshake proof.
