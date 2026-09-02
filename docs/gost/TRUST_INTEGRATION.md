# Windows system roots + Russian Trusted Root CA integration

Status: **ACTIVE / FAST PREFLIGHT GREEN; FULL PACKAGE RETRY IN PROGRESS**.

Track: browser/government-system packaging and ordinary Firefox/NSS trust integration. This is independent from GOST TLS MSSPI server verification and from Windows Vista/7/XP binary compatibility.

## Current checkpoint — 2026-09-02

The trust-integration work continues on the isolated branch:

`agent/trust-integration-poc`

Branch base / documented default-branch checkpoint:

`ab9b9abb09f30e5dcb665b681cd1fbc092954c1b`

Current full-package source-under-test:

`e7640a8195c6f10d8e909ad620ace74fa08c2c86`

The later branch commit `88f7d45c01a8a9a740d4e3d35043ae812a9dd624` only restores the original heavy-workflow trigger policy and must not be cited as the source-under-test for the already-started package run.

The current implementation contains the intended trust changes relative to the branch base:

- `.github/workflows/government-trust-packaging-preflight.yml` — exact two-root static contract;
- `r3dfox/policies.json` — `Certificates.ImportEnterpriseRoots=true` and exactly two `Certificates.Install` entries;
- `r3dfox/moz.build` — both roots staged under `distribution/Certificates`, with the list kept in the lexicographic order required by Mozilla `StrictOrderingOnAppendList`;
- `browser/installer/package-manifest.in` — both roots preserved in the final package;
- `.github/workflows/cryptopro-mozilla-packaging-smoke.yml` — exact root presence/hash gates in real `dist/bin` and in the extracted final portable archive, plus trust evidence files in the existing evidence artifact.

The temporary `apply-trust-integration-once.yml` bootstrap workflow used during branch setup has been removed. Repository edits are direct; GitHub Actions in this track are verification only.

## Pinned public trust anchors

Bundle exactly these two binary DER root CAs:

1. `r3dfox/certificates/russian_trusted_root_ca_rsa.cer`
   - subject/common name: `Russian Trusted Root CA`;
   - organization: `The Ministry of Digital Development and Communications`;
   - self-signed CA root;
   - validity: 2022-03-01 through 2032-02-27;
   - SHA-256: `d26d2d0231b7c39f92cc738512ba54103519e4405d68b5bd703e9788ca8ecf31`.

2. `r3dfox/certificates/russian_trusted_root_ca_gost.cer`
   - subject/common name: `Минцифры России`;
   - self-signed CA root;
   - validity: 2022-01-08 through 2040-01-08;
   - SHA-256: `4bb37cc7c0ff4bf2aa893e95076ebb3565c69237ee1b61635beee4c1966495c7`.

Both source files must remain binary DER and byte-for-byte pinned.

Do **not** bundle/install a Sub CA/intermediate. Manual runtime testing established that the intended behavior requires the root anchors, not an explicitly bundled intermediate. Reopen that decision only if a concrete future runtime failure proves an intermediate is required.

## Firefox Enterprise Policy

`r3dfox/policies.json` contains:

```json
"Certificates": {
  "ImportEnterpriseRoots": true,
  "Install": [
    "russian_trusted_root_ca_rsa.cer",
    "russian_trusted_root_ca_gost.cer"
  ]
}
```

`ImportEnterpriseRoots=true` is the authoritative product mechanism for importing the Windows enterprise/system trust roots. `Certificates.Install` supplies the two pinned portable fallback trust anchors.

### AutoConfig boundary

The inherited `r3dfox/config.cfg` still contains the pre-existing enterprise-root defaults:

```js
defaultPref("security.certerrors.mitm.auto_enable_enterprise_roots", false);
defaultPref("security.enterprise_roots.enabled", false);
```

The current PoC deliberately does not change them before exact-artifact runtime verification. Firefox 153 enterprise-policy implementation handles `Certificates.ImportEnterpriseRoots` by setting and locking `security.enterprise_roots.enabled` to the policy value, so the expected effective runtime value is `true` despite the inherited AutoConfig default. The clean-profile runtime acceptance gate must prove that actual precedence/effective state in this fork rather than assuming it from static code alone.

`security.certerrors.mitm.auto_enable_enterprise_roots` is a separate automatic MITM/certificate-error mechanism and is not set by the `Certificates.ImportEnterpriseRoots` policy. Its inherited `false` value is therefore not by itself evidence that policy-driven Windows-root import is disabled.

If exact-artifact runtime evidence shows that AutoConfig defeats or otherwise conflicts with policy behavior, change `config.cfg` on that evidence. Do not change both mechanisms speculatively before the runtime gate.

## Build and package staging

`r3dfox/moz.build` stages:

```text
distribution/Certificates/russian_trusted_root_ca_gost.cer
distribution/Certificates/russian_trusted_root_ca_rsa.cer
```

The source list is intentionally `gost` before `rsa` because Mozilla's `FINAL_TARGET_FILES` list type enforces lexical ordering.

`browser/installer/package-manifest.in` explicitly preserves both certificate paths in the final portable package.

The manifest and policy changes were diff-checked after editing and contain no unrelated substitutions.

## Fast trust preflight — GREEN

`.github/workflows/government-trust-packaging-preflight.yml` is the low-cost static trust gate.

Authoritative successful result:

- workflow: `Government trust packaging preflight`;
- run ID: `33593375735`;
- job ID: `100131774111` (`Windows/NSS two-root trust packaging contract`);
- source-under-test: `b7a2b7289a49e498911ac1231e517632469074b3`;
- result: **SUCCESS**.

The exact run passed:

