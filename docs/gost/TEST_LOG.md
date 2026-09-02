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
