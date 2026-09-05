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

## Adopted source-built `bcrypt.dll` remediation — SINGLE-DLL / PHYSICALLY PROVEN

The project no longer treats the missing stock-XP `bcrypt.dll` dependency as an unresolved focused dependency/runtime blocker.

The adopted implementation is built from pinned One-Core source rather than taken as an opaque prebuilt binary:

- upstream repository: `shorthorn-project/One-Core-API-Source`;
- pinned upstream source commit: `9eb3c31de9460c1ccce3f6a10c9c4a704f032514`;
- source components: `dll/win32/bcrypt` plus the pinned active C modules from `dll/3rdparty/mbedtls`;
- build environment: RosBE 2.1.6 i386;
- project source-under-test: `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- workflow: `One-Core bcrypt source XP x86 smoke`;
- Actions run `33513084915`, job `99873297193`, success;
- runtime artifact `9802703271`, digest `sha256:e6ea796ef5f7dfb67e346630cd6432c9659e6d90d39ce90b8f44a1b3632edc8f`;
- diagnostics artifact `9802704126`, digest `sha256:d989ce72af60185cb16b0ff99d156ed39170beab00055e776b881ee2cc54e6de`.

The adopted runtime closure is a single deployable DLL:

`bcrypt.dll -> XP system DLLs`

with the required mbedTLS C implementation compiled directly into `bcrypt.dll`; there is no runtime `mbedtls.dll` dependency.

Build-composition requirements for this exact contract:

- use the pinned active mbedTLS C source set proven by the smoke;
- compile those C sources directly as private sources of the bcrypt target;
- do not link the separate `mbedtls` DLL/import-library target into bcrypt;
- preserve normal bcrypt/Wine compile context for `bcrypt_main.c`;
- apply `-U__WINESRC__` to the embedded mbedTLS C sources so their compile semantics match the standalone mbedTLS target that previously built successfully;
- do not patch bcrypt or mbedTLS C implementation source merely to force the build.

The focused gate audits the resulting single `bcrypt.dll` and both consumer executables for PE floor and known post-XP hard imports, requires the final DLL not to import `mbedtls.dll`, and verifies the required BCrypt export surface.

On physical Windows XP SP3 x86 (`Microsoft Windows XP [Version 5.1.2600]`), the user ran exact runtime artifact `9802703271`. The extracted runtime directory contained only one DLL, `bcrypt.dll` (`520704` bytes), and no `mbedtls.dll`. Both consumers loaded the app-local `bcrypt.dll`, reported `EXPORTS PASS`, `RNG PASS`, `SHA256 PASS`, and returned exit code `0` through both exact-local dynamic loading and ordinary linked/IAT resolution.

Physical-file identity recorded by the user for the proven DLL:

- size: `520704` bytes;
- SHA-1: `ae021f44edc48b03bb4d67cb5773b62bdf60cb67`;
- SHA-256: `f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`.

Therefore the single-DLL source-built bcrypt closure satisfies the physical-runtime requirement of this contract at focused dependency scale and is the selected implementation for full-browser transfer.

### Canonical reusable binary distribution

The exact physically proven binary is published as a raw GitHub Release asset in this repository so full Firefox builds and experiment branches do not need to rebuild One-Core on every run:

- tag `xp-bcrypt-v1`;
- tag target `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- release `XP bcrypt primitive v1`, release ID `380563342`, prerelease/technical distribution;
- release asset ID `539647946`;
- asset name `bcrypt.dll`;
- asset size `520704` bytes;
- asset digest `sha256:f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`.

Publication was performed by source `76225fcf95e4e484f0cec30c8e25a235119b0256`, workflow run `33518189052`, job `99890447193`. That publisher source is infrastructure identity only; it does not replace `a30a701...` as the source-under-test for the binary.

Consumption contract for full/browser workflows and other branches:

1. obtain `bcrypt.dll` from release tag `xp-bcrypt-v1` (an Actions cache may be used only as an acceleration layer);
2. require exact SHA-256 `f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193` and size `520704` before staging;
3. on cache miss, download the canonical release asset; **do not silently rebuild One-Core** inside the heavy Firefox workflow;
4. stage only `bcrypt.dll`; no `mbedtls.dll` belongs to the selected runtime closure;
5. preserve PE/import and post-package survival gates after staging.

The focused One-Core smoke remains the build/provenance path for producing a future replacement. A replacement must receive a new tag/version and physical XP proof before it supersedes `xp-bcrypt-v1`.

The earlier physically proven two-DLL source-built closure remains historical fallback/baseline evidence:

- source `fdd4d4dac5a7d9611ec71975ae800437f45c47dd`;
- run `33493625367`, job `99810642354`;
- runtime artifact `9794971087`;
- closure `bcrypt.dll -> mbedtls.dll -> XP system DLLs`.

It is no longer the selected packaging contract. The earlier prebuilt forwarder/Code-Integrity experiments remain historical evidence only and must not be mixed with either source-built closure.

Full-browser adoption is still a separate integration step: consume the exact `xp-bcrypt-v1` raw release asset, verify its fixed SHA-256/size, stage only `bcrypt.dll`, preserve provenance/import/package-survival gates, and test the resulting exact browser artifact on physical XP. Independent SRW/condition-variable and other post-XP imports remain separate blockers.

Detailed status is recorded in `XP_BCRYPT_STATUS.md`.

## Full-build migration rule

The full XP x32 workflow must use the same msvcr14x build procedure as the physically proven focused smoke and must gate the CRT closure before the expensive Firefox build proceeds. Once a self-built dependency family is brought under this contract, later full-build work should keep that family green and move to the next remaining owner/component reported by the broad final PE/import audit.

The intended remediation order is therefore:

1. make project-built/staged dependency closures intrinsically XP-compatible;
2. classify and remediate Firefox-owned imports at their source abstraction when practical;
3. handle separately linked third-party/shipping DLLs at their own build or replacement boundary;
4. use the narrowest justified YY provider only for residual unavoidable low-level gaps;
5. run the full final import audit and then test the exact artifact on physical XP.

Exact experiment evidence belongs in `TEST_LOG.md`; current synthesis belongs in `PROJECT_STATE.md`; pending migration work belongs in `TODO.md`.