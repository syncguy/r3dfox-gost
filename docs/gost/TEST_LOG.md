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
