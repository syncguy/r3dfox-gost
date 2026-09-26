# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-23_pre_download_recent_docs_green.md`](./TEST_LOG_2026-09-23_pre_download_recent_docs_green.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-26 — graphics-triggered GPU-child 0x80000007 persists on 27f4271; old D3DKMT boundary absent

Track: Windows XP SP3 x86 compatibility / GPU-process teardown. Independent of GOST TLS and WebRTC functional evidence.

Exact identity remains:

- source-under-test `27f4271bddc228f21d64370a3781ba35a92a96e0`;
- full build run `36164782271`, job `108169777457`;
- package artifact `10883654763`;
- the physically exercised binaries are already independently hash-correlated to that package;
- matching `xul.pdb` from diagnostics artifact `10884079570` matches the packaged `xul.dll` CodeView identity.

New physical reproduction under RDP:

- ordinary browser startup/profile/policy/browsing/shutdown can complete normally;
- after exercising the graphics path by opening the WebGL test page and then closing the browser, DrWatson again records `0x80000007 / STATUS_WAKE_SYSTEM_DEBUGGER` in the exact new-build GPU child;
- the dump identifies the process role as GPU child and is consistent with teardown after the parent begins exiting;
- `libEGL.dll`, `libGLESv2.dll`, and system `d3d9.dll` are loaded in the captured GPU child.

Matching-symbol analysis materially changes the boundary from the predecessor capture:

- the exception-thread Firefox return address maps to `mozilla::widget::WinUtils::WaitForMessage()`;
- exact packaged-`xul.dll` disassembly shows that return address is immediately after the imported `USER32!MsgWaitForMultipleObjectsEx` call; Watson's nearby export label `USER32!GetLastInputInfo+...` is therefore not accepted as the actual API owner;
- the upper Firefox chain is the ordinary child main event loop: `nsAppShell::ProcessNextNativeEvent -> nsBaseAppShell::OnProcessNextEvent -> nsThread::ProcessNextEvent -> NS_ProcessNextEvent -> MessagePump::Run -> MessageLoop -> XRE_RunAppShell -> XRE_InitChildProcess`;
- across the xul frames present in this Watson capture there are no matching-symbol frames for `gfxWindowsPlatform::GetGpuTimeSinceProcessStartInMs()`, `mozilla::glean::RecordPowerMetrics()`, or `mozilla::glean::FlushFOGData()`;
- the prior `LoadLibraryW / GetModuleHandleW` telemetry-loader sequence is absent from this capture;
- exact packaged code contains the pre-Vista guard and returns `NS_ERROR_NOT_AVAILABLE` before the `gdi32.dll` / D3DKMT probe on XP.

Conclusion: the pre-Vista D3DKMT guard remains a valid advancement and the predecessor Glean/D3DKMT loader boundary is not reproduced. However, the top-level `0x80000007` symptom still reproduces after graphics-path activation during GPU-child teardown. The current dump does **not** establish `WinUtils::WaitForMessage`, USER32, ANGLE, or D3D9 as the root cause; the exception surfaces while the GPU main thread is parked in its normal Windows message wait.

This contradicts only the earlier broad wording that RDP shutdown acceptance was closed for all exercised paths. The narrower ordinary-RDP lifecycle PASS remains valid, while graphics-triggered GPU-child teardown is reopened.

Next diagnostic: capture the exact reproduction under WinDbg with child-process debugging and first-chance handling for `0x80000007`, preserving matching PDBs. Record the first-chance exception/context and all thread stacks before considering another source change.

Status: **ordinary RDP lifecycle PASS retained / graphics-triggered GPU-child teardown OPEN / old D3DKMT telemetry boundary advanced past / no new source owner proven**.

---

## 2026-09-26 — artifact-correlated physical XP RDP lifecycle PASS on 27f4271

Track: Windows XP SP3 x86 compatibility / GPU telemetry A/B runtime. Independent of GOST TLS and WebRTC functional evidence.

Exact identity remains:

- source-under-test `27f4271bddc228f21d64370a3781ba35a92a96e0`;
- full build run `36164782271`, job `108169777457`;
- package artifact `10883654763`;
- physically exercised `r3dfox.exe`, `xul.dll`, and `libGLESv2.dll` are already independently hash-correlated to that package.

Physical Windows XP SP3 x86 result under RDP:

