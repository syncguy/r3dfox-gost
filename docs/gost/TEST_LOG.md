# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-23_pre_download_recent_docs_green.md`](./TEST_LOG_2026-09-23_pre_download_recent_docs_green.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-24 — XP ANGLE trace fix advances to second TLS-backed local-static crash

Track: Windows XP SP3 x86 compatibility / ANGLE / WebGL runtime. Independent of GOST TLS and WebRTC functional evidence.

Exact exercised build identity:

- branch `agent/winrt-source-poc`;
- source-under-test `3119c849b3930145c8e4181b8a06a692ec20514d`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `35860139917`;
- job `107178068460`;
- physical-test runtime artifact `10759971452`;
- diagnostics artifact `10759359771`;
- `r3dfox.exe` SHA-1 `4103c98f53c53513f42f087df4ff6306083cc9dd`;
- `xul.dll` SHA-1 `790260efa0bde58fb4faa964a517914efbe44d40`;
- `libGLESv2.dll` SHA-1 `84edd61305a6bd048c1710f2a6e7d326fd11ac4c`.

A fresh Firefox profile starts and ordinary browsing works, so the earlier no-network observation with a copied older profile is not treated as a binary networking regression.

Physical Windows XP WebGL execution still fails with `0xC0000005`, but the fault boundary has advanced. The predecessor source `e13354c...` failed at `libGLESv2+0x0003C1CA` in the ANGLE trace-category local-static path. The exact `3119c849...` runtime instead fails with `libGLESv2.dll` loaded at `0x0f600000`, EIP `0x0f759ebb`, therefore RVA `libGLESv2+0x00159EBB`. The faulting instruction is `mov ecx,[eax]` with `eax=0`; `EGL_Initialize+0x78` remains a stable exported stack anchor.

Matching `libGLESv2.pdb` from diagnostics artifact `10759359771` maps the fault to the inline `std::_Tree<...>::begin()` called by `rx::d3d9_gl::GenerateCaps()` at `gfx/angle/checkout/src/libANGLE/renderer/d3d/d3d9/renderer9_utils.cpp:517`. The call immediately before the failing `std::set` begin is `gl::GetAllSizedInternalFormats()` at `gfx/angle/checkout/src/libANGLE/formatutils.cpp:2006`.

That function owns another dynamically initialized function-local static:

`static angle::base::NoDestructor<FormatSet> formatSet(BuildAllSizedInternalFormatSet());`

Disassembly of the exact `84edd613...` DLL shows the MSVC thread-safe local-static fast path reading per-thread state through `fs:[0x2c]`; matching PDB symbols identify its slow-path calls as `_Init_thread_header` and `_Init_thread_footer` from `thread_safe_statics.cpp`. The caller receives a `FormatSet` whose tree head is null and faults in `begin()`.

Conclusion: the narrow trace-event source workaround was useful because it advanced execution past the previous `+0x3C1CA` boundary, but the blocker class is broader than that one macro. A second independent ANGLE function-local static now fails through the same TLS-backed MSVC initialization mechanism during real D3D9 capability generation.

Corrective candidate on the implementation branch:

- `5934345e6c6e805a703efc1cc425b6aebfe8c0a4` adds `/Zc:threadSafeInit-` to Windows x86 ANGLE build flags in `gfx/angle/moz.build.common`;
- `b01f3461d52eec1b60aa87d12e083f3485032fba` restores the normal trace-event static cache so the compiler option, rather than a one-off source workaround, owns this compatibility behavior;
- candidate HEAD `b01f3461...` has **no CI or physical-runtime acceptance yet**.

Next proof chain: full XP x86 build from exact `b01f3461...`; confirm the ANGLE compile/codegen no longer emits the TLS-backed thread-safe-local-static path at the known sites; then run the exact resulting artifact on physical XP with the same WebGL trigger and matching binary hashes.

Status: **`3119c849...` physical WebGL FAIL / previous trace crash advanced past / new `GenerateCaps -> GetAllSizedInternalFormats` local-static blocker PROVEN / `b01f3461...` candidate pending build.**

---

## 2026-09-23 — XP ANGLE trace-cache local-static remediation full build GREEN

