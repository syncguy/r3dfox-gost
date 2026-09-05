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
