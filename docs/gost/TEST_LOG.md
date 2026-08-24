# r3dfox GOST TLS — Experiment Log

This is an append-oriented engineering log. It preserves the evidence behind `PROJECT_STATE.md` so future work does not have to reconstruct old conclusions from chat history.

For each completed experiment, record:

- exact date;
- branch and commit SHA;
- GitHub Actions run/job when applicable;
- hypothesis/change;
- observation;
- conclusion;
- whether the finding is current, superseded, or still open.

Do not silently rewrite a failed experiment into a successful one. Add a new entry when understanding changes.

---

## 2026-08-22 — First full build used for GOST runtime testing

**Track:** GOST TLS runtime  
**Branch:** `agent/gost-tls-poc`  
**Commit:** `9b7e4b23f09b760dddfa40981e293f69416d7eff`  
**Actions run:** `32558048307`  
**Workflow:** `GOST TLS PoC build`  
**CI result:** successful build

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32558048307>

### Purpose

Produce a complete browser build containing the initial MSSPI-backed GOST socket layer and test it against `fzs.roskazna.ru`.

### Runtime observation

The runtime log established that:

- the host allowlist matched `fzs.roskazna.ru`;
- the MSSPI GOST layer attached;
- the connection then failed in the MSSPI lower-transport callback path rather than completing the handshake.

The failure pointed at the way the MSSPI callbacks reached the NSPR lower `PRFileDesc` after the custom layer had been pushed.

### Conclusion

**Superseded transport failure.** The PoC routing and layer attachment were real, but the callback/lower-layer plumbing was not yet stable enough to diagnose the actual server handshake.

The next change needed to stabilize the callback argument and resolve the real lower transport after `PR_PushIOLayer`.

---

## 2026-08-22 — Stabilize MSSPI callbacks across the NSPR push

**Track:** GOST TLS runtime  
**Branch:** `agent/gost-tls-poc`  
**Commit:** `caa420c25bcc2693137666b625e62a1b58fdcb0f`  
**Commit message:** `fix(gost): stabilize MSSPI transport callbacks across NSPR push`  
**Actions run:** `32571061759`  
**Workflow:** `GOST TLS PoC build`  
**CI result:** successful, attempt 2

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32571061759>

### Change

`nsGostSSLIOLayer.cpp` was changed so that:

- `GostSecret` stores `PRFileDesc* lower`;
- MSSPI receives `GostSecret*` as its stable callback argument instead of relying on the originally supplied layer pointer;
- after `PR_PushIOLayer`, the code resolves the active GOST layer with `PR_GetIdentitiesLayer` and stores its real `lower` transport;
- `LowerRead` and `LowerWrite` operate on that stored transport;
- close/shutdown handling was tightened.

### Runtime test

The resulting build was run with:

```bat
set R3DFOX_GOST_HOSTS=fzs.roskazna.ru

r3dfox.exe -no-remote ^
  --MOZ_LOG=timestamp,sync,GostTLS:5 ^
  --MOZ_LOG_FILE=C:\\Temp\\r3dfox-gost ^
  https://fzs.roskazna.ru/
```

### Key observed sequence

The log showed:

```text
allowlist matched host=fzs.roskazna.ru
MSSPI GOST layer attached

GostWrite amount=229, handshake not complete
DriveHandshake
LowerWrite len=198 -> rv=198
LowerRead len=18432 -> pending, osError=10035
msspi_connect -> pending, state MSSPI_READING (0x00000002)

later:
LowerRead len=18432 -> rv=1039
LowerWrite len=7 -> rv=7
msspi_connect -> rv=0, error=0x80090308
state -> MSSPI_ERROR (0x40000000)
```

A subsequent call reported `0x0000054f` / `ERROR_INTERNAL_ERROR` while MSSPI was already in `MSSPI_ERROR`.

### Conclusions

**Confirmed:** the previous NSPR transport callback problem is fixed.

Evidence:

- all 198 initial output bytes reached the lower socket;
- would-block (`10035`) was correctly treated as nonblocking pending I/O;
- a later read received 1039 real bytes from the peer;
- therefore Poll/LowerRead/LowerWrite and the pushed-layer lower transport are functioning sufficiently to reach the real SSPI handshake failure.

**Current blocker:** `InitializeSecurityContextA` rejects the 1039-byte server input with `SEC_E_INVALID_TOKEN` (`0x80090308`).

**Secondary error:** the later `0x54f` is not the initiating failure; MSSPI is already in its terminal error state.

**Leading interpretation:** the 7-byte write after the server response is very likely an SSPI-generated TLS Alert. This remains a hypothesis until the exact bytes are logged.

### Next runtime experiment

Instrument the MSSPI callback boundary to capture/parse:

1. the 198-byte initial TLS output;
2. the 1039-byte server input;
3. the complete 7-byte post-failure output.

From those bytes determine the offered/selected cipher suite and TLS alert description before changing transport logic again.

