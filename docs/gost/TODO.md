# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog. Current synthesis is in `PROJECT_STATE.md`; exact runtime test sequencing/recovery is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP multi-host mTLS branch is in `STAGE2_GIS_GMP.md`; the WinRT source-removal alternative is in `WINRT_SOURCE_POC.md`; Windows XP compatibility architecture/import triage is in `XP_COMPATIBILITY_STRATEGY.md`; the mandatory XP x86 build/dependency contract is in `XP_BUILD_CONTRACT.md`; experiment evidence is in `TEST_LOG.md` and dated volumes.

## GOST TLS runtime — immediate

F1 close/shutdown lifecycle, F2 positive `Once` fanout/scope, F3 generic GOST mTLS host scope, GIS-G4 cross-host decision isolation, explicit positive `Session` lifetime, the SD1-SD6 Session-default exact-artifact regression, T3 explicit Cancel/no-certificate semantics, T4 involuntary tab/load Abort semantics, T7/T8 missing-medium/provider recovery, the T9 long-provider-wait characterization, and T10 detailed Russian picker presentation are closed as experiments.

Current Session-default runtime evidence is source `afbdad307f63e594d3715169d6e34235280dddaf`, main run `33073577269`, job `98521835354`, artifact `9652941006`. Do not repeat closed tests on unchanged source merely for confirmation.

### 1. Continue client-decision / provider semantics

Immediate next:

1. **T6 — real Permanent semantics.** Implement and prove persistence distinct from the current process-local non-Once store, including intended process-restart persistence and the intended forget/change behavior.
2. **T11/T12 — discovery boundary.** Verify dynamic `CurrentUser\MY` re-enumeration and determine whether provider/removable-media-only identities are discoverable without browser restart or interactive provider/PIN/media UI during candidate enumeration.

**T5 — Session failure-boundary regression is DEFERRED, not closed.** The 2026-08-28 T5 probe showed that removing the key medium *after* a successful Treasury Session mTLS does not create a provider failure: CryptoPro/SSPI retains an already-acquired credential context, and a fresh Treasury socket about 192 seconds later still receives a new CertificateRequest, reuses `scope=session`, emits a client-auth flight and completes TLS 1.2 / `0xFF85` mTLS. Therefore post-login medium removal is not a valid T5 fault injection in the current environment. Resume T5 only when there is a safe deterministic way to invalidate an already-acquired provider/private-key credential inside the same browser process; do not invent an invasive synthetic invalidation merely to force the test.

T7/T8 prove the complementary pre-acquisition boundary on the current artifact: with the certificate still discoverable from `CurrentUser\MY` but the key medium unavailable before first private-key acquisition, provider refusal produces `SEC_E_NO_CREDENTIALS` only for that MSSPI attempt; the positive Firefox `Session` decision survives, and after the medium returns the next request in the same browser process reuses `scope=session`, completes GOST mTLS and resumes protected application traffic without another picker.

T9 now proves the long-wait concurrency boundary. A positive Treasury Session selection entered the synchronous CryptoPro/SSPI provider path for `74.742 s`. The Firefox UI remained responsive by user observation, but the shared Firefox Socket Thread produced no `GostTLS` activity during that interval. When the provider action was cancelled, `SEC_E_NO_CREDENTIALS` returned and queued network work resumed immediately: `pay.gov.ru` began on the same timestamp and completed GOST TLS `291 ms` later. The later Treasury flow still reused `scope=session` and recovered successfully. Thus timeout/coordinator state remains safe, but **global Socket Thread network starvation during synchronous provider UI is a confirmed behavior**.

T10 closes the detailed picker presentation on the current artifact: human-readable owner/issuer presentation, correct Cyrillic and localized expiry, readable details, serial details-only, all three remember choices visible, and `Session` visibly selected by default. The successful post-inspection Treasury login is only a functional smoke; T10 does not imply real `Permanent` persistence.

