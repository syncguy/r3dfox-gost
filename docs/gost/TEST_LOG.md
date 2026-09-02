# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-01_pre_bcrypt_closure.md`](./TEST_LOG_2026-09-01_pre_bcrypt_closure.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-02 — first full trust-package attempt fails at moz.build ordering before browser build

Track: Firefox/NSS + Windows trust + bundled Russian root CAs + final portable packaging only. This is not GOST TLS MSSPI handshake evidence and not Windows XP/Vista/7 compatibility evidence.

Exact project/build identity:

- branch `agent/trust-integration-poc`;
- source-under-test `b2184aa0c7c95a47a35c7010248953902500daf3`;
- workflow `CryptoPro Mozilla packaging smoke`;
- Actions run `33594665980`;
- job `100135594681` (`Windows x64 / CryptoPro real Firefox packaging / ru + en-US`);
- run/job conclusion: **failure**.

Observed boundary:

- setup, pinned Russian localization source, CryptoPro selection, pagefile setup, MozillaBuild/MSSPI setup, Rust build-std preparation and the Win7 Rust preflight all passed;
- `Configure object directory and verify Rust target and l10n base` failed while processing `r3dfox/moz.build`;
- `mach build` never started;
- the real `dist/bin` CryptoPro/trust-root gate was skipped;
- production `ru` merge, `mach package`, final portable trust-root gate and packaged-browser upload were skipped;
- therefore this run provides **no pass/fail evidence** for root survival in `dist/bin`, final portable packaging, runtime policy precedence, or NSS trust behavior.

Root cause is exact and local to the Mozilla build description. `FINAL_TARGET_FILES.distribution.Certificates` is a `StrictOrderingOnAppendList`; source `b2184aa...` supplied:

```text
certificates/russian_trusted_root_ca_rsa.cer
certificates/russian_trusted_root_ca_gost.cer
```

but lexical order requires GOST before RSA. Configure raised `mozbuild.util.UnsortedError` with expected `certificates/russian_trusted_root_ca_gost.cer` and received `certificates/russian_trusted_root_ca_rsa.cer`.

Repair commit `e7640a8195c6f10d8e909ad620ace74fa08c2c86` swaps only those two staging lines. Its checked diff contains no other source change.

A corrected heavy retry was created from that exact repair source:

- source-under-test `e7640a8195c6f10d8e909ad620ace74fa08c2c86`;
- run `33595966569`;
- job `100139347397`;
- state at handoff: **in progress**.

The later commit `88f7d45c01a8a9a740d4e3d35043ae812a9dd624` removes exactly three unintended heavy-workflow trigger additions and restores the prior trigger policy; it does not change the source already checked out by retry `33595966569` and must not be substituted for `e7640a819...` as that run's source identity.

Conclusion: **FAIL / BUILD-DESCRIPTION HARNESS DEFECT / TRUST PACKAGE VERDICT OPEN.** The failed run does not invalidate the two-root trust design or the green fast trust preflight. The next evidence boundary is the exact corrected retry `33595966569` / `100139347397` / `e7640a819...`; do not mark its build, trust-root, localization or package gates passed until it completes.

---

## 2026-09-02 — repaired final Russian localization Gate D passes the full ru + en-US package workflow

Track: bundled extensions / localization / package behavior only. This is not GOST TLS runtime/handshake evidence and not old-Windows runtime evidence.

Exact project/build identity:

- branch `agent/gost-tls-poc`;
- source-under-test `3e2c32386f373d4693db52b32c05aa2000878def`;
- workflow `CryptoPro Mozilla packaging smoke`;
- Actions run `33520207057`;
- job `99897230730` (`Windows x64 / CryptoPro real Firefox packaging / ru + en-US`);
- run/job conclusion: **success**;
- pinned `firefox-l10n` source SHA remains `4273d99ccdc4a516ec6abd742a272ad1d385ddf4`.

Exact artifacts:

- packaged browser artifact `9812333220` (`r3dfox-cryptopro-mozilla-packaging-ru-en-US`), digest `sha256:c8e62704fcc2cd1b99c78cf6cf90b405b653a9aeba5272d132bcda4eaed5edd8`;
- packaging evidence artifact `9812333789` (`cryptopro-mozilla-packaging-evidence`), digest `sha256:fdcb6a34ed5625532af86413330b5c2d4453be046f3d6419d49d2d45c7a143dc`.

Every relevant localization/package boundary is green in the exact job:

