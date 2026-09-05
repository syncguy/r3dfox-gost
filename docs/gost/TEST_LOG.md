# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-05_pre_reggetvaluew_closure.md`](./TEST_LOG_2026-09-05_pre_reggetvaluew_closure.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-05 — focused `ADVAPI32!RegGetValueW` XP x86 probe passes through narrow YY-Thunks provider

Track: Windows XP SP3 x86 compatibility / focused ADVAPI32 registry import closure only. This is not full Firefox integration, physical-XP browser acceptance, or GOST TLS runtime/handshake evidence.

Exact source/build identity:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `8ad1d5e9a935ed1cce8ee268f693af72aad1f7c4` (`test(xp): extend ADVAPI32 YY probe with RegGetValueW`);
- workflow `.github/workflows/xp-core-kernel32-cluster-smoke.yml` / `XP x86 core KERNEL32 cluster smoke`;
- Actions run `33946751857`, attempt `1`;
- job `101254130849`;
- run/job conclusion: **success**.

Exact artifacts:

- runtime artifact `9963660843` (`xp-core-kernel32-cluster-runtime`), `665282` bytes, digest `sha256:358dddbf5539db7596260b005117da11b99216d5b307c01bb75f6a8652fe6375`;
- diagnostics artifact `9963661150` (`xp-core-kernel32-cluster-diagnostics`), `1065875` bytes, digest `sha256:e90cb2629935594a5c4964c9b604665f87a8c9cb8f514e9a8b18ef1a2cb84005`.

The exact job is fully GREEN. The focused sequence successfully completed narrow YY provider construction, ordinary x86 probe compilation/linking, PE/direct-import gating, hosted execution, the already-existing `NtCancelIoFileEx` probe, and `Build and run ADVAPI32 YY probe`; the physical-XP runtime bundle and both evidence uploads also completed successfully.

Conclusion: **PASS / FOCUSED `ADVAPI32!RegGetValueW` YY-THUNKS CLOSURE PROVEN.** The existing physically narrow YY-Thunks provider approach can satisfy the newly added `RegGetValueW` compatibility case without adopting broad ADVAPI32 interposition. This solution is now a proven focused building block and should not be re-investigated unless contradictory evidence appears.

Evidence boundary: this focused smoke proves capability only. It does **not** prove that final production Firefox binaries no longer carry an XP-incompatible `RegGetValueW` import, does not prove physical-XP browser startup, and proves nothing about GOST TLS runtime or handshake behavior.

Next integration boundary: transfer only the proven `RegGetValueW` provider/alias solution into a new full XP x32 Firefox build, bind that build to its own exact source SHA/run/job, and require final PE/import evidence for the production binaries before declaring browser-level closure. Then test the exact resulting runtime on physical XP. Keep the independent `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1` static compatibility line separate.

Status: **current focused solution; full-browser integration still open.**

---

## 2026-09-05 — first two focused ANGLE `libGLESv2` runs expose a harness target-selection defect

Track: Windows XP SP3 x86 compatibility / ANGLE-DXGI focused build harness only. This is not GOST TLS runtime evidence and neither failed run is valid evidence about the final `libGLESv2.dll` import table.

Exact source/run identity shared by both manual dispatches:

- source branch/ref: `agent/winrt-source-poc`;
- source-under-test SHA: `2e4da5002f77b5cedf7285ee302da3a4bca07cea` (`test(xp): add focused ANGLE libGLESv2 smoke`);
- workflow: `.github/workflows/xp-angle-libglesv2-smoke.yml` / `XP ANGLE libGLESv2 smoke`;
- run `33949834809`, job `101262393084`, conclusion **failure**;
- run `33952062351`, job `101268597022`, conclusion **failure**.

Exact evidence:

- run `33949834809` diagnostics artifact `9964674275` (`xp-angle-libglesv2-smoke`), digest `sha256:4c0c4a5aeee9ff331cbc861cee7aff65b7aae2e119a835c28ad2115c139ff0db`;
- run `33952062351` diagnostics artifact `9965329387` (`xp-angle-libglesv2-smoke`), digest `sha256:e2ff47eee0b4e9cfe7856474180ea103a2f80a640f5d5e34d2610bb7691dce60`.

