# GOST TLS transport (PoC)

This directory contains the first r3dfox GOST TLS experiment.

- `GostTLSService.*` selects hosts from `R3DFOX_GOST_HOSTS`.
- `GostSocketControl.*` adapts the MSSPI connection to Firefox's `CommonSocketControl` / `nsITLSSocketControl` surface.
- `nsGostSSLIOLayer.*` is an NSPR I/O layer that drives MSSPI non-blockingly and maps MSSPI read/write readiness to NSPR `PR_WOULD_BLOCK_ERROR` / poll semantics.
- `nsSSLSocketProvider.cpp` dispatches allowlisted hosts here; all other hosts remain on the original NSS path.

The CI workflow materializes pinned MSSPI sources at build time and registers these sources in `moz.build`. That is deliberate for PoC iteration: once the integration compiles cleanly, the build-system changes can be made permanent in-tree.
