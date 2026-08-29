# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-27_2026-08-28_part2.md`](./TEST_LOG_2026-08-27_2026-08-28_part2.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. For current technical synthesis, see [`PROJECT_STATE.md`](./PROJECT_STATE.md). For forward work, see [`TODO.md`](./TODO.md). For the detailed source-level WinRT experiment design, see [`WINRT_SOURCE_POC.md`](./WINRT_SOURCE_POC.md). For formally closed milestones, see [`DONE.md`](./DONE.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

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