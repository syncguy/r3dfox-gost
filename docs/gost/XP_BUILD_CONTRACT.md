# Windows XP x86 build contract — canonical location

The authoritative `XP_BUILD_CONTRACT.md` is maintained on the repository default branch `agent/gost-tls-poc` at the same path:

`docs/gost/XP_BUILD_CONTRACT.md`

This branch-local file exists only so XP work on `agent/winrt-source-poc` does not produce a false "document not found" result during context recovery.

For contract decisions, always read the canonical file from `agent/gost-tls-poc`; do not treat this pointer as a substitute for its contents. Branch-local code, `PROJECT_STATE.md`, and `TEST_LOG.md` may contain newer experiment evidence, but they do not override the durable build contract unless the canonical contract is explicitly updated.