---

## 2026-08-22/23 — VC-LTL static CRT mismatch finding

**Track:** Windows Vista/7 build compatibility  
**Status:** retained negative finding

### Experiment/failure

An earlier VC-LTL integration forced linker directives equivalent to selecting the static C++ runtime inside a Firefox build that otherwise uses the dynamic CRT model.

The linker exposed the mismatch through `/failifmismatch`, with objects in an `MD_DynamicRelease` world conflicting with `libcpmt.lib` / `MT_StaticRelease`.

### Conclusion

Do **not** fix Win7 compatibility by injecting the static CRT into Firefox's existing `/MD` build.

VC-LTL/YY-Thunks integration must preserve the Firefox runtime-library model and should be judged by actual final imports. This finding is independent of the current GOST TLS `SEC_E_INVALID_TOKEN` runtime failure.

---

## 2026-08-23 — YY-Thunks / Rust Win7 experiment series

**Track:** Windows Vista/7 build compatibility

This sequence explored which import libraries/order can remove or redirect Win8+ imports introduced through Rust `libstd`/`gkrust` without changing the whole Firefox CRT model.

### Experiment commits

- `09546d605e73fd32e72eb49edb6a9abbd026617f` — `ci: add YY-Thunks Rust Win7 smoke test`.
- `9a66088635d2d2b1a5876d37ea2499c6d9afbb7a` — `ci: test YY-Thunks API-set import library before Rust libstd`.
- `a76bb469be18daa135e4d477cd092b9713d98140` — `ci: use YY-Thunks synchronization import library`.
- `a73f18e823c083c970eea649ce305da648640e2f` — `ci: link YY-Thunks sync and kernel32 libs before gkrust`.
- `1b2c329589d8a256ea5615bf2eb15027b0624787` — `ci: test YY-Thunks 1.2.2 in Rust smoke`.
- `79061580dabae72a03f78e66fe8b90d1f1cb1ee7` — `ci: test VC-LTL 5.2.2 with YY-Thunks 1.2.2`.

The newest dedicated smoke configuration at `79061580...` combines:

- YY-Thunks 1.2.2;
- VC-LTL 5.2.2 (`TargetPlatform/6.0.6000.0/lib/x64`);
- thunk-rs 0.3.5 provisioning;
- Rust `nightly-2026-08-20`;
- baseline and multiple explicit linker-order variants;
- PE-import auditing for forbidden Win8+ synchronization/crypto/API-set imports.

### Full-build result: whole YY `kernel32.lib` before `gkrust` does not scale

**Actions run:** `32623108290`  
**Job:** `97162633898`  
**Workflow:** `GOST TLS PoC build - thunk-rs experiment`  
**Run SHA:** `a73f18e823c083c970eea649ce305da648640e2f`  
**CI result:** failed in `Build r3dfox` while linking `xul.dll`

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32623108290>

The `a73f18e...` experiment deliberately inserted YY-Thunks `synchronization.lib` and the complete YY-Thunks `kernel32.lib` before the Rust static library so that `WaitOnAddress` / `WakeByAddress*` and `ProcessPrng` could be intercepted before Rust raw-dylib imports won resolution.

The full Firefox link exposed a symbol collision that the smaller smoke had not modeled:

```text
lld-link: error: duplicate symbol: LockResource
>>> defined at gkrust.lib(48d3f1b29a630f4c-gl.o)
>>> defined at kernel32.lib(kernel32.dll)
```

### Conclusion

**Failed hypothesis at Firefox scale.** Prepending the complete YY-Thunks `kernel32.lib` before `gkrust.lib` is too broad. It exposes ordinary kernel32 definitions early enough to collide with symbols also emitted by Rust raw-dylib import objects inside `gkrust.lib`; `LockResource` is the first observed collision.

This is a Windows Vista/7 linker result only. It does not change the independent GOST TLS `SEC_E_INVALID_TOKEN` runtime failure.

The earlier tiny smoke result that accepted a thunk-first order is therefore insufficient as a scale-up proof: the smoke must reproduce the Rust archive/raw-dylib collision class, not just produce an executable with clean final imports.

### Next Win7 linker experiment

Do **not** launch another full Firefox build yet.

Use `.github/workflows/yy-thunks-rust-smoke.yml` on the newer YY-Thunks 1.2.2 + VC-LTL 5.2.2 line to:

1. reproduce the `LockResource` collision class with a Rust archive/raw-dylib import surface representative of `gkrust.lib`;
2. keep the specialized YY-Thunks `synchronization.lib` available for `WaitOnAddress` / `WakeByAddress*`;
3. test a narrow resolution for `ProcessPrng` that does not prepend the entire YY `kernel32.lib` before the Rust archive;
4. gate on both successful linking and absence of the forbidden Win8+ imports;
5. only after a smoke variant passes both conditions, transfer that exact linker strategy into the full Firefox link and spend another full-build cycle.

---

