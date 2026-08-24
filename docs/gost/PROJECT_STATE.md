# r3dfox GOST TLS — Project State

Last updated: 2026-08-24

This file is the current technical synthesis for the GOST TLS fork. For chronology and evidence from individual experiments, see [`TEST_LOG.md`](./TEST_LOG.md). For workflow roles, see [`WORKFLOWS.md`](./WORKFLOWS.md).

## Repository and branches

- Repository: `syncguy/r3dfox-gost`.
- Default / active development branch: `agent/gost-tls-poc`.
- Frozen baseline: `win-153` at `0d023eb0e3517dea36f2f134a9a25f872611c688` when protection was configured.
- `win-153` is protected with restricted updates, restricted deletion, and blocked force-pushes. Fork syncing is disabled for that ruleset.
- PR #1 historically has base `win-153`; that does **not** make `win-153` the active development branch.

## Version policy

The current r3dfox baseline is from the Firefox/r3dfox 153 line. Firefox upstream has moved to 154, but this project must not automatically migrate, rebase, or retarget to 154. That is a separate future decision requiring explicit user direction.

## Project objective

Add GOST TLS support to r3dfox while preserving the browser's normal TLS path.

Design intent:

- normal HTTPS continues through Firefox NSS;
- only allowlisted hosts are redirected to a GOST-capable TLS transport backed by `deemru/msspi` and Windows SSPI/CryptoPro;
- the first phase remains constrained to Windows, TLS 1.2, HTTP/1.1, and server authentication while transport and handshake behavior are stabilized.

The primary runtime test host is `fzs.roskazna.ru`.

## GOST TLS runtime track

### Architecture

The PoC adds a parallel TLS path around the normal NSS socket path for explicitly selected hosts.

Important pieces include:

- host allowlist selected by `R3DFOX_GOST_HOSTS`;
- `GostTLSService` / socket-provider routing;
- `GostSocketControl` implementing the TLS socket-control surface expected by Necko;
- `nsGostSSLIOLayer.cpp`, which pushes a custom NSPR I/O layer;
- MSSPI callbacks that read/write through the actual lower NSPR transport;
- Windows SSPI/CryptoPro performing TLS/GOST handshake and record protection.

Ordinary non-allowlisted HTTPS must remain on NSS.

### MSSPI baseline

Pinned MSSPI source commit:

`f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`

The Firefox wrapper configures the client with the equivalent of:

- `msspi_set_client`;
- TLS 1.2 via `msspi_set_version(..., 0x0303)`;
- `msspi_set_hostname`;
- `msspi_set_peerauth`.

The current Firefox integration does not yet treat an explicit cipher-list setting as proven to be required. Chromium-Gost's MSSPI path does configure an explicit cipher list, so cipher negotiation remains a high-value comparison point.

### Confirmed runtime behavior

The transport-side NSPR/MSSPI integration is far enough to exchange a real TLS handshake flight with the server.

With the `caa420c25bcc2693137666b625e62a1b58fdcb0f` transport fix and the successful main-build Actions run `32571061759`:

1. `fzs.roskazna.ru` matches the allowlist.
2. A TCP socket is created.
3. MSSPI is opened and configured as a TLS 1.2 client.
4. The GOST NSPR layer is pushed.
5. The wrapper resolves and stores the real lower transport after the push.
6. MSSPI emits a 198-byte initial TLS flight; `LowerWrite` sends all 198 bytes.
7. The first nonblocking read returns Winsock `10035` / would-block and is correctly treated as pending.
8. A later `LowerRead` receives 1039 bytes from the server.
9. The failure occurs only after those server bytes reach SSPI.

This proves the earlier callback/lower-layer transport bug is no longer the current blocker. Do not return to redesigning Poll/LowerRead/LowerWrite unless new evidence shows a transport regression.

### Current runtime blocker

After receiving the 1039-byte server handshake flight, the call through MSSPI to `InitializeSecurityContextA` fails with:

`0x80090308` — `SEC_E_INVALID_TOKEN`

MSSPI then enters `MSSPI_ERROR` (`0x40000000`). A later `0x0000054f` / `ERROR_INTERNAL_ERROR` is secondary because MSSPI is already in its terminal error state.

Observed flow:

```text
Firefox/MSSPI
  -> 198-byte client TLS flight
fzs.roskazna.ru
  -> 1039-byte server TLS flight
SSPI InitializeSecurityContextA
  -> SEC_E_INVALID_TOKEN (0x80090308)
MSSPI/SSPI
  -> 7-byte output, likely a TLS Alert
```

