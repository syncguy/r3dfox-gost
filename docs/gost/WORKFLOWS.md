# r3dfox GOST TLS — Workflow Roles

This file records the intended roles of the project GitHub Actions workflows so build results are not confused across independent experiment tracks.

## Main GOST build

Workflow file:

`.github/workflows/gost-poc-build.yml`

Workflow name:

`GOST TLS PoC build`

Role:

This is the project's main GOST TLS browser build workflow. Use results from this workflow when referring to the main project build unless a different workflow is named explicitly.

## Experimental Windows Vista/7 thunk-rs build

Workflow file:

`.github/workflows/gost-poc-build-thunk.yml`

Workflow name:

`GOST TLS PoC build - thunk-rs experiment`

Role:

This is an experimental Windows Vista/7 linker/toolchain workflow. It exists to test YY-Thunks, thunk-rs, VC-LTL, Rust raw-dylib import behavior, final PE imports, and related compatibility hypotheses at full Firefox/xul.dll scale.

Do not call this the project's main build. A successful or failed run here is evidence for the Windows Vista/7 compatibility track and does not by itself establish the state of the main GOST TLS build or the GOST TLS runtime handshake.

## Experimental Windows XP Rust/thunk smoke

Workflow file:

`.github/workflows/rust-xp-thunk-smoke.yml`

Workflow name:

`Rust XP thunk smoke test`

Role:

This is an exploratory Windows XP compatibility workflow, separate from the main GOST TLS goal. It tests whether a modern Rust/MSVC program can be pushed toward an XP-compatible binary model using `i686-pc-windows-msvc`, `thunk-rs`, an x86 PE image, Windows XP subsystem version 5.01, and explicit inspection of modern WinAPI imports such as `ProcessPrng`, `WaitOnAddress`, `WakeByAddress*`, `GetSystemTimePreciseAsFileTime`, and `GetOverlappedResultEx`.

The current smoke runs the produced executable on the GitHub-hosted Windows Server 2022 runner. Therefore a successful build/run there plus PE 5.01 headers is not proof that the executable actually runs on Windows XP. Real XP runtime execution remains a separate compatibility gate.

This track is technically useful even if GOST TLS is never supported on XP. A future XP-compatible r3dfox build without GOST would still be a worthwhile outcome. The intended progression is to use small Rust/WinAPI compatibility probes first, then carry proven techniques into Firefox-scale PE/import and runtime work.

Potentially relevant external project:

- `Chuyu-Team/msvcr14x`: <https://github.com/Chuyu-Team/msvcr14x>

`msvcr14x` is relevant to the CRT/UCRT/API-set part of old-Windows compatibility: it is designed to let software built with VC2015 and newer avoid depending on a set of `api-ms-win-*` runtime DLLs, and it references YY-Thunks-related techniques. Treat it as a candidate/reference for future XP compatibility work, not as an already integrated or validated dependency of r3dfox-gost.

The XP line must remain conceptually separate from the GOST TLS runtime line. XP compatibility may be pursued without MSSPI/CryptoPro/GOST support if that substantially reduces the platform constraints.

## Current full-scale thunk experiment

As of 2026-08-23, the current experimental run is:

- workflow: `GOST TLS PoC build - thunk-rs experiment`;
- run number: `#14`;
- Actions run ID: `32647338452`;
- job ID: `97213486474`;
- branch: `agent/gost-tls-poc`;
- commit SHA under test: `0eb29ecccaa3d2a0762af17e458c42cf245410d7`;
- commit message: `ci: scale narrow ProcessPrng strategy to xul`;
- status when this note was written: `in_progress`.

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32647338452>

The hypothesis under test is whether the narrow ProcessPrng provider plus YY-Thunks `synchronization.lib`, already confirmed by the representative closing smoke, scales to the real Firefox `xul.dll` link without reintroducing the broad whole-YY-`kernel32.lib` collision class and while keeping the known forbidden Win8+ imports out of the final PE import table.

The final result of this run belongs in `docs/gost/TEST_LOG.md` after the run completes and its exact outcome is inspected.

## Terminology rule

Keep these concepts separate:

- `gost-poc-build.yml` = main GOST TLS build workflow;
- `gost-poc-build-thunk.yml` = experimental Windows Vista/7 thunk-rs build workflow;
- `rust-xp-thunk-smoke.yml` = exploratory Windows XP Rust/thunk compatibility smoke workflow;
- `agent/gost-tls-poc` = active development branch used by these workflows;
- `win-153` = protected frozen baseline branch.

Workflow role and Git branch role are independent. Do not infer that an experimental compatibility workflow is the main build merely because it runs on the active development branch.