T3/T4 establish the negative-decision split on the current artifact: explicit picker Cancel is consumed as Declined/phase `2`, while an unanswered picker abandoned by tab/load teardown remains unresolved phase `0` and is removed by lifecycle cleanup. Neither path poisons later recovery.

The current source routes every non-`Once` positive choice through the same in-memory remember store. Therefore real persistent `Permanent` semantics remain unproven; do not assume the current `Permanent` UI choice survives process restart.

### 2. Provider-wait Socket Thread isolation follow-up

T9 failed the intended no-network-starvation subcriterion: while CryptoPro/provider key access was synchronously blocked for `74.742 s`, new network work from other browser windows/tabs queued behind the same Firefox Socket Thread and started only when the provider call returned.

Open follow-up:

- compare this behavior with stock Firefox synchronous client-certificate/token/PIN handling before declaring it an incompatibility;
- determine whether MSSPI/CryptoPro key-access can be moved off the shared Socket Thread without breaking NSPR/MSSPI state ownership, client-auth lifecycle, cancellation, or proxy/CONNECT sequencing;
- do not redesign threading merely from intuition: preserve the exact T9 capture as the concrete baseline and require a focused implementation experiment if offloading is attempted;
- treat this as a responsiveness/performance limitation, not as evidence of a failed GOST handshake or broken UI event loop.

### 3. Continue the remaining Stage 2 runtime matrix

Remaining groups include:

- T5 deterministic failure-boundary test once an already-acquired provider credential can be invalidated safely;
- dynamic `CurrentUser\MY` discovery and token-only/removable-media discovery;
- no acceptable cert / unsuitable cert / wrong cert / unavailable key / PIN-private-key failure / server rejection;
- issuer-aware validity/KU/EKU/private-key candidate policy;
- sensitive-log audit;
- final exact-build Treasury mTLS regression.

### 4. Attribute picker timeout and residual poll churn

T2R and the T3 timeout segment both show lifecycle-safe but non-fixed picker teardown timing. T2R measured `32.576 s`, `37.420 s`, `30.330 s`; T3 measured one additional unanswered-picker removal after `30.276 s`. T4 is deliberately different: closing the owning tab removed the pending decision after only `4.059 s`, confirming that its teardown was user/load driven rather than timeout driven.

T9 is also distinct from those Firefox-picker timeouts: after the Firefox certificate decision had already resolved, the Socket Thread remained synchronously inside provider/key acquisition for `74.742 s` until provider Cancel. No automatic ~30-second picker teardown occurred in that state.

Before changing timeout policy or calling the wait path fully quiescent:

- identify which Firefox/Necko/load timer actually tears down each timed-out *Firefox picker* attempt;
- keep that lifecycle separate from the T9 provider/key-access wait;
- explain why the first historical picker-timeout cycle polls much more aggressively than later cycles;
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

## Windows compatibility — independent

Current detailed handoff for the physical Windows XP SP3 x86 startup/runtime-closure line is [`XP_RUNTIME_COMPATIBILITY_STATUS.md`](./XP_RUNTIME_COMPATIBILITY_STATUS.md). Read it before proposing another XP patch.

The current mandatory build/dependency contract remains [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md). Preserve all already-proven dependency families while advancing one owner/component at a time.

### Current exact boundary

Latest completed full XP x32 browser:

