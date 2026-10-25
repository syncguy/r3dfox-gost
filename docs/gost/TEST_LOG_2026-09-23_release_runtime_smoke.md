# r3dfox GOST TLS — 2026-09-23 clean-product XP runtime smoke

Track: Windows XP SP3 x86 compatibility / clean-product browser runtime and ordinary NSS HTTPS UI. Independent of GOST TLS MSSPI/CryptoPro handshake evidence.

## CI context

- workflow `.github/workflows/xp-release-build-x32.yml` / `XP release build x32`;
- Actions run `35724604122`;
- job `106735182867`;
- product source-under-test recorded by the workflow checkout: `win-153-xp` / `85863f2355a23223bf33f55b641ccb509a2b72ac`;
- aggregate CI result: **completed / success / GREEN**;
- package artifact `10700255591` (`r3dfox-xp-x32-package`), digest `sha256:63b97b0e53b31bcb062dbf98d1ebdb67124de76af1bad663911972834c1c2cb2`;
- runtime artifact `10700395290` (`r3dfox-xp-x32-runtime`), digest `sha256:f8dd39d87d304f5e99d02e299a08c278287f18a523f207dd257c53aaa04076b3`;
- diagnostics artifact `10700061102` (`r3dfox-xp-x32-diagnostics`), digest `sha256:ab984ed4662365fdb8fcbba17166edc9ebb362d3ae95d44dd39281c7960eaad0`.

The CI result remains **build/package/static evidence**. Physical runtime acceptance requires exact binary identity and is evaluated separately below.

## User-observed physical Windows XP smoke

The user supplied screenshots from a physical Windows XP browser session and SHA-1 identities for the launched binaries:

- `r3dfox.exe`: `b1e38de25a5212a54833ddcd4ca830318a10467c`;
- `xul.dll`: `266b8baea04e92d301fb6ffdd5ad87f492c398eb`.

Observed behavior for that exact local binary pair:

- the browser is running and usable on Windows XP;
- ChatGPT loads over ordinary HTTPS;
- Page Info opens and the General, Media, Permissions and Security tabs render;
- the Media tab lists page resources and renders the selected OpenAI SVG preview;
- the Permissions tab renders the site-permission matrix, including the source-owned `Create WebGL context` fallback;
- the Security tab reports an encrypted ordinary HTTPS connection using TLS 1.3 / `TLS_AES_128_GCM_SHA256`;
- `View Certificate` opens `about:certificate`; the displayed chain is `chatgpt.com -> WE1 -> GTS Root R4`, with Google Trust Services as issuer;
- `View Saved Passwords` opens `about:logins`; the filtered view is functional and reports no matching saved login for `chatgpt.com`.

Conclusion at the exact-local-binary scope: **PHYSICAL WINDOWS XP RUNTIME / PAGE INFO / CERTIFICATE UI / ORDINARY NSS HTTPS SMOKE PASS.** The previously reproduced Page Info localization path remains functional in this exercised session.

This is **not** GOST TLS MSSPI/CryptoPro handshake evidence. The displayed ChatGPT TLS connection is the ordinary Firefox NSS path.

## Provenance check against the CI artifacts

The downloaded authoritative package and runtime artifacts from run `35724604122` were independently inspected. The browser payloads in package artifact `10700255591` and runtime artifact `10700395290` contain the same binaries:

- artifact `r3dfox.exe` SHA-1: `adc00ebb4cee4bc9fdd611016433827a695c93a0`;
- artifact `xul.dll` SHA-1: `b7806d06aecdb47b83482666d3a7d59dcd8c5c6a`.

Those hashes do **not** match the physically tested local pair `b1e38de2...` / `266b8bae...`.

Therefore the physical smoke is accepted only for the exact user-tested local binaries. It must **not** be promoted to an artifact-correlated physical PASS for source-under-test `85863f2355a23223bf33f55b641ccb509a2b72ac` until provenance is reconciled.

Next discriminating step: either identify the exact build/artifact that produced the local SHA-1 pair, or physically test binaries extracted directly from package artifact `10700255591` / runtime artifact `10700395290` and record their matching hashes before accepting `85863f23...` as the new artifact-correlated physical clean-product baseline.

Status: **physical XP smoke PASS for exact local hashes; run `35724604122` remains GREEN build/package/static; local-binary-to-CI provenance unresolved.**
