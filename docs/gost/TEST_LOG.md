# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-09-02_pre_trust_package_closure.md`](./TEST_LOG_2026-09-02_pre_trust_package_closure.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); formally closed milestones are in [`DONE.md`](./DONE.md); the mandatory Windows XP x86 build/dependency contract is in [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-09-02 — corrected full trust-package retry passes real dist/bin and final portable root gates

Track: Firefox/NSS + Windows trust + bundled Russian root CAs + final portable packaging only. This is not GOST TLS MSSPI handshake evidence and not Windows XP/Vista/7 compatibility evidence.

Exact project/build identity:

- branch `agent/trust-integration-poc`;
- source-under-test `e7640a8195c6f10d8e909ad620ace74fa08c2c86`;
- workflow `CryptoPro Mozilla packaging smoke`;
- Actions run `33595966569`, attempt 2;
- job `100141282134` (`Windows x64 / CryptoPro real Firefox packaging / ru + en-US`);
- run/job conclusion: **success**.

Exact artifacts:

- packaged browser artifact `9838528394` (`r3dfox-cryptopro-mozilla-packaging-ru-en-US`), digest `sha256:8341f2a4c11a3aeaf088f4fb46655bef405014ca4e9f47132640545d52784354`;
- packaging evidence artifact `9838528813` (`cryptopro-mozilla-packaging-evidence`), digest `sha256:e89f134877ecbba92e04782dddc13edd5b3981db64b1687c186f47c4ff2d3d09`.

Observed green boundaries in the exact job:

- full release Firefox build — **PASS**;
- CryptoPro XPI plus both pinned Russian trust roots in real `dist/bin` — **PASS**;
- exact trust-root hash checks in real `dist/bin` — **PASS**;
- production Russian localization merge — **PASS**;
- `ru + en-US` multi-locale package — **PASS**;
- CryptoPro XPI, both trust roots, exact root hashes and substantive ru/en-US UI in the extracted final portable archive — **PASS**;
- packaged-browser upload — **PASS**;
- packaging-evidence upload — **PASS**.

The source-under-test is the narrow repair commit that only reorders the two `FINAL_TARGET_FILES.distribution.Certificates` entries into Mozilla-required lexical order. It supersedes the failed predecessor source `b2184aa0c7c95a47a35c7010248953902500daf3`, run `33594665980`, job `100135594681`, which failed during configure before `mach build` because the certificate staging list was unsorted.

Conclusion: **PASS / FULL PACKAGE TRUST-STAGING GATE CLOSED.** The two pinned public root files survive byte-for-byte through the real Firefox build output and final portable package while the existing CryptoPro and localization gates remain green. The previous `StrictOrderingOnAppendList` failure is no longer an active blocker.

This result does **not** prove runtime policy effectiveness. The next exact boundary is a clean-profile launch of artifact `9838528394` proving `about:policies`, effective `security.enterprise_roots.enabled`, Windows-root import without manual NSS import, availability of the two bundled anchors, and the intended RSA/GOST PKI behavior without explicitly bundling a Sub CA. This package result also does not close MSSPI/SSPI GOST server verification or old-Windows runtime compatibility.

---

## 2026-09-02 — Win7 SP1 x64 exact-artifact ordinary NSS Russian RSA trust smoke passes

Track: Firefox/NSS + Windows trust + bundled Russian root CAs. This is ordinary HTTPS/NSS trust evidence for the trust-integration branch, not GOST TLS MSSPI/SSPI handshake evidence and not a general Windows XP/Vista/7 compatibility conclusion.

Exact build/runtime identity:

- branch `agent/trust-integration-poc`;
- source-under-test `e7640a8195c6f10d8e909ad620ace74fa08c2c86`;
- workflow `CryptoPro Mozilla packaging smoke`;
- Actions run `33595966569`, attempt 2;
- job `100141282134`;
- packaged-browser artifact `9838528394`;
- runtime OS `Microsoft Windows [Version 6.1.7601]` = Windows 7 SP1;
- runtime directory reported as `C:\1\r3dfox-v153.0.3.win64.portable`.

Package-side reference hashes derived directly from artifact `9838528394` and local runtime hashes supplied by the user are identical:

- `r3dfox.exe` SHA-256 package/runtime `a439940ba92e70f14b1997f7d82e5beceb2ef6aa4517c21ca9001311cfa13aa7` — **MATCH**;
- `xul.dll` SHA-256 package/runtime `8ebda2b3337e2fe9c88a7191885e509d55fb1fa2cbb3c5ca54e1df4be8b323d6` — **MATCH**.