- branch `agent/winrt-source-poc`;
- source-under-test / implementation HEAD `622a87625036e9c45a8650264336eceeb9be8753` (`fix(xp): restore Rust target expression`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `33864176444`, attempt `1`;
- job `100995134125`;
- package artifact `9937354583`, digest `sha256:9457e3d5102bd60caa4f1cdf23a432fa21444efdd34054e688c1a8f507dc5e98`;
- runtime artifact `9937355457`, digest `sha256:5f60d06985e20282bf4a231a28e2bc5d8945c71ba6e92739ee162b510fda91dd`;
- diagnostics artifact `9937356676`, digest `sha256:88b416d3042522a2284c33617267878bb035dd750f5275aa6de98deacd8e55f6`;
- aggregate workflow result **RED only at final summary**, after build/package/audit/uploads all passed.

Exact current static result:

```text
NtCancelIoFileEx               CLOSED in final production xul.dll
NtCancelIoFile                 present as the resulting XP-side native boundary
KERNEL32 source quartet        PASS / surviving=none
SetProcessDPIAware mode        PASS / direct=0 / delay_user32=1
xul.dll -> PROPSYS.dll         CLOSED in current final binary
libGLESv2.dll -> dxgi.dll      OPEN
CreateDXGIFactory1             OPEN
```

The broad forbidden-direct-import report now contains exactly one row:

```text
libGLESv2.dll|DLL|dxgi.dll
```

The physical XP machine does not contain `dxgi.dll`.

### Closed in this iteration — do not leave as backlog

The following older TODO items are superseded by completed evidence and must not be repeated:

- debugger localization of the `kernel32!RaiseException` startup failure: exact root cause was proven as `USER32.dll!SetProcessDPIAware` `C06D007F` on runtime artifact `9899304858`;
- source/static DPI remediation: current full source `622a876...` revalidates the pre-Vista source guard and final delay-import mode;
- KERNEL32 quartet revalidation: final production 0/4 is proven and remains strict-gate PASS;
- focused `NtCancelIoFileEx` YY capability: run `33861819326`, job `100987750213`, source `be122cfc...`, PASS;
- full Firefox `NtCancelIoFileEx` integration: run `33864176444`, job `100995134125`, source `622a876...`, final `xul.dll` contains `NtCancelIoFile` and not `NtCancelIoFileEx`;
- `xul.dll -> PROPSYS.dll` ordinary dependency: absent from the latest broad forbidden-import report;
- physical XP system-DLL baseline for PROPSYS/DXGI/UIAutomationCore/NCRYPT: already recorded.

### Open work, in order

1. **Trace the remaining `CreateDXGIFactory1` owner in the exact ANGLE / `libGLESv2.dll` build.** Determine the source and target/link configuration that gives final shipped `libGLESv2.dll` its ordinary `dxgi.dll!CreateDXGIFactory1` dependency. Keep this investigation at the graphics/ANGLE component boundary; `xul.dll` link changes cannot fix another PE's import table.
2. **Choose the narrowest XP-compatible ANGLE remediation.** Prefer an existing legacy backend/build switch/source fallback or exclusion that preserves intended XP graphics behavior. Do not introduce broad YY interposition merely to hide DXGI and do not route the problem through the `xul.dll` linker.
3. **Rebuild under a new exact source SHA and require DXGI closure without regressions.** The broad audit must remove `libGLESv2.dll|DLL|dxgi.dll`, while `NtCancelIoFileEx`, PROPSYS, quartet, DPI, msvcr14x, bcrypt and D3DCompiler gates remain closed/green.
4. **Physical XP acceptance of the resulting exact browser.** Require successful startup plus representative ordinary browsing. If a new runtime failure appears, bind it to that exact source/run/job/artifact and diagnose the first actual boundary rather than reopening old static families.
5. **Optional localization-only physical probe of current artifact `9937355457`.** It may be useful to see whether startup advances past the old `SetProcessDPIAware` exception before DXGI remediation, but it cannot be called an accepted clean-XP result while the exact static gate still reports DXGI.
6. **Continue through remaining delay/dynamic/COM surfaces only when evidence reaches them.** WinRT API sets, `UIAutomationCore.dll`, `ncrypt.dll`, `AVRT.dll`, `dwmapi.dll` and similar optional surfaces remain hypotheses until runtime or mandatory static policy makes them blocking.
7. **GOST TLS on old Windows — later exact-artifact milestone.** A browser that starts and browses ordinary pages on XP still does not prove MSSPI/CryptoPro GOST behavior.

### Closed compatibility families — do not spend new cycles without contradictory evidence

- pinned/restored msvcr14x Release x86 contract;
- narrow YY provider strategy and the closed SRW/condition-variable family;
- `CreateWaitableTimerExA` source fallback;
- exact app-local `xp-bcrypt-v1/bcrypt.dll`;
- legacy `D3DCompiler_47.dll` staging/packaging;
- narrow YY residual KERNEL32 line including `TryAcquireSRWLockExclusive` and `FlsGetValue`;
- focused + full-integration `NtCancelIoFileEx` closure;
- KERNEL32 source-remediation quartet at final-production 0/4;
- current final-production `xul.dll -> PROPSYS.dll` ordinary-dependency closure;
- historical `SetProcessDPIAware` root-cause diagnosis and current source/static DPI integration;
- the historical broad curated forbidden-import progression `69 -> 3 -> 0`.

The selected `xp-bcrypt-v1` binary remains trusted project infrastructure:

- source `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`;
- run `33513084915`, job `99873297193`, runtime artifact `9802703271`;
- technical release/tag `xp-bcrypt-v1`;
- size `520704` bytes;
- SHA-256 `f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`;
- physical XP dynamic + ordinary linked/IAT PASS;
- no runtime `mbedtls.dll`.

Do not rebuild/re-prove it inside heavy Firefox work unless its identity changes or new exact evidence specifically implicates that DLL.

### Deferred optional hardening — restore x86 sandbox

The sandbox-on Win7/RNG work is preserved but removed from the XP critical path.

Historical evidence includes source `982d6529a707c6feecad97c725feed8a3cd21c81` / run `33141004769`, where sandbox-enabled Win7 x32 content tabs died in `RandomUint64OrDie`, and source `19c82e7eec160dab761083d454d084515060f808` / run `33298304132` / job `99221664596`, where the CryptoAPI RNG experiment still produced `Gah. Your tab just crashed.` with sandbox enabled.

Do **not** spend new full-build cycles on `LowerToken`, RNG pre-warm, persistent `HCRYPTPROV`, or other modern sandbox-on fixes unless the user explicitly chooses sandbox restoration as a security-hardening goal. If reopened, start from the existing exact WinDbg/runtime evidence and design specifically for the desired XP/Vista/Win7 x86 sandbox semantics rather than treating current Win7 behavior as an XP prerequisite.

## Bundled government-system extensions — independent

Current packaged three-extension artifact `9614275050` is packaging-proven and clean-profile discovery/enabled-state is proven for all three project extensions.

Next:

1. re-check CryptoPro basic functionality on this exact package;
2. test legacy IFCPlugin with installed native host;
3. test Gosplugin with its local/native component;
4. verify the Russian-first content-language preference in runtime if desired;
5. generalize the historically CryptoPro-named packaging workflow to assert all three XPI + language pref;
6. transfer only proven shared packaging gates into the two main browser workflows;
7. later prove real version-to-version update behavior where a valid older/newer signed extension is available.

## CI artifact ergonomics — project-wide

For every heavyweight workflow that performs a full browser compilation/package, add a dedicated portable artifact containing only the produced runnable `.7z` archive.

- Keep the existing package, runtime, diagnostics, import-audit, evidence, and other artifacts; the portable artifact is additional, not a replacement.
- Publish the exact `.7z` produced by the successful full compilation/package as its own artifact payload, without unrelated build trees or diagnostics in that artifact.
- Apply this consistently to the project's heavy full-build lines so a tester can retrieve the portable browser from every successful full compilation without downloading the much larger general package/runtime bundle.
- Treat this as a developer/test ergonomics requirement only; it does not change the evidentiary meaning of the existing build, runtime, packaging, or compatibility artifacts.

## Upstream base — deferred

Stay on r3dfox / Firefox 153. Do not migrate to Firefox 154 merely because upstream Mozilla has released it. Evaluate a newer base only after r3dfox itself publishes one and the user explicitly decides to upgrade.