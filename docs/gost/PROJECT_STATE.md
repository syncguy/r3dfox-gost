# r3dfox GOST TLS — Project State

Last updated: 2026-09-03

This file is the authoritative current technical synthesis and handoff for new chats. Detailed experiment evidence belongs in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes; closed milestones are in `DONE.md`; pending work is in `TODO.md`; workflow roles are in `WORKFLOWS.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default GOST development branch and canonical documentation source: `agent/gost-tls-poc`.
- Windows XP SP3 x86 compatibility implementation branch: `agent/winrt-source-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the active work branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer base.

For Windows XP work, read `XP_BUILD_CONTRACT.md` and, for source compile-out rules, `XP_MOZ_XP_COMPAT_CONTRACT.md` before proposing build/configuration changes.

## Separation of conclusions

Keep these tracks independent unless a deliberately combined experiment tests both:

1. GOST TLS runtime / NSS / NSPR / MSSPI / SSPI / CryptoPro / handshake.
2. Windows Vista/7/XP compatibility / Rust / msvcr14x / YY-Thunks / linker / PE imports / physical runtime.
3. Bundled government-system extensions and localization/package behavior.

A successful build is not a successful GOST handshake. A hosted compatibility probe is not physical-XP proof. Win7 x86 runtime success is not XP import closure. A documentation commit is never the source-under-test SHA for an earlier artifact.

# GOST TLS runtime

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

Current runtime constraints include:

- TLS 1.2 / HTTP/1.1 PoC path;
- coordinated Firefox client-auth picker as default;
- `Session` is the current default positive certificate choice and remains process-local;
- true persistent `Permanent` semantics remain open;
- final fail-closed server verification remains open;
- synchronous provider/key access can still block the shared Firefox Socket Thread during long CryptoPro waits.

Current authoritative Session-default browser source is `afbdad307f63e594d3715169d6e34235280dddaf`, full build run `33073577269`, job `98521835354`, release artifact `9652941006`.

Current GOST runtime work remains: persistent `Permanent` semantics, provider-boundary testing, provider-wait comparison with stock Firefox, and final fail-closed server trust / certificate-override integration.

# Windows XP SP3 x86 compatibility

This track is independent of GOST TLS runtime. Active implementation work is on `agent/winrt-source-poc`; documentation remains on `agent/gost-tls-poc`.

## Closed compatibility families

Do not reopen without new contradictory evidence:

- SRW / condition-variable family: source `d65b464c74caadace97995f07a4919363c41a0ea`, run `33470957048`, job `99740439208`;
- `CreateWaitableTimerExA`: source-level fallback closure, source `17cdb459ec4f115a209fd50ac225cf867b9f3a2f`, run `33638897692`, job `100276666021`;
- selected single-DLL `bcrypt.dll`: source `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`, run `33513084915`, job `99873297193`, physically proven on Windows XP and published as `xp-bcrypt-v1`;
- legacy `D3DCompiler_47.dll` staging/packaging: source `b77b22ef1e35564dfe76997d3d393d45ee697e49`, run `33349340069`, job `99359475336`.

Full YY `kernel32.lib` interposition remains prohibited. Keep per-PE/provider ownership narrow.

## Latest completed full XP x32 build/package evidence

The latest completed full-browser compatibility run is:

- experiment branch `agent/winrt-source-poc`;
- exact source-under-test `f602df1b2f3c9b85a4b938a4ea57b07373ac9a95`;
- workflow `GOST TLS PoC build  XP x32`;
- Actions run `33738262420`, job `100593897593`, attempt `1`;
- aggregate conclusion: **failure** at the final evidence summary, after successful compile/package and artifact preservation.

Exact artifacts from this run:

- package artifact `9891436211`, digest `sha256:277f4584bc95a8b425c640db01d18078cdd9ab307caa33bbc8fc2940457ed362`;
- runtime artifact `9891437190`, digest `sha256:a9f8d9598f431f757fcc63c3796dcc600af48371236cf0586e18f5bd9e323cf3`;
- diagnostics artifact `9891438460`, digest `sha256:a421a0cabbfcb151120842e4525b2296011c2c1bc127808e1cfaf52d0e1f612a`.

Full build, production core-browser import gate, D3D staging/retarget/package survival, CRT staging/package survival, bcrypt staging/package survival, runtime-archive creation and all three artifact uploads are GREEN. The final run-level RED is not a compile/package failure; the summary promotes the deliberately non-fatal broad all-PE import audit outcome.

The authoritative broad forbidden-import report is now reduced to exactly three rows, all in GMP test DLLs:

- `gmp-fake/1.0/fake.dll` -> `FlsGetValue`;
- `gmp-fake/1.0/fake.dll` -> `TryAcquireSRWLockExclusive`;
- `gmp-fakeopenh264/1.0/fakeopenh264.dll` -> `FlsGetValue`.

