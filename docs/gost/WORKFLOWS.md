# r3dfox GOST TLS — Workflow Roles

This file records the intended roles of the project GitHub Actions workflows so build results are not confused across independent experiment tracks.

## Main GOST build

Workflow file:

`.github/workflows/gost-poc-build.yml`

Workflow name:

`GOST TLS PoC build`

Role:

This is the project's main GOST TLS browser build workflow. Use results from this workflow when referring to the main project build unless a different workflow is named explicitly.

It is the authoritative build line for the GOST TLS runtime/handshake track. A successful build still does not by itself prove a successful GOST handshake.

## Experimental Windows Vista/7 thunk-rs build

Workflow file:

`.github/workflows/gost-poc-build-thunk.yml`

Workflow name:

`GOST TLS PoC build - thunk-rs experiment`

Role:

This is the full Firefox/xul-scale Windows Vista/7 linker/toolchain workflow. It tests YY-Thunks, thunk-rs, VC-LTL, Rust raw-dylib import behavior, final PE imports, and related compatibility hypotheses against a real packaged Firefox build.

Do not call this the project's main GOST build. Results here belong to the Windows Vista/7 compatibility track and do not establish GOST TLS handshake state.

Current linker strategy:

- YY-Thunks 1.2.2 `synchronization.lib` for the selected synchronization redirects;
- a physically narrow provider containing the proven ProcessPrng and `GetSystemTimePreciseAsFileTime` weak-alias members plus the common YY implementation member;
- no broad complete-YY-`kernel32.lib` interposition before Rust/gkrust;
- preserve Firefox's `/MD` CRT model.

Run `32695496647`, job `97336702701`, commit `ae3d52f42b8b6b509c1263418bead8bb9324dd00` completed the full build/package and removed `GetSystemTimePreciseAsFileTime` from xul's direct imports. Its final red status came only from incorrectly classifying Vista-supported `GetQueuedCompletionStatusEx` as Win8+. Commit `e2a9c3bcbbdfade62a15a144da9117e249cc6305` removes that one false-positive policy entry without changing linker behavior.

The xul audit has a meaningful ordinary/direct import parser. Direct imports are the current process-loader hard gate.

The delay-load side requires an important qualification: `dumpbin` formats delay API rows differently from ordinary import rows, and the API regex used in `ae3d52f4...` does not match that delay row shape. Therefore an empty `xul-thunk-win7-delay-import-api-names.txt` is **not** proof that no delay-loaded APIs exist. Keep the raw `xul-thunk-win7-imports.txt` diagnostic and fix/replay the delay parser before making delay-load runtime-path conclusions.

## Narrow ProcessPrng closing smoke

Workflow file:

`.github/workflows/yy-thunks-processprng-smoke.yml`

Role:

This is the representative Rust/raw-dylib closing proof for the physically narrow ProcessPrng provider. It was used to reproduce the raw-dylib collision class that the broad YY `kernel32.lib` triggered and to prove a narrow archive strategy without full Firefox build cost.

Formal passing evidence:

- run `32644291202`;
- job `97207125757`;
- commit `fd925b1780fa3470a2cfba743a7374f7d7e644d6`.

This smoke proved the narrow ProcessPrng strategy at representative-link scale; later full xul runs are required for Firefox-scale conclusions.

## Precise-time closing smoke

Workflow file:

`.github/workflows/yy-thunks-precise-time-smoke.yml`

Workflow name:

`YY-Thunks precise-time closing smoke`

Role:

This is the focused closing proof for the `GetSystemTimePreciseAsFileTime` hard direct-import blocker found after the first full xul-scale narrow ProcessPrng run.

Passing evidence:

- run `32680494331`;
- job `97296220325`;
- commit `cdef097b1912f68232de13d5e41b1a84add466d6`;
- result: success on the first attempt.

It verifies the ordinary and `__imp_` COFF weak aliases, uses only the selected precise-time alias members plus the common YY implementation object, keeps a representative Rust raw-dylib `LockResource` positive control, and requires precise-time to disappear from the final PE imports without allowing the complete YY `kernel32.lib` into the final link.

Passing this smoke is representative-link proof, not by itself Firefox/xul-scale or Windows 7 runtime proof. Run `32695496647` supplied the later xul-scale proof.

## Forward VC-LTL / YY-Thunks Rust smoke

Workflow file:

`.github/workflows/yy-thunks-rust-smoke.yml`

Workflow name:

`YY-Thunks Rust Win7 smoke`

Role:

This is a forward-compatibility canary for current VC-LTL and YY-Thunks releases on the Rust/MSVC Win7 compatibility path. Its primary purpose is to answer whether representative Rust code still compiles/links when external compatibility components are advanced.

It is not the authoritative proof for the linker strategy currently used in Firefox's real `xul.dll`; that proof belongs to the dedicated closing smokes plus `.github/workflows/gost-poc-build-thunk.yml`.

Starting with VC-LTL 5.3.1, VC-LTL no longer supplies YY-Thunks as an automatic dependency. Therefore this canary treats VC-LTL and YY-Thunks as independently versioned inputs and may use `thunk-rs` path overrides instead of its older embedded download pins.

Do not conflate a canary dependency-version result with the full xul-scale linker/import result.

## Isolated msvcr14x Win7 smoke

Workflow file:

`.github/workflows/msvcr14x-win7-smoke.yml`

Role:

This is the isolated CRT/UCRT compatibility smoke for `Chuyu-Team/msvcr14x`. It tests a normal `/MD` C++ object against the pinned msvcr14x import-library/runtime surface and audits the resulting PE for direct API-set and VCRUNTIME dependencies.

