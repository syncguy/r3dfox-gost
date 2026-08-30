# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

The immediately preceding active volume is preserved unchanged in [`TEST_LOG_2026-08-29_2026-08-29.md`](./TEST_LOG_2026-08-29_2026-08-29.md). Earlier historical evidence remains in the other dated `TEST_LOG_*.md` volumes. Current synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); forward work is in [`TODO.md`](./TODO.md); the Windows XP compatibility architecture and import-triage policy are in [`XP_COMPATIBILITY_STRATEGY.md`](./XP_COMPATIBILITY_STRATEGY.md); the source-level WinRT experiment is in [`WINRT_SOURCE_POC.md`](./WINRT_SOURCE_POC.md); formally closed milestones are in [`DONE.md`](./DONE.md).

For each completed experiment, record the exact date, branch and source-under-test SHA, GitHub Actions run/job when applicable, sanitized observation, conclusion, and whether the finding is current, superseded, or still open. Do not publish client-certificate identifiers, private credential metadata, user data, or unsanitized runtime captures; follow `/AGENTS.md`.

---

## 2026-08-30 — XP import inventory reclassified as a compatibility-design problem, not a one-API-at-a-time implementation backlog

**Track:** Windows XP x86 compatibility  
**Inventory source branch:** `agent/winrt-source-poc`  
**Source-under-test:** `4c982371a53a5d03cfcfe1d4107d1a40cc99c3f9`  
**Run:** `33264392080`  
**Job:** `99131766920`  
**Diagnostics artifact:** `9719920434` (`r3dfox-gost-xp-x32-diagnostics`), digest SHA-256 `6ac47675c07e575cac9854b50d42907d8a04f8bbd0b99a0d9487c3869805d232`

### Exact current workflow-gate result

The full Firefox build/package/runtime staging succeeded and the run became red only at `GATE - Audit XP x32 PE floor and direct imports`.

The checked-in manually curated gate reported:

- 112 violation rows;
- 110 API rows and 2 DLL rows;
- 27 unique listed API names;
- 15 affected PE files;
- `bcrypt.dll` as the DLL-level violation in `mozglue.dll` and `xul.dll`;
- `xul.dll`: 19 listed API violations plus the `bcrypt.dll` dependency.

This gate is useful but incomplete because its `forbiddenApis` model is not an exhaustive stock-XP-SP3 export manifest.

### Expanded planning estimate

A broader comparison of the same diagnostic import tables against the stock XP SP3 x86 system surface produced an approximate direct-import inventory of:

- `xul.dll`: ~57 unique imported functions absent from stock XP SP3;
- the whole scanned `dist/bin` PE set: ~73 unique imported functions absent from stock XP SP3.

The narrow YY diagnostic symbol catalog contains implementation symbols for approximately 49/57 of the `xul.dll` candidates and 65/73 of the whole scanned set. Eight direct candidates were not found in that YY implementation-symbol catalog: `GetApplicationRestartSettings`, `GetNamedPipeServerProcessId`, `PropVariantToString`, `RegisterApplicationRestart`, `RtlDosPathNameToNtPathName_U_WithStatus`, `UnregisterApplicationRestart`, `WSASendMsg`, `WSCGetProviderInfo`.

Availability of a YY implementation symbol is **not** proof that the final PE has been thunked; weak-alias/archive extraction and consumer linkage remain separate integration questions.

### Architectural conclusion

The raw count is not a requirement to hand-implement 57 or 73 APIs. Every incompatible dependency must first be classified as one of:

- modern feature/path that must be absent from the XP build;
- XP-native source replacement/fallback;
- bounded YY-Thunks/compatibility-layer coverage;
- vetted third-party XP compatibility implementation;
- genuinely required project-specific shim;
- optional/test-only component that does not belong in the required browser runtime budget.

WinRT remains explicitly in the first class: remove/fallback at source level rather than carrying the WinRT activation/HSTRING runtime onto XP.

The full `dist/bin` number is also an overestimate of actual browser work because the audit includes test/developer/fake PEs in addition to required runtime components.

Current order-of-magnitude planning estimate, pending a generated exhaustive classification report:

- ~10–15 source-level legacy adaptations;
- ~20–30 stable low-level imports suitable for YY/another compatibility layer;
- ~15–20 modern-feature imports expected to disappear through legacy source selection/fallback;
- roughly 3–6 residual custom-shim cases as a conservative upper working estimate.

These ranges are planning estimates only and must not become fixed implementation targets without caller-level classification.

The full policy, CI redesign, delay-load treatment, third-party dependency rules, and current evidence are recorded in [`XP_COMPATIBILITY_STRATEGY.md`](./XP_COMPATIBILITY_STRATEGY.md).

Status: current architectural guidance; no GOST TLS conclusion follows.

---

## 2026-08-30 — CryptoAPI OS-RNG full XP x32 build completed; physical Win7 sandbox validation is next

**Track:** Windows compatibility / Win7 content-sandbox RNG and XP-compatible OS RNG  
**Experimental branch:** `agent/legacy-rng-poc`  
**Source-under-test:** `19c82e7eec160dab761083d454d084515060f808`  
**Underlying source change:** `7f84f7b4d083b1ea068b86910a90fabebb7524e1` (`fix(xp): use CryptoAPI for Windows OS RNG`)  
**Run:** `33298304132`  
**Job:** `99221664596` (`Windows x86 / r3dfox GOST / XP SP3 full build`)  
**Overall Actions result:** failure at the post-build broad XP import audit