- browser starts normally;
- a completely new browser profile is created successfully;
- package-supplied mandatory extensions are provisioned successfully;
- the policy-driven extension installation completes successfully;
- ordinary site browsing works;
- browser shutdown completes normally;
- no exception is produced during the exercised shutdown/lifecycle.

Conclusion: the exact `27f4271...` payload has an **artifact-correlated physical XP RDP lifecycle PASS**, including clean startup, profile creation, extension/policy provisioning, browsing, and normal shutdown. The prior `0x80000007 / STATUS_WAKE_SYSTEM_DEBUGGER` shutdown symptom is **not reproduced in this RDP lifecycle test**.

Scope limit: the active display path is still RDP, so this result does **not** establish WebGL or console graphics acceptance for the new payload. The predecessor `f15a...` console run remains the latest accepted physical WebGL rendering evidence. A console-session WebGL regression on exact `27f4271...` remains pending.

Status: **artifact-correlated physical XP RDP lifecycle PASS / shutdown PASS under RDP / prior telemetry exception not reproduced / WebGL NOT TESTED / console graphics acceptance OPEN**.

---

## 2026-09-26 — artifact-correlated physical XP startup PASS over RDP on 27f4271

Track: Windows XP SP3 x86 compatibility / GPU telemetry A/B runtime. Independent of GOST TLS and WebRTC functional evidence.

Physical runtime evidence:

- source-under-test `27f4271bddc228f21d64370a3781ba35a92a96e0`;
- full build run `36164782271`, job `108169777457`, package artifact `10883654763`;
- physical Windows XP SP3 x86 startup succeeds in an RDP session;
- the active display path is the remote/RDP display path, so this session is not accepted as a console GPU/WebGL rendering test;
- WebGL was not exercised in this session;
- normal shutdown behavior for this exact payload is not established by the supplied observation.

Artifact correlation is **PROVEN** against `r3dfox-v153.0.3.win32.zip` inside package artifact `10883654763`. Independent artifact inspection matches the physically exercised identities exactly:

- `r3dfox.exe`: 363520 bytes, SHA-1 `e7fd4ab6a6c069d551ecd9893c15e15989891065`, SHA-256 `09f3b8b403a386d9e6ba7928969456807c7150fcef5fc0dbcd89078eb06bacfc`;
- `xul.dll`: 162337280 bytes, SHA-1 `bbac9391ac9c82ecb21b411ea91343937a6644a4`, SHA-256 `9b245fecc4dce62414bf2a066578b39f9b37e65e7dbdb34bc39dd8cc96ac1248`;
- `libGLESv2.dll`: 3801600 bytes, SHA-1 `1e0a410ad7e6fee93d123908a1bdb645490f95e8`, SHA-256 `cde068d864b178bed563d8cf0e11e44d5b7e3a131ca7b7f3f55e149e593bca38`;
- `application.ini`: BuildID `20260925173211`, SourceStamp `27f4271bddc228f21d64370a3781ba35a92a96e0`;
- `platform.ini`: BuildID `20260925194629`, SourceStamp `27f4271bddc228f21d64370a3781ba35a92a96e0`.

Conclusion: exact new package startup on physical XP is **PASS under RDP** and provenance is closed. This does not replace the pending console graphics acceptance: the predecessor `f15a...` console WebGL result remains the latest accepted physical WebGL rendering evidence. The telemetry/shutdown A/B also remains open until normal shutdown of the exact `27f4271...` payload is observed without the prior symptom, preferably followed by console/WebGL regression when console access is available.

Status: **artifact-correlated physical XP startup PASS under RDP / WebGL NOT TESTED / console graphics acceptance OPEN / shutdown acceptance OPEN**.

---

## 2026-09-26 — pre-Vista D3DKMT telemetry guard full XP x32 build GREEN

Track: Windows XP SP3 x86 compatibility / GPU-process shutdown telemetry. Independent of GOST TLS and WebRTC functional evidence.

Source change:

- branch `agent/winrt-source-poc`;
- source-under-test `27f4271bddc228f21d64370a3781ba35a92a96e0` (`fix(xp): skip D3DKMT GPU telemetry before Vista`);
- only `gfx/thebes/gfxWindowsPlatform.cpp` changed from the prior implementation HEAD;
- `gfxWindowsPlatform::GetGpuTimeSinceProcessStartInMs()` returns `NS_ERROR_NOT_AVAILABLE` when `!IsVistaOrLater()` before `LoadLibrary(L"gdi32.dll")`;
- the existing Vista+ D3DKMT path and the established ANGLE/WebGL/D3D9 remediation are unchanged.

