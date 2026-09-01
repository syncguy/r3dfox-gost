# Windows XP synchronization import status

Last updated: 2026-09-01

Track: Windows Vista/7/XP binary compatibility only. This document is not GOST TLS handshake evidence.

## Exact evidence identity

The narrow SRW compatibility mechanism was proven by:

- source-under-test `b19ba4ff3eebd2f323743d92110241fc9d4ce399` on `agent/gost-tls-poc`;
- workflow `msvcr14x Rust YY XP x86 SRW smoke`;
- GitHub Actions run `33387080767`, job `99472017220`;
- runtime artifact `9756275917` (`msvcr14x-rust-yy-xp-x86-srw-runtime`);
- run conclusion: **success**.

That smoke explicitly selected YY-Thunks objects for these five APIs and rejected any final direct import of them:

- `AcquireSRWLockExclusive`;
- `AcquireSRWLockShared`;
- `ReleaseSRWLockExclusive`;
- `ReleaseSRWLockShared`;
- `SleepConditionVariableSRW`.

The subsequent full Firefox XP x32 build was:

- source-under-test `99fac0b869c4c0a4638f4e076d77547d90e146cb`;
- workflow `GOST TLS PoC build XP x32`;
- GitHub Actions run `33396056005`, job `99500729287`;
- package artifact `9764345117` (`r3dfox-gost-xp-x32-package`);
- run conclusion: **failure**.

The full workflow copied only the older narrow YY provider members (`ProcessPrng`, `GetSystemTimePreciseAsFileTime`, `FlsAlloc`, `FlsFree`, `FlsSetValue`, `IsThreadAFiber`, `SetThreadStackGuarantee`) and did **not** copy the five SRW `.obj/.obi` members that had been proven by run `33387080767`. Therefore the synthetic SRW success was not actually transferred into the Firefox link.

The job built and packaged Firefox but then failed at the post-package msvcr14x CRT-survival gate. Consequently the later broad `GATE - Audit XP x32 PE floor and direct imports` did not execute, so the SRW regression was not caught by CI before the package artifact was uploaded.

## Exact artifact/manual-runtime correlation

The package artifact `9764345117` was independently downloaded and its browser ZIP inspected. The user-tested files are exactly the files from that artifact:

- `r3dfox.exe` SHA-1 `562195fb0dfb9b6032069fd050ee8995efe74e62`;
- `xul.dll` SHA-1 `194184fd716ec9d916230fed087da4ea2c5ba28f`.

Physical Windows XP startup fails with:

```text
The procedure entry point AcquireSRWLockExclusive could not be located in the dynamic link library KERNEL32.dll.
```

Direct import inspection of the exact packaged artifact confirms the loader failure is real and expected. In particular:

- `r3dfox.exe` imports `AcquireSRWLockExclusive`, `ReleaseSRWLockExclusive`, `SleepConditionVariableSRW`, and `WakeAllConditionVariable` from `KERNEL32.dll`;
- `xul.dll` imports `AcquireSRWLockExclusive`, `InitializeConditionVariable`, `InitializeCriticalSectionEx`, `InitializeSRWLock`, `ReleaseSRWLockExclusive`, `SleepConditionVariableCS`, `SleepConditionVariableSRW`, `WakeAllConditionVariable`, and `WakeConditionVariable`;
- `mozglue.dll` imports `AcquireSRWLockExclusive`, `AcquireSRWLockShared`, `InitializeConditionVariable`, `InitializeCriticalSectionEx`, `ReleaseSRWLockExclusive`, `ReleaseSRWLockShared`, `SleepConditionVariableCS`, `SleepConditionVariableSRW`, `WakeAllConditionVariable`, and `WakeConditionVariable`.

Other separately linked shipped PEs in the same package also retain portions of this family (`mozinference.dll`, `mozavcodec.dll`, `mozavutil.dll`, `gkcodecs.dll`, `libGLESv2.dll`, `gmp-clearkey/0.1/clearkey.dll`). They must be solved at their own link/dependency boundary and must not be assumed fixed by a provider linked only into libxul.

## Complete synchronization family currently relevant to the XP audit

The project synchronization-family inventory is broader than the five APIs exercised by the successful SRW smoke. Current names are:

### SRW lock operations

- `AcquireSRWLockExclusive`;
- `AcquireSRWLockShared`;
- `ReleaseSRWLockExclusive`;
- `ReleaseSRWLockShared`;
- `InitializeSRWLock`;
- `TryAcquireSRWLockExclusive` where present in non-core/test PEs.

No current artifact evidence requires `TryAcquireSRWLockShared`; do not add it merely by symmetry without an observed caller/import.

### Condition-variable operations

- `InitializeConditionVariable`;
- `SleepConditionVariableCS`;
- `SleepConditionVariableSRW`;
- `WakeAllConditionVariable`;
- `WakeConditionVariable`.

The previously abbreviated `Wake*` notation means exactly `WakeAllConditionVariable` and `WakeConditionVariable`. These were omitted from the five-function SRW smoke coverage even though they are direct XP-incompatible imports in the full browser package. `WakeAllConditionVariable` is especially important because it is imported directly by `r3dfox.exe` itself.

### Related critical-section compatibility item

`InitializeCriticalSectionEx` is also a post-XP synchronization import in core browser PEs, but it is tracked separately from the SRW/condition-variable YY set because the preferred design is first to evaluate an XP-native fallback (`InitializeCriticalSection` / `InitializeCriticalSectionAndSpinCount`) at the owning abstraction rather than automatically thunk it.

## Current conclusion

The result of run `33387080767` remains valid: YY-Thunks can eliminate direct imports for its tested five-function SRW subset. The full Firefox package from run `33396056005` does not contain that integration and therefore cannot be used as evidence that the subset was transferred successfully.

The next synchronization experiment must not stop at those five names. Before another expensive full build, the intended core-browser coverage must explicitly account for the observed full family, at minimum:

- the five already-proven SRW calls;
- `InitializeSRWLock`;
- `InitializeConditionVariable`;
- `SleepConditionVariableCS`;
- `WakeAllConditionVariable`;
- `WakeConditionVariable`.

`TryAcquireSRWLockExclusive` should be covered only for a PE that actually imports it, and `InitializeCriticalSectionEx` should remain a separately classified source/native-fallback item unless caller analysis proves YY is the better boundary.

A dedicated post-link gate for the synchronization family must run immediately after the relevant final PEs exist, before packaging/CRT gates that can terminate the workflow early. A later package-level audit is still required because separately linked DLLs can retain the same imports independently.