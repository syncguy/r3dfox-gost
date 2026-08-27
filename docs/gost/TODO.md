# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog. Current synthesis is in `PROJECT_STATE.md`; exact runtime test sequencing/recovery is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP multi-host mTLS branch is in `STAGE2_GIS_GMP.md`; experiment evidence is in `TEST_LOG.md` and dated volumes.

## GOST TLS runtime — immediate

### 1. Fix coordinated client-auth close/shutdown lifecycle

Current blocker is proven by T2 on main artifact `9606431408`, source `860de8e38deed326b7fcd1c547e928c5b48c72a9`, run `32951903026` attempt 2, job `98130275465`.

Implement:

- mark the MSSPI/socket as closing before legacy close / `msspi_shutdown()`;
- refuse any client-cert callback for a closing handle before it can create/join a coordinated decision or open a dialog;
- defensively remove any waiter by preserved handle identity after legacy close returns;
- add concise decision/waiter/close lifecycle diagnostics;
- keep stale-callback protection;
- ensure timeout/load/socket teardown can never leave a reusable `Declined`/negative coordinated decision.

Do not retest the broken old artifact. After a fixing build, first run T2R from `STAGE2_RUNTIME_TEST_PLAN.md`: unanswered picker -> timeout/teardown -> F5/Try again/new login must produce a fresh picker.

### 2. Fix positive `Once` scope across one logical login

T1 proves concurrent single-flight already works, but one Treasury login spans sequential connection waves and currently asks three times.

Implement an attempt-local **positive-only `Once` fanout/lease**:

- one explicit `Once` selection may satisfy compatible follow-on waves of the same logical login/navigation attempt;
- next independent login asks again;
- do not change global Firefox remember defaults;
- do not convert `Once` to `Session`;
- never lease a decline, abort, zero-candidate result, internal failure, provider failure or server rejection;
- use lifecycle/generation ownership rather than an unbounded arbitrary cache.

After a fixing build, run T1R: successful Treasury login must complete real mTLS/application login with one visible picker for the logical attempt while all compatible live sockets receive the positive choice safely.

### 3. Generalize GOST mTLS client-auth beyond the Treasury Stage-1 host

GIS GMP runtime on the same main artifact `9606431408`, source `860de8e...`, run `32951903026` attempt 2, job `98130275465`, now confirms the earlier source diagnosis.

Capture `gost_pay.gov.ru.zip` (SHA-256 `2e9630e5d8048482ebc6a3d3ac0576db6af2c6b4e108c3c1de6ea4e30d99596b`; inner log SHA-256 `f32fd8bf7067dd487e79121faf467f1038906d91ed958df87c572aff991bc5ed`) proves:

- `pay.gov.ru` and `portalgisgmp.login.roskazna.ru` complete GOST TLS 1.2 / `0xFF85` successfully;
- certificate login really reaches `portalgisgmp.cert.roskazna.ru` at the network layer;
- that host sends a real TLS `CertificateRequest` with a non-empty acceptable-CA list containing 36 DER Distinguished Names in the captured handshake;
- current browser answers with an empty TLS client `Certificate` message on all three observed cert-host attempts;
- server returns fatal `handshake_failure` (`0x28`) and MSSPI reports primary `0x80090326`;
- no custom client-cert callback/issuer/candidate marker appears for that host.

Exact source still carries `kStage1MtlsHost = "lk-fzs.roskazna.ru"` and:

- registers `msspi_set_cert_cb(..., SelectStage1ClientCertificate)` only for that one host;
- rejects the Firefox client-auth callback when the current host differs from that one host.

Therefore F3 is now **runtime-confirmed**: the real GIS GMP server asks for client auth, but our Treasury-only callback scope prevents issuer collection, candidate filtering and the picker from running.

Implement F3:

- make the Firefox/MSSPI client-auth callback available for every already-selected/allowlisted GOST socket that actually receives a client-certificate request;
- remove the Treasury-only host rejection from the normal Firefox-UI/coordinated path;
- do not broaden backend selection beyond the existing GOST allowlist/session policy;
- do not automatically send a certificate; normal server `CertificateRequest` + Firefox selection/remember semantics still control client auth;
- keep decision isolation by actual host, port, OriginAttributes and acceptable-CA identity;
- keep the explicit `R3DFOX_GOST_CLIENT_CERT_THUMBPRINT` path narrow/diagnostic rather than silently making it a cross-site automatic selector;
- preserve the proven legacy A/B core as cleanly as practical;
- add host/callback/issuer-count/candidate-count lifecycle diagnostics.

