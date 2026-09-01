# Windows XP x86 `bcrypt.dll` compatibility status

Last updated: 2026-09-01

This document records the adopted remediation and current evidence for the Windows XP x86 `bcrypt.dll` dependency. It belongs to the Windows compatibility track only and is not GOST TLS handshake evidence.

## Decision

The project continues to evaluate the XP-compatible `bcrypt.dll` supplied by `shorthorn-project/One-Core-API-Binaries` as the selected dependency-level remediation for the core-browser `bcrypt.dll` imports. This remains independent of the YY-Thunks synchronization provider.

The physical-XP probe on 2026-09-01 proved that `bcrypt.dll` cannot be treated as a single-file closure: its export table contains forwarded exports, including `BCryptCreateHash -> bcryptext.BCryptCreateHash`. The earlier static conclusion that the local closure contained only `bcrypt.dll` is superseded.

## Exact candidate identity

The focused smoke pins the primary candidate to immutable upstream content rather than floating `master`:

- repository: `shorthorn-project/One-Core-API-Binaries`;
- upstream commit: `6c3b3b372d46dace7ba729dcd16b316b0acf664c`;
- primary path: `Packages/x86/Pack Installer/base/bcrypt.dll`;
- Git blob: `0b7d83ddbae62142ee6fca69208d77a8a5d3b0f7`;
- size: `279552` bytes;
- SHA-256: `ada28a011cf08d9e10780fde09966899f5f40e08c4f5abb05eaa38dbc2f0cfc5`.

Known forwarded dependency discovered by the physical-XP experiment and confirmed in the pinned upstream tree:

- path: `Packages/x86/Pack Installer/extensions/bcryptext.dll`;
- Git blob: `5c638cc34aedfe6bebcb800e56b9a10d98670207`;
- size: `10752` bytes.

`bcryptprimitives.dll` is present beside `bcrypt.dll` upstream, but it is not assumed to belong to the runtime closure unless the recursive import/forwarder audit discovers it transitively.

## Hosted focused-smoke baseline

Previous exact focused experiment:

- source-under-test: `9be3a933c3eac2defec24df4826fded48ead02f4`;
- workflow: `bcrypt XP x86 smoke`;
- Actions run `33475562495`, job `99753970359`;
- runtime artifact `9788031922`;
- diagnostics artifact `9788032206`.

That experiment established the primary `bcrypt.dll` PE/import/export surface but its closure algorithm followed only the PE Import Table. It therefore missed export-forwarder dependencies and its `closure = bcrypt.dll only` conclusion is invalid.

A later hosted workflow run used source `b8608989aaa8e853fd0fc0de940ce6388007a695`, run `33477355118`, job `99759309370`, runtime artifact `9788642060`, diagnostics artifact `9788642478`. Its hosted result was green only because the known Windows Server 2022 `ERROR_INVALID_IMAGE_HASH (577)` exact-local limitation was classified as an expected hosted XFAIL while all other static/build/artifact gates passed. That run still inherited the incomplete import-only closure logic and therefore produced an incomplete physical-XP bundle.

## Physical Windows XP result — FAIL, forwarder closure incomplete

A physical Windows XP x86 run of `run-on-xp.cmd` supplied by the user produced:

```text
=== bcrypt dynamic local-load probe ===
LOAD FAIL error=0x0000045A
ExitCode=1

=== bcrypt normal link-time consumer ===
ExitCode=-1073741511
```

The loader also displayed:

```text
bcrypt-linked.exe - Entry Point Not Found
The procedure entry point bcryptext.BCryptCreateHash could not be located in the dynamic link library bcrypt.dll.
```

Interpretation:

- `0x45A` is `ERROR_DLL_INIT_FAILED`: the local `bcrypt.dll` was found but failed initialization on XP;
- `-1073741511` is `0xC0000139` / `STATUS_ENTRYPOINT_NOT_FOUND`: the normal linked consumer fails in the loader before entering its test body;
- `dumpbin /exports` for the pinned `bcrypt.dll` shows `BCryptCreateHash (forwarded to bcryptext.BCryptCreateHash)`;
- therefore the old import-only dependency closure was incomplete, and the old runtime artifact cannot be accepted as a valid physical-XP test of the intended One-Core bcrypt stack.

Until the exact artifact identity of the user-run bundle is independently rebound by artifact ID/hash, treat the runtime-output identity as contextual rather than formal provenance. The technical forwarder conclusion itself is independently confirmed against the pinned candidate's export table.

## Corrected closure experiment

Source `3dc50ea09dd84e9a5c5e47c171fb180eb1acac4f` changes the focused smoke to search both pinned One-Core roots used by this dependency family:

- `Packages/x86/Pack Installer/base/`;
- `Packages/x86/Pack Installer/extensions/`.

The closure is now recursive over both:

1. normal PE imports; and
2. exported forwarders reported by `dumpbin /exports`.

Forwarder targets are audited, hashed and staged like ordinary local dependencies. The first expected newly discovered member is `bcryptext.dll`; any further transitively required One-Core DLLs must also be included automatically.

Actions run `33477914922` is the first run of this corrected closure logic. Its source-under-test is `3dc50ea09dd84e9a5c5e47c171fb180eb1acac4f`. Do not use its result as evidence until the run finishes and its exact artifacts are recorded.

## Physical XP acceptance boundary

The previous runtime artifacts are superseded for physical acceptance because they omit export-forwarder closure.

The next decisive test is:

1. wait for corrected run `33477914922` to finish;
2. use its newly generated `bcrypt-xp-x86-runtime` artifact unchanged;
3. copy the entire extracted directory to physical Windows XP SP3 x86;
4. run `run-on-xp.cmd` from that directory;
5. require both probes to return `ExitCode=0` and report `LOAD PASS`, `EXPORTS PASS`, `RNG PASS`, and `SHA256 PASS`.

Do not mark the One-Core bcrypt replacement physically XP-verified until that corrected complete-closure artifact passes both probes on the real XP machine.

## Relationship to the full-browser work

Historical broad audit source `1635d28360ee35d47c1d8237bcf8f5864cc1144f`, Actions run `33310150314`, job `99253613546`, reported direct `bcrypt.dll` dependencies in `xul.dll` and `mozglue.dll`. The One-Core candidate remains the selected remediation candidate for that DLL-level boundary, but its complete app-local dependency/forwarder closure must first pass focused physical-XP testing.

This focused experiment neither builds Firefox nor changes the independent SRW/condition-variable/CRT/YY-Thunks line. Successful compilation or packaging elsewhere must not be confused with successful loading of the complete One-Core bcrypt stack on physical XP.
