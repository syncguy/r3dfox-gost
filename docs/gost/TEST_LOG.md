# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-12_pre_angle_d3d9_graph_pass.md`](./TEST_LOG_2026-09-12_pre_angle_d3d9_graph_pass.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-12 — exact-vendored ANGLE D3D9 generated graph passes the authoritative semantic gate

Track: Windows XP SP3 x86 ANGLE build-graph generation. Independent of GOST TLS runtime and not physical-XP browser-runtime evidence.

Exact experiment identity:

- branch `agent/winrt-source-poc`;
- source-under-test and Actions head SHA `7b214d64fe0110431c73ef9e81f17e37c33b2926`;
- workflow `.github/workflows/xp-angle-d3d9-regenerate.yml` / `XP ANGLE D3D9-only regeneration smoke`;
- run `34684794502`;
- job `103529796175` (`Regenerate exact vendored ANGLE with D3D11 disabled`);
- aggregate result: **completed / success / GREEN**;
- evidence artifact `10295651148` (`xp-angle-d3d9-regeneration-34684794502`), 361,098 bytes, digest `sha256:e680e33dc7a788a6a4b4230c7f12af40e0f0fa97cf837d7bc13e186b09f11c7d`.

The persisted generated `libGLESv2.moz.build` passes the authoritative post-regeneration semantic gate:

- `d3d11_source_refs=0`;
- `d3d9_source_refs=20`;
- `ANGLE_ENABLE_D3D11_TRUE=False`;
- `ANGLE_ENABLE_D3D9_TRUE=True`;
- `Renderer11=False`, `Renderer9=True`;
- `CompositorNativeWindow11=False`;
- `dxgi_format_map_autogen=False`;
- `dxgi_support_table_autogen=False`;
- `dxgi_format_map_header=False`;
- `dxgi_support_table_header=False`;
- shared `d3d_format.cpp=True`;
- `OS_LIBS_d3d11=False`, `OS_LIBS_d3d9=True`.

`OS_LIBS_dxgi=True` is retained only as diagnostic evidence because it is also `True` in the baseline generated file; it is not evidence that the four D3D11-owned DXGI format/support-table sources remain. Likewise `d3d_format.h` is a GN/header dependency and is not required to appear as a compile-source line in this generated `moz.build`.

The artifact also preserves the raw graph evidence: `gn-desc.json` is 582,587 bytes (`sha256:e1750ac65e388cbf56cff1fa69b5860494d97e8b5db5ce102a3700b513165570`) and `export-targets.json` is 126,888 bytes (`sha256:fc8e788b164c572d28515a9d404f2163d789671b18074fc8290e12455faac821`).

One harness distinction is intentional and must remain explicit: the older internal regeneration script still reports `regeneration_step_outcome=failure` after regeneration because its legacy blanket checkout-change verdict is overbroad. The workflow deliberately treats that step as diagnostic and makes the subsequent semantic validator authoritative. In this run the semantic validator reports `semantic validation PASS`, and the aggregate job/workflow result is GREEN. The earlier REDs caused by SDK pinning, shallow merge-base history, native-stderr handling and fragile harness patching are therefore test-infrastructure history, not evidence against the generated D3D9 graph.

Conclusion: **FOCUSED ANGLE SOURCE-GRAPH PASS.** For the exact Firefox/r3dfox 153 vendored ANGLE snapshot, the narrow `angle_d3d_format_tables` split removes the four D3D11-owned DXGI format/support-table files while retaining the D3D9 backend and shared D3D format implementation. The functional correction remains a small conditional in upstream `BUILD.gn`; manually deleting final generated `moz.build` entries is not required.

This does **not** prove a full Firefox/r3dfox XP build, final PE/import cleanliness, physical Windows XP runtime, or GOST TLS behavior. Next evidence boundary: transfer the narrow source-graph fix into the full XP x86 build, inspect the resulting final PE/import evidence independently, and then exercise the exact accepted browser artifact on physical XP.

Status: **current authoritative focused ANGLE D3D9 graph closure.**
