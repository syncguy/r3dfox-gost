# r3dfox GOST TLS — Experiment Log

This is the current append-oriented engineering log.

Historical experiments through 2026-08-24 are preserved unchanged in [`TEST_LOG_2026-08-22_2026-08-24.md`](./TEST_LOG_2026-08-22_2026-08-24.md). Earlier 2026-08-25 experiments are preserved unchanged in [`TEST_LOG_2026-08-25_2026-08-25.md`](./TEST_LOG_2026-08-25_2026-08-25.md). For current technical synthesis, see [`PROJECT_STATE.md`](./PROJECT_STATE.md). For planned and deferred work, see [`TODO.md`](./TODO.md), and for formally closed milestones see [`DONE.md`](./DONE.md).

For each completed experiment, record:

- exact date;
- branch and commit SHA;
- GitHub Actions run/job when applicable;
- hypothesis/change;
- sanitized observation;
- conclusion;
- whether the finding is current, superseded, or still open.

Do not silently rewrite a failed experiment into a successful one. Add a new entry when understanding changes. Client-certificate and user-originated test data must follow the sanitization rules in `/AGENTS.md`.

---

## 2026-08-25 — CryptoPro real Mozilla portable-packaging proof passes

**Track:** bundled government-system extensions / Mozilla packaging integration  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `17b8d9762b489ed8fc9c3a8e1595802065dd7188` (`ci(extensions): watch Mozilla packaging inputs`)  
**Actions run:** `32847887872`  
**Job:** `97801745453`  
**Workflow:** `CryptoPro Mozilla packaging smoke`  
**CI result:** success  
**Evidence artifact:** `9569388324` (`cryptopro-mozilla-packaging-evidence`)  
**Packaged-browser artifact:** `9569387758` (`r3dfox-cryptopro-mozilla-packaging`)

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32847887872>

### Purpose

Revalidate the dedicated real-Firefox packaging path after run `32817910715`, job `97709832302`, proved that the selected CryptoPro XPI reached the real `dist/bin/distribution/extensions` tree but was omitted from the final portable archive. The corrective packaging line adds the exact XPI path to `browser/installer/package-manifest.in`.

### Observation

The exact run completed successfully. In particular:

- `GATE - Select CryptoPro XPI and prepare working tree`: success;
- the full Firefox build: success;
- `GATE - Verify CryptoPro XPI in real dist/bin`: success;
- `Package release r3dfox`: success;
- `GATE - Verify CryptoPro XPI in final portable archive`: success;
- packaged-browser upload: success;
- dedicated packaging-evidence upload: success.

Therefore one exact run/SHA passed the updater/selection, real Mozilla build staging, package generation, and final portable-archive verification gates together. The final archive contains the expected CryptoPro extension under `distribution/extensions`, with the workflow's selected-candidate SHA-256 and manifest-ID checks passing.

### Conclusion

**The real Mozilla portable-packaging integration for the bundled CryptoPro extension is proven at source SHA `17b8d9762b489ed8fc9c3a8e1595802065dd7188`.**

The missing-final-archive blocker from run `32817910715` is closed and that failed run remains historical evidence of the diagnosed `package-manifest.in` staging omission.

This result closes the dedicated Mozilla packaging proof only. It does not prove clean-profile Firefox discovery/install/update runtime behavior and does not by itself prove GOST TLS runtime or Windows Vista/7 compatibility. The next extension work is to transfer only the already-proven updater preparation and final package-verification gates into the two main browser workflows, then perform the separate clean-profile runtime proof.

Status: current; previous final-portable-archive blocker closed.

---

## 2026-08-26 — CryptoPro extension is discovered automatically in a clean profile and works at runtime

**Track:** bundled government-system extensions / Firefox runtime discovery and functionality  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `17b8d9762b489ed8fc9c3a8e1595802065dd7188`  
**Actions run:** `32847887872`  
**Job:** `97801745453`  
**Packaged-browser artifact:** `9569387758` (`r3dfox-cryptopro-mozilla-packaging`)  
**Runtime evidence:** user manual test of the packaged portable browser with a new profile

### Observation

The user tested the exact portable artifact produced by the successful real-Mozilla packaging run.

- A new Firefox profile discovers the bundled `ru.cryptopro.nmcades@cryptopro.ru` extension automatically; no manual XPI installation is required.
- The extension appears enabled in Add-ons Manager as `CryptoPro Extension for CAdES Browser Plug-in`, version `1.2.14`.
- The user exercised the normal CryptoPro signature-verification functionality and confirmed that it works.
- The Add-ons Manager shows `Allow automatic updates: Default` for this extension.

A source/configuration audit for the exact source-under-test shows:

