# XP full-build workflow structural refactor

Last updated: 2026-09-07

This document records the maintenance process used to reduce the size and fragility of the Windows XP SP3 x86 full-build GitHub Actions YAML without changing the proven build/link/runtime compatibility contract.

It is a workflow-maintenance document, not physical-runtime evidence. Build/runtime conclusions remain separate and must be tied to exact source/run/job/artifact identities.

## Scope

Target workflow:

`.github/workflows/gost-poc-build-xp-x32.yml`

Implementation branch:

`agent/winrt-source-poc`

Canonical documentation branch:

`agent/gost-tls-poc`

This work belongs only to the Windows compatibility track. It does not change or prove GOST TLS runtime behavior.

## Refactor objective

The first phase is **structure-only**.

Expected compatibility behavior change:

`none`

The YAML remains the orchestration layer. Large self-contained PowerShell implementations move to `.github/scripts/xp/`, while the Actions step graph, dependency pins, linker contract, gate semantics, diagnostic filenames and artifact relationships remain unchanged.

The purpose is not to minimize YAML at any cost. It is to separate orchestration from implementation without changing the evidence boundary.

## Why the workflow remains one job

Do not mechanically split this workflow into reusable workflows or multiple jobs during the structure-only phase.

The XP full build intentionally shares state through:

- `$GITHUB_ENV` and `$GITHUB_OUTPUT`;
- `$RUNNER_TEMP`;
- the checkout working tree;
- `OBJDIR/dist/bin`;
- temporary `.lib` providers and extracted YY objects;
- `diagnostics/` files;
- `steps.<id>.outcome` conditions;
- package/runtime artifact paths.

Moving a step into another job would change the state-transfer model and become an architectural CI change rather than a mechanical refactor.

Keep diagnostic and gate steps visible as separate GitHub Actions steps. Extract their implementation, not their Actions identity.

## Structure-only invariants

For every extracted step preserve unless a later experiment explicitly changes one of them:

- step `name`, order, `id`, `if`, `continue-on-error` and `shell`;
- input environment variables;
- `$GITHUB_ENV` / `$GITHUB_OUTPUT` writes;
- output and diagnostic filenames;
- temporary directory names used by later steps;
- artifact paths;
- final Step Summary references;
- external-command exit handling;
- dependency/version pins;
- linker ordering and scope;
- positive/negative diagnostic semantics.

Do not combine mechanical extraction with a linker-policy or compatibility-policy change.

Scripts consume the workflow's existing environment pins rather than duplicating version/hash constants.

## Preferred extraction cycle

Each extraction is completed as a pair before another one begins.

### Commit A — add the script

- mechanically copy the inline PowerShell body to `.github/scripts/xp/<name>.ps1`;
- remove only YAML indentation;
- avoid behavior cleanup during the initial move;
- verify the commit adds only the intended script.

### Commit B — switch the workflow step

- re-fetch the current workflow/blob SHA;
- replace only the inline `run: |` body with `run: .\.github\scripts\xp\<name>.ps1`;
- preserve step identity and conditions;
- verify the diff contains only that workflow hunk.

## First extraction checkpoint

The first checkpoint contains four completed extraction pairs.

### Pinned XP bcrypt preparation

- script creation `4146956a2fc57d87afeb614dd3efe092619e12e8` — `ci(xp): extract pinned bcrypt preparation script`;
- workflow switch `1dec42a35708a7e64197c7047cc19e10eb3ee85f` — `ci(xp): use extracted bcrypt preparation script`;
- script `.github/scripts/xp/prepare-pinned-xp-bcrypt.ps1`.

### msvcr14x XP runtime contract gate

- script creation `fad25733a7e8ca9bffda7707f88ccd39da8de15b` — `ci(xp): extract msvcr14x XP contract gate`;
- workflow switch `235189158ad6e119f79e971b85deea64c1bdef89` — `ci(xp): use extracted msvcr14x XP contract gate`;
- script `.github/scripts/xp/verify-msvcr14x-xp-contract.ps1`.

### Final xul IPHLPAPI diagnostic

- script creation `28f974a9eeee289ddbf50a0d54c1516a22cb1015` — `ci(xp): extract xul IPHLPAPI diagnostic`;
- workflow switch `9ca9425c5da93edadf94f859d5c72405dc561950` — `ci(xp): use extracted xul IPHLPAPI diagnostic`;
- script `.github/scripts/xp/diag-xul-iphlpapi.ps1`.

The Actions metadata remains part of the contract: `id: xul-iphlpapi-import-diag`, its `if` expression and `continue-on-error: true` are intentionally preserved.

### Narrow YY provider construction

- script creation `c05bb71aa1b2cace6f670b640c03baa008628012` — `ci(xp): extract narrow YY provider build`;
- workflow switch `e9c8c766e20b0160094257d674ded1ea57aa82ee` — `ci(xp): use extracted narrow YY provider build`;
- script `.github/scripts/xp/build-narrow-yy.ps1`.

The step still produces the same `NARROW_YY_LIB` through `$GITHUB_ENV` and preserves selected-member, symbol and broad-provider rejection logic.

## First checkpoint full-build validation — GREEN

