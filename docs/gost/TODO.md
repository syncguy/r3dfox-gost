# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog. Current synthesis is in `PROJECT_STATE.md`; exact runtime test sequencing/recovery is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP multi-host mTLS branch is in `STAGE2_GIS_GMP.md`; experiment evidence is in `TEST_LOG.md` and dated volumes.

## GOST TLS runtime — immediate

F1 close/shutdown lifecycle, F2 positive default-`Once` fanout/scope, F3 generic GOST mTLS host scope, GIS-G4 cross-host decision isolation, and the explicit positive `Session` lifetime baseline are closed on source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`, main run `33039013849`, job `98408139479`, artifact `9636591432`.

Do not repeat T1R/T1R-B, GIS-G1/G2/G3/G4, or S1/S1-B/S1-C on unchanged source merely for confirmation.

### 1. Validate the Session-default picker build

The planned picker UX/default iteration is implemented and fully built on:

- source `afbdad307f63e594d3715169d6e34235280dddaf` (`fix(gost): mark Session picker default in runtime logs`);
- short SSL compile run `33073577249`, job `98521835147`, success;
- authoritative main full build run `33073577269`, job `98521835354`, success;
- main release artifact `9652941006` (`r3dfox-gost-win64-release`);
- main Win7 import-audit artifact `9652941552`;
- independent thunk-rs full build run `33073577260`, job `98521835116`, success.

Implemented behavior to regress on exact artifact `9652941006`:

- `Session` is the default remember choice;
- explicit `Once` remains available and keeps the proven positive-only 5-second idle fanout lease;
- `Issued by` uses a human-friendly issuer common name when available, with full issuer DN only as fallback;
- callback registration logs expose `picker_default=session`.

Run these targeted regressions before proceeding deeper into the remaining matrix:

1. default Session first Treasury login: one picker, successful GOST mTLS/application login;
2. same-process matching reuse across later connections/windows/tabs: no second picker;
3. full browser-process restart: fresh picker;
4. explicit Once: preserve short positive fanout and fresh picker after idle expiry;
5. different GOST mTLS host: no cross-host remembered-decision leakage;
6. picker presentation smoke: Session visibly selected by default and `Issued by` is human-readable.

The current source routes every non-`Once` positive choice through the same in-memory remember store. Therefore real persistent `Permanent` semantics remain a separate implementation/test item; do not assume the current `Permanent` UI choice survives process restart until that is explicitly implemented and proven.

### 2. Continue the remaining Stage 2 runtime matrix

Remaining groups include:

- explicit Cancel/no-certificate vs involuntary Abort;
- full `Permanent` semantics;
- missing-media/provider Cancel and recovery;
- long provider-media wait using measured current-artifact timeout behavior;
- Russian picker row/details rendering;
- dynamic `CurrentUser\MY` discovery and token-only/removable-media discovery;
- no acceptable cert / unsuitable cert / wrong cert / unavailable key / PIN-private-key failure / server rejection;
- issuer-aware validity/KU/EKU/private-key candidate policy;
- sensitive-log audit;
- final exact-build Treasury mTLS regression.

### 3. Attribute picker timeout and residual poll churn

T2R proved lifecycle safety but also showed non-uniform timeout/poll behavior:

- picker-to-close intervals: `32.576 s`, `37.420 s`, `30.330 s`;
- `GostPoll client-auth wait quiescent`: `10,825`, `34`, and `21` calls respectively.

Before changing timeout policy or calling the wait path fully quiescent:

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