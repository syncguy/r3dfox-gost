# Windows XP x86 — refactor/PDB/YY full-build evidence — 2026-09-07

Track: Windows XP SP3 x86 compatibility only. This experiment does not establish GOST TLS runtime or handshake behavior.

## Exact completed build

- implementation branch: `agent/winrt-source-poc`;
- source-under-test: `a15dcd738edda4ab810fc9f92289170f115519e4` (`ci(xp): preserve matching xul PDB diagnostics`);
- workflow: `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run: `34095425319`, attempt `1`;
- job: `101657910987` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- event: `workflow_dispatch`;
- result: **SUCCESS**.

All build, package, runtime-archive, compatibility gates, diagnostic steps, artifact uploads and the final summary completed successfully. In particular:

- `Build release r3dfox XP x32` — success;
- `DIAG - Record xul IPHLPAPI XP compatibility imports` — success;
- `DIAG - Inventory YY-Thunks DLL entry-point coverage` — success;
- package/runtime/diagnostics uploads — success;
- final XP x32 summary — success.

Exact artifacts:

- package artifact `10013484854`, digest `sha256:d8764c7dbf0a2d2b47858554628aa009641589241e582eec9cb7d40199a89873`;
- runtime artifact `10013486539`, digest `sha256:daaed105abe6c9ce3a9afa9db4a17254c8520f2a6823dbc53e0e7bc6a4a8360b`;
- diagnostics artifact `10013519035`, digest `sha256:6fef7bf7e0122de7c5747e0923585123ea5753666fc6bd38ff1ac6be4cf20df9`.

## Workflow structural-refactor validation

The preceding known-good Firefox source point `0a18ba85b3f493b17c5a62742e869788ca3f2f6b` to `a15dcd738edda4ab810fc9f92289170f115519e4` changes only the XP full-build workflow/refactor surface:

- `.github/scripts/xp/prepare-pinned-xp-bcrypt.ps1`;
- `.github/scripts/xp/verify-msvcr14x-xp-contract.ps1`;
- `.github/scripts/xp/diag-xul-iphlpapi.ps1`;
- `.github/scripts/xp/build-narrow-yy.ps1`;
- `.github/workflows/gost-poc-build-xp-x32.yml`.

No Firefox production source changed in that range. The structural checkpoint `e9c8c766e20b0160094257d674ded1ea57aa82ee` is one commit behind `a15dcd...`; the only additional change is the debug-symbol/PDB diagnostic extension. Therefore run `34095425319` is accepted as the first GREEN full-build revalidation of the four-script structural-refactor checkpoint together with the PDB extension.

The validated extraction pairs are:

1. pinned XP bcrypt preparation;
2. msvcr14x XP runtime-contract verification;
3. final xul IPHLPAPI diagnostic;
4. narrow YY provider construction.

This GREEN result permits the next structure-only refactor batch, but linker-policy changes must still not be mixed into mechanical extraction work.

## Matching `xul.pdb` diagnostics

Commit `a15dcd738edda4ab810fc9f92289170f115519e4` changed the XP mozconfig from:

```text
--disable-debug-symbols
```

to:

```text
--enable-debug-symbols
```

and added:

```text
obj-gost-xp-x32/**/xul.pdb
```

to the diagnostics upload.

The exact diagnostics artifact `10013519035` was inspected and contains one matching PDB:

```text
r3dfox-gost/r3dfox-gost/obj-gost-xp-x32/toolkit/library/build/xul.pdb
```

Identity:

- uncompressed size: `1,864,486,912` bytes;
- SHA-256: `fb35a5e682fb5b0fab3039a2dc504339002d9e8932a0dae71933da44a35ada02`.

The matching `xul.dll` reported by the same diagnostics inventory has SHA-256:

`c5dd98c21fe59640e56498c695808819fa5d5bbe26be324cb926cc7c2235aa8e`.

**Symbolization rule:** this PDB belongs only to the `xul.dll` from run `34095425319` / source `a15dcd...`. It must not be used to symbolize the earlier `0a18ba85...` browser or the later Shell32 build from `cd5e715...`.

## YY DLL entry-point/TLS inventory

The non-blocking YY inventory successfully exercised its `xul.dll` positive control:

```text
xul_positive_control=true
strong_candidates=13
contracts_present=3
missing_contract_candidates=10
```

Contract-present strong candidates:

- `xul.dll`;
- `ucrtbase.dll`;
- `msvcp140.dll`.

The diagnostic classified these ten DLLs as strong candidates without the YY DLL entry-wrapper/TLS contract:

- `gkcodecs.dll`;
- `gmp-clearkey/0.1/clearkey.dll`;
- `gmp-fake/1.0/fake.dll`;
- `gmp-fakeopenh264/1.0/fakeopenh264.dll`;
- `libGLESv2.dll`;
- `mozavcodec.dll`;
- `mozavutil.dll`;
- `mozglue.dll`;
- `mozinference.dll`;
- `nss3.dll`.

Interpretation: **FOLLOW-UP EVIDENCE ONLY.** This inventory is heuristic and non-blocking. A `YY_CANDIDATE_CONTRACT_MISSING` classification does not prove that the DLL causes an XP runtime failure. Any production change must first be tied to an exact runtime failure/call path or a stronger dedicated proof.

`xul.dll` itself has the intended contract (`entry_wrapper=true`, `yy_first_tls_callback=true`) and therefore remains the positive control for this diagnostic.

## Residual IPHLPAPI delay-import evidence

The same build's final xul IPHLPAPI diagnostic reported:

- `NotifyIpInterfaceChange` — absent;
- `CancelMibChangeNotify2` — absent;
- `GetIpInterfaceTable` — present as delay import;
- `FreeMibTable` — present as delay import;
- `if_indextoname` — present as delay import;
- `GetAdaptersAddresses` / `GetBestInterfaceEx` — present as delay imports.

The diagnostic result was:

```text
UNEXPECTED|post_vista_survivors=GetIpInterfaceTable,FreeMibTable,if_indextoname
```

This does **not** reopen the earlier IP Helper runtime blocker by itself. These are residual delay-import edges from a non-blocking diagnostic; their owners/reachability must be established before a compatibility change. The earlier exact physical `0a18ba85...` browser had already progressed beyond the preceding IP Helper runtime boundary.

## Relationship to the current Shell32 build

This completed build predates the current `SHGetKnownFolderPath` source-remediation cluster and therefore does **not** validate those source changes.

The later/current Shell32 validation build is:

- run `34107793132`;
- job `101696721232`;
- source `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4`.

That descendant inherits the already-GREEN refactored workflow and debug-symbol/PDB diagnostic contract, while separately testing the Shell32 production-source changes.

Status: **GREEN full-build/static refactor and diagnostics baseline; matching xul PDB proven present; YY inventory recorded; no physical-XP runtime conclusion from this build yet.**