## Open experiment queue as of 2026-08-23

### GOST TLS runtime

1. Add structured/full TLS-buffer diagnostics around MSSPI I/O.
2. Decode the current ClientHello.
3. Decode the server's 1039-byte response and ServerHello cipher selection.
4. Decode the complete 7-byte output after `SEC_E_INVALID_TOKEN`.
5. Compare the result with Chromium-Gost's explicit MSSPI cipher-list setup.
6. If justified by the capture, test an explicit GOST TLS 1.2 cipher list such as `C100:C101:C102:FF85:0081`, preferably behind a diagnostic override rather than silently changing baseline behavior.

### Windows Vista/7 build compatibility

1. Reproduce the `LockResource` duplicate-symbol class in the short YY-Thunks/Rust smoke on YY-Thunks 1.2.2 + VC-LTL 5.2.2.
2. Find a narrow linker configuration that redirects the required Win8+ Rust imports without placing the whole YY `kernel32.lib` before `gkrust`.
3. Require the smoke to pass both linker-conflict and PE-import gates.
4. Run the next full Firefox build only after the smoke identifies a clean strategy.
5. Keep CRT-model compatibility (`/MD`) separate from import-thunking decisions.

---

## 2026-08-23 — Narrow ProcessPrng closing smoke stopped on COFF weak-alias detection

**Track:** Windows Vista/7 build compatibility  
**Branch:** `agent/gost-tls-poc`  
**Commit under test:** `517950bb31d232a0a5173c01c47c9c171e9b242d`  
**Actions run:** `32639164528`  
**Job:** `97193471177`  
**Workflow:** `YY-Thunks narrow ProcessPrng closing smoke`  
**CI result:** failed in `Build one physically narrow YY ProcessPrng provider`

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32639164528>

### Hypothesis

Test one narrow linker strategy: isolate the real YY-Thunks 1.2.2 `ProcessPrng` redirect/implementation members from YY's complete `kernel32.lib`, combine that provider with `synchronization.lib`, and then require a representative Rust raw-dylib link plus a clean Win7 PE-import audit without supplying the complete YY `kernel32.lib` to the final linker.

### Observation

The provider-discovery step failed with:

```text
Expected exactly one YY-backed ProcessPrng redirect member; found 0
```

The later Rust archive, final link, and PE-import audit steps were skipped. The diagnostics artifact `yy-thunks-processprng-closing-smoke-diagnostics` was uploaded as artifact `9493229238`.

Per-member `dumpbin /symbols` evidence shows that the failure was in the harness model, not evidence that the YY redirect is absent:

```text
ProcessPrng.obi:
002 ... UNDEF ... External     | __imp_YY_Thunks_ProcessPrng
003 ... UNDEF ... WeakExternal | __imp_ProcessPrng
    Default index        2 Alias record

ProcessPrng.obj:
002 ... UNDEF ... External     | YY_Thunks_ProcessPrng
003 ... UNDEF ... WeakExternal | ProcessPrng
    Default index        2 Alias record
```

A separate `YY_Thunks_for_6.1.7600.0.obj` member defines both `YY_Thunks_ProcessPrng` and `__imp_YY_Thunks_ProcessPrng`.

The failed workflow only parsed ordinary `External` records and required a non-`UNDEF` plain `ProcessPrng`/`__imp_ProcessPrng` definition. YY encodes these redirects as two `UNDEF WeakExternal` alias records whose `Default index` points at the prefixed YY symbol, so the detector necessarily returned zero candidates.

The common YY implementation object is monolithic and contains normal undefined dependencies such as `__imp_LoadLibraryExW`, but it does not define the previously colliding ordinary `LockResource`/`__imp_LockResource` surface. Therefore undefined implementation dependencies must not be confused with broad ordinary definitions exported by the provider; the final PE audit remains the decisive compatibility gate.

### Conclusion

**Harness failure; original narrow-provider linker hypothesis remains untested by this run.**

Run `32639164528` does not prove the narrow YY strategy works, but it also does not disprove it. It established the actual YY-Thunks 1.2.2 archive anatomy needed for the next attempt:

1. `ProcessPrng.obj`: `ProcessPrng -> YY_Thunks_ProcessPrng` weak alias;
2. `ProcessPrng.obi`: `__imp_ProcessPrng -> __imp_YY_Thunks_ProcessPrng` weak alias;
3. `YY_Thunks_for_6.1.7600.0.obj`: real prefixed implementation.

The smoke harness was corrected in commit `83208f74718cc70ad8c65081d2771b5babe60f09` to recognize and validate those two COFF weak aliases explicitly, select only those alias members plus the implementation member, reject defined broad ordinary kernel32 surface, keep exactly one final link candidate, and retain the final PE-import audit.

### Next Win7 experiment

Dispatch `.github/workflows/yy-thunks-processprng-smoke.yml` at `83208f74718cc70ad8c65081d2771b5babe60f09`.