Track: Windows XP SP3 x86 compatibility / ANGLE / WebGL runtime. Independent of GOST TLS and WebRTC functional evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test / Actions head SHA `3119c849b3930145c8e4181b8a06a692ec20514d`;
- source commit `3119c849b3930145c8e4181b8a06a692ec20514d` (`fix(xp): avoid ANGLE trace local-static TLS guard`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `35860139917`;
- job `107178068460` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / success / GREEN**.

Artifacts bound to exact source-under-test `3119c849...`:

- package artifact `10760076917` (`r3dfox-gost-xp-x32-package`), digest `sha256:a78f1943847d57c4adfcaccb08d3fbb754f65e8a08a9edcd42d1e7feb03738eb`;
- physical-test runtime artifact `10759971452` (`r3dfox-gost-xp-x32-runtime`), digest `sha256:089a6c0ea8b9a3baa1a43ef5df9d0b057967174b42af0d50d9c31a70b2adee75`;
- diagnostics artifact `10759359771` (`r3dfox-gost-xp-x32-diagnostics`), digest `sha256:e081580c903dc913b152ec71facf19804b5e82bac77d7865e86126f6f6dd6de1`.

This source is the narrow follow-up to the physically reproduced GPU-child WebGL crash on predecessor source `e13354c79ebfa206fbccc946592256d33e4ac519`. That crash occurs at `libGLESv2.dll+0x0003C1CA` while evaluating the ANGLE trace category used by `ANGLE_TRACE_EVENT0("gpu.angle", "egl::Display::initialize")`, before renderer implementation initialization.

The remediation changes `INTERNAL_TRACE_EVENT_GET_CATEGORY_INFO` in `gfx/angle/checkout/src/third_party/trace_event/trace_event.h`: under `MOZ_XP_COMPAT`, the category pointer is no longer a dynamically initialized function-local `static`, avoiding the MSVC thread-safe local-static guard/TLS-epoch path at this proven runtime owner. Non-XP builds retain the original function-local `static` behavior.

Run `35860139917` completed the release browser build, packaging, runtime-archive creation, XP compatibility/import gates, package-survival checks, artifact uploads, and final summary successfully. Therefore the narrow source change is **build/package/static accepted** for exact source `3119c849...`.

Evidence boundary: this build does **not** prove that the physical GPU-child `libGLESv2` crash is closed and does not independently prove that the inferred TLS/epoch mechanism is the complete root cause. Physical acceptance still requires the exact `10759971452` runtime payload on Windows XP, matching local binary hashes, and the same WebGL trigger (`https://get.webgl.org/` with WebGL context creation allowed) to advance past the former `libGLESv2+0x3C1CA` boundary.

Status: **completed / build+package+static GREEN / physical XP WebGL retest pending.**

---

## 2026-09-23 — XP download/recent-documents remediation full build and physical runtime PASS

Track: Windows XP SP3 x86 compatibility / download completion / Windows Recent Documents integration. Independent of WebRTC functional runtime and GOST TLS handshake evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test / Actions head SHA `e13354c79ebfa206fbccc946592256d33e4ac519`;
- functional remediation commit `2c8dc1dc4696c5efcef0b00da4106ac4170b4de7` (`fix(xp): use legacy recent-documents path`);
- regression-gate commit `e13354c79ebfa206fbccc946592256d33e4ac519` (`test(xp): reject SHCreateItemFromParsingName`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `35810132801`;
- job `107019631325` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / success / GREEN**.

Artifacts bound to exact source-under-test `e13354c...`:

- package artifact `10733487295` (`r3dfox-gost-xp-x32-package`), digest `sha256:cc72661870838b6127e08b5c80f27a91de69ab5725546d5134095d6fb27d2b2c`;
- physical-test runtime artifact `10733956483` (`r3dfox-gost-xp-x32-runtime`), digest `sha256:e9edf4fdeb2902592b88332655332f130cf8e914d693fa926b14a4d3dffb45eb`;
- diagnostics artifact `10733113244` (`r3dfox-gost-xp-x32-diagnostics`), digest `sha256:d47de71f9b51dbcdf2fdaa857dcac8ce6a5edc1b24d96042ed73afdf0ee02013`.

The predecessor physical XP build from source `9e692fc9dfb1dd6f8099503e94afe887545cb5bb`, run `35700636148`, job `106657546780`, had a stable download-completion `0xC06D007F` boundary. Matching dump/PDB/PE evidence localized the delayed call to `SHELL32.dll!SHCreateItemFromParsingName` from `AddToRecentDocs()` inside `DownloadPlatform::DownloadDone()`. The same physical predecessor build completed downloads without the crash when `browser.download.manager.addToRecentDocs=false`, which is an A/B runtime confirmation of that owner/path but not a source-level fix.

Source `e13354c...` applies the narrow XP remediation: under `MOZ_XP_COMPAT`, the modern AppUserModelID / `SHCreateItemFromParsingName` branch is not compiled and `AddToRecentDocs()` falls through to the existing legacy `SHAddToRecentDocs(SHARD_PATHW, ...)` path. Non-XP Windows retains the existing modern path.

The same source also adds `SHCreateItemFromParsingName` to `.github/scripts/xp/reject-core-browser-xp-direct-imports.ps1`. In run `35810132801`, both `GATE - Reject proven core browser XP direct imports` and the broad `GATE - Audit XP x32 PE floor and direct imports` completed successfully. The release build, packaging, runtime archive creation, package-survival checks, artifact uploads and final summary also passed.

Physical Windows XP validation of the exact successor runtime is now complete with `browser.download.manager.addToRecentDocs=true`. The user completed an ordinary download without an error or browser crash. User-recorded SHA-1 identities are:

- `r3dfox.exe`: `3f4f98bb9ad710bda5c72fa25d1e124d37c211b4`;
- `xul.dll`: `17ee19d4a947466b25d95089a967f7d055261c2b`.

The runtime artifact `10733956483` was independently downloaded and unpacked; its `r3dfox.exe` and `xul.dll` SHA-1 values match the user's physical binaries exactly. This binds the physical PASS directly to source-under-test `e13354c...` and run `35810132801`, rather than relying only on user association.

Conclusion: **DOWNLOAD / WINDOWS RECENT DOCUMENTS XP BLOCKER PHYSICALLY CLOSED.** Exact source `e13354c...` has full build/package/static import-regression PASS and an artifact-correlated physical Windows XP download-completion PASS with `browser.download.manager.addToRecentDocs=true`. The predecessor `0xC06D007F` / `SHELL32!SHCreateItemFromParsingName` boundary did not recur in the exercised path.

Evidence boundary: this closes the reproduced download/recent-documents blocker only. It does not add WebRTC functional-runtime evidence or GOST TLS handshake evidence.

Status: **completed / build+package+static GREEN / artifact-correlated physical XP download-completion PASS.**

---

## 2026-09-23 — WebGL permission reliably reproduces GPU-child `libGLESv2` local-static/TLS AV

Track: Windows XP SP3 x86 compatibility / ANGLE / WebGL runtime. Independent of GOST TLS and WebRTC functional evidence.

Exact experiment identity:

- physically exercised source: `e13354c79ebfa206fbccc946592256d33e4ac519`, recovered from the uploaded process dump;
- canonical build for that source: `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`, run `35810132801`, job `107019631325`;
- runtime artifact: `10733956483`;
- diagnostics artifact: `10733113244`;
- the previously recorded `r3dfox.exe` and `xul.dll` physical binaries for this source are artifact-correlated; the crashing local `libGLESv2.dll` itself is still **NOT CHECKED** byte-for-byte against the runtime artifact.

Physical trigger: on Windows XP SP3 x86, opening `https://get.webgl.org/` and allowing creation of the WebGL context reliably reaches the failure.

The uploaded DrWatson capture reports `0xC0000005` read access at `libGLESv2.dll+0x0003C1CA`, with the dereferenced cached pointer `NULL`; `libGLESv2.dll!EGL_Initialize+0x78` is the reliable exported stack anchor. This is the same RVA and failure shape already mapped in the public runtime artifact to the `ANGLE_TRACE_EVENT0("gpu.angle", "egl::Display::initialize")` local-static category cache, before `mImplementation->initialize(this)`.

The accompanying full process dump adds one new proven fact that the earlier DrWatson-only record did not establish: the crashing process is the **GPU child**. Its recovered command line identifies the Firefox child-process role as `gpu`. Therefore this incident must no longer be described as process-role `UNKNOWN` for this capture.

The trigger also strengthens the runtime boundary: the crash occurs when WebGL causes the GPU child to initialize EGL/ANGLE, not during ordinary browser startup and not during D3D9 renderer implementation initialization. The already-closed direct `CreateDXGIFactory1`/D3D9 graph blocker remains closed.

Current root-cause status is still narrower than a final proof. The artifact instructions show the MSVC thread-safe function-local-static fast path consulting module TLS-backed per-thread epoch state; at the fault, the cached category pointer remains `NULL` while the initializer path has been skipped. This is consistent with an invalid or stale per-thread local-static epoch/TLS state on XP, but the exact TLS/epoch values on the faulting thread have not yet been captured.

Preferred remediation direction for a source experiment is to remove this XP dependency on MSVC thread-safe local-static TLS at the ANGLE trace-cache boundary rather than disabling WebGL, removing the trace point, weakening an assertion, or reopening the D3D9 backend. A targeted XP-only trace-cache fallback can avoid the function-local dynamically initialized `static` while leaving non-XP behavior unchanged. A broader `/Zc:threadSafeInit-` ANGLE build experiment remains a secondary diagnostic option because it changes all affected local-static initialization in the compiled target rather than only the proven owner.

Status: **reproduced / GPU-child role PROVEN / fault owner and pre-renderer boundary PROVEN / exact TLS-epoch root cause still OPEN.**