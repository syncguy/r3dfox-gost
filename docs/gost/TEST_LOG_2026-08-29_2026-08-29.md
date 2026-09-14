# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-27_2026-08-28_part2.md`](./TEST_LOG_2026-08-27_2026-08-28_part2.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. For current technical synthesis, see [`PROJECT_STATE.md`](./PROJECT_STATE.md). For forward work, see [`TODO.md`](./TODO.md). For the detailed source-level WinRT experiment design, see [`WINRT_SOURCE_POC.md`](./WINRT_SOURCE_POC.md). For formally closed milestones, see [`DONE.md`](./DONE.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-08-29 — YY-Thunks expansion is retired as the primary remedy for the Win7 WinRT delay-load blocker

**Track:** Windows compatibility / Win7 x32 WinRT delay-load remediation strategy  
**Branch reviewed:** `agent/gost-tls-poc`  
**First dedicated WinRT YY smoke source:** `90067edba48fd4e8bb986ced02a47ae2189e9fb3` (`ci(win7): add WinRT YY-Thunks delay-load smoke`)  
**Final reviewed source:** `3ebfef1ddbb70b0d2b29f160dabcaa8fbef4fab5` (`ci(win7): link OLE32 in WinRT smoke`)  
**Final workflow:** `msvcr14x Rust YY XP x86 coexistence smoke`  
**Final run:** `33186862417`, run number `31`  
**Final job:** `98901994671`  
**Final result:** failure

### Scope of this decision

This finding is deliberately narrow. It does **not** reject YY-Thunks as a project dependency or as a tool for bounded old-Windows Win32 compatibility gaps. The representative XP x86 coexistence workload remains physically runtime-proven on source `d78137a931145af877dc458b01e494ad0467723d`, run `33138244191`, job `98743029100`, runtime artifact `9673057839`, with three physical XP SP3 x86 executions returning `ExitCode=0`.

The retired strategy is specifically:

> keep Firefox 153's WinRT consumers intact and keep extending the project's narrow YY-Thunks provider / link harness until the entire WinRT activation/string delay-load surface and its transitive dependencies link and run on legacy Windows.

The proven Win7 blocker itself is unchanged and remains bound to source `982d6529a707c6feecad97c725feed8a3cd21c81`, run `33141004769`, job `98751650853`, runtime artifact `9676549576`: `xul.dll` delay-loads `api-ms-win-core-winrt-l1-1-0.dll`, reaches `RoGetActivationFactory`, Win7 reports `ERROR_MOD_NOT_FOUND (0x7e)`, and the MSVC delay-load helper raises `0xc06d007e`.

### Run-history / change-history signal

The dedicated YY WinRT line began at `90067edba48fd4e8bb986ced02a47ae2189e9fb3` on 2026-08-28 12:21 UTC and reached `3ebfef1ddbb70b0d2b29f160dabcaa8fbef4fab5` at 15:47 UTC, about 3 h 26 min later.

Between those two points the branch accumulated **26 additional commits**. A direct compare shows that almost all code churn was concentrated in `.github/workflows/msvcr14x-rust-yy-xp-x86-coexistence-smoke.yml`: 171 additions and 174 deletions, 345 changed lines, while only 9 lines changed in `docs/gost/TODO.md`.

The important signal is not net YAML length but the semantic expansion of the compatibility surface. The commit history repeatedly moved the boundary outward:

- introduce WinRT YY delay-load smoke;
- switch to YY `runtimeobject` WinRT aliases and then a compact YY object package;
- isolate the delay-load probe from the normal `delayimp` runtime;
- generate correct x86 WinRT import aliases;
- add harness/runtime stubs for `_purecall`, operator delete, `atexit`, `wcsrchr`, `free`, and `malloc`, including a MASM detour for the isolated `wcsrchr` stub;
- add system libraries one after another: `ADVAPI32`, `GDI32`, `USER32`, `VERSION`, `NTDLL`, `OLEAUT32`, then `OLE32`.

This is exactly the failure mode the project's narrow-provider policy was intended to avoid: a supposedly surgical compatibility shim begins reconstructing an expanding transitive Windows/WinRT support environment around the imported implementation rather than closing one stable API boundary.

