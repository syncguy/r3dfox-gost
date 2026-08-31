# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-30_2026-08-31.md`](./TEST_LOG_2026-08-30_2026-08-31.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); the Windows XP compatibility architecture and import-triage policy are in [`XP_COMPATIBILITY_STRATEGY.md`](./XP_COMPATIBILITY_STRATEGY.md); the source-level WinRT experiment is in [`WINRT_SOURCE_POC.md`](./WINRT_SOURCE_POC.md); formally closed milestones are in [`DONE.md`](./DONE.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-08-31 — sandbox-disabled XP x32 artifact runs correctly on physical Windows 7 x32

Track: Windows Vista/7/XP binary compatibility only; this result is not GOST TLS handshake evidence.

Exact source/build identity:

- source-under-test `1635d28360ee35d47c1d8237bcf8f5864cc1144f` on experiment branch `agent/winrt-source-poc`;
- workflow `GOST TLS PoC build XP x32`;
- Actions run `33310150314`, job `99253613546`;
- runtime artifact `9733280458`;
- the full browser build/package/runtime staging succeeded; the Actions run conclusion is `failure` only because the later broad XP direct-import gate remained red.

Physical Windows 7 x32 runtime observation supplied by the user for this exact build:

- the browser starts and operates correctly on Windows 7 x32;
- build-time `--disable-sandbox` behaves as intended;
- `MOZ_DISABLE_CONTENT_SANDBOX=1` is no longer required in the environment;
- the browser does not show the prior notification/warning associated with runtime sandbox disabling;
- normal Windows 7 x32 browser operation is observed with the sandbox-disabled build.

Conclusion: **PASS for the intended Windows 7 x32 sandbox-disabled runtime baseline.** This confirms that build-time `--disable-sandbox` is the correct inherited x86 compatibility mode for the current XP-oriented artifact and removes the previous need for the `MOZ_DISABLE_CONTENT_SANDBOX=1` runtime workaround on Windows 7 x32. It does not close physical Windows XP startup/browsing, remaining XP PE-import work, or any GOST TLS runtime milestone.