This supersedes run `33718674533` as current completed full-build inventory evidence and materially narrows its **69 broad findings to 3**. The production core-browser gate remains GREEN. The source-remediation quartet diagnostic is informational/non-blocking and reports `GetApplicationRestartSettings` and `GetNamedPipeServerProcessId` as surviving in its focused `xul.dll` check, but neither appears in the authoritative broad forbidden-import report for the final distribution audit.

The three residual rows are confined to fake/test GMP PEs and are not evidence of a production core-browser regression. Nevertheless, the current full workflow is intentionally re-running with narrow YY provider coverage for both residual API names so the same exhaustive all-PE audit can determine whether the report reaches zero without weakening or excluding the audit.

## Provisional full-build rerun for the residual three imports

A new full XP x32 build is currently **in progress** and must not yet be treated as passed evidence:

- experiment branch `agent/winrt-source-poc`;
- exact source-under-test `2b1cf7e1b59881b935c7f695a54edd6b92c8066e` (`ci(xp): add residual YY KERNEL32 providers`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33757305364`, attempt `1`;
- job `100654730312`;
- current state at documentation time: **in_progress**.

The source change adds `TryAcquireSRWLockExclusive` and `FlsGetValue` to the existing physically narrow YY KERNEL32 provider selection. The existing workflow machinery therefore extracts the corresponding YY `.obj` + `.obi` members and verifies their `YY_Thunks_*` symbols while continuing to prohibit full YY `kernel32.lib` injection into global target LDFLAGS.

Focused capability for exactly these two residual API names was already proven GREEN by workflow `XP x86 core KERNEL32 cluster smoke`, run `33741674218`, job `100604798167`, source `d6391b43f6af91ed2548372a59fc7a5bfe26a5e9`. That focused smoke is provider/link capability evidence only; run `33757305364` is the full-Firefox integration check.

Until run `33757305364` completes, the authoritative completed inventory remains **3 rows**, not zero. Do not mark the broad import gate GREEN, do not promote a new runtime artifact, and do not infer physical Windows XP startup or GOST TLS handshake behavior from the running build.

Current compatibility next step: inspect the completed result of exact run `33757305364`. If its exhaustive broad import audit is GREEN, bind the resulting package/runtime/diagnostics artifacts and advance the exact physical-XP startup candidate. If any hard imports remain, classify them from that run's exact diagnostics rather than reopening already-closed production core-browser families.

Runtime artifact `9891437190` from completed run `33738262420` remains the newest accepted physical Windows XP startup candidate until the in-progress rerun produces and passes its artifact/gate chain. Physical XP must determine whether startup advances beyond the last documented loader edge `KERNEL32!InitOnceExecuteOnce`.

No GOST TLS runtime or handshake conclusion follows from either compatibility build.

## Residual low-level YY line

Focused proof exists for:

- `InitOnceExecuteOnce`;
- `GetThreadPreferredUILanguages`;
- `QueryFullProcessImageNameA`.

Evidence: source `ffb72c4ae6988a7c4f82b4e67a9027e41afb572b`, workflow `XP x86 core KERNEL32 cluster smoke`, run `33712987285`, job `100516220327`.

Focused proof also exists for the two API names behind the last three broad-audit rows:

- `TryAcquireSRWLockExclusive`;
- `FlsGetValue`.

Evidence: source `d6391b43f6af91ed2548372a59fc7a5bfe26a5e9`, workflow `XP x86 core KERNEL32 cluster smoke`, run `33741674218`, job `100604798167`, result GREEN.

These smokes prove focused capability only, not full Firefox integration or physical-XP startup. Run `33738262420` retains the production core-browser gate GREEN and reduces the completed authoritative broad report to the three GMP test-DLL imports listed above. Run `33757305364` is the current full-scale integration attempt for the final two API names. Physical XP remains the final runtime boundary.

The last documented physical XP loader edge remains `KERNEL32!InitOnceExecuteOnce` until a newer exact physical-XP artifact advances beyond it.

## KERNEL32 source-remediation quartet — source-integrated

The quartet:

- `GetApplicationRestartSettings`;
- `RegisterApplicationRestart`;
- `UnregisterApplicationRestart`;
- `GetNamedPipeServerProcessId`;

is now **SOURCE-INTEGRATED / CONDITIONALLY CLOSED** on `agent/winrt-source-poc`.

Exact implementation/configuration chain:

1. `194496e76559e1d86e7e3f920fb3f1fc0e46c2d7` — disable Windows Application Restart under `MOZ_XP_COMPAT`;
2. `20f00258ac59296782fbaffbf0131d636c0d3c00` — define `MOZ_XP_COMPAT` for `nsAppRunner.cpp`;
3. `561bded451638e599fae2d57285446261f9a0035` — disable modern UIA client detection under `MOZ_XP_COMPAT`;
4. `ebe325ad87232f68ca01d7e4c63be14f9c4ee74b` — define `MOZ_XP_COMPAT` for `CompatibilityUIA.cpp`.

The work branch reached exact HEAD `ebe325ad87232f68ca01d7e4c63be14f9c4ee74b` after this chain.

### Application Restart

Production owner: `toolkit/xre/nsAppRunner.cpp`.

For the XP translation unit, the complete `RegisterApplicationRestartChanged` callback and its preference registration are compiled out under `MOZ_XP_COMPAT`. The surrounding Windows startup facilities remain intact. The XP release does not emulate the Vista+ Application Restart facility.

### Modern UIA client detection

Production owner: `accessible/windows/msaa/CompatibilityUIA.cpp`.

For the XP translation unit, Win10/Win11 UI Automation client-detection implementations are compiled out and `Compatibility::GetUiaClientPids` is a no-op. The XP release intentionally does not preserve these newer-OS features. This supersedes the earlier proposed dynamic-resolution approach for `GetNamedPipeServerProcessId`.

Because `CompatibilityUIA.cpp` was a unified source, it was moved to ordinary `SOURCES` before receiving its source-local compatibility define.

Detailed status: `XP_KERNEL32_SOURCE_REMEDIATION_STATUS.md`.

## Mandatory `MOZ_XP_COMPAT` build rule

`MOZ_XP_COMPAT` is now the preferred project-owned compile-time signal for new XP-specific source removal where a modern Windows feature has no useful XP semantic equivalent.

For every production translation unit containing an accepted `MOZ_XP_COMPAT` boundary, the XP build MUST define `MOZ_XP_COMPAT` for that exact owner. Prefer source-local configuration:

```python
SOURCES["Owner.cpp"].flags += ["-DMOZ_XP_COMPAT"]
```

If the owner is in `UNIFIED_SOURCES`, move only that source to ordinary `SOURCES` before assigning the source-specific flag.

Do not make `MOZ_XP_COMPAT` a global Firefox define without a separate architectural decision. Existing `MOZ_NO_WINRT` remediations remain valid and do not need renaming merely for consistency.

Authoritative rules: `XP_MOZ_XP_COMPAT_CONTRACT.md`.

## Evidence boundary after source closure

The project intentionally does not require isolated Mozilla partial builds merely to re-prove accepted source guards. Mozilla's build graph is tightly coupled; accepted source changes ride otherwise-justified full XP browser builds.

Run `33738262420` proves that the full Firefox x32 build/package and runtime-archive boundaries complete with the current dependency/package contract while the authoritative broad inventory is down to three GMP test-DLL hard imports. Run `33757305364` is a provisional full rebuild with narrow YY coverage for the two API names responsible for those three rows; its result is not evidence until completion. Future full builds must retain the inventory-driven PE/import audit. Source removal or a GREEN curated core gate does not by itself prove complete distribution import closure or physical Windows XP startup.

Final XP acceptance remains:

1. exact source-under-test SHA;
2. successful full XP x32 build/package under the established build contract;
3. inventory-driven audit of the complete required PE closure, distinguishing hard imports from delay-loads and shipped/runtime-required PEs from test-only/non-shipped PEs;
4. exact artifact identity/hashes;
5. physical Windows XP execution.

A curated known-API list remains a regression gate, not exhaustive compatibility proof.

## XP dependency/build contract

- pinned/restored msvcr14x Release x86 remains mandatory; do not substitute host Win7+ redistributables;
- x86 PE subsystem must be 5.01 or lower for XP runtime PEs;
- `editbin` header retargeting alone is never compatibility proof;
- project-controlled modern dependencies should first be removed/remediated at source/build/subsystem boundary;
- separately linked PEs own separate import tables;
- successful focused/full build is not physical-XP runtime proof.

`XP_BUILD_CONTRACT.md` remains authoritative.

# Bundled government-system extensions / localization

Current proven three-extension packaging checkpoint remains source `b3d097de20b7a5711f161199a727bcfe9468bcc8`, run `32976571122`, job `98202641607`.

Current corrected Russian localization package gate is source `3e2c32386f373d4693db52b32c05aa2000878def`, workflow `CryptoPro Mozilla packaging smoke`, run `33520207057`, job `99897230730`, success. The previous mass-empty Russian payload defect and final path-shape false negative are closed.

Manual runtime evidence belongs to the exact artifact on which it was observed; do not reattribute it to later packaging-only correction builds.

# Global evidence rules

- Build success != GOST handshake success.
- GOST runtime success != final server-trust closure.
- Focused dependency/runtime success != full Firefox startup.
- Win7 x86 startup != XP startup.
- Source/build removal of a hard import != physical-XP runtime closure until the exact accepted artifact advances past that edge.
- Documentation HEADs never replace the exact source-under-test SHA for previously built or runtime-tested artifacts.
- For in-progress runs, record provisional state and never mark a pending gate as passed.