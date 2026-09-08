# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-08_pre_xp_build_34213345771.md`](./TEST_LOG_2026-09-08_pre_xp_build_34213345771.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-08 — XP x32 battery legacy-path remediation builds GREEN and removes the Vista-only USER32 delay imports

Track: Windows XP SP3 x86 build/static compatibility. Independent of GOST TLS runtime. This entry is CI/static evidence, not physical-XP runtime proof.

Exact source/build identity:

- branch `agent/winrt-source-poc`;
- source-under-test `db334d39cf929de7a12ea2f74bea32ddc4f3e4e4`;
- battery implementation commit `b68b925efc504ffe6696fc28848f8df0b3cae343` (`fix(xp): use legacy battery power notifications`);
- battery import-gate commit `db334d39cf929de7a12ea2f74bea32ddc4f3e4e4` (`ci(xp): gate Vista-only battery imports`);
- lineage also includes `dad33d25dddc060ee74d773dcc492d835a78fd1e`, which removes the earlier rejected shared-memory access-mask override while preserving the successful child-HANDLE inheritance remediation;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34213345771`, attempt `1`;
- job `102019253738` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / success / GREEN**.

Exact artifacts:

- package `10056086223` (`r3dfox-gost-xp-x32-package`), 327,786,207 bytes, digest `sha256:9135b55913dfcf49390d022b94c21520ed2f5852e8b846f4b117635696634949`;
- runtime `10056088395` (`r3dfox-gost-xp-x32-runtime`), 74,928,371 bytes, digest `sha256:2cf7cf6ca44c0d8abddb930564a65bdf57188f4a2ae0fd5a56b29d7c522ce57f`;
- diagnostics `10056127829` (`r3dfox-gost-xp-x32-diagnostics`), 420,515,830 bytes, digest `sha256:04d284ce8738a63b72508e00747576c56fb2dfb86233e6e460fc1803b4234b33`.

The exact run completed the full Firefox compile/link, package, physical-test runtime archive, diagnostics upload and final aggregate verdict. In particular, all of the following completed `success`:

- `Build release r3dfox XP x32`;
- `GATE - Require XP battery Vista-only USER32 imports absent from xul.dll`;
- `GATE - Require source-remediation quartet absent from xul.dll`;
- `GATE - Require ADVAPI32 compatibility family absent from xul.dll`;
- `GATE - Verify mozglue SetProcessDPIAware stays delay-loaded`;
- `GATE - Reject proven core browser XP direct imports`;
- legacy D3DCompiler staging/retarget/package gates;
- msvcr14x packaged CRT gate;
- pinned bcrypt packaged gate;
- `GATE - Audit XP x32 PE floor and direct imports`;
- YY-Thunks DLL entry-point inventory;
- package/runtime/diagnostics uploads;
- `GATE - Summarize XP x32 full build`.

The new battery gate checks both ordinary and delay-load USER32 imports in final `xul.dll` and passed, so this exact binary no longer contains either of the two Vista-only battery APIs that owned the preceding physical exception path:

```text
RegisterPowerSettingNotification
UnregisterPowerSettingNotification
```

The source remediation is intentionally narrow. Under C/C++ `MOZ_XP_COMPAT`, `hal/windows/WindowsBattery.cpp` keeps the existing hidden window and `GetSystemPowerStatus()` data path but listens for the XP-compatible `WM_POWERBROADCAST / PBT_APMPOWERSTATUSCHANGE` notification. The Vista+ `RegisterPowerSettingNotification` / `UnregisterPowerSettingNotification` path remains unchanged for non-XP builds.

This build is also the planned build-level control for the removal of the rejected `Platform::Freeze()` access-mask experiment: source `db334d...` includes that cleanup plus the already physically successful `base::LaunchApp` child-HANDLE inheritance fallback. Static/build success does not establish that SharedPrefMap remains physically passed; that must be checked on this exact new artifact.

Conclusion: **BUILD/STATIC PASS.** The precise `USER32!RegisterPowerSettingNotification` delay-import edge is absent from the final `xul.dll`, and the complete XP build/package/static contract remains GREEN at source `db334d...` / run `34213345771`.

Physical acceptance remains pending. On physical Windows XP SP3 x86, exercise the exact runtime/package artifact and require both:

1. continued advance past the already closed `SharedPrefMap.cpp:25` / invalid child-HANDLE boundary despite removal of the rejected shared-memory access-mask override;
2. advance past the previous `0xC06D007F` / `USER32!RegisterPowerSettingNotification` delay-load boundary.

If a later failure appears, record the next exact runtime boundary rather than reopening either old hypothesis without contradictory evidence.

Status: **current authoritative XP build/static candidate; physical XP runtime validation pending.**

---

## 2026-09-08 — physical XP `0xC06D007F` localized exactly to `USER32!RegisterPowerSettingNotification`

Track: Windows XP SP3 x86 physical runtime / Windows HAL compatibility. Independent of GOST TLS runtime.

Exact runtime identity remained the preceding physically exercised candidate:

- branch `agent/winrt-source-poc`;
- source-under-test `897e1cdf98bcc091e13283fa8004177971d30f27`;
- workflow run `34194737456`, job `101959901573`;
- user physical `r3dfox.exe` SHA-1 `dbfaed8d2d06d50195a572f8364186e4032f8a97`;
- user physical `xul.dll` SHA-1 `fcc09439c4e36be056b5796303f7e433a7afe585`.

The supplied physical-XP DrWatson capture repeatedly reported exception `0xC06D007F`. Exact package binaries and the matching PDB were recovered from the same run; their identities matched the physical files. Symbolization resolved the main-thread path through:

```text
kernel32!RaiseException
__delayLoadHelper2
_tailMerge_user32.dll
mozilla::hal::ObserversManager<mozilla::hal::BatteryInformation>::AddObserver
mozilla::hal::RegisterBatteryObserver
mozilla::gfx::GPUProcessManager::BatteryObserver::BatteryObserver
mozilla::gfx::GPUProcessManager::OnProcessLaunchComplete
```

The delay-load information in the captured stack established:

- loaded module `USER32.dll`;
- `dwLastError = 0x7f` (`ERROR_PROC_NOT_FOUND`);
- the delay-IAT slot maps exactly to `RegisterPowerSettingNotification`;
- the captured procedure-name string is exactly `RegisterPowerSettingNotification`.

Source ownership is `hal/windows/WindowsBattery.cpp::EnableBatteryNotifications()`. The corresponding `UnregisterPowerSettingNotification` API is the same Vista-era mechanism and must also be absent from the XP-compiled path.

Conclusion: **ROOT CAUSE LOCALIZED.** The physical `0xC06D007F` is an MSVC delay-load failure for `USER32.dll!RegisterPowerSettingNotification`, reached when the GPU process manager creates its battery observer. This is not a YY-Thunks ownership problem and should use the legacy Windows source path rather than a thunk.

Remediation selected for the successor build: under `MOZ_XP_COMPAT`, use XP-compatible `PBT_APMPOWERSTATUSCHANGE` and retain `GetSystemPowerStatus()` for the actual battery snapshot; compile out both Vista-only registration APIs. The successor build/static validation is recorded in the entry above.

Status: **physical root cause established on source `897e1cdf...`; successor source `db334d...` removes the edge statically, but physical closure awaits execution of the successor artifact.**
