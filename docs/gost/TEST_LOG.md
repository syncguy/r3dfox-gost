# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-30_2026-08-31.md`](./TEST_LOG_2026-08-30_2026-08-31.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); the Windows XP compatibility architecture and import-triage policy are in [`XP_COMPATIBILITY_STRATEGY.md`](./XP_COMPATIBILITY_STRATEGY.md); the source-level WinRT experiment is in [`WINRT_SOURCE_POC.md`](./WINRT_SOURCE_POC.md); formally closed milestones are in [`DONE.md`](./DONE.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-01 — focused Firefox 153 Russian l10n merge produces real payload

Track: browser packaging / localization only. This is not GOST TLS handshake evidence and not Windows compatibility evidence.

Exact source/experiment identity:

- source-under-test `91328ba86f050a7b64a5f344726548d22e599648` on `agent/gost-tls-poc`;
- commit message `ci(localization): expose vendored Python deps to l10n smoke`;
- workflow `Russian localization payload smoke`;
- Actions run `33468459359`, job `99733112273`;
- run/job conclusion: **success**;
- `firefox-l10n` source SHA `4273d99ccdc4a516ec6abd742a272ad1d385ddf4`;
- evidence artifact `9785719216` (`ru-localization-payload-smoke-evidence`), digest `sha256:e8cac1213a8bf7ffd39357f62673f0d1f20649866e8a3986d042ecfa97583d78`.

The smoke runs the exact Firefox 153 merge primitive from `toolkit/locales/l10n.mk` without configuring or compiling Firefox:

```text
python -m moz.l10n.bin.build --config browser/locales/l10n.toml --base <firefox-l10n> --target <merge-dir> --locales ru --coverage
```

Source-tree sanity for the exact l10n SHA:

- Fluent files: `245`;
- non-empty: `245`;
- zero-length: `0`;
- containing Cyrillic: `244`.

Merged Russian tree:

- Fluent files: `217`;
- non-empty: `216`;
- zero-length: `1`;
- containing Cyrillic: `215`;
- representative `browser/browser/browser.ftl`, `browser/browser/preferences/preferences.ftl`, and `toolkit/toolkit/neterror/netError.ftl` are present and non-empty.

The exact zero-length merged Fluent path is:

```text
.l10n/merge-dir/ru/toolkit/toolkit/about/aboutConfig.ftl
```

Conclusion: **PASS for real Russian source input and the standard Firefox 153 l10n merge primitive.** The merge step itself does not reproduce the mass-empty localization shape seen in packaged artifact `9768056691` (`97/100` empty root Russian files and `119/129` empty browser Russian files). The active localization blocker therefore moves downstream to full Windows multi-locale package/repack integration: the full packaging workflow either did not receive the real l10n input at the correct stage or loses/empties resources later in `package-multi-locale`/packaging. The next justified experiment is to feed the proven l10n source into `cryptopro-mozilla-packaging-smoke.yml`, record its exact l10n SHA, and add strict root/browser `omni.ja` zero-length/path/content gates before another runtime UI test.

---

## 2026-09-01 — full Windows x64 Russian-first `ru + en-US` package passes packaging mechanics but Russian payload/runtime UI fail

Track: browser packaging / localization / bundled-extension integration. This result is not GOST TLS handshake evidence and is not Windows compatibility evidence.

Exact source/build identity:

- source-under-test `37846488e281b4c3a2df46e949b4f970a7343ed3` on `agent/gost-tls-poc`;
- commit message `ci(localization): verify Russian UI inside omni.ja`;
- workflow `CryptoPro Mozilla packaging smoke`;
- Actions run `33403654068`, job `99525795309`;
- run/job conclusion: **success**;
- packaged-browser artifact `9768056691` (`r3dfox-cryptopro-mozilla-packaging-ru-en-US`), digest `sha256:29c6c09dfe61fa0fe51cad4a97f9235c71fe02b5bcd7530104cafafa8da40b9c`;
- packaging-evidence artifact `9768057338` (`cryptopro-mozilla-packaging-evidence`), digest `sha256:9e88560db20a36f77311203453927d2c0232b6d80ef3ee5150eb7d187674a591`.

Verified CI stages for this exact run:

- packaging-only Russian UI default configuration — **PASS**;
- CryptoPro XPI selection and working-tree staging — **PASS**;
- full release browser build — **PASS**;
- CryptoPro XPI presence/hash validation in real `dist/bin` — **PASS**;
- `mach package` — **PASS**;
- `mach package-multi-locale --locales ru` — **PASS**;
- final portable-archive path/existence gate for CryptoPro XPI plus `ru` and `en-US` resources — **PASS**;
- final packaged `defaults/pref/r3dfox-bundle.js` check inside `omni.ja` — **PASS**;
- packaged-browser and evidence artifact uploads — **PASS**.

