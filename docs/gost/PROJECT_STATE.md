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

## 2026-09-23 physical XP runtime smoke — PASS for exact local hashes; release-candidate correlation disproven

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

The authoritative CI artifacts from release run `35724604122` were independently inspected. Both package artifact `10700255591` and runtime artifact `10700395290` contain:

- `r3dfox.exe` SHA-1 `adc00ebb4cee4bc9fdd611016433827a695c93a0`;
- `xul.dll` SHA-1 `b7806d06aecdb47b83482666d3a7d59dcd8c5c6a`.

Those hashes do not match the physically tested local pair. The local pair is now user-identified as the later WebRTC/GOST full-build lineage from run `35737946733`, job `106779925555`, source-under-test `afee8c9e5ad2da729407ae06cda8d8029895ab06`; the same pair was again supplied when confirming physical XP startup of that build. Therefore the earlier smoke must not be attributed to clean release source `85863f23...`.

The release-line conclusion remains: **`85863f23...` has build/package/static GREEN evidence, but no hash-correlated physical runtime PASS yet.** The prior provenance ambiguity is resolved in the sense that the tested local pair belongs to a different implementation/WebRTC build lineage; independent artifact-side rehash of the `35737946733` payload against the supplied local SHA-1 pair is still desirable before calling that pair artifact-correlated rather than user-associated.

Detailed release-line evidence remains in `TEST_LOG_2026-09-23_release_runtime_smoke.md`.

## Last artifact-correlated clean-product physical baseline — PASS

The current source/artifact-correlated clean-product physical baseline remains:

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

The physical Page Info smoke on 2026-09-23 also shows that General, Media, Permissions, Security, certificate-viewer and saved-password UI paths remain functional for the exact local hashes recorded above. Those hashes are now associated with the later WebRTC/GOST implementation build, not with release candidate `85863f23...`; this observation therefore remains separate from clean-release acceptance.

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

## Download completion / Windows Recent Documents XP line

The predecessor physical XP build from implementation source `9e692fc9dfb1dd6f8099503e94afe887545cb5bb`, run `35700636148`, job `106657546780`, exposed a stable `0xC06D007F` crash when an ordinary download completed while `browser.download.manager.addToRecentDocs=true`. Matching dump/PDB/PE analysis localized the exact delayed API to `SHELL32.dll!SHCreateItemFromParsingName`, called from `AddToRecentDocs()` in `DownloadPlatform::DownloadDone()`.

On that same predecessor build, setting `browser.download.manager.addToRecentDocs=false` allowed downloads to complete without the crash. This is a useful A/B runtime confirmation of the owner/path, but it is a workaround on the old binary and not proof of the source fix.

The narrow implementation fix is now source `e13354c79ebfa206fbccc946592256d33e4ac519`, containing:

- `2c8dc1dc4696c5efcef0b00da4106ac4170b4de7` — under `MOZ_XP_COMPAT`, skip the AppUserModelID / `SHCreateItemFromParsingName` path and use the existing `SHAddToRecentDocs(SHARD_PATHW, ...)` fallback;
- `e13354c79ebfa206fbccc946592256d33e4ac519` — add `SHCreateItemFromParsingName` to the core-browser XP import regression gate.

Canonical full-build evidence for this exact source is:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `35810132801`, job `107019631325`;
- aggregate result **completed / success / GREEN**;
- package artifact `10733487295`, digest `sha256:cc72661870838b6127e08b5c80f27a91de69ab5725546d5134095d6fb27d2b2c`;
- runtime artifact `10733956483`, digest `sha256:e9edf4fdeb2902592b88332655332f130cf8e914d693fa926b14a4d3dffb45eb`;
- diagnostics artifact `10733113244`, digest `sha256:d47de71f9b51dbcdf2fdaa857dcac8ce6a5edc1b24d96042ed73afdf0ee02013`.

The release build, package creation, runtime archive, core-browser import gate, broad XP PE/direct-import audit, artifact uploads and final summary all passed. Therefore **build/package/static import-regression acceptance is established for the remediation**. Physical closure remains pending: the exact `e13354c...` artifact must complete a normal download on XP with `browser.download.manager.addToRecentDocs=true` and matching local binary hashes.