Full-build evidence:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `36164782271`;
- job `108169777457`;
- exact run head/source-under-test `27f4271bddc228f21d64370a3781ba35a92a96e0`;
- result **completed / success / GREEN**;
- full browser build, ANGLE local-static codegen gate, XP PE/import gates, packaging, runtime archive creation, artifact uploads, and blocking aggregate summary all completed successfully;
- package artifact `10883654763`, digest `sha256:00811e502d032cfc7798a22028c27de8950fcdf4c0b2f3323d089be86f8906d2`;
- runtime artifact `10883894624`, digest `sha256:2393524a74445ed5bf24ef13558aeca35bc2c7ebbf2e4945f123cb93943b8e83`;
- diagnostics artifact `10884079570`, digest `sha256:fbd2f1842e94a6c3b44a258417884e6a5b753fd71fbf5c424fd2ef87342ef6eb`.

This closes the **build/package/static** acceptance boundary for the pre-Vista D3DKMT telemetry A/B. It does not establish physical Windows XP runtime success and does not prove that the prior `0x80000007 / STATUS_WAKE_SYSTEM_DEBUGGER` shutdown symptom is fixed.

The next acceptance boundary is physical XP execution of the exact new payload: confirm the previously proven WebGL context/rendering path remains intact, then perform a normal browser shutdown. If `0x80000007` recurs, localize the new exact capture with matching symbols before any broader workaround.

Status: **build/package/static GREEN / physical XP runtime result NOT ESTABLISHED**.

---

## 2026-09-25 — physical XP WebGL rendering reached on f15a, intermittent GPU-child failure remains

Track: Windows XP SP3 x86 compatibility / ANGLE / WebGL runtime. Independent of GOST TLS and WebRTC functional evidence.

Physical evidence:

- physical Windows XP SP3 x86, console session rather than RDP;
- browser/GPU-child memory contains SourceStamp `f15a047e847cdca07d90396fe88d32a74cee416e` and BuildID `20260924094702`;
- the exercised GPU child is identified by its Firefox child-process command line as role `gpu`;
- `libEGL.dll`, `libGLESv2.dll`, system `d3d9.dll`, and the pinned `d3dcompiler_47.dll` are loaded in that GPU child;
- on `get.webgl.org`, the page reports WebGL support and visibly renders the rotating/wireframe cube.

Conclusion from the positive path: the `f15a...` browser reaches successful WebGL context creation and exercised rendering on physical XP. This physically advances beyond both predecessor ANGLE local-static failure boundaries that prevented useful WebGL initialization/rendering on earlier builds.

Stability is **not** accepted yet. The GPU child still fails intermittently after WebGL has rendered. A DrWatson capture was obtained, but the capture's top-level exception is `0x80000007 / STATUS_WAKE_SYSTEM_DEBUGGER`, with the recorded state in `ntdll!KiFastSystemCallRet`; the capture contains no `0xC0000005` fault location for the intermittent failure. Therefore this Watson record is not accepted as localization of a new ANGLE crash site and must not be used to assign ownership to `libGLESv2`, D3D9, mozglue, or another component.

Artifact correlation is now **PROVEN** against package artifact `10806218628`, specifically its final portable ZIP payload. The physically tested files match the published package byte-for-byte:

- `r3dfox.exe`: 363520 bytes, SHA-256 `e46e86105a7acd99dd9cb3ed803eca90ccd0df519a3a9f10b4bf471f4e3e370c`;
- `xul.dll`: 162337280 bytes, SHA-256 `44bf7b20cca45742bac988876cf2cf179435eb2adbf7ca0a66e2bed932b1c165`;
- final packaged `libGLESv2.dll`: 3801600 bytes, SHA-256 `ae6589abc4acaee7535e706106183b8d201adf5f2aa71a992db5197ffe87624c`.

The portable package also contains the same public source/build identity observed locally: `application.ini BuildID=20260924094702`, `platform.ini BuildID=20260924115716`, and SourceStamp `f15a047e847cdca07d90396fe88d32a74cee416e` in both files.