In both jobs, step `Build libGLESv2 only` was reported GREEN and the following `GATE - Inspect focused libGLESv2 binary` failed because `libGLESv2.dll` was absent. The build log resolves the apparent contradiction. `mach build gfx/angle/targets/libGLESv2` emitted:

```text
Build argument 'gfx/angle/targets/libGLESv2' is a subdirectory and was ignored.
...
Your build was successful!
```

Therefore the build system did not build the requested ANGLE shared-library target at all; the subsequent missing-DLL exception is a harness consequence, not an ANGLE compile/link failure. No DXGI or D3D9 conclusion may be drawn from either run.

A second diagnostics defect was also identified: `angle-source-baseline.txt` incorrectly recorded `ANGLE_ENABLE_D3D9=False` and `ANGLE_ENABLE_D3D11=False` because the PowerShell literal search contained erroneous quote escaping. The source file at this SHA actually contains both `DEFINES["ANGLE_ENABLE_D3D9"] = True` and `DEFINES["ANGLE_ENABLE_D3D11"] = True`.

Harness remediation on canonical/default branch `agent/gost-tls-poc`:

- commit `9b942b831b4a10da2d78556170482f946c4df35e` replaces the ignored directory-form `mach build` invocation with an explicit generated-objdir `mozmake -C obj-angle-xp-x32\gfx\angle\targets\libGLESv2 libs` target and adds a guard against the prior ignored-target warning;
- commit `6034d61a7efdfb4903bd2e2570b2abde7a345ca2` fixes the D3D9/D3D11 baseline literal detection;
- the focused workflow is now reusable through `workflow_call` as well as manually dispatchable, so a minimal XP-branch trigger can invoke the canonical workflow without duplicating its build logic.

Conclusion: **FAIL / HARNESS DEFECT CONFIRMED; ANGLE/DXGI EXPERIMENT NOT YET EXECUTED.** The next valid experiment must first prove that the focused harness actually produces an x86 `libGLESv2.dll`, then inspect its real PE imports. Only after that baseline is valid should the D3D11-OFF / D3D9-ON source experiment begin.

Status: **historical harness diagnosis; superseded by the later valid focused baseline run `33976374784`.**

---

## 2026-09-05 — focused ANGLE build reaches real link prerequisite and exposes missing `pure_virtual.lib`

Track: Windows XP SP3 x86 compatibility / ANGLE-DXGI focused build harness only. This is not GOST TLS runtime evidence and the failed run still does not establish the final `libGLESv2.dll` import table.

Exact identity:

- canonical workflow branch: `agent/gost-tls-poc`;
- workflow-trigger SHA: `6a817ae8bbfedf5b48179081a32b76a897760d4a` (`ci(xp): preserve ANGLE native warnings in smoke`);
- checked-out source branch: `agent/winrt-source-poc`;
- actual source-under-test SHA recorded after checkout: `3106657906d2d93e12530308982f866b81065519`;
- workflow `.github/workflows/xp-angle-libglesv2-smoke.yml` / `XP ANGLE libGLESv2 smoke`;
- Actions run `33965678827`, attempt `1`;
- job `101305268403`;
- conclusion: **failure**;
- diagnostics artifact `9969684836` (`xp-angle-libglesv2-smoke`), digest `sha256:e36a23da111b968b3dd44c59650d887996e0f3cefe8c2e58d21d9514a1b30792`.

The preceding PowerShell/native-stderr harness defect is fixed: ordinary clang warnings no longer terminate the build. The focused `libGLESv2` compile proceeds through ANGLE source compilation and resource generation, then stops at a real generated-build dependency:

```text
mozmake: *** No rule to make target '../../../../build/pure_virtual/pure_virtual.lib', needed by
'../../../../dist/bin/libGLESv2.dll'.  Stop.
```