## WebRTC XP line

The first WebRTC-enabled source `75b4e8f052fb6fc09c723651938fde18f95af4ea`, run `35706851492`, job `106677750169`, built/package GREEN but exposed a physical XP loader blocker from direct `xul.dll -> WS2_32.dll!inet_pton`. Matching diagnostics/PDB localized both references to `nr_str_port_to_transport_addr()` in nICEr.

Source-under-test `afee8c9e5ad2da729407ae06cda8d8029895ab06` applies the narrow XP-only source fallback by copying the proven IPv4/IPv6 parser into the Windows nICEr port while non-XP retains native `inet_pton`. Its canonical full-build experiment is:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `35737946733`, job `106779925555`;
- aggregate result **completed / success / GREEN**;
- package artifact `10707883013`, digest `sha256:3c0c130432521825a4c5961fe5c0f2b390b6a8f70731e32d4a8440477581d995`;
- runtime artifact `10707967905`, digest `sha256:39c55c4b6904a1f1fb5fad1c829da670a356c532e4aeb0ca08068338b7428ac2`;
- diagnostics artifact `10707868191`, digest `sha256:c4f3951d2358c4ef530013bedb3abc8e2d7368a4bdcc1981eb866441f9d136f5`.

The user physically launched this build on Windows XP and confirmed that the previous missing-entry-point dialog for `WS2_32!inet_pton` no longer appears and the browser starts. User-reported local SHA-1 identities for this test are `r3dfox.exe=b1e38de25a5212a54833ddcd4ca830318a10467c` and `xul.dll=266b8baea04e92d301fb6ffdd5ad87f492c398eb`.

Conclusion: **the nICEr `inet_pton` XP loader blocker is physically closed for source `afee8c9e...` and the user-associated run `35737946733` binaries.** This is browser startup/runtime-boundary evidence, not a functional WebRTC PASS: `RTCPeerConnection`, `getUserMedia`, DataChannel, ICE/STUN and real-call behavior remain to be exercised separately.

Later commit `1ba6150ca58ea9da341f53374f9bf5dc8d0a4366` adds `inet_pton` to the broad forbidden direct-import audit. That hardened rule is now build-proven on successor source `e13354c79ebfa206fbccc946592256d33e4ac519`: run `35810132801`, job `107019631325` completed GREEN with both the targeted core-browser import gate and the broad XP PE/direct-import audit successful. This is regression-gate evidence only; it does not add functional WebRTC runtime coverage. Parser deduplication into a neutral shared helper remains deferred until functional WebRTC runtime is established.

# Build-configuration identity

Keep the XP mechanisms distinct:

- C/C++: `CFLAGS/CXXFLAGS += -DMOZ_XP_COMPAT`;
- Rust: `RUSTFLAGS="--cfg moz_xp_compat"`;
- neither implies `CONFIG["MOZ_XP_COMPAT"]` in `moz.build`.

# Current acceptance / next boundary

For the clean release line, no evidence currently overturns the proven physical XP lifecycle of `586fe5f8...`. The newer `85863f23...` release candidate is GREEN through build/package/static gates, but the physical binaries previously assumed to belong to it are now identified as a different WebRTC/GOST implementation lineage. Immediate clean-product acceptance boundary remains physical execution of the exact `10700255591` / `10700395290` release payload with matching hashes.

For the implementation XP line, source `e13354c...` is now GREEN through the canonical full build/package/static gates, including the hardened `inet_pton` rule and the new `SHCreateItemFromParsingName` regression rule. The immediate download-specific acceptance boundary is physical execution of the exact `10733487295` / `10733956483` payload with `browser.download.manager.addToRecentDocs=true`, followed by a normal completed download and exact binary-hash capture. Until that succeeds, the former download-completion `0xC06D007F` blocker is source-remediated and build-proven but not physically closed.

For the WebRTC XP line, the `inet_pton` loader blocker is physically closed on `afee8c9e...`; the hardened import regression rule is now build-proven on successor `e13354c...`. Actual WebRTC API and transport/media runtime testing remains the next functional evidence boundary.

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
