# Global instructions
Limit the amount of comments you put in the code to a strict minimum. You should almost never add comments, except sometimes on non-trivial code, function definitions if the arguments aren't self-explanatory, and class definitions and their members.

Do not remove existing comments unless they are directly related to what you are changing.

If you see a good first bug that isn't directly related to your work, don't hesitate to propose it as a good first bug (see the `file-good-first-bug` skill).

The Firefox repository is very big and so it isn't advised to blindly run rg or grep commands without specifying a narrow set of directories to search. When local text search via shell is necessary, prefer `rg` over `grep` as it is faster. There are tools available to help, see next section.

## Tooling for Firefox work
- Some tools useful for Firefox work are available in the `moz` MCP server
- Firefox is a very large repository, and it isn't efficient to search with usual tooling. When working on Firefox, you MUST use the `searchfox-cli` tool if you want to know about something. Its `--help` flag will show the options, but you probably want:
```
searchfox-cli --define 'AudioContext::AudioContext' # get function impl
searchfox-cli --define 'AudioSink' # get class definition
searchfox-cli --path ipdl -q 'MySearchTerm' # search for a text string, restrict on path
searchfox-cli --id AudioSink -l 150 --cpp # search for identifier AudioSink
```
- For C++, Rust and Java code, prefer searching for identifiers with `searchfox-cli`. Use text search restricted by path otherwise.
- Do not try to use identifier search for front-end identifiers like JS object or function names, CSS classes or HTML custom element names.
- `searchfox-cli`'s `--path` can only be provided once, but supports globs so you can combine a path with a file extension restriction.
- If you must use regular expressions with `searchfox-cli`, don't forget the `--regexp` flag.
- Use the `searchfox-cli` tool, only using `rg` or usual local tools if you need to find information about something
that has definitely changed locally. If you're unsure, ask.
- If you can't find something quickly, it is better to ask than run local searches.
- `./mach` is the main interface to the Mozilla build system and common developer tasks. Important commands are listed here, and you can run `./mach help` for a full list of commands. If you want additional details for a given command, you can run `./mach COMMAND --help`
- `./mach format`: Format code. Run it without additional parameters to format all the files you have modified
- `./mach build`: Build the project. Full builds can take a long time, up to tens of minutes.
- `./mach test --auto`: Run tests
- `./mach run`: Run the project
- `./mach doc --no-serve --no-open`: Build the documentation
- `./mach python --virtualenv <virtualenv_name>`: Execute Python of a Mach command's virtualenv. Value of `virtualenv_name` is in relevant `@Command` decorator. This avoids `ImportError`s.
- `treeherder-cli`: Pull CI results for a try push
- Use the MCP resource `@moz:bugzilla://bug/{bug_id}` to retrieve a bug
- Use the MCP resource `@moz:phabricator://revision/D{revision_id}` to retrieve a Phabricator revision

## Fixing review comments
Use `@moz:phabricator://revision/D{revision_id}` to retrieve the revision and its comments.

You can find the review identifier by inspecting the commit log with:

- `jj log -T builtin_log_detailed` if using `jj`
- `git log -v -l 10` if using git

## Code Style
- Our style guide forbids the use of emoji.

## Workflow
- You can run tests by using `./mach test --auto`. Once you are satisfied with the tests you run locally, use `mach try auto` to run tests in CI
- When running slow commands like `./mach test`, `./mach mochitest`, etc., NEVER pipe their output through `tail`, `grep`, `head`, or other filters. Instead redirect output to a temporary file in `artifacts/` (create if necessary) and selectively read this file. This avoids having to re-run slow commands multiple times to extract different pieces of information.
- Do not run `./mach build faster` when only front-end test files (JS, HTML, etc.) were modified — they don't need compilation.
- Ask if you should run a test. If you do, you probably want to run the test with `--headless`
- Never submit patches to Phabricator without explicit user approval.
- In commit messages, group reviewers use a `#` prefix: `r?#group-name` (e.g. `r?#linter-reviewers`), while individual reviewers do not: `r?username`
- Never put `DONTBUILD` (or `CLOSED TREE`) in the `-m` message of `mach try fuzzy` when you want builds to actually run. The Gecko decision task scans the message and on `DONTBUILD` strips every task from the graph: the decision task itself succeeds (Treeherder shows green) but no builds are scheduled.
- When doing Android and Desktop front-end-only changes, use the special `./mach build faster` to skip all C++/Rust compilation.
- Conversely, for C/C++/Obj-C/Rust only changes you can use the special `./mach build binaries` to skip all front-end-related tasks.

