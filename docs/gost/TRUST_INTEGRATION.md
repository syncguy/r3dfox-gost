# Windows system roots + Russian Trusted Root CA integration

Status: **ACTIVE / TWO-ROOT POC IMPLEMENTED; FAST PREFLIGHT IN PROGRESS**.

Track: browser/government-system packaging and ordinary Firefox/NSS trust integration. This is independent from GOST TLS MSSPI server verification and from Windows Vista/7/XP binary compatibility.

## Current checkpoint — 2026-09-02

The earlier trust-integration work had been started but left incomplete around an obsolete one-root contract. The current work resumes it on the isolated branch:

`agent/trust-integration-poc`

Branch base / documented default-branch checkpoint:

`ab9b9abb09f30e5dcb665b681cd1fbc092954c1b`

Current implementation source-under-test before documentation-only follow-up:

`ba947ff81ccd49fb470f5316b0009dbc28ccbdd9`

The implementation checkpoint contains only the intended trust changes relative to the branch base:

- `.github/workflows/government-trust-packaging-preflight.yml` — converted from the stale one-root check to the exact two-root contract;
- `r3dfox/policies.json` — adds `Certificates.ImportEnterpriseRoots=true` and exactly two `Certificates.Install` entries;
- `r3dfox/moz.build` — stages both root certificates under `distribution/Certificates`;
- `browser/installer/package-manifest.in` — preserves both roots in the final package.

The temporary `apply-trust-integration-once.yml` bootstrap workflow used during branch setup has been removed. Repository edits are now made directly; GitHub Actions in this track are verification only.

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

`r3dfox/policies.json` now contains:

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

The inherited `r3dfox/config.cfg` still contains the pre-existing enterprise-root defaults. The current PoC deliberately does **not** duplicate the same trust switch through a second configuration mechanism.

The acceptance requirement is therefore behavioral, not a second static configuration assertion: after building the exact artifact, a clean-profile runtime test must prove that the active enterprise policy produces the required effective browser trust behavior and effective preference state. If the inherited AutoConfig setting actually defeats or conflicts with the policy at runtime, that will be a concrete failure and `config.cfg` will then be changed with exact evidence.

This avoids changing both policy and AutoConfig speculatively before their real precedence/effective behavior is observed in the adapted browser.

## Build and package staging

`r3dfox/moz.build` now stages:

```text
distribution/Certificates/russian_trusted_root_ca_rsa.cer
distribution/Certificates/russian_trusted_root_ca_gost.cer
```

`browser/installer/package-manifest.in` now explicitly preserves the same two paths in the final portable package.

The manifest change was diff-checked after editing: the final net manifest difference is exactly two added certificate paths and no unrelated substitutions.

The policy change was also diff-checked: the final net policy difference is exactly the seven lines of the `Certificates` section and no unrelated search-engine or other policy changes.

## Fast trust preflight

`.github/workflows/government-trust-packaging-preflight.yml` is the low-cost static trust gate.

Current run under evaluation:

- workflow: `Government trust packaging preflight`;
- run ID: `33592606106`;
- job ID: `100129486191`;
- source-under-test: `ba947ff81ccd49fb470f5316b0009dbc28ccbdd9`;
- current state at documentation time: **in progress**.

Do not treat that run as passed until the exact job finishes successfully.

The updated gate verifies:

- `Certificates.ImportEnterpriseRoots=true`;
- `Certificates.Install` contains exactly the RSA and GOST root filenames;
- both source certificates exist as DER;
- exact SHA-256 for both roots;
- expected public subjects;
- self-signed root identity and `BasicConstraints: CA=TRUE`;
- `r3dfox/moz.build` stages both roots;
- `browser/installer/package-manifest.in` packages both roots.

The fast gate intentionally does not claim runtime policy effectiveness and does not prove final portable archive survival.

## Historical bootstrap failures — not trust evidence

Two temporary one-shot branch-bootstrap runs failed for infrastructure reasons only and must not be interpreted as certificate, policy, NSS or packaging failures:

- run `33590909408`, job `100124538722`, source/trigger `d2d8f0a22063d40881f9fa2f4928cf9a585fb8d1`: the helper performed an unnecessarily deep checkout and its eventual push was rejected after the branch had moved;
- run `33591700739`, job `100126850286`, source `668d0c9db56dd7b49de911924f9872a9911b3d32`: the helper produced the intended local trust commit, but GitHub rejected the push because the Actions token lacked permission to update workflow files.

The helper workflow is removed. Future source changes in this track are direct repository edits; Actions are used only as gates/tests.

## Remaining PoC work

1. Obtain a green result from the exact fast preflight source SHA and record its run/job/SHA.
2. Extend a real full-build/package workflow to verify both pinned hashes in `dist/bin/distribution/Certificates` and again in the extracted final portable archive.
3. Build the exact browser artifact only after the fast gate is green.
4. On a completely new profile verify `about:policies`, effective enterprise-root behavior and Windows-root import without manual NSS import.
5. Verify the target Russian RSA PKI path and the relevant GOST PKI path with the two-root contract and without bundling a Sub CA.
6. Bind the runtime result to exact source SHA, Actions run/job, artifact and browser binary hashes.
7. After the PoC is proven, transfer only the minimal audited trust diff back to `agent/gost-tls-poc`; do not merge the experimental branch history wholesale.

## Heavy package integration gate

The existing `.github/workflows/cryptopro-mozilla-packaging-smoke.yml` can be reused or adapted as a full Mozilla build/package survival proof because it already exercises real `dist/bin`, `mach package` and final portable extraction.

Historical relevant run `33076347741`, job `98531418338`, source `07c7c48419ca39952a57a53967c1bcabaa8384c1` is not current trust evidence. It completed build/package and later failed on an unrelated loose `r3dfox-bundle.js` assertion.

Before a heavy trust/package proof is accepted, require exact RSA/GOST certificate hashes in both `dist/bin/distribution/Certificates` and the extracted final portable archive. Keep this evidence separate from GOST MSSPI handshake and Windows loader-compatibility conclusions.

## Runtime acceptance gate

A full integrated build is accepted for this track only after a clean-profile exact-artifact test proves:

1. `about:policies` shows the `Certificates` policy active;
2. Windows-installed trusted roots are honored without manual NSS import;
3. the effective enterprise-root preference/state is compatible with the policy despite the inherited AutoConfig defaults;
4. both pinned portable root anchors are available to the packaged browser;
5. the target RSA and GOST PKI paths behave as required with the two roots and no explicitly bundled Sub CA;
6. exact source SHA, Actions run/job, artifact and relevant browser binary hashes are recorded.

## Boundary with GOST TLS

This work is ordinary Firefox/NSS + Windows trust-store integration for the adapted browser. It does **not** close the independent GOST TLS MSSPI server-verification blocker. MSSPI/SSPI/CryptoAPI verification requires its own exact-artifact GOST runtime evidence.

Likewise, a green trust preflight or successful browser package does not prove Windows XP/Vista/7 loader compatibility.
