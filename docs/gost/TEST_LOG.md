# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-01_pre_bcrypt_closure.md`](./TEST_LOG_2026-09-01_pre_bcrypt_closure.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-01 — single-DLL source-built One-Core bcrypt with embedded mbedTLS passes CI; physical XP confirmation pending

Track: Windows XP x86 binary compatibility only. This is not GOST TLS runtime/handshake evidence and does not close the independent SRW/condition-variable or remaining post-XP browser-import work.

Exact project identity:

- branch `agent/gost-tls-poc`;
- source-under-test `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- workflow `One-Core bcrypt source XP x86 smoke`;
- Actions run `33513084915`;
- job `99873297193`;
- run/job conclusion: **success**.

Pinned upstream source/build identity:

- repository `shorthorn-project/One-Core-API-Source`;
- pinned upstream source commit `9eb3c31de9460c1ccce3f6a10c9c4a704f032514`;
- build environment RosBE 2.1.6 i386;
- successful two-DLL physical-XP baseline remains project source `fdd4d4dac5a7d9611ec71975ae800437f45c47dd`, run `33493625367`, job `99810642354`;
- the smoke keeps the same one-line unrelated WIDL host-tool correction as the proven baseline;
- `bcrypt` and mbedTLS C implementations remain unmodified; the experiment changes only build composition/compile context.

Architecture under test:

- the pinned active mbedTLS C modules are compiled directly as private sources of `bcrypt.dll`;
- the `mbedtls` import-library dependency is removed from the bcrypt target;
- the embedded mbedTLS source files receive `-U__WINESRC__` so they retain the compile semantics of the previously successful standalone mbedTLS target while `bcrypt_main.c` keeps its normal bcrypt/Wine compile context;
- runtime goal is a single deployable DLL: `bcrypt.dll` with no runtime `mbedtls.dll` dependency.

The previous run `33511801331`, job `99869030264`, source `ef0050d5ded758acae1694a0e1b619830f440d37`, reached real compilation but failed in embedded `entropy_poll.c` because the mbedTLS sources inherited bcrypt's `__WINESRC__`, causing ReactOS/Wine headers to prohibit unsuffixed `CryptAcquireContext`. The source-under-test `a30a701...` corrects only that compile-context mismatch.

Observed CI result:

- all embedded mbedTLS C objects compile successfully inside the bcrypt target;
- final link completes as `dll\\win32\\bcrypt\\bcrypt.dll`;
- the PE/import gate passes, including the explicit requirement that final `bcrypt.dll` does **not** import `mbedtls.dll` and contains no currently gated forbidden post-XP hard imports;
- required BCrypt exports remain present;
- exact-local dynamic consumer loads the staged local DLL and passes:

```text
LOAD PASS
MODULE PATH: D:\\a\\r3dfox-gost\\r3dfox-gost\\artifacts\\onecore-bcrypt-source-xp-x86\\runtime\\bcrypt.dll
EXPORTS PASS
RNG PASS
SHA256 PASS
```

- the linked consumer also passes exports/RNG/SHA256 on hosted Windows Server 2022, but its module path is `C:\\Windows\\System32\\bcrypt.dll`; therefore that hosted linked result is affected by Windows KnownDLL resolution and is **not** proof that the linked consumer executed the staged local bcrypt on the hosted runner.

Artifacts:

- runtime artifact `9802703271` (`onecore-bcrypt-source-xp-x86-runtime`), digest `sha256:e6ea796ef5f7dfb67e346630cd6432c9659e6d90d39ce90b8f44a1b3632edc8f`;
- diagnostics artifact `9802704126` (`onecore-bcrypt-source-xp-x86-diagnostics`), digest `sha256:d989ce72af60185cb16b0ff99d156ed39170beab00055e776b881ee2cc54e6de`.

Conclusion: **CI PASS / preferred single-DLL candidate / PHYSICAL XP PENDING.** The experiment proves that the One-Core bcrypt implementation can be built as one `bcrypt.dll` with the mbedTLS C implementation embedded and without a runtime `mbedtls.dll` dependency, while retaining the required BCrypt ABI and passing exact-local hosted dynamic RNG/SHA-256 execution. It does not yet supersede the physically proven two-DLL closure from run `33493625367` because the exact new runtime artifact has not yet been executed on Windows XP through both dynamic and linked consumers.

Next experiment: extract runtime artifact `9802703271` unchanged on physical Windows XP SP3 x86, run `run-on-xp.cmd`, require both consumers to report the local artifact path plus `EXPORTS PASS`, `RNG PASS`, `SHA256 PASS` and exit code `0`. If that succeeds, adopt the single-DLL closure as the selected bcrypt contract for transfer into the full XP x32 Firefox package and demote the two-DLL `bcrypt.dll + mbedtls.dll` closure to historical fallback/baseline evidence.

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

---

## 2026-09-01 — full ru + en-US package is substantively localized; Gate D fails on a path-shape assertion

Track: bundled extensions / localization / package behavior only. This is not GOST TLS runtime/handshake evidence and not old-Windows runtime evidence.

Exact project identity:

- branch `agent/gost-tls-poc`;
- source-under-test `e4f9f775d82ff14a75708e11043211e7259eed9b`;
- documentation HEAD observed after the run: `3ca8f1ff3ad33c8957b3757a2efffad80733d112`;
- workflow `CryptoPro Mozilla packaging smoke`;
- Actions run `33489331410`;
- job `99796818515`;
- run/job conclusion: **failure** at final Gate D only.

Pinned localization identity:

- `firefox-l10n` source SHA `4273d99ccdc4a516ec6abd742a272ad1d385ddf4`.

Passed boundaries before the failure:

- pinned Russian localization checkout and packaging-only Russian UI default;
- full release build;
- CryptoPro XPI presence/hash gate in real `dist/bin`;
- production `ru` merge materialization/content gate;
- `ru + en-US` multi-locale packaging.

Production merge evidence is substantive, not placeholder localization:

- `217` Russian FTL files, `216` non-empty, `1` zero-length, `215` containing Cyrillic;
- representative `browser.ftl`, `preferences.ftl`, and `netError.ftl` are non-empty and contain Cyrillic;
- immediately before packaging, root staging has `99` FTL (`98` non-empty) and browser staging has `129` FTL (`129` non-empty).

The uploaded final browser artifact `9798517225` was independently inspected after the failed job. The final package contains both `omni.ja` files and the expected CryptoPro XPI. Its localization payload is also substantive:

- browser `omni.ja`: `129` RU FTL, `0` zero-length, `118` containing Cyrillic; `preferences.ftl` is substantive and differs from en-US;
- root `omni.ja`: `99` RU FTL, `1` zero-length, `96` containing Cyrillic; `netError.ftl` is substantive and differs from en-US;
- `defaults/pref/r3dfox-bundle.js` requests `ru` by default;
- `res/multilocale.txt` contains exact `ru,en-US`.

Root cause of the red Gate D is the gate predicate, not missing Russian UI content. In the production merge tree the representative browser resource is under `browser/browser/browser.ftl`, but in final `browser/omni.ja` it is normalized to `localization/ru/browser/browser.ftl`. Gate D still searches for a suffix `browser/browser/browser.ftl`; therefore it does not count the real packaged `browser.ftl` and reaches the assertion `Final browser omni missing substantive Russian browser/preferences resources` even though the file is present, non-empty and Cyrillic.

Conclusion: **LOCALIZATION PACKAGE CONTENT PASS / CI GATE FALSE NEGATIVE.** This run supersedes the previous working hypothesis that the full-package blocker is zero-length Russian Fluent content in final `omni.ja`. For source `e4f9f775d82ff14a75708e11043211e7259eed9b`, substantive Russian resources survive into both final root and browser `omni.ja`; the remaining immediate blocker is a path-shape bug in Gate D itself.

Next experiment: correct Gate D to validate the actual final `omni.ja` path `localization/ru/browser/browser.ftl` (while retaining the existing zero-length/Cyrillic/en-US-difference, Russian-default and `ru,en-US` checks), rerun the same full packaging workflow from the new exact source SHA, and only after that green package gate perform a clean-profile runtime Russian-UI verification. Do not infer any GOST TLS result from this packaging run.
