# Windows XP x86 `bcrypt.dll` compatibility status

Last updated: 2026-09-01

This document records the adopted remediation and exact evidence for the Windows XP x86 `bcrypt.dll` dependency. It belongs to the Windows compatibility track only and is not GOST TLS handshake evidence.

## Status — CLOSED at focused dependency/runtime level; single-DLL simplification candidate awaiting physical XP

The missing stock-XP `bcrypt.dll` boundary is no longer an unresolved focused-runtime problem.

The physically proven baseline remains the source-built One-Core-API variant from `shorthorn-project/One-Core-API-Source` with its source-built `mbedtls.dll` runtime dependency. That exact two-DLL closure has passed both hosted execution and physical Windows XP SP3 x86 execution.

A newer preferred packaging candidate now also passes CI: the same pinned mbedTLS C implementation is compiled directly into `bcrypt.dll`, eliminating the runtime `mbedtls.dll` dependency while preserving the BCrypt ABI. This single-DLL candidate has not yet been executed on physical XP and therefore does **not** yet supersede the physically proven two-DLL baseline.

This closes the focused question of whether a working source-built bcrypt implementation exists. It does **not** prove that a complete Firefox build starts on XP, and it does not close the independent SRW/condition-variable or other remaining post-XP import work.

## Physically proven baseline — two-DLL closure

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

Pinned One-Core source contains one unrelated WIDL host-tool signature mismatch. The smoke applies only the documented one-line host-tool correction required to build the pinned tree. `dll/win32/bcrypt` and `dll/3rdparty/mbedtls` implementations are not modified by that correction.

Exact artifacts:

- runtime artifact `9794971087` (`onecore-bcrypt-source-xp-x86-runtime`), digest `sha256:03627eb494b604d3a84a9473cad8c0928b13ec458c20cee9e63bfc0ca10d75f1`;
- diagnostics artifact `9794971830` (`onecore-bcrypt-source-xp-x86-diagnostics`), digest `sha256:832563a5618d52f061fcc55efea463e618b4212aea12236ef7bf015cd39e93fe`.

The proven runtime closure is:

`bcrypt.dll -> mbedtls.dll -> XP system DLLs`.

The runtime bundle carries two independent consumers:

- `bcrypt-source-dynamic.exe` — no static `bcrypt.dll` import; exact local `LoadLibraryW(.\\bcrypt.dll)` plus `GetProcAddress`;
- `bcrypt-source-linked.exe` — ordinary PE import of `bcrypt.dll`.

Both consumers test the required BCrypt export surface, `BCryptGenRandom`, and SHA-256 of `abc`.

### Physical Windows XP SP3 x86 result — PASS

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

## Preferred simplification candidate — one deployable `bcrypt.dll`

Exact project identity:

- source-under-test `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- workflow `One-Core bcrypt source XP x86 smoke`;
- Actions run `33513084915`;
- job `99873297193`;
- run/job conclusion: **success**;
- pinned One-Core source remains `9eb3c31de9460c1ccce3f6a10c9c4a704f032514`;
- successful two-DLL baseline remains `fdd4d4dac5a7d9611ec71975ae800437f45c47dd` / run `33493625367` / job `99810642354`.

Build composition:

- the pinned active mbedTLS C modules are compiled directly into the bcrypt target as private sources;
- the bcrypt target no longer links the `mbedtls` import library;
- no separate `mbedtls.dll` is staged;
- `bcrypt_main.c` remains in the normal bcrypt/Wine compile context;
- embedded mbedTLS C sources receive `-U__WINESRC__`, matching the important compile-context difference of the previously successful standalone mbedTLS target;
- no bcrypt or mbedTLS C implementation source is patched.

The compile-context adjustment is required because the previous direct-source attempt, source `ef0050d5ded758acae1694a0e1b619830f440d37`, run `33511801331`, job `99869030264`, inherited bcrypt's `__WINESRC__` into `entropy_poll.c`. ReactOS/Wine headers then deliberately rejected unsuffixed `CryptAcquireContext`, so the failure was a target compile-context mismatch rather than a crypto implementation defect.

Exact successful candidate artifacts:

- runtime artifact `9802703271` (`onecore-bcrypt-source-xp-x86-runtime`), digest `sha256:e6ea796ef5f7dfb67e346630cd6432c9659e6d90d39ce90b8f44a1b3632edc8f`;
- diagnostics artifact `9802704126` (`onecore-bcrypt-source-xp-x86-diagnostics`), digest `sha256:d989ce72af60185cb16b0ff99d156ed39170beab00055e776b881ee2cc54e6de`.

CI proves:

- all embedded mbedTLS C objects compile and link into `dll/win32/bcrypt/bcrypt.dll`;
- final `bcrypt.dll` passes the project's current XP PE/import gate;
- final `bcrypt.dll` does **not** import `mbedtls.dll`;
- required BCrypt exports remain present;
- the exact-local dynamic consumer loads the staged local `bcrypt.dll` and passes exports, RNG and SHA-256.

Hosted linked-consumer nuance: on Windows Server 2022 the linked consumer reports `C:\Windows\System32\bcrypt.dll`, consistent with system KnownDLL resolution. Its hosted RNG/SHA-256 pass therefore does not prove linked execution against the staged local candidate. This is why physical XP execution of artifact `9802703271` remains mandatory before adoption.

### Next acceptance gate

Run artifact `9802703271` unchanged on physical Windows XP SP3 x86 with `run-on-xp.cmd` and require both consumers to report:

- the local artifact `bcrypt.dll` module path;
- `EXPORTS PASS`;
- `RNG PASS`;
- `SHA256 PASS`;
- exit code `0`.

If that succeeds, the single-DLL closure becomes the selected contract for full Firefox integration and the two-DLL closure remains historical fallback/baseline evidence. Until then, the two-DLL closure remains the last physically proven implementation.

## Relationship to Firefox XP work

Historical broad Firefox audit source `1635d28360ee35d47c1d8237bcf8f5864cc1144f`, run `33310150314`, job `99253613546`, reported direct `bcrypt.dll` dependencies in `xul.dll` and `mozglue.dll`.

The focused bcrypt implementation is proven in two-DLL form and has a CI-green single-DLL candidate. Transfer into the full XP x32 browser workflow remains a separate integration experiment and should use the single-DLL candidate only after its physical-XP gate passes.

A full browser can still fail on independent imports such as the SRW/condition-variable family or other post-XP APIs. Do not reinterpret any focused bcrypt success as Firefox startup proof or GOST TLS proof.
