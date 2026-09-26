# Windows XP x86 ANGLE / DXGI current state

> **Historical snapshot.** This page records the 2026-09-06 DXGI/`CreateDXGIFactory1` closure work and is no longer the active ANGLE/WebGL handoff. Current state is maintained in [PROJECT_STATE.md](PROJECT_STATE.md), [TODO.md](TODO.md), and [TEST_LOG.md](TEST_LOG.md). As of 2026-09-24, product remediation `b01f3461...` has focused codegen GREEN in run `35974426502 / 107551429542`; full browser run `35980235042 / 107570122638` on implementation source `f15a047e...` is in progress. Do not interpret the older “current implementation” text below as the present blocker or next step.

Last updated: 2026-09-24

This document is a handoff note for the current Windows XP SP3 x86 ANGLE/DXGI remediation state. It supplements `PROJECT_STATE.md` and the exact experiment evidence in `TEST_LOG.md`.

## Current implementation scope

The currently proven ANGLE late-binding implementation exists **only** on the XP implementation branch:

- branch: `agent/winrt-source-poc`;
- source-under-test / implementation commit: `4aceb9ea7216b61805789b96de536e53aed73d01` (`test(xp): late-bind DXGI factory in ANGLE Renderer11`);
- changed source file: `gfx/angle/checkout/src/libANGLE/renderer/d3d/d3d11/Trim11.cpp`.

The current code is deliberately **not wrapped in `MOZ_XP_COMPAT`**. The `ANGLECreateDXGIFactory1` late-binding path is therefore compiled unconditionally in this experimental branch state. It resolves `dxgi.dll!CreateDXGIFactory1` with `LoadLibraryW` / `GetProcAddress`, and the diagnostic carrier includes `Renderer11.cpp` through `Trim11.cpp` while the generated `libGLESv2` target list still records `Renderer11=False`.

Do not describe this state as the final production-shaped implementation and do not assume the same code exists on `agent/gost-tls-poc` or `win-153`. `agent/gost-tls-poc` contains the canonical documentation/workflows; the implementation itself remains only on `agent/winrt-source-poc`. `win-153` remains frozen and must not be changed.

The user has explicitly chosen to **leave the code in this state for now**. Do not automatically refactor it behind `MOZ_XP_COMPAT`, restore normal `Renderer11.cpp` target ownership, or otherwise productionize the ANGLE change unless a later explicit task requests that work.

## Proven focused result

The implementation above is bound to:

- Actions run `34012302206`;
- job `101430096691`;
- source-under-test `4aceb9ea7216b61805789b96de536e53aed73d01`;
- result: **success**;
- artifact `9983181080` (`xp-angle-libglesv2-smoke`), digest `sha256:2cc68a6faf74398757bf2cdf7f310739e4c741ee0d43db6cc72515554442c8bd`.

Focused PE evidence:

```text
machine_x86=True
dxgi_dll=False
d3d9_dll=True
CreateDXGIFactory=False
CreateDXGIFactory1=False
```

This proves focused static DXGI import closure while retaining the D3D9 dependency. It does not by itself prove full Firefox integration or physical Windows XP runtime acceptance.

## Full-build implication

A manual full XP build launched from `agent/winrt-source-poc` will checkout that branch's current source and therefore includes the current ANGLE late-binding implementation without requiring an additional workflow-side ANGLE patch. The final packaged `libGLESv2.dll` must still be audited in that exact full-build run before declaring the browser-level DXGI blocker closed.

For default ANGLE D3D display selection, the current source queues D3D11 before D3D9 and tries the next renderer after an initialization failure, so a failed D3D11 initialization can fall through to D3D9. This is not universal for explicit D3D11-only / explicitly requested D3D11 configurations.
