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
searchfox-cli --id AudioSink -l 150 --cpp # search for identifier audio sink in C++ code, 150 results max
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

These rules supplement the global Firefox instructions above and are authoritative for this fork.

### Repository and branch policy
- Repository: `syncguy/r3dfox-gost`.
- Default and active development branch: `agent/gost-tls-poc`.
- Frozen baseline branch: `win-153`.
- `win-153` is protected as a reference snapshot: updates, deletion, and force-pushes are restricted, and fork syncing is not allowed by its ruleset.
- NEVER commit, push, merge, rebase, or otherwise modify `win-153` unless the user explicitly requests that exact operation.
- Do not infer the active working branch from an old pull request base. PR #1 historically targets `win-153`; active work still belongs on `agent/gost-tls-poc`.

### Project goal
- Add GOST TLS support to r3dfox/Firefox through `deemru/msspi` and the Windows CryptoPro/SSPI stack.
- Ordinary HTTPS must continue to use Firefox NSS. Only explicitly selected/allowlisted GOST TLS hosts use the MSSPI-backed transport.
- Phase 1 established Windows TLS 1.2 / HTTP/1.1 server-authenticated GOST HTTPS. The next GOST work includes fail-closed server-certificate verification and client-certificate / mutual TLS integration; see `docs/gost/TODO.md`.

### Mandatory context recovery
Before answering a technical question about the current project state or changing code:
1. Verify the repository default branch and the exact HEAD/ref relevant to the question.
2. Read `docs/gost/PROJECT_STATE.md` from the current default branch.
3. Read `docs/gost/TODO.md` for explicit pending/deferred work and future milestones.
4. Read `docs/gost/WORKFLOWS.md` before analyzing, comparing, naming, or drawing conclusions from GitHub Actions workflows or build runs. Treat it as authoritative for the role of each workflow, especially the distinction between the main GOST build and experimental Windows Vista/7 thunk-rs builds.
5. If the question concerns a previous build, regression, test, error, or discarded approach, read the relevant entries in `docs/gost/TEST_LOG.md`.
6. Associate runtime logs and GitHub Actions results with their exact run ID and commit SHA before drawing conclusions.
7. Treat `docs/gost/PROJECT_STATE.md` as the current synthesis, `docs/gost/TODO.md` as the forward backlog, `docs/gost/WORKFLOWS.md` as the workflow-role map, and `docs/gost/TEST_LOG.md` as the historical evidence trail. Prefer verified repository/run state over conversational memory.

Do not resurrect a hypothesis marked resolved or rejected in these files without new evidence.

### Keep investigation tracks separate
There are two related but distinct tracks:
- GOST TLS runtime/handshake behavior (`nsGostSSLIOLayer`, NSPR, MSSPI, SSPI, CryptoPro).
- Windows Vista/7 binary compatibility and toolchain/linker work (Rust, YY-Thunks, VC-LTL, thunk-rs, PE import audits).

A successful build does not imply a successful GOST TLS handshake, and a TLS runtime failure does not by itself imply a Win7 linker/import problem.

### Upstream/version policy
- This project is based on the maintained fork `Eclipse-Community/r3dfox`, not directly on Mozilla Firefox upstream.
- The current r3dfox base/default branch is `win-153`.
- Mozilla Firefox may advance independently; that alone is not a reason to retarget this project.
- Monitor `Eclipse-Community/r3dfox` for its next maintained baseline. Do not migrate, rebase, or retarget this project to r3dfox 154-or-later until r3dfox itself publishes that baseline and the user explicitly decides to evaluate the upgrade.

### Documentation maintenance
After a meaningful experiment:
- Append the evidence and conclusion to `docs/gost/TEST_LOG.md`.
- Update `docs/gost/PROJECT_STATE.md` only when the current understanding, blocker, architecture, pinned dependency, or next experiment changes.
- Update `docs/gost/TODO.md` when a planned/deferred milestone is added, completed, reprioritized, or deliberately dropped.
- Keep failed/rejected approaches in the test log so future agents do not repeat them blindly.