- `browser/app/profile/firefox.js` sets `extensions.update.autoUpdateDefault = true`;
- `extensions.update.enabled = true`;
- the normal extension-update interval is `86400` seconds;
- the bundled CryptoPro XPI declares the official CryptoPro update manifest `https://www.cryptopro.ru/sites/default/files/products/cades/extensions/ffupdates.json`;
- `r3dfox/policies.json` contains no CryptoPro-specific `ExtensionSettings` entry and no policy disabling extension updates.

### Conclusion

**Clean-profile discovery/install and basic functional runtime use of the bundled CryptoPro extension are proven for artifact `9569387758` / source SHA `17b8d9762b489ed8fc9c3a8e1595802065dd7188`.**

The `Default` update choice follows Firefox's global add-on auto-update setting. For this exact source, the global defaults have extension update checks enabled and automatic application enabled, so an untouched clean profile is expected to update this extension automatically through its vendor update manifest.

A real version-to-version update has not yet been observed. That remains the only open runtime-update proof for this extension track; it should be tested with an older valid signed CryptoPro XPI or when CryptoPro publishes a version newer than `1.2.14`.

Status: current; clean-profile discovery/functionality closed, real update transition still open.

---

## 2026-08-26 — Firefox-facing client-cert refcount fix passes both full browser builds

**Track:** GOST TLS runtime / Stage 2 Firefox-facing client-certificate selection; build validation only  
**Branch:** `agent/gost-tls-poc`  
**Code-under-test:** `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e` (`fix(gost): use Firefox thread-safe refcounting`)

### Main full build

- **Actions run:** `32844083378`
- **Job:** `97789764275`
- **Workflow:** `GOST TLS PoC build`
- **CI result:** success
- `GATE - Compile security manager SSL target objects`: success
- full release build: success
- Win7 import audit: success
- package/upload: success
- final known-Win8+ direct-import gate: success
- release artifact: `9567881847` (`r3dfox-gost-win64-release`), SHA-256 digest `c5c4a6774e77fc1b791237dcf6059a546d95a919eb6799c7bf04abf3ade6569d`
- import-audit artifact: `9567882486` (`r3dfox-gost-win64-win7-import-audit`), SHA-256 digest `54d2b9b39256736eb3505da9b05b3cd4525aea7c6ea7ce1bcd160c89376f7f4e`

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32844083378>

### Experimental thunk-rs full build

- **Actions run:** `32844083433`
- **Job:** `97789764481`
- **Workflow:** `GOST TLS PoC build - thunk-rs experiment`
- **CI result:** success
- `GATE - Compile security manager SSL target objects`: success
- full release build with the narrow YY-Thunks linker path: success
- package/upload: success
- thunked `xul.dll` Win7 import audit: success
- final known direct Win8+ import gate: success
- release artifact: `9567061391` (`r3dfox-gost-win64-thunk-experiment`), SHA-256 digest `fe165b0b04485354a5e2dac1c7a5a54fb82946ead1b30075a5fdf22bde7122a9`
- diagnostics artifact: `9567062774` (`r3dfox-gost-win64-thunk-diagnostics`), SHA-256 digest `a14bfdfe54ec86cae334ba812b34fb7231b585e7408d667f74fb12561b27b216`

Run link: <https://github.com/syncguy/r3dfox-gost/actions/runs/32844083433>

### Purpose and observation

The exact source SHA is the compile-fix descendant of failed SSL-only run `32837093952`, where the new Stage 2 picker state used the nonexistent Firefox-153 `mozilla::RefCountedThreadSafe` API. Short compile run `32844083351`, job `97789764135`, had already proven the replacement with `NS_INLINE_DECL_THREADSAFE_REFCOUNTING` at the SSL-target level.

These two full runs now extend that proof through both current full-browser strategies. The same Stage 2 Firefox-facing client-certificate picker/refcount source compiles, links, packages, uploads, and passes each workflow's existing direct-import compatibility gate.

### Conclusion

**Source SHA `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e` is proven full-buildable and packageable in both current browser build strategies.** The earlier `RefCountedThreadSafe` / `AddRef` / `Release` compile regression is therefore closed not only at the short SSL compile gate but also at full Firefox/xul scale.

This is intentionally a build result, not runtime proof. Neither run exercises the Firefox client-certificate dialog/selection flow, peer-certificate acquisition, fail-closed server verification, MSSPI client authentication, or a GOST TLS handshake. The next evidence for this GOST-runtime line must come from runtime testing of an artifact built from this exact source SHA (or a clearly identified descendant).

For the Windows Vista/7 compatibility track, the experimental run proves only that the existing direct-import audit/gate passes for this source and linker strategy. It does not by itself prove real Windows 7 runtime compatibility.

Status: current; full-build prerequisite closed, Stage 2 runtime/integration work remains open.
