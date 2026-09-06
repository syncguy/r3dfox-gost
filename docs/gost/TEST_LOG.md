# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-06_pre_full_xp_green.md`](./TEST_LOG_2026-09-06_pre_full_xp_green.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-06 — full XP x32 build is GREEN after closing all currently discovered build/static blockers

Track: Windows XP SP3 x86 compatibility / full Firefox build, packaging and static import closure. This is independent of GOST TLS runtime and does not prove a GOST TLS handshake.

Exact source/build identity:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `176eb94b503e773334593508df408fa491faa45f`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34027798932`, attempt `1`;
- job `101471779766`;
- aggregate run/job conclusion: **success**.

Exact evidence artifacts:

- package artifact `9989656813` (`r3dfox-gost-xp-x32-package`), `327776567` bytes, digest `sha256:67e490b43001c092f2cb403d88273fd722b9cec5d6b72d1c2bcea02f74fea886`;
- runtime artifact `9989657830` (`r3dfox-gost-xp-x32-runtime`), `74920900` bytes, digest `sha256:64b0f5a0ccf94900fa882069369e26d3beaf46fa128f7b6b650c44d1e87c2c2f`;
- diagnostics artifact `9989658809` (`r3dfox-gost-xp-x32-diagnostics`), `5999340` bytes, digest `sha256:9e3e9e2e6fac3f0a33a17d94bdf0460edd1020c61c388307a2f8ccd78e2f50fb`.

The exact job completed the substantive full-build sequence, packaging, compatibility/import gates, evidence collection and final summary with **success**. This is the first current full-build candidate after integrating the accumulated XP compatibility work, including the previously isolated WS2_32 and ANGLE/DXGI blockers, for which the workflow itself is fully GREEN rather than stopping at the final compatibility summary gate.

Interpretation: **PASS / CURRENT FULL-BUILD AND STATIC-COMPATIBILITY CLOSURE.** All incompatibilities currently discovered by this build/audit line have been walked through far enough for this exact Firefox 153 XP x86 candidate to build, package and pass the workflow's current static compatibility gates. The active project blocker therefore moves beyond build/link/import closure.

Evidence boundary: this result is not physical Windows XP runtime acceptance. A GREEN CI build cannot establish that no runtime-only missing export, delay-load edge, subsystem behavior, or other XP-specific incompatibility remains. It also proves nothing new about the independent GOST TLS handshake path.

Next boundary: run the exact runtime artifact `9989657830` from source `176eb94b503e773334593508df408fa491faa45f` on physical Windows XP SP3 x86. If it starts, advance through representative browser use and record the first runtime edge, if any. Any future runtime conclusion must remain bound to this exact run/job/SHA/artifact identity.

Status: **current authoritative full XP x32 build/static baseline; build/static blockers currently known are closed, physical-XP runtime validation is next.**