Do not run a full Firefox build yet. The corrected smoke must first reach the representative Rust link and PE-import audit. If it fails, stop at the exact next gate instead of adding another linker candidate.

---

## 2026-08-23 — Closing smoke reached Rust link but probe rlib name was rejected

**Track:** Windows Vista/7 build compatibility  
**Branch:** `agent/gost-tls-poc`  
**Commit under test:** `5ab5fdf5bcf832eb15ad7d4c6f2db7635da4abed`  
**Actions run:** `32642384623`  
**Job:** `97201364265`  
**Workflow:** `YY-Thunks narrow ProcessPrng closing smoke`  
**CI result:** failed in `Link exactly one candidate`

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32642384623>

### Observation

The corrected weak-alias/provider gates and representative Rust archive build passed. The final Rust invocation then failed before the linker experiment because the probe archive was named `yy_processprng_probe.rlib` and `rustc --extern` rejected that path as an unknown extern type.

```text
error: extern location for yy_processprng_probe is of an unknown type:
...\\yy_processprng_probe.rlib
```

The final PE audit was skipped.

### Conclusion

**Harness failure, not a linker-strategy result.** The provider construction and representativeness checks advanced past the earlier weak-alias failure, but this run did not test the final link because the rlib filename did not use Rust's standard `lib<crate>.rlib` form.

Commit `d32ef97dac1faa5d51fe7e2b4d2ace9c6b47ec11` renamed the archive to `libyy_processprng_probe.rlib` and added a narrow push trigger for this smoke workflow.

---

## 2026-08-23 — Narrow ProcessPrng strategy linked cleanly; raw audit produced a basename false positive

**Track:** Windows Vista/7 build compatibility  
**Branch:** `agent/gost-tls-poc`  
**Commit under test:** `d32ef97dac1faa5d51fe7e2b4d2ace9c6b47ec11`  
**Actions run:** `32643370376`  
**Job:** `97203781090`  
**Workflow:** `YY-Thunks narrow ProcessPrng closing smoke`  
**Diagnostics artifact:** `9494281868`  
**CI result:** failed in `Audit final PE imports`

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32643370376>

### Observation

This run reached and completed the representative final Rust/LLD link. The diagnostics prove all of the intended linker-side invariants:

- `final-link.map` contains `YY_Thunks_ProcessPrng` and maps `ProcessPrng` to the same address;
- `__imp_ProcessPrng` and `__imp_YY_Thunks_ProcessPrng` also map to the same address;
- the complete YY `kernel32.lib` was not supplied to the final linker;
- the full YY Lib directory was not supplied through `LIBPATH`;
- the representative `LockResource` raw-dylib control linked without the previous duplicate-symbol failure.

The job then reported:

```text
Win7-incompatible imports survived: ProcessPrng
```

However, inspection of the uploaded `final-imports.txt` shows that this is not an actual PE import. The raw `dumpbin /imports` output contains no imported `ProcessPrng`, no `bcryptprimitives.dll`, no `api-ms-win-core-synch-l1-2-0.dll`, and no `WaitOnAddress` / `WakeByAddressAll` / `WakeByAddressSingle`. It does contain the expected `KERNEL32.dll` and `LockResource` positive controls.

The only `ProcessPrng` substring in the complete dump text is the executable path itself:

```text
Dump of file ...\\processprng-closing-smoke\\processprng-closing-smoke.exe
```

The audit at `d32ef97...` used case-insensitive `IndexOf` against the entire raw dump text, so the executable basename caused a false positive.

### Conclusion

**The exact narrow linker strategy satisfies the intended smoke evidence in run `32643370376`; the red Actions result is an audit-harness false negative.**

This is stronger than the earlier harness failures because the actual link and PE were produced and can be audited from the artifact. The evidence shows:

1. YY's two ProcessPrng weak aliases were selected;
2. the YY implementation was selected;
3. the broad whole-YY-`kernel32.lib` collision path was absent;
4. the forbidden ProcessPrng / Win8+ synchronization imports are absent from the actual final import table;
5. `LockResource` remains an ordinary `KERNEL32.dll` import.

For a formal green CI gate, commit `fd925b1780fa3470a2cfba743a7374f7d7e644d6` replaces raw substring scanning with exact parsed DLL/API import names and writes the parsed sets into diagnostics.

### Next Win7 experiment

Run the same closing smoke at `fd925b1780fa3470a2cfba743a7374f7d7e644d6`. Do not change the linker strategy and do not run the full Firefox build until the corrected audit records a formal PASS. If that run is green, transfer this exact narrow ProcessPrng + `synchronization.lib` strategy into the Firefox `xul.dll` link as the next single experiment.

---

## 2026-08-23 — Narrow ProcessPrng closing smoke formally passed