The structure-only checkpoint is now **validated**.

Exact validation build:

- source branch `agent/winrt-source-poc`;
- source-under-test `a15dcd738edda4ab810fc9f92289170f115519e4`;
- run `34095425319`, attempt `1`;
- job `101657910987`;
- result **SUCCESS**.

All existing build, package, runtime-archive, compatibility gates, diagnostics, artifact uploads and the final summary completed successfully.

The structural checkpoint commit `e9c8c766e20b0160094257d674ded1ea57aa82ee` is exactly one commit behind `a15dcd...`. That one additional commit changes only `.github/workflows/gost-poc-build-xp-x32.yml` by enabling debug symbols and adding `xul.pdb` to diagnostics. Therefore this GREEN run validates both:

1. the four-script structure-only extraction checkpoint; and
2. the new matching-PDB diagnostic extension.

Exact artifacts from the GREEN validation:

- package `10013484854`, digest `sha256:d8764c7dbf0a2d2b47858554628aa009641589241e582eec9cb7d40199a89873`;
- runtime `10013486539`, digest `sha256:daaed105abe6c9ce3a9afa9db4a17254c8520f2a6823dbc53e0e7bc6a4a8360b`;
- diagnostics `10013519035`, digest `sha256:6fef7bf7e0122de7c5747e0923585123ea5753666fc6bd38ff1ac6be4cf20df9`.

This validation is build/static evidence only. It is not physical-XP runtime proof and not GOST TLS handshake proof.

## Matching `xul.pdb` diagnostic contract

Commit `a15dcd738edda4ab810fc9f92289170f115519e4` (`ci(xp): preserve matching xul PDB diagnostics`) changes the XP mozconfig from `--disable-debug-symbols` to `--enable-debug-symbols` and adds:

```text
obj-gost-xp-x32/**/xul.pdb
```

to `r3dfox-gost-xp-x32-diagnostics`.

The exact GREEN diagnostics artifact `10013519035` was inspected and contains:

```text
r3dfox-gost/r3dfox-gost/obj-gost-xp-x32/toolkit/library/build/xul.pdb
```

Identity:

- size `1,864,486,912` bytes;
- SHA-256 `fb35a5e682fb5b0fab3039a2dc504339002d9e8932a0dae71933da44a35ada02`.

The corresponding `xul.dll` from the same build is recorded by the diagnostics inventory with SHA-256:

`c5dd98c21fe59640e56498c695808819fa5d5bbe26be324cb926cc7c2235aa8e`.

Never use this PDB for an earlier or later `xul.dll`. It is matching-symbol evidence only for run `34095425319` / source `a15dcd...`.

The descendant Shell32 validation source `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4` inherits the same debug-symbol/PDB workflow contract, but its physical failures must be symbolized with the PDB produced by its own exact build.

## YY DLL entry-point diagnostic from the GREEN run

The non-blocking all-DLL inventory produced a valid xul positive control:

```text
xul_positive_control=true
strong_candidates=13
contracts_present=3
missing_contract_candidates=10
```

Contract-present strong candidates were `xul.dll`, `ucrtbase.dll`, and `msvcp140.dll`.

The heuristic reported ten strong candidates without the YY DLL entry-wrapper/TLS contract:

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

This is **follow-up evidence only**. The inventory is deliberately non-blocking and does not prove any listed DLL causes an XP runtime crash. Extend the YY DLL/TLS contract only when exact runtime or stronger focused evidence identifies a real consumer boundary.

Detailed experiment evidence is preserved in `TEST_LOG_2026-09-07_refactor-pdb-yy.md`.

## Next refactor phase after GREEN

The first extraction checkpoint is now GREEN, so another small structure-only batch may proceed when desired.

Highest-risk next candidate:

`.github/scripts/xp/activate-narrow-yy.ps1`

corresponding to `Activate narrow YY XP x86 provider for all target links`.

This block is sensitive because it composes:

- the NTDLL `NtCancelIoFileEx` alias provider;
- the ADVAPI32 ETW/RegGetValueW alias provider;
- the WS2_32 alias provider;
- the narrow common YY implementation provider;
- `synchronization.lib`;
- global target `LDFLAGS` ordering;
- the prohibition on broad `kernel32.lib`, `ntdll.lib`, `advapi32.lib`, and `ws2_32.lib` injection.

Its extraction must remain mechanical; do not combine it with linker-policy changes.

Later strong candidates remain:

- `audit-runtime-pe-imports.ps1` for the broad final PE/import audit;
- `audit-yy-dll-entrypoints.ps1` for the non-blocking YY DLL entry-point/TLS inventory.

Short staging/archive steps should remain inline unless they acquire independent algorithmic complexity.

## Acceptance rule for later extraction batches

Do not launch the multi-hour full Firefox build after every mechanical extraction. Accumulate a small reviewable batch, then perform one exact full-workflow revalidation.

A clean diff or YAML parse is necessary but insufficient. A refactor batch is accepted only when an exact source SHA completes the expected build/package/diagnostic/audit/artifact pipeline.

A GREEN workflow refactor remains separate from physical Windows XP runtime success and from GOST TLS runtime/handshake success.