- `Certificates.ImportEnterpriseRoots=true`;
- exactly the two RSA/GOST `Certificates.Install` filenames;
- both DER files and exact SHA-256 values;
- public X.509 identities;
- self-issued/root identity and `BasicConstraints: CA=TRUE`;
- `r3dfox/moz.build` staging entries;
- `browser/installer/package-manifest.in` package entries.

The predecessor failed run `33592606106` was a workflow-harness false negative caused by a Cyrillic Subject literal in Windows PowerShell, not a certificate/trust failure.

The fast gate intentionally does not prove runtime policy effectiveness and does not prove survival in the final portable archive.

## Full package integration

`.github/workflows/cryptopro-mozilla-packaging-smoke.yml` is the selected heavy integration/package proof because it already exercises the full release Firefox build, CryptoPro XPI staging, pinned Russian localization, production `ru` merge, `mach package`, final portable extraction and evidence upload.

The trust extension keeps all existing CryptoPro/l10n gates and additionally requires:

- both pinned roots at `obj-gost-win64/dist/bin/distribution/Certificates/` after the full build;
- exact SHA-256 for both roots there;
- exactly one copy of each root under `distribution/Certificates/` in the extracted final portable archive;
- the same exact SHA-256 values again in the portable package;
- `trust-dist-bin-evidence.txt` and `trust-package-evidence.txt` in the existing packaging evidence artifact.

### First heavy trust attempt — FAILED BEFORE BUILD

Exact result:

- source-under-test `b2184aa0c7c95a47a35c7010248953902500daf3`;
- run `33594665980`;
- job `100135594681` (`Windows x64 / CryptoPro real Firefox packaging / ru + en-US`);
- result: **FAILURE**;
- failing step: `Configure object directory and verify Rust target and l10n base`;
- full `mach build`, `dist/bin` trust gate, package step and final portable trust gate were all skipped.

The failure was a Mozilla build-description ordering error, not trust evidence. `r3dfox/moz.build` supplied the certificate list as RSA then GOST, while `FINAL_TARGET_FILES` uses `StrictOrderingOnAppendList` and required lexical order GOST then RSA. Configure raised `mozbuild.util.UnsortedError` before any browser compilation.

Commit `e7640a8195c6f10d8e909ad620ace74fa08c2c86` fixes only that ordering defect by swapping the two certificate entries. Its diff was checked and contains no other source change.

### Corrected heavy retry — IN PROGRESS

- source-under-test `e7640a8195c6f10d8e909ad620ace74fa08c2c86`;
- run `33595966569`;
- job `100139347397`;
- state at handoff: **in progress**.

Do not record any build/package/trust gate from this retry as passed until the exact job finishes.

The heavy workflow had temporarily acquired three unintended trigger additions (`agent/trust-integration-poc`, `r3dfox/policies.json`, `r3dfox/certificates/**`) solely as launch plumbing. Commit `88f7d45c01a8a9a740d4e3d35043ae812a9dd624` removes exactly those three lines and restores the prior trigger policy while preserving the trust gates. The already-running retry remains bound to `e7640a819...`.

## Historical bootstrap failures — not trust evidence

Two temporary one-shot branch-bootstrap runs failed for infrastructure reasons only and must not be interpreted as certificate, policy, NSS or packaging failures:

- run `33590909408`, job `100124538722`, source/trigger `d2d8f0a22063d40881f9fa2f4928cf9a585fb8d1`: the helper performed an unnecessarily deep checkout and its eventual push was rejected after the branch had moved;
- run `33591700739`, job `100126850286`, source `668d0c9db56dd7b49de911924f9872a9911b3d32`: the helper produced the intended local trust commit, but GitHub rejected the push because the Actions token lacked permission to update workflow files.

The helper workflow is removed. Future source changes in this track are direct repository edits; Actions are used only as gates/tests.

## Remaining PoC work

1. Obtain the final conclusion of heavy retry `33595966569` / job `100139347397` / source `e7640a8195c6f10d8e909ad620ace74fa08c2c86` and require both exact trust gates plus the existing CryptoPro/l10n gates to pass.
2. Record the exact packaged browser and evidence artifact identities from that run if successful.
3. On a completely new profile verify `about:policies`, effective `security.enterprise_roots.enabled`, Windows-root import without manual NSS import, and the intended relationship with the inherited AutoConfig defaults.
4. Verify the target Russian RSA PKI path and relevant GOST PKI path with the two-root contract and without bundling a Sub CA.
5. Bind runtime results to the exact source SHA, Actions run/job, browser artifact and relevant binary hashes.
6. After the PoC is proven, transfer only the minimal audited trust diff back to `agent/gost-tls-poc`; do not merge the experimental branch history wholesale.

## Runtime acceptance gate

A full integrated build is accepted for this track only after a clean-profile exact-artifact test proves:

1. `about:policies` shows the `Certificates` policy active;
2. `security.enterprise_roots.enabled` is effectively `true` under policy;
3. Windows-installed trusted roots are honored without manual NSS import;
4. both pinned portable root anchors are available to the packaged browser;
5. the target RSA and GOST PKI paths behave as required with the two roots and no explicitly bundled Sub CA;
6. exact source SHA, Actions run/job, artifact and relevant browser binary hashes are recorded.

## Boundary with GOST TLS

This work is ordinary Firefox/NSS + Windows trust-store integration for the adapted browser. It does **not** close the independent GOST TLS MSSPI server-verification blocker. MSSPI/SSPI/CryptoAPI verification requires its own exact-artifact GOST runtime evidence.

Likewise, a green trust preflight or successful browser package does not prove Windows XP/Vista/7 loader compatibility.
