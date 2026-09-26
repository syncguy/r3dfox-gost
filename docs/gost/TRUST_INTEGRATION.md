# Windows system roots + Russian Trusted Root CA integration

Status: **ACTIVE / ISOLATED TRUST-INTEGRATION POC NEXT**.

Track: browser/government-system packaging and ordinary Firefox/NSS trust integration. This is independent from GOST TLS MSSPI server verification and from Windows Vista/7/XP binary compatibility.

## Current checkpoint — 2026-09-02

The earlier trust-integration work was started but not completed. The repository retained a fast workflow and this design document, but both still described an obsolete one-root contract.

Current default-branch checkpoint before creating the isolated PoC branch:

- default/active branch: `agent/gost-tls-poc`;
- source checkpoint: `a258821f49df78a47bc2972e62d47c9d77b34e62`;
- two public root CA source files are now committed under `r3dfox/certificates/` as binary DER:
  - `russian_trusted_root_ca_rsa.cer`;
  - `russian_trusted_root_ca_gost.cer`;
- the RSA DER is the expected `Russian Trusted Root CA` and retains the previously pinned SHA-256 `d26d2d0231b7c39f92cc738512ba54103519e4405d68b5bd703e9788ca8ecf31`;
- the GOST root is also committed as DER and must receive its exact pinned SHA-256/identity gate before the PoC is considered complete;
- `r3dfox/policies.json` does not yet contain the required `Certificates` policy;
- `r3dfox/config.cfg` still disables enterprise/system roots through the inherited defaults;
- `r3dfox/moz.build` and `browser/installer/package-manifest.in` do not yet stage/package both roots;
- `.github/workflows/government-trust-packaging-preflight.yml` exists and auto-triggers on `r3dfox/certificates/**`, but it still implements the obsolete single-file `russian_trusted_root_ca.cer` contract and therefore must be updated before its result can be used as trust-integration evidence.

The certificate-source commit itself is intentionally inert with respect to browser runtime behavior. Active trust integration begins only when policy/preferences/build/package staging are changed.

## Runtime evidence that defines the product requirement

A prior clean-profile runtime experiment established that the r3dfox AutoConfig layer disables Windows enterprise/system roots by default through `security.enterprise_roots.enabled=false`. Manually enabling enterprise-root support caused Firefox to import/use the trusted Windows certificate stores and the previously untrusted Russian PKI site became trusted without manual NSS certificate import.

Separate manual testing also established the intended chain policy for this project: the Sub CA/intermediate is not required for the target behavior. Trust succeeds when the required root anchors are present and the enterprise/system-root settings are enabled. Therefore the product contract intentionally bundles the two root CAs only; do not add a Sub CA unless new concrete runtime evidence proves it is required.

## Required production contract

### 1. Firefox Enterprise Policy

`r3dfox/policies.json` must contain:

```json
"Certificates": {
  "ImportEnterpriseRoots": true,
  "Install": [
    "russian_trusted_root_ca_rsa.cer",
    "russian_trusted_root_ca_gost.cer"
  ]
}
```

`ImportEnterpriseRoots=true` is the primary integration mechanism. It makes Windows machine/user CA stores an explicit browser contract rather than relying on the inherited r3dfox default.

`Certificates.Install` provides the two pinned portable fallback trust anchors.

### 2. AutoConfig preferences

The production configuration must not contradict the policy. `r3dfox/config.cfg` must enable the relevant enterprise-root preferences:

```js
defaultPref("security.certerrors.mitm.auto_enable_enterprise_roots", true);
defaultPref("security.enterprise_roots.enabled", true);
```

The exact production comment around these preferences should describe Windows/enterprise roots or Russian PKI integration, not RSA only, because the portable bundle contains both RSA and GOST roots.

### 3. Bundled root anchors

Bundle exactly these two public root CA files:

- `r3dfox/certificates/russian_trusted_root_ca_rsa.cer`;
- `r3dfox/certificates/russian_trusted_root_ca_gost.cer`.

Both source files must remain binary DER and byte-for-byte pinned.

RSA root expected identity:

- common name: `Russian Trusted Root CA`;
- organization: `The Ministry of Digital Development and Communications`;
- self-signed root;
- `BasicConstraints: CA=TRUE`;
- validity approximately 2022-03-01 through 2032-02-27;
- SHA-256: `d26d2d0231b7c39f92cc738512ba54103519e4405d68b5bd703e9788ca8ecf31`.

GOST root requirements:

- preserve the exact DER committed in the source checkpoint;
- prove self-signed root / `BasicConstraints: CA=TRUE`;
- record and pin its exact SHA-256 and stable public X.509 identity in the updated preflight before accepting the PoC;
- do not infer its identity merely from the filename.

Do **not** bundle/install a Sub CA/intermediate. The current runtime requirement has already been proven without it.

### 4. Build and package staging

`r3dfox/moz.build` must stage both DER files into:

```text
distribution/Certificates/russian_trusted_root_ca_rsa.cer
distribution/Certificates/russian_trusted_root_ca_gost.cer
```

`browser/installer/package-manifest.in` must explicitly preserve both files in the final portable package.

## Isolated PoC branch and implementation plan

Continue this work on a dedicated branch created directly from the current default-branch trust-source checkpoint. Planned branch name:

`agent/trust-integration-poc`

Keep this branch limited to the trust-integration line. Do not mix Windows XP/WinRT/toolchain experiments or GOST MSSPI handshake changes into it.

Implementation order:

1. validate both committed DER files and pin exact SHA-256/X.509 identity for both roots;
2. update `r3dfox/policies.json` for `ImportEnterpriseRoots=true` and both `Certificates.Install` filenames;
3. enable the two enterprise-root preferences in `r3dfox/config.cfg`;
4. update `r3dfox/moz.build` to stage both roots;
5. update `browser/installer/package-manifest.in` to package both roots;
6. rewrite `.github/workflows/government-trust-packaging-preflight.yml` from the obsolete one-root contract to the exact two-root contract;
7. require the fast preflight to pass on an exact branch SHA before starting an expensive full browser build;
8. extend the heavy package integration gate to verify both exact certificate hashes in `dist/bin` and the final portable archive;
9. test the exact built artifact with a new clean profile and record the runtime result.

## Fast CI contract

`.github/workflows/government-trust-packaging-preflight.yml` is the intended low-cost trust integration gate. Its existing trigger on `r3dfox/certificates/**` is useful, but its implementation is currently stale and must not be treated as a pass/fail verdict on the new two-root design until updated.

The corrected fast gate must verify:

- both source DER files exist;
- both exact SHA-256 values match pinned expectations;
- both certificates parse as X.509;
- both are CA/root certificates with the expected public identities;
- `r3dfox/policies.json` contains `Certificates.ImportEnterpriseRoots=true`;
- `Certificates.Install` contains exactly the two intended root filenames;
- `r3dfox/config.cfg` enables both enterprise-root preferences;
- `r3dfox/moz.build` stages both roots into `distribution/Certificates`;
- `browser/installer/package-manifest.in` contains both final package paths;
- no Sub CA/intermediate is accidentally added to the explicit bundled trust-anchor set.

The automatic run started by the DER source commit is diagnostic only until the workflow itself is updated: it still expects `russian_trusted_root_ca.cer`, one old hash and one-root policy/package entries.

## Heavy package integration gate

The existing heavy integration workflow `.github/workflows/cryptopro-mozilla-packaging-smoke.yml` can be reused as a full Mozilla build/package survival proof because it already exercises real `dist/bin`, `mach package` and final portable extraction.

Historical relevant run:

- run `33076347741`;
- job `98531418338`;
- source-under-test `07c7c48419ca39952a57a53967c1bcabaa8384c1`.

That historical run completed the full Firefox build and package stages and failed later on an unrelated loose `r3dfox-bundle.js` assertion. It is not trust-certificate failure evidence and must not be rerun as if it tested current source.

Before using the heavy workflow as final trust/package proof:

- include `r3dfox/policies.json`, `r3dfox/config.cfg`, `r3dfox/certificates/**`, `r3dfox/moz.build` and `browser/installer/package-manifest.in` in the relevant trigger/contract;
- verify both exact certificate hashes in `dist/bin/distribution/Certificates`;
- verify both exact hashes again after extracting the final portable archive;
- keep certificate/package evidence separate from GOST MSSPI handshake conclusions.

## Runtime acceptance gate

After a full integrated build, use the mandatory exact-artifact discipline and a completely new profile. Require:

1. `about:policies` shows the `Certificates` policy active;
2. `security.enterprise_roots.enabled` is effectively true;
3. `security.certerrors.mitm.auto_enable_enterprise_roots` is effectively true;
4. a root trusted through the Windows certificate store is honored without manual NSS import;
5. the target Russian RSA PKI path is trusted with the RSA root contract;
6. the target GOST PKI path is trusted with the GOST root contract where applicable;
7. the same tests succeed without installing/bundling a Sub CA solely for convenience;
8. the exact browser source SHA, Actions run/job, artifact and relevant binary hashes are recorded with the result.

## Boundary with GOST TLS

This work closes ordinary Firefox/NSS + Windows trust-store integration for the adapted browser. It does **not** close the independent GOST TLS MSSPI server-verification blocker. MSSPI/SSPI/CryptoAPI verification must still be proven with its own exact-artifact GOST runtime evidence.

Likewise, a green trust preflight or successful browser package does not prove Windows XP/Vista/7 loader compatibility.

## Return-to-main rule

Do not merge experimental noise merely because the PoC builds. Once the fast gate and runtime/package acceptance are proven, transfer the minimal proven trust integration back to `agent/gost-tls-poc` as a small auditable change set. The two DER root source files are already present in the default branch and therefore do not need to be reintroduced from the experiment branch.