### Source strategy

On Windows, `mozilla::GenerateRandomBytesFromOS()` keeps its existing Firefox-facing contract but the experiment replaces the `RtlGenRandom`/`SystemFunction036` implementation with a real XP-supported CryptoAPI path:

`CryptAcquireContextW -> CryptGenRandom -> CryptReleaseContext`.

This is intentional source-level compatibility, not emulation of a newer Windows RNG API.

### CI result

The browser itself crossed all full-build/package gates before the known broad import inventory gate:

- full release Firefox/r3dfox XP x32 build — success;
- msvcr14x XP runtime staging — success;
- PE subsystem retargeting — success;
- package — success;
- physical-test runtime archive — success;
- artifact uploads — success;
- `GATE - Audit XP x32 PE floor and direct imports` — failure.

Artifacts:

- package artifact `9729515763`, digest SHA-256 `5434c8b61a8351761b514653136133aa026081824d6694d59031df6baedf4be9`;
- runtime artifact `9729516268`, digest SHA-256 `7fbc6b3977b1910dc3087424233726cecbc6b4e6564bff4bdfbb336f61cc8de7`;
- diagnostics artifact `9729516770`, digest SHA-256 `309e63e4dc0369cb84431a6ed024578438e5562dbdbbd056f5fbfab7d9570b3f`.

The red Actions status therefore does not mean compilation/package failure. It means the resulting package still contains the broader unresolved XP compatibility inventory documented separately.

### Next proof

Run this exact artifact on physical Windows 7 x32 with the content sandbox enabled. The candidate fixes the previously localized sandbox RNG blocker only if normal content processes survive startup and ordinary real pages load without the `RandomUint64OrDie` crash.

Do not call the sandbox blocker fixed from build success alone. A later WinRT/other compatibility failure, if reached, remains a separate blocker and must be bound to this exact source/artifact before interpretation.

Status: full-build candidate available; physical Win7 x32 runtime result pending; no GOST TLS conclusion follows.

---

## 2026-08-30 — CryptoAPI RNG full-build candidate still crashes content tabs on physical Win7 x32

**Track:** Windows compatibility / Win7 content-sandbox RNG  
**Experimental branch:** `agent/legacy-rng-poc`  
**Source-under-test:** `19c82e7eec160dab761083d454d084515060f808`  
**Run:** `33298304132`  
**Job:** `99221664596`  
**Package artifact tested:** `9729515763` (`r3dfox-gost-xp-x32-package`), artifact digest SHA-256 `5434c8b61a8351761b514653136133aa026081824d6694d59031df6baedf4be9`  
**Platform:** physical Windows 7 x32  
**Content sandbox:** enabled; `MOZ_DISABLE_CONTENT_SANDBOX` not set

### Observation

The browser parent UI starts, but opening ordinary pages still causes content-tab failure with the Firefox crash page:

`Gah. Your tab just crashed.`

Therefore the acceptance criterion for the CryptoAPI RNG full-build candidate is **FAIL**: replacing `GenerateRandomBytesFromOS()` with per-call CryptoAPI acquisition did not make sandboxed content processes survive normal page loading on the tested Win7 x32 machine.

No new debugger trace was captured in this observation, so this result does not yet prove that the new crash still terminates at the same `RandomUint64OrDie` assertion. It proves only that the candidate did not close the user-visible sandbox blocker.

### Source-level lifecycle finding

The exact source contains both parts of the attempted remedy:

- `SandboxTarget::LowerContentSandbox()` calls `GenerateRandomBytesFromOS()` before `LowerToken()` on pre-Win8 systems;
- `GenerateRandomBytesFromOS()` now performs `CryptAcquireContextW(..., CRYPT_VERIFYCONTEXT | CRYPT_SILENT)`, calls `CryptGenRandom()`, then immediately calls `CryptReleaseContext()` on every invocation.

This creates a concrete lifecycle weakness in the candidate: the pre-lockdown call obtains a CryptoAPI CSP context and releases it before sandbox lockdown. A later RNG call therefore cannot reuse that pre-lockdown provider handle; it must acquire a new CSP context from inside the restricted content process.

Microsoft documents the `HCRYPTPROV` returned by `CryptAcquireContext` as the provider handle used by later CryptoAPI calls, and documents `CRYPT_VERIFYCONTEXT` temporary context lifetime through `CryptReleaseContext`. This makes retained pre-lockdown provider state a technically plausible next hypothesis, but the current runtime failure does **not** by itself prove that `CryptAcquireContextW` is the failing post-lockdown call.

### Next diagnostic

Do not spend another full Firefox build solely on the retained-provider hypothesis yet. Use the current exact binary under WinDbg on physical Win7 x32 and distinguish the failure point:

1. observe the pre-lockdown `CryptAcquireContextW` / `CryptGenRandom` call;
2. observe the first post-lockdown RNG call from the sandboxed `tab` process;
3. determine whether `CryptAcquireContextW` returns zero, or whether acquisition succeeds and `CryptGenRandom` fails;
4. record `GetLastError()` for the first failing CryptoAPI call and confirm whether the eventual termination still reaches `mozglue!mozilla::RandomUint64OrDie`.

Only after that result should the next source experiment choose between retaining a pre-lockdown CSP handle, changing the provider/path, or abandoning CryptoAPI for this sandbox-specific boundary.

Status: current candidate failed physical Win7 sandbox acceptance; root cause of the post-lockdown failure still requires debugger confirmation; no GOST TLS conclusion follows.