The next runtime analysis should determine what SSPI rejected rather than modifying the NSPR transport again.

Highest-value questions remain:

1. What exactly is in the ClientHello emitted by the current MSSPI configuration?
2. What TLS records and handshake messages are in the server response?
3. Which cipher suite did the ServerHello select?
4. What are the exact 7 bytes emitted after `SEC_E_INVALID_TOKEN`?
5. How does this differ from Chromium-Gost's explicit MSSPI cipher-list setup?

Keep runtime conclusions tied to the exact main-build run/SHA and runtime log used for the test.

## Windows Vista/7 build-compatibility track

This track is separate from the GOST TLS runtime handshake.

### Retained constraints

- Firefox is normally built in the `/MD` dynamic CRT model.
- Do not solve Win7 compatibility by forcing a static CRT into the existing Firefox `/MD` world.
- The earlier static VC-LTL experiment exposed `/failifmismatch` conflicts such as `MD_DynamicRelease` versus `MT_StaticRelease` / `libcpmt.lib`.
- A successful linker invocation is not enough; final PE imports and target-OS execution matter.
- The complete YY-Thunks `kernel32.lib` must not be placed before Rust/gkrust as a broad interposition mechanism.

The retained negative full-build proof for broad YY `kernel32.lib` interposition is:

- run `32623108290`;
- job `97162633898`;
- commit `a73f18e823c083c970eea649ce305da648640e2f`;
- failure: duplicate `LockResource` between `gkrust.lib` raw-dylib surface and YY `kernel32.lib`.

### Proven narrow ProcessPrng strategy

Representative closing smoke:

- run `32644291202`;
- job `97207125757`;
- commit `fd925b1780fa3470a2cfba743a7374f7d7e644d6`;
- result: success.

The passing strategy uses YY-Thunks 1.2.2 `synchronization.lib` plus a physically narrow archive built from:

- `ProcessPrng.obj`;
- `ProcessPrng.obi`;
- `YY_Thunks_for_6.1.7600.0.obj`.

It preserves `/MD`, leaves the full YY `kernel32.lib` out of the final linker inputs, keeps `LockResource` as a normal KERNEL32 import, and removes `ProcessPrng` plus the selected Win8+ synchronization imports from the representative PE.

### First xul-scale result and precise-time blocker

Full Firefox run:

- run `32647338452`;
- job `97213486474`;
- commit `0eb29ecccaa3d2a0762af17e458c42cf245410d7`.

The build and package succeeded. The xul import audit showed the ProcessPrng/synchronization strategy had scaled far enough that the next hard direct blocker was:

`KERNEL32.dll!GetSystemTimePreciseAsFileTime`

That API requires Windows 8 and was therefore a real Windows 7 loader-hard blocker in that binary.

### Precise-time closing smoke

Focused workflow result:

- run `32680494331`;
- job `97296220325`;
- commit `cdef097b1912f68232de13d5e41b1a84add466d6`;
- workflow `YY-Thunks precise-time closing smoke`;
- result: success on the first attempt.

The smoke proved the narrow provider can close `GetSystemTimePreciseAsFileTime` using exactly:

- `GetSystemTimePreciseAsFileTime.obj`;
- `GetSystemTimePreciseAsFileTime.obi`;
- `YY_Thunks_for_6.1.7600.0.obj`.

It verified both ordinary and `__imp_` COFF weak aliases, did not expose the broad `LockResource`/`LoadLibraryExW` surface, and removed precise-time from the final representative PE imports without supplying the full YY `kernel32.lib`.

A prior direct edit of the full workflow in commit `b3c3d3b00c6e4a76fbfaa615b9104828c26e78ba` corrupted embedded-Python newline literals and was not experimental proof. The malformed workflow surfaced as run `32692410607` at commit `08203bb0d7023b7186dc11e4d765f0349aadf076`, which GitHub rejected before creating a build job.

### Current xul-scale result

The narrow ProcessPrng + precise-time strategy has now crossed the real Firefox/xul build boundary.

Actions result:

- run `32695496647`;
- job `97336702701`;
- exact commit `ae3d52f42b8b6b509c1263418bead8bb9324dd00`;
- release artifact `9512347999`;
- diagnostics artifact `9512349511`.

The following stages all passed:

- narrow YY ProcessPrng + precise-time provider construction;
- libxul linker patch;
- configure/export/SSL target gates;
- full release Firefox build;
- package;
- release artifact upload;
- xul import-audit step;
- diagnostics upload.

Only the final policy gate failed.

The diagnostics prove that `GetSystemTimePreciseAsFileTime` is absent from the final xul direct imports. The previous hard blocker is therefore closed at full Firefox build/package scale. `ProcessPrng`, `WaitOnAddress`, `WakeByAddressAll`, `WakeByAddressSingle`, and `GetOverlappedResultEx` are also absent from the checked direct-import set.

The generated forbidden-direct file contains exactly:

`GetQueuedCompletionStatusEx`

That API is genuinely a direct KERNEL32 import in this xul, but it is **not** a Windows-8-only API. Microsoft documents minimum supported client Windows Vista, so it is valid on Windows 7. The red final status of run `32695496647` is therefore a policy/harness false positive, not a new Win7 loader blocker.

Commit `e2a9c3bcbbdfade62a15a144da9117e249cc6305` removes only `GetQueuedCompletionStatusEx` from the Win8+ hard blacklist. It does not change the linker strategy.

### Direct versus delay-load audit status

The ordinary/direct import parser used in run `32695496647` is sufficient for the current hard-loader gate and is the basis for the precise-time closure conclusion.

The delay-load API parser is **not yet complete**. `dumpbin /imports` formats delay API rows differently from ordinary import rows. The workflow switches to a delay section and records delay DLL names, but the API regex in `ae3d52f4...` matches only the ordinary-import row shape. Therefore `xul-thunk-win7-delay-import-api-names.txt` is empty and must not be interpreted as proof that there are no delay-loaded APIs.

Re-parsing the retained raw import dump with the correct delay-row shape yields 504 unique delay API names. Relevant post-Win7 candidates include:

- `GetAutoRotationState`;
- `GetPointerFrameTouchInfo`;
- `GetPointerType`;
- `CoIncrementMTAUsage`;
- `RoActivateInstance`;
- `RoGetActivationFactory`;
- Windows Runtime string APIs.

These are delay-loaded in the inspected binary and therefore must be analyzed as runtime-path compatibility questions, not automatically promoted to process-loader blockers.

Separate direct imports such as `api-ms-win-crt-*` belong to CRT/UCRT deployment analysis and must not be conflated with YY-Thunks symbol interposition.

### Current next Win7 experiments

1. Obtain the full-build result for the corrected direct-import policy on commit `e2a9c3bcbbdfade62a15a144da9117e249cc6305` (or its exact descendant if the branch advances before the run is created). Always bind the conclusion to the actual run head SHA.
2. If the corrected direct gate is clean, treat the narrow ProcessPrng + precise-time direct-import problem as closed.
3. Fix or replay the delay-load API parser against the retained raw dump before claiming delay-load coverage.
4. Classify the actual delay-loaded post-Win7 APIs by whether Firefox guards those runtime paths on Windows 7.
5. Perform real Windows 7 execution/runtime validation. A clean PE import audit is necessary but not sufficient proof of compatibility.

The forward `yy-thunks-rust-smoke.yml` canary may independently test newer VC-LTL releases such as 5.3.1. Do not conflate that canary's dependency-version investigation with the full xul linker strategy above.

## Separation of conclusions

Keep these statements distinct:

- **Build success** means the selected source/toolchain combination compiled and packaged.
- **Win7 direct-import success** means the current exact loader-hard blacklist is absent from ordinary imports; it still does not prove target-OS execution.
- **Win7 runtime compatibility** requires actual execution and guarded handling of any relevant delay-loaded APIs/runtime dependencies.
- **GOST transport success** means MSSPI can exchange bytes through the NSPR layer.
- **GOST TLS success** requires the complete TLS handshake and usable HTTPS traffic.

At present the NSPR transport exchange is working, but the GOST TLS handshake is not yet complete because SSPI rejects the server flight with `SEC_E_INVALID_TOKEN`.

## Maintenance rule

After each meaningful test:

1. append the run/SHA, hypothesis, observation, and conclusion to `TEST_LOG.md`;
2. update this file only if the current blocker, architecture, pinned dependency, confirmed behavior, or next experiment changed;
3. mark speculative interpretations explicitly as hypotheses;
4. never overwrite historical failures just because a later experiment superseded them.
