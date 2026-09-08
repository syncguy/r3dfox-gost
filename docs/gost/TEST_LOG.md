# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-07_pre_xp_build_34107793132.md`](./TEST_LOG_2026-09-07_pre_xp_build_34107793132.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-07 — full XP x32 YY DLL entry-point experiment reaches 13/13 contracts; aggregate RED is supplemental warm-relink failure

Track: Windows XP SP3 x86 build/static compatibility. This is independent of GOST TLS runtime and does not prove physical-XP startup or a GOST TLS handshake.

Exact workflow/source identity:

- workflow-definition / run-head branch: `agent/gost-tls-poc`;
- workflow-definition / run-head SHA: `4ea3b94c048436c3f316704c54605567dba975bd`;
- checked-out implementation branch: `agent/winrt-source-poc`;
- source-under-test: `6885135565f7262bb88c80c4751f4a6c4b93e3ef`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34138054280`, attempt `1`;
- job `101793510758` (`Windows x86 / r3dfox GOST / XP YY DLL entry-point experiment`);
- aggregate job conclusion: **failure**.

Exact artifacts were successfully produced before the final summary gate:

- package artifact `10028971959` (`r3dfox-gost-xp-x32-package`), 327,817,004 bytes, digest `sha256:a856a62da534f774d08cb576978a86001bb063848bc7a30edae362db94749920`;
- runtime artifact `10028972525` (`r3dfox-gost-xp-x32-runtime`), 74,931,692 bytes, digest `sha256:29b8b69d59a7c8ac99f1d5919eee1bba7a97f89a0ecdba209ccd821018523391`;
- diagnostics artifact `10028995017` (`r3dfox-gost-xp-x32-diagnostics`), 420,495,148 bytes, digest `sha256:6ff6bb1f934ba814059848fd640312bf422446ece11ead93408782872a48e864`.

The normal full Firefox compile/link succeeded. Packaging, runtime archive creation, source/import compatibility gates, PE floor/direct-import audit, artifact uploads and `GATE - Verify YY-Thunks DLL entry-point coverage` all succeeded.

The preceding all-GREEN build `34107793132` / source `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4` reported:

```text
strong candidates=13
contracts=3
missing-contract candidates=10
```

This exact experiment reports:

```text
strong candidates=13
contracts=13
missing-contract candidates=0
xul_positive_control=true
```

`yy-dll-entrypoint-missing-contract.txt` contains:

```text
none
```

All ten candidates that were missing the contract in run `34107793132` now have `contract=true`:

```text
gkcodecs.dll
gmp-clearkey/0.1/clearkey.dll
gmp-fake/1.0/fake.dll
gmp-fakeopenh264/1.0/fakeopenh264.dll
libGLESv2.dll
mozavcodec.dll
mozavutil.dll
mozglue.dll
mozinference.dll
nss3.dll
```

Interpretation of the YY result: **PASS / CURRENT STRONG-CANDIDATE STATIC YY DLL STARTUP COVERAGE = 13/13, MISSING=0.** The one full build was sufficient to prove the ten additional final DLLs; separate per-library builds are not required merely to reproduce this static result.

The aggregate RED is caused by a separate supplemental experiment, `GATE - Warm-relink early YY DLLs from completed objdir`. It ran under `continue-on-error` but its internal outcome was `failure` because its generated-objdir layout assumptions were wrong:

```text
mozglue.dll   — Expected one local mozglue.dll before warm relink; found 0
nss3.dll      — Expected one generated nss_nss3 target directory; found 0
libGLESv2.dll — Expected one local libGLESv2.dll before warm relink; found 0
```

No intended second relink occurred in that supplemental step. Because `continue-on-error` allowed the job to proceed, GitHub showed the step as completed while preserving its internal failed outcome. The final `GATE - Summarize XP YY x32 full build` inspected that outcome and deliberately made the job RED.

This does not invalidate the normal full-build links: the final produced `mozglue.dll`, `nss3.dll`, `libGLESv2.dll` and the other seven formerly missing candidates all pass the final YY contract audit in diagnostics artifact `10028995017`.

Status: **static YY DLL entry-point/TLS coverage debt for the current 13 strong candidates is closed by source `688513...` / run `34138054280`; aggregate RED is an orchestration/experimental warm-relink issue. Physical XP remains separately blocked by the SharedPrefMap mapping failure observed on the prior exact runtime.**

---

## 2026-09-07 — physical XP: repeated `0x80000003` resolves to `SharedPrefMap.cpp:25`; one separate Moz2D replay assert

Track: Windows XP SP3 x86 physical runtime. This is independent of GOST TLS runtime and does not prove a GOST TLS handshake.

Exact build identity:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4` (`fix(xp): use legacy ProgramData shell folder`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34107793132`, attempt `1`;
- job `101696721232` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- runtime artifact `10018223364`, digest `sha256:ea39193e3f8422ee5e35bbe8f830cef936bb45273eff299392480c17357db61d`;
- diagnostics artifact `10018257313`, digest `sha256:8a4f3939b2bf8d30837060172b7cf4dc5de58dcb4a2b06a4a2e9d7220945a325`.

Physical launch on Windows XP SP3 x86 was performed as:

```bat
set MOZ_GFX_CRASH_MOZ_CRASH=
r3dfox.exe
```

The supplied `drwtsn32.zip` has SHA-256 `0774b0acf721af81f5df715f68738f3ad4ab726d3108d49a09ad2ca105dc94ef`. Its `drwtsn32.log` has SHA-256 `cc50d60c9e611a7599cc17e7f7eca32ad5063a7bdbc6b650fcd7c838cc69c067` and records ten `0x80000003` hardcoded-breakpoint exceptions between `19:50:22.270` and `19:52:40.173` physical-XP local time.

Nine of the ten processes fail at the same `xul.dll` location:

```text
xul load base  0x01bb0000
fault VA       0x01e348e6
fault RVA      0x002848e6
instruction    int 3
```

The exact `xul.dll` from package artifact `10018222073` is 155,288,576 bytes with SHA-256 `ba777e5f72332aa93151c068d82c9ea877a2826bf0058393db680ec6fd595e0e`. The matching `xul.pdb` from diagnostics artifact `10018257313` is 1,864,507,392 bytes with SHA-256 `5748e64d3cfd335a02fac2ec2e906d20db9527d6c7c4151cce89e2ae8c06f326`.

Exact-binary disassembly at RVA `0x002848e6` shows the fatal path stores the crash-reason string `MOZ_RELEASE_ASSERT(map)` and the embedded source line number `25` immediately before `int 3`. Source `modules/libpref/SharedPrefMap.cpp` line 25 is:

```cpp
SharedPrefMap::SharedPrefMap(const ReadOnlySharedMemoryHandle& aMapHandle) {
  auto map = aMapHandle.Map();
  MOZ_RELEASE_ASSERT(map);
```

Therefore the current repeated blocker is **not SpiderMonkey/Wasm**. `ReadOnlySharedMemoryHandle::Map()` returns an invalid mapping on physical XP, and the `SharedPrefMap` constructor deliberately terminates. The previous Wasm attribution of the same assertion text is superseded: `WasmProcess.cpp` also contains `MOZ_RELEASE_ASSERT(map)`, but its exact references carry different embedded line numbers (58, 73, 254), whereas the physically reached site carries line 25.

On Windows, this mapping path reaches `ipc/glue/SharedMemoryPlatform_windows.cpp::Platform::Map`, which calls `MapViewOfFileEx` with `FILE_MAP_READ` for a read-only handle and returns an invalid mapping when `MapViewOfFileEx` returns `NULL`. The current Dr. Watson capture does not preserve the corresponding `GetLastError()`, so handle-rights/duplication, IPC/sandbox transfer, and mapping semantics remain hypotheses rather than conclusions.

One of the ten processes (PID `3036`) reaches a different breakpoint:

```text
fault VA       0x02da8533
fault RVA      0x011f8533
instruction    int 3
```

Exact-binary analysis resolves it to `MOZ_RELEASE_ASSERT(false)` with embedded line number `487`. The matching source is `gfx/webrender_bindings/Moz2DImageRenderer.cpp`: `translator.TranslateRecording(...)` returned false, emitted `Replay failure: ...`, then hit the release assert. This is a separate GFX symptom and is not currently established as the root cause of the nine repeated SharedPrefMap failures.

Interpretation: **PHYSICAL XP START FAIL / CURRENT PRIMARY BLOCKER = READ-ONLY SHARED-PREF MEMORY MAP FAILURE.** The old Shell32 `SHGetKnownFolderPath` boundary is no longer the first reached failure in this exact rebuilt browser. The previous Wasm owner attribution is corrected by exact line-number evidence from this build.

Next diagnostic: instrument the XP Windows shared-memory map failure narrowly enough to preserve `GetLastError()`, handle validity/access context, offset, size, read-only mode and fixed-address request when `MapViewOfFileEx` returns `NULL`. Do not weaken `MOZ_RELEASE_ASSERT(map)` or implement a speculative shared-memory workaround before obtaining that error code.

Status: **current authoritative physical-XP blocker for source `cd5e715...` / run `34107793132`.**

---

## 2026-09-07 — full XP x32 build with current Shell32 source cluster is GREEN

Track: Windows XP SP3 x86 full Firefox build and static-import validation. This is independent of GOST TLS runtime and does not prove a GOST TLS handshake.

Exact source/build identity:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4` (`fix(xp): use legacy ProgramData shell folder`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34107793132`, attempt `1`;
- job `101696721232` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- trigger: `workflow_dispatch`;
- aggregate run/job conclusion: **success**.

The exact job completed the full browser build, packaging, runtime archive, XP import/PE gates, matching-PDB diagnostics, YY-Thunks inventory, all three artifact uploads and final summary successfully.

Exact artifacts:

- package artifact `10018222073` (`r3dfox-gost-xp-x32-package`), 327,794,307 bytes, digest `sha256:e2d535dc622c67cffb754f8bcafbb6d89127e7cdd7d0e40a298c2f675fda5b38`;
- runtime artifact `10018223364` (`r3dfox-gost-xp-x32-runtime`), 74,928,765 bytes, digest `sha256:ea39193e3f8422ee5e35bbe8f830cef936bb45273eff299392480c17357db61d`;
- diagnostics artifact `10018257313` (`r3dfox-gost-xp-x32-diagnostics`), 420,489,482 bytes, digest `sha256:8a4f3939b2bf8d30837060172b7cf4dc5de58dcb4a2b06a4a2e9d7220945a325`.

Interpretation: **PASS / CURRENT SOURCE CLUSTER IS BUILD-VALID AT EXACT SHA `cd5e715...`.** This result proves compile/package/static compatibility gates only. Physical-XP runtime acceptance is separate and, for this exact build, now fails at the SharedPrefMap mapping boundary recorded immediately above.

Status: **current authoritative all-GREEN build/static baseline for source `cd5e715...` / run `34107793132`; later run `34138054280` strengthens static YY DLL coverage to 13/13 but is aggregate RED for the separately logged warm-relink orchestration issue.**