The predecessor run `33076347741`, job `98531418338`, source `07c7c48419ca39952a57a53967c1bcabaa8384c1` had already built and packaged successfully but was marked failed by an incorrect final gate that searched for loose `defaults\pref\r3dfox-bundle.js`. Artifact inspection established that Firefox packages this file inside `r3dfox/omni.ja` as `defaults/pref/r3dfox-bundle.js`. Source `37846488...` corrected that path gate and run `33403654068` passed the workflow.

Subsequent exact-artifact runtime and content inspection supersedes the earlier interpretation that directory presence proved functional Russian UI resources:

- Windows 7 x64 runtime remains English on clean profile/restart even though `intl.locale.requested=ru`, `Requested Locales=["ru"]`, `Available Locales=["ru","en-US"]`, and `App Locales=["ru","en-US"]`;
- manually changing packaged `omni.ja!/default.locale` from `en-US` to `ru` does not change the visible UI;
- root `omni.ja` has 100 Russian localization files, 97 zero-length;
- `browser/omni.ja` has 129 Russian localization files, 119 zero-length;
- corresponding en-US resources are populated.

Conclusion: **multi-locale packaging mechanics PASS; Russian localization payload FAIL; Russian-first runtime UI FAIL.** Locale registration/negotiation and `default.locale` are not the primary blocker. Focused run `33468459359` later proves that a real Russian l10n checkout and the standard Firefox 153 merge primitive produce a populated tree, so the remaining defect is downstream full-package/repack integration rather than an inherent merge failure.

---

## 2026-08-31 — sandbox-disabled XP x32 artifact runs correctly on physical Windows 7 x32

Track: Windows Vista/7/XP binary compatibility only; this result is not GOST TLS handshake evidence.

Exact source/build identity:

- source-under-test `1635d28360ee35d47c1d8237bcf8f5864cc1144f` on experiment branch `agent/winrt-source-poc`;
- workflow `GOST TLS PoC build XP x32`;
- Actions run `33310150314`, job `99253613546`;
- runtime artifact `9733280458`;
- the full browser build/package/runtime staging succeeded; the Actions run conclusion is `failure` only because the later broad XP direct-import gate remained red.

Physical Windows 7 x32 runtime observation supplied by the user for this exact build:

- the browser starts and operates correctly on Windows 7 x32;
- build-time `--disable-sandbox` behaves as intended;
- `MOZ_DISABLE_CONTENT_SANDBOX=1` is no longer required in the environment;
- the browser does not show the prior notification/warning associated with runtime sandbox disabling;
- normal Windows 7 x32 browser operation is observed with the sandbox-disabled build.

Conclusion: **PASS for the intended Windows 7 x32 sandbox-disabled runtime baseline.** This confirms that build-time `--disable-sandbox` is the correct inherited x86 compatibility mode for the current XP-oriented artifact and removes the previous need for the `MOZ_DISABLE_CONTENT_SANDBOX=1` runtime workaround on Windows 7 x32. It does not close physical Windows XP startup/browsing, remaining XP PE-import work, or any GOST TLS runtime milestone.

---

## 2026-08-31 — legacy Firefox XP `D3DCompiler_47.dll` staging and packaging gates pass

Track: Windows Vista/7/XP binary compatibility only; this result is not GOST TLS handshake evidence.

Exact source/build identity:

- source-under-test `b77b22ef1e35564dfe76997d3d393d45ee697e49` on experiment branch `agent/winrt-source-poc`;
- commit message `ci(xp): fix D3DCompiler subsystem gate`;
- workflow `GOST TLS PoC build XP x32`;
- Actions run `33349340069`, job `99359475336`;
- package artifact `9744739123` (`r3dfox-gost-xp-x32-package`);
- runtime artifact `9744739656` (`r3dfox-gost-xp-x32-runtime`);
- run conclusion: `failure`.

Observed gate results for the exact run:

- `Prepare pinned legacy Firefox XP D3DCompiler_47` — **PASS**;
- `Stage pinned legacy Firefox XP D3DCompiler_47` — **PASS**;
- `GATE - Verify retargeted legacy D3DCompiler_47` — **PASS**;
- `Package XP x32 experiment` — **PASS**;
- `GATE - Verify legacy D3DCompiler_47 survived packaging` — **PASS**;
- the later independent `GATE - Audit XP x32 PE floor and direct imports` — **FAIL**.

