# One-Core-API bcrypt physical Windows XP SP3 x86 runtime test

This bundle is a focused Windows compatibility experiment. It is independent of Firefox and GOST TLS runtime.

1. Copy the whole directory unchanged to a physical Windows XP SP3 x86 machine.
2. Open `cmd.exe` in this directory.
3. Run `run-on-xp.cmd`.
4. Preserve the complete console output. Both probes must print `ExitCode=0`; the functional checks must include `LOAD PASS`, `EXPORTS PASS`, `RNG PASS`, and `SHA256 PASS`.

`bcrypt-dynamic.exe` calls `LoadLibraryW(L".\\bcrypt.dll")` and resolves the required BCrypt exports dynamically. `bcrypt-linked.exe` is an ordinary PE with a link-time import from `bcrypt.dll`. Both use BCrypt for a random buffer and SHA-256 of `abc` (expected digest `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`).

A successful GitHub-hosted Windows run is only a build/functional smoke and is not physical-XP evidence. Do not mark One-Core-API bcrypt as physically XP-verified until this exact bundle succeeds on physical Windows XP SP3 x86.
