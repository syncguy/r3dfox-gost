# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-07_pre_xp_build_34107793132.md`](./TEST_LOG_2026-09-07_pre_xp_build_34107793132.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-07 — XP Build: current ProgramData Shell32 fallback source compiles, packages and passes static gates

Track: Windows XP SP3 x86 compatibility / full Firefox build and static-import validation. This is independent of GOST TLS runtime and does not prove a GOST TLS handshake.

Exact source/build identity:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4` (`fix(xp): use legacy ProgramData shell folder`);
- workflow: `XP Build`;
- Actions run `34107793132`, attempt `1`;
- job `101696721232` (`build-windows-xp`);
- trigger: `workflow_dispatch`;
- aggregate run/job conclusion: **success**.

Change under test:

- under `MOZ_XP_COMPAT`, the ProgramData path avoids the XP-incompatible `SHGetKnownFolderPath(FOLDERID_ProgramData, ...)` path and uses `SHGetFolderPathW(..., CSIDL_COMMON_APPDATA, ...)` instead;
- source commit `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4` changes:
  - `config/external/sqlite3/src/sqlite3.c`;
  - `toolkit/mozapps/update/common/updatedir.cpp`;
- the workflow's pre-build XP compatibility assertions reported the ProgramData Shell32 fallback present in both files.

Exact CI result:

- browser build: **success**;
- build-driver log extraction: **success**;
- package: **success**;
- packaged ZIP verification: **success**;
- Rust CRT import gate: **success**;
- direct XP-ready import diagnostics: **success**;
- hard direct XP-ready import gate: **success**;
- packaged artifact upload: **success**;
- build-driver logs upload: **success**;
- XP compatibility diagnostics upload: **success**.

Evidence artifacts:

- `r3dfox-xp-153.0.en-US.win64.zip`
  - artifact ID `5875778788`;
  - size `150304690` bytes;
  - digest `sha256:d5c51e686d6a59ac0146726234a6d02aec0c20b8e49bf0a8aa66b4864f8c405e`;
- `r3dfox-xp-build-logs`
  - artifact ID `5875778720`;
  - size `1312329` bytes;
  - digest `sha256:85500ade7ffc242edd3e03e2379ec30880874341b66697b6ab18ed883766d9d4`;
- `r3dfox-xp-compat-diagnostics`
  - artifact ID `5875778793`;
  - size `420211156` bytes;
  - digest `sha256:120238721588471833187ca565fff4171587cf3606f4b1c2091b4e7eebcb219b`.

Interpretation: **PASS / CURRENT SOURCE CLUSTER IS BUILD-VALID AT EXACT SHA `cd5e715...`.** The ProgramData Shell32 source mitigation survives the current full build, packaging and hard static import gates, and the workflow produced all required evidence artifacts.

Evidence boundary: this GREEN result does **not** by itself prove Windows XP startup/runtime acceptance. It also proves nothing about the independent NSS/SSPI/CryptoPro GOST TLS handshake path. The exact effect on residual Shell32 delay imports should be read from the successful run's compatibility diagnostics before claiming any specific delay-import edge has disappeared.

Status: **current authoritative build/static validation for source `cd5e715...` / run `34107793132`; physical-XP validation remains separate.**