It is not a Rust/YY proof and is not a full Firefox/xul proof. Its purpose is to establish that msvcr14x can replace the standard CRT/UCRT import-library surface while preserving `MD_DynamicRelease`.

## msvcr14x Rust/YY coexistence smoke

Workflow file:

`.github/workflows/msvcr14x-rust-yy-coexistence-smoke.yml`

Workflow name:

`msvcr14x Rust YY coexistence smoke`

Role:

This is the closing representative-link proof for combining msvcr14x with modern Rust/libstd and the already-proven narrow YY-Thunks 1.2.2 strategy. It keeps an ordinary C++ `/MD` object, uses YY `synchronization.lib` plus the narrow ProcessPrng + precise-time provider, rejects complete YY `kernel32.lib` interposition, audits the final PE for direct API-set/VCRUNTIME/known Win8+ hard imports, and runs the resulting probe on the hosted Windows runner.

Formal passing evidence:

- run `32713958570`;
- job `97391163925`;
- commit `1abf867307ca56b97b7f2fb41e5e58e86ee08463`;
- msvcr14x commit `6495947edbdd8f5dc4b2ddb8ca0cb5dbdac05384`;
- YY-Thunks `1.2.2`;
- Rust `nightly-2026-08-20`;
- result: success.

Passing this smoke closes the representative coexistence question only. It does not prove that msvcr14x integration scales through Firefox's full link or that the resulting browser runs on Windows 7. The next compatibility experiment belongs in the full Firefox/xul workflow line.

## Experimental Windows XP Rust/thunk smoke

Workflow file:

`.github/workflows/rust-xp-thunk-smoke.yml`

Workflow name:

`Rust XP thunk smoke test`

Role:

This is an exploratory Windows XP compatibility workflow, separate from both the GOST TLS runtime line and the Windows 7 full-xul line. It tests whether modern Rust/MSVC output can be pushed toward an XP-compatible binary model using `i686-pc-windows-msvc`, thunk techniques, XP PE subsystem settings, and import inspection.

A successful build/run on a current GitHub-hosted Windows runner plus PE 5.01 headers is not proof that the executable runs on Windows XP. Real XP runtime execution remains a separate gate.

## CryptoPro extension packaging smoke

Workflow file:

`.github/workflows/cryptopro-extension-smoke.yml`

Workflow name:

`CryptoPro extension packaging smoke`

Role:

This is the dedicated low-cost integration smoke for the bundled CryptoPro CAdES Firefox extension. It is separate from the GOST TLS runtime/handshake track and from the Windows Vista/7 linker/toolchain track.

It tests `build/update-cryptopro-extension.py` and the committed fallback XPI without compiling Firefox. Its gates cover fallback integrity, forced network failure, invalid-fallback hard failure, acceptance of a valid downloaded candidate, malformed-candidate fallback, wrong-extension-ID fallback, a live check of the official CryptoPro XPI endpoint, staging into `distribution/extensions`, and verification of the final ZIP layout/hash/extension ID.

Formal passing evidence for the standalone phase:

- run `32815118778`;
- job `97701728235`;
- code-under-test commit `2ad7025ca300613d39a227b9e7582a341260d648`;
- evidence artifact `9551126137`;
- result: success.

This standalone success does **not** prove Mozilla `FINAL_TARGET_FILES` integration or installation by a real packaged Firefox. The next extension-track proof is the real Mozilla packaging-graph integration, still kept separate from both full browser workflows until proven.

Detailed design and current extension state are recorded in [`EXTENSIONS.md`](./EXTENSIONS.md).

## Current full-scale thunk evidence

The significant completed full-scale result is:

- workflow: `GOST TLS PoC build - thunk-rs experiment`;
- Actions run ID: `32695496647`;
- job ID: `97336702701`;
- commit SHA: `ae3d52f42b8b6b509c1263418bead8bb9324dd00`;
- release artifact: `9512347999`;
- diagnostics artifact: `9512349511`.

The build/package/linker strategy succeeded. `GetSystemTimePreciseAsFileTime` is no longer a direct xul import. The red final status was a direct-gate policy false positive on Vista-supported `GetQueuedCompletionStatusEx`.

The corrective workflow commit is `e2a9c3bcbbdfade62a15a144da9117e249cc6305`. Conclusions from its next full build must be associated with that run's actual head SHA; later documentation-only commits on the branch do not change which source/workflow revision an already-created run tested.

## Terminology rule

Keep these concepts separate:

- `gost-poc-build.yml` = main GOST TLS build workflow;
- `gost-poc-build-thunk.yml` = experimental Windows Vista/7 full Firefox/xul workflow;
- `yy-thunks-processprng-smoke.yml` = representative narrow ProcessPrng closing proof;
- `yy-thunks-precise-time-smoke.yml` = focused precise-time closing proof;
- `yy-thunks-rust-smoke.yml` = forward VC-LTL / YY-Thunks Rust compatibility canary;
- `msvcr14x-win7-smoke.yml` = isolated msvcr14x CRT/UCRT smoke;
- `msvcr14x-rust-yy-coexistence-smoke.yml` = representative msvcr14x + Rust/libstd + narrow YY coexistence closing proof;
- `rust-xp-thunk-smoke.yml` = exploratory Windows XP Rust/thunk compatibility smoke;
- `cryptopro-extension-smoke.yml` = standalone CryptoPro extension update/fallback/staging/package proof;
- `agent/gost-tls-poc` = active development branch;
- `agent/msvcr14x-win7-smoke` = isolated experimental branch for the msvcr14x compatibility line;
- `win-153` = protected frozen baseline branch.

Workflow role and Git branch role are independent. Do not infer that an experimental compatibility workflow is the main GOST build merely because it runs on an active development or experiment branch.