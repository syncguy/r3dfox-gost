# XP full-build workflow structural refactor

Last updated: 2026-09-07

This document records the maintenance process used to reduce the size and fragility of the Windows XP SP3 x86 full-build GitHub Actions YAML without changing the proven build/link/runtime compatibility contract.

It is a workflow-maintenance document, not experiment evidence. Build/runtime conclusions still belong in `TEST_LOG.md`, `PROJECT_STATE.md`, and the XP compatibility documents according to the normal documentation rules.

## Scope

Target workflow:

`.github/workflows/gost-poc-build-xp-x32.yml`

Implementation branch:

`agent/winrt-source-poc`

Canonical documentation branch:

`agent/gost-tls-poc`

The refactor exists because the XP full-build workflow accumulated large inline PowerShell programs while compatibility work progressed through Rust, msvcr14x, YY-Thunks, PE retargeting, import audits, packaging gates, and physical-XP diagnostics. The goal is to make the workflow maintainable while preserving its meaning and evidence boundary.

This work belongs only to the Windows compatibility track. It does not change or prove GOST TLS runtime behavior.

## Refactor objective

The first phase is **structure-only**.

Expected behavioral change:

`none`

The YAML remains the orchestration layer. Large self-contained PowerShell implementations move to `.github/scripts/xp/`, but the Actions step graph and the build contract remain unchanged.

The purpose is not to make the workflow shorter at any cost. The purpose is to separate orchestration from implementation while keeping every existing gate, diagnostic, artifact, dependency pin, and evidence relationship intact.

## Why the workflow remains one job

Do not mechanically split this workflow into reusable workflows or multiple jobs during the structure-only phase.

The current XP build has intentional state shared between steps through:

- `$GITHUB_ENV`;
- `$RUNNER_TEMP`;
- the checkout working tree;
- `OBJDIR/dist/bin`;
- temporary `.lib` providers and extracted YY objects;
- files under `diagnostics/`;
- `steps.<id>.outcome` conditions;
- package/runtime artifact paths.

Moving a step into another job or `workflow_call` would change the state-transfer model and therefore become an architectural CI change rather than a mechanical refactor.

Keep diagnostic and gate steps visible as separate GitHub Actions steps. Extract their implementation, not their Actions identity.

## What should be extracted

Use this threshold:

> Extract a PowerShell block when it is roughly more than 50 lines, or when it contains a self-contained algorithm, parser, audit, or build mechanism that is reasonable to inspect/test independently.

Good extraction candidates include:

- construction of the narrow YY provider;
- activation/composition of YY alias providers;
- PE/import auditing;
- DLL entry-point/TLS contract inspection;
- pinned binary provenance/contract validation;
- non-trivial diagnostic parsers.

Short orchestration and staging blocks normally stay inline. A 15-30 line step that only copies files, invokes `mach`, writes a small environment value, or packages an archive does not need a separate script merely to reduce YAML line count.

Do not extract every PowerShell block mechanically.

## Structure-only invariants

For every extracted step preserve all of the following unless a later change explicitly targets one of them:

- step `name`;
- step order;
- `id`;
- `if` expression;
- `continue-on-error`;
- `shell`;
- input environment variables;
- `$GITHUB_ENV` and `$GITHUB_OUTPUT` writes;
- output/diagnostic filenames;
- temporary directory names when later steps consume them;
- artifact paths;
- final Step Summary references;
- external-command exit-code handling;
- dependency/version pins;
- linker ordering and scope;
- positive/negative diagnostic semantics.

Do not reformat the whole YAML while extracting one block. The workflow diff should show the removed inline body and a single script invocation, not unrelated whitespace or ordering churn.

Scripts must consume the existing workflow environment pins rather than duplicating version/hash constants. This keeps one source of truth for dependency identity.

Scripts are expected to run from the repository root on the same `windows-2022` runner context used by the workflow.

Preserve `$ErrorActionPreference = 'Stop'` when the original inline block had it. Do not add it merely for style if the old step deliberately relied on non-terminating behavior. The non-blocking IPHLPAPI diagnostic is an example where exact semantics are more important than stylistic uniformity.

## Repository mutation discipline

This refactor uses only the authorized implementation branch and direct file operations.