### Final run evidence

Run `33186862417`, job `98901994671`, source `3ebfef1ddbb70b0d2b29f160dabcaa8fbef4fab5` is the decisive stopping point for this strategy.

The run successfully reached the narrow-provider/WinRT-link probe far enough to show that the previously targeted WinRT activation/string import groups and accumulated supporting objects/libraries were being incorporated. It did **not** close the synthetic WinRT gate. The final link failed on another newly exposed dependency:

`__imp__StrCmpLogicalW@8`

Thus after adding the WinRT aliases, shared YY implementation support, CRT/harness stubs and a growing sequence of Windows system libraries, the result was not a bounded completed provider but the next outward dependency (`StrCmpLogicalW`, from the shell/string-comparison support surface).

The workflow's final metadata is also material: this was run number `31`, still red, and the strategy had not yet reached a successful full `xul.dll` closure or physical Win7 runtime validation for the WinRT blocker.

### Conclusion

**STRATEGY DECISION — CLOSED AS UNPROMISING FOR THIS WINRT BLOCKER.**

Do not continue the present approach by blindly adding the next YY alias, CRT stub, import library, Windows system library or hand-written harness dependency revealed by the synthetic WinRT link probe. The evidence shows an unbounded/transitive portability surface and poor leverage: substantial iterative compatibility work is being spent before reaching the actual Firefox `xul.dll`/physical-Win7 proof boundary.

This does not mean a YY thunk may never appear in the final legacy-Windows solution. YY-Thunks remains appropriate for small, stable, evidence-bounded Win32 imports. If source-level WinRT removal later leaves one or a few unavoidable imports with narrow and well-defined semantics, a surgical YY shim may be reconsidered for those residual imports. What is retired is **YY-Thunks expansion as the primary mechanism for carrying Firefox's WinRT feature surface onto Win7/XP**.

The active primary direction for the WinRT blocker is now source-level removal/fallback of nonessential WinRT consumers, currently isolated in `agent/winrt-source-poc`. That PoC is still unvalidated: runs `33242986136` / job `99075394860` / source `f6e87ba87919f999d2a3ec6c2b9ba103fea1d99e` and `33243005271` / job `99075448278` / source `f1c55320f77a9ff932fa3e6cca2bc2443c20ec45` both fail at `Build export prerequisites` before their target proof gates. Promoting source removal to the primary direction is therefore a strategy choice based on the negative YY scaling evidence, **not** a claim that the source-removal PoC already works.

No GOST TLS runtime/handshake conclusion follows from this strategy decision.

Status: current; YY WinRT-expansion path retired for this blocker, source-level WinRT removal/fallback is the primary active experiment, residual bounded YY use remains allowed if later evidence justifies it.

---

## 2026-08-29 — WinRT source-removal PoC documented as an alternative to narrow YY-Thunks coverage; current validation runs fail before target proof gates

**Track:** Windows compatibility / Win7 x32 WinRT delay-load remediation  
**Main/default branch recorded in:** `agent/gost-tls-poc`  
**Main comparison base:** `3ebfef1ddbb70b0d2b29f160dabcaa8fbef4fab5`  
**Experimental branch:** `agent/winrt-source-poc`  
**Experimental HEAD reviewed:** `f1c55320f77a9ff932fa3e6cca2bc2443c20ec45` (`ci(xp): dispatch full build for WinRT legacy PoC`)  
**Compare relation at review:** 8 commits ahead, 0 behind; 11 changed files; 336 additions / 989 deletions

### Motivation and relation to the proven Win7 blocker

The source-removal branch addresses the already-proven later Win7 parent/browser crash from exact Firefox x86 source `982d6529a707c6feecad97c725feed8a3cd21c81`, run `33141004769`, job `98751650853`, runtime artifact `9676549576`.

That physical Win7 evidence remains authoritative for the failure itself:

`xul.dll` delay-load -> missing `api-ms-win-core-winrt-l1-1-0.dll` -> attempted `RoGetActivationFactory` -> `ERROR_MOD_NOT_FOUND (0x7e)` -> MSVC delay-load exception `0xc06d007e` -> unhandled parent/browser crash.

