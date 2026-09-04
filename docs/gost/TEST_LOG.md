# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-01_pre_bcrypt_closure.md`](./TEST_LOG_2026-09-01_pre_bcrypt_closure.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-03 — first fully GREEN XP x32 full-build workflow; prior three GMP imports closed, two xul quartet imports still diagnostic WARN

Track: Windows XP SP3 x86 compatibility / full Firefox 153 x32 integration only. This is not GOST TLS runtime/handshake evidence and is not physical-Windows-XP runtime proof.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `2b1cf7e1b59881b935c7f695a54edd6b92c8066e` (`ci(xp): add residual YY KERNEL32 providers`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33757305364`, attempt `1`;
- job `100654730312`;
- aggregate run/job conclusion: **success**.

Exact artifacts:

- package artifact `9899302735`, `327770380` bytes, digest `sha256:baeb2aaa2c31599da56c2b1c767bdd969914e034ab2c94826c0dd18db36d394b`;
- runtime artifact `9899304858`, `74919909` bytes, digest `sha256:7d6eff6a4af1b1358f17ed1db9f9194d03702298def5708542a6510aa10029e0`;
- diagnostics artifact `9899307128`, `5945299` bytes, digest `sha256:cb08028e3518d8834b50d50b9b68a98e3166a2c25a0177397214a8dabd6b3132`.

All hard workflow boundaries are GREEN, including:

- pinned msvcr14x XP runtime contract;
- narrow YY XP x86 provider build and all-target-link activation while the full YY `kernel32.lib` remains prohibited;
- Firefox configure/export/security-manager object gate;
- full release Firefox x86 build;
- production core-browser direct-import gate;
- D3DCompiler_47 retarget/package-survival contract;
- staged and packaged msvcr14x CRT contract;
- staged and packaged physically proven `xp-bcrypt-v1` contract;
- runtime-test archive creation;
- final inventory-driven `GATE - Audit XP x32 PE floor and direct imports`;
- package/runtime/diagnostics uploads;
- final `GATE - Summarize XP x32 full build`.

The exact diagnostics show that the previous three broad-audit rows from run `33738262420` are gone: neither `FlsGetValue` nor `TryAcquireSRWLockExclusive` survives in the audited GMP fake/test DLL import dumps. Thus the narrow YY provider transfer for those two residual API names is proven at full-Firefox integration scale, not merely by the earlier focused smoke.

However, GREEN does **not** mean complete XP hard-import closure. The intentionally informational source-remediation quartet diagnostic remains `WARN` and records two surviving hard imports in `xul.dll`:

- `GetApplicationRestartSettings`;
- `GetNamedPipeServerProcessId`.

`RegisterApplicationRestart` and `UnregisterApplicationRestart` are absent from that focused quartet result. The two survivors are also visible in the raw `xul.dll` import dump. They are not currently promoted by the workflow's final forbidden-import hard gate, so the run can be GREEN while this diagnostic debt remains. Do not mark the quartet fully closed on the basis of this run.

Conclusion: **FIRST FULL WORKFLOW GREEN / PREVIOUS THREE GMP IMPORT FINDINGS CLOSED / PHYSICAL XP PENDING / TWO XUL QUARTET IMPORTS STILL OPEN AS DIAGNOSTIC DEBT.** Runtime artifact `9899304858` supersedes `9891437190` as the newest exact physical-Windows-XP startup candidate. The next runtime boundary is physical XP execution of this exact artifact, while the separate source-remediation line must explain and eliminate or deliberately reclassify `GetApplicationRestartSettings` and `GetNamedPipeServerProcessId`. No GOST TLS handshake conclusion follows from this compatibility build.

---

## 2026-09-03 — broad XP x32 import inventory reduced from 69 findings to three test-GMP imports

Track: Windows XP SP3 x86 compatibility / full Firefox 153 x32 integration only. This is not GOST TLS runtime/handshake evidence.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `f602df1b2f3c9b85a4b938a4ea57b07373ac9a95`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33738262420`, attempt `1`;
- job `100593897593`;
- aggregate run/job conclusion: **failure** at final summary after evidence collection.

Exact artifacts:

- package artifact `9891436211`, `327757708` bytes, digest `sha256:277f4584bc95a8b425c640db01d18078cdd9ab307caa33bbc8fc2940457ed362`;
- runtime artifact `9891437190`, `74914750` bytes, digest `sha256:a9f8d9598f431f757fcc63c3796dcc600af48371236cf0586e18f5bd9e323cf3`;
- diagnostics artifact `9891438460`, `5947148` bytes, digest `sha256:a421a0cabbfcb151120842e4525b2296011c2c1bc127808e1cfaf52d0e1f612a`.

Passed boundaries before the aggregate RED:

- full Firefox x86 build — **PASS**;
- production core-browser direct-import gate — **PASS**;
- D3DCompiler_47 retarget/package-survival gates — **PASS**;
- packaged CRT contract — **PASS**;
- packaged `xp-bcrypt-v1` contract — **PASS**;
- package and physical-test runtime archive creation — **PASS**;
- package/runtime/diagnostics uploads — **PASS**.

The final broad all-PE audit is the only diagnostic RED promoted by `GATE - Summarize XP x32 full build`. Its exact `xp-x32-forbidden-direct-imports.txt` contains only three rows:

- `gmp-fake/1.0/fake.dll` -> `FlsGetValue`;
- `gmp-fake/1.0/fake.dll` -> `TryAcquireSRWLockExclusive`;
- `gmp-fakeopenh264/1.0/fakeopenh264.dll` -> `FlsGetValue`.

This is a material reduction from the 69 findings in run `33718674533`. The curated production core-browser gate remains GREEN, so this run does not re-open the previously closed core-browser linker/source-remediation lines. The source-remediation quartet diagnostic is informational/non-blocking and reports two surviving names, `GetApplicationRestartSettings` and `GetNamedPipeServerProcessId`; those do not appear in the authoritative broad forbidden-import file for this run.

Conclusion: **FULL BUILD + PACKAGE + RUNTIME ARCHIVE GREEN; BROAD INVENTORY RED ONLY ON THREE GMP TEST DLL IMPORTS.** The immediate build-side blocker is now classification/removal or exclusion of those GMP test-only PEs from the XP runtime-required closure, while preserving the complete inventory-driven audit. Runtime artifact `9891437190` supersedes `9883135451` as the newest exact physical-Windows-XP startup candidate. No physical-XP startup and no GOST TLS handshake conclusion follows from this CI run.

---

## 2026-09-03 — full XP x32 package dependency closure GREEN; broad distribution import inventory remains RED

Track: Windows XP SP3 x86 compatibility / full Firefox 153 x32 integration only. This is not GOST TLS runtime/handshake evidence.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `4949a16e730cc15fc85b128fd62dac2a27c4d9c5` (`ci(xp): preserve artifacts across diagnostic reds`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33718674533`, attempt `1`;
- job `100533128424`;
- aggregate run/job conclusion: **failure**, intentionally propagated by the final evidence summary after non-fatal diagnostic collection.

Exact artifacts:

- package artifact `9883134667`, `327699666` bytes, digest `sha256:64b9537376b72a9e38728236b666b929e84e9c6895a022a1dd66338b9a645582`;
- runtime artifact `9883135451`, `74911275` bytes, digest `sha256:9a5380bfec2b05a8460f6dfef99c85a1c053e1b31f9f18f101d6a7fc5563127b`;
- diagnostics artifact `9883136547`, `5912540` bytes, digest `sha256:b7fb3503a258d78fec927cd0f81413d5124f6f9b4a61cd27a034ec6092607f1c`.

Passed boundaries before the aggregate RED:

- full Firefox x86 compile/build — **PASS**;
- production core-browser import gate — **PASS**;
- pinned msvcr14x staging — **PASS**;
- legacy `D3DCompiler_47.dll` staging/retarget/package survival — **PASS**;
- exact `xp-bcrypt-v1` staging/package survival — **PASS**;
- `mach package` / portable package production — **PASS**;
- msvcr14x portable-package survival contract — **PASS**;
- physical-test runtime archive creation — **PASS**;
- package, runtime and diagnostics artifact uploads — **PASS**.

The previous CRT packaging blocker is closed. `packaged-crt-contract.txt` accepts `r3dfox-v153.0.3.win32.portable.7z` with matching staged/packaged identities: `ucrtbase.dll` SHA-256 `455fa6bc5ceedd89fc3650a224f96ba4dee0fbcb87e2823c1670a4704b737b2f` and `msvcp140.dll` SHA-256 `a1d6099eea3b7742b86ba44a7be7fc64bf0041a80e67ef7e54641ab283285c19`.

The app-local bcrypt package contract is also closed at automated build/package level. The accepted archive contains the exact physically proven `xp-bcrypt-v1` binary: size `520704`, SHA-1 `ae021f44edc48b03bb4d67cb5773b62bdf60cb67`, SHA-256 `f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`, release asset ID `539647946`.

The aggregate RED is not a compile or packaging failure. The broad all-PE import audit intentionally runs non-fatally so diagnostics and runnable artifacts survive; it produced **69 known post-XP findings** in auxiliary/media/test PEs, and the final summary promoted that diagnostic result to the run-level failure. The residual-three names `InitOnceExecuteOnce`, `GetThreadPreferredUILanguages`, and `QueryFullProcessImageNameA` are absent from that broad forbidden-import report, while the production core-browser gate is GREEN. This advances those three names to full-build/import evidence, but not physical-XP closure.

Conclusion: **FULL BUILD + CRT PACKAGE + BCRYPT PACKAGE + RUNTIME ARCHIVE GREEN; BROAD DISTRIBUTION IMPORT INVENTORY RED.** The immediate compatibility blocker is now classification and closure of the 69 broad-audit findings by shipped/runtime-required versus test-only/non-shipped status. Runtime artifact `9883135451` is the next exact physical-Windows-XP candidate for startup progression beyond the previously observed `KERNEL32!InitOnceExecuteOnce` edge. No GOST TLS handshake conclusion follows from this run.

---

## 2026-09-02 — full XP x32 Firefox build and package pass; portable msvcr14x survival gate remains red

Track: Windows XP SP3 x86 compatibility / full Firefox build and packaging only. This is not GOST TLS runtime/handshake evidence.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `17cdb459ec4f115a209fd50ac225cf867b9f3a2f`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33638897692`, attempt `1`;
- job `100276666021` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- overall run/job conclusion: **failure**, localized after successful build/package to the portable CRT-survival gate.

Passed boundaries before the red flag:

- pinned `msvcr14x` Release x86 build and the focused proven XP runtime-contract gate — **PASS**;
- narrow YY-Thunks XP x86 provider and core-browser linker patching — **PASS**;
- Firefox x86 configure/export prerequisites — **PASS**;
- security-manager SSL target-object compile gate — **PASS**;
- full `Build release r3dfox XP x32` — **PASS**;
- early `GATE - Reject proven core browser XP direct imports` — **PASS**;
- app-local XP CRT staging — **PASS**;
- legacy Firefox XP `D3DCompiler_47.dll` staging, PE retarget and package-survival gates — **PASS**;
- pre-package CRT identity recording — **PASS**;
- `Package XP x32 experiment` / Firefox package production — **PASS**.

The exact staged CRT identity recorded before packaging was:

- `ucrtbase.dll`: SHA-256 `b78cf1cdc5c1bce0716e31352940663128978bc1720f8b1ad015d97eb41e2ac8`, size `992712` bytes;
- `msvcp140.dll`: SHA-256 `d7c77c8ac9dd56f0cd6902010f05297d6ef96a4d0f9a75986914fab7d3b5ad7d`, size `446784` bytes.

Red flag:

- step `GATE - Verify msvcr14x CRT survived portable packaging` — **FAIL**;
- the gate requires exactly one packaged `ucrtbase.dll` and one packaged `msvcp140.dll` matching the pre-package SHA-256 identities above;
- no produced portable package satisfied that exact contract, so the workflow terminated with `No produced portable package contains the exact staged XP CRT runtime.`;
- independent inspection of uploaded package artifact `9855749298` (`r3dfox-gost-xp-x32-package`) confirms that `r3dfox-v153.0.3.win32.zip` contains neither `ucrtbase.dll` nor `msvcp140.dll`;
- diagnostics artifact `9855751471` (`r3dfox-gost-xp-x32-diagnostics`) preserves the pre-package CRT identities and other build evidence.

Because this integrity gate failed, the workflow intentionally skipped the physical-test runtime archive and the final broad `GATE - Audit XP x32 PE floor and direct imports`. Therefore the successful full compile/link/package checkpoint must not be promoted to an authoritative XP runtime package, and the early core-import gate must not be misread as complete post-XP import closure.

Conclusion: **major full-build progress / packaging-contract RED.** The current blocker exposed by this run is no longer Firefox compilation or packaging itself; it is preservation of the already staged and identified app-local msvcr14x runtime across the Mozilla `dist/bin -> mach package -> portable archive` boundary. Do not reopen the Rust/YY synchronization linker work on the basis of this failure alone.

Next experiment: repair portable-package inclusion/survival of the exact staged `ucrtbase.dll` and `msvcp140.dll`, rerun the same full XP x32 lineage, require the CRT-survival gate to pass, then allow the final broad PE/import audit and physical-test runtime archive to execute. Only an exact resulting package tested on physical XP can advance the full-browser runtime milestone.

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