Do not create temporary branches as part of the refactor. Do not use `create_branch`, `update_ref`, merge, rebase, force-push, or low-level blob/tree/ref construction unless the user explicitly requests that exact operation.

For an existing workflow file:

1. verify the current `agent/winrt-source-poc` HEAD;
2. fetch the exact workflow file and current blob SHA;
3. fetch the complete exact blob when needed;
4. replace only the intended inline block;
5. update that same path through the direct contents API using the exact current blob SHA;
6. fetch the resulting commit;
7. compare parent -> new commit and inspect the changed-file list/diff.

For a new script, use the direct file-create operation on `agent/winrt-source-poc`.

No workflow-as-editor workaround is allowed.

## Preferred extraction cycle

Each extraction is completed before starting another one.

The preferred two-commit cycle is:

### Commit A — add the script

- mechanically copy the inline PowerShell body into `.github/scripts/xp/<name>.ps1`;
- remove only YAML indentation;
- avoid cleanup/refactoring inside the script during the first move;
- verify that the commit adds exactly the intended script and nothing else.

At this point the script is intentionally unused for only one commit.

### Commit B — switch the Actions step

- re-fetch the current workflow/blob SHA after Commit A;
- replace only the inline `run: |` body with `run: .\.github\scripts\xp\<name>.ps1`;
- keep the step's `name`, `id`, `if`, `continue-on-error`, and `shell` unchanged;
- verify the commit diff contains only that workflow hunk.

Do not create another unused script before Commit B completes the previous extraction.

## Verification after each pair

After each script/switch pair verify:

1. the script exists on the current implementation HEAD;
2. the workflow invocation path matches the real file path;
3. no step identity or condition changed;
4. no environment pin moved into the script unnecessarily;
5. diagnostic filenames and artifact-consumed paths are unchanged;
6. `$LASTEXITCODE` handling remains equivalent;
7. the compare range contains only the expected script/workflow files;
8. no unrelated YAML formatting or source changes appeared.

For link-provider steps, additionally verify that library ordering, alias selection, symbol checks, and prohibitions on broad provider injection are byte-for-byte/mechanically equivalent in meaning.

## Revalidation cadence

Do not launch the multi-hour full Firefox build after every mechanical extraction.

Instead accumulate a small, reviewable batch of clean extraction pairs, then stop and perform one full workflow revalidation before touching the most sensitive linker/composition logic.

The current chosen boundary is four extracted areas. This gives a meaningful maintainability improvement while keeping the unvalidated structural delta small enough to diagnose if the full run fails.

A successful YAML parse or clean diff is necessary but not sufficient. The refactor is not considered validated until the exact refactor source SHA completes the full XP x32 workflow with the expected build, package, diagnostic, audit, and artifact results.

A GREEN refactor build is still not physical-XP runtime proof and is not GOST TLS handshake proof.

## Current structural checkpoint

Implementation branch HEAD at the current stop point:

`e9c8c766e20b0160094257d674ded1ea57aa82ee`

The following extraction pairs are complete:

### Pinned XP bcrypt preparation

Script creation:

- `4146956a2fc57d87afeb614dd3efe092619e12e8` — `ci(xp): extract pinned bcrypt preparation script`

Workflow switch:

- `1dec42a35708a7e64197c7047cc19e10eb3ee85f` — `ci(xp): use extracted bcrypt preparation script`

Script:

`.github/scripts/xp/prepare-pinned-xp-bcrypt.ps1`

### msvcr14x XP runtime contract gate

Script creation:

- `fad25733a7e8ca9bffda7707f88ccd39da8de15b` — `ci(xp): extract msvcr14x XP contract gate`

Workflow switch:

- `235189158ad6e119f79e971b85deea64c1bdef89` — `ci(xp): use extracted msvcr14x XP contract gate`

Script:

`.github/scripts/xp/verify-msvcr14x-xp-contract.ps1`

### Final xul IPHLPAPI diagnostic

Script creation:

- `28f974a9eeee289ddbf50a0d54c1516a22cb1015` — `ci(xp): extract xul IPHLPAPI diagnostic`

Workflow switch:

- `9ca9425c5da93edadf94f859d5c72405dc561950` — `ci(xp): use extracted xul IPHLPAPI diagnostic`

Script:

`.github/scripts/xp/diag-xul-iphlpapi.ps1`

The Actions metadata for this diagnostic remains significant: `id: xul-iphlpapi-import-diag`, its `if` expression, and `continue-on-error: true` must remain unchanged.

### Narrow YY provider construction

Script creation:

- `c05bb71aa1b2cace6f670b640c03baa008628012` — `ci(xp): extract narrow YY provider build`

Workflow switch:

- `e9c8c766e20b0160094257d674ded1ea57aa82ee` — `ci(xp): use extracted narrow YY provider build`

Script:

`.github/scripts/xp/build-narrow-yy.ps1`

This step still produces the same `NARROW_YY_LIB` through `$GITHUB_ENV` and retains the existing selected-member, symbol, and broad-symbol rejection logic.

## Current validation status

No full revalidation run has yet been accepted for source `e9c8c766e20b0160094257d674ded1ea57aa82ee`.

Therefore the current state is:

**structural extraction complete to the planned checkpoint; full-build validation pending**.

Do not cite the refactor as GREEN until a completed run is bound to exact:

- source SHA `e9c8c766e20b0160094257d674ded1ea57aa82ee`;
- Actions run ID;
- job ID;
- expected package/runtime/diagnostics artifacts and final gate outcomes.

## Next refactor phase after GREEN

Only after the checkpoint receives a clean full revalidation should the next extraction batch begin.

Highest-risk next candidate:

`.github/scripts/xp/activate-narrow-yy.ps1`

This corresponds to the existing `Activate narrow YY XP x86 provider for all target links` Actions step. Keep it one Actions step even if the script later uses internal helper functions.

This block is especially sensitive because it composes:

- the selected NTDLL `NtCancelIoFileEx` alias provider;
- the selected ADVAPI32 ETW/RegGetValueW alias provider;
- the selected WS2_32 alias provider;
- the narrow common YY implementation provider;
- `synchronization.lib`;
- global target `LDFLAGS` ordering;
- the prohibition on broad `kernel32.lib`, `ntdll.lib`, `advapi32.lib`, and `ws2_32.lib` injection;
- historical run/job/SHA evidence written into diagnostics.

Do not combine its extraction with a linker-policy change.

Later strong candidates include:

- `audit-runtime-pe-imports.ps1` for the broad final PE/import audit;
- `audit-yy-dll-entrypoints.ps1` for the non-blocking YY DLL entry-point/TLS inventory.

Short staging/archive steps should remain inline unless they later acquire independent algorithmic complexity.

## Full-build acceptance for the refactor

The structure-only refactor passes its first validation checkpoint only if the exact source-under-test completes the existing full workflow without changing the intended gate semantics.

At minimum verify:

- build succeeds;
- package succeeds;
- runtime archive succeeds;
- pinned bcrypt provenance/contract remains valid;
- msvcr14x runtime contract remains valid;
- narrow YY construction succeeds;
- existing YY alias/link contract remains intact;
- IPHLPAPI diagnostic still produces its expected evidence files;
- source/import/DPI/ADVAPI32/core import gates retain their behavior;
- PE subsystem retargeting remains intact;
- packaged CRT, D3DCompiler, and bcrypt gates retain their behavior;
- broad final PE/import audit retains its behavior;
- YY DLL entry-point inventory remains non-blocking and evidence-preserving;
- all expected package/runtime/diagnostics artifacts are uploaded;
- final Step Summary still references the same step IDs/outcomes.

If the full run fails, first classify whether the failure is a script extraction regression or an unrelated source/runner/dependency failure before changing compatibility logic.

## Documentation after the revalidation run

Once the exact refactor run finishes:

- append the exact run/job/SHA and conclusion to `TEST_LOG.md` because the full build is a meaningful experiment;
- update this document's validation checkpoint if the process itself advances;
- update `WORKFLOWS.md` only if the workflow role/topology meaning changes;
- update `PROJECT_STATE.md` only if the current blocker, architecture, confirmed behavior, dependency, or immediate next experiment changes;
- do not treat a structure-only GREEN build as physical-XP runtime evidence.
