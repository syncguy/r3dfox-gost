# Windows XP x86 `bcrypt.dll` compatibility status

Last updated: 2026-09-01

This document records the adopted remediation and exact evidence for the Windows XP x86 `bcrypt.dll` dependency. It belongs to the Windows compatibility track only and is not GOST TLS handshake evidence.

## Status — CLOSED at focused dependency/runtime level

The missing stock-XP `bcrypt.dll` boundary is no longer an unresolved focused-runtime problem.

The selected implementation is now the source-built One-Core-API variant from `shorthorn-project/One-Core-API-Source`, with its required source-built `mbedtls.dll` runtime dependency. The exact runtime closure has passed both hosted exact-local execution and physical Windows XP SP3 x86 execution.

This closes the focused `bcrypt.dll` dependency/runtime question. It does **not** prove that a complete Firefox build starts on XP, and it does not close the independent SRW/condition-variable or other remaining post-XP import work.

## Exact source/build identity

Project source-under-test:

- branch: `agent/gost-tls-poc`;
- source-under-test: `fdd4d4dac5a7d9611ec71975ae800437f45c47dd`;
- workflow: `One-Core bcrypt source XP x86 smoke`;
- Actions run `33493625367`;
- job `99810642354`;
- run/job conclusion: **success**.

Pinned upstream source:

- repository: `shorthorn-project/One-Core-API-Source`;
- pinned source commit: `9eb3c31de9460c1ccce3f6a10c9c4a704f032514`;
- bcrypt source: `dll/win32/bcrypt`;
- mbedtls source: `dll/3rdparty/mbedtls`;
- build environment: RosBE 2.1.6 i386.

Pinned One-Core source contains one unrelated WIDL host-tool signature mismatch. The smoke applies only the documented one-line host-tool correction required to build the pinned tree. `dll/win32/bcrypt` and `dll/3rdparty/mbedtls` are not modified by that correction.

## Exact artifacts

- runtime artifact `9794971087` (`onecore-bcrypt-source-xp-x86-runtime`), digest `sha256:03627eb494b604d3a84a9473cad8c0928b13ec458c20cee9e63bfc0ca10d75f1`;
- diagnostics artifact `9794971830` (`onecore-bcrypt-source-xp-x86-diagnostics`), digest `sha256:832563a5618d52f061fcc55efea463e618b4212aea12236ef7bf015cd39e93fe`.

The runtime closure contains the source-built `bcrypt.dll`, source-built `mbedtls.dll`, and two independent consumers:

- `bcrypt-source-dynamic.exe` — no static `bcrypt.dll` import; exact local `LoadLibraryW(.\\bcrypt.dll)` plus `GetProcAddress`;
- `bcrypt-source-linked.exe` — ordinary PE import of `bcrypt.dll`.

Both consumers test the required BCrypt export surface, `BCryptGenRandom`, and SHA-256 of `abc`.

## Dependency closure

The source-built `bcrypt.dll` has a real runtime dependency on `mbedtls.dll`. That dependency is explicit in the One-Core build definition and is included in the artifact.

The built `mbedtls.dll` resolves only to XP-era system DLLs (`advapi32.dll`, `kernel32.dll`, `msvcrt.dll` in the final PE) and the focused audit found no known forbidden post-XP hard import from the project's current XP gate set.

The source-built closure therefore terminates as:

`bcrypt.dll -> mbedtls.dll -> XP system DLLs`.

This supersedes the earlier prebuilt-binary closure experiments involving export forwarders to `bcryptext.dll`. The prebuilt and source-built One-Core bcrypt implementations are distinct artifacts and must not be conflated.

## Hosted exact-local result

Run `33493625367` passes the hosted Windows Server 2022 runtime checks for the complete source-built closure. Unlike the earlier prebuilt binary, this source-built bcrypt does not hit the prebuilt image's Code Integrity refusal and executes the actual local library bytes.

Both dynamic and linked consumers pass their RNG and SHA-256 checks in CI.

## Physical Windows XP SP3 x86 result — PASS

The user executed the exact runtime bundle from run `33493625367` on a physical Windows XP machine on 2026-09-01.

Dynamic consumer result:

```text
LOAD PASS
MODULE PATH: D:\2026\09\01\onecore-bcrypt-source-xp-x86-runtime\bcrypt.dll
EXPORTS PASS
RNG PASS
SHA256 PASS
DynamicExitCode=0
```

Linked consumer result:

```text
LOAD PASS
MODULE PATH: D:\2026\09\01\onecore-bcrypt-source-xp-x86-runtime\bcrypt.dll
EXPORTS PASS
RNG PASS
SHA256 PASS
LinkedExitCode=0
```

This is decisive focused physical-XP evidence that the source-built `bcrypt.dll + mbedtls.dll` closure loads and executes successfully through both explicit dynamic loading and normal loader/IAT resolution.

## Relationship to Firefox XP work

Historical broad Firefox audit source `1635d28360ee35d47c1d8237bcf8f5864cc1144f`, run `33310150314`, job `99253613546`, reported direct `bcrypt.dll` dependencies in `xul.dll` and `mozglue.dll`.

The focused bcrypt dependency implementation is now proven and may be transferred into the full XP x32 browser workflow with its exact source/provenance/import/package gates.

That transfer is a separate integration experiment. A full browser can still fail on independent imports such as the SRW/condition-variable family or other post-XP APIs. Do not reinterpret this focused success as Firefox startup proof or GOST TLS proof.
