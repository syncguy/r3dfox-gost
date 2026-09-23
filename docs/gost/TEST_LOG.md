# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-23_pre_download_recent_docs_green.md`](./TEST_LOG_2026-09-23_pre_download_recent_docs_green.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-23 — XP download/recent-documents remediation full build and physical runtime PASS

Track: Windows XP SP3 x86 compatibility / download completion / Windows Recent Documents integration. Independent of WebRTC functional runtime and GOST TLS handshake evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test / Actions head SHA `e13354c79ebfa206fbccc946592256d33e4ac519`;
- functional remediation commit `2c8dc1dc4696c5efcef0b00da4106ac4170b4de7` (`fix(xp): use legacy recent-documents path`);
- regression-gate commit `e13354c79ebfa206fbccc946592256d33e4ac519` (`test(xp): reject SHCreateItemFromParsingName`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `35810132801`;
- job `107019631325` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / success / GREEN**.

Artifacts bound to exact source-under-test `e13354c...`:

- package artifact `10733487295` (`r3dfox-gost-xp-x32-package`), digest `sha256:cc72661870838b6127e08b5c80f27a91de69ab5725546d5134095d6fb27d2b2c`;
- physical-test runtime artifact `10733956483` (`r3dfox-gost-xp-x32-runtime`), digest `sha256:e9edf4fdeb2902592b88332655332f130cf8e914d693fa926b14a4d3dffb45eb`;
- diagnostics artifact `10733113244` (`r3dfox-gost-xp-x32-diagnostics`), digest `sha256:d47de71f9b51dbcdf2fdaa857dcac8ce6a5edc1b24d96042ed73afdf0ee02013`.

The predecessor physical XP build from source `9e692fc9dfb1dd6f8099503e94afe887545cb5bb`, run `35700636148`, job `106657546780`, had a stable download-completion `0xC06D007F` boundary. Matching dump/PDB/PE evidence localized the delayed call to `SHELL32.dll!SHCreateItemFromParsingName` from `AddToRecentDocs()` inside `DownloadPlatform::DownloadDone()`. The same physical predecessor build completed downloads without the crash when `browser.download.manager.addToRecentDocs=false`, which is an A/B runtime confirmation of that owner/path but not a source-level fix.

Source `e13354c...` applies the narrow XP remediation: under `MOZ_XP_COMPAT`, the modern AppUserModelID / `SHCreateItemFromParsingName` branch is not compiled and `AddToRecentDocs()` falls through to the existing legacy `SHAddToRecentDocs(SHARD_PATHW, ...)` path. Non-XP Windows retains the existing modern path.

The same source also adds `SHCreateItemFromParsingName` to `.github/scripts/xp/reject-core-browser-xp-direct-imports.ps1`. In run `35810132801`, both `GATE - Reject proven core browser XP direct imports` and the broad `GATE - Audit XP x32 PE floor and direct imports` completed successfully. The release build, packaging, runtime archive creation, package-survival checks, artifact uploads and final summary also passed.

Physical Windows XP validation of the exact successor runtime is now complete with `browser.download.manager.addToRecentDocs=true`. The user completed an ordinary download without an error or browser crash. User-recorded SHA-1 identities are:

- `r3dfox.exe`: `3f4f98bb9ad710bda5c72fa25d1e124d37c211b4`;
- `xul.dll`: `17ee19d4a947466b25d95089a967f7d055261c2b`.

The runtime artifact `10733956483` was independently downloaded and unpacked; its `r3dfox.exe` and `xul.dll` SHA-1 values match the user's physical binaries exactly. This binds the physical PASS directly to source-under-test `e13354c...` and run `35810132801`, rather than relying only on user association.

Conclusion: **DOWNLOAD / WINDOWS RECENT DOCUMENTS XP BLOCKER PHYSICALLY CLOSED.** Exact source `e13354c...` has full build/package/static import-regression PASS and an artifact-correlated physical Windows XP download-completion PASS with `browser.download.manager.addToRecentDocs=true`. The predecessor `0xC06D007F` / `SHELL32!SHCreateItemFromParsingName` boundary did not recur in the exercised path.

Evidence boundary: this closes the reproduced download/recent-documents blocker only. It does not add WebRTC functional-runtime evidence or GOST TLS handshake evidence.

Status: **completed / build+package+static GREEN / artifact-correlated physical XP download-completion PASS.**