## r3dfox GOST TLS project-specific instructions

These rules supplement the global Firefox instructions above and are authoritative for this fork. Treat this section as the entry point for project context recovery; it should contain durable rules and document topology, not a snapshot of the current experiment.

### Repository and branch policy
- Repository: `syncguy/r3dfox-gost`.
- Default and active development branch: `agent/gost-tls-poc`.
- Frozen baseline branch: `win-153`.
- `win-153` is a protected reference snapshot. NEVER commit, push, merge, rebase, force-push, delete, fork-sync, or otherwise modify `win-153` unless the user explicitly requests that exact operation.
- Do not infer the active working branch from an old pull request base. PR #1 historically targets `win-153`; active development remains on `agent/gost-tls-poc`.

### GitHub repository mutation policy
- If a direct repository tool exists for the requested mutation, MUST use that direct tool. The existence of an indirect workaround is not permission to use it.
- To modify an existing UTF-8 repository file, MUST fetch the exact target file and current blob SHA, then use the direct file-update operation for that same path.
- To create or delete a repository file, MUST use the direct file-create or file-delete operation respectively when available.
- NEVER create a temporary GitHub Actions workflow in order to edit another repository file, commit or push repository changes, dispatch another workflow, work around GitHub App or `GITHUB_TOKEN` permissions, or delete itself after performing such an operation.
- NEVER use a GitHub Actions runner as a surrogate repository editor when direct repository mutation tools are available.
- NEVER use low-level Git data operations such as blob/tree/commit/ref construction to work around a failed or unavailable direct file operation unless the user explicitly authorizes that exact approach.
- A requested change to `.github/workflows/<name>.yml` must modify only that requested workflow unless the user explicitly requests additional workflow files.
- Before every write under `.github/workflows/`, identify and fetch the exact existing target file and its current blob SHA. After the write, verify the resulting commit and changed filenames.
- If a workflow is `workflow_dispatch`-only and no direct workflow-dispatch operation is available, commit the requested workflow change and STOP. Ask the user to start it manually. NEVER synthesize a dispatcher workflow as a workaround.
- Whenever asking the user to start a workflow manually, MUST provide the direct GitHub Actions workflow page in the form `https://github.com/<owner>/<repo>/actions/workflows/<workflow-file>.yml`, where the `Run workflow` control is available.
- In the same manual-launch instruction, MUST state the exact branch name/ref the user should select in `Run workflow`; never leave the branch implicit.
- Do not substitute a repository tree/blob link to `.github/workflows/...` or the generic Actions page for the direct workflow Actions page when manual launch is required.

### Project invariants
- Add GOST TLS support to r3dfox/Firefox through `deemru/msspi` and the Windows CryptoPro/SSPI stack.
- Ordinary HTTPS must continue to use Firefox NSS. Only explicitly selected/allowlisted GOST TLS hosts use the MSSPI-backed transport.
- A successful build does not prove a successful GOST TLS handshake.
- A successful loader/import or Windows compatibility result does not prove GOST TLS runtime behavior.
- Successful extension staging or packaging does not prove either GOST TLS behavior or Windows Vista/7 compatibility.
- Current blockers, active implementation details, and next experiments belong in `docs/gost/PROJECT_STATE.md` and `docs/gost/TODO.md`, not in this file.

### Mandatory context recovery
At the start of every new technical chat, and again before making a technical change if the branch may have moved:
1. Verify the repository default branch and exact current HEAD/ref relevant to the question.
2. Read this `AGENTS.md` project-specific section.
3. Read `docs/gost/PROJECT_STATE.md` from the current default branch for the current technical synthesis.
4. Read `docs/gost/TODO.md` for pending, deferred, and future work.
5. Read `docs/gost/DONE.md` when the question concerns a completed milestone, closed blocker, already-proven baseline, or hypothesis that might otherwise be reopened.
6. Read `docs/gost/WORKFLOWS.md` before analyzing, comparing, naming, or drawing conclusions from GitHub Actions workflows or build runs.
7. If the question concerns a previous build, runtime test, regression, error, failed experiment, or discarded approach, read the relevant entry in the active `docs/gost/TEST_LOG.md` and, when necessary, the dated `docs/gost/TEST_LOG_*.md` volume containing that event.
8. Prefer verified repository, code, workflow, run, and log state over conversational memory.