**Track:** Windows Vista/7 build compatibility  
**Branch:** `agent/gost-tls-poc`  
**Commit under test:** `fd925b1780fa3470a2cfba743a7374f7d7e644d6`  
**Actions run:** `32644291202`  
**Job:** `97207125757`  
**Workflow:** `YY-Thunks narrow ProcessPrng closing smoke`  
**Diagnostics artifact:** `9494650310`  
**CI result:** success

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32644291202>

### Observation

Every substantive gate passed: narrow provider construction, representative Rust archive construction, the single final Rust/LLD link, exact PE-import audit, and diagnostics upload.

The uploaded diagnostics confirm the intended final state:

- `ProcessPrng` and `YY_Thunks_ProcessPrng` resolve to the same address in `final-link.map`;
- the narrow provider is supplied together with YY `synchronization.lib`;
- the complete YY `kernel32.lib` path and the full YY Lib directory are absent from the final link inputs;
- parsed imported DLLs are only `KERNEL32.dll`, `msvcrt.dll`, and `ntdll.dll`;
- parsed imported API names contain the positive-control `LockResource`;
- parsed imported API names do not contain `ProcessPrng`, `WaitOnAddress`, `WakeByAddressAll`, or `WakeByAddressSingle`;
- `bcryptprimitives.dll` and `api-ms-win-core-synch-l1-2-0.dll` are absent.

### Conclusion

**Representative-smoke confirmation of the narrow linker strategy.** The previous whole-YY-`kernel32.lib` approach remains disproved, while the exact narrow `ProcessPrng` provider plus `synchronization.lib` strategy passes both the raw-dylib collision model and the final PE-import gate.

This does not yet prove that the strategy scales to Firefox's full `xul.dll` link or that the resulting browser is Windows 7-compatible at runtime.

### Next Win7 experiment

Transfer this exact strategy, without adding a second linker candidate, into `.github/workflows/gost-poc-build-thunk.yml`:

1. use YY-Thunks 1.2.2;
2. build the narrow provider from `ProcessPrng.obj`, `ProcessPrng.obi`, and `YY_Thunks_for_6.1.7600.0.obj`;
3. keep YY `synchronization.lib`;
4. remove complete YY `kernel32.lib` interposition and do not add the full YY Lib directory to final `LIBPATH`;
5. preserve Firefox's `/MD` CRT model;
6. run one full Firefox build and apply an exact parsed import audit to the produced `xul.dll`.

Only that full-scale result can establish whether the passing smoke strategy survives the real Firefox link.

---

## 2026-08-23/24 — GetSystemTimePreciseAsFileTime: discovery, smoke closure, and xul-scale closure

**Track:** Windows Vista/7 build compatibility  
**Branch:** `agent/gost-tls-poc`

### Event chain

1. **Run `32647338452`, job `97213486474`, commit `0eb29ecccaa3d2a0762af17e458c42cf245410d7`.** The full Firefox build/package succeeded with the narrow ProcessPrng strategy. The exact xul import audit then identified the next hard direct blocker: `KERNEL32.dll!GetSystemTimePreciseAsFileTime`, a Windows-8+ API.
2. **Commit `b3c3d3b00c6e4a76fbfaa615b9104828c26e78ba`.** The first attempt to add precise-time members directly to the full workflow had the correct narrow-provider intent but corrupted embedded-Python `\\n` literals into physical YAML-breaking line breaks. It is not experimental proof.
3. **Run `32692410607`, commit `08203bb0d7023b7186dc11e4d765f0349aadf076`.** GitHub rejected `.github/workflows/gost-poc-build-thunk.yml` around line 446 before creating a build job, confirming the YAML corruption.
4. **Run `32680494331`, job `97296220325`, commit `cdef097b1912f68232de13d5e41b1a84add466d6`.** The focused `YY-Thunks precise-time closing smoke` passed on its first attempt. It selected `GetSystemTimePreciseAsFileTime.obj`, `GetSystemTimePreciseAsFileTime.obi`, and `YY_Thunks_for_6.1.7600.0.obj`, verified both COFF weak aliases, rejected broad ordinary surface, linked a representative Rust raw-dylib probe without complete YY `kernel32.lib`, and removed `GetSystemTimePreciseAsFileTime` from the final PE imports while keeping `LockResource` as a normal KERNEL32 positive control.
5. **Run `32695496647`, job `97336702701`, commit `ae3d52f42b8b6b509c1263418bead8bb9324dd00`.** Full xul-scale integration completed narrow-provider construction, libxul patching, full release build, package, release upload, import audit, and diagnostics upload. Release artifact: `9512347999`; diagnostics artifact: `9512349511`. Only the final policy gate failed.

### Run 32695496647 evidence

The diagnostics establish that `GetSystemTimePreciseAsFileTime` is absent from the final xul direct-import list and absent from the raw `dumpbin /imports` text. `ProcessPrng`, `WaitOnAddress`, `WakeByAddressAll`, `WakeByAddressSingle`, and `GetOverlappedResultEx` are also absent from the checked direct-import set.

