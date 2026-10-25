# Windows XP x86 — Rust `mtu` XP cfg wiring finding — 2026-09-07

Track: Windows XP SP3 x86 compatibility only. This finding does not establish GOST TLS runtime or handshake behavior.

## Exact build evidence

Newest completed build/static baseline used for this analysis:

- implementation branch: `agent/winrt-source-poc`;
- source-under-test: `a15dcd738edda4ab810fc9f92289170f115519e4`;
- Actions run `34095425319`, attempt `1`;
- job `101657910987`;
- result: **SUCCESS**.

The final `xul.dll` IPHLPAPI diagnostic from that exact build reported the post-XP delay-import survivors:

- `GetIpInterfaceTable`;
- `FreeMibTable`;
- `if_indextoname`.

At the same time the C++ network-listener remediation was effective: `NotifyIpInterfaceChange` and `CancelMibChangeNotify2` were absent. `GetAdaptersAddresses` and `GetBestInterfaceEx` remained as XP-safe delayed imports.

## Rust source remediation is present

Commit `7e4965bc2057f6f0a75d043f0711fefbcfddff68` (`fix(xp): use legacy MTU adapter lookup`) changed `third_party/rust/mtu/src/windows.rs` so the XP path is selected by the Rust configuration predicate:

```rust
#[cfg(moz_xp_compat)]
```

while the modern path containing `GetIpInterfaceTable`, `FreeMibTable`, and `if_indextoname` is guarded by:

```rust
#[cfg(not(moz_xp_compat))]
```

This source patch is already an ancestor of `a15dcd...`. The compare from `7e4965bc...` to `a15dcd...` does not modify `third_party/rust/mtu/src/windows.rs`; only the crate checksum is updated later. Therefore the residual imports are not explained by the XP Rust source patch being applied after the build or later reverted.

## Missing cfg propagation

The XP full-build mozconfig at `a15dcd...` exports:

```text
CFLAGS   += -DMOZ_NO_WINRT -DMOZ_XP_COMPAT
CXXFLAGS += -DMOZ_NO_WINRT -DMOZ_XP_COMPAT
```

Those C/C++ preprocessor defines do not activate Rust `#[cfg(moz_xp_compat)]`.

The exact workflow contains no `RUSTFLAGS` entry carrying `--cfg moz_xp_compat`.

The vendored crate's `third_party/rust/mtu/build.rs` only defines the unrelated `bsd` cfg alias and does not emit `cargo:rustc-cfg=moz_xp_compat`.

The crate manifest declares `build = "build.rs"` but does not expose a Cargo feature that maps to the project XP compatibility switch.

## Interpretation

**HIGH-CONFIDENCE BUILD-CONFIGURATION DEFECT:** the XP Rust source remediation is present, but its `moz_xp_compat` Rust cfg is not wired by the full XP workflow/build configuration found in the exact source under test. Therefore the modern `#[cfg(not(moz_xp_compat))]` MTU implementation is the expected compiled branch.

The exact residual import trio in final `xul.dll` matches that modern branch, while the independently C/C++-guarded listener APIs disappeared. This split strongly corroborates the missing-Rust-cfg diagnosis.

This is still not a formal proof that no second source owner contributes any of the same imports. Final owner attribution may be strengthened with matching PDB/object/link evidence if needed. However the missing cfg wiring must be fixed regardless if the project intends the vendored Rust XP branch to be active.

## Current running build

The later Shell32 validation build:

- run `34107793132`;
- job `101696721232`;
- source `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4`;

inherits the same Rust source and the same XP workflow cfg wiring. Do not cancel or reinterpret that run: it is the current Shell32 source-remediation experiment. Its result remains useful independently, but the same residual Rust MTU imports should be expected unless another hidden build-system mechanism supplies `moz_xp_compat`.

## Next compatibility experiment

After the current Shell32 build is classified, wire the XP condition into Rust with the narrowest project-owned mechanism available. Do not automatically choose a global `RUSTFLAGS=--cfg moz_xp_compat` before checking Mozilla's Rust flag/config plumbing, because a global cfg affects every Rust crate.

Acceptance for the Rust MTU wiring experiment:

1. prove the `mtu` crate is compiled with the XP cfg;
2. rebuild the relevant Firefox/xul target or full XP candidate;
3. require `GetIpInterfaceTable`, `FreeMibTable`, and `if_indextoname` to disappear from final `xul.dll` ordinary/delay import evidence attributable to this path;
4. preserve `GetAdaptersAddresses` and `GetBestInterfaceEx` as allowed XP-era dependencies;
5. keep physical Windows XP runtime as a separate acceptance gate.

Status: **Rust XP source patch present; Rust cfg activation missing by inspected workflow/crate plumbing; narrow cfg wiring experiment pending after current Shell32 build.**
