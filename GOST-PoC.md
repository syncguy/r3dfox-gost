# r3dfox GOST TLS PoC

Target branch: `agent/gost-tls-poc` (based on r3dfox `win-153`).

## Goal

Use the existing Firefox/Necko TLS socket-provider path, but dispatch explicitly allowlisted HTTPS hosts to an MSSPI-backed NSPR I/O layer. Ordinary HTTPS continues to use NSS unchanged.

```text
HTTPS
  |
nsSSLSocketProvider
  |
  +-- ordinary host ------------------> NSS
  |
  +-- R3DFOX_GOST_HOSTS match
          |
      nsGostSSLIOLayer
          |
        MSSPI
          |
   Windows Security.dll / SSPI
          |
     CryptoPro CSP
```

## Phase 1 limits

- Windows only.
- TLS 1.2 forced for the first browser experiment.
- HTTP/1.1 only; ALPN is intentionally ignored.
- Server authentication only.
- No client certificate/container selection yet.
- No automatic NSS -> MSSPI fallback/detection yet.
- No certificate import into Firefox security UI yet.

## First runtime test

On Windows 7 with CryptoPro CSP installed:

```cmd
set R3DFOX_GOST_HOSTS=fzs.roskazna.ru
set MOZ_LOG=GostTLS:5
r3dfox.exe
```

Then open:

```text
https://fzs.roskazna.ru/
```

Expected log markers:

```text
attached MSSPI GOST layer host=fzs.roskazna.ru port=443 TLS=1.2
handshake complete host=fzs.roskazna.ru cipher=0xff85 tls=0x0303
```

## MSSPI input

CI uses the tested upstream revision:

```text
deemru/msspi
f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232
```

The uploaded/tested local MSSPI differs in the VC12 `USE_BOOST` guard by adding `!defined(_MSC_VER)`. CI applies that exact one-line delta before compilation.
