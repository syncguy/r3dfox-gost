# Windows XP x86 bcrypt release/staging contract

## Purpose

This document defines the mandatory lightweight acceptance contract for the app-local `bcrypt.dll` used by the Windows XP SP3 x86 compatibility line.

The contract is intentionally separate from the full Firefox build. Its job is to prove that the already physically validated binary can be retrieved reproducibly from the project release, staged at the same logical `dist/bin` boundary used by the browser build, and accepted only when its exact binary identity and minimum PE/runtime surface remain unchanged.

Passing this focused smoke is a prerequisite for integrating `bcrypt.dll` into `.github/workflows/gost-poc-build-xp-x32.yml` and into the final portable package. It does not by itself prove Firefox startup or GOST TLS runtime behavior.

## Authoritative binary

Release/tag: `xp-bcrypt-v1`  
Release ID: `380563342`  
Release asset: `bcrypt.dll`  
Asset ID: `539647946`  
Tag target/source checkpoint: `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`  
Upstream One-Core source: `9eb3c31de9460c1ccce3f6a10c9c4a704f032514`  
Size: `520704` bytes  
SHA-1: `ae021f44edc48b03bb4d67cb5773b62bdf60cb67`  
SHA-256: `f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`

The release records physical Windows XP 5.1.2600 PASS for this exact x86 binary. The deployment closure is one app-local `bcrypt.dll`; the mbedTLS implementation is embedded and no runtime `mbedtls.dll` is required.

Do not rebuild or substitute another bcrypt implementation merely to satisfy the browser package. A different binary requires a new explicit evidence cycle and must not silently replace `xp-bcrypt-v1`.

## Mandatory focused smoke

Workflow: `.github/workflows/xp-bcrypt-release-staging-smoke.yml`  
Workflow name: `XP bcrypt release staging smoke`

The smoke must remain independent from full Firefox compilation. It must:

1. resolve project release/tag `xp-bcrypt-v1`;
2. require the expected release ID and exactly one `bcrypt.dll` asset with the expected asset ID and size;
3. download that raw release asset;
4. stage it as `artifacts/xp-bcrypt-release-staging/dist/bin/bcrypt.dll`, representing the browser `dist/bin` integration boundary;
5. require exact size, SHA-1 and SHA-256 equality with the physically proven binary;
6. require PE x86 machine `14C`;
7. reject an external `mbedtls.dll` dependency and selected post-XP dependency classes (`api-ms-win-*`, `ext-ms-*`, `KERNELBASE.dll`, `BCRYPTPRIMITIVES.dll`);
8. require the minimum BCrypt exports used by the project compatibility path;
9. upload the staged `dist/bin` payload and diagnostics as separate artifacts.

The identity gate is fail-closed. A download that exists but differs by one byte is RED and must not be promoted into the full browser workflow.

## Focused smoke validation — GREEN

The release/staging contract is proven independently from a Firefox build.

Primary current evidence:

- branch: `agent/winrt-source-poc`;
- source-under-test: `8599aff218163d1c8f628be82db78a144b192700`;
- Actions run: `33711739424`;
- job: `100512509387` (`Stage proven bcrypt.dll into dist/bin`);
- result: **success**;
- staged payload artifact: `9877206025` (`xp-bcrypt-release-dist-bin`), digest `sha256:974d34619fa94b89119b02921e18ad9bde11f2a7648c065f54f8f096496cce0c`;
- diagnostics artifact: `9877206292` (`xp-bcrypt-release-staging-diagnostics`), digest `sha256:7d68383e993d02269995b2d9fdc4074d62236e127898d7e4deb721a090bc5620`.

Every workflow gate passed: release metadata retrieval, exact `dist/bin` staging, size/SHA-1/SHA-256 identity, x86 PE/runtime-closure audit, contract summary, and both artifact uploads.

The immediately preceding run also passed and serves as the initial implementation validation:

- source-under-test: `fe4c0f351cd44611b43acb42f6e44d1b134cf701`;
- Actions run: `33711714730`;
- job: `100512436855`;
- result: **success**;
- staged payload artifact: `9877189099`, digest `sha256:e9165dd31477229a2c7a27c36cd8e12e9cc69005f4c1a82c1dfa9d26919e6a10`;
- diagnostics artifact: `9877189382`, digest `sha256:52252ed0ca7aeb63ea4d3bc420d5c02ab79dad2c38afc746221a1e338d014ffa`.

The second GREEN is the preferred focused evidence because it validates the same workflow after the contract document was added.

## Full Firefox package integration — GREEN

The required integration sequence is now closed through the portable-package boundary.

Exact full-build evidence:

- branch: `agent/winrt-source-poc`;
- source-under-test: `4949a16e730cc15fc85b128fd62dac2a27c4d9c5`;
- workflow: `GOST TLS PoC build  XP x32`;
- Actions run: `33718674533`;
- job: `100533128424`;
- package artifact: `9883134667`, digest `sha256:64b9537376b72a9e38728236b666b929e84e9c6895a022a1dd66338b9a645582`;
- physical-test runtime artifact: `9883135451`, digest `sha256:9a5380bfec2b05a8460f6dfef99c85a1c053e1b31f9f18f101d6a7fc5563127b`;
- diagnostics artifact: `9883136547`, digest `sha256:b7fb3503a258d78fec927cd0f81413d5124f6f9b4a61cd27a034ec6092607f1c`.

The full workflow retrieves the pinned release asset, verifies the release/tag/asset metadata and exact binary identity, stages the proven DLL into the real `obj-gost-xp-x32/dist/bin` after the general PE-retarget step, and requires the package manifest to carry it into the portable archive.

`diagnostics/packaged-bcrypt-contract.txt` proves that accepted archive `r3dfox-v153.0.3.win32.portable.7z` contains exactly the same binary identity after packaging:

- size `520704`;
- SHA-1 `ae021f44edc48b03bb4d67cb5773b62bdf60cb67`;
- SHA-256 `f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`;
- source tag `xp-bcrypt-v1`;
- source asset ID `539647946`.

Therefore the automated chain `release -> exact identity -> real dist/bin -> package manifest -> portable archive` is **GREEN and closed** for `bcrypt.dll`.

The aggregate run is still RED for a separate reason: the distribution-wide import audit intentionally runs non-fatally to preserve evidence and found remaining post-XP imports in auxiliary/media/test PEs. That RED does not reopen the bcrypt identity/package contract.

## Required integration sequence — current status

1. focused `XP bcrypt release staging smoke` remains GREEN — **closed**;
2. reuse the same tag/asset identity in the full XP x32 workflow — **closed**;
3. put the exact `bcrypt.dll` into real Firefox `obj-gost-xp-x32/dist/bin` — **closed**;
4. explicit Mozilla packaging entry for `bcrypt.dll` — **closed**;
5. post-package exact-one-copy/hash gate — **closed**;
6. physical-XP browser startup using an artifact containing the exact proven bcrypt plus required CRT pair — **pending** for the current full-browser artifact.

## Evidence boundary

Historical physical proof for the underlying binary remains tied to the release metadata: source `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`, Actions run `33513084915`, job `99873297193`, runtime artifact `9802703271`, physical Windows XP PASS.

The focused and full-package GREEN results do not replace physical proof of the whole Firefox artifact. They prove that CI retrieves, stages, and packages exactly the same already-proven bcrypt binary. Full Firefox startup on physical XP remains a separate acceptance gate.
