# Windows XP x86 `bcrypt.dll` compatibility status

Last updated: 2026-09-01

This document records the adopted remediation and exact evidence for the Windows XP x86 `bcrypt.dll` dependency. It belongs to the Windows compatibility track only and is not GOST TLS handshake evidence.

## Status — CLOSED at focused dependency/runtime level; single-DLL implementation selected and physically proven

The missing stock-XP `bcrypt.dll` boundary is no longer an unresolved focused-runtime problem.

The selected implementation is the source-built One-Core-API `bcrypt.dll` from pinned `shorthorn-project/One-Core-API-Source`, with the required mbedTLS C implementation compiled directly into `bcrypt.dll`. No separate runtime `mbedtls.dll` is required.

The exact single-DLL runtime artifact has passed:

- source/build CI;
- PE/import gates;
- exact-local hosted dynamic execution;
- physical Windows XP SP3 x86 execution through both explicit dynamic loading and normal linked/IAT resolution.

This closes the focused bcrypt dependency/runtime question. It does **not** prove that a complete Firefox build starts on XP, and it does not close the independent SRW/condition-variable or other remaining post-XP import work.

## Selected implementation — one deployable `bcrypt.dll`

Exact project identity:

- branch: `agent/gost-tls-poc`;
- source-under-test: `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- workflow: `One-Core bcrypt source XP x86 smoke`;
- Actions run `33513084915`;
- job `99873297193`;
- run/job conclusion: **success**.

Pinned upstream source/build identity:

- repository: `shorthorn-project/One-Core-API-Source`;
- pinned source commit: `9eb3c31de9460c1ccce3f6a10c9c4a704f032514`;
- bcrypt source: `dll/win32/bcrypt`;
- mbedTLS source: `dll/3rdparty/mbedtls`;
- build environment: RosBE 2.1.6 i386.

Pinned One-Core source contains one unrelated WIDL host-tool signature mismatch. The smoke applies the same documented one-line host-tool correction used by the earlier proven baseline. The bcrypt and mbedTLS C implementation sources themselves remain unmodified.

Build composition:

- the pinned active mbedTLS C modules are compiled directly into the bcrypt target as private sources;
- the bcrypt target no longer links/imports the separate `mbedtls` DLL target;
- no `mbedtls.dll` is staged;
- `bcrypt_main.c` remains in the normal bcrypt/Wine compile context;
- embedded mbedTLS C sources receive `-U__WINESRC__`, matching the important compile-context difference of the previously successful standalone mbedTLS target.

The `-U__WINESRC__` adjustment is required because the prior direct-source attempt, source `ef0050d5ded758acae1694a0e1b619830f440d37`, run `33511801331`, job `99869030264`, inherited bcrypt's `__WINESRC__` into `entropy_poll.c`. ReactOS/Wine headers then deliberately rejected unsuffixed `CryptAcquireContext`; this was a target compile-context mismatch, not a crypto implementation defect.

## Exact selected artifacts

- runtime artifact `9802703271` (`onecore-bcrypt-source-xp-x86-runtime`), digest `sha256:e6ea796ef5f7dfb67e346630cd6432c9659e6d90d39ce90b8f44a1b3632edc8f`;
- diagnostics artifact `9802704126` (`onecore-bcrypt-source-xp-x86-diagnostics`), digest `sha256:d989ce72af60185cb16b0ff99d156ed39170beab00055e776b881ee2cc54e6de`.

CI proves:

- all embedded mbedTLS C objects compile and link into `dll/win32/bcrypt/bcrypt.dll`;
- final `bcrypt.dll` passes the project's current XP PE/import gate;
- final `bcrypt.dll` does **not** import `mbedtls.dll`;
- required BCrypt exports remain present;
- exact-local dynamic execution against the staged local DLL passes exports, RNG and SHA-256.

Hosted linked-consumer nuance: on Windows Server 2022 the linked consumer resolves `bcrypt.dll` to `C:\Windows\System32\bcrypt.dll` through the system KnownDLL path. That hosted linked result was therefore not used as physical evidence for the staged candidate; physical XP execution below closes that boundary.

## Physical Windows XP SP3 x86 result — PASS

The user extracted exact runtime artifact `9802703271` unchanged on a physical machine reporting:

```text
Microsoft Windows XP [Version 5.1.2600]
```

The runtime directory contains exactly five files:

```text
bcrypt-source-dynamic.exe   4,096 bytes
bcrypt-source-linked.exe    4,096 bytes
bcrypt.dll                520,704 bytes
README-XP.md                1,147 bytes
run-on-xp.cmd                 303 bytes
```

There is no `mbedtls.dll` in the runtime directory.

Dynamic consumer result:

```text
=== One-Core source-built embedded-mbedtls bcrypt dynamic probe ===
LOAD PASS
MODULE PATH: D:\2026\09\01\onecore-bcrypt-source-xp-x86-runtime\bcrypt.dll
EXPORTS PASS
RNG PASS
SHA256 PASS
DynamicExitCode=0
```

Linked consumer result:

```text
=== One-Core source-built embedded-mbedtls bcrypt linked probe ===
LOAD PASS
MODULE PATH: D:\2026\09\01\onecore-bcrypt-source-xp-x86-runtime\bcrypt.dll
EXPORTS PASS
RNG PASS
SHA256 PASS
LinkedExitCode=0
```

Physical-file identity recorded by the user:

- `bcrypt.dll` size: `520704` bytes;
- SHA-1: `ae021f44edc48b03bb4d67cb5773b62bdf60cb67`.

This is decisive focused physical-XP evidence that the single source-built `bcrypt.dll` loads and executes successfully through both explicit dynamic loading and normal loader/IAT resolution, with the embedded mbedTLS implementation and no runtime `mbedtls.dll` dependency.

## Historical two-DLL baseline — physically proven, superseded as selected implementation

The earlier source-built closure remains valid historical evidence:

- source-under-test `fdd4d4dac5a7d9611ec71975ae800437f45c47dd`;
- run `33493625367`, job `99810642354`, success;
- runtime artifact `9794971087`, digest `sha256:03627eb494b604d3a84a9473cad8c0928b13ec458c20cee9e63bfc0ca10d75f1`;
- diagnostics artifact `9794971830`, digest `sha256:832563a5618d52f061fcc55efea463e618b4212aea12236ef7bf015cd39e93fe`;
- closure `bcrypt.dll -> mbedtls.dll -> XP system DLLs`;
- both dynamic and linked consumers passed on physical XP.

That result proved the underlying source implementation before the packaging simplification. It remains a fallback/baseline, but the physically proven single-DLL implementation from run `33513084915` now supersedes it for full-browser integration.

The still earlier prebuilt-binary closure experiments involving `bcryptext.dll`, Code Integrity, `ERROR_INVALID_IMAGE_HASH`, and `DLL_INIT_FAILED` remain historical diagnostics only and must not be mixed with either source-built closure.

## Relationship to Firefox XP work

Historical broad Firefox audit source `1635d28360ee35d47c1d8237bcf8f5864cc1144f`, run `33310150314`, job `99253613546`, reported direct `bcrypt.dll` dependencies in `xul.dll` and `mozglue.dll`.

The focused bcrypt implementation is now closed in its selected single-DLL form. The next bcrypt work is integration, not implementation research:

1. reproduce the exact pinned source/build composition in the full XP x32 workflow;
2. stage only the resulting `bcrypt.dll` into the browser package;
3. preserve source/provenance, PE/import and package-survival gates;
4. bind the resulting exact Firefox package to physical-XP startup/browsing.

A full browser can still fail on independent imports such as the SRW/condition-variable family or other post-XP APIs. Do not reinterpret this focused bcrypt success as Firefox startup proof or GOST TLS proof.