`xul-thunk-win7-forbidden-direct-imports.txt` contains exactly `GetQueuedCompletionStatusEx`. That symbol is a genuine direct KERNEL32 import in this `xul.dll`, but the gate classification was wrong: Microsoft documents `GetQueuedCompletionStatusEx` with minimum supported client Windows Vista. It is therefore valid on Windows 7 and is not a Win8+ loader blocker.

The direct-import conclusion is reliable. A separate diagnostics limitation was also found: `dumpbin` formats delay-load API lines differently from ordinary import lines. The workflow correctly switches direct/delay sections and records delay DLL names, but the API-name regex used by `ae3d52f4...` only matches the ordinary-import line shape. Consequently `xul-thunk-win7-delay-import-api-names.txt` is empty and must not be interpreted as evidence that the binary has no delay-loaded APIs. Re-parsing the retained raw dump with the delay-load line shape yields 504 unique delay API names, including known post-Win7 candidates such as `GetAutoRotationState`, `GetPointerFrameTouchInfo`, `GetPointerType`, `CoIncrementMTAUsage`, `RoActivateInstance`, `RoGetActivationFactory`, and Windows string APIs. This diagnostics limitation does not affect the direct-import gate or the conclusion about precise-time closure.

### Conclusion and follow-up

The narrow ProcessPrng + precise-time strategy is now proven at Firefox `xul.dll` build/package scale. The previous hard blocker `GetSystemTimePreciseAsFileTime` is closed at the direct PE-import level. This is not Windows 7 runtime proof.

Commit `e2a9c3bcbbdfade62a15a144da9117e249cc6305` removes only the Vista-supported `GetQueuedCompletionStatusEx` false positive from the Win8+ hard blacklist; the linker strategy is unchanged. The next full result should validate the corrected direct-import gate. After that, fix/replay the delay-load API parser before using delay-load diagnostics for runtime-path conclusions.

This result is independent from the GOST TLS runtime blocker `SEC_E_INVALID_TOKEN`.

---

## 2026-08-24 — Portable build from run 32695496647 starts on Windows 7

**Track:** Windows Vista/7 build compatibility  
**Branch:** `agent/gost-tls-poc`  
**Build Actions run:** `32695496647`  
**Build job:** `97336702701`  
**Build commit:** `ae3d52f42b8b6b509c1263418bead8bb9324dd00`  
**Release artifact:** `9512347999`  
**Portable package:** `r3dfox-v153.0.3.win64.portable.7z`  
**Package SHA-256:** `534adf0777685f554f8948e19d84042b84520d9521a6f6084534c84c6558c08b`  
**Runtime result:** user-reported successful launch on Windows 7

### Observation

The exact portable package extracted from release artifact `9512347999` was copied to a Windows 7 system and launched successfully. The browser reaches normal process/browser startup instead of failing at the Windows loader because of an unresolved direct import.

No separate runtime log was supplied for this check, so the evidence scope is deliberately narrow: **startup of this exact x64 portable build on Windows 7 is confirmed**. This test does not by itself establish that every browser feature, every delay-loaded post-Win7 API path, or the GOST TLS handshake works on Windows 7.

### Conclusion

**Target-OS startup proof obtained.** For the exact build from run `32695496647` / commit `ae3d52f42b8b6b509c1263418bead8bb9324dd00`, the Windows 7 compatibility line has progressed beyond build/link/import analysis to successful execution on the target OS.

This materially strengthens the narrow YY-Thunks strategy result: the produced browser is not merely linkable/packageable with a cleaned direct-import surface; it actually starts on Windows 7.

The remaining Win7 work is broader runtime coverage rather than proving basic process startup. In particular, delay-loaded post-Win7 APIs still need path/guard analysis and representative feature exercise. The separate GOST TLS runtime blocker remains `SEC_E_INVALID_TOKEN`; successful Windows 7 startup does not prove a successful GOST TLS handshake.

---

## 2026-08-24 — TLS-buffer A/B capture exposed the HTTP proxy as the actual peer

**Track:** GOST TLS runtime  
**Branch:** `agent/gost-tls-poc`  
**Build commit:** `08203bb0d7023b7186dc11e4d765f0349aadf076`  
**Actions run:** `32692411195`  
**Job:** `97328339347`  
**Workflow:** `GOST TLS PoC build`  
**CI result:** success  
**Runtime target:** `fzs.roskazna.ru` through the configured system HTTP proxy

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32692411195>

### Change under test

The build added two diagnostics/controls in `nsGostSSLIOLayer.cpp`:

- exact pre-handshake `TLSBUF` hex logging at the MSSPI lower-I/O callback boundary;
- an explicit default TLS 1.2 GOST cipher list `C100:C101:C102:FF85:0081`, with `R3DFOX_GOST_CIPHERS=default` retaining the old MSSPI native cipher-list behavior for A/B comparison.

### Forced GOST-list observation

With no `R3DFOX_GOST_CIPHERS` override, the log confirmed:

```text
AddToSocket set_cipherlist ... ok=1 source=gost-default list=C100:C101:C102:FF85:0081
TLSBUF direction=out ... len=122 ...
```

The 122-byte TLS 1.2 ClientHello contains exactly five offered cipher suites:

`C100 C101 C102 FF85 0081`

The next lower-socket input was 1038 bytes beginning with:

```text
HTTP/1.1 400 Bad Request
Via: 1.1 ASUGATE
Connection: close
Proxy-Connection: close
```

The HTML body identifies proxy address `10.138.1.254`, server `ASUGATE.ctikem.ru`, and source `proxy`. MSSPI then failed with `SEC_E_INVALID_TOKEN` (`0x80090308`).

### Native-default control observation

With `R3DFOX_GOST_CIPHERS=default`, the log confirmed that the explicit cipher call was skipped. MSSPI emitted the previous 198-byte ClientHello with its broader native suite set plus the five GOST suites.

The next input was the same 1038-byte ASUGATE HTTP 400 response. MSSPI additionally emitted:

```text
15 03 03 00 02 02 0A
```

Decoded as TLS 1.2 Alert, payload length 2, level `fatal`, description `unexpected_message`. `msspi_connect` then returned `SEC_E_INVALID_TOKEN`, followed by the already-known secondary `0x0000054f` after MSSPI was in `MSSPI_ERROR`.

### Conclusion

**The earlier interpretation of the roughly 1039-byte input as a real `fzs.roskazna.ru` TLS server flight is superseded.** The bytes are plaintext HTTP from the enterprise HTTP proxy, not ServerHello/Certificate data from the origin.

The actual failure chain is:

```text
Firefox needs HTTP CONNECT to the proxy
  -> GOST layer starts MSSPI on the first socket I/O
  -> MSSPI ClientHello goes directly to ASUGATE
  -> ASUGATE returns HTTP 400
  -> SSPI receives HTTP bytes where it expects TLS
  -> fatal unexpected_message / SEC_E_INVALID_TOKEN
```

This test also proves that `msspi_set_cipherlist` is wired correctly and materially changes the ClientHello. It does **not** prove whether the forced GOST list is required by the origin, because neither captured ClientHello reached `fzs.roskazna.ru`.

**Current runtime blocker:** the GOST TLS layer must participate correctly in Firefox's HTTP CONNECT lifecycle and defer MSSPI until Necko calls `ProxyStartSSL()` after a successful tunnel.

### Follow-up implementation

Commit `4887e07d847b1c3c2e13b491dcc85f50ddaa9804` implements the proxy-lifecycle fix candidate: HTTP-proxy I/O remains plaintext pass-through until `ProxyStartSSL()` activates MSSPI. This implementation still requires the existing main-workflow SSL compile gate and a new runtime log before the blocker can be considered fixed.

---

## 2026-08-24 — msvcr14x + Rust libstd + narrow YY-Thunks coexistence smoke passed

**Track:** Windows Vista/7 build compatibility  
**Branch:** `agent/msvcr14x-win7-smoke`  
**Commit under test:** `1abf867307ca56b97b7f2fb41e5e58e86ee08463`  
**Actions run:** `32713958570`  
**Job:** `97391163925`  
**Workflow:** `msvcr14x Rust YY coexistence smoke`  
**CI result:** success

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32713958570>

### Hypothesis

Test whether the modern Windows 7 compatibility pieces can coexist in one representative final PE without changing Firefox's dynamic CRT model:

- ordinary C++ `/MD` / `MD_DynamicRelease` object;
- Rust `nightly-2026-08-20` and real `libstd` surface;
- YY-Thunks 1.2.2 `synchronization.lib`;
- one physically narrow YY provider for `ProcessPrng` and `GetSystemTimePreciseAsFileTime`;
- pinned `msvcr14x` commit `6495947edbdd8f5dc4b2ddb8ca0cb5dbdac05384` supplying the compatible UCRT/C++ runtime import libraries.

The smoke explicitly forbids supplying the complete YY `kernel32.lib` or the full YY library directory to the final link.

### Observation

The run completed successfully. Its final gates require and therefore confirm for the produced representative executable:

- the C++ helper remains `MD_DynamicRelease`;
- Rust libstd's `ProcessPrng` and synchronization surface links through YY-Thunks 1.2.2;
- `GetSystemTimePreciseAsFileTime` resolves through the same narrow YY provider;
- `LockResource` remains a normal `KERNEL32.dll` raw-dylib positive control without the earlier duplicate-symbol collision;
- the full YY `kernel32.lib` is absent from the final link command;
- direct imports do not contain `ProcessPrng`, `WaitOnAddress`, `WakeByAddressAll`, `WakeByAddressSingle`, `GetSystemTimePreciseAsFileTime`, or `GetOverlappedResultEx`;
- direct DLL imports contain neither `api-ms-win-*` / `ext-ms-*` nor `VCRUNTIME140.dll` / `VCRUNTIME140_1.dll`;
- the selected runtime DLLs include `ucrtbase.dll` and `msvcp140.dll`;
- the final probe executes successfully on the Windows 2022 runner.

