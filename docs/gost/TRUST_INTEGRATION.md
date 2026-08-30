# Windows system roots + Russian Trusted Root CA integration

Status: **MANDATORY BEFORE THE NEXT FULL BROWSER BUILD AFTER THE LEGACY RNG PoC**.

Track: browser/government-system packaging and ordinary NSS trust integration. This is independent from GOST TLS MSSPI server verification and from the Windows compatibility/RNG implementation itself.

## Why this is mandatory

A prior clean-profile runtime experiment established that the r3dfox AutoConfig layer disables Windows enterprise/system roots by default through `security.enterprise_roots.enabled=false`. Manually enabling `security.enterprise_roots.enabled=true` on a clean profile caused Firefox to import/use the trusted Windows certificate stores and the previously untrusted Russian PKI site became trusted without manual NSS certificate import.

The latest Windows x86 compatibility build must not be treated as product-complete merely because it starts on Win7, contains GOST TLS, and passes loader/runtime compatibility gates. Before the next expensive integrated browser build, the project must restore the already-agreed trust configuration below.

## Required production contract

1. `r3dfox/policies.json` must explicitly contain Firefox Enterprise Policy:

   ```json
   "Certificates": {
     "ImportEnterpriseRoots": true,
     "Install": [
       "russian_trusted_root_ca.cer"
     ]
   }
   ```

   `ImportEnterpriseRoots=true` is the primary mechanism. It makes Windows machine/user CA stores an explicit browser contract instead of relying on the current r3dfox AutoConfig default.

2. Bundle exactly one fallback trust anchor: **Russian Trusted Root CA** / Ministry of Digital Development and Communications.

   Required certificate SHA-256:

   `d26d2d0231b7c39f92cc738512ba54103519e4405d68b5bd703e9788ca8ecf31`

   Expected identity from the previously inspected DER:

   - subject/common name: `Russian Trusted Root CA`;
   - organization: `The Ministry of Digital Development and Communications`;
   - self-signed root;
   - `BasicConstraints: CA=TRUE`;
   - validity approximately 2022-03-01 through 2032-02-27.

3. Do **not** bundle/install the intermediate certificate unless a future concrete site/runtime failure proves it is required. The prior runtime result showed that enabling system roots plus the root certificate is sufficient; installing an intermediate with `Certificates.Install` would unnecessarily promote it to explicit NSS trust.

4. Package the DER as a portable browser resource under:

   `distribution/Certificates/russian_trusted_root_ca.cer`

   The source file should live under the r3dfox source tree and be copied by `r3dfox/moz.build`; `browser/installer/package-manifest.in` must explicitly allow it into the final package.

## Required CI gates

A fast trust/packaging smoke must verify before the next full browser build:

- source DER exists and SHA-256 equals `d26d2d0231b7c39f92cc738512ba54103519e4405d68b5bd703e9788ca8ecf31`;
- certificate parses as DER X.509;
- it is a CA/root and matches the expected public identity;
- `r3dfox/policies.json` contains `Certificates.ImportEnterpriseRoots=true`;
- `Certificates.Install` contains exactly the intended bundled root filename for this integration;
- `r3dfox/moz.build` stages the root into `distribution/Certificates`;
- `browser/installer/package-manifest.in` includes the root path;
- the full packaging workflow later proves exact SHA equality in `dist/bin/distribution/Certificates` and in the final portable archive.

The packaging workflow path triggers must include at least:

- `r3dfox/policies.json`;
- the bundled certificate source path/directory;
- `r3dfox/moz.build`;
- `browser/installer/package-manifest.in`.

## Runtime acceptance gate

After the integrated build, use a completely new profile and verify:

1. `about:policies` shows the certificate policy active;
2. `security.enterprise_roots.enabled` is true/policy-controlled;
3. a Windows-installed trusted root is automatically honored without manual NSS import;
4. the Russian PKI site used in the previous clean-profile experiment is trusted with only the root requirement above;
5. no intermediate has been promoted to a trust anchor merely for convenience.

## Boundary with GOST TLS

This work closes ordinary Firefox/NSS + Windows trust-store integration for the adapted browser. It does **not** close the independent GOST TLS MSSPI server-verification blocker. MSSPI/SSPI/CryptoAPI trust behavior must still be proven with its own GOST runtime evidence.

## Ordering

Current work remains the isolated `agent/legacy-rng-poc` experiment. Do not interrupt that line with a full browser build for this trust work.

Required sequence:

`legacy RNG PoC -> trust integration + fast packaging smoke -> integrate proven WinRT/XP/RNG/trust changes -> next full browser build -> clean-profile trust runtime regression + Win7/XP compatibility runtime`.

The next expensive full browser build is blocked until this trust contract is implemented and its fast static/packaging preflight is green.
