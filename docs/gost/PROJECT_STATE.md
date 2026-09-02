# r3dfox GOST TLS — Project State

Last updated: 2026-09-02

This file is the authoritative current technical synthesis. Detailed evidence belongs in `TEST_LOG.md` and immutable dated `TEST_LOG_*.md` volumes; forward work is in `TODO.md`; formally closed milestones are in `DONE.md`; workflow roles are in `WORKFLOWS.md`; the mandatory Windows XP x86 dependency/build contract is in `XP_BUILD_CONTRACT.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default / active branch: `agent/gost-tls-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the working branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer maintained r3dfox baseline.

## Track separation

Keep these conclusions independent unless a deliberately combined experiment tests both:

1. GOST TLS runtime / MSSPI / SSPI / CryptoPro / handshake.
2. Windows Vista/7/XP binary compatibility / toolchain / PE imports / runtime closure.
3. Bundled government-system extensions and localization/package behavior.
4. Firefox/NSS + Windows trust + bundled Russian root CAs / final portable package.

Build success does not prove GOST TLS. A focused dependency runtime pass does not prove full Firefox startup. Packaging success does not prove runtime discovery or network behavior. Trust preflight/package success does not prove MSSPI server verification or old-Windows compatibility.

# GOST TLS runtime

## Architecture

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication.

Current core constraints:

- allowlist: `R3DFOX_GOST_HOSTS`;
- TLS 1.2 / HTTP/1.1 PoC path;
- default GOST ciphers: `C100:C101:C102:FF85:0081`;
- coordinated Firefox client-auth picker is default;
- `R3DFOX_GOST_CLIENT_AUTH_MODE=legacy` remains a same-binary diagnostic fallback;
- explicit local certificate selector remains diagnostic only;
- `Session` is the picker default;
- explicit `Once` uses the positive-only 5-second idle fanout lease;
- explicit Cancel is attempt-local and is not stored as reusable negative state;
- an unanswered picker abandoned by tab/load teardown remains unresolved phase 0 and is removed by lifecycle cleanup;
- candidate discovery from `CurrentUser\MY` is distinct from live private-key/provider availability;
- a provider refusal before first key acquisition fails only the current MSSPI attempt with `SEC_E_NO_CREDENTIALS`; a positive Session decision survives and can recover after the medium returns;
- removing the key medium after a credential has already been acquired may not invalidate that live provider context;
- synchronous CryptoPro/provider access currently runs on the shared Firefox Socket Thread; T9 measured a `74.742 s` provider wait during which unrelated network work queued while browser UI remained responsive;
- current source still routes every non-`Once` positive choice through the same process-local remember store, so true persistent `Permanent` semantics remain unimplemented/unproven.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

## Current authoritative GOST runtime browser

- source-under-test `afbdad307f63e594d3715169d6e34235280dddaf`;
- short SSL compile run `33073577249`, job `98521835147`, success;
- authoritative main full build run `33073577269`, job `98521835354`, success;
- release artifact `9652941006`;
- `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`;
- `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`.

Every new GOST runtime conclusion must pass the exact binary/environment/profile preflight in `STAGE2_RUNTIME_TEST_PLAN.md`.

## Closed runtime milestones

The following are closed on their recorded exact artifacts; do not repeat them on unchanged source merely for confirmation:

- basic Treasury GOST HTTPS/application traffic;
- explicit-selector Treasury mTLS;
- coordinated client-auth F1 lifecycle;
- positive `Once` fanout/post-expiry scope;
- generic GIS GMP mTLS scope and cross-host decision isolation;
- positive `Session` same-process lifetime and restart boundary;
- Session-default SD1-SD6 regression;
- T3 explicit Cancel/no-certificate semantics;
- T4 involuntary tab/load Abort semantics;
- T7/T8 missing-medium/provider recovery;
- T9 long provider wait characterization;
- T10 detailed Russian picker presentation.

Exact evidence is in `DONE.md` and the test logs.

## Current GOST runtime blockers / next work