- pinned Russian localization checkout — **PASS**;
- packaging-only Russian UI default — **PASS**;
- full release browser build — **PASS**;
- CryptoPro XPI presence/hash in real `dist/bin` — **PASS**;
- production `ru` merge materialization/content gate — **PASS**;
- `ru + en-US` multi-locale package — **PASS**;
- corrected final Gate D inside the extracted portable archive — **PASS**;
- packaged-browser upload — **PASS**;
- packaging-evidence upload — **PASS**.

The repair commit changes only the final `browser/omni.ja` representative-resource suffix used by Gate D: the packaged path is checked as `browser/browser.ftl` rather than the production-merge-tree shape `browser/browser/browser.ftl`. This is the exact defect characterized by failed predecessor run `33489331410`, job `99796818515`, source `e4f9f775d82ff14a75708e11043211e7259eed9b`.

The successful rerun therefore closes the CI false negative. The full package now proves, under the existing hard checks, that substantive Russian resources survive in both root and browser `omni.ja`, differ from en-US where representative checks require it, Russian is requested by default, and the package declares exact `ru,en-US` multilocale content.

Separately, the user had already manually exercised the packaged browser from predecessor artifact `9798517225` and observed Russian UI out of the box, including localized settings and TLS error UI, and successful switching back to `en-US`. That runtime/UI observation belongs to the predecessor exact artifact and is not reattributed to run `33520207057`; the new source change is a CI gate correction rather than a browser localization-content change.

Conclusion: **PASS / localization package gate CLOSED.** The previous mass-empty-Russian-payload defect and the later Gate D path-shape false negative are both superseded as active blockers. There is no current localization packaging blocker. Any future runtime regression check should be bound to its own exact browser artifact, but another full build is not required merely to re-prove the corrected Gate D on unchanged source.

---

## 2026-09-01 — physically proven single-DLL bcrypt published as reusable raw release asset

Track: Windows XP x86 dependency distribution/integration only. This does not add new bcrypt runtime evidence and is not GOST TLS handshake evidence.

Binary identity remains the already physically proven implementation:

- binary source-under-test `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- source-build workflow run `33513084915`, job `99873297193`;
- runtime artifact `9802703271`;
- `bcrypt.dll` size `520704` bytes;
- SHA-1 `ae021f44edc48b03bb4d67cb5773b62bdf60cb67`;
- SHA-256 `f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`;
- physical Windows XP 5.1.2600 dynamic + linked/IAT PASS already recorded below.

Publication identity is separate from binary source identity:

- publication workflow source `76225fcf95e4e484f0cec30c8e25a235119b0256`;
- publication workflow `Publish proven XP bcrypt release`;
- Actions run `33518189052`;
- job `99890447193`;
- conclusion **success**;
- tag `xp-bcrypt-v1` points directly to binary source-under-test `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- technical prerelease ID `380563342`, title `XP bcrypt primitive v1`;
- raw release asset ID `539647946`, name `bcrypt.dll`, size `520704`, GitHub digest `sha256:f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`.

The publication job passed these boundaries in order: reject an existing tag/release, download exact runtime artifact `9802703271`, verify the exact proven DLL identity, and publish the raw DLL directly as the release asset. The DLL is not wrapped in ZIP/7z. GitHub still exposes its automatic source archives for the tag, but those are unrelated to the binary asset.

The first bootstrap push for the temporary publisher, source `e6b5690e9524cbf40586392a3e402758a769b3ac`, produced run `33518088668` with no jobs because of a workflow YAML validation error. This was publisher-harness failure only. Source `76225fc...` corrected the YAML and publication then passed. The one-shot publisher workflow was removed after success by commit `14e47fe0bed8e6acf0948dca3cdedf7a4c9cdf5b` so it does not remain as a permanent Actions workflow.

Conclusion: **PASS / reusable binary distribution established.** `xp-bcrypt-v1` is now the canonical cross-branch binary input for the selected physically proven bcrypt primitive. Heavy Firefox workflows should consume this release asset, verify exact SHA-256 and size, and stage only `bcrypt.dll`. Actions cache may be layered in front as an accelerator, but cache miss must download the canonical release asset rather than silently rebuilding One-Core. Future bcrypt replacements require a new version/tag and fresh physical-XP proof before superseding `xp-bcrypt-v1`.

---

## 2026-09-01 — single-DLL source-built One-Core bcrypt with embedded mbedTLS passes physical Windows XP through dynamic and linked consumers

Track: Windows XP x86 binary compatibility only. This is not GOST TLS runtime/handshake evidence and does not close the independent SRW/condition-variable or remaining post-XP browser-import work.

Exact project/build identity:

- branch `agent/gost-tls-poc`;
- source-under-test `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- workflow `One-Core bcrypt source XP x86 smoke`;
- Actions run `33513084915`;
- job `99873297193`;
- run/job conclusion: **success**;
- pinned upstream `shorthorn-project/One-Core-API-Source@9eb3c31de9460c1ccce3f6a10c9c4a704f032514`;
- build environment RosBE 2.1.6 i386.

Exact artifacts:

- runtime artifact `9802703271` (`onecore-bcrypt-source-xp-x86-runtime`), digest `sha256:e6ea796ef5f7dfb67e346630cd6432c9659e6d90d39ce90b8f44a1b3632edc8f`;
- diagnostics artifact `9802704126` (`onecore-bcrypt-source-xp-x86-diagnostics`), digest `sha256:d989ce72af60185cb16b0ff99d156ed39170beab00055e776b881ee2cc54e6de`.

Architecture proven by the CI build:

- the pinned active mbedTLS C modules are compiled directly as private sources of `bcrypt.dll`;
- `bcrypt.dll` no longer links/imports the separate `mbedtls` DLL target;
- embedded mbedTLS sources receive `-U__WINESRC__` so their compile semantics match the previously successful standalone mbedTLS target, while `bcrypt_main.c` keeps its normal bcrypt/Wine compile context;
- no bcrypt or mbedTLS C implementation source is patched;
- final `bcrypt.dll` passes the current XP PE/import gate, does not import `mbedtls.dll`, preserves the required BCrypt exports, and passes the exact-local hosted dynamic exports/RNG/SHA-256 probe.

Physical machine evidence supplied by the user:

```text
Microsoft Windows XP [Version 5.1.2600]
```

The extracted runtime directory contains exactly five files and only one DLL:

```text
bcrypt-source-dynamic.exe   4,096 bytes
bcrypt-source-linked.exe    4,096 bytes
bcrypt.dll                520,704 bytes
README-XP.md                1,147 bytes
run-on-xp.cmd                 303 bytes
```

There is no `mbedtls.dll` in the runtime directory.

Physical XP execution of `run-on-xp.cmd`:

```text
=== One-Core source-built embedded-mbedtls bcrypt dynamic probe ===
LOAD PASS
MODULE PATH: D:\2026\09\01\onecore-bcrypt-source-xp-x86-runtime\bcrypt.dll
EXPORTS PASS
RNG PASS
SHA256 PASS
DynamicExitCode=0

=== One-Core source-built embedded-mbedtls bcrypt linked probe ===
LOAD PASS
MODULE PATH: D:\2026\09\01\onecore-bcrypt-source-xp-x86-runtime\bcrypt.dll
EXPORTS PASS
RNG PASS
SHA256 PASS
LinkedExitCode=0
```

Physical-file identity additionally recorded by the user:

- `bcrypt.dll` size: `520704` bytes;
- SHA-1: `ae021f44edc48b03bb4d67cb5773b62bdf60cb67`.

Conclusion: **PASS / SELECTED / CLOSED at focused dependency-runtime level.** The exact single-DLL artifact from run `33513084915` is physically proven on Windows XP SP3 x86. Both explicit dynamic loading and normal linked/IAT resolution load the same app-local `bcrypt.dll`; required exports, RNG and SHA-256 work; no separate `mbedtls.dll` is required at runtime.

This single-DLL implementation supersedes the earlier physically proven two-DLL `bcrypt.dll + mbedtls.dll` closure from source `fdd4d4dac5a7d9611ec71975ae800437f45c47dd`, run `33493625367`, job `99810642354` as the selected implementation for Firefox integration. The two-DLL result remains valid historical baseline/fallback evidence and must not be confused with the selected one-DLL contract.

Next boundary: integrate the exact single-DLL source/build/provenance contract into the full XP x32 Firefox build/package, require PE/import and package-survival gates, and bind the resulting exact browser artifact to physical-XP startup/browsing. Full Firefox startup and the independent synchronization/remaining post-XP import work are not closed by this focused dependency result.

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

Conclusion at that time: **CI PASS / preferred single-DLL candidate / PHYSICAL XP PENDING.** This status is now superseded by the physical-XP PASS recorded immediately above for the same exact artifact.

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

Conclusion: **PASS / CLOSED at focused dependency-runtime level / SUPERSEDED AS SELECTED IMPLEMENTATION.** The source-built One-Core `bcrypt.dll + mbedtls.dll` closure is physically proven on Windows XP SP3 x86 through both explicit dynamic loading and normal loader/IAT resolution. It remains valid historical fallback/baseline evidence, but the later physically proven single-DLL embedded-mbedTLS implementation from run `33513084915` is now selected for Firefox integration.

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
