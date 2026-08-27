# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog. Current synthesis is in `PROJECT_STATE.md`; exact runtime test sequencing/recovery is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP multi-host mTLS branch is in `STAGE2_GIS_GMP.md`; experiment evidence is in `TEST_LOG.md` and dated volumes.

## GOST TLS runtime — immediate

F1 close/shutdown lifecycle, F2 positive default-`Once` fanout/scope, and F3 generic GOST mTLS host scope are formally closed on source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`, main run `33039013849`, job `98408139479`, artifact `9636591432`.

The passing GIS GMP capture is `gis-g1-g2-g3.zip` SHA-256 `8bb1fd3cfb6773739f0c9b05fd31555eef4180d65ce0518d54a63c85691558ce`; inner log SHA-256 `451ed230a972b19ec35c1edc8952d1b234366ac5775c7252e8e67a92a289f1b1`. GIS-G1/G2/G3 prove generic callback reachability, current CA count `36`, one valid candidate/picker, five successful certificate-host GOST mTLS handshakes, application success, and no spurious picker on the two non-mTLS GOST hosts.

Do not repeat T1R/T1R-B or GIS-G1/G2/G3 on unchanged source merely for confirmation.

### 1. Baseline `Session` semantics and prepare the picker UX/default change

Before changing the default, the current artifact can prove explicit `Session` semantics by manually choosing `Session` in the Firefox picker:

- **S1:** first Treasury login shows one picker; choose `Session`; protected login succeeds;
- **S1-B:** an independent matching login in the same browser process should reuse the positive Session decision without a new picker;
- **S1-C:** after closing and restarting the browser process, the Session decision must be gone and a fresh picker must appear.

This tests semantics only; it does not prove `Session` is the UI default.

Planned code/UX change after the baseline:

- make `Session` the default remember choice for the picker;
- preserve explicit `Once` and the proven positive-only short fanout lease;
- keep the current 5-second idle lease behavior for now, with later consideration of an `about:config` preference rather than hard-wiring future policy;
- render `Issued by` using a human-friendly issuer display in the same spirit as the already-improved `Issued to`, rather than exposing the full raw DN in the primary details row;
- run targeted exact-build regressions for default Session plus explicit Once after the change.

### 2. GIS-G4 — cross-host decision isolation

The real GIS GMP host-scope defect is closed, but cross-host remember/decision isolation remains worth proving explicitly.

At minimum:

- a Treasury `Once` choice must never silently apply to `portalgisgmp.cert.roskazna.ru`;
- host/port/OriginAttributes/acceptable-CA identity isolation must remain intact;
- if `Session` or `Permanent` is tested on both hosts, each host must follow the intended Firefox remember semantics without credential leakage across origins.

### 3. Continue the remaining Stage 2 runtime matrix

Follow `STAGE2_RUNTIME_TEST_PLAN.md` after the immediate Session/UX and GIS-G4 work. Remaining groups include:

- explicit Cancel/no-certificate vs involuntary Abort;
- explicit `Session` and `Permanent` semantics beyond the initial S1 baseline;
- missing-media/provider Cancel and recovery;
- long provider-media wait using measured current-artifact timeout behavior;
- Russian picker row/details rendering;
- dynamic `CurrentUser\MY` discovery and token-only/removable-media discovery;
- no acceptable cert / unsuitable cert / wrong cert / unavailable key / PIN-private-key failure / server rejection;
- issuer-aware validity/KU/EKU/private-key candidate policy;
- sensitive-log audit;
- final exact-build Treasury mTLS regression.

### 4. Attribute picker timeout and residual poll churn

T2R proved lifecycle safety but also showed non-uniform timeout/poll behavior:

- picker-to-close intervals: `32.576 s`, `37.420 s`, `30.330 s`;
- `GostPoll client-auth wait quiescent`: `10,825`, `34`, and `21` calls respectively.

The first cycle still has substantial polling churn (~332/s), while later cycles are near one call per second. Before changing timeout policy or calling the wait path fully quiescent:

- identify which Firefox/Necko/load timer actually tears down each attempt;
- explain why the first cycle polls much more aggressively than later cycles;
- preserve stock-compatible timeout semantics rather than introducing an arbitrary GOST-specific timeout.

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

Current packaged three-extension artifact `9614275050` is packaging-proven and clean-profile discovery/enabled-state is proven for all three bundled project extensions.

Next:

1. re-check CryptoPro basic functionality on this exact package;
2. test legacy IFCPlugin with installed native host;
3. test Gosplugin with its local/native component;
4. verify the Russian-first content-language preference in runtime if desired;
5. generalize the historically CryptoPro-named packaging workflow to assert all three XPI + language pref;
6. transfer only proven shared packaging gates into the two main browser workflows;
7. later prove real version-to-version update behavior where a valid older/newer signed extension is available.

## Upstream base — deferred

Stay on r3dfox / Firefox 153. Do not migrate to Firefox 154 merely because upstream Mozilla has released it. Evaluate a newer base only after r3dfox itself publishes one and the user explicitly decides to upgrade.