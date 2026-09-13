# Russian-first `ru + en-US` localization finding — 2026-09-01

Track: browser packaging / localization only. This is not GOST TLS handshake evidence and not Windows compatibility evidence.

## Exact build under test

- source-under-test: `37846488e281b4c3a2df46e949b4f970a7343ed3`
- branch: `agent/gost-tls-poc`
- workflow: `CryptoPro Mozilla packaging smoke`
- Actions run: `33403654068`
- job: `99525795309`
- browser artifact: `9768056691`
- evidence artifact: `9768057338`
- CI conclusion: `success`

The build runs:

```text
mach package
mach package-multi-locale --locales ru
```

and packages both `ru` and `en-US`, with `intl.locale.requested=ru`.

## Runtime result

On Windows 7 x64 the actual browser UI remains English even with a clean profile and full restart.

`about:support` reports:

```text
Requested Locales ["ru"]
Available Locales ["ru","en-US"]
App Locales ["ru","en-US"]
Regional Preferences ["ru-RU"]
Default Locale "en-US"
```

The application-language UI also reports Russian as selected.

Changing packaged `omni.ja!/default.locale` manually from `en-US` to `ru` does not change the actual UI. Therefore the hypothesis that `default.locale=en-US` alone is the cause is rejected as insufficient.

## Decisive artifact finding

Inspection of the exact browser artifact `9768056691` shows that the Russian localization tree is registered but is almost empty:

- root `omni.ja`: `localization/ru` contains 100 files, of which 97 are zero-length;
- `browser/omni.ja`: `localization/ru` contains 129 files, of which 119 are zero-length;
- the corresponding `en-US` resources are populated.

This explains the apparent contradiction between locale negotiation and visible UI.

`LocaleService` can correctly negotiate `ru` and expose it as requested/available/app locale because the locale is registered in the package. When concrete Fluent/UI resources are resolved, however, the selected Russian resource tree contains little or no message payload, so resolution falls back to populated `en-US` resources. Changing `default.locale` cannot restore missing localization payload and therefore cannot fix this artifact.

## Focused Firefox 153 l10n merge experiment — PASS

A dedicated cheap smoke now proves that the standard Firefox 153 locale merge itself can consume a real Russian localization checkout and produce an overwhelmingly populated merged tree.

Exact experiment identity:

- source-under-test `91328ba86f050a7b64a5f344726548d22e599648` on `agent/gost-tls-poc`;
- commit message `ci(localization): expose vendored Python deps to l10n smoke`;
- workflow `Russian localization payload smoke`;
- Actions run `33468459359`;
- job `99733112273`;
- run/job conclusion: **success**;
- `firefox-l10n` source SHA `4273d99ccdc4a516ec6abd742a272ad1d385ddf4`;
- evidence artifact `9785719216` (`ru-localization-payload-smoke-evidence`), digest `sha256:e8cac1213a8bf7ffd39357f62673f0d1f20649866e8a3986d042ecfa97583d78`.

The smoke executes the same merge primitive used by Firefox 153 `toolkit/locales/l10n.mk`:

```text
python -m moz.l10n.bin.build \
  --config browser/locales/l10n.toml \
  --base <firefox-l10n> \
  --target <merge-dir> \
  --locales ru \
  --coverage
```

Source checkout sanity for the exact l10n SHA:

- Russian Fluent files: `245`;
- non-empty: `245`;
- zero-length: `0`;
- containing Cyrillic: `244`.

Merged Firefox 153 Russian tree:

- Fluent files: `217`;
- non-empty: `216`;
- zero-length: `1`;
- containing Cyrillic: `215`;
- representative `browser/browser/browser.ftl`, `browser/browser/preferences/preferences.ftl`, and `toolkit/toolkit/neterror/netError.ftl` are present and non-empty.

The one zero-length merged Fluent file is:

```text
.l10n/merge-dir/ru/toolkit/toolkit/about/aboutConfig.ftl
```

This single empty file is not comparable to the broken full portable artifact, where root `omni.ja` had `97/100` empty Russian files and `browser/omni.ja` had `119/129` empty Russian files.

### Conclusion of the focused smoke

**Russian l10n source input PASS; Firefox 153 standard l10n merge PASS.**

The experiment rejects the hypothesis that the Firefox 153 merge primitive itself inherently turns the Russian localization tree into an almost-empty payload. It also proves that the project can consume the tested `firefox-l10n` checkout through the standard `moz.l10n` merge path without a full browser build.

The current localization blocker therefore moves downstream: the mass empty-file defect must arise later in the full Windows multi-locale build/package/repack path, or because that path was not supplied/configured with the proven l10n input when `package-multi-locale --locales ru` ran.

The smoke currently uses the recorded `firefox-l10n` revision above. This is useful experiment evidence but should not yet be treated as the permanent production pin for Firefox 153 until the eventual full packaging path is made reproducible and validated end-to-end.

## Updated next experiment

The next justified experiment is now a full packaging integration test, not another locale-negotiation or merge-only test:

1. modify `cryptopro-mozilla-packaging-smoke.yml` so the Windows Firefox build/repack has a real Russian `firefox-l10n` tree available through the normal l10n-base mechanism before `package-multi-locale --locales ru`;
2. record the exact l10n SHA used by that full run;
3. keep the existing en-US base architecture for this experiment;
4. inspect both root `omni.ja` and `browser/omni.ja` after multi-locale packaging;
5. fail unless representative Russian Fluent files are non-empty and Cyrillic;
6. fail on the prior mass-empty shape, with explicit zero-length counts and paths;
7. only after that gate passes, promote the resulting portable artifact to clean-profile Russian UI runtime testing.

A primary `AB_CD=ru` browser build remains unnecessary unless this correctly supplied en-US-base + l10n merge/repack path still fails.

## Required CI gates

The existing localization gate is insufficient because it treats path existence as localization success. Future full-package gates should fail unless:

- `ru` is listed in `multilocale.txt`;
- representative `ru` Fluent resources in both root and browser `omni.ja` are non-zero;
- representative Russian files contain real Russian translations rather than empty files or copied en-US payload;
- the proportion/count of zero-length `ru` localization files stays below an explicit strict threshold;
- full paths of every zero-length Russian resource are retained in evidence;
- a known sample of `ru` and `en-US` files differs in content where translation is expected;
- the exact `firefox-l10n` source SHA is recorded with the build.

The original artifact `9768056691` remains classified as:

**multi-locale packaging mechanics PASS; Russian localization payload FAIL; Russian-first runtime UI FAIL.**

The focused run `33468459359` adds a new, separate conclusion:

**Russian source tree PASS; Firefox 153 merge primitive PASS; downstream full-package/repack integration remains the active localization blocker.**

This finding supersedes any interpretation of run `33403654068` as proof that Russian UI resources are functionally present merely because the locale directories exist.
