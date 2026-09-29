# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-23_pre_download_recent_docs_green.md`](./TEST_LOG_2026-09-23_pre_download_recent_docs_green.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-27 — RDP get.webgl.org exercise completes with clean browser shutdown; WebGL remains disabled by RDP path

Track: Windows XP SP3 x86 compatibility / ANGLE / libGLESv2 runtime follow-up. Independent of GOST TLS runtime and WebRTC functional evidence.

Exact product identity remains source-under-test `ad96945f101cedc25b9ed40df25bbed25c045833`, full build run `36294912858`, job `108551864059`, package artifact `10925293352`; the exercised `r3dfox.exe`, `xul.dll`, and `libGLESv2.dll` were already artifact-correlated in the preceding entry.

A physical Windows XP SP3 x86 RDP session opened `https://get.webgl.org/` while MOZ network/IPC logging was active. The log contains HTTP activity for `get.webgl.org:443`, a live GPU child throughout the exercised interval, and orderly parent network shutdown including `xpcom-shutdown`, connection-manager shutdown and socket-transport shutdown. No fatal/crash/exception marker is present in the supplied MOZ log, and the user reports no visible error dialog during startup, page exercise, or browser close.

The accompanying `about:support` capture explains the graphics limitation of this run: software WebRender is active, the display driver is the RDP display path, and both WebGL 1 and WebGL 2 report disabled. Therefore this experiment does not instantiate or prove the console WebGL rendering path and cannot by itself prove absence of the previously captured `libGLESv2!DllMain / DLL_THREAD_DETACH` failure under a real WebGL context.

Environment note: the capture shows the project-recognized gfx crash override as `SET_VALUE_WITHHELD`; no conclusion here depends on its exact value.

Conclusion: **artifact-correlated RDP page-exercise + clean shutdown PASS**, with the previous visible error symptom not reproduced. The remaining physical acceptance boundary is still console-capable WebGL creation/rendering followed by GPU-child/browser teardown.

Status: **RDP get.webgl.org navigation PASS / clean shutdown PASS / WebGL disabled by RDP path / console WebGL teardown acceptance OPEN**.

---

## 2026-09-27 — artifact-correlated physical XP RDP startup advances past prior visible failure

Track: Windows XP SP3 x86 compatibility / ANGLE / libGLESv2 static-TLS lifecycle. Independent of GOST TLS runtime and WebRTC functional evidence.

Physical Windows XP SP3 x86 execution was performed from the exact full-build package artifact `10925293352` produced by run `36294912858`, job `108551864059`, source-under-test `ad96945f101cedc25b9ed40df25bbed25c045833`.

The physically exercised binaries were independently correlated against the package contents:

- `r3dfox.exe` SHA-1 `5782f259de42100eeb381ad24f3ff74d168f2784`;
- `xul.dll` SHA-1 `f9ed3373bcd84c5bf3924406a19710cce08d8b5c`;
- `libGLESv2.dll` SHA-1 `8a2b7558af0b7fdbcc741b4fed6f71fedf44c16f`.

Observed result under an RDP session:

- browser startup succeeds on physical Windows XP;
- the previously seen visible error dialogs are not reproduced in the exercised session;
- no WebGL rendering assertion is made because the active RDP display path does not provide an accepted console WebGL observation.

Conclusion: the exact `ad96945f...` payload has an **artifact-correlated physical XP RDP startup advancement** and does not reproduce the prior visible failure symptom during the exercised session. This is meaningful runtime evidence beyond CI/static qualification, but it is not yet the targeted WebGL+GPU-child teardown acceptance. Final acceptance of the libGLESv2 TLS-lifecycle remediation still requires exercising the WebGL path and observing teardown without the previously captured `DLL_THREAD_DETACH` access violation.

Status: **physical XP startup PASS under RDP / prior visible error symptom not reproduced / WebGL NOT TESTED / targeted teardown acceptance still OPEN**.

---

## 2026-09-27 — full XP x32 candidate GREEN; final libGLESv2 YY TLS contract verified

Track: Windows XP SP3 x86 compatibility / full implementation build / ANGLE static-TLS lifecycle. Independent of GOST TLS runtime and WebRTC functional evidence.

Exact full-build evidence:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `36294912858`;
- job `108551864059`;
- source-under-test `ad96945f101cedc25b9ed40df25bbed25c045833`;
- result **completed / success / GREEN**;
- package artifact `10925293352`, digest `sha256:81b57739dc8202b24fb4b3e65e0a13ef1031f3b373861bc2534cf8181b68eb85`;
- runtime artifact `10925462253`, digest `sha256:4bfc6052d6abe6af34792da47ceee088edb1b192ccfbf77ee19652ea9cb24e33`;
- diagnostics artifact `10925258640`, digest `sha256:3cbb8b5efc823b8b88ca7c5da7d71a039e6d8bd280115fa375d74b513afab4ef`.

All relevant blocking build/static gates completed successfully, including the full browser build, ANGLE XP local-static codegen gate, XP PE/import audit, package/runtime creation, and aggregate summary. The final runtime-closure YY audit reports for `libGLESv2.dll`: `entry_wrapper=true`, `yy_first_tls_callback=true`, `contract=true`, classification `YY_CANDIDATE_CONTRACT_PRESENT`. This closes the full-build/static acceptance boundary for the targeted `libGLESv2` YY TLS entry-point remediation.

The same diagnostic inventory reports `strong candidates=16`, `contracts=4`, `missing-contract candidates=12`. These 12 entries are follow-up candidates only; the workflow explicitly treats them as diagnostic rather than proof of a physical XP failure or proof that each DLL requires the YY TLS-aware entry point. They require compiler-TLS/PE-entry/load-lifecycle analysis before any additional target is changed.

