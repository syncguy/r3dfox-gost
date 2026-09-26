# Windows XP synchronization import status

Last updated: 2026-09-01

Track: Windows Vista/7/XP binary compatibility only. This document is not GOST TLS handshake evidence.

## Exact failure evidence from the full Firefox build

The relevant full Firefox XP x32 build was:

- source-under-test `99fac0b869c4c0a4638f4e076d77547d90e146cb` on experiment branch `agent/winrt-source-poc`;
- workflow `GOST TLS PoC build XP x32`;
- Actions run `33396056005`, job `99500729287`;
- package artifact `9764345117` (`r3dfox-gost-xp-x32-package`);
- diagnostics artifact `9764346755`;
- run conclusion: **failure**.

The exact package artifact was independently downloaded and correlated with the physical-XP test files:

- `r3dfox.exe` SHA-1 `562195fb0dfb9b6032069fd050ee8995efe74e62`;
- `xul.dll` SHA-1 `194184fd716ec9d916230fed087da4ea2c5ba28f`.

Physical Windows XP startup fails with:

```text
The procedure entry point AcquireSRWLockExclusive could not be located in the dynamic link library KERNEL32.dll.
```

This is not a wrong-artifact incident. The tested binaries are exactly the files from package artifact `9764345117`, and those binaries retain direct XP-incompatible synchronization imports.

The full workflow at source `99fac0...` had copied only the older narrow YY provider members (`ProcessPrng`, `GetSystemTimePreciseAsFileTime`, `FlsAlloc`, `FlsFree`, `FlsSetValue`, `IsThreadAFiber`, `SetThreadStackGuarantee`). It did **not** copy the SRW `.obj/.obi` members already proven by the focused smoke. In addition, the compatibility linker injection targeted only `xul.dll`, while `r3dfox.exe`, `mozglue.dll`, and `plugin-container.exe` are separately linked PEs.

The job completed the expensive Firefox build and package stages but then failed at the post-package msvcr14x CRT-survival gate. Consequently the later broad `GATE - Audit XP x32 PE floor and direct imports` did not execute, so the synchronization regression was hidden by an independent earlier gate failure.

## Current ten-API synchronization family

The core-browser synchronization set now explicitly tracked as one focused YY experiment is:

- `AcquireSRWLockExclusive`;
- `AcquireSRWLockShared`;
- `ReleaseSRWLockExclusive`;
- `ReleaseSRWLockShared`;
- `InitializeSRWLock`;
- `InitializeConditionVariable`;
- `SleepConditionVariableCS`;
- `SleepConditionVariableSRW`;
- `WakeAllConditionVariable`;
- `WakeConditionVariable`.

The previously abbreviated `Wake*` notation means exactly `WakeAllConditionVariable` and `WakeConditionVariable`.

`TryAcquireSRWLockExclusive` remains outside this ten-function core set unless a target PE actually imports it. `TryAcquireSRWLockShared` is likewise not added by symmetry without observed evidence.

`InitializeCriticalSectionEx` is a related post-XP synchronization import but remains separately classified because the preferred direction is first to evaluate an XP-native source fallback (`InitializeCriticalSection` / `InitializeCriticalSectionAndSpinCount`) rather than automatically assign it to YY.

## Focused ten-API proof

The expanded focused synchronization smoke is now green:

- source-under-test `d65b464c74caadace97995f07a4919363c41a0ea` on `agent/gost-tls-poc`;
- commit message `ci(xp): expand synchronization YY smoke to ten APIs`;
- workflow `msvcr14x Rust YY XP x86 SRW smoke`;
- Actions run `33470957048`, job `99740439208`;
- runtime artifact `9786702687` (`msvcr14x-rust-yy-xp-x86-srw-runtime`), digest `sha256:6b931856c9e4e31b067b5684d3c49fd9028c2c9aaf7f2566be79c910ad353571`;
- diagnostics artifact `9786703244` (`msvcr14x-rust-yy-xp-x86-srw-diagnostics`), digest `sha256:57c67a45a30b94a854f00e358c528c1ffe4129dc7dc615de19c1ed725e89c530`;
- run/job conclusion: **success**.

Verified gates for this exact run:

- pinned msvcr14x Release x86 build — **PASS**;
- `GATE - Require ten synchronization weak aliases in YY kernel32` — **PASS**;
- physically narrow YY XP provider with the ten synchronization functions — **PASS**;
- ordinary C++ `/MD` helper that directly references all ten APIs — **PASS**;
- representative Rust archive — **PASS**;
- final link — **PASS**;
- final linker map selects all ten `YY_Thunks_*` implementations — **PASS**;
- `GATE - Reject ten direct synchronization imports` — **PASS**;
- XP x86 PE floor — **PASS**;
- hosted Windows 2022 probe execution — **PASS**.

This supersedes the earlier five-function capability proof from run `33387080767` for synchronization coverage. The older run remains useful as the first physically proven SRW/CRT contract, but the current focused compatibility surface is the ten-API set above.

## Transfer to the full XP x32 build

The ten-API mechanism has now been transferred into the full XP x32 workflow lineage used by run `33396056005`:

- branch: `agent/winrt-source-poc`;
- transfer commit: `8d76efba59fd7d4c04df3f0d3fe82e1c4e08a3ce`;
- workflow: `.github/workflows/gost-poc-build-xp-x32.yml`.

The transfer deliberately fixes both previously identified integration defects:

1. the narrow YY provider now includes the direct/import `.obj/.obi` members for all ten synchronization APIs and verifies the corresponding `YY_Thunks_*` symbols before the expensive Firefox build;
2. the narrow provider is injected at the separate link boundaries for `xul.dll`, `r3dfox.exe`, `mozglue.dll`, and `plugin-container.exe`, rather than assuming a libxul-only link can rewrite imports of separately linked PEs.

The invariant remains that the complete YY `kernel32.lib` must **not** reach final Firefox links. `synchronization.lib` remains the existing bounded input for the Rust `WaitOnAddress` family; the ten API aliases come from the physically narrow provider extracted from YY `kernel32.lib`.

A new fail-fast step `GATE - Reject core browser synchronization direct imports` runs immediately after the Firefox build and before msvcr14x runtime staging, legacy D3DCompiler staging, PE retargeting and package/CRT-survival gates. It inspects:

- `r3dfox.exe`;
- `xul.dll`;
- `mozglue.dll`;
- `plugin-container.exe`.

If any of the ten synchronization names survives as a direct import, the workflow now fails at that dedicated gate and uploads the per-PE import diagnostics. Therefore an unrelated later CRT/package failure can no longer hide this specific synchronization regression.

## Current conclusion

**Focused capability: PASS. Full Firefox integration: implemented, not yet proven by a new full run.**

The next heavy XP x32 build must be tied to exact source SHA `8d76efba...` or a later explicitly identified descendant containing the same transfer. The ten-API gate must pass before any conclusion is drawn from later packaging or broad-import stages. Only after that exact full build passes the dedicated synchronization gate should this family be considered transferred successfully into Firefox. Physical Windows XP startup remains a separate subsequent runtime gate.