Hash qualification: the earlier `libGLESv2.dll` SHA-256 `30ff7dc27e949e5d952ccc1e15186aff07523d1acd5da6ec18ba51493d8075f7` belongs to the verifier's diagnostic copy captured immediately after `mach build`, before the later full-workflow PE-retarget/package stages. The final portable `libGLESv2.dll` is the retargeted packaged file above. The two hashes therefore describe different workflow stages rather than contradictory binaries.

Additional `about:support` evidence from the same physical console-session build shows:

- compositor path: Software WebRender fallback;
- GPU process: active;
- WebGL feature decision: available;
- hardware-compositing / WebRender initialization has separately fallen back, so compositor fallback and WebGL availability must not be conflated;
- the graphics failure history contains repeated abnormal compositor/IPC shutdown records, consistent with the separately observed GPU-process instability.

The new shutdown DrWatson capture and the earlier intermittent capture both report `0x80000007 / STATUS_WAKE_SYSTEM_DEBUGGER` in the same exact artifact-correlated GPU process line. Matching `xul.pdb` symbolization establishes a repeatable Firefox boundary:

`gfxWindowsPlatform::GetGpuTimeSinceProcessStartInMs()`
→ `mozilla::glean::RecordPowerMetrics()`
→ `mozilla::glean::FlushFOGData()`
→ GPU-process IPC / main-loop dispatch.

Immediately below the first Firefox frame, the native stack is inside `LoadLibraryW` / mozglue DLL-blocklist handling / `GetModuleHandleW` / the loader critical-section path. Exact source `gfx/thebes/gfxWindowsPlatform.cpp` shows that `GetGpuTimeSinceProcessStartInMs()` dynamically loads `gdi32.dll` before resolving `D3DKMTQueryStatistics`. The current shutdown capture reaches this path through a parent-requested GPU `FlushFOGData`; the earlier intermittent capture reaches the same `RecordPowerMetrics` path through a FOG IPC payload flush. This explains why the visible symptom can occur both during use and during browser shutdown without implicating the WebGL renderer itself.

Root-cause qualification: `0x80000007` is not a new access-violation site, so the exact mechanism of the process termination is still not proven. However, the repeated `FlushFOGData -> RecordPowerMetrics -> GetGpuTimeSinceProcessStartInMs -> LoadLibrary(gdi32.dll)` boundary is now established independently of ANGLE rendering.

Evidence boundary:

- **PROVEN:** exact artifact-correlated `f15a...` physical XP console session, GPU-child role, WebGL context creation and exercised rendering.
- **NOT YET PROVEN:** stable repeated GPU-process lifetime; exact mechanism behind the `0x80000007` termination while the GPU process is in the Glean GPU-time/power-metrics loader path.

Next experiment should be a narrow source-level A/B around `gfxWindowsPlatform::GetGpuTimeSinceProcessStartInMs()`: on pre-Vista Windows, return `NS_ERROR_NOT_AVAILABLE` before `LoadLibrary(L"gdi32.dll")`, preserving the existing Vista+ path. This avoids the WDDM/D3DKMT telemetry probe on XP without changing ANGLE, WebGL, D3D9 rendering, or compositor policy. Rebuild/test only after that one-owner change; if the `0x80000007` symptom persists, capture the new exact boundary with matching symbols.

Status: **artifact-correlated physical XP WebGL context + rendering PASS observed / repeated GPU-process Glean power-metrics loader boundary established / termination mechanism still open.**

---

## 2026-09-24 — full XP x32 build GREEN with ANGLE full-build codegen gate

Track: Windows XP SP3 x86 compatibility / ANGLE / WebGL runtime. Independent of GOST TLS and WebRTC functional evidence.

Exact identity:

- implementation branch: `agent/winrt-source-poc`;
- source-under-test: `f15a047e847cdca07d90396fe88d32a74cee416e`;
- browser/ANGLE remediation commit beneath CI-only follow-ups: `b01f3461d52eec1b60aa87d12e083f3485032fba`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `35980235042`;
- job `107570122638`;
- aggregate result: **completed / success / GREEN**;
- package artifact `10806218628`, digest `sha256:ecd32f1a07c25b2dd50df73665e0760b07761ae0ed23131cb082cffd428d6628`;
- runtime artifact `10806283395`, digest `sha256:af912df8e86267c1a2b53db5124bbcb3509e2bf93d6ff749560d5488d2b47da6`;
- diagnostics artifact `10806562241`, digest `sha256:024754c869c02e592f85a0cfccf545528258eab8f748a93c2ec2ae0925d29f40`.