At the exact source-under-test SHA, `build/pure_virtual/moz.build` defines `Library("pure_virtual")`, `FORCE_STATIC_LIB = True`, so `pure_virtual.lib` is a normal sibling static-library prerequisite. The focused harness had run only `recurse_pre-export`, `recurse_export`, then direct `mozmake` in `gfx/angle/targets/libGLESv2`; that direct subdirectory invocation assumes the sibling library artifact already exists and has no rule to construct it from there.

Conclusion: **FAIL / FOCUSED BUILD PREREQUISITE GAP CONFIRMED.** This is a harness/build-graph prerequisite issue, not evidence that ANGLE source cannot compile, not a `CreateDXGIFactory1` result, and not a GOST TLS result. The final `libGLESv2.dll` link/import inspection has still not been reached.

Remediation: canonical workflow commit `82e4da3cb9e681d9c24c4f6e1aa2e9a3a7677bc9` explicitly builds `obj-angle-xp-x32/build/pure_virtual` and verifies `pure_virtual.lib` before invoking the focused `libGLESv2` compile. The next experiment is the automatic run triggered by that workflow commit; only its exact run/source identity may advance the ANGLE/DXGI conclusion.

Status: **historical prerequisite diagnosis; superseded by the later valid focused baseline run `33976374784`.**

---

## 2026-09-05 — focused ANGLE `libGLESv2` baseline fully builds and confirms `dxgi.dll!CreateDXGIFactory1`

Track: Windows XP SP3 x86 compatibility / ANGLE-DXGI focused PE/import baseline only. This is independent of the `xul.dll` ADVAPI32 runtime line and is not GOST TLS runtime/handshake evidence.

Exact source/build identity:

- canonical workflow branch/ref: `agent/gost-tls-poc`;
- workflow/head SHA: `94849e95211a2a3dd4ff7df6e694b3c86f5a7f39` (`ci(xp): prebuild dllservices mozglue contributor`);
- checked-out source branch: `agent/winrt-source-poc`;
- actual source-under-test SHA recorded by the artifact after checkout: `5d4d40c9b3c6fc39fe17c03bef864193f63fcb31`;
- workflow `.github/workflows/xp-angle-libglesv2-smoke.yml` / `XP ANGLE libGLESv2 smoke`;
- Actions run `33976374784`, attempt `1`;
- job `101333682681`;
- run/job conclusion: **success**.

Exact evidence artifact:

- artifact `9972876541` (`xp-angle-libglesv2-smoke`), `1797735` bytes, digest `sha256:3bd464b4e1376a9cc727bdc2756a7e5543a0c39acac64aad4504e6b386e6386d`.

The job is fully GREEN through the decisive focused boundaries:

- `Build libGLESv2 link prerequisites` — success;
- `Inspect focused mozglue binary` — success;
- `Build libGLESv2 only` — success;
- `GATE - Inspect focused libGLESv2 binary` — success.

The artifact contains the actual focused output `obj-angle-xp-x32\dist\bin\libGLESv2.dll`, SHA-256 `677eec30aaa4ceee734ebef818f44cfc855a7f6c8c9241c997ed7e933736d7ca`. `libGLESv2-result.txt` records:

```text
machine_x86=True
dxgi_dll=True
d3d9_dll=True
CreateDXGIFactory=False
CreateDXGIFactory1=True
```

The raw `dumpbin` import inventory independently shows the ordinary import:

```text
dxgi.dll
    CreateDXGIFactory1
```

and also retains the expected D3D9 surface, including `d3d9.dll!Direct3DCreate9`.

The matching source baseline records:

```text
ANGLE_ENABLE_D3D9=True
ANGLE_ENABLE_D3D11=True
libGLESv2_dxgi_link=True
gpu_info_dxgi_link=True
Renderer9=True
Renderer11=True
```

Conclusion: **PASS / VALID FOCUSED ANGLE BASELINE; `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1` CONFIRMED DIRECTLY IN THE BUILT PE.** The earlier focused failures were harness/prerequisite failures; this run is the first valid focused build/import result in this line. The DXGI blocker is therefore no longer inferred only from a full-browser audit or source inspection.

