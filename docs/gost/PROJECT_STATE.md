# r3dfox GOST TLS — Project State

Last updated: 2026-09-23

This file is the authoritative current technical synthesis and handoff for new chats. Detailed experiment evidence is in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes; closed milestones are in `DONE.md`; pending work is in `TODO.md`; workflow roles are in `WORKFLOWS.md`; the mandatory Windows XP x86 build/dependency contract is in `XP_BUILD_CONTRACT.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default branch and canonical documentation source: `agent/gost-tls-poc`.
- Windows XP SP3 x86 implementation branch: `agent/winrt-source-poc`.
- Current implementation-branch HEAD observed before this documentation update: `e13354c79ebfa206fbccc946592256d33e4ac519` (`test(xp): reject SHCreateItemFromParsingName`).
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the active work branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides otherwise.

## Evidence separation

Keep these tracks independent unless a deliberately combined experiment tests both:

1. GOST TLS runtime / NSS / NSPR / MSSPI / SSPI / CryptoPro / handshake.
2. Windows Vista/7/XP compatibility / Rust / msvcr14x / YY-Thunks / linker / PE imports / physical runtime.
3. Bundled extensions, localization and packaging.

Build success is not physical runtime success. Static PE/import success is not runtime success. Physical browser runtime success is not a GOST TLS handshake. Documentation commits never replace the source-under-test SHA of a binary artifact.

# Clean `win-153-xp` release line

## Latest build/package/static baseline — GREEN

The current clean-product release candidate is:

- source-under-test branch `win-153-xp`;
- source-under-test SHA `85863f2355a23223bf33f55b641ccb509a2b72ac`;
- workflow `.github/workflows/xp-release-build-x32.yml` / `XP release build x32`;
- run `35724604122`;
- job `106735182867`;
- aggregate result **completed / success / GREEN**;
- package artifact `10700255591`, digest `sha256:63b97b0e53b31bcb062dbf98d1ebdb67124de76af1bad663911972834c1c2cb2`;
- runtime artifact `10700395290`, digest `sha256:f8dd39d87d304f5e99d02e299a08c278287f18a523f207dd257c53aaa04076b3`;
- diagnostics artifact `10700061102`, digest `sha256:ab984ed4662365fdb8fcbba17166edc9ebb362d3ae95d44dd39281c7960eaad0`.

The full Firefox/r3dfox XP x86 compile/link, XP compatibility gates, package construction, runtime-archive generation, package-survival checks, broad PE/direct-import audit, artifact uploads and final summary all passed. This is authoritative **build/package/static** evidence for exact product source `85863f23...`.

The source contains the six-file WebGL/stock-language-pack fallback already physically proven on the implementation line.

## 2026-09-23 physical XP runtime smoke — PASS for exact local hashes, CI provenance unresolved

The user physically exercised a Windows XP browser and supplied exact local SHA-1 identities:

- `r3dfox.exe`: `b1e38de25a5212a54833ddcd4ca830318a10467c`;
- `xul.dll`: `266b8baea04e92d301fb6ffdd5ad87f492c398eb`.

For that exact local pair, the physical XP smoke is a **PASS**:

- browser remains usable on XP;
- ChatGPT loads over ordinary Firefox NSS HTTPS;
- Page Info General, Media, Permissions and Security render;
- the Permissions page includes the source-owned `Create WebGL context` fallback;
- certificate viewer opens and displays the `chatgpt.com -> WE1 -> GTS Root R4` chain;
- Page Info reports TLS 1.3 / `TLS_AES_128_GCM_SHA256` for the ordinary HTTPS connection;
- Saved Passwords opens `about:logins` successfully.

The authoritative CI artifacts from run `35724604122` were independently inspected. Both package artifact `10700255591` and runtime artifact `10700395290` contain:

- `r3dfox.exe` SHA-1 `adc00ebb4cee4bc9fdd611016433827a695c93a0`;
- `xul.dll` SHA-1 `b7806d06aecdb47b83482666d3a7d59dcd8c5c6a`.

Those hashes do not match the physically tested local pair. Therefore the strongest valid conclusion is:

**PHYSICAL XP RUNTIME / PAGE INFO / CERTIFICATE UI / ORDINARY NSS HTTPS SMOKE PASS for the exact local hashes, but the local binaries are not yet artifact-correlated to source `85863f23...`.**

Do not promote `85863f23...` to an artifact-correlated physical runtime PASS until provenance is reconciled. Either identify the exact build/artifact that produced the user-tested pair or physically test binaries extracted directly from artifact `10700255591` / `10700395290` and record matching hashes.

Detailed evidence is in `TEST_LOG_2026-09-23_release_runtime_smoke.md`.

## Last artifact-correlated clean-product physical baseline — PASS

Until the provenance gap above is closed, the current source/artifact-correlated clean-product physical baseline remains:

- `win-153-xp @ 586fe5f856971a790db6e3529bdb0ac7a6133872`;
- workflow `XP release build x32`;
- run `35697342392`, job `106647034214`;
- package `10685004306`, runtime `10684874629`, diagnostics `10686043053`;
- build/package/static result **completed / success / GREEN**;
- physical Windows XP startup, new-profile creation, policy-driven uBlock installation, representative page browsing, normal shutdown and orderly termination **PASS**;
- four key runtime binaries were independently hash-correlated to package artifact `10685004306`.

This distinction is intentional: the newer source has the stronger build/static result, while the older source remains the latest clean-product physical result whose local binaries are proven to come from the named CI artifact.

# Localization / packaging

The reproduced Russian-language-pack Page Info/WebGL localization blocker is closed. The source-owned Fluent fallback was physically accepted on implementation source `9e692fc9dfb1dd6f8099503e94afe887545cb5bb`, run `35700636148`, job `106657546780`, and is transferred unchanged into clean-product source `85863f23...`.

The physical Page Info smoke on 2026-09-23 also shows that General, Media, Permissions, Security, certificate-viewer and saved-password UI paths remain functional for the exact local hashes recorded above. Because those local hashes are not yet mapped to the named CI artifact, this observation is runtime evidence for the local binaries and not a new artifact-correlated acceptance of `85863f23...`.

# GOST TLS runtime

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication. Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

Physical Windows XP GOST TLS server-auth proof exists for source `88453be37a7f39f690c504078f6f9434e2547ab6`, workflow run `34459906476`, job `102815008544`, runtime artifact `10150744314`. Under forced non-e10s and an explicit GOST allowlist, the exact browser completed TLS 1.2 MSSPI handshakes with successful server verification and HTTP application traffic.

A later no-preload XP build at source `f7d1df4eebe527f0167b0e805d1c9d9c46eaed5f`, run `35500734933`, job `106051926870`, was also user-observed to run on physical XP with ordinary RSA HTTPS and GOST TLS working. Keep that TLS-runtime evidence independent from the clean-product release line, which contains no GOST TLS/MSSPI source injection.

Open GOST work remains real `Permanent` client-certificate persistence, discovery/provider semantics, deferred deterministic T5 credential invalidation, fail-closed server-trust closure and negative verification tests, remaining mTLS/client-certificate matrix coverage, and the confirmed provider-wait Socket Thread starvation follow-up. See `TODO.md` and Stage 2 documents.

# Windows XP SP3 x86 compatibility

The project has an established physical full-browser lifecycle PASS on the GOST-bearing implementation lineage at source `62835966a1c680382b8ab8a7100b810abccbf2c5`, run `35443499166`, job `105898364295`, with eight key binaries independently matched to package artifact `10587340718`. That closed the earlier GPU-child detach AV as an immediate browser blocker without claiming a global YY/static-TLS lifecycle fix.

The temporary early private-`pwrp_k32.dll` preload is removed from the accepted line; source `f7d1df4e...` proved the narrow failed-`LdrLoadDll` output remediation is sufficient for the exercised physical lifecycle without that ordering workaround.

The XP legacy Windows file-picker fallback is physically accepted on exact source `e9d4a1115d3c97cad8cdeb0aa42c61ee5e9240a8`, focused run `35509299508 / 106074306188`, full-build run `35509338997 / 106074415929`.

The focused YY/static-TLS detach-order reproducer remains forensic evidence only: on exact source `1a61565dd3442d817893c52d473365442e24ba6c`, run `35495864771`, job `106038556671`, `owner-first` passes while `late-first` hangs during teardown. Do not use that focused result as a substitute for browser runtime evidence and do not broaden YY-Thunks from inference.

The active implementation branch has moved beyond the release candidate with additional compatibility work. Do not infer physical acceptance from its current HEAD. Every new runtime claim still requires exact source/artifact/binary identity.

## WebRTC XP line

WebRTC-enabled source `75b4e8f052fb6fc09c723651938fde18f95af4ea` built/package GREEN but exposed a physical XP loader blocker from direct `WS2_32!inet_pton` use in nICEr. Candidate commit `afee8c9e5ad2da729407ae06cda8d8029895ab06` applies the narrow XP-only source fallback by copying the proven parser into the Windows nICEr port. Final build/import/runtime acceptance and later parser deduplication remain separate evidence boundaries.

# Build-configuration identity

Keep the XP mechanisms distinct:

- C/C++: `CFLAGS/CXXFLAGS += -DMOZ_XP_COMPAT`;
- Rust: `RUSTFLAGS="--cfg moz_xp_compat"`;
- neither implies `CONFIG["MOZ_XP_COMPAT"]` in `moz.build`.

# Current acceptance / next boundary

For the clean release line, no evidence currently overturns the proven physical XP lifecycle of `586fe5f8...`. The newer `85863f23...` release candidate is GREEN through build/package/static gates and the WebGL localization patch itself is already proven, but its exact CI binaries have not yet been hash-matched to a physical run.

Immediate clean-product acceptance boundary: **close the binary provenance gap for the 2026-09-23 smoke or run the exact `10700255591` / `10700395290` payload on physical XP.**

Keep later XP compatibility experiments, WebRTC, packaging/localization and GOST TLS runtime as independent evidence lines.

# Global evidence rules

- Build success != physical runtime PASS.
- Physical runtime PASS != GOST handshake PASS.
- Static PE/import PASS != runtime PASS.
- Win7 x86 startup != XP startup.
- Static source/import removal != physical-XP closure until the exact accepted artifact advances past it.
- Documentation HEADs never replace source-under-test SHA.
- A PDB may symbolize only its matching binary from the same build.
- Runtime claims stay bound to exact source SHA + Actions run/job + exact artifact/binary identity.