The exact binary-identity portion of the runtime preflight is therefore closed for this smoke.

Runtime environment and launch reported by the user:

- `R3DFOX_GOST_HOSTS=lk.zakupki.gov.ru`;
- client-certificate thumbprint override cleared;
- client-auth mode override cleared;
- cipher override cleared;
- profile path `C:\Temp\r3dfox\profile`;
- launch URL `https://zakupki.gov.ru/epz/main/public/home.html`.

Sanitized observed evidence:

- `about:policies` shows the `Certificates` policy in the **Active** section with `ImportEnterpriseRoots=true` and both `Install` entries, `russian_trusted_root_ca_rsa.cer` and `russian_trusted_root_ca_gost.cer`;
- the main EIS procurement page at `zakupki.gov.ru` loads successfully over HTTPS;
- the Firefox certificate viewer shows the server leaf `*.zakupki.gov.ru`, issued by `Russian Trusted Sub CA`, chaining to `Russian Trusted Root CA`;
- the tested main host is `zakupki.gov.ru`, while the GOST allowlist token supplied for this launch is `lk.zakupki.gov.ru`, so this main-page result belongs to the ordinary Firefox/NSS trust path rather than the allowlisted MSSPI GOST transport;
- no explicitly bundled Sub CA/intermediate is part of the two-root package contract, yet the observed RSA server chain builds through `Russian Trusted Sub CA` to the bundled Russian RSA root and the page renders without a certificate error.

Conclusion: **PASS / EXACT-ARTIFACT RUSSIAN RSA NSS RUNTIME SMOKE GREEN.** This is concrete runtime evidence on Windows 7 SP1 x64 that the tested browser binaries are byte-for-byte the expected artifact payload, the packaged `Certificates` policy is active, and the target Russian RSA PKI path is usable without explicitly bundling the Sub CA.

---

## 2026-09-02 — clean-profile policy precedence confirmed; Firefox/NSS trust-integration PoC accepted complete

Track: Firefox/NSS + Windows trust + bundled Russian root CAs. This closes the trust-integration PoC only; it does not close MSSPI/SSPI GOST server verification or the broader legacy-Windows compatibility track.

Exact runtime identity remains:

- branch `agent/trust-integration-poc`;
- source-under-test `e7640a8195c6f10d8e909ad620ace74fa08c2c86`;
- Actions run `33595966569`, attempt 2;
- job `100141282134`;
- packaged-browser artifact `9838528394`;
- runtime OS Windows 7 SP1 x64 (`6.1.7601`);
- `r3dfox.exe` SHA-256 `a439940ba92e70f14b1997f7d82e5beceb2ef6aa4517c21ca9001311cfa13aa7` — exact artifact match;
- `xul.dll` SHA-256 `8ebda2b3337e2fe9c88a7191885e509d55fb1fa2cbb3c5ca54e1df4be8b323d6` — exact artifact match.

Additional runtime evidence supplied by the user:

- the profile is newly created before every launch, including this test sequence;
- `about:config` shows `security.enterprise_roots.enabled` with status **locked**, type `boolean`, value **true**;
- therefore the active `Certificates.ImportEnterpriseRoots=true` enterprise policy wins over the inherited AutoConfig `defaultPref(..., false)` and locks the effective runtime preference to `true`;
- the previously supplied `about:policies` evidence shows the `Certificates` policy active with both pinned RSA/GOST `Install` entries;
- the exact same clean-profile browser successfully validates and renders the ordinary NSS RSA chain `*.zakupki.gov.ru -> Russian Trusted Sub CA -> Russian Trusted Root CA` without an explicitly bundled Sub CA.

Conclusion: **PASS / FIREFOX-NSS TRUST-INTEGRATION POC COMPLETE.** The project accepts this exact clean-profile Win7 SP1 x64 evidence as the runtime acceptance closure for the two-root packaging/policy design. No `config.cfg` change is required: enterprise policy precedence is directly proven by the locked `true` runtime preference.

Separate Windows-store-only isolation and a separate browser-side GOST-root website probe are no longer acceptance blockers for this packaging/NSS integration milestone. The two pinned root files are package/hash-proven and present in the active policy; the RSA path is functionally proven. Any future GOST TLS server-verification conclusion remains exclusively in the independent MSSPI/SSPI/CryptoPro track and must not be inferred from this closure.

Next product action is not another trust PoC experiment: transfer only the minimal audited trust diff from `agent/trust-integration-poc` into `agent/gost-tls-poc`, preserving the exact two-root contract and the proven policy behavior. Do not merge the experimental branch history wholesale.

---