1. **T6 — real Permanent semantics.** Implement persistence distinct from the current in-memory non-Once store and prove process-restart/forget/change behavior.
2. **T11/T12 — discovery boundary.** Verify dynamic `CurrentUser\MY` re-enumeration and provider/removable-media-only discovery behavior.
3. **Provider-wait concurrency follow-up.** Compare T9 with stock Firefox token/PIN/client-certificate behavior before deciding whether MSSPI/provider access should move off the shared Socket Thread.
4. **T5 remains deferred.** Post-login medium removal is not a valid fault injection because an already-acquired provider credential can remain usable.
5. Continue candidate-policy/negative-path matrix.
6. Complete mandatory fail-closed server trust.

## Mandatory server-trust closure — OPEN

Final production behavior must:

- reject `verifyOk == 0`;
- reject any nonzero verification status;
- integrate Firefox temporary/permanent certificate overrides;
- use positive browser-session verification cache keyed by exact server identity;
- prove valid Treasury hostname/chain succeeds;
- prove wrong hostname and invalid/untrusted chain fail closed;
- prove client private-key operations cannot occur before server trust.

Do not use a production verification bypass.

# Windows XP / legacy Windows compatibility

This track is independent of GOST TLS handshake evidence.

## Mandatory XP x86 build contract

Authoritative rules are in `XP_BUILD_CONTRACT.md`.

Physically proven CRT/Rust/YY reference remains:

- source `b19ba4ff3eebd2f323743d92110241fc9d4ce399`;
- run `33387080767`, job `99472017220`;
- runtime artifact `9756275917`;
- exact runtime bundle executed successfully on physical Windows XP.

The ten-API synchronization capability smoke is also green at representative-link scale:

- source `d65b464c74caadace97995f07a4919363c41a0ea`;
- run `33470957048`, job `99740439208`;
- runtime artifact `9786702687`;
- covered APIs: `AcquireSRWLockExclusive`, `AcquireSRWLockShared`, `ReleaseSRWLockExclusive`, `ReleaseSRWLockShared`, `InitializeSRWLock`, `InitializeConditionVariable`, `SleepConditionVariableCS`, `SleepConditionVariableSRW`, `WakeAllConditionVariable`, `WakeConditionVariable`.

This is capability proof only; full Firefox link consumption remains a separate gate.

## Source-built One-Core bcrypt closure — SINGLE-DLL / PHYSICALLY PROVEN / SELECTED

The stock-XP missing `bcrypt.dll` boundary is closed at focused dependency/runtime level.

Selected implementation:

- project source-under-test `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- workflow `One-Core bcrypt source XP x86 smoke`;
- run `33513084915`, job `99873297193`, success;
- pinned upstream source `shorthorn-project/One-Core-API-Source@9eb3c31de9460c1ccce3f6a10c9c4a704f032514`;
- build environment RosBE 2.1.6 i386;
- runtime artifact `9802703271`, digest `sha256:e6ea796ef5f7dfb67e346630cd6432c9659e6d90d39ce90b8f44a1b3632edc8f`;
- diagnostics artifact `9802704126`, digest `sha256:d989ce72af60185cb16b0ff99d156ed39170beab00055e776b881ee2cc54e6de`.

The pinned active mbedTLS C modules are compiled directly into `bcrypt.dll`; the separate runtime `mbedtls.dll` dependency is removed. Embedded mbedTLS sources use `-U__WINESRC__` to preserve the compile semantics of the previously successful standalone mbedTLS target, while `bcrypt_main.c` remains in its normal bcrypt/Wine context. The bcrypt and mbedTLS C implementation sources themselves remain unmodified.

CI proves that the final single `bcrypt.dll` links, does not import `mbedtls.dll`, passes the current XP forbidden-import gate, retains the required BCrypt exports, and passes exact-local hosted dynamic exports/RNG/SHA-256 execution against the staged local DLL.

Physical Windows XP SP3 x86 (`Microsoft Windows XP [Version 5.1.2600]`) now closes the runtime boundary for the exact artifact. The extracted runtime directory contains exactly five files and only one DLL, `bcrypt.dll` (`520704` bytes); there is no `mbedtls.dll`. Both independent consumers load the same app-local path `D:\2026\09\01\onecore-bcrypt-source-xp-x86-runtime\bcrypt.dll` and report `EXPORTS PASS`, `RNG PASS`, `SHA256 PASS`, with `DynamicExitCode=0` and `LinkedExitCode=0`. User-recorded SHA-1 for the proven `bcrypt.dll` is `ae021f44edc48b03bb4d67cb5773b62bdf60cb67`; SHA-256 is `f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`.

Therefore the selected focused runtime closure is one deployable app-local DLL:

`bcrypt.dll -> XP-era system DLLs`

with the required mbedTLS implementation embedded into the DLL itself.

The exact proven DLL is now also published for cross-branch reuse as technical prerelease/tag `xp-bcrypt-v1` in this repository. The tag points directly to source-under-test `a30a701...`; release ID `380563342` contains one raw asset `bcrypt.dll` (asset ID `539647946`, size `520704`, digest `sha256:f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`). Publication workflow run `33518189052`, job `99890447193`, source `76225fcf95e4e484f0cec30c8e25a235119b0256` passed download, exact binary verification and raw asset publication. This publisher SHA is infrastructure identity only and is not the binary source-under-test.

For heavy Firefox builds, this Release asset is the canonical reusable input. An Actions cache may accelerate access, but cache miss must fall back to downloading `xp-bcrypt-v1` and verifying exact SHA-256/size; heavy workflows must not silently rebuild One-Core. Stage only `bcrypt.dll` and retain PE/import/package-survival gates.

The earlier physically proven two-DLL source-built closure remains historical fallback/baseline evidence:

- source `fdd4d4dac5a7d9611ec71975ae800437f45c47dd`;
- run `33493625367`, job `99810642354`;
- runtime artifact `9794971087`;
- closure `bcrypt.dll -> mbedtls.dll -> XP-era system DLLs`.

It is no longer the selected packaging contract. Earlier prebuilt One-Core `Check integrity`, `ERROR_INVALID_IMAGE_HASH`, `bcryptext` forwarder and `DLL_INIT_FAILED` experiments remain historical diagnostics only and must not be mixed with either source-built closure.

**Next bcrypt work is integration, not research:** update the full XP x32 Firefox workflow to consume the raw `xp-bcrypt-v1` release asset, require exact SHA-256/size before staging, stage only `bcrypt.dll`, retain PE/import and package-survival gates, and test the resulting exact browser artifact on physical XP.

Detailed status: `XP_BCRYPT_STATUS.md`.

## Current full Firefox XP boundary

Historical broad baseline:

- experiment branch `agent/winrt-source-poc`;
- source `1635d28360ee35d47c1d8237bcf8f5864cc1144f`;
- run `33310150314`;
- job `99253613546`;
- runtime artifact `9733280458`;
- diagnostics artifact `9733280937`;
- broad gate: 103 rows, 26 unique forbidden APIs across 15 PEs; `xul.dll` and `mozglue.dll` directly import `bcrypt.dll` in that baseline.

Later physical-XP browser evidence from source `99fac0b869c4c0a4638f4e076d77547d90e146cb`, run `33396056005`, job `99500729287`, package artifact `9764345117` reaches a real loader failure at `KERNEL32!AcquireSRWLockExclusive`. That is independent of the now-proven bcrypt closure.

The ten-API synchronization mechanism has been transferred into the full XP x32 workflow lineage with separate link-boundary handling for `xul.dll`, `r3dfox.exe`, `mozglue.dll`, and `plugin-container.exe`, plus an early post-build synchronization-import gate. Full YY `kernel32.lib` interposition remains prohibited.

Current full-browser work order:

1. prove the ten-API synchronization aliases are actually consumed by all four core Firefox PEs in a full build;
2. keep the physically proven msvcr14x runtime/package contract green;
3. consume the physically proven raw `xp-bcrypt-v1` release asset in the full package, verify exact SHA-256/size, stage only `bcrypt.dll`, and require package survival;
4. regenerate the surviving broad import inventory after those already-proven families are removed;
5. remediate remaining Firefox-owned and separately linked component imports at their source/build/dependency boundary where practical;
6. test the exact resulting package on physical XP for startup and ordinary browsing;
7. only after ordinary XP browser viability, treat GOST TLS on XP as a separate exact-artifact milestone.

### Other closed/independent XP findings

- Legacy `D3DCompiler_47.dll` staging/packaging boundary is closed by source `b77b22ef1e35564dfe76997d3d393d45ee697e49`, run `33349340069`, job `99359475336`.
- Official r3dfox `v153.0.3` x86 ships with sandbox disabled; sandbox restoration is optional hardening, not an XP prerequisite.
- Broad YY 26-name coverage smoke proves capability only; production membership remains caller/owner-driven.
- WinRT broad YY expansion is retired; source-level removal/fallback remains the architectural direction for WinRT because WinRT has no XP meaning.

# Bundled government-system extensions / localization

Current proven three-extension package checkpoint:

- source `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- full packaging run `32976571122`, job `98202641607`;
- packaged-browser artifact `9614275050`;
- evidence artifact `9614275551`.

The portable archive contains CryptoPro CAdES `1.2.14`, legacy Gosuslugi/IFCPlugin `1.2.8`, Gosplugin `1.3.43.0`, and the Russian-first content-language preference. Clean-profile discovery/enabled state is proven for all three. Native-component functionality and version-to-version update behavior remain separate work.

## Russian localization — package gate closed; Russian-first UI manually observed

Historical full Windows x64 package source `37846488e281b4c3a2df46e949b4f970a7343ed3`, run `33403654068`, job `99525795309`, packaged artifact `9768056691` was packaging-green but not a functional Russian-UI pass because most packaged Russian Fluent resources in root/browser `omni.ja` were zero-length.

Focused Firefox 153 l10n merge proof remains:

- source `91328ba86f050a7b64a5f344726548d22e599648`;
- run `33468459359`, job `99733112273`, success;
- `firefox-l10n` SHA `4273d99ccdc4a516ec6abd742a272ad1d385ddf4`;
- evidence artifact `9785719216`.

The first substantive full integration package was source `e4f9f775d82ff14a75708e11043211e7259eed9b`, run `33489331410`, job `99796818515`, packaged artifact `9798517225`. Its build, production Russian merge and `ru + en-US` packaging passed, and independent artifact inspection proved populated Russian resources in both final `omni.ja` files. Its only red step was a Gate D false negative caused by testing the production-merge suffix `browser/browser/browser.ftl` against the normalized final archive path `localization/ru/browser/browser.ftl`.

That CI blocker is now closed by the corrected exact source/run:

- source-under-test `3e2c32386f373d4693db52b32c05aa2000878def`;
- workflow `CryptoPro Mozilla packaging smoke`;
- Actions run `33520207057`, job `99897230730`;
- run/job conclusion: **success**;
- packaged-browser artifact `9812333220`, digest `sha256:c8e62704fcc2cd1b99c78cf6cf90b405b653a9aeba5272d132bcda4eaed5edd8`;
- evidence artifact `9812333789`, digest `sha256:fdcb6a34ed5625532af86413330b5c2d4453be046f3d6419d49d2d45c7a143dc`.

For this exact run the pinned Russian source checkout, Russian-default configuration, full release build, CryptoPro `dist/bin` gate, production `ru` merge gate, `ru + en-US` package, corrected final Gate D, and both artifact uploads all pass. Gate D retains the substantive-content checks: root/browser Russian Fluent payload, zero-length limits, Cyrillic content, representative differences from en-US, Russian requested by default, and exact `ru,en-US` multilocale declaration.

Runtime/UI evidence is kept bound to its own exact artifact. The user manually exercised predecessor artifact `9798517225` from run `33489331410` and observed a Russian interface out of the box, localized Settings and TLS error UI, and successful switching to `en-US`. The later source `3e2c323...` changes only the final CI path predicate; that prior runtime observation is therefore not relabeled as execution of artifact `9812333220`.

Current localization status: **no active packaging blocker**. The mass-empty Russian payload defect is superseded, and the final Gate D path-shape false negative is closed. A future exact-artifact runtime regression is useful when localization/package behavior changes, but another full build is not required merely to reconfirm this corrected gate on unchanged source.

# Firefox/NSS + Windows trust integration

This is an independent trust/package line on `agent/trust-integration-poc`; detailed design and exact acceptance criteria are authoritative in `TRUST_INTEGRATION.md`.

Current static contract is green:

- exactly two bundled public roots, RSA SHA-256 `d26d2d0231b7c39f92cc738512ba54103519e4405d68b5bd703e9788ca8ecf31` and GOST SHA-256 `4bb37cc7c0ff4bf2aa893e95076ebb3565c69237ee1b61635beee4c1966495c7`;
- `Certificates.ImportEnterpriseRoots=true` plus exactly the two `Certificates.Install` filenames;
- both roots staged by `r3dfox/moz.build` and preserved by `browser/installer/package-manifest.in`;
- fast preflight source `b7a2b7289a49e498911ac1231e517632469074b3`, run `33593375735`, job `100131774111`, **success**.

The first heavy package attempt remains build-description failure evidence, not trust-failure evidence:

- source `b2184aa0c7c95a47a35c7010248953902500daf3`;
- run `33594665980`, job `100135594681`;
- failed during configure before `mach build` because the two certificate entries in `FINAL_TARGET_FILES.distribution.Certificates` were not lexically sorted for Mozilla `StrictOrderingOnAppendList`;
- therefore the `dist/bin` trust gate, package step and final portable trust gate were all skipped.

The ordering defect is fixed by source `e7640a8195c6f10d8e909ad620ace74fa08c2c86`. Its corrected heavy package is now authoritative:

- workflow `CryptoPro Mozilla packaging smoke`;
- Actions run `33595966569`, attempt `2`;
- job `100141282134` (`Windows x64 / CryptoPro real Firefox packaging / ru + en-US`);
- run/job conclusion: **success**;
- packaged-browser artifact `9838528394`, digest `sha256:8341f2a4c11a3aeaf088f4fb46655bef405014ca4e9f47132640545d52784354`;
- packaging-evidence artifact `9838528813`, digest `sha256:e89f134877ecbba92e04782dddc13edd5b3981db64b1687c186f47c4ff2d3d09`.

The exact successful job passes the full release build, `GATE - Verify CryptoPro XPI and trust roots in real dist/bin`, production Russian localization merge, `ru + en-US` package, `GATE D - Verify CryptoPro XPI, trust roots, and substantive ru/en-US UI in final portable archive`, and both artifact uploads. The two pinned roots are therefore proven to survive the real `dist/bin/distribution/Certificates` tree and the extracted final portable `distribution/Certificates` tree under the workflow's exact presence/hash checks, while the existing CryptoPro and localization package gates remain green.

Attempt `1` of the same run, job `100139347397`, was cancelled during checkout and is superseded by successful attempt `2`.

Current trust status: **package/staging closure is GREEN; clean-profile runtime acceptance is OPEN.** The next boundary is the exact packaged browser artifact `9838528394`: verify `about:policies`, effective `security.enterprise_roots.enabled=true`, Windows-root import without manual NSS import, availability of both bundled root anchors, and the target Russian RSA/GOST PKI paths with the two-root contract and no explicitly bundled Sub CA. Bind that runtime result to source `e7640a8195c6f10d8e909ad620ace74fa08c2c86`, run `33595966569`, job `100141282134`, artifact `9838528394`, relevant browser binary hashes, clean profile and sanitized observations.

`r3dfox/config.cfg` still has inherited `defaultPref(..., false)` values for enterprise-root preferences. Firefox enterprise policy is expected to set-and-lock `security.enterprise_roots.enabled=true`; this precedence must be verified on the exact built artifact before changing AutoConfig. The separate `security.certerrors.mitm.auto_enable_enterprise_roots` mechanism is not itself the policy switch.

This trust line does not close the independent MSSPI/SSPI GOST server-verification blocker and does not prove Windows XP/Vista/7 runtime compatibility.

# Separation of conclusions

- Build success != GOST handshake success.
- Coordinated runtime success != final server-trust closure.
- `client_cert_loaded=1` != private-key-use proof; completed mTLS is the proof.
- Focused XP dependency runtime success != full Firefox XP startup.
- Source-built bcrypt physical-XP success != synchronization/import closure.
- Single-DLL bcrypt physical-XP success proves only the focused app-local bcrypt dependency/runtime contract, not Firefox startup.
- GOST runtime != Windows compatibility.
- Extension/localization packaging != extension runtime, UI runtime, GOST runtime, or old-Windows runtime.
- Trust preflight/package survival != clean-profile NSS policy effectiveness != GOST MSSPI server trust.
- Documentation HEADs never replace the exact source-under-test SHA for a previously built or runtime-tested artifact.
