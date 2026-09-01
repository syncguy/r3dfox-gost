# Windows XP x86 `bcrypt.dll` compatibility status

Last updated: 2026-09-01

This document records the adopted remediation for the Windows XP x86 `bcrypt.dll` dependency. It belongs to the Windows compatibility track only and is not GOST TLS handshake evidence.

## Decision

The project treats the `bcrypt.dll` dependency reported by the XP PE/import audit as **architecturally resolved by dependency replacement**.

The selected implementation is the XP-compatible `bcrypt.dll` supplied by the `shorthorn-project/One-Core-API-Binaries` project:

- repository: `https://github.com/shorthorn-project/One-Core-API-Binaries`;
- source branch/location selected by the user: `master`;
- remediation type: third-party compatibility DLL staged with the XP browser package;
- intended consumers include the direct `bcrypt.dll` dependencies previously reported in `xul.dll` and `mozglue.dll`.

This is a separate dependency-level solution. It is not part of the YY-Thunks synchronization provider and must not be mixed with the remaining post-XP Win32 API inventory.

## Status semantics

For planning and blocker counts, `bcrypt.dll` is no longer an open design question. Future XP work should not list it as an unresolved dependency choice unless new runtime evidence disproves the selected implementation.

Reproducible integration still requires the exact staged binary to be identified and gated. Before the replacement becomes a fully reproducible build-contract artifact, record:

- exact upstream path and immutable upstream revision or equivalent artifact identity;
- exact SHA-256 of the staged `bcrypt.dll`;
- x86 PE/subsystem identity;
- direct-import/dependency closure on XP;
- required BCrypt export surface for the actual Firefox consumers;
- license/provenance record appropriate for redistribution;
- confirmation that the same binary survives portable packaging;
- physical Windows XP startup/runtime confirmation using the exact packaged artifact.

These are provenance and acceptance checks for the chosen solution, not a request to re-evaluate whether One-Core-API should be used.

## Relationship to the current import baseline

The historical broad audit from source `1635d28360ee35d47c1d8237bcf8f5864cc1144f`, Actions run `33310150314`, job `99253613546`, reported two DLL-level violations: direct `bcrypt.dll` dependencies in `xul.dll` and `mozglue.dll`.

Those rows remain useful historical evidence describing the stock-XP loader gap in that artifact, but they should no longer be described as an unresolved current blocker. The adopted One-Core-API replacement is the current remediation for that DLL-level gap.

The remaining post-XP API work, including the synchronization family and source/native fallbacks, is tracked independently.