Evidence boundary: this is a focused component build on a hosted runner. It does **not** prove full Firefox integration, physical-XP runtime behavior, or any GOST TLS behavior. `dxgi.dll` is absent on the recorded physical XP baseline, so the direct dependency remains incompatible with that XP environment until remediated at the ANGLE/`libGLESv2.dll` owner boundary.

Next experiment: make the narrow XP ANGLE source/build change that disables the D3D11/DXGI path while retaining D3D9, rebuild this same focused target, and require a real x86 `libGLESv2.dll` whose import gate shows `dxgi.dll=False` / `CreateDXGIFactory1=False` while the intended D3D9 path remains present. Only after that focused result should the change move to a full XP Firefox build.

Status: **current authoritative focused ANGLE/DXGI baseline; remediation still open.**

---

## 2026-09-05 — diagnostic-enabled focused ANGLE build is GREEN and proves bulk prerequisite preflight

Track: Windows XP SP3 x86 compatibility / focused build-harness methodology using the ANGLE `libGLESv2` target. This is build-graph diagnostic evidence only; it is not physical-XP runtime proof and not GOST TLS runtime/handshake evidence.

Exact source/build identity:

- canonical workflow branch/ref: `agent/gost-tls-poc`;
- workflow/head SHA: `720085a648254ce4e1aa6457be71681163a7836e` (`ci(xp): add fast dependency dry-run diagnostics`);
- checked-out source branch: `agent/winrt-source-poc`;
- actual source-under-test SHA recorded by the artifact after checkout: `5d4d40c9b3c6fc39fe17c03bef864193f63fcb31`;
- workflow `.github/workflows/xp-angle-libglesv2-smoke.yml` / `XP ANGLE libGLESv2 smoke`;
- Actions run `33976858570`, attempt `1`;
- job `101334969800`;
- run/job conclusion: **success**.

Exact evidence artifact:

- artifact `9972991054` (`xp-angle-libglesv2-smoke`), digest `sha256:b53521859aa86b88ab16a8d16f5492fbf810b1a7b67c2c9f3f62aa4772c5d043`.

The new `Quick dependency dry-run diagnostics` step executes `mozmake -n -k compile` against the generated `mozglue\build` and `gfx\angle\targets\libGLESv2` target directories after configure/export setup. It records all unique lines matching `No rule to make target|needed by` rather than stopping at the first missing build-graph edge. For this exact run the summary reported:

```text
mozglue|dry_run_exit=2|missing_lines=87
libGLESv2|dry_run_exit=2|missing_lines=422
```

These counts are matched diagnostic lines, not a count of unique prerequisite files. The nonzero dry-run exit is expected when the purpose is to inventory incomplete focused-target closure; it is diagnostic state and not the acceptance gate.

The same job then executed the real prerequisite closure and build. `Build libGLESv2 link prerequisites`, `Inspect focused mozglue binary`, `Build libGLESv2 only`, and `GATE - Inspect focused libGLESv2 binary` all completed successfully. Therefore the dry-run can expose a large unresolved prerequisite set in one pass without falsely implying that the target itself cannot build once its contributors are constructed.

The final PE result remains the already-established baseline:

```text
machine_x86=True
dxgi_dll=True
d3d9_dll=True
CreateDXGIFactory=False
CreateDXGIFactory1=True
```

Conclusion: **PASS / DIAGNOSTIC-ENABLED FOCUSED BUILD GREEN; BULK MISSING-PREREQUISITE PREFLIGHT PROVEN USEFUL.** For new focused generated-object-directory targets, dependency discovery should no longer proceed by repeated long builds that expose one `No rule to make target` edge at a time. A non-gating `-n -k` preflight should first collect the available missing-prerequisite inventory, then the real build and its output/binary gates remain authoritative.

Evidence boundary: the preflight does not execute compilation/linking and cannot discover failures that occur only while commands run. A clean or informative dry-run is never build proof. If the dry-run cannot expose the actual blocker, improve the diagnostic or proceed to the real focused build rather than weakening its gate.

Status: **current build-harness methodology baseline; generalized as a project rule in `/AGENTS.md`.**
