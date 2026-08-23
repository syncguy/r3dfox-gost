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
- `agent/gost-tls-poc` = active development branch used by both workflows;
- `win-153` = protected frozen baseline branch.

Workflow role and Git branch role are independent. Do not infer that the thunk-rs workflow is the main build merely because it runs on the active development branch.
