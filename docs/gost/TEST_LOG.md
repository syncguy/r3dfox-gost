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
  --MOZ_LOG_FILE=C:\Temp\r3dfox-gost ^
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

This is a Windows Vista/7 linker result only. It does not change the independent GOST TLS runtime blocker `SEC_E_INVALID_TOKEN`.

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
...\yy_processprng_probe.rlib
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
Dump of file ...\processprng-closing-smoke\processprng-closing-smoke.exe
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