Do not resurrect a hypothesis marked resolved or rejected in `DONE.md` or in any current or historical test-log volume without new evidence.

### Evidence identity
- Associate every GitHub Actions conclusion with the exact run ID, job ID when relevant, and source-under-test commit SHA.
- Associate runtime logs with the exact browser/build artifact and source-under-test SHA before drawing technical conclusions.
- Keep source-under-test identity separate from later documentation-only HEADs. A docs commit must never be cited as the binary/source SHA for an earlier build or runtime result.
- When a run is still in progress, describe its state as provisional. Do not document a pending gate as passed or close the corresponding task before the exact run finishes.

### Mandatory GOST runtime-test preflight
- Every GOST TLS runtime test sequence must pass the exact binary/environment/profile preflight defined in `docs/gost/STAGE2_RUNTIME_TEST_PLAN.md` before its result is accepted as evidence.
- Verify the launched `r3dfox.exe` and `xul.dll` SHA-256 values against the authoritative build artifact for the source under test. A mismatch invalidates the test until the correct binary is launched.
- Use the documented baseline GOST environment with diagnostic selector/mode/cipher overrides cleared unless the named test explicitly requires an override. Record any intentional deviation with the test result.
- Start each independent runtime test sequence from a new clean test-specific Firefox profile. Reuse a process/profile only when continuity is part of the test semantics, such as Session reuse, restart-boundary, Once-fanout, or cross-host isolation experiments.
- Bind each runtime result to source SHA, Actions run/job, artifact ID, binary hashes, profile/test identity, environment state, and sanitized capture/log identity where applicable.
- A runtime log produced without a successful preflight is invalid evidence and must not be used to pass/fail a named SD/T test or change the current technical conclusion.

### Keep project tracks separate
There are three independent project tracks. Evidence from one track must not be used as proof for another unless a deliberately combined experiment tests both.

1. **GOST TLS runtime / handshake**
   - `nsGostSSLIOLayer`, NSPR, MSSPI, SSPI, CryptoPro, proxy lifecycle, TLS handshake, server verification, client certificates, mTLS, runtime application traffic.
2. **Windows Vista/7 binary compatibility**
   - Rust, YY-Thunks, VC-LTL, thunk-rs, msvcr14x, linker behavior, PE imports, loader/startup compatibility, real Windows runtime coverage.
3. **Bundled government-system extensions**
   - extension updater/fallback behavior, Mozilla build-system staging, installer/package manifests, portable archive contents, Firefox extension discovery/install/update runtime behavior.

A workflow may reuse infrastructure from another track without changing the meaning of its evidence. Use `docs/gost/WORKFLOWS.md` to determine each workflow's intended role.

### Sensitive certificate and test data
- The repository is public. Treat all client-certificate, credential, and user-originated test data as sensitive by default.
- NEVER commit or publish a complete client-certificate thumbprint/fingerprint, including full SHA-1, SHA-256, or other certificate hash values.
- NEVER commit or publish client-certificate serial numbers, full subject/issuer DNs that identify the user or organization, certificate key IDs, private-key container/provider identifiers, PINs/passwords, private-key material, PFX/PKCS#12 contents, or equivalent identifying credential metadata.
- NEVER commit or publish contents of user-filled forms, personal-cabinet responses, account identifiers, or other private application data observed during runtime tests.
- Do not paste raw client certificates, raw private mTLS captures, or unsanitized diagnostic dumps into `PROJECT_STATE.md`, `TODO.md`, `DONE.md`, `TEST_LOG.md`, dated historical `TEST_LOG_*.md` volumes, issues, PR comments, commit messages, or CI logs.
- Before publishing any mTLS/certificate experiment result, sanitize it. Record only protocol facts required to reproduce the engineering conclusion, such as host, build run/commit, TLS state, certificate-request presence, acceptable-CA count, abstract selector type, success/failure class, and sanitized error codes.
- If a diagnostic selector needs a certificate identifier locally, keep the concrete value outside the repository and outside CI logs. Documentation may say `known-good client certificate`, `<local-cert-id>`, or equivalent; it must not contain the real identifier.
- Full Git commit SHAs, GitHub Actions run/job IDs, artifact hashes, and hashes of non-sensitive build/log artifacts may still be recorded when useful for reproducibility. This exception does NOT apply to certificate fingerprints/thumbprints or other credential-derived identifiers.
- If existing logs contain sensitive certificate/user data, summarize sanitized evidence rather than uploading or quoting the raw data.

### Upstream/version policy
- This project is based on the maintained fork `Eclipse-Community/r3dfox`, not directly on Mozilla Firefox upstream.
- The project remains on the r3dfox/Firefox 153 baseline represented by `win-153` until the user explicitly decides to evaluate a newer r3dfox baseline.
- Mozilla Firefox upstream advancing to 154 or later is not by itself a reason to migrate this project.
- Monitor `Eclipse-Community/r3dfox` for its next maintained baseline. Do not migrate, rebase, or retarget this project to a 154-or-later base until r3dfox itself publishes that baseline and the user explicitly decides to evaluate the upgrade.

### Documentation topology
- `docs/gost/PROJECT_STATE.md` — current technical synthesis: architecture, confirmed current behavior, active blockers, pinned dependencies, and immediate next experiment.
- `docs/gost/TODO.md` — forward-looking backlog only: pending, deferred, and future work.
- `docs/gost/DONE.md` — compact registry of formally closed milestones, blockers, and conclusions. It is not a second experiment log.
- `docs/gost/WORKFLOWS.md` — authoritative workflow-role map. Detailed run histories belong in the test logs, not here.
- `docs/gost/TEST_LOG.md` — active append-oriented experiment/evidence log.
- `docs/gost/TEST_LOG_*.md` — immutable dated historical evidence volumes.
- Track-specific design documents such as `docs/gost/STAGE2_PLAN.md` and `docs/gost/EXTENSIONS.md` may contain detailed active plans/contracts for their subsystem; they do not replace `PROJECT_STATE.md`, `TODO.md`, `DONE.md`, or the test logs.

### Documentation maintenance
After a meaningful experiment:
- Append exact evidence and the conclusion to the active `docs/gost/TEST_LOG.md`.
- Keep completed historical `docs/gost/TEST_LOG_*.md` volumes immutable except for an explicit correction that preserves the original conclusion and explains the correction.
- Update `docs/gost/PROJECT_STATE.md` only when the current understanding, blocker, architecture, pinned dependency, confirmed behavior, or immediate next experiment changes.
- Keep `docs/gost/TODO.md` forward-looking. Add/reprioritize/remove pending work as evidence changes. Completed narrative must not accumulate there.
- Update `docs/gost/DONE.md` when a milestone, blocker, or research conclusion is formally closed or reopened. Keep entries concise and point to authoritative evidence rather than duplicating the test log.
- When a milestone closes: record the detailed evidence in `TEST_LOG.md`, update `PROJECT_STATE.md` if the current synthesis changes, remove the completed work from `TODO.md`, and add a concise closure entry to `DONE.md`.
- When new evidence reopens a closed item: append the new evidence to `TEST_LOG.md`, restore the open work to `TODO.md`, update `PROJECT_STATE.md` if needed, and amend the corresponding `DONE.md` entry instead of silently deleting history.
- Keep failed/rejected approaches in the active or historical test logs so future agents do not repeat them blindly.

### TEST_LOG rotation procedure
Rotate the active experiment log proactively when `docs/gost/TEST_LOG.md` becomes large enough that routine fetch/update operations are cumbersome, truncated, or risky. Rotation is normal documentation maintenance and does not require a separate user decision unless the user has requested a different archival scheme.

Use this procedure:
1. Verify the current default branch and exact HEAD immediately before rotation and fetch the current `TEST_LOG.md` blob SHA.
2. Create `docs/gost/TEST_LOG_YYYY-MM-DD_YYYY-MM-DD.md` covering the first and last experiment dates in the active volume.
3. Preserve the completed volume byte-for-byte when no correction is intended. Do not summarize, compact, reorder, or delete old failures during rotation.
4. Replace `docs/gost/TEST_LOG.md` with a small new active volume linking to the immediately preceding dated volume plus `PROJECT_STATE.md`, `TODO.md`, and `DONE.md`; retain the sanitization and append-only rules.
5. If a meaningful experiment triggered rotation, record that experiment in the new active volume in the same documentation operation.
6. Update `PROJECT_STATE.md`, `TODO.md`, and `DONE.md` only as required by the experiment or changed evidence topology.
7. Verify that the historical file exists, the preserved blob is unchanged when intended, links are current, and the branch HEAD is the expected docs-only descendant.
8. Keep source-under-test identity separate from the rotation/docs commit.

For later rotations, never rename or chain-rewrite older historical volumes. Create one new dated volume from the then-current active log and keep all previous dated volumes authoritative and immutable.