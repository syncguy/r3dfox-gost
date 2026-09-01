# r3dfox GOST TLS — Project State

Last updated: 2026-09-01

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

Build success does not prove GOST TLS. A focused dependency runtime pass does not prove full Firefox startup. Packaging success does not prove runtime discovery or network behavior.

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

## Russian localization — package content proven, final gate repair pending

Historical full Windows x64 package source `37846488e281b4c3a2df46e949b4f970a7343ed3`, run `33403654068`, job `99525795309`, packaged artifact `9768056691` was packaging-green but not a functional Russian-UI pass because most packaged Russian Fluent resources in root/browser `omni.ja` were zero-length.

Focused Firefox 153 l10n merge proof remains:

- source `91328ba86f050a7b64a5f344726548d22e599648`;
- run `33468459359`, job `99733112273`, success;
- `firefox-l10n` SHA `4273d99ccdc4a516ec6abd742a272ad1d385ddf4`;
- evidence artifact `9785719216`.

The latest full integration run advances the boundary substantially:

- source-under-test `e4f9f775d82ff14a75708e11043211e7259eed9b`;
- workflow `CryptoPro Mozilla packaging smoke`;
- Actions run `33489331410`, job `99796818515`;
- packaged-browser artifact `9798517225`;
- run conclusion: failure only at final Gate D.

The pinned Russian source checkout, packaging-only Russian default, full release build, CryptoPro `dist/bin` gate, production `ru` merge gate, and `ru + en-US` multi-locale packaging all passed. The production merge contains `217` RU FTL files (`216` non-empty, `215` with Cyrillic); prepackage staging contains substantive root and browser resources (`98/99` and `129/129` non-empty respectively).

Independent inspection of the exact final portable artifact proves that substantive Russian UI resources survive packaging: browser `omni.ja` contains `129` RU FTL with zero zero-length files and `118` containing Cyrillic; root `omni.ja` contains `99` RU FTL with one zero-length file and `96` containing Cyrillic. Representative `browser.ftl`, `preferences.ftl`, and `netError.ftl` are substantive; the package requests Russian by default and declares exact `ru,en-US` multilocale content.

The red Gate D is therefore a **CI false negative**, not a localization-content failure. The production merge path for the representative browser resource is `browser/browser/browser.ftl`, while final `browser/omni.ja` normalizes it to `localization/ru/browser/browser.ftl`. Gate D still tests the former suffix and incorrectly reports the packaged browser resource as missing.

Current localization blocker: repair Gate D to validate the actual final `omni.ja` path while retaining the zero-length, Cyrillic, en-US-difference, Russian-default and `ru,en-US` checks. After that gate is green on a new exact source/run, perform a clean-profile runtime Russian-UI verification. The current packaging evidence does not by itself prove runtime UI behavior.

# Separation of conclusions

- Build success != GOST handshake success.
- Coordinated runtime success != final server-trust closure.
- `client_cert_loaded=1` != private-key-use proof; completed mTLS is the proof.
- Focused XP dependency runtime success != full Firefox XP startup.
- Source-built bcrypt physical-XP success != synchronization/import closure.
- Single-DLL bcrypt physical-XP success proves only the focused app-local bcrypt dependency/runtime contract, not Firefox startup.
- GOST runtime != Windows compatibility.
- Extension/localization packaging != extension runtime, UI runtime, GOST runtime, or old-Windows runtime.
- Documentation HEADs never replace the exact source-under-test SHA for a previously built or runtime-tested artifact.