Status: **full build/static qualification GREEN / targeted final libGLESv2 contract proven / physical XP WebGL+teardown acceptance still pending**. Build success and static PE evidence do not prove runtime closure.

---

## 2026-09-27 — corrected focused libGLESv2 YY entry-point preflight GREEN; full candidate build active

Track: Windows XP SP3 x86 compatibility / ANGLE / libGLESv2 static-TLS lifecycle. Independent of GOST TLS runtime and WebRTC functional evidence.

The first focused attempt for the new Windows x86 `libGLESv2.dll` YY TLS entry-point contract was run `36255787912`, job `108442196461`, against product source `482bc4417601fc96f2ab135f377f64e03945cd27`. The new `DllMainCRTStartupForYY_Thunks` linker entry was present, but the focused workflow did not yet activate the YY provider used by the full XP build, so the focused link failed with unresolved `_DllMainCRTStartupForYY_Thunks`. This is classified as focused-workflow infrastructure failure, not rejection of the product remediation.

Workflow/control commit `1129e3a054a1fd8a6a86b6c6f6e3d59d67da25ae` adds the proven YY-Thunks 1.2.2 / XP x86 preparation, narrow-provider build and activation steps to `.github/workflows/xp-angle-libglesv2-smoke.yml`.

Corrected focused evidence:

- workflow `XP ANGLE libGLESv2 smoke`;
- run `36257921234`;
- job `108448117969`;
- workflow/control SHA `1129e3a054a1fd8a6a86b6c6f6e3d59d67da25ae`;
- checked-out product source-under-test `ad96945f101cedc25b9ed40df25bbed25c045833`;
- artifact `10911892631`, digest `sha256:0ac161f5360eeb7bf9541476e9869a26a1000465503175084da6bbb89143f453`;
- aggregate result **completed / success / GREEN**;
- `Build libGLESv2 only`: success;
- ANGLE XP trace-codegen gate: success;
- focused binary-inspection gate: success;
- final focused link contains both `-ENTRY:DllMainCRTStartupForYY_Thunks` and the original-CRT alternate contract;
- focused binary inspection reports `DXGI=False`, `CreateDXGIFactory=False`, `CreateDXGIFactory1=False`, `D3D9=True`;
- focused `libGLESv2.dll` SHA-256 `3d1dfbb9bef6f9ddffb6ca3da5a666c81c2302f93677a4db003a260d67ce4e12`.

Conclusion: the immediate focused-link risk introduced by the new YY TLS-aware PE entry-point contract is closed. This is focused compile/link/codegen/binary evidence only; it does not prove the full packaged browser or physical XP teardown behavior.

Full candidate run is already active:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `36294912858`;
- job `108551864059`;
- exact source-under-test `ad96945f101cedc25b9ed40df25bbed25c045833`;
- current status at this documentation update: **in_progress**;
- committed xul/libGLESv2 source-contract gate: success;
- browser build step: in progress;
- ANGLE full-build codegen gate, final packaged-runtime `libGLESv2.dll contract=true` gate, package/runtime artifacts and aggregate verdict: pending.

Status: **focused YY-entrypoint preflight GREEN / full candidate run in progress / physical XP fix not yet proven**.

---

## 2026-09-26 — WinDbg proves libGLESv2 DLL_THREAD_DETACH AV from missing YY TLS entry-point contract

Track: Windows XP SP3 x86 compatibility / ANGLE static TLS lifecycle. Independent of GOST TLS and WebRTC functional evidence.

Exact tested payload remains source `27f4271bddc228f21d64370a3781ba35a92a96e0`, full build run `36164782271`, job `108169777457`, package artifact `10883654763`, diagnostics artifact `10884079570`. The live debugger used the matching `libGLESv2.pdb` for the exact packaged `libGLESv2.dll`.

A graphics-triggered reproduction under WinDbg with child-process debugging produced a first-chance and then unhandled second-chance `0xC0000005` in `libGLESv2!DllMain`. The `DllMain` arguments are physically observed as `fdwReason=3` / `DLL_THREAD_DETACH`. Matching source and PDB map this path to `egl::DeallocateCurrentThread()`, which executes `SafeDelete(gCurrentThread)` for the Windows `thread_local Thread *gCurrentThread`.

Live TLS evidence on the faulting thread:

- the TEB TLS vector and the module TLS slot are present;
- `egl::gCurrentThread` is NONNULL but invalid for the observed dereference;
- the failing instruction performs a read through `gCurrentThread` and raises the second-chance access violation.

YY-Thunks TLS-remediation symbols are present in the same exact DLL, including `g_TlsHeader`, `g_TlsMode`, and `_tls_index_old`, while the observed symbolic mode remains `g_TlsMode=None`. Independent PE inspection of the exact packaged DLL maps its entry point with the matching PDB to ordinary `_DllMainCRTStartup`, not `DllMainCRTStartupForYY_Thunks`. Debugger-derived numeric pointer/memory values are withheld from the public record.

Conclusion: the current physical owner is the `libGLESv2.dll` XP static-TLS lifecycle contract. The DLL contains C++ `thread_local` state and YY-Thunks TLS-remediation code, but its PE entry point bypasses the YY TLS-aware wrapper. The resulting `DLL_THREAD_DETACH` reaches ANGLE with invalid TLS state and produces the second-chance AV. This is a stronger and more specific boundary than the earlier top-level `0x80000007` Watson capture; it does not prove that every earlier `0x80000007` instance had the same initiating mechanism.

Narrow build remediation is now committed on `agent/winrt-source-poc`:

- product commit `482bc4417601fc96f2ab135f377f64e03945cd27`: add the already-proven YY DLL entry-point contract to Windows x86 `gfx/angle/targets/libGLESv2/moz.build`;
- source-gate commit `e8bb142248ccbf03b24f6a7a8cddf510ef54986e`;
- final-binary gate workflow commit `3bb7c0d17112b0ec65cb144f5291ee03431c1550`;
- aggregate blocking-gate commit / current implementation HEAD `ad96945f101cedc25b9ed40df25bbed25c045833`.

The remediation does not change ANGLE runtime logic, the existing `/Zc:threadSafeInit-` fix, D3D9/WebGL policy, or the pre-Vista D3DKMT guard. It changes only the Windows x86 `libGLESv2.dll` linker entry-point contract and CI verification.

Next acceptance: run the full XP x32 workflow from `agent/winrt-source-poc @ ad96945f101cedc25b9ed40df25bbed25c045833`. Build acceptance requires the new final-binary gate to report `libGLESv2.dll ... contract=true`. Physical acceptance then requires the exact artifact to exercise WebGL and exit without the reproduced `DLL_THREAD_DETACH` second-chance AV.

Status: **root-cause owner PROVEN for the captured AV / narrow source remediation committed / CI NOT YET RUN / physical fix NOT YET PROVEN**.

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

---

## 2026-09-28 — WebGL ANGLE D3D9Ex presentation fallback full build GREEN + Windows 10 visible-render PASS

Track: Windows graphics compatibility / WebGL presentation path. Independent of GOST TLS and WebRTC evidence.

Exact build identity:

- branch `agent/winrt-source-poc`;
- source-under-test `705470c0f1fd7302669b1f4d4c9aead33b773928` (`fix(webgl): fall back when ANGLE has no D3D11 device`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `36325907730`;
- job `108638512476`;
- result: **completed / success / GREEN**.

Artifacts bound by GitHub Actions to exact source-under-test `705470c0...`:

- package `10936509397` (`r3dfox-gost-xp-x32-package`), digest `sha256:65552a1e53bf98d25e59039afa3cdc2ee5dba7531bb39b7ef1b422361a1e7dbd`;
- runtime `10937007948` (`r3dfox-gost-xp-x32-runtime`), digest `sha256:56e24e564eee9eb0765053b777315dd91cf074d79e7774b2f84e6da82a5a840f`;
- diagnostics `10936509452` (`r3dfox-gost-xp-x32-diagnostics`), digest `sha256:0176bb946fc349ae2be7e0bbfa07e304519facbd11455381a0faa67804cec33a`.

All recorded blocking build/package/static gates in job `108638512476` completed successfully, including the release browser build, ANGLE XP local-static codegen gate, XP PE/import audit, final packaged-runtime `libGLESv2.dll` YY TLS entry-point contract gate, packaging and aggregate summary.

The source change hardens `GetD3D11DeviceOfEGLDisplay()` and rejects `SurfaceFactory_ANGLEShareHandle` during factory selection when the ANGLE display does not expose a D3D11 device. This allows the existing `InitSwapChain()` fallback to choose `SurfaceFactory_Basic` instead of failing later in `SwapChain::Acquire()` and losing the WebGL context.

Windows 10 control-system runtime result: the user reports testing the newly built browser from this run with the same ANGLE D3D9Ex configuration that previously produced `Swap chain surface creation failed.` / context loss. `get.webgl.org` now visibly renders the rotating cube; the supplied screenshot shows the rendered cube and the page's WebGL-support result. This is a **visible WebGL presentation PASS on Windows 10 for the exact packaged build**.

The Windows 10 runtime is now independently artifact-correlated against package artifact `10936509397`. User-supplied SHA-1 values are `r3dfox.exe=e4a77e076f0355bd7ed10b7e355310103e640cc2`, `xul.dll=553dd042bd47d9db9a8bb2d1656ad2b0de6948f9`, and `libGLESv2.dll=0095e2aa591f1d94a8de86191a3ebe15b6fe08e5`. The same files extracted from the packaged `r3dfox-v153.0.3.win32.zip` member of artifact `10936509397` have identical SHA-1 values. Therefore the Windows 10 rotating-cube result is bound byte-for-byte to exact source `705470c0...` and run `36325907730`.

Physical Windows XP acceptance remains separate. Required next evidence is a real WebGL render on XP (preferably console; RDP may additionally be tested with the WebGL blocklist/force prefs controlled), followed by graphics-triggered normal shutdown without recurrence of the prior `libGLESv2!DllMain` `DLL_THREAD_DETACH` second-chance AV.

Status: **full build/package/static GREEN / artifact-correlated Windows 10 visible WebGL presentation PASS / physical XP WebGL + teardown acceptance pending.**


---

## 2026-09-28 — Exact-package physical Windows XP WebGL presentation FAIL after Win10 fallback PASS

Track: Windows XP SP3 x86 compatibility / WebGL presentation path. Independent of GOST TLS and WebRTC evidence.

Exact tested identity:

- branch `agent/winrt-source-poc`;
- source-under-test `705470c0f1fd7302669b1f4d4c9aead33b773928`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `36325907730`;
- job `108638512476`;
- package artifact `10936509397`;
- `r3dfox.exe` SHA-1 `e4a77e076f0355bd7ed10b7e355310103e640cc2`;
- `xul.dll` SHA-1 `553dd042bd47d9db9a8bb2d1656ad2b0de6948f9`;
- `libGLESv2.dll` SHA-1 `0095e2aa591f1d94a8de86191a3ebe15b6fe08e5`.

These SHA-1 values exactly match the corresponding files independently extracted from package artifact `10936509397`, so the physical XP result is byte-for-byte artifact-correlated to source `705470c0...`.

Physical XP result: `get.webgl.org` does **not** render the cube. The page reports WebGL support but the canvas remains blank. Developer console output includes:

- `TypeError: WebGLRenderingContext.deleteShader: Argument 1 does not implement interface WebGLShader.`;
- a subsequent page-script error because `program` is null;
- `WebGL warning: <Present>: Swap chain surface creation failed.`;
- `WebGL context was lost.`.

The screenshot supplied with the test visibly shows the blank WebGL area and the above presentation/context-loss warnings.

Conclusion: the source `705470c0...` fix is a real Windows 10 presentation-path correction but is **not sufficient on physical Windows XP**. The exact XP payload still reaches `WebGLContext::PresentInto()`, `SwapChain::Acquire()` returns null, and Firefox loses the context. The exact selected `SurfaceFactory` and first failing allocation/query have not yet been captured, so the XP owner below `SwapChain::Acquire()` remains `NOT ESTABLISHED`.

Source-level next boundary: if XP has already selected `SurfaceFactory_Basic`, then `SharedSurface_Basic::Create()` can fail only when `MozFramebuffer::Create(...)` returns null. If a typed factory is still selected, that route must be identified first. Do not assume the Basic/FBO failure until factory selection is measured.

Status: **artifact-correlated physical Windows XP WebGL presentation FAIL / exact failure boundary `SwapChain::Acquire() -> nullptr` PROVEN / selected factory and first failed operation OPEN.**


---

## 2026-09-28 — XP WebGL Basic-surface failure narrowed to zero GL object names

Track: Windows XP SP3 x86 compatibility / WebGL presentation path. Independent of GOST TLS and WebRTC evidence.

Exact runtime remains source `705470c0f1fd7302669b1f4d4c9aead33b773928`, run `36325907730`, job `108638512476`, package artifact `10936509397`, with artifact-correlated SHA-1 values already recorded for `r3dfox.exe`, `xul.dll`, and `libGLESv2.dll`.

The supplied `about:support` capture on physical Windows XP reports Software WebRender, active GPU process, NVIDIA GeForce GT 240 / XPDM-era driver, and `WEBGL default available`. The Graphics failure log contains:
- `RcANGLE(no compositor device for EGLDisplay)`;
- fallback from hardware WebRender to Software WebRender;
- `RcANGLE(no compositor device for EGLDisplay)(Create)`;
- `MozFramebuffer::CreateImpl(size:Size(140,150), samples:0, depthAndStencil:false, colorTarget:0xde1, colorName:0): Incomplete: 0x0`.

The `140x150`, `samples=0`, `depthAndStencil=false` tuple matches the WebGL presentation shared-surface allocation rather than the default WebGL framebuffer. This establishes that the presentation path has reached the existing `SurfaceFactory_Basic` route after the D3D11 share-handle route is unavailable.

The first concrete failure is now below `SharedSurface_Basic::Create()`: `MozFramebuffer::Create()` reaches `CreateImpl()` with `colorName=0`. In source, that value comes directly from `gl->CreateTexture() -> fGenTextures()`. The local GL error scope did not report an error before `CreateImpl()`, and framebuffer status is also logged as `0x0`. A leading hypothesis is that the GL/EGL context is not actually current when the Basic presentation framebuffer is allocated, despite the unforced `MakeCurrent()` call; this is not yet proven.

Next low-cost A/B: disable `webgl.use-canvas-render-thread`, restart the browser, and repeat the exact WebGL page. If the zero-object-name failure disappears, investigate thread/context-current ownership and TLS-current caching before source modification. Otherwise instrument `MozFramebuffer::Create()` to record `MakeCurrent()` result, `IsCurrentImpl()`, generated texture/framebuffer names, and the first GL/EGL error.

Status: **SurfaceFactory_Basic route PROVEN / `glGenTextures -> colorName=0` boundary PROVEN / reason for zero object name OPEN.**


---

## 2026-09-28 — XP WebGL canvas-render-thread A/B negative; d3dcompiler_47 static compatibility checked

Exact runtime remains source `705470c0f1fd7302669b1f4d4c9aead33b773928`, run `36325907730`, job `108638512476`, package `10936509397`.

A/B result: setting `webgl.use-canvas-render-thread=false` and fully restarting the browser does not change the failure. `get.webgl.org` still ends with `<Present>: Swap chain surface creation failed.` and context loss; Graphics failure log still reports `MozFramebuffer::CreateImpl(... colorName:0): Incomplete: 0x0`. Therefore simply moving WebGL work off the canvas render thread does not resolve the zero-object-name boundary.

A follow-up static inspection of the exact packaged `d3dcompiler_47.dll` from artifact `10936509397` shows SHA-1 `60fd000169306c8c7f33f7df175cc5c3a6562ab5`, PE32/i386, subsystem version 5.1, and direct imports limited to XP-era KERNEL32/ADVAPI32/RPCRT4/MSVCRT entry points in the inspected import table. ANGLE's `HLSLCompiler::ensureInitialized()` dynamically loads the configured D3D compiler DLL with `LoadLibraryA`, resolves `D3DCompile` and `D3DDisassemble`, and falls back to `d3dcompiler_old.dll` only if the default compiler DLL cannot be loaded. The package contains `d3dcompiler_47.dll` and no `d3dcompiler_old.dll`.

This static inspection does not prove that `d3dcompiler_47.dll` loads successfully or that shader compilation succeeds on physical XP. Because the page also reports a null WebGL program/shader path before presentation, D3D compiler load/compile behavior is now a legitimate parallel diagnostic target. It is not yet established as the cause of `glGenTextures -> colorName=0`.

Next diagnostic should first verify actual runtime loading of `d3dcompiler_47.dll` and capture any ANGLE HLSL compiler/load failure, while separately preserving the proven Basic framebuffer zero-name boundary.


---

## 2026-09-28 — XP WebGL D3D compiler load failure proven by first-chance STATUS_ENTRYPOINT_NOT_FOUND

Exact runtime remains source `705470c0f1fd7302669b1f4d4c9aead33b773928`, run `36325907730`, job `108638512476`, package artifact `10936509397`.

On physical Windows XP under WinDbg, reloading `get.webgl.org` produces:

- `ModLoad: ...\d3dcompiler_47.dll`;
- immediately followed by first-chance exception `0xC0000139`;
- then the page reports a null WebGL program path, followed by the already-known `<Present>: Swap chain surface creation failed.` and context loss.

`0xC0000139` is `STATUS_ENTRYPOINT_NOT_FOUND`. This establishes that the packaged `d3dcompiler_47.dll` cannot complete normal loader import resolution on XP.

Independent inspection of the exact packaged `d3dcompiler_47.dll` (SHA-1 `60fd000169306c8c7f33f7df175cc5c3a6562ab5`) shows a direct import of `_except_handler4_common` from `msvcrt.dll` together with other CRT imports. Historical Mozilla bug 980697 documented the same XP blocker for D3DCompiler 47: lowering the PE subsystem version was not sufficient because the DLL still depended on Vista-only `_except_handler4_common`.

ANGLE source at this exact branch dynamically loads the configured D3D compiler DLL and, if that load fails, attempts `d3dcompiler_old.dll`. The current package contains `d3dcompiler_47.dll` but no `d3dcompiler_old.dll`.

This does not yet prove which missing import WinDbg encountered first on the current machine; loader snaps should be used if exact symbol identity is required. However the compiler DLL's XP incompatibility itself is now proven.

Next low-cost product-free A/B: provide a known XP-compatible D3D compiler exposing `D3DCompile` and `D3DDisassemble` under ANGLE's fallback filename `d3dcompiler_old.dll`, using a legitimate historical Mozilla/Microsoft redistributable source, and repeat WebGL on the exact package. If shader compilation succeeds but the Basic framebuffer still returns zero GL object names, keep the two blockers separate.


---

## 2026-09-28 — Physical XP WebGL visible-render PASS with legacy D3D compiler fallback

Track: Windows XP SP3 x86 compatibility / WebGL. Independent of GOST TLS and WebRTC evidence.

Base browser identity remains source `705470c0f1fd7302669b1f4d4c9aead33b773928`, run `36325907730`, job `108638512476`, package artifact `10936509397`, with previously recorded artifact-correlated hashes for `r3dfox.exe`, `xul.dll`, and `libGLESv2.dll`.

A single runtime addition was made without rebuilding the browser: `D3DCompiler_43.dll` from an installed 32-bit Firefox 52.9.0 directory was copied beside `r3dfox.exe` and renamed to ANGLE's existing fallback filename `D3DCompiler_old.dll`.

Exact uploaded fallback DLL identity:

- SHA-1 `98be17e1d324790a5b206e1ea1cc4e64fbe21240`;
- PE32/i386;
- PE subsystem target Windows 5.0;
- file/product version `9.29.952.3111`;
- original filename metadata `D3DCompiler_43.dll`;
- exports include both `D3DCompile` and `D3DDisassemble`.

Physical Windows XP result: `get.webgl.org` visibly renders the rotating cube. The user explicitly confirms successful WebGL rendering on XP. The supplied screenshot shows the rendered cube and no WebGL context-loss warnings.

The accompanying `about:support` capture still records Software WebRender, `WEBGL default available`, and the expected hardware-compositor fallback diagnostics (`RcANGLE(no compositor device for EGLDisplay)` / software WebRender fallback). The previous `MozFramebuffer::CreateImpl(... colorName:0): Incomplete: 0x0` failure is absent from the new Graphics failure log. `webgl.use-canvas-render-thread=false` remained set during this successful test, so that pref is not established as required for the PASS.

This A/B is strong evidence that the XP WebGL blocker was the unusable packaged `d3dcompiler_47.dll` path rather than a missing Basic presentation implementation. ANGLE's existing fallback to `d3dcompiler_old.dll` is sufficient when supplied with an XP-compatible D3DCompiler 43 binary. It also explains the earlier shader/program-null errors and the downstream Basic-surface allocation failure disappearing together. Exact internal causality between failed shader compiler initialization and the prior zero GL object name remains inferred rather than directly instrumented.

Historical Mozilla evidence independently matches this result: Firefox's XP-era builds retained `D3DCompiler_43.dll` specifically for Windows XP WebGL, while D3DCompiler 47 was known to depend on Vista-only `_except_handler4_common`.

Acceptance boundary: **physical XP visible WebGL render PASS with base artifact plus injected legacy compiler fallback**. Browser shutdown after this exact graphics workload is not yet recorded here, so the prior graphics-triggered `libGLESv2!DllMain` teardown boundary remains open until explicitly retested.


---

## 2026-09-28 — Physical XP WebGL PASS confirmed with default WebGL prefs

Follow-up acceptance on the same physical Windows XP system and same base browser source `705470c0f1fd7302669b1f4d4c9aead33b773928`, with the same injected legacy compiler fallback `D3DCompiler_old.dll` derived from Firefox 52.9.0 32-bit `D3DCompiler_43.dll`.

The user restored all tested `webgl.*` preferences to their defaults, fully restarted the browser, verified the WebGL prefs were default-valued, and repeated `get.webgl.org`. The rotating cube remained visibly functional.

Therefore none of the temporary preference overrides used during diagnosis (`webgl.force-enabled`, `webgl.ignore-blocklist`, or `webgl.use-canvas-render-thread=false`) is required for the observed XP WebGL PASS.

The supplied screenshot confirms visible rendering after the clean-config restart.

The user's binary comparison between the packaged r3dfox `d3dcompiler_47.dll` and a current Yandex Browser `d3dcompiler_47.dll` shows only two differing bytes at file offsets `0x150` and `0x152`: r3dfox has `05 01`, Yandex has `06 00`. This is consistent with the already-observed r3dfox DLL reporting PE subsystem version 5.1 versus the Yandex DLL retaining subsystem version 6.0. That header-only compatibility difference does not address the XP loader failure caused by the DLL's runtime import contract.

Final current XP WebGL conclusion: **default WebGL prefs + existing ANGLE Basic fallback + XP-compatible D3DCompiler 43 under the existing `d3dcompiler_old.dll` fallback name = visible WebGL PASS on physical XP.**


---

## 2026-09-28 — Focused Firefox 52 ESR D3DCompiler pair smoke GREEN

Workflow `XP D3DCompiler pair smoke`, run `36385541515`, job `108810027817`, source-under-test `9599a02978386c3011bbee46f36d105a3a2e9abb`: completed successfully.

Artifacts:
- `firefox-52.9.0esr-d3dcompiler-pair`: artifact `10953904803`, digest `sha256:66a9ffcb0fcd9c3ba33936e02883021381e13f7fb55674ca1559121b69abd0d2`;
- diagnostics: artifact `10954019191`, digest `sha256:16257fd4241b19ed161e2997caf053e5615cbf6afaa522c5dfb09081738a2f26`.

Pinned source archive:
- Firefox 52.9.0 ESR win32 SDK ZIP;
- archive SHA-256 `c3788c977d19149cc62daf9f4494d08092f836b9e60fa8ef411e05469f4bad4f`.

Verified pair:
- `D3DCompiler_43.dll`: size 2106216, SHA-1 `98be17e1d324790a5b206e1ea1cc4e64fbe21240`, SHA-256 `2f23182ec6f4889397ac4bf03d62536136c5bdba825c7d2c4ef08c827f3a8a1c`, subsystem 5.0, version 9.29.952.3111;
- `d3dcompiler_47.dll`: size 3747512, SHA-1 `dbb91a14563712ee6d7b6361ead29ef43c89fe80`, SHA-256 `3a010ee7186086a7f77b6aec3644e05f8495a84895b90572cab8d4f14efa088e`, subsystem 6.0, version 10.0.14393.33;
- `d3dcompiler_old.dll` is byte-identical to the verified `D3DCompiler_43.dll`.

Both DLLs passed the focused functional probe using `D3DCompile` on a minimal `ps_3_0` shader.

This smoke establishes a reproducible source and exact binary identities for both the XP-compatible legacy compiler and the unmodified Firefox 52 ESR D3DCompiler 47 reference.


---

## 2026-09-28 — D3DCompiler full package gates PASS; broad import audit false-positive isolated to provider-blind `_except_handler4_common` rule

Track: Windows XP SP3 x86 compatibility / D3DCompiler packaging / final PE-import audit. Independent of GOST TLS runtime.

Exact full-build evidence:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `36390265057`;
- job `108824318489`;
- source-under-test `8bb4ef8fed2362030a27e67058be87e12be61bba`;
- package artifact `10962792058`, digest `sha256:a037410334fb59f4c0371ea118b871df0d277967ef1bf1df6270784fafd7df59`;
- runtime artifact `10962781974`, digest `sha256:5ea89f3722a8393985f2b2df322f005beb383ce832a1d5868abce8c9b64f6f3a`;
- diagnostics artifact `10962284979`, digest `sha256:2d6692c671bc4fe68552b044e03c4cea0e8cb8a9fda70641ad4daa8dbc209c8c`;
- final result: completed / failure because aggregate summary received `BROAD_IMPORT_AUDIT_OUTCOME=failure`.

All new D3DCompiler packaging gates passed on this exact build: the pair remained unchanged through PE retargeting, the pinned `d3dcompiler_old.dll` survived portable packaging, the build-produced optional `d3dcompiler_47.dll` survived unchanged, the packaged pair passed the direct `vs_3_0` + `ps_3_0` compile probe, and the CRT/private-DWrite/bcrypt package gates also passed.

The broad audit failure is a gate-policy false positive, not a newly established runtime incompatibility. Its output contains 23 hits and every hit is the bare API name `_except_handler4_common`. Re-reading the per-PE `dumpbin /imports` diagnostics shows that all 23 required PEs import that symbol from the pinned app-local `ucrtbase.dll`, not from system `msvcrt.dll`. The original physical XP evidence that motivated this check concerned an older packaged `d3dcompiler_47.dll` importing `msvcrt.dll!_except_handler4_common`; that provider edge is incompatible with XP, whereas the project-supplied msvcr14x `ucrtbase.dll` is a separately gated XP runtime provider.

Implementation candidate `bbcdbb4a73ddbb168a1c141e371efeaac4c7655d` narrows only this rule: `_except_handler4_common` is no longer globally forbidden by bare symbol name; required PEs are rejected when the direct-import parser observes the specific edge `msvcrt.dll!_except_handler4_common`. The existing optional root `d3dcompiler_47.dll` exception, all other forbidden DLL/API rules, required-PE hard-import rejection for `d3dcompiler_47.dll`, and strict `d3dcompiler_old.dll` contract remain unchanged.

Status: **D3DCompiler full package/static gates PASS on 8bb4ef8 / broad audit policy false-positive PROVEN / provider-scoped audit fix committed at bbcdbb4 / rerun pending / no new physical-runtime claim**.


---

## 2026-09-28 — speculative `_except_handler4_common` broad-audit guard removed

Follow-up to the immediately preceding D3DCompiler audit-policy entry.

The project does not retain a standalone broad-audit rule for `_except_handler4_common`. The physical XP evidence belongs to the specific historical `d3dcompiler_47.dll` loader failure and the corresponding dependency edge observed in that binary; the product fix is the existing ANGLE fallback to pinned XP-compatible `d3dcompiler_old.dll`.

Because root `d3dcompiler_47.dll` is intentionally classified as an optional dynamically loaded modern primary and excluded from the required-XP import contract, extending that historical symbol into a new generic guard for unrelated required PEs had no current owner and violated the project's narrow-remediation discipline. The temporary provider-scoped follow-up rule was therefore removed as well.

Implementation commit `0832bbb1dbbe52f9dde9f101bef2a512c5daf72e` restores the broad audit parser to its simpler previous structure and removes `_except_handler4_common` from the special forbidden policy entirely. All pre-existing forbidden DLL/API checks, required-PE rejection of hard imports on optional `d3dcompiler_47.dll`, and the optional-root compiler exception remain unchanged.

Status: **special `_except_handler4_common` audit policy REMOVED / historical D3DCompiler evidence retained at its exact scope / no runtime claim changed**.


---

## 2026-09-28 — XP-compatible build freezes reported Windows web identity at 10.0

Track: Windows XP SP3 x86 compatibility / web-visible OS identity. Independent of GOST TLS runtime and D3DCompiler packaging evidence.

Implementation commit `94ff24222ce2b05c2f89185778f062120a332881` changes only `netwerk/protocol/http/nsHttpHandler.cpp`. Under the existing C/C++ `MOZ_XP_COMPAT` define, `InitUserAgentComponents()` no longer calls `GetVersionEx` to populate the Windows OS token and instead sets `dwMajorVersion=10`, `dwMinorVersion=0` before formatting `mOscpu`. Non-`MOZ_XP_COMPAT` Windows behavior is unchanged.

Expected web-visible result for the XP-compatible build is `Windows NT 10.0` in the HTTP User-Agent OS token and `navigator.oscpu`; `navigator.platform` remains the normal Windows x86 value `Win32`. The existing r3dfox product token is not changed by this commit. This is a build-mode policy rather than a physical-XP-only runtime branch, so the same XP-compatible binary reports Windows NT 10.0 when run on later Windows versions as well.

Full run `36448769364 / 109017796850` is source-under-test `94ff24222ce2b05c2f89185778f062120a332881` and completed **success / GREEN**, providing full build/package/static acceptance of this exact web-identity implementation. Runtime acceptance still requires the exact produced package on physical XP, with no manual `general.useragent.override`, checking `navigator.userAgent`, `navigator.oscpu`, `navigator.platform`, `navigator.appVersion`, and the actual outgoing HTTP `User-Agent`.

Status: **source implementation committed / full CI build-package-static GREEN / physical runtime evidence pending**.

---

## 2026-09-28 — cleaned D3DCompiler/broad-import candidate full build GREEN

Track: Windows XP SP3 x86 compatibility / D3DCompiler packaging / final PE-import audit. Independent of GOST TLS runtime and the later web-identity change.

Exact full-build evidence:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `36422520907`;
- job `108928478106`;
- source-under-test `0832bbb1dbbe52f9dde9f101bef2a512c5daf72e`;
- run status: `completed`;
- conclusion: `success` / **GREEN**;
- package artifact `10979596508`, digest `sha256:f6e61b5045e192f0ddcb912e3516759bd45384d5c987d64db2a3cb9728a7641b`;
- runtime artifact `10979016989`, digest `sha256:e2ded9fd6f9763ccf47cdabe09225322b1df3a0b931250578705ea792ea54088`;
- diagnostics artifact `10979372043`, digest `sha256:1afc11e0d0e28ffee733322852fce1522631aa9bb65558a33b1083c620a873e3`.

All blocking full-build/package/static gates passed, including the release build, ANGLE XP local-static codegen, core XP direct-import gates, packaged D3DCompiler pair plus SM3 compile probe, CRT/private-DirectWrite/bcrypt packaging checks, final XP PE-floor/direct-import audit, and aggregate summary.

This run proves that removal of the speculative bare `_except_handler4_common` audit rule restores a GREEN full CI result while preserving the existing narrow XP import policy and the packaged legacy D3DCompiler fallback contract.

Evidence boundary: **build/package/static GREEN only**. This does not establish physical Windows XP runtime PASS, WebGL runtime PASS, clean graphics-triggered shutdown, or GOST TLS handshake PASS.

The run predates implementation commit `94ff24222ce2b05c2f89185778f062120a332881` (`MOZ_XP_COMPAT` web-visible Windows version frozen at 10.0), so it must not be cited as evidence for that later change.

Status: **CI GREEN / exact artifacts recorded / physical runtime acceptance pending**.

---

## 2026-09-28 — web-identity exact-source full XP x32 build GREEN

Track: Windows XP SP3 x86 compatibility / web-visible OS identity. Independent of GOST TLS runtime.

Exact full-build evidence:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `36448769364`;
- job `109017796850`;
- source-under-test `94ff24222ce2b05c2f89185778f062120a332881`;
- run status: `completed`;
- conclusion: `success` / **GREEN**;
- package artifact `10990972577`, digest `sha256:042eca7570bccf7df6764eaf6d7caf6dfd3a01b6a67fc3facddfa85bede59aa8`;
- runtime artifact `10990353061`, digest `sha256:4c744ce5abde18d0d5d0c3ed08afaed5141f1767dd860ffed5902323abed4dd8`;
- diagnostics artifact `10990717703`, digest `sha256:60192433e2bcfe0b28e43acb70f95267921a847b60feeb29f8cf42a4e23ca14e`.

All blocking build/package/static gates completed successfully, including the release build, ANGLE XP local-static codegen, XP direct-import gates, packaged D3DCompiler pair plus SM3 probe, CRT/private-DirectWrite/bcrypt packaging checks, final PE-floor/direct-import audit, and aggregate summary.

This is the first full XP x32 build bound to the exact source that freezes the XP-compatible build's reported Windows version at `10.0` in `nsHttpHandler.cpp`.

Evidence boundary: **build/package/static GREEN only**. It does not yet prove the web-visible values on physical XP, WebGL runtime behavior, clean graphics-triggered shutdown, or any GOST TLS handshake.

Next runtime acceptance for this exact package: no manual `general.useragent.override`; verify `navigator.userAgent`, `navigator.oscpu`, `navigator.platform`, `navigator.appVersion`, the outgoing HTTP `User-Agent`, WebGL using the packaged D3DCompiler fallback path, and clean shutdown.

Status: **exact-source CI GREEN / exact artifacts recorded / physical XP runtime acceptance pending**.

---

## 2026-09-29 — exact package physical XP startup/session PASS

Track: Windows XP SP3 x86 compatibility / exact-artifact physical runtime. Independent of GOST TLS runtime.

CI/build identity:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `36448769364`;
- job `109017796850`;
- source-under-test `94ff24222ce2b05c2f89185778f062120a332881`;
- package artifact `10990972577`, digest `sha256:042eca7570bccf7df6764eaf6d7caf6dfd3a01b6a67fc3facddfa85bede59aa8`.

Physical-XP local identity supplied from the running portable directory:

- `r3dfox.exe` SHA-1 `73ee1b683e4410804f4aa113e3057a3a2f50575d`;
- `xul.dll` SHA-1 `fc1c57d8aa5827c76f0e6c51631424acde65438b`;
- `libGLESv2.dll` SHA-1 `e01c0757697214101e9d6aa887576f46011b1c21`;
- `d3dcompiler_47.dll` SHA-1 `ac019f36f22d527b60773e380b473a764721d377`;
- `d3dcompiler_old.dll` SHA-1 `98be17e1d324790a5b206e1ea1cc4e64fbe21240`;
- `application.ini BuildID=20260928163654`, `SourceStamp=94ff24222ce2b05c2f89185778f062120a332881`;
- `platform.ini BuildID=20260928185320`, `SourceStamp=94ff24222ce2b05c2f89185778f062120a332881`.

Artifact correlation was independently checked by downloading package artifact `10990972577`, extracting its `r3dfox-v153.0.3.win32.zip`, and hashing the corresponding files. All five SHA-1 values and both BuildID/SourceStamp pairs match the physical-XP local values exactly.

Physical runtime result: the exact build launches on Windows XP SP3 x86 and sustains a live interactive browsing/network session; the user is using this exact browser build for the current ChatGPT session.

Evidence boundary: **physical XP startup/session PASS**. This does not yet establish the intended web-visible Windows identity, WebGL runtime PASS, graphics-triggered clean shutdown, or GOST TLS handshake PASS.

Status: **artifact-correlated physical XP startup/session PASS / remaining focused runtime checks pending**.

---

## 2026-09-29 — exact package physical XP WebGL PASS; HTTP UA observation pending override exclusion

Track: Windows XP SP3 x86 compatibility / WebGL runtime / web identity. Independent of GOST TLS runtime.

Exact artifact remains run `36448769364`, job `109017796850`, source-under-test `94ff24222ce2b05c2f89185778f062120a332881`, package artifact `10990972577`.

Physical XP WebGL result: **PASS**. On `https://get.webgl.org/`, the page reports `Your browser supports WebGL` and the WebGL cube is visibly rendered on the physical XP desktop. This advances the same artifact-correlated package that already has startup/session PASS.

HTTP web-identity observation from the same running browser:

- `httpbin.org/headers` returns `User-Agent: Mozilla/5.0 (Windows NT 10.0; Win32; x86; rv:153.0) Gecko/20100101 Firefox/153.0`;
- `httpbin.org/user-agent` returns the same value.

The initial observation above was contaminated by a retained manual `general.useragent.override` from earlier UA investigation and therefore was not accepted as source-fix proof.

The override was then explicitly reset/removed, the browser was fully restarted, and `general.useragent.override` was confirmed absent from the profile. After restart, `https://httpbin.org/user-agent` returned:

`Mozilla/5.0 (Windows NT 10.0; rv:153.0) Gecko/20100101 Firefox/153.0 r3dfox/153.0.3`

This clean control closes the server-side HTTP User-Agent boundary for commit `94ff24222ce2b05c2f89185778f062120a332881`: on physical Windows XP, the exact artifact emits `Windows NT 10.0` without a manual UA override, while retaining the normal `r3dfox/153.0.3` product token.

Remaining web-identity check: record `navigator.userAgent`, `navigator.oscpu`, `navigator.platform`, and `navigator.appVersion` from the same no-override session.

Remaining runtime boundary after WebGL PASS: graphics-triggered clean shutdown. GOST TLS remains an independent evidence line.
