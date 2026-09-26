# Windows XP x86 — Rust compatibility wiring

Last updated: 2026-09-07

Track: Windows XP SP3 x86 compatibility only. This document does not describe GOST TLS runtime behavior.

Canonical documentation branch: `agent/gost-tls-poc`.
Implementation branch: `agent/winrt-source-poc`.

## Global XP Rust build signal

The canonical full XP x32 workflow now defines the Rust-side XP compatibility signal globally at job scope:

```yaml
RUSTFLAGS: "--cfg moz_xp_compat"
```

This is intentionally symmetric with the existing C/C++ XP build mode:

```sh
export CFLAGS="$CFLAGS -DMOZ_NO_WINRT -DMOZ_XP_COMPAT"
export CXXFLAGS="$CXXFLAGS -DMOZ_NO_WINRT -DMOZ_XP_COMPAT"
```

For XP builds, Rust source may therefore use:

```rust
#[cfg(moz_xp_compat)]
```

and

```rust
#[cfg(not(moz_xp_compat))]
```

without crate-local `build.rs` wiring. Normal non-XP workflows must not set this cfg unless separately decided.

## Why this was needed

The vendored `third_party/rust/mtu` XP remediation was already source-integrated, but it selected its legacy adapter-enumeration path with `#[cfg(moz_xp_compat)]`. The full XP workflow previously propagated `MOZ_XP_COMPAT` only through C/C++ `CFLAGS` / `CXXFLAGS`; that does not define a Rust cfg.

Consequently, completed GREEN source `a15dcd738edda4ab810fc9f92289170f115519e4`, run `34095425319`, job `101657910987`, still compiled the `#[cfg(not(moz_xp_compat))]` branch of `mtu` and retained these xul delay imports:

- `GetIpInterfaceTable`;
- `FreeMibTable`;
- `if_indextoname`.

That static result is now understood as a build-wiring gap in our Rust remediation, not evidence that the vendored Rust source fix was absent.

## Current implementation

Current implementation HEAD:

- branch `agent/winrt-source-poc`;
- HEAD `6885135565f7262bb88c80c4751f4a6c4b93e3ef`;
- final workflow state contains job-global `RUSTFLAGS: "--cfg moz_xp_compat"`.

The initial global-Rust-cfg change was introduced in commit `0f91ea213996024b5d729973231d862cf72f3d83`; follow-up commits `7de17bc9fdb304b4d094f2f8c6639e9b6083b8e6` and `6885135565f7262bb88c80c4751f4a6c4b93e3ef` repaired incidental quote collateral in the pre-existing WS2 diagnostic. The effective source state to build is `6885135565f7262bb88c80c4751f4a6c4b93e3ef` or a descendant.

## Validation status

Status: **source-integrated; build/static validation pending**.

Run `34107793132`, job `101696721232`, source `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4`, predates the global Rust cfg and therefore cannot validate this wiring change even if that run is otherwise GREEN.

The next full XP x32 build that validates this change must use exact source `6885135565f7262bb88c80c4751f4a6c4b93e3ef` or a descendant and must be tied to exact run ID, job ID and source SHA.

Expected static result for the `mtu` owner is that the XP cfg activates the legacy adapter-enumeration path and removes the `GetIpInterfaceTable` / `FreeMibTable` / `if_indextoname` references contributed by that crate. If any of those names still survive in final `xul.dll`, first localize additional owners before concluding that the global Rust cfg failed.

Physical Windows XP runtime remains a separate acceptance gate. A successful build or import cleanup does not by itself close runtime compatibility.
