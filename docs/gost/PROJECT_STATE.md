# r3dfox GOST TLS — Project State

Last updated: 2026-08-27

This file is the authoritative current technical synthesis. Detailed evidence is in `TEST_LOG.md` and immutable dated `TEST_LOG_*.md` volumes; forward work is in `TODO.md`; the restart-safe runtime sequence is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP branch is in `STAGE2_GIS_GMP.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default / active branch: `agent/gost-tls-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the working branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer r3dfox baseline.

## Architecture

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication.

Current constraints:

- allowlist: `R3DFOX_GOST_HOSTS`;
- TLS 1.2 / HTTP/1.1 PoC path;
- default GOST ciphers: `C100:C101:C102:FF85:0081`;
- coordinated Firefox client-auth picker is default;
- `R3DFOX_GOST_CLIENT_AUTH_MODE=legacy` remains a same-binary diagnostic fallback;
- explicit local thumbprint selection remains diagnostic only;
- current source makes `Session` the GOST picker default; positive Session state uses the existing in-memory remember path for the matching coordinated decision key, is shared across matching handshakes in the running browser process rather than scoped to one tab/window, stays isolated from a different GOST mTLS host, and is cleared by browser-process restart;
- explicit `Once` remains available and keeps the already-proven positive-only fanout lease with a 5-second idle lifetime; each successful reuse refreshes the idle expiry;
- the picker details field `Issued by` now uses the human-facing issuer common name when available, with full issuer DN only as fallback.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

## Confirmed GOST milestones

### Basic Treasury GOST HTTPS

- source `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`;
- main run `32710363486`, job `97380247020`, artifact `9518011746`.

Real Treasury HTTP CONNECT, GOST TLS 1.2 / `0xFF85`, protected HTTP application traffic and browser rendering are proven.

### Stage 1 explicit-selector Treasury mTLS

- source `f5d04896e17f91f58b6a137af823360f4718eb29`;
- main run `32751967162`, job `97510763210`.

A locally designated client certificate can be loaded by MSSPI/CryptoPro and completes real Treasury GOST TLS 1.2 / `0xFF85` mutual TLS plus authenticated application traffic. The concrete certificate identifier remains private.

## Current Stage 2 coordinated browser identity

Runtime-proven F1/F2/F3 baseline:

- source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea` (`fix(gost): harden coordinated client auth lifecycle`);
- short SSL compile run `33039013892`, job `98408139567`, success;
- authoritative main full build run `33039013849`, job `98408139479`, success;
- main release artifact `9636591432` (`r3dfox-gost-win64-release`);
- Win7 import-audit artifact `9636591757`;
- independent thunk-rs full-xul run `33039013822`, job `98408139313`, success;
- thunk browser artifact `9636047031`, diagnostics `9636048172`.

Artifact `9636591432` remains the authoritative browser for the completed F1/F2/F3, GIS GMP and explicit-Session runtime evidence below. The thunk artifact is independent Windows-compatibility evidence and is not GOST runtime proof.

Exact local binary preflight for main artifact `9636591432`:

- `r3dfox.exe` SHA-256 `ccd3ed44bc57345eb7821a949dd96a6b3c45c71b47f3a577da26fc1265481187`;
- `xul.dll` SHA-256 `8cee03269e18dff2bc48d5c25bef34a6c62c520908d937e3b3e4a03031d0ab68`.

The valid T1R/T1R-B, GIS GMP G1/G2/G3/G4, and explicit-Session S1/S1-B/S1-C evidence below is bound to this artifact. An earlier `t1r_error.zip` was later confirmed by the user to have been produced from an older browser build and is historical invalid-test evidence only.

Current picker UX/default build candidate:

- source `afbdad307f63e594d3715169d6e34235280dddaf` (`fix(gost): mark Session picker default in runtime logs`);
- changes: GOST-scoped picker default `Session`, explicit `Once` + 5-second positive lease unchanged, `Issued by` rendered from `issuerCommonName` with `issuerName` fallback, and callback registration logs include `picker_default=session`;
- short SSL compile run `33073577249`, job `98521835147`, **success** on exact `head_sha=afbdad307f63e594d3715169d6e34235280dddaf`;
- main full build run `33073577269`, job `98521835354`, still in progress on the same SHA at the time of this update;
- independent thunk-rs full build run `33073577260`, job `98521835116`, **success** on the same SHA; browser artifact `9652182123`, diagnostics artifact `9652183604`.

The short SSL gate proves compilation of the `security/manager/ssl` target for the new C++ source. The successful independent thunk run additionally proves full Firefox/xul build, package and current direct-import gate compatibility on the same source. Neither result by itself proves the JavaScript picker presentation, runtime default-Session behavior, real Windows 7 runtime compatibility, or GOST handshake success. Those require the completed main artifact and targeted runtime regression, with real Win7 execution remaining a separate compatibility gate.

A separate packaging-only localization experiment is now running from workflow commit `07c7c48419ca39952a57a53967c1bcabaa8384c1`: CryptoPro packaging run `33076347741`, job `98531418338`. That workflow requests Russian UI by default only inside its own working tree and builds a `ru + en-US` multi-locale portable package; it does not change the English-only main/thunk build workflows.

## Stage 2 coordinated runtime checkpoint

### F1 — close/shutdown client-auth lifecycle — CLOSED

T2R on artifact `9636591432` passed across three unanswered-picker timeout cycles:

- capture `t2r_timeout.zip` SHA-256 `88053089499fee19edf7506d4fe257567dcc688740741313ff9430749e84bba7`;
- inner log SHA-256 `261ddf9a4008c212f1ee5b5ec2213ab0fb3ee6e6a244e586987ff04a8de8d5`;
- 3 decisions created and removed;
- 3 pre-close waiter removals reaching zero waiters;
- 3 shutdown-time callbacks rejected with `reason=closing`;
- 3 abandoned UI callbacks rejected as stale;
- no shutdown-created orphan decision;
- zero `selected=0`, `0x80090326`, `0x0000054f`, or `MSSPI_X509_LOOKUP`.

Measured picker-to-close intervals were `32.576`, `37.420`, and `30.330 s`. Poll counts were `10,825`, `34`, and `21`; timeout-source attribution and first-cycle poll churn remain separate non-blocking work and do not reopen F1.

### F2 — positive default-`Once` fanout/scope — CLOSED on the runtime-proven baseline

T1R and T1R-B on source `ef1a7...`, run `33039013849`, job `98408139479`, artifact `9636591432` prove both sides of the tested default-`Once` behavior. The current source changes only the initial UI choice to Session; explicit `Once` still uses this same lease mechanism and must receive a targeted regression on the new artifact.

T1R capture:

- `t1r-current.zip` SHA-256 `1c75f484607a6e3eb95439275e2698098a04551689619f95f93f13ca890b248e`;
- inner log SHA-256 `9f77de380e9ebf9b98f2e7cf2d3c0d6eb03233eb7afed0d103b2ecbf49bc78c7`.

T1R proves one visible picker for one logical Treasury login, one positive lease store, seven lease reuses across sequential waves, and eight successful `lk-fzs.roskazna.ru` TLS 1.2 / `0xFF85` mTLS handshakes with `client_cert_loaded=1`. The protected personal cabinet loads and behaves normally.

T1R-B capture:

- `T1R-B-current.zip` SHA-256 `c2d018b8637467b4c1368bfa66399dd042d73b88c39c6de7bf07368c7524ea65`;
- inner `t1r-current.moz_log` SHA-256 `c30c9f61e008d8bdb321570373c1c5cf6f3bc9eaa9e980564d463d03e307686e`.

T1R-B stays in the same process (`Parent 6204`) and same browser context (`browser_id=14`). Generation 1 is last reused at `09:07:13.004 UTC`, nominally expires at `09:07:18.004`, and a real independent client-auth request at `09:09:44.169` creates fresh `decision=2` plus a new picker rather than reusing generation 1. This is `151.165 s` after the final reuse and `146.165 s` after nominal expiry. A new positive choice stores generation 2 at `09:09:46.616` and the new attempt completes GOST mTLS.

Whole T1R-B capture: 2 decisions, 2 picker requests, 2 positive lease stores, 11 generation-1 reuses, 14 successful login-host mTLS handshakes, and zero `selected=0`, `0x80090326`, `0x0000054f`, `MSSPI_X509_LOOKUP`, stale callbacks, or `E/GostTLS`.

Therefore the explicit `Once` mechanism has the intended attempt-local positive fanout semantics on the runtime-proven baseline: compatible waves within the idle lease reuse one user choice, while an independent post-expiry attempt asks again. F2's mechanism remains closed; the new artifact still needs a focused regression to prove no implementation regression from the UI-default change.

### F3 — generic GOST mTLS host scope — CLOSED

Current GIS GMP runtime on the same source/run/artifact closes the old Treasury-host-specific client-auth blocker.

Capture:

- `gis-g1-g2-g3.zip` SHA-256 `8bb1fd3cfb6773739f0c9b05fd31555eef4180d65ce0518d54a63c85691558ce`;
- inner `gis-g1.moz_log` SHA-256 `451ed230a972b19ec35c1edc8952d1b234366ac5775c7252e8e67a92a289f1b1`.

GIS-G1 proves on `portalgisgmp.cert.roskazna.ru`:

- generic coordinated client-certificate callback registration succeeds;
- the real server client-certificate request reaches the callback;
- current acceptable-CA count is `36`;
- candidate enumeration returns `1` policy-eligible certificate;
- one coordinated decision/picker is created.

GIS-G2 proves real application mTLS:

- the user selects the intended certificate with default `Once`;
- one positive lease is stored and four follow-on requests reuse it without further UI;
- five certificate-host handshakes complete as TLS 1.2 / `0xFF85`, state `0x00000000`, `client_cert_loaded=1`;
- all five reach `verify ok=1 status=0x00000000` under the current verification path;
- the user confirms the certificate-login/application flow succeeds.

GIS-G3 proves generic registration does not cause spurious UI: `pay.gov.ru` and `portalgisgmp.login.roskazna.ru` register the callback but issue zero client-certificate requests and complete their GOST handshakes with `client_cert_loaded=0`. The only client-auth requests and the only picker occur on the certificate endpoint.

Whole GIS capture has zero `selected=0`, `0x80090326`, `0x0000054f`, `MSSPI_X509_LOOKUP`, or `E/GostTLS`.

Therefore the old empty-client-Certificate / `0x80090326` GIS host-scope failure is closed on the current artifact. Final fail-closed server-trust closure remains mandatory.

### Explicit `Session` baseline and GIS-G4 cross-host isolation — COMPLETE

In-process Session / GIS-G4 capture:

- `session-current.zip` SHA-256 `6eccbf7d49e69a92d9634507b111759f096c4dee00a0313ec3d7c20017f5dec1`;
- inner `session-current.moz_log` SHA-256 `b3b2c8751e1f0cf66cfda73a1c068f609efb1692ade910b0d4ffcb42ff4905f8`;
- capture process: `Parent 6200`.

Treasury S1/S1-B evidence:

- first `lk-fzs.roskazna.ru` client-auth request at `11:36:28.521 UTC` creates decision `1` / one picker;
- user selects the intended certificate with explicit `Session`; resolution at `11:36:33.382` records `remember=2`;
- no Treasury `Once` lease is created for that choice;
- ten later client-auth requests for the same Treasury decision key are satisfied from `scope=session` without another picker;
- the eleven resulting `lk-fzs.roskazna.ru` handshakes all complete as TLS 1.2 / `0xFF85`, state `0x00000000`, `client_cert_loaded=1`;
- the user confirms the remembered Session choice remains effective while working across tabs and browser windows in the same running browser process.

The log's Treasury client-auth requests all carry `browser_id=14`; therefore the raw log formally proves process-level remembered reuse for repeated matching handshakes, while the tab/window topology is additionally user-observed rather than separately encoded by distinct browser IDs in that capture.

GIS-G4 is directly proven in the same process: after the Treasury Session decision exists, navigation to the different GOST mTLS endpoint `portalgisgmp.cert.roskazna.ru` produces a new client-auth request with `browser_id=17`, fresh decision `2`, and a fresh picker at `11:37:37.389 UTC`. The Treasury Session certificate is not silently applied cross-host. The user then selects `Once` for GIS GMP; generation `1` is stored and reused four times, and five GIS GMP certificate-host mTLS handshakes succeed.

S1-C restart-boundary capture:

- `session-current2.zip` SHA-256 `e32b71ca51d151e553ab82c321fd8f829270e09b6a8390f7fb3ea828af3a29e7`;
- inner `session-current.moz_log` SHA-256 `5b156cf0765c9aad3ceffeac6d1a845cea381f219ea168d59b318201b9f419b5`;
- new process `Parent 5112`, versus prior Session process `Parent 6200`.

In the new process, the first Treasury client-auth request at `12:05:43.453 UTC` has no old Session remembered hit, creates fresh decision `1`, enumerates one candidate and shows a fresh picker. After the user establishes a new explicit Session at `12:05:47.363` (`remember=2`), five later matching requests are served from `scope=session`; six Treasury mTLS handshakes complete successfully. No `Once` lease, sticky negative state, or GOST error appears.

Therefore S1/S1-B/S1-C prove the intended browser-process lifetime: positive Session reuse is shared across matching handshakes and user-visible tabs/windows within one running browser, does not cross to an independent GOST mTLS host, and is cleared by full browser-process restart.

## Immediate runtime / implementation order

1. **Picker UX/default build candidate — ACTIVE:** short SSL compile gate is green on source `afbdad...`; wait for main run `33073577269` to produce the authoritative new artifact, then run targeted exact-artifact regressions for default Session, same-process reuse, restart boundary, explicit Once, cross-host isolation, and the human-friendly `Issued by` presentation.
2. Continue explicit Cancel/no-certificate vs Abort, true Persistent/Permanent semantics, provider/media, picker UI, discovery and negative matrix.
3. Complete final server-trust closure.
4. Keep timeout-source/poll-churn attribution as separate non-blocking work.

Do not treat the successful short compile or independent thunk full build as GOST runtime proof. Do not repeat T1R/T1R-B, GIS-G1/G2/G3/G4, or the explicit-Session baseline on the old unchanged artifact merely for confirmation.

## Server trust — still mandatory

Positive Treasury server verification and peer-certificate acquisition have been demonstrated on earlier runtime sources, but final trust integration is not closed.

Required:

- fail closed if verification fails or status is nonzero;
- integrate Firefox temporary/permanent certificate overrides;
- positive browser-session verification cache keyed by exact server identity;
- valid Treasury positive case;
- wrong-hostname and untrusted/invalid-chain negative cases;
- no client private-key operation before server trust.

## Provider/private-key media evidence

Earlier source `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`, run `32844083378`, job `97789764275`, artifact `9567881847` proves:

- a certificate may remain in `CurrentUser\MY` while its CryptoPro private-key medium/container is unavailable;
- `CERT_KEY_PROV_INFO_PROP_ID` is binding metadata, not proof of live key availability;
- provider Cancel can fail only the current attempt with `SEC_E_NO_CREDENTIALS`;
- a later attempt can recover when the medium becomes available.

These scenarios need revalidation after the current client-decision/UX work.

## Windows Vista/7 compatibility — independent track

Current full-xul narrow YY/thunk-rs build/package/direct-import evidence for the Session-default source:

- source `afbdad307f63e594d3715169d6e34235280dddaf`;
- run `33073577260`, job `98521835116`, success;
- browser artifact `9652182123`;
- diagnostics artifact `9652183604`.

This supersedes source `ef1a7fdd...`, run `33039013822`, job `98408139313`, artifacts `9636047031` / `9636048172` as the newest full-xul build/package/direct-import evidence. It remains Windows-compatibility evidence and must not be interpreted as GOST runtime proof or real Win7 runtime proof.

Still open: full-Firefox msvcr14x integration, final direct/delay-load PE audit, real Win7 runtime without the copied compatibility bundle, broader Win7 runtime, and a separate exact GOST-on-Win7 milestone.

## Bundled government-system extensions — independent track

Current three-extension package checkpoint:

- source `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- full packaging run `32976571122`, job `98202641607`;
- packaged-browser artifact `9614275050`;
- evidence artifact `9614275551`.

The portable archive contains CryptoPro CAdES `1.2.14`, legacy Gosuslugi/IFCPlugin `1.2.8`, Gosplugin `1.3.43.0`, and the Russian-first content-language preference. Clean-profile discovery/enabled-state is proven for all three project extensions.

Current packaging experiment `33076347741` / job `98531418338`, source/workflow commit `07c7c48419ca39952a57a53967c1bcabaa8384c1`, adds a packaging-only Russian-default Firefox UI with `en-US` retained in the same multi-locale package. This experiment is in progress and has no success conclusion yet.

Still open: successful completion/runtime verification of this ru+en-US packaging experiment, CryptoPro functionality on the exact packaged artifact, native-component tests for IFCPlugin and Gosplugin, update behavior, and transfer/generalization of packaging gates.

## Separation of conclusions

- Build success != GOST handshake success.
- Coordinated runtime success != final server-trust closure.
- `client_cert_loaded=1` != private-key-use proof; completed mTLS is the proof.
- GOST runtime != Windows compatibility.
- Extension packaging != extension runtime, GOST runtime, or Win7 runtime.
- Docs HEAD != source-under-test SHA for an earlier binary.