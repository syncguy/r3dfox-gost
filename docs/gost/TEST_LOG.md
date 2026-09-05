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

Status: **current harness diagnosis; replacement validation run pending.**

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

Status: **current focused blocker remediated in harness; validation run pending.**
