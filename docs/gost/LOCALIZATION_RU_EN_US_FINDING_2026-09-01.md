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

## Packaging mechanism hypothesis

The current workflow starts from an en-US base build and later runs `package-multi-locale --locales ru`, but it does not explicitly prepare a real Firefox 153 Russian localization source tree before the localization merge/repack stage.

Upstream `browser/locales/Makefile.in` shows that non-en-US locale generation is not just registration: `chrome-ru` / `l10n-ru` invoke the locale merge path (`merge-ru`) and expect actual localized source material. A package can therefore contain locale registration, `multilocale.txt`, and `localization/ru/...` paths while still carrying empty merged payload if the source l10n tree was not correctly supplied.

Current working hypothesis: the primary defect is missing or incorrect Russian l10n source input (`L10NBASEDIR` / `--with-l10n-base` or equivalent compatible Firefox 153 `firefox-l10n/ru` checkout) during the merge/repack stage, not locale negotiation.

Do not yet conclude that the base browser must be rebuilt with `AB_CD=ru`. First prove or reject the standard en-US-base plus correctly supplied Russian l10n merge path with a cheap packaging-only experiment.

## Next cheap experiment

Before another full two-hour Firefox build:

1. obtain a Russian localization tree compatible with the Firefox/r3dfox 153 baseline;
2. point the localization build to it using the normal l10n-base mechanism;
3. rerun only the localization merge/repack path against the existing build/object/package state where practical;
4. inspect representative Russian Fluent files before packaging and inside both root `omni.ja` and `browser/omni.ja`;
5. only if the Russian payload is populated should the resulting package be promoted to runtime UI testing.

If a correctly supplied l10n tree still produces English-first UI, then investigate a true `AB_CD=ru` primary build with `en-US` as secondary. That more expensive architecture change is not yet justified by current evidence.

## Required CI gates

The existing localization gate is insufficient because it treats path existence as localization success. Future gates should fail unless:

- `ru` is listed in `multilocale.txt`;
- representative `ru` Fluent resources in both root and browser `omni.ja` are non-zero;
- representative Russian files contain real Russian translations rather than empty files or copied en-US payload;
- the proportion/count of zero-length `ru` localization files stays below an explicit strict threshold;
- a known sample of `ru` and `en-US` files differs in content where translation is expected.

The current artifact must therefore be classified as:

**multi-locale packaging mechanics PASS; Russian localization payload FAIL; Russian-first runtime UI FAIL.**

This finding supersedes any interpretation of run `33403654068` as proof that Russian UI resources are functionally present merely because the locale directories exist.
