# Windows XP x86 workflow scripts

This document is the index and maintenance policy for reusable PowerShell implementation used by the Windows XP SP3 x86 GitHub Actions line. Canonical documentation lives on `agent/gost-tls-poc`; the active XP implementation branch is `agent/winrt-source-poc`.

The main heavy workflow is `.github/workflows/gost-poc-build-xp-x32.yml`. Its YAML should primarily describe orchestration: Actions metadata, step ordering, `if:` conditions, `continue-on-error`, action invocations, artifact uploads, and the small amount of `env:` wiring required to pass GitHub expression values into scripts. Substantial implementation belongs under `.github/scripts/xp/`.

## Authoring rule

When adding a new non-trivial XP build, staging, verification, audit, diagnostic, packaging, or summary stage, do not first implement a large inline `run: |` block in the workflow and plan to extract it later. Create the PowerShell implementation under `.github/scripts/xp/` from the start and keep the workflow step as a short call to that script.

A block should normally become a script when it contains meaningful control flow, loops, helper functions, PE parsing, dependency preparation, archive extraction, hashing/provenance checks, multi-file staging, diagnostic/report generation, or enough PowerShell that it would materially enlarge the YAML. Tiny one-command or a few-line orchestration steps may remain inline when extraction would reduce clarity.

Do not split a coherent stage into many tiny scripts merely to minimize YAML line count. Prefer one script per coherent responsibility. Existing scripts should be reused or extended when the new behavior belongs to the same responsibility; create a new script when the evidence boundary or lifecycle stage is distinct.

GitHub Actions expressions such as `${{ steps.<id>.outcome }}` are evaluated in workflow YAML, not inside repository `.ps1` files. When an extracted script needs such values, keep the expressions in a compact workflow `env:` bridge and consume the resulting environment variables from PowerShell.

Before changing an existing script, fetch its current content and blob SHA, then update that exact file directly. After any workflow/script mutation, verify the resulting commit SHA and changed filenames. Do not use temporary workflows as repository editors.

## Current XP script inventory

The active implementation branch currently uses the following scripts under `.github/scripts/xp/`. This is a navigation index, not a substitute for reading the current script before changing it.

### Runner and configure preparation

- `plan-pagefile.ps1` — chooses/plans runner pagefile placement for the heavy XP build.
- `verify-runner-pagefile.ps1` — verifies the runner pagefile state before expensive work.
- `configure-firefox-x86-target.ps1` — runs/checks the Firefox x86 configure target used by the XP line.
- `build-export-prerequisites.ps1` — builds the export prerequisites needed before focused target compilation.
- `compile-security-manager-ssl-targets.ps1` — focused compile of the security-manager SSL targets used as an early compile gate.
- `verify-mime-guess-checksum.ps1` — verifies the committed `mime_guess` vendored checksum without mutating source in CI.
- `verify-dpi-source-guard.ps1` — source-level guard for the pre-Vista DPI compatibility path.

### msvcr14x and XP runtime dependencies

- `build-msvcr14x-release-x86.ps1` — builds pinned msvcr14x Release x86 using the proven restore/build path.
- `verify-msvcr14x-xp-contract.ps1` — verifies the msvcr14x XP PE/import/runtime contract before staging.
- `prepare-pinned-xp-bcrypt.ps1` — obtains and verifies the pinned physically proven XP `bcrypt.dll` release asset.
- `stage-proven-xp-bcrypt.ps1` — stages exact proven `bcrypt.dll` into `dist/bin` and records its identity.
- `verify-packaged-msvcr14x-crt.ps1` — verifies `ucrtbase.dll` and `msvcp140.dll` identities inside the produced portable package and selects the verified portable archive.
- `verify-packaged-proven-bcrypt.ps1` — verifies exact `bcrypt.dll` identity after portable packaging.
- `prepare-legacy-d3dcompiler47.ps1` — prepares the pinned legacy Firefox XP-compatible `D3DCompiler_47` input.
- `verify-retargeted-legacy-d3dcompiler47.ps1` — verifies legacy D3DCompiler identity, PE subsystem, and forbidden imports after retargeting.

### YY-Thunks integration and diagnostics

- `prepare-yy-thunks-x86.ps1` — prepares the pinned YY-Thunks x86 library tree and exports resolved paths.
- `build-narrow-yy.ps1` — builds/materializes the selected narrow YY provider composition.
- `activate-narrow-yy-provider.ps1` — activates the proven narrow YY provider and weak-alias families for the full Firefox link while keeping broad provider libraries prohibited.
- `verify-xul-yy-entrypoint-contract.ps1` — verifies the committed `xul.dll` YY entry-point/TLS contract linker flags.
- `inventory-yy-dll-entrypoint-coverage.ps1` — non-blocking PE/fingerprint inventory of YY resolver candidates and DLL entry-point/TLS callback contract coverage.

### DirectWrite integration

- `prepare-private-dwrite-integration.ps1` — prepares the pinned private DirectWrite integration inputs.
- `dwrite-private-closure.ps1` — owns the private DirectWrite closure staging/verification/package-verification modes and exact closure contract.

### PE retargeting and import gates

- `retarget-dist-bin-pe-subsystem.ps1` — retargets eligible x86 `dist/bin` PE subsystem headers to the configured XP floor; this is header work only, not compatibility proof.
- `audit-xp-x32-pe-floor-direct-imports.ps1` — broad all-PE x86/subsystem/direct-import audit with the current forbidden DLL/API policy and the narrow private-DWrite exception.
- `reject-core-browser-xp-direct-imports.ps1` — targeted direct-import gate for the core browser PE set.
- `verify-xul-battery-user32-imports.ps1` — rejects Vista-only battery USER32 imports from final `xul.dll`.
- `verify-xul-source-remediation-quartet.ps1` — verifies the source-remediated restart/named-pipe API quartet is absent from final imports.
- `verify-xul-advapi32-compat-imports.ps1` — verifies the selected ADVAPI32 compatibility family is absent as direct final imports.
- `verify-mozglue-dpi-delay-import.ps1` — requires `SetProcessDPIAware` to remain exactly one USER32 delay import rather than an ordinary import.
- `diag-xul-iphlpapi.ps1` — non-blocking xul IPHLPAPI/legacy-MTU diagnostic evidence.

### Final evidence aggregation

- `summarize-xp-x32-full-build.ps1` — writes the final Actions evidence summary and aggregate RED verdict from operation/gate outcomes passed through workflow environment variables.

## Maintenance expectations

When a script is added, removed, renamed, or its responsibility changes materially, update this index in the same documentation pass or immediately after the technical change. The index should describe responsibility and evidence boundary, not duplicate implementation details that are clearer in code.

Do not use the existence of a script as proof that its gate passed. Build/runtime conclusions still require the exact workflow, run ID, job ID, source-under-test SHA, and artifacts where relevant. Physical XP runtime and GOST TLS handshake remain separate acceptance lines.