The full Firefox/r3dfox build completed successfully. `GATE - Verify ANGLE XP local-static codegen` also completed successfully in `FullBuild` mode against the objects emitted by that full build:

- `Display.obj: Init_thread_matches=0`;
- `formatutils.obj: Init_thread_matches=0`;
- full-build `libGLESv2.dll` SHA-256 `30ff7dc27e949e5d952ccc1e15186aff07523d1acd5da6ec18ba51493d8075f7`.

The final aggregate summary records success for the ANGLE codegen gate, browser build, package, runtime archive, package-survival checks and broad XP PE/direct-import audit. Package, runtime and diagnostics artifacts were uploaded successfully.

Conclusion: the Windows x86 ANGLE `/Zc:threadSafeInit-` remediation is now accepted at both focused-object scale and full Firefox build/package/static scale for exact source `f15a047e...`. This closes the current full-build/static acceptance boundary.

Evidence boundary: this GREEN does **not** establish physical Windows XP WebGL success and does not prove the predecessor TLS/epoch corruption mechanism. Physical acceptance requires exact-artifact binary correlation followed by WebGL context creation and exercised rendering on XP. Predecessor `libGLESv2` RVAs are historical fault identities and are not assumed to apply to this newly linked DLL.

Status: **full XP build/package/static GREEN / physical XP WebGL test pending.**

---

## 2026-09-24 — focused ANGLE /Zc:threadSafeInit- codegen gate GREEN

Track: Windows XP SP3 x86 compatibility / ANGLE / WebGL runtime. Independent of GOST TLS and WebRTC functional evidence.

Exact experiment identity:

- product source checked out and built: `agent/winrt-source-poc @ b01f3461d52eec1b60aa87d12e083f3485032fba`;
- workflow/control branch: `agent/gost-tls-poc`;
- workflow/control SHA: `741ebbca871a696f82aa857be2e6aa6ef5414738`;
- workflow `.github/workflows/xp-angle-libglesv2-smoke.yml` / `XP ANGLE libGLESv2 smoke`;
- run `35974426502`;
- job `107551429542`;
- artifact `10798373361` (`xp-angle-libglesv2-smoke`), digest `sha256:39c88010a830bc2d4af4cb828704f0252b07bbe972d571c2f6835685f38beda4`;
- aggregate result: **completed / success / GREEN**.

The corrected codegen gate executed successfully against the exact focused build. The job reports:

- `Display.cpp: /Zc:threadSafeInit-=True Init_thread_matches=0`;
- `formatutils.cpp: /Zc:threadSafeInit-=True Init_thread_matches=0`.

The subsequent focused binary gate also passed. Exact focused `libGLESv2.dll` SHA-256 is `8db4feb9db2f99eb61e3bc611abd2845a913e4b2cc1a281e1df0264ee8c46aa6`; the inspection reports `DXGI=False`, `CreateDXGIFactory=False`, `CreateDXGIFactory1=False`, `D3D9=True`.

Conclusion: the Windows x86 ANGLE build option `/Zc:threadSafeInit-` is now directly proven at focused-object scale to eliminate the MSVC `_Init_thread_header/footer/epoch` machinery from both physically reproduced local-static owners while preserving the original source statics.

Follow-up integration: the same verifier responsibility has been transferred into the full XP x32 workflow on `agent/winrt-source-poc`. Implementation commits `cee8175a...`, `d655a237...`, and `f15a047e...` add the full-build verifier, insert a blocking ANGLE codegen gate immediately after successful `mach build`, and include its outcome in the aggregate final verdict. Full run `35980235042`, job `107570122638`, is already dispatched from exact source-under-test `f15a047e847cdca07d90396fe88d32a74cee416e` and remains `in_progress` at this documentation update; no full-build GREEN is claimed.

Evidence boundary: this GREEN is **focused compile/codegen/static evidence**, not a full Firefox build and not physical XP WebGL runtime proof.

Status: **focused ANGLE codegen GREEN / full XP browser run `35980235042` / job `107570122638` in progress on exact source `f15a047e...` / physical XP WebGL retest pending.**