### Conclusion

**Representative coexistence hypothesis confirmed.** `msvcr14x`, modern Rust/libstd, and the proven narrow YY-Thunks strategy can coexist in one `/MD` final link without reintroducing the broad YY `kernel32.lib` collision class or the tested direct CRT/API-set/Win8+ hard imports.

This is representative-link proof, not yet Firefox/xul-scale proof and not a Windows 7 runtime proof for an `msvcr14x`-integrated browser.

### Next Win7 experiment

Move directly to one full Firefox/xul integration experiment using the same proven combination. Preserve Firefox's `/MD` model and the existing narrow YY provider. Make `msvcr14x` the selected CRT/UCRT import-library surface at link time, package its required app-local runtime DLLs, and audit the produced Firefox PE set for direct `api-ms-win-*`, `ext-ms-*`, `VCRUNTIME140*.dll`, and the known Win8+ hard imports before target-OS testing.

---

## 2026-08-24 — First complete GOST TLS page load through the system HTTP proxy

**Track:** GOST TLS runtime  
**Branch:** `agent/gost-tls-poc`  
**Build commit:** `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`  
**Actions run:** `32710363486`  
**Job:** `97380247020`  
**Workflow:** `GOST TLS PoC build`  
**CI result:** success  
**Release artifact:** `9518011746` (`r3dfox-gost-win64-release`)  
**Runtime target:** `fzs.roskazna.ru` through the configured system HTTP proxy / ASUGATE

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32710363486>

### Change under test

Commit `4887e07d...` defers MSSPI TLS until Firefox/Necko finishes the HTTP CONNECT tunnel and invokes `ProxyStartSSL()`. Before activation the GOST NSPR layer passes proxy traffic transparently to the lower transport.

The same source commit also passed the dedicated SSL compile check in run `32710363528`, job `97380247058`.

### Runtime evidence

Two runtime logs from this exact release build were captured:

1. default explicit GOST list `C100:C101:C102:FF85:0081`;
2. control mode `R3DFOX_GOST_CIPHERS=default`, which keeps the MSSPI native cipher list.

Both logs show the intended proxy lifecycle:

```text
tlsActive=0
GostWrite/GostRead proxy plaintext ...
ProxyStartSSL host=fzs.roskazna.ru
GOST TLS activated ... after_proxy_tunnel=1
TLSBUF direction=out ... ClientHello
TLSBUF direction=in ... real TLS handshake records
MSSPI handshake complete host=fzs.roskazna.ru TLS=0x0303 cipher=0xff85
```

The earlier ASUGATE failure signature is absent after activation: no plaintext `HTTP/1.1 400 Bad Request`, no `SEC_E_INVALID_TOKEN`, and no fatal `unexpected_message` sequence.

The explicit-list log contains seven successful `ProxyStartSSL`/MSSPI handshake sequences; the native-default control contains six. Every completed handshake negotiated TLS 1.2 (`0x0303`) and cipher suite `0xFF85`. After handshake, the logs show sustained `msspi_write` and `msspi_read` application-data traffic, demonstrating that the browser is not stopping at ServerHello/Finished but is carrying HTTPS payloads through MSSPI.

### Browser-visible result

The user confirmed that the Treasury site pages **loaded completely in the browser, including scripts and images**. This is the first project result that combines all of the following on the real target site:

- Firefox system-proxy handling and HTTP CONNECT;
- `ProxyStartSSL()` transition;
- MSSPI / Windows SSPI / CryptoPro GOST TLS 1.2 handshake;
- negotiated GOST suite `0xFF85`;
- bidirectional protected application traffic;
- complete browser rendering of the site, including dependent JavaScript and image resources.

This is therefore stronger than a handshake-only result: **the GOST HTTPS path is operational end-to-end for the tested Treasury pages in this environment.**

### Cipher-list A/B conclusion

The explicit GOST list is not required for this server to complete a GOST handshake: the native-default MSSPI ClientHello also succeeds and the server selects the same `0xFF85` suite. Keeping the explicit list may still be useful to make the allowlisted GOST path deterministic and prevent negotiation of a non-GOST suite; that is a policy choice rather than the cause of the successful handshake.

### Remaining security question

The successful logs also contain:

```text
DriveHandshake verify host=fzs.roskazna.ru ok=0 status=0x00000000
```

The current wrapper accepts that case because it rejects only `verifyOk && verifyStatus != 0`. The pinned MSSPI implementation uses manual credential validation and `msspi_get_verify_status()` returns 0 on its internal-error path. Therefore **successful page loading is not yet proof that server-certificate validation is correctly enforced fail-closed**.

This is now the next GOST-runtime security question. It is separate from the transport/CONNECT/handshake result, which is confirmed working.
