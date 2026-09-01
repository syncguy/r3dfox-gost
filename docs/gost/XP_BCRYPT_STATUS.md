# Windows XP x86 `bcrypt.dll` compatibility status

Last updated: 2026-09-01

This document records the adopted remediation and current evidence for the Windows XP x86 `bcrypt.dll` dependency. It belongs to the Windows compatibility track only and is not GOST TLS handshake evidence.

## Decision

The project continues to use the XP-compatible `bcrypt.dll` supplied by `shorthorn-project/One-Core-API-Binaries` as the selected dependency-level remediation for the core-browser `bcrypt.dll` imports. This remains independent of the YY-Thunks synchronization provider.

## Exact candidate identity

The focused smoke pins the candidate to immutable upstream content rather than floating `master`:

- repository: `shorthorn-project/One-Core-API-Binaries`;
- upstream commit: `6c3b3b372d46dace7ba729dcd16b316b0acf664c`;
- path: `Packages/x86/Pack Installer/base/bcrypt.dll`;
- Git blob: `0b7d83ddbae62142ee6fca69208d77a8a5d3b0f7`;
- size: `279552` bytes;
- SHA-256: `ada28a011cf08d9e10780fde09966899f5f40e08c4f5abb05eaa38dbc2f0cfc5`.

`bcryptprimitives.dll` is present beside the candidate upstream, but the recursive PE import audit does not include it in the dependency closure.

## Focused smoke evidence

Current exact focused experiment:

- source-under-test: `9be3a933c3eac2defec24df4826fded48ead02f4`;
- workflow: `bcrypt XP x86 smoke`;
- Actions run `33475562495`, job `99753970359`;
- runtime artifact `9788031922`, digest `sha256:c0d60f0a0bc18acd09abb9138ea2769a36c3996e71c87018ccf4842abd9e0817`;
- diagnostics artifact `9788032206`, digest `sha256:83685ec9aebb4987e95e42cff6c74f958a1c9252d06721383323e0ab5b200fbe`;
- CI conclusion: **failure**, specifically because the exact-local hosted runtime probe cannot load the unmodified candidate on Windows Server 2022.

Static surface established by this run:

- machine: x86 (`0x14c`);
- PE operating-system/image/subsystem version: `6.00`;
- direct DLL imports: `ADVAPI32.dll`, `KERNEL32.dll`, `ntdll.dll`;
- recursive local closure: **`bcrypt.dll` only**;
- current explicit XP hard-import audit: no obvious post-XP hard imports detected in that closure;
- required BCrypt exports all present: `BCryptOpenAlgorithmProvider`, `BCryptCloseAlgorithmProvider`, `BCryptGetProperty`, `BCryptCreateHash`, `BCryptHashData`, `BCryptFinishHash`, `BCryptDestroyHash`, `BCryptGenRandom`;
- DLL characteristics contain `Check integrity`; Certificate Directory is zero; Authenticode status is `NotSigned`.

Both focused x86 consumer probes build with PE subsystem floor `5.01`. `bcrypt-dynamic.exe` has no link-time bcrypt dependency and explicitly requests `.\bcrypt.dll`; `bcrypt-linked.exe` is an ordinary `bcrypt.lib` consumer with a normal `bcrypt.dll` IAT import.

## Hosted-runner limitation

On the exact run, the dynamic local-load probe returns:

```text
LOAD FAIL error=0x00000241
ExitCode=1
```

`0x241` / 577 is `ERROR_INVALID_IMAGE_HASH`. Given the exact image's `Check integrity` characteristic and absence of an embedded signature, current Windows Server 2022 refuses the exact local upstream image under modern Code Integrity. This hosted failure must not be treated as physical-XP evidence and must not be worked around by mutating the candidate bytes.

The ordinary linked probe passes its functional RNG/SHA-256 test on the hosted runner, but records:

```text
MODULE PATH: C:\Windows\System32\bcrypt.dll
```

Thus modern Windows resolves the normal `bcrypt.dll` dependency to its system copy. That result proves the linked probe itself is a valid ordinary consumer; it does **not** validate the local One-Core-API implementation.

## Physical XP acceptance boundary

Artifact `9788031922` is the current physical Windows XP SP3 x86 test bundle. It contains exactly:

- `bcrypt.dll` — 279552 bytes, SHA-256 `ada28a011cf08d9e10780fde09966899f5f40e08c4f5abb05eaa38dbc2f0cfc5`;
- `bcrypt-dynamic.exe` — SHA-256 `851994bc485f850660a4a7409d224b1490a2ef46d64342b58ab2317d14a6bc37`;
- `bcrypt-linked.exe` — SHA-256 `c9e0fc9d316da3286be9c2ca839ba1cd26f07979710825ffd69c1de514f4da57`;
- `run-on-xp.cmd`;
- `README-XP.md`.

The candidate is **not physically XP-verified yet**. The next decisive step is to copy this archive unchanged to physical Windows XP SP3 x86 and run `run-on-xp.cmd`. Both probes must return `ExitCode=0`; the functional output must include `LOAD PASS`, `EXPORTS PASS`, `RNG PASS`, and `SHA256 PASS`.

Do not call the replacement fully accepted for XP runtime until that exact physical test succeeds.

## Relationship to the full-browser work

Historical broad audit source `1635d28360ee35d47c1d8237bcf8f5864cc1144f`, Actions run `33310150314`, job `99253613546`, reported direct `bcrypt.dll` dependencies in `xul.dll` and `mozglue.dll`. The One-Core candidate remains the selected remediation for that DLL-level boundary.

This focused experiment neither builds Firefox nor changes the independent SRW/condition-variable/CRT/YY-Thunks line. Successful compilation or packaging elsewhere must not be confused with successful loading of this exact `bcrypt.dll` on physical XP.
