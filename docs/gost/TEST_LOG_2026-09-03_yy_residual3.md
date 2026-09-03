# Experiment Log — 2026-09-03 — XP x86 YY residual-three GREEN

Track: Windows XP SP3 x86 compatibility / focused YY-Thunks residual KERNEL32 closure. This is not GOST TLS runtime/handshake evidence.

Exact evidence identity:

- branch: `agent/winrt-source-poc`;
- source-under-test: `ffb72c4ae6988a7c4f82b4e67a9027e41afb572b`;
- workflow: `.github/workflows/xp-core-kernel32-cluster-smoke.yml` / `XP x86 core KERNEL32 cluster smoke`;
- Actions run: `33712987285`, attempt 1;
- job: `100516220327` (`Core post-XP API cluster / XP x86`);
- job result: **success**;
- runtime artifact: `9877671991` (`xp-core-kernel32-cluster-runtime`), size `647453`, digest `sha256:7019174cb87bed77832b98138d850fa0d5577f7686acb4f5dc1a3610328fcfbe`;
- diagnostics artifact: `9877672471` (`xp-core-kernel32-cluster-diagnostics`), size `1015661`, digest `sha256:4b9679d2f419e9fd3ab8dba58a060e9ad6f67cbe437dda43cce99aa93b7f2334`.

Required delta:

- `InitOnceExecuteOnce`;
- `GetThreadPreferredUILanguages`;
- `QueryFullProcessImageNameA`.

Observed gates:

- YY capability inventory: PASS;
- required-delta capability gate: `required_delta_capability=PASS`;
- physically narrow YY provider construction: PASS;
- native x86 link: PASS;
- XP PE/direct-import gate: `cluster_import_gate=PASS`;
- hosted runtime: all three required APIs report `PASS`;
- overall hosted probe: `Overall: PASS`, `ExitCode=0`;
- physical-XP runtime bundle creation/upload: PASS.

Capability inventory confirms a direct weak-alias `.obj`, matching `.obi`, expected x86 stdcall decorated symbol and `YY_Thunks_*` implementation marker for each required API:

- `InitOnceExecuteOnce` -> `_InitOnceExecuteOnce@16`;
- `GetThreadPreferredUILanguages` -> `_GetThreadPreferredUILanguages@16`;
- `QueryFullProcessImageNameA` -> `_QueryFullProcessImageNameA@16`.

Semantic runtime coverage:

- `InitOnceExecuteOnce`: eight threads share one `INIT_ONCE`; callback executes exactly once and all successful callers observe the expected context;
- `GetThreadPreferredUILanguages`: size/count query followed by real buffer query; non-empty result required;
- `QueryFullProcessImageNameA`: current-process query must return a non-empty path.

Conclusion: **FOCUSED GREEN.** These three APIs are no longer unproven YY candidates. They are ready to be transferred into the full Firefox XP x86 physically narrow provider/link ownership model. The full-browser early import gate should then reject all three direct imports.

Evidence boundary: this run is focused capability/link/PE/hosted-runtime proof. It does not by itself prove full Firefox consumption of the selected YY members, physical-XP execution of the focused bundle, browser startup/browsing on XP, or GOST TLS behavior.

Next experiment: integrate these selected members into the real full Firefox link(s), respecting `mozglue.dll`/`xul.dll` ownership, rerun the full XP x32 workflow, and require the actual core PE import inventories to contain none of the three symbols. The remaining known hard KERNEL32 source-remediation queue is `GetApplicationRestartSettings`, `RegisterApplicationRestart`, `UnregisterApplicationRestart`, and `GetNamedPipeServerProcessId`. `PROPSYS.dll` remains a separate stage.