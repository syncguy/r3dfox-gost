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

### Current full-build snapshot

**Actions run:** `32623108290`  
**Workflow:** `GOST TLS PoC build - thunk-rs experiment`  
**Run SHA:** `a73f18e823c083c970eea649ce305da648640e2f`  
**Snapshot status when recorded:** in progress

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32623108290>

At the recorded snapshot, prerequisite setup, MSSPI preparation, the Win7/thunk gates, export prerequisites, and the targeted security-manager SSL compilation had succeeded. The long full-release build step was still running.

### Important interpretation rule

Do not attribute this run's outcome to `1b2c329...` or `79061580...`: run `32623108290` is pinned to `a73f18e...`.

Do not mark this experiment successful or failed in the project state until the run reaches a terminal status and the final package/import audit is inspected.

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

1. Let run `32623108290` reach a terminal result and inspect its final PE import audit.
2. Evaluate the later YY-Thunks 1.2.2 + VC-LTL 5.2.2 dedicated smoke independently of that older full-build SHA.
3. Keep CRT-model compatibility (`/MD`) separate from import-thunking decisions.