---

## 2026-09-24 — focused ANGLE /Zc:threadSafeInit- build PASS, verifier infrastructure RED

Track: Windows XP SP3 x86 compatibility / ANGLE / WebGL runtime. Independent of GOST TLS and WebRTC functional evidence.

Exact experiment identity:

- source-under-test branch `agent/winrt-source-poc`;
- source-under-test / run head SHA `b01f3461d52eec1b60aa87d12e083f3485032fba`;
- trigger workflow `.github/workflows/xp-angle-smoke-trigger.yml` / `Trigger XP ANGLE libGLESv2 smoke`;
- reusable workflow `.github/workflows/xp-angle-libglesv2-smoke.yml@agent/gost-tls-poc`;
- run `35970854066`;
- job `107539996865`;
- artifact `10797530363` (`xp-angle-libglesv2-smoke`), digest `sha256:2ba7dcba3fbe79cdf235870ffd033de88209eb75432b9fc5f84f8b93260f2c65`;
- aggregate workflow result: **completed / failure**.

The aggregate RED is not a compile/link failure. The exact source checkout is recorded as `b01f3461d52eec1b60aa87d12e083f3485032fba`. All prerequisite build stages, focused `mozglue.dll`, and `Build libGLESv2 only` completed successfully.

The focused build log proves that both physically relevant ANGLE translation units were compiled with the intended XP compatibility configuration:

- `Display.cpp -> Display.obj`: `-DMOZ_XP_COMPAT`, optimized build, and `/Zc:threadSafeInit-`;
- `formatutils.cpp -> formatutils.obj`: `-DMOZ_XP_COMPAT`, optimized build, and `/Zc:threadSafeInit-`.

The linker then produced `dist/bin/libGLESv2.dll` using `lld-link` with `-SUBSYSTEM:WINDOWS,5.01` and `-MACHINE:X86`; the subsequent Mozilla `check_binary` invocation completed before the build step returned success.

The failure occurred only in `GATE - Verify XP ANGLE trace codegen`. The script invocation failed with `CommandNotFoundException` because the reusable workflow used `${{ github.workflow_sha }}` for the verification-script checkout. In this reusable-call context that value resolved to the caller/source SHA `b01f3461...`, while `.github/scripts/xp/verify-angle-trace-xp-codegen.ps1` exists on the canonical `agent/gost-tls-poc` branch, not on the implementation branch. Therefore the verification file was absent at runtime. The later binary-inspection step was skipped after that gate failure.

Evidence boundary: this run **proves focused compile/link acceptance and propagation of `/Zc:threadSafeInit-` into both known owner translation units**, but it does **not** prove that `_Init_thread_header`, `_Init_thread_footer`, or `_Init_thread_epoch` disappeared from the resulting objects, because the codegen verifier never executed.

Verifier remediation on the canonical branch:

- `fbefe5191c564bca64fc8f83602d6d3dc3d5e294` pins the verification-script checkout to `agent/gost-tls-poc` and records its actual checkout SHA;
- `741ebbca871a696f82aa857be2e6aa6ef5414738` finalizes the updated verifier contract: retain both original function-local statics, require `Display.cpp` and `formatutils.cpp` to compile with `MOZ_XP_COMPAT`, optimization and `/Zc:threadSafeInit-`, and reject `_Init_thread_header/footer/epoch` evidence from both compiled objects.

Status: **focused ANGLE compile/link PASS for source `b01f3461...`; overall run RED from verifier checkout infrastructure; local-static codegen verdict still pending a clean rerun.**

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

Physical Windows XP WebGL execution still fails with `0xC0000005` read access, but the fault boundary has advanced. The predecessor source `e13354c...` failed at `libGLESv2+0x0003C1CA` in the ANGLE trace-category local-static path. The exact `3119c849...` runtime instead fails at `libGLESv2+0x00159EBB`; the faulting dereference sees a `NULL` pointer, and `EGL_Initialize+0x78` remains a stable exported stack anchor.

Publication correction (2026-09-24): an earlier public version of this entry included raw debugger load/instruction addresses and register state. The current tip retains only the allowlisted module+RVA, access-type and pointer-state summary. The experiment conclusion is unchanged; this corrective edit does not erase earlier Git history.

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