The adjacent exact `xul.dll` delay-load group also contains WinRT string APIs (`WindowsCompareStringOrdinal`, `WindowsCreateString`, `WindowsCreateStringReference`, `WindowsDeleteString`, `WindowsGetStringRawBuffer`).

The main branch already has one remediation hypothesis: expose only the precise YY-Thunks 1.2.2 WinRT alias/import members needed by these proven `xul.dll` imports, preserving the project's narrow-provider strategy.

`agent/winrt-source-poc` explores a second, independent hypothesis: **remove or replace nonessential Firefox WinRT consumers at source level so the legacy build no longer carries the problematic WinRT dependency surface.** This is a Windows compatibility experiment only; it does not modify or prove the GOST TLS handshake/runtime path.

### Source-level design observed in `agent/winrt-source-poc`

The reviewed diff intentionally degrades selected modern Windows integrations while preserving interfaces or existing Firefox fallbacks:

- `widget/windows/ToastNotification.cpp` / `.h`: the large WinRT-backed toast implementation is replaced by a compact ABI/XPCOM-compatible stub. WinRT-specific initialization/show/XML/tag/install operations return `NS_ERROR_NOT_IMPLEMENTED`; teardown/close/history-style behavior remains safe where appropriate.
- `toolkit/components/alerts/nsAlertsService.cpp`: when the platform/system alerts backend is unavailable, Firefox falls through to `nsXULAlerts`, giving the intended legacy behavior `no WinRT system toast -> XUL alert fallback` instead of making notification delivery depend on WinRT.
- `widget/windows/OSKInputPaneManagerLegacy.cpp`: retains the `OSKInputPaneManager` call surface but implements the WinRT InputPane show/dismiss operations as no-ops.
- `widget/windows/rust/Cargo.toml`: removes the Windows widget crate's `windows` / `windows-core` dependency on the PoC path rather than retaining the broad windows-rs WinRT feature surface.
- `widget/windows/rust/src/lib.rs`: retains `nsIAlertsServiceRust` but returns an empty toast history and omits WinRT-backed notification/taskbar/UI modules.
- `widget/windows/rust/src/permission_monitor.rs`: retains the XPCOM object but returns `NS_ERROR_NOT_IMPLEMENTED` from `StartMonitoring()` because WinRT `AppCapability` has no implemented legacy equivalent in this PoC.
- `toolkit/system/windowsPackageManager/moz.build` and `widget/windows/moz.build`: selected source files are compiled with `-D__MINGW32__` to reuse existing non-WinRT conditionals under clang-cl; the widget build also selects the legacy InputPane implementation and excludes `ToastNotificationHandler.cpp` from the intended legacy path.

This is broader than merely patching one `RoGetActivationFactory` caller. The PoC deliberately asks whether Firefox 153 can be built for old Windows with a reduced modern-Windows feature set rather than requiring a growing loader-emulation surface.

### Architectural assessment recorded for future work

Keep two remediation strategies distinct until exact evidence selects one:

1. **Narrow YY-Thunks coverage:** preserve Firefox's WinRT consumers but satisfy only the proven activation/string imports through precisely selected YY-Thunks members. This minimizes source divergence and preserves more modern Windows behavior, but each newly observed WinRT dependency may require another carefully selected alias/member and runtime semantics still need validation.
2. **Source-level WinRT removal/fallback:** explicitly omit unsupported/nonessential modern Windows features on legacy targets. This may remove the import class at the feature boundary, but it creates greater Firefox source divergence and can disable more functionality than necessary.

The PoC's `__MINGW32__` macro spoofing is acceptable only as an isolation technique. It is not a preferred final architecture because `__MINGW32__` describes a toolchain while the build still uses clang-cl. If the source-removal strategy survives validation, replace this with a narrowly scoped explicit legacy/no-WinRT build capability and audit every conditional it controls.

Likewise, do not assume that removing the entire Rust `windows` dependency is the final minimal answer: windows-rs exposes ordinary Win32 APIs as well as WinRT. A successful PoC should be reduced to the smallest necessary WinRT exclusion while restoring unrelated Win32 functionality/dependencies where possible.

Expected functional cost of the current PoC includes at least native WinRT toast notifications/history/tag/XML behavior, WinRT InputPane/on-screen-keyboard integration, WinRT AppCapability permission monitoring, and related Rust-side WinRT notification/taskbar/UI paths. These losses may be acceptable for a legacy browser only if ordinary browser runtime/regression testing proves the fallback behavior sufficient.

### Targeted CI evidence: run `33242986136`

**Workflow:** `WinRT source PoC x86`  
**Source-under-test:** `f6e87ba87919f999d2a3ec6c2b9ba103fea1d99e` (`xp: replace WinRT alerts with legacy fallbacks`)  
**Run:** `33242986136`  
**Job:** `99075394860` (`Firefox source WinRT isolation / x86`)  
**Result:** failure

The job successfully completed checkout, exact identity recording, `GATE - Verify intended source isolation`, MozillaBuild installation, x86 mozconfig, bootstrap and x86 configure.

It then failed at `Build export prerequisites`.

The decisive proof steps were therefore skipped:

- `GATE - Compile WinRT-related target objects`;
- `GATE - Disabled legacy paths have no WinRT API references`.

Conclusion from this run is deliberately narrow: the source-isolation precondition is present, but the run does **not** prove that the changed WinRT-related objects compile and does not prove that their references/imports are free of the targeted WinRT APIs.

### Full XP x32 workflow evidence: run `33243005271`

**Workflow:** `GOST TLS PoC build  XP x32`  
**Source-under-test:** `f1c55320f77a9ff932fa3e6cca2bc2443c20ec45` (`ci(xp): dispatch full build for WinRT legacy PoC`)  
**Run:** `33243005271`  
**Job:** `99075448278` (`Windows x86 / r3dfox GOST / XP SP3 full build`)  
**Result:** failure

This run successfully completed the compatibility setup through Firefox configure, including pinned MSSPI preparation/source registration, MSVC x86 setup, pinned Rust x86 target, msvcr14x Release x86 build, YY-Thunks 1.2.2 download, construction of the narrow YY XP x86 provider and the libxul compatibility-layer linker patch.

It also failed at `Build export prerequisites`.

The subsequent SSL compile gate, full Firefox build, runtime staging, packaging and final XP PE/direct-import audit were skipped. Therefore this run produced no full Firefox/xul result that can be used to decide whether the source-removal PoC eliminates the WinRT imports.

### Current conclusion / required next proof

**The source-removal idea is now a documented architectural candidate, not a validated fix.** Both relevant current Actions runs are bound to exact source SHAs and fail before the gates needed to establish the central claim.

Not yet proven:

- target WinRT-related object compilation;
- successful full `xul.dll` link;
- disappearance of `api-ms-win-core-winrt-l1-1-0.dll` / WinRT string API-set delay imports;
- absence of a reachable `RoGetActivationFactory` delay-load path;
- physical Win7 startup/stability through the previously observed later-crash interval;
- physical XP runtime;
- sufficiency of the intended feature fallbacks;
- any GOST TLS behavior.

Required sequence before considering integration into `agent/gost-tls-poc`:

1. repair the PoC branch's `Build export prerequisites` failure without weakening source isolation;
2. pass targeted compilation of the modified WinRT-related objects;
3. pass object/reference inspection for the disabled paths;
4. complete an exact full x86 Firefox/xul build and package;
5. audit final `xul.dll` ordinary and delay imports for the proven WinRT activation/string surface;
6. run that exact artifact on physical Win7 with normal sandbox settings and enough ordinary browsing/soak time to cross the prior later-crash window;
7. run a separate physical XP compatibility test;
8. only afterward test GOST TLS on the exact old-Windows artifact as a separate milestone.

If the PoC passes, reduce it before integration: use explicit legacy/no-WinRT feature flags instead of pretending clang-cl is MinGW, restore any windows-rs/Win32 surface that need not be removed, and document each intentionally unavailable feature plus fallback.

Detailed file inventory and design rationale are maintained in [`WINRT_SOURCE_POC.md`](./WINRT_SOURCE_POC.md). `PROJECT_STATE.md` and `TODO.md` now keep the narrow-YY and source-removal approaches visible as competing open hypotheses.

Status: current; source-removal strategy documented, current targeted/full validation runs fail before proof gates, no merge recommendation yet.