The user's CA-policy hypothesis is now narrower: the old server list is known to be non-empty (36 DNs), but the old artifact never invokes our own candidate filter on this host. Do not change issuer matching until post-F3 GIS-G1 produces an actual candidate count.

Detailed GIS GMP design, runtime evidence and test branching are in `STAGE2_GIS_GMP.md`.

After F3 is built, run GIS-G1 only after the core coordinator regressions T2R/T1R. If candidate count is nonzero, continue to real GIS GMP mTLS. If candidate count is zero, stop and diagnose the actual server CA list / local chain matching before changing issuer policy.

### 4. Build gates for the next candidate

Prefer separable code changes for F1, F2 and F3, but one final candidate may contain all three to avoid redundant full builds.

Required gates:

1. short `GOST SSL compile check`;
2. authoritative main `GOST TLS PoC build`;
3. bind runtime evidence to the exact new source SHA/run/job/artifact.

The thunk-rs build remains a separate Windows-compatibility line and is not required as GOST runtime proof.

### 5. Continue Stage 2 runtime matrix after T2R/T1R pass

Follow `STAGE2_RUNTIME_TEST_PLAN.md` and `STAGE2_GIS_GMP.md` in order. Remaining groups:

- GIS GMP generic mTLS callback reachability, real acceptable-CA/candidate result and real GIS GMP mTLS login;
- explicit Cancel/no-certificate vs involuntary Abort;
- `Once`, explicit `Session`, explicit `Permanent`;
- missing-media/provider Cancel and recovery;
- long provider-media wait crossing the observed picker-timeout scale;
- Russian picker row/details rendering;
- dynamic `CurrentUser\MY` discovery and token-only/removable-media discovery;
- no acceptable cert / unsuitable cert / wrong cert / unavailable key / PIN-private-key failure / server rejection;
- issuer-aware validity/KU/EKU/private-key candidate policy;
- sensitive-log audit;
- final exact-build Treasury mTLS regression.

## GOST TLS security — mandatory Stage 2 server-trust closure

Complete fail-closed server verification:

- reject `verifyOk == 0`;
- reject any nonzero verification status;
- integrate Firefox temporary/permanent certificate overrides;
- positive browser-session verification cache keyed by exact server identity;
- prove valid Treasury hostname/chain succeeds;
- prove wrong hostname and invalid/untrusted chain fail;
- prove client private-key operations cannot occur before server trust.

Do not use a production verification bypass.

## GOST network coverage — later

After Stage 2 security/runtime closure:

- direct connection without proxy;
- HTTPS proxy / nested TLS;
- SOCKS lifecycle;
- proxy authentication/reconnect edge cases beyond the currently exercised HTTP CONNECT path.

## Final UX polish — later

After core GOST TLS is stable, evaluate transparent one-shot GOST discovery:

- explicit allowlist still enters MSSPI immediately;
- unknown host starts with NSS;
- only `SSL_ERROR_NO_CYPHER_OVERLAP` may authorize one MSSPI retry;
- no retry loops;
- only a successful, normally verified GOST connection becomes session-confirmed;
- discovery cache is process/session scoped and never bypasses trust/client-auth policy.

## Windows Vista/7 compatibility — independent

Open work:

1. integrate proven `msvcr14x + modern Rust/libstd + narrow YY-Thunks` into full Firefox/xul while preserving `/MD`;
2. audit final PE set for direct API-set/VCRUNTIME/known Win8+ imports;
3. fix/replay delay-load parser and classify guarded post-Win7 paths;
4. run the resulting portable browser on real Windows 7 without the copied compatibility bundle;
5. expand real Win7 runtime coverage;
6. run GOST TLS on Win7 as a separate exact-build/runtime milestone.

## Bundled government-system extensions — independent

Current packaged three-extension artifact `9614275050` is packaging-proven but not fully runtime-proven.

Next:

1. clean-profile discovery/enabled-state for all three bundled extensions;
2. re-check CryptoPro basic functionality on this exact package;
3. test legacy IFCPlugin with installed native host;
4. test Gosplugin with its local/native component;
5. generalize the historically CryptoPro-named packaging workflow to assert all three XPI + language pref;
6. transfer only proven shared packaging gates into the two main browser workflows;
7. later prove real version-to-version update behavior where a valid older/newer signed extension is available.

## Upstream base — deferred

Stay on r3dfox / Firefox 153. Do not migrate to Firefox 154 merely because upstream Mozilla has released it. Evaluate a newer base only after r3dfox itself publishes one and the user explicitly decides to upgrade.