Manual artifact inspection supplied by the user for the downloaded primary package confirms that the packaged `d3dcompiler_47.dll` reports version **`10.0.14393.33`**. This independently confirms that the intended legacy DLL, rather than the prior incompatible replacement, is present in the user-visible packaged artifact.

Conclusion: **PASS for the D3DCompiler_47 replacement/staging/packaging experiment.** The pinned legacy Firefox XP `D3DCompiler_47.dll` is successfully prepared, staged into the built browser, survives the PE-retarget/package path, is still present in the packaged result under the dedicated validation gates, and the downloaded package is manually confirmed to contain version `10.0.14393.33`. The overall Actions run remains red because the subsequent broad XP PE-floor/direct-import audit still reports independent compatibility violations. Therefore this result closes only the `D3DCompiler_47.dll` packaging hypothesis; it does not make the full XP compatibility pipeline green, does not prove physical Windows XP runtime, and has no bearing on GOST TLS handshake status.

---

## 2026-08-31 — SRW YY thunking passes, fresh SRW-smoke CRT bundle fails physical XP while prior CRT bundle passes

Track: Windows Vista/7/XP binary compatibility only; this result is not GOST TLS handshake evidence.

Exact source/build identity:

- source-under-test `89b236ad3289fcb9dc65b4bcabdf39d41f7f3be7` on `agent/gost-tls-poc`;
- workflow `msvcr14x Rust YY XP x86 coexistence smoke`;
- Actions run `33373236602`, job `99428838270`;
- runtime artifact `9751154072` (`msvcr14x-rust-yy-xp-x86-srw-runtime`), artifact digest `sha256:bc339afc644e53e31cbb2763a80f6b0949ae0686206d3d516163a2a83580f225`;
- diagnostics artifact `9751155495`, digest `sha256:b5819b09616e98fb2de8e99fbffe9a5c3639cd251a010d392d7f5d101422c4ec`;
- run conclusion: `failure` only at the runtime-bundle XP PE-floor gate.

CI observations before the failure:

- YY-Thunks 1.2.2 `kernel32.lib` contains the required weak aliases for `AcquireSRWLockExclusive`, `AcquireSRWLockShared`, `ReleaseSRWLockExclusive`, `ReleaseSRWLockShared`, and `SleepConditionVariableSRW`;
- the narrow YY XP provider builds successfully;
- representative C++ `/MD` + Rust archive + YY provider link succeeds;
- the final linker map selects all five `YY_Thunks_*` implementations;
- the final probe has no direct imports of those five SRW APIs;
- the generated probe PE is explicitly retargeted to subsystem 5.01;
- the later PE-floor gate rejects the freshly built `msvcp140.dll` because its subsystem is 6.0.

Physical Windows XP A/B observation supplied by the user for the exact SRW probe:

1. With the `msvcp140.dll` and `ucrtbase.dll` produced/staged by the current SRW runtime artifact, `msvcr14x-rust-yy-xp-x86-srw.exe` does not start and the XP loader reports: `The procedure entry point FlsGetValue could not be located in the dynamic link library KERNEL32.dll.`
2. Keeping the same SRW probe EXE but replacing only `msvcp140.dll` and `ucrtbase.dll` with the pair from the previously created `msvcr14x-rust-yy-xp-x86-smoke` makes the probe run successfully on physical XP.

Conclusion: **PASS for the five-function SRW YY-Thunks mechanism; FAIL for the freshly produced CRT runtime bundle.** The same EXE succeeds or fails solely according to the app-local CRT pair, so the physical-XP failure is localized to the current `msvcp140.dll`/`ucrtbase.dll` runtime bundle rather than to the SRW thunk provider or the probe itself. The existing PE-floor gate correctly detects a real compatibility regression and must not be weakened. The next CRT experiment must restore/reproduce the provenance and build configuration of the previously proven XP-compatible `msvcp140.dll` + `ucrtbase.dll` pair and use that runtime contract for subsequent SRW/full-browser packaging work.

---

## 2026-08-31 — aligned msvcr14x restore/configuration reproduces an XP-compatible SRW runtime bundle

Track: Windows Vista/7/XP binary compatibility only; this result is not GOST TLS handshake evidence.

Exact source/build identity:

- source-under-test `b19ba4ff3eebd2f323743d92110241fc9d4ce399` on `agent/gost-tls-poc`;
- commit message `ci(xp): align SRW msvcr14x build with proven XP smoke`;
- workflow `msvcr14x Rust YY XP x86 SRW smoke`;
- Actions run `33387080767`, job `99472017220`;
- runtime artifact `9756275917` (`msvcr14x-rust-yy-xp-x86-srw-runtime`), artifact digest `sha256:f5708981117e84ec1815554cc08494b79960464ccffcbdc1d6a70a099a1962d0`;
- diagnostics artifact `9756276724` (`msvcr14x-rust-yy-xp-x86-srw-diagnostics`), artifact digest `sha256:682755b5a1962c3ac44a9a19151f8e1faf6086805402b0ca61c32e6fccf87a05`;
- run conclusion: **success**.

The SRW workflow was aligned to the known-good XP coexistence build contract from run `33378796910` / job `99446194289` / source `08c3f6a45290c1632e7e87a69d1c269a93158e97`: msvcr14x is built with MSBuild restore (`-r`), binary logging, exact source-SHA validation, the same XP identity diagnostics, and the same `THUNK_YY_*` variable convention. The SRW-specific five-function thunk mechanism was otherwise preserved.

Verified CI gates for run `33387080767`:

- pinned msvcr14x Release x86 build — **PASS**;
- five SRW weak aliases in YY `kernel32.lib` — **PASS**;
- narrow YY XP provider including the SRW family — **PASS**;
- representative C++ `/MD` + Rust link — **PASS**;
- final PE rejects all five direct SRW imports — **PASS**;
- XP runtime staging — **PASS**;
- `GATE - Require XP x86 PE floor` — **PASS** for the complete runtime bundle;
- hosted Windows 2022 execution — **PASS**.

Independent inspection of runtime artifact `9756275917` confirms:

- `msvcp140.dll`: 423936 bytes, SHA-256 `cb907a4663249753275b4c7afceffa684a7e25607fa1d217874906a24c31d55d`, PE subsystem 5.1;
- `ucrtbase.dll`: 908800 bytes, SHA-256 `de0bd4b2152d9877a9f6e8ac05156bbd83fa7836e727f84bcfd9aa279be27906`, PE subsystem 5.1;
- `msvcr14x-rust-yy-xp-x86-srw.exe`: SHA-256 `d211e7676bf970165f9f73a771fa486311637cd017f9c0d608eb2886e4a50094`, PE subsystem 5.1;
- neither runtime DLL has direct imports of `FlsAlloc`, `FlsFree`, `FlsGetValue`, `FlsSetValue`, `AcquireSRWLock*`, `TryAcquireSRWLock*`, `ReleaseSRWLock*`, or `SleepConditionVariableSRW` in the inspected PE import tables.

The new CRT DLL sizes match the previously proven XP-compatible pair from run `33378796910`, but their SHA-256 values differ, so this is not a byte-for-byte reproduction of the old DLLs. It is a reproduction of the required XP binary contract: x86, subsystem 5.1, and no hard imports of the XP-missing FLS/SRW APIs that caused the prior loader failure.

Conclusion: **PASS and closes the fresh-CRT regression at representative SRW-smoke scale.** Aligning the SRW msvcr14x build with the proven restore/configuration contract restores an XP-compatible runtime closure while preserving the already-proven SRW YY-Thunks resolution. Because several build-contract details were aligned together, this experiment strongly implicates the previously missing MSBuild restore but does not isolate `-r` as the sole causal variable. Subsequent XP/full-browser work should treat this restored msvcr14x build contract, including restore, as mandatory and must keep the CRT PE/import gates intact. Physical Windows XP execution of this newly generated exact runtime bundle remains a separate runtime confirmation gate.

---

## 2026-08-31 — exact restored SRW runtime bundle passes on physical Windows XP

Track: Windows Vista/7/XP binary compatibility only; this result is not GOST TLS handshake evidence.

Exact source/build identity is unchanged from the immediately preceding CI experiment:

- source-under-test `b19ba4ff3eebd2f323743d92110241fc9d4ce399` on `agent/gost-tls-poc`;
- workflow `msvcr14x Rust YY XP x86 SRW smoke`;
- Actions run `33387080767`, job `99472017220`;
- runtime artifact `9756275917`, digest `sha256:f5708981117e84ec1815554cc08494b79960464ccffcbdc1d6a70a099a1962d0`;
- CI conclusion: success.

Physical Windows XP observation supplied by the user:

- the runtime artifact produced by this exact new build was tested on a real Windows XP computer;
- the artifact starts and executes successfully without substituting the older CRT DLL pair.

This closes the remaining runtime-confirmation gap from the preceding CI-only result. The exact freshly generated CRT closure (`msvcp140.dll` + `ucrtbase.dll`) that passed the XP PE/import gates is therefore also physically usable on Windows XP in the representative C++ `/MD` + Rust libstd + narrow YY/SRW workload.

Conclusion: **PHYSICAL XP PASS; current reference XP build contract established.** The restored/pinned msvcr14x build procedure plus XP PE/import closure gates is now both CI-proven and physically proven on Windows XP. The prior incompatible fresh-CRT result from run `33373236602` / job `99428838270` is superseded for build-contract purposes. This does not prove a full Firefox XP build or GOST TLS behavior. The next Windows-compatibility step is to apply this same contract to the full XP x32 workflow and then remove remaining post-XP dependencies component-by-component, beginning with project-built/staged libraries rather than masking them through PE-header retargeting or broad thunking.

---

## 2026-08-31 — full XP x32 build packages, but CRT packaging and final direct-import closure remain broken

Track: Windows Vista/7/XP binary compatibility only; this result is not GOST TLS handshake evidence.

Exact source/build identity:

- source-under-test `99fac0b869c4c0a4638f4e076d77547d90e146cb` on experiment branch `agent/winrt-source-poc`;
- workflow `GOST TLS PoC build XP x32`;
- Actions run `33396056005`, job `99500729287`;
- package artifact `9764345117` (`r3dfox-gost-xp-x32-package`);
- diagnostics artifact `9764346755` (`r3dfox-gost-xp-x32-diagnostics`);
- run conclusion: `failure`.

The exact job completed the expensive Firefox build and package stages. It failed at the post-package gate that verifies the XP-compatible msvcr14x CRT survived portable packaging, so the later workflow step `GATE - Audit XP x32 PE floor and direct imports` did not execute. The red job therefore is not a compiler/build failure.

Independent inspection of the exact package and diagnostics artifacts establishes the following:

- the packaged `r3dfox.exe`, `mozglue.dll`, and `xul.dll` all have PE OS/subsystem floor 5.01; this confirms that the header retargeting path is active, but does not imply XP-safe dependency closure;
- the package contains no app-local `vcruntime*.dll`, `msvcp*.dll`, `ucrtbase.dll`, or `api-ms-win-crt-*.dll`, while `r3dfox.exe` directly imports `VCRUNTIME140.dll` and `xul.dll` directly imports `msvcp140.dll`; therefore the proven XP-compatible CRT runtime closure did **not** survive final portable packaging and this is a hard loader blocker independently of the broad API audit;
- `r3dfox.exe` has one current XP-audit violation: forbidden direct DLL import `VCRUNTIME140.dll`;
- `mozglue.dll` has two current forbidden direct API imports: `GetTickCount64` and `InitializeCriticalSectionEx`;
- `xul.dll` has 50 current violations under the workflow's curated XP contract: forbidden direct DLL import `BCRYPT.dll` plus 49 forbidden direct APIs;
- those `xul.dll` API imports include SRW/condition-variable/threadpool/FLS families and specifically include `GetSystemTimePreciseAsFileTime`, `GetOverlappedResultEx`, `GetTickCount64`, `InitializeCriticalSectionEx`, `CancelIoEx`, `GetFileInformationByHandleEx`, `GetFinalPathNameByHandleW`, `GetLocaleInfoEx`, `LCIDToLocaleName`, `LocaleNameToLCID`, and `ProcessPrng`;
- the diagnostics narrow YY provider contains thunk implementations/aliases for many of these names, including `GetSystemTimePreciseAsFileTime`, FLS, `GetTickCount64`, `InitializeCriticalSectionEx`, and `RoGetActivationFactory`, but the final packaged `xul.dll` still imports the APIs directly; provider membership therefore does not prove effective interposition in the full Firefox link;
- packaged `d3dcompiler_47.dll` has no violations under the current curated forbidden DLL/API set. Its PE OS version remains 10.0 while subsystem is 5.01, so its dedicated legacy staging result remains a separate verified boundary rather than evidence about Firefox's own import closure.

Conclusion: **FAIL for full-browser XP dependency/import closure; PASS for identifying the next concrete blockers.** The restored msvcr14x build contract is not yet correctly propagated through final Firefox packaging, and the final `xul.dll` still retains a large direct post-XP import surface despite the presence of a narrow YY provider. Header retargeting and provider symbol availability are therefore insufficient. The next compatibility work should first restore the proven app-local CRT pair into the final portable package and add a post-package CRT identity/import gate, then analyze why the full `xul.dll` link is not resolving the intended narrow YY aliases before adding any more thunk coverage. The broad PE audit should also be made to run or upload its inventory even when an earlier packaging gate fails, so subsequent full builds do not hide import evidence behind a separate gate failure.