# Windows XP x86 build contract

This document defines the mandatory build contract for the Windows XP SP3 x86 compatibility track. It applies to project-built or project-staged x86 runtime libraries and to the full XP x32 browser workflow. It is independent of GOST TLS handshake evidence.

## Physically proven reference

The current reference contract is proven by the focused `msvcr14x + Rust libstd + YY-Thunks / XP x86 SRW` experiment:

- branch: `agent/gost-tls-poc`;
- source-under-test: `b19ba4ff3eebd2f323743d92110241fc9d4ce399`;
- workflow: `msvcr14x Rust YY XP x86 SRW smoke`;
- Actions run `33387080767`, job `99472017220`;
- runtime artifact `9756275917` (`msvcr14x-rust-yy-xp-x86-srw-runtime`), digest `sha256:f5708981117e84ec1815554cc08494b79960464ccffcbdc1d6a70a099a1962d0`;
- diagnostics artifact `9756276724`;
- CI result: success;
- physical runtime result supplied by the user: the exact runtime artifact starts and executes successfully on a real Windows XP machine.

This supersedes the incompatible fresh-CRT result from source `89b236ad3289fcb9dc65b4bcabdf39d41f7f3be7`, run `33373236602`, job `99428838270`, whose app-local CRT closure contained PE subsystem 6.0 DLLs and hard post-XP imports and failed on physical XP with missing `KERNEL32!FlsGetValue`.

## Mandatory contract

Until a newer physically proven result explicitly supersedes this reference, every XP x86 build or compatibility experiment must preserve the following rules.

1. **Pin and restore the dependency graph before building.** For the current msvcr14x integration, build pinned commit `6495947edbdd8f5dc4b2ddb8ca0cb5dbdac05384` as Release x86 using the proven MSBuild restore/configuration path (`/restore` or `-r`) and preserve a binary log/provenance record. Do not substitute a host-installed Win7+ redistributable runtime.
2. **Target XP at build/link time.** Project-built or project-staged runtime PEs intended to load on XP must be x86 and have PE subsystem version 5.01 or lower before they are accepted into the runtime closure.
3. **PE retargeting is not compatibility.** `editbin /SUBSYSTEM:...,5.01` may correct the PE header of an otherwise XP-safe binary, but it must never be treated as proof that the binary is XP-compatible. A retargeted PE with hard imports absent from XP is still incompatible.
4. **Audit every app-local runtime closure before staging it.** A project-built dependency must fail fast if its DLLs retain known post-XP direct imports or forbidden post-XP dependency DLLs. For the msvcr14x CRT closure this includes the FLS and SRW/condition-variable families that caused or could reproduce the loader regression (`FlsAlloc`, `FlsFree`, `FlsGetValue`, `FlsSetValue`, `AcquireSRWLock*`, `TryAcquireSRWLock*`, `ReleaseSRWLock*`, `SleepConditionVariableSRW`) and the repository's broader curated XP import list.
5. **Prefer removing dependencies at their owner/build boundary.** If a DLL is built by this project or by a pinned source dependency under our control, first fix its source, build configuration, dependency selection, or legacy backend. Do not immediately hide its modern imports with broad YY-Thunks or a global shim.
6. **Keep separately linked components separate.** `xul.dll`, `mozglue.dll`, media/graphics DLLs, CRT DLLs, helper executables, and other independently linked PEs each own their import table. A linker change in one PE does not fix another.
7. **Keep diagnostics sufficient to reproduce provenance.** Record source commit, toolchain identity, restored dependency configuration, resolved output directory, PE headers, direct imports, SHA-256 hashes, and the exact staged files for each controlled runtime closure.
8. **Do not weaken a failing gate to obtain a green build.** A build/package success is only a build result. Physical XP runtime remains a separate acceptance gate, and GOST TLS remains a separate project track.

## Adopted `bcrypt.dll` remediation

The project no longer treats the missing stock-XP `bcrypt.dll` dependency as an unresolved architectural blocker.

The user selected an XP-compatible `bcrypt.dll` from the `shorthorn-project/One-Core-API-Binaries` project as the compatibility implementation for this dependency:

- upstream repository: `https://github.com/shorthorn-project/One-Core-API-Binaries`;
- upstream branch used as the source location: `master`;
- remediation class: vetted third-party XP compatibility implementation / staged dependency replacement;
- intended scope: satisfy the direct `bcrypt.dll` dependency reported for core browser PEs such as `xul.dll` and `mozglue.dll` on stock Windows XP.

This decision is independent of the SRW/condition-variable work and must not be counted as one of the remaining post-XP API imports. The remaining API inventory should therefore be discussed separately from the already-selected `bcrypt.dll` dependency remediation.

For reproducible CI/package adoption, the exact `bcrypt.dll` binary that is staged must still be pinned by upstream path/revision or immutable artifact identity, SHA-256, PE subsystem/import closure, required export surface, license/provenance record, package-survival gate, and physical-XP runtime evidence. Those reproducibility checks refine the adopted solution; they do not reopen the architectural decision to use the One-Core-API implementation.

Detailed status and provenance expectations are recorded in `XP_BCRYPT_STATUS.md`.

## Full-build migration rule

The full XP x32 workflow must use the same msvcr14x build procedure as the physically proven focused smoke and must gate the CRT closure before the expensive Firefox build proceeds. Once a self-built dependency family is brought under this contract, later full-build work should keep that family green and move to the next remaining owner/component reported by the broad final PE/import audit.

The intended remediation order is therefore:

1. make project-built/staged dependency closures intrinsically XP-compatible;
2. classify and remediate Firefox-owned imports at their source abstraction when practical;
3. handle separately linked third-party/shipping DLLs at their own build or replacement boundary;
4. use the narrowest justified YY provider only for residual unavoidable low-level gaps;
5. run the full final import audit and then test the exact artifact on physical XP.

Exact experiment evidence belongs in `TEST_LOG.md`; current synthesis belongs in `PROJECT_STATE.md`; pending migration work belongs in `TODO.md`.