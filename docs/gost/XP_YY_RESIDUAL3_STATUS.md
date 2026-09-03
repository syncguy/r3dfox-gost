# Windows XP x86 — YY residual-three closure

Last updated: 2026-09-03

This document records the focused YY-Thunks proof for three hard KERNEL32 residual imports found in the full Firefox XP x32 diagnostics. This is Windows XP SP3 x86 compatibility evidence only; it is not GOST TLS runtime/handshake evidence.

## Status

**FOCUSED GREEN / READY FOR FULL-FIREFOX INTEGRATION.**

The following three APIs are now proven through the project’s physically narrow YY-Thunks 1.2.2 provider model at capability, native-link, PE/direct-import and hosted semantic-runtime levels:

- `InitOnceExecuteOnce`;
- `GetThreadPreferredUILanguages`;
- `QueryFullProcessImageNameA`.

They must no longer be treated as unproven YY candidates. They are not yet closed as full-Firefox or physical-Windows-XP dependencies until the selected members are integrated into the real browser link(s), the resulting core PEs no longer import them directly, and the exact browser artifact advances on physical XP.

## Exact evidence identity

- branch: `agent/winrt-source-poc`;
- source-under-test: `ffb72c4ae6988a7c4f82b4e67a9027e41afb572b`;
- workflow: `.github/workflows/xp-core-kernel32-cluster-smoke.yml` / `XP x86 core KERNEL32 cluster smoke`;
- Actions run: `33712987285`, attempt 1;
- job: `100516220327` (`Core post-XP API cluster / XP x86`);
- job result: **success**;
- runtime artifact: `9877671991` (`xp-core-kernel32-cluster-runtime`), size `647453` bytes, digest `sha256:7019174cb87bed77832b98138d850fa0d5577f7686acb4f5dc1a3610328fcfbe`;
- diagnostics artifact: `9877672471` (`xp-core-kernel32-cluster-diagnostics`), size `1015661` bytes, digest `sha256:4b9679d2f419e9fd3ab8dba58a060e9ad6f67cbe437dda43cce99aa93b7f2334`;
- YY-Thunks: `1.2.2`, XP target `5.1.2600.0`, x86;
- msvcr14x: pinned `6495947edbdd8f5dc4b2ddb8ca0cb5dbdac05384`, Release x86.

The residual-import provenance used by the smoke is the full Firefox source `17cdb459ec4f115a209fd50ac225cf867b9f3a2f`, run `33638897692`, job `100276666021`.

## Capability proof

The workflow makes these three APIs a required delta rather than optional inventory entries. `diagnostics/required-delta-capability.txt` records:

`required_delta_capability=PASS`

The capability inventory confirms for each API one direct weak-alias object, one import object, the expected x86 stdcall decorated symbol, and a `YY_Thunks_*` implementation marker:

| API | Decorated x86 symbol | Stack bytes | YY capability |
| --- | --- | ---: | --- |
| `InitOnceExecuteOnce` | `_InitOnceExecuteOnce@16` | 16 | capable |
| `GetThreadPreferredUILanguages` | `_GetThreadPreferredUILanguages@16` | 16 | capable |
| `QueryFullProcessImageNameA` | `_QueryFullProcessImageNameA@16` | 16 | capable |

The workflow hard-fails if any of the required three is missing. Therefore this run does not obtain GREEN through a `SKIP` path.

## Narrow-provider / link proof

The existing cluster architecture is preserved:

- only selected `.obj` + `.obi` members are extracted from YY `kernel32.lib`;
- the existing internal `ProcessPrng` closure members and common `YY_Thunks_for_5.1.2600.0.obj` implementation member are retained;
- complete YY `kernel32.lib` is prohibited from the final link;
- the final native x86 link passes;
- the XP PE subsystem gate passes.

The final direct-import gate records:

`cluster_import_gate=PASS`

and explicitly rejects any surviving direct import of the three required residual APIs.

## Hosted semantic runtime proof

The hosted Windows run reports:

- `GetThreadPreferredUILanguages: PASS`;
- `InitOnceExecuteOnce: PASS`;
- `QueryFullProcessImageNameA: PASS`;
- `Overall: PASS`;
- `ExitCode=0`.

The semantic probes are deliberately stronger than symbol-resolution checks:

### `InitOnceExecuteOnce`

Eight threads call the same `INIT_ONCE`. The callback increments a shared counter and publishes a context pointer. Acceptance requires:

- all eight calls to succeed;
- every caller to observe the expected context;
- callback execution count to equal exactly one;
- zero per-thread failures.

This validates once-only concurrency semantics on the hosted runner.

### `GetThreadPreferredUILanguages`

The probe performs the size/count query and then the real buffer query. Acceptance requires a successful second call, a positive language count and a non-empty returned multi-string.

### `QueryFullProcessImageNameA`

The probe calls the ANSI API for the current process and requires a successful, non-empty executable path.

## Relationship to the earlier 24-API cluster

This run extends rather than reopens the already-green 24-API KERNEL32 cluster from source `0184985c2f0c5ab1c4c732a200cfbda07a6aefb4`, run `33600786738`, job `100153789478`.

`CreateWaitableTimerExA` is intentionally absent from the active candidate inventory because the product dependency was already removed at source level by using Firefox’s existing `mHiResTimer == nullptr` fallback. YY support for that API is neither required nor an open blocker.

The effective focused YY capability set for this line is therefore the proven 24-API cluster plus these three newly proven residual APIs, while the earlier ten-API SRW/condition-variable baseline remains independently closed and valid.

## Full-Firefox integration boundary

The exact full-build diagnostics that motivated this experiment showed:

- `InitOnceExecuteOnce` as a hard KERNEL32 import in `mozglue.dll` and `xul.dll`;
- `GetThreadPreferredUILanguages` as a hard KERNEL32 import in `xul.dll`;
- `QueryFullProcessImageNameA` as a hard KERNEL32 import in `xul.dll`.

The next implementation step is therefore not another capability smoke. It is to transfer the exact selected YY members into the full XP Firefox narrow-provider/link ownership model and extend the early core-browser import gate to reject all three symbols.

Per-PE ownership must remain explicit. Do not solve an `xul.dll` or `mozglue.dll` import by reintroducing broad global `kernel32.lib` interposition.

After that integration, a full Firefox build must prove that the actual product PEs no longer directly import these three APIs. Physical Windows XP startup remains a separate acceptance boundary.

## Remaining known hard KERNEL32 source-remediation queue

Once these three proven YY members are transferred into the full browser, the currently known hard KERNEL32 residuals that are not covered by this YY closure are:

- `GetApplicationRestartSettings`;
- `RegisterApplicationRestart`;
- `UnregisterApplicationRestart`;
- `GetNamedPipeServerProcessId`.

Those remain source/caller-remediation work unless new evidence supports a different bounded solution.

`PROPSYS.dll` remains a separate adaptation stage and must not be mixed into this KERNEL32 YY closure.

## Evidence boundary

Run `33712987285` proves focused YY capability, physically narrow native linking, XP PE/direct-import closure, and hosted semantic runtime behavior for the three required APIs.

It does **not** by itself prove:

- that the current full Firefox `xul.dll` and `mozglue.dll` consume these members;
- physical Windows XP execution of the focused runtime bundle;
- full Firefox startup or ordinary browsing on XP;
- any GOST TLS behavior.

Those are later, separately identified gates.