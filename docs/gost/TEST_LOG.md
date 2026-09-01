# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-01_pre_bcrypt_closure.md`](./TEST_LOG_2026-09-01_pre_bcrypt_closure.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-01 — source-built One-Core bcrypt closure passes CI and physical Windows XP through dynamic and linked consumers

Track: Windows XP x86 binary compatibility only. This is not GOST TLS runtime/handshake evidence and does not close the independent SRW/condition-variable or remaining post-XP browser-import work.

Exact project identity:

- branch `agent/gost-tls-poc`;
- source-under-test `fdd4d4dac5a7d9611ec71975ae800437f45c47dd`;
- workflow `One-Core bcrypt source XP x86 smoke`;
- Actions run `33493625367`;
- job `99810642354`;
- run/job conclusion: **success**.

Pinned upstream source/build identity:

- repository `shorthorn-project/One-Core-API-Source`;
- pinned upstream source commit `9eb3c31de9460c1ccce3f6a10c9c4a704f032514`;
- source components `dll/win32/bcrypt` and `dll/3rdparty/mbedtls`;
- build environment RosBE 2.1.6 i386;
- the smoke applies one documented one-line correction to an unrelated pinned WIDL host-tool signature mismatch; `bcrypt` and `mbedtls` implementation sources remain unmodified.

Artifacts:

- runtime artifact `9794971087` (`onecore-bcrypt-source-xp-x86-runtime`), digest `sha256:03627eb494b604d3a84a9473cad8c0928b13ec458c20cee9e63bfc0ca10d75f1`;
- diagnostics artifact `9794971830` (`onecore-bcrypt-source-xp-x86-diagnostics`), digest `sha256:832563a5618d52f061fcc55efea463e618b4212aea12236ef7bf015cd39e93fe`.

Focused closure:

`bcrypt.dll -> mbedtls.dll -> XP-era system DLLs`.

The runtime artifact carries two independent consumers:

1. `bcrypt-source-dynamic.exe`: no static bcrypt import; exact local `LoadLibraryW(.\\bcrypt.dll)` and `GetProcAddress` path.
2. `bcrypt-source-linked.exe`: ordinary PE/IAT import of `bcrypt.dll`.

Both consumers exercise the required BCrypt export surface, `BCryptGenRandom`, and SHA-256(`abc`). The CI run passes the PE/import gates and hosted exact-local execution for the complete source-built closure.

Physical Windows XP SP3 x86 result supplied by the user for the exact runtime bundle:

```text
=== One-Core source-built bcrypt + mbedtls dynamic probe ===
LOAD PASS
MODULE PATH: D:\2026\09\01\onecore-bcrypt-source-xp-x86-runtime\bcrypt.dll
EXPORTS PASS
RNG PASS
SHA256 PASS
DynamicExitCode=0

=== One-Core source-built bcrypt + mbedtls linked probe ===
LOAD PASS
MODULE PATH: D:\2026\09\01\onecore-bcrypt-source-xp-x86-runtime\bcrypt.dll
EXPORTS PASS
RNG PASS
SHA256 PASS
LinkedExitCode=0
```

Conclusion: **PASS / CLOSED at focused dependency-runtime level.** The source-built One-Core `bcrypt.dll + mbedtls.dll` closure is physically proven on Windows XP SP3 x86 through both explicit dynamic loading and normal loader/IAT resolution. This supersedes the earlier prebuilt One-Core bcrypt implementation as the selected implementation for transfer into the full XP browser workflow.

Next boundary: integrate this proven source-built closure into the full XP x32 Firefox build/package with provenance, import and package-survival gates. Full Firefox startup remains separately blocked by the surviving synchronization/other post-XP imports until those are removed and the exact browser artifact passes physical XP.
