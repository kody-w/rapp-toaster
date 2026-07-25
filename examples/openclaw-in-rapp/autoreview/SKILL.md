---
name: "autoreview"
description: "Pre-commit/ship code review: Codex default; optional Claude or Pi."
---

# Auto Review

Run the bundled structured review helper as a closeout check. This is code review, not Guardian `auto_review` approval routing.

Codex review is the default when no engine is set. It uses `gpt-5.6-sol` with `high` reasoning by default, then retries once with `gpt-5.6-terra` only when the account cannot access Sol. Claude review is optional and uses `claude-fable-5` by default.

For user-visible behavior, pair autoreview with `behavior-validator`. Autoreview is source-aware and judges the change bundle; behavior validation is source-blind and judges the running product or tool against a behavior contract. A clean autoreview is not proof that a UI, CLI, API, or generated artifact works from the user's perspective.

Use when:

- user asks for Codex review / Claude review / Pi review / autoreview / second-model review
- after non-trivial code edits, before final/commit/ship
- reviewing a local branch or PR branch after fixes

Do not require autoreview for a change whose entire diff is prose-only internal notes or `SKILL.md` documentation. Still inspect the diff directly and run the repository's lightweight documentation validation, if any. This exception does not cover user-facing documentation, executable examples, configuration, scripts, generated files, or behavior changes.

## Contract

- Treat review output as advisory. Never blindly apply it.
- Verify every finding by reading the real code path and adjacent files.
- Read dependency docs/source/types when the finding depends on external behavior.
- Reject unrealistic edge cases, speculative risks, broad rewrites, and fixes that over-complicate the codebase.
- Prefer small fixes at the right ownership boundary; no refactor unless it clearly improves the bug class.
- When an accepted finding shows a bug class or repeated pattern, inspect the current PR scope for sibling instances before fixing.
- Fix the scoped bug class at once when practical; stop at touched surfaces, owner boundaries, and clear follow-up territory.
- Keep going until structured review returns no accepted/actionable findings only while the work remains inside the original task scope.
- If a review-triggered fix changes code, rerun focused tests and rerun the structured review helper.
- For security-audit suppression changes, verify accepted findings remain auditable: suppressed findings stay in structured output, active output keeps an unsuppressible suppression notice, and aggregate findings cannot hide unrelated active risk.
- Never switch or override the requested review engine/model except for the documented Codex Sol-to-Terra account-access fallback. Capacity, rate-limit, and unrelated failures keep the same engine/model.
- Be patient with large bundles. Structured review can take up to 30 minutes while the model call is active, especially with Codex tools or web search.
- Treat heartbeat lines like `review still running: ... elapsed=... pid=...` as healthy progress, not a hang. Let the helper continue while heartbeats are advancing. Pass `--stream-engine-output` when live engine text is useful; Codex and Claude filter tool/file chatter, other runnable engines pass raw output through.
- Do not kill a review just because it has been quiet for 2-5 minutes, or because it is still running under the 30-minute window. Inspect the process only after missing multiple expected heartbeats, after 30 minutes, or after an obviously failed subprocess; prefer letting the same helper command finish.
- Tools are useful in review mode. Codex receives the validated bundle in an empty workspace so ignored files and linked-worktree metadata remain unreadable; web search stays available for dependency contracts and upstream docs.
- Security perspective is always included, but it should not cripple legitimate functionality. Report security findings only when the change creates a concrete, actionable risk or removes an important safety check.
- Reviewer subprocesses preserve engine authentication and non-credentialed proxy variables needed by headless or restricted-network environments while stripping process-injection, Git override, and credentialed proxy values.
- Before engine invocation, autoreview runs TruffleHog over temporary snapshots of the exact added or modified content under review. It intentionally matches TruffleHog's low-false-positive pre-commit policy (`verified,unknown`); it does not classify arbitrary password-like strings or rescan unchanged history. Install TruffleHog using its official platform-neutral instructions; autoreview fails with that link when the binary is unavailable and never auto-installs it. Repositories should also run TruffleHog in pull-request CI as a backup outside autoreview; repository-local Git hooks are optional. Review bundles still omit security-sensitive paths or files, and explicit prompt and dataset inputs remain checked before engine invocation. Safe large diffs are sent as one pass while they fit the aggregate prompt limit, then partitioned into complete bounded passes without truncation.
- For regression provenance, keep roles separate: blamed code author, blamed PR author, PR merger/committer, current PR author, and PR/date. If no blamed PR is traceable, use the blamed commit as the provenance: commit SHA, date, and author username. Do not guess a merger or frame missing PR metadata as a separate finding.
- If the blamed PR was merged by `clawsweeper[bot]` or another automation, identify the human trigger when practical. Check timeline/comments first; if rate-limited, use gitcrawl/cache or public PR HTML. Look for maintainer commands such as `@clawsweeper automerge`, `/landpr`, or labels/status comments that armed automerge. Report `automerge triggered by @login`; if not found, say trigger unknown.
- Do not invoke built-in `codex review`, nested reviewers, or reviewer panels from inside the review. The helper builds one validated bundle, calls the selected engine once for normal inputs or once per complete bounded chunk for oversized inputs, validates the structured results, and stops.
- Stop as soon as the helper exits 0 with no accepted/actionable findings. Do not run an extra review just to get a nicer "clean" line, a second opinion, or clearer closeout wording.
- Treat the helper's successful exit plus absence of actionable findings as the clean review result, even if the underlying Codex CLI output is terse.
- Multi-reviewer panels are opt-in only. Use them when explicitly requested or when risk justifies the extra spend; the main agent still verifies every accepted finding before fixing.
- If rejecting a finding as intentional/not worth fixing, add a brief inline code comment only when it explains a real invariant or ownership decision that future reviewers should know.
- If `gh`/Gitcrawl reports `database disk image is malformed`, run `gitcrawl doctor --json` once to let the portable cache repair before retrying review; do not bypass the shim unless repair fails and freshness requires live GitHub.
- If Gitcrawl reports a portable manifest mismatch, source/runtime DB health error, or stale portable-store checkout, run `gitcrawl doctor --json` and inspect `source_db_health`, `runtime_db_health`, and `portable_store_status` before falling back to live GitHub.
- Do not push just to review. Push only when the user requested push/ship/PR update.

## Scope Governor

Autoreview is a closeout gate, not permission to rewrite the task.

Before the first review, freeze a scope baseline: original request or issue, target branch, intended behavior, owner boundary, changed files, and non-test LOC. For inherited or already-bloated branches, use the intended PR diff as the baseline rather than accepting all existing branch drift.

Before patching a finding, classify it:

- **In-scope blocker**: the finding is introduced by the current diff, affects the same owner boundary, and can be fixed without changing the task's contract.
- **Follow-up**: the finding is real but belongs to an adjacent bug class, sibling surface, cleanup, or broader hardening track.
- **Stop-and-escalate**: the finding requires a new protocol/config/storage/public API contract, a different owner boundary, a release-process change, or a design choice outside the original request.

Stop patching and report the scope break instead of continuing when:

- a narrow PR turns into an architecture change, protocol change, migration, or release-process change;
- the diff grows past 2x the original files or non-test LOC without explicit approval to expand scope;
- two review-triggered patch cycles have not converged; pause and reclassify every remaining finding before another edit;
- the best fix is "define the canonical contract first" rather than another local inference layer;
- fixing the accepted finding would make the PR no longer describe the same behavior, issue, or owner boundary.

After the two-cycle pause, continue only when every remaining accepted finding is still an in-scope blocker. Otherwise preserve the useful analysis, identify the smallest safe landed subset if one exists, and open or request a follow-up for the larger fix. Do not keep committing speculative fixes just to satisfy the reviewer.

Do not stack or push review-triggered fix commits while scope classification or focused proof is unresolved. Keep exploratory edits local until the cycle is proven in scope; if scope breaks, remove them from the landing lane instead of preserving them as branch history.

Critical exceptions must be explicit: active data loss, crash, broken install/upgrade, release blocker, or concrete security exposure. If the exception is not one of those, it is not critical enough to blow up scope.

## Release Branches And Release Process

On release, beta, stable, hotfix, signing, notarization, appcast, package-publish, or release-check work, use freeze discipline even when the branch name is not release-like:

- Fix only release blockers, failed release infrastructure, exact backports, install/upgrade breakage, data loss, crashes, or concrete security exposure.
- Treat non-blocking autoreview findings as follow-ups for `main`, not reasons to broaden the release branch.
- Do not introduce new product behavior, config surface, protocol shape, migration, plugin ownership, docs narrative, or process policy unless it directly unblocks the release.
- Keep proof tied to the release target: exact branch/ref, failing check or shipped-risk reason, smallest command/proof, and whether the fix must also forward-port to `main`.
- If review discovers a real but non-critical design problem during release closeout, stop with a follow-up issue/PR plan; do not use the release branch as the refactor lane.

## Skill Path (set once)

Set the skill script paths once, then use `"$AUTOREVIEW"` and `"$AUTOREVIEW_HARNESS"` in the examples below.

Choose one:

```bash
# Project-local skill in the current repo for Codex and other agents:
export AUTOREVIEW=".agents/skills/autoreview/scripts/autoreview"
export AUTOREVIEW_HARNESS=".agents/skills/autoreview/scripts/test-review-harness"
```

```bash
# Claude Code project-local skill in the current repo:
export AUTOREVIEW=".claude/skills/autoreview/scripts/autoreview"
export AUTOREVIEW_HARNESS=".claude/skills/autoreview/scripts/test-review-harness"
```

```bash
# Source checkout of openclaw/agent-skills:
export AUTOREVIEW="skills/autoreview/scripts/autoreview"
export AUTOREVIEW_HARNESS="skills/autoreview/scripts/test-review-harness"
```

```bash
# Global skill:
export AGENTS_HOME="${AGENTS_HOME:-$HOME/.agents}"
export AUTOREVIEW="$AGENTS_HOME/skills/autoreview/scripts/autoreview"
export AUTOREVIEW_HARNESS="$AGENTS_HOME/skills/autoreview/scripts/test-review-harness"
```

When using Claude Code, set `AGENTS_HOME="$HOME/.claude"` for global skills.

On native Windows, choose the matching pair:

```powershell
# Project-local skill in the current repo for Codex and other agents:
$AUTOREVIEW = ".agents\skills\autoreview\scripts\autoreview"
$AUTOREVIEW_HARNESS = ".agents\skills\autoreview\scripts\test-review-harness.ps1"
```

```powershell
# Claude Code project-local skill in the current repo:
$AUTOREVIEW = ".claude\skills\autoreview\scripts\autoreview"
$AUTOREVIEW_HARNESS = ".claude\skills\autoreview\scripts\test-review-harness.ps1"
```

```powershell
# Source checkout of openclaw/agent-skills:
$AUTOREVIEW = "skills\autoreview\scripts\autoreview"
$AUTOREVIEW_HARNESS = "skills\autoreview\scripts\test-review-harness.ps1"
```

```powershell
# Global skill:
$AgentsHome = if ($env:AGENTS_HOME) { $env:AGENTS_HOME } else { Join-Path $HOME ".agents" }
$AUTOREVIEW = Join-Path $AgentsHome "skills\autoreview\scripts\autoreview"
$AUTOREVIEW_HARNESS = Join-Path $AgentsHome "skills\autoreview\scripts\test-review-harness.ps1"
```

## Pick Target

Dirty local work:

```bash
"$AUTOREVIEW" --mode local
```

Use this only when the patch is actually unstaged/staged/untracked in the
current checkout. `--mode uncommitted` is accepted as an alias for `--mode local`.
For committed, pushed, or PR work, point the helper at the commit
or branch diff instead; do not force dirty modes just
because the helper docs mention dirty work first. A clean local review
only proves there is no local patch.

Branch/PR work:

```bash
"$AUTOREVIEW" --mode branch --base origin/main
```

Optional review context is first-class. Prompt files and datasets must be repo-relative so review bundles cannot pull arbitrary host files:

```bash
"$AUTOREVIEW" --mode branch --base origin/main --prompt-file review-notes.md --dataset evidence.json
```

If an open PR exists, use its actual base:

```bash
base=$(gh pr view --json baseRefName --jq .baseRefName)
"$AUTOREVIEW" --mode branch --base "origin/$base"
```

Committed single change:

```bash
"$AUTOREVIEW" --mode commit --commit HEAD
```

Use commit review for already-landed or already-pushed work on `main`. Reviewing
clean `main` against `origin/main` is usually an empty diff after push. For a
small stack, review each commit explicitly or review the branch before merging
with `--base`.

## Oversized Bundles

The helper scans the full patch before partitioning it. A safe bundle that fits
the aggregate prompt limit remains one integrated review pass. Larger bundles
are split at bundle sections and file boundaries where possible; an oversized
single-file block is split at line boundaries with repeated file/hunk context
and an absolute new- or old-file line offset. Untracked snapshots use
injection-safe source-line records so continuation passes retain reportable
locations. A single physical diff line split across passes also retains its
original addition, deletion, or context marker.
Every original bundle byte appears exactly once across the pass sequence, and
all validated reports are merged before required-finding and exit-status checks.
The helper caps one run at eight bounded passes so an unexpectedly huge branch
cannot create unbounded model calls; split still-larger work into coherent review
targets.

Chunking makes large-diff review usable, but it cannot give one model call every
cross-file implementation detail. For architecture-heavy changes, still prefer
a coherent branch or PR shape whose semantic decision surface fits one pass.
Removing verified non-authoritative generated noise remains useful, but never
drop lockfiles, generated clients, policies, manifests, schemas, or other
independently semantic artifacts merely to shrink the review.

## Parallel Closeout

Format first if formatting can change line locations. Then it is OK to run tests and review in parallel:

```bash
"$AUTOREVIEW" --parallel-tests "<focused test command>"
```

On Windows, the default `--parallel-tests` shell preserves the platform `cmd.exe`
semantics used by Python `shell=True`. Use `--parallel-tests-shell powershell`
or `--parallel-tests-shell pwsh` when the focused test command is PowerShell-specific.
Parallel tests inherit only a small allowlist of ordinary OS, CI, and toolchain
variables. Put additional non-secret project controls directly in the test command.
Home and standard config directories point to a temporary isolated root that is
removed after the command exits. Do not put secrets in the command because it is
printed before execution. Set `OPENCLAW_TESTBOX=1` on the autoreview process, not
inside the test command, because the environment snapshot and credential staging
happen before the test shell starts:

```bash
OPENCLAW_TESTBOX=1 "$AUTOREVIEW" --parallel-tests "pnpm check:changed"
```

On POSIX, the helper puts this isolated Testbox home under the short, sticky
system `/tmp`; Blacksmith creates an SSH control socket below that home, and a
long macOS `TMPDIR` can exceed the Unix-socket path limit. With an older helper,
prefix the outer autoreview process with `TMPDIR=/tmp`. Setting `TMPDIR` inside
the quoted test command is too late because the isolated home already exists.

This is the narrow trusted-maintainer-code exception: it stages only the Blacksmith
credential file into the temporary home so the command can delegate remotely. Never
use this credential-hydrated path for untrusted contributor or fork code. Run other
secret-bearing or credentialed tests separately in an appropriately isolated remote
runner.

Tradeoff: tests may force code changes that stale the review. If tests or review lead to code edits, rerun the affected tests and rerun review until no accepted/actionable findings remain. Once that rerun exits cleanly, stop; do not spend another long review cycle on redundant confirmation.

## Review Panels

Run multiple reviewers against one frozen bundle:

```bash
"$AUTOREVIEW" --reviewers codex,claude,pi
```

`--panel` is shorthand for Codex plus Claude unless `--engine` changes the first reviewer:

```bash
"$AUTOREVIEW" --panel
```

Set reviewer models and thinking/effort explicitly:

```bash
"$AUTOREVIEW" --reviewers codex,claude --model codex=gpt-5.6-sol --thinking codex=high --model claude=claude-fable-5 --thinking claude=max
```

Inline syntax is also supported for simple model IDs:

```bash
"$AUTOREVIEW" --reviewers codex:gpt-5.6-sol:high,claude:claude-fable-5:max
```

For models with slashes or extra colons, prefer keyed form:

```bash
"$AUTOREVIEW" --engine pi --model anthropic/claude-sonnet-4 --thinking high
"$AUTOREVIEW" --reviewers codex,pi --model codex=gpt-5.6-sol --model pi=anthropic/claude-sonnet-4
```

`--reviewers all` covers Codex, Claude, and Pi. Droid, Copilot, Cursor, and OpenCode selections fail closed because their current CLI contracts cannot confine project instructions, filesystem reads, or network fetches to the review boundary.

## Models and thinking

The helper accepts `--model` globally or per engine (`engine=model`) and `--thinking` globally or per engine (`engine=level`). Repeat either flag for multiple reviewers.

Recommended model defaults:

| Engine              | Default model                                      | Source note                                           |
| ------------------- | -------------------------------------------------- | ----------------------------------------------------- |
| **codex** (default) | `gpt-5.6-sol` -> `gpt-5.6-terra` on access failure | OpenClaw org review default                           |
| **claude**          | `claude-fable-5`                                   | Anthropic's most capable widely released Claude model |

CLI flags and environment variables override these defaults. Pi does not get a built-in model default because its provider catalog may vary by installation. Droid, Copilot, Cursor, and OpenCode are currently refused.

| Engine              | Model flag                 | Example model IDs                                                            | Thinking flag                 | Accepted levels                                            |
| ------------------- | -------------------------- | ---------------------------------------------------------------------------- | ----------------------------- | ---------------------------------------------------------- |
| **codex** (default) | `codex --model X exec ...` | `gpt-5.6-sol`, then `gpt-5.6-terra` on Sol access failure                    | `-c model_reasoning_effort=Y` | `none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max` |
| **claude**          | `claude --model X`         | `claude-fable-5`, `claude-opus-4-8`, `claude-sonnet-4-6`, `claude-haiku-4-5` | `--effort Y`                  | `low`, `medium`, `high`, `xhigh`, `max`                    |
| **droid**           | currently refused          | Factory model IDs                                                            | `-r, --reasoning-effort Y`    | `off`, `none`, `low`, `medium`, `high`, `xhigh`, `max`     |
| **copilot**         | currently refused          | Copilot model aliases                                                        | not supported                 | n/a                                                        |
| **pi**              | `pi --model X`             | `anthropic/claude-sonnet-4`, `openai/gpt-4o`                                 | `--thinking Y`                | `off`, `minimal`, `low`, `medium`, `high`, `xhigh`         |
| **cursor**          | currently refused          | Cursor model aliases                                                         | not supported                 | n/a                                                        |
| **opencode**        | currently refused          | OpenCode provider/model IDs                                                  | not supported                 | n/a                                                        |

Claude also supports `--fallback-model a,b` for availability-based fallback chains ([model-config](https://code.claude.com/docs/en/model-config)). Current Claude docs note that auth, billing, rate-limit, request-size, and transport errors do not trigger fallback, and the changelog documents interactive-session support in `v2.1.166`.

[OpenAI's model guidance](https://developers.openai.com/api/docs/guides/latest-model) identifies Sol as the GPT-5.6 frontier-capability route and documents `max` support. Autoreview keeps `high` as its default; use `max` only for the hardest quality-first reviews after comparing its latency and cost with `xhigh` on representative changes.

Examples matching current `main` behavior:

```bash
# Codex with explicit model and reasoning
"$AUTOREVIEW" --engine codex --model gpt-5.6-sol --thinking high

# Codex fast mode (priority service tier); needs a model whose catalog lists the tier, silently standard otherwise
"$AUTOREVIEW" --engine codex --codex-speed fast

# Safe Codex model/response tuning overrides (--codex-speed wins over a service_tier here)
"$AUTOREVIEW" --engine codex --codex-config 'service_tier="fast"'

# Claude Code aliases or full model names, with optional availability fallback
"$AUTOREVIEW" --engine claude --model claude-fable-5 --thinking max
"$AUTOREVIEW" --engine claude --model claude-fable-5 --fallback-model claude-opus-4-8,claude-sonnet-4-6

# Pi with explicit model and thinking level
"$AUTOREVIEW" --engine pi --model anthropic/claude-sonnet-4 --thinking high --pi-bin pi

```

`--cursor-agent-bin` and `CURSOR_AGENT_BIN` remain compatibility aliases for
`--cursor-bin` and `CURSOR_BIN`.

### Environment defaults

CLI flags take precedence over environment variables.

Store persistent personal defaults in your shell startup file or launcher
environment. For repository-local defaults, use an existing local environment
loader such as an untracked `.envrc`; the helper does not write a config file.

| Variable                           | Purpose                                                                                                                          |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `AUTOREVIEW_MODEL`                 | Override the built-in default `--model` for all engines                                                                          |
| `AUTOREVIEW_THINKING`              | Default `--thinking` for all engines                                                                                             |
| `AUTOREVIEW_FALLBACK_MODEL`        | Default Claude `--fallback-model` chain                                                                                          |
| `AUTOREVIEW_<ENGINE>_MODEL`        | Per-engine model override, for example `AUTOREVIEW_CODEX_MODEL=gpt-5.6-sol`                                                      |
| `AUTOREVIEW_<ENGINE>_THINKING`     | Per-engine thinking override                                                                                                     |
| `AUTOREVIEW_CODEX_CONFIG`          | Safe Codex model/response tuning overrides, semicolon-separated, e.g. `service_tier="fast"`; capability-bearing keys fail closed |
| `AUTOREVIEW_CODEX_SPEED`           | Codex service tier override: `fast` (priority), `flex`, or `default`; silently standard when the model does not list the tier    |
| `AUTOREVIEW_CLAUDE_FALLBACK_MODEL` | Claude-only fallback chain                                                                                                       |
| `AUTOREVIEW_PROVIDER_ENV_ALLOW`    | Comma-separated custom Pi/OpenCode credential variable names; names must end in a recognized credential suffix                   |

Codex maps thinking to `model_reasoning_effort`. Claude maps thinking to `--effort`. Pi maps thinking to `--thinking`. Only Claude accepts `--fallback-model`; global CLI/env fallback requires at least one Claude reviewer, and engine-specific fallback overrides require that reviewer to be selected. Non-Claude fallback overrides, including `AUTOREVIEW_<NONCLAUDE>_FALLBACK_MODEL`, fail closed instead of being silently ignored.

## Review engine isolation

When autoreview runs inside the repository under review, external reviewer CLIs must not load project-local trust or configuration that the branch controls.

| Engine       | Isolation flags                                                                                                                                                                                  | Reference                                                                   |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| **codex**    | Auth-only config overrides, isolated workspace, `exec --ignore-user-config --ignore-rules --skip-git-repo-check`, plus read-only sandbox                                                         | Codex CLI `exec --help`                                                     |
| **claude**   | `--safe-mode --setting-sources user --strict-mcp-config --disallowedTools mcp__*`; auto-memory and filesystem/shell tools disabled; empty external workspace; WebSearch by default (`v2.1.169+`) | Claude Code [CLI reference](https://code.claude.com/docs/en/cli-reference)  |
| **droid**    | Fails closed: current CLI cannot disable both project instructions and all tools                                                                                                                 | Droid CLI `exec --help` and `--list-tools`                                  |
| **copilot**  | Fails closed: repository read tools also expose ignored files outside the reviewed bundle                                                                                                        | GitHub Copilot CLI command reference                                        |
| **pi**       | `--no-approve --no-session --no-context-files --no-extensions --no-skills --no-prompt-templates --no-themes --no-tools`                                                                          | Pi CLI `--help`; requires Pi `v0.79.0+`                                     |
| **opencode** | Fails closed: project/global config isolation and private-network fetch denial are not both proven                                                                                               | OpenCode CLI contract                                                       |
| **cursor**   | Fails closed: documented read permissions can target absolute host paths and no proven repository-only filesystem sandbox is exposed                                                             | Cursor CLI [permissions](https://cursor.com/docs/cli/reference/permissions) |

Codex `--ignore-user-config` skips config loading for the exec run. Autoreview reconstructs only the documented `cli_auth_credentials_store`, `forced_login_method`, and `forced_chatgpt_workspace_id` settings from `CODEX_HOME/config.toml`, keeping authentication usable without forwarding unrelated user configuration. Codex runs in an empty temporary workspace: the validated bundle is its sole repository input, ignored files and linked-worktree metadata remain unreadable, and the zero project-doc budget keeps workspace instructions out of the prompt. `--ignore-rules` skips user/project execpolicy rules. Claude `--safe-mode` disables project hooks, skills, plugins, MCP servers, and CLAUDE.md; autoreview supplies WebSearch by default, permits only explicitly domain-constrained WebFetch rules, and exposes no filesystem or shell tools. Pi runs from a neutral temporary directory with project resources disabled and `--no-tools`. Droid, Copilot, Cursor, and OpenCode fail closed because their current CLI contracts cannot isolate untrusted review input from host, project, or private-network trust surfaces.

Codex uses a named permission profile that grants read access only to an empty temporary workspace. This is narrower than repository-root access, which would expose ignored credentials, and narrower than the legacy `read-only` sandbox, which permits reads across the host filesystem.

## Context Efficiency

Run the helper directly so target selection, engine choice, structured validation, and exit status all stay in one path. If output is noisy, summarize the completed helper output after it returns; do not ask another agent or reviewer to rerun the review.

## Helper

After setting `AUTOREVIEW` and `AUTOREVIEW_HARNESS` above:

```bash
"$AUTOREVIEW" --help
```

The smoke harness has thin shell wrappers over a shared Python implementation:

```bash
"$AUTOREVIEW_HARNESS" --fixture benign --engine codex
```

On native Windows, invoke the extensionless Python helper through Python:

```powershell
python $AUTOREVIEW --help
```

and the smoke harness:

```powershell
& $AUTOREVIEW_HARNESS -Fixture benign -Engine codex
```

The helper:

- chooses dirty local changes first
- accepts `--mode uncommitted` as an alias for `--mode local`
- otherwise uses current PR base if `gh pr view` works
- otherwise uses `origin/main` for non-main branches
- does not fetch automatically during branch review; the selected base ref must already resolve locally
- recognizes `--engine droid`, `copilot`, `cursor`, and `opencode` only to fail closed with isolation errors; runnable engines are `codex`, `claude`, and `pi`; default is `AUTOREVIEW_ENGINE` or `codex`
- resolves bare `git`, `gh`, reviewer, and PowerShell shell commands from absolute `PATH` entries only, never from the reviewed checkout; explicit `--*-bin` paths are interpreted from the reviewed repository root when relative and accepted only when both the supplied path and resolved target stay outside the reviewed repository
- use `--mode commit --commit <ref>` for already-committed work, especially clean `main` after landing
- scans safe Git patches in full, recognizes synthetic fixture values tied to their credential field, reviews them in one pass up to the aggregate prompt limit, and automatically uses complete bounded passes above it
- should be left in `--mode auto` or forced to `--mode branch` for PR/branch work; do not force `--mode local` after committing
- writes only to stdout unless `--output`, `--json-output`, or live streamed engine stderr is set
- supports `--dry-run`, `--parallel-tests`, `--parallel-tests-shell`, `--prompt`, repo-relative `--prompt-file`, repo-relative `--dataset`, `--no-tools`, `--no-web-search`, repeatable Codex-only safe model/response tuning with `--codex-config key=value`, Codex-only `--codex-speed fast|flex|default`, and commit refs
- supports `--stream-engine-output` or `AUTOREVIEW_STREAM_ENGINE_OUTPUT=1` for live engine text while preserving structured validation; Codex and Claude hide tool/file event details, emit compact activity summaries, and report usage at turn completion
- supports opt-in review panels with `--panel` / `--reviewers`, plus per-engine `--model`, `--thinking`, and Claude `--fallback-model`
- uses built-in defaults `codex=gpt-5.6-sol` with `high` reasoning and an access-only `gpt-5.6-terra` retry, plus `claude=claude-fable-5`; honors `AUTOREVIEW_MODEL`, `AUTOREVIEW_THINKING`, `AUTOREVIEW_FALLBACK_MODEL`, and per-engine `AUTOREVIEW_<ENGINE>_MODEL` / `AUTOREVIEW_<ENGINE>_THINKING` environment overrides when CLI flags are omitted
- gives Codex the bundle in an empty workspace with web search available; Claude receives the bundle plus WebSearch by default and optional domain-constrained WebFetch, and Pi receives the bundle with no tools
- runs Claude with `--safe-mode` (`v2.1.169+`), `--setting-sources user`, MCP and auto-memory disabled, no filesystem/shell tools, an empty external workspace, and `--fallback-model` when set
- refuses Droid, Copilot, Cursor, and OpenCode reviews until their CLIs expose the required project, filesystem, and network isolation
- runs Pi `v0.79.0+` from neutral temporary directories with `--no-approve`, `--no-session`, disabled Pi context/resource loading, and `--no-tools` because its built-in read tools are not repository-confined
- prints `review still running: <engine> elapsed=<seconds>s pid=<pid>` to stderr at long-running intervals while waiting for the selected review engine, unless streamed output or compact Codex activity has been visible recently
- prints `autoreview clean: no accepted/actionable findings reported` when the selected review command exits 0
- exits nonzero when accepted/actionable findings are present

## Final Report

Include:

- review command used
- tests/proof run
- findings accepted/rejected, briefly why
- the clean review result from the final helper/review run, or why a remaining finding was consciously rejected

Do not run another review solely to improve the final report wording. If the final helper run exited 0 and produced no accepted/actionable findings, report that exact run as clean.

## Parameters

The typed contract this capability answers to (JSON Schema — the deterministic layer):

```json
{
  "type": "object",
  "properties": {
    "autoreview": {
      "type": "string",
      "description": "Derived from `$AUTOREVIEW` used in the documented command at line 86."
    }
  },
  "required": []
}
```

## Deterministic steps

Lifted verbatim from the procedure above by `toaster.py toast`. Run them in order, substituting the typed parameters; do not paraphrase:

```bash
gh
gh pr view
git
gh
python $AUTOREVIEW --help
```

<!-- toaster:generated:begin -->

## Parameters

The typed contract this capability answers to (JSON Schema — the deterministic layer):

```json
{
  "properties": {
    "autoreview": {
      "description": "Derived from `$AUTOREVIEW` used in the documented command at line 86.",
      "type": "string"
    }
  },
  "required": [],
  "type": "object"
}
```

<!-- toaster:generated:end -->

<!-- rci-capsule:v1:H4sIAAAAAAAC/9R9CZPiyNXgXyH6c6w9Q1HcV7fHsUIIEPd9uR2NQEIS6EIHl2f++76XmRKiunqmPR57dyvs6SqQ8nj57iv/+UEKfM12P3y0AsN4+SArrn6WfN22Pnz8+z8/HHVL/vDxg2Kdz5L74eWDoVvKh4+V0ssHR3IlE76C121XOevKBb727aMCL374EzebDsbCXBQWH375B47q7VzdocN+GLpKamebpu6nPU13EjtbVhJ0jI8JHv64JmRlLwWG/ylhk5ckI8EbUgCP2W5iqL/CVMpVMh1D8WCZMIFmm4ojqUq4DR2++/Dxnx8MyVJhRucGe7TgLc9XHI/sbGfixlQt2lSh8MvL4+OE4ybYptjXmWrse91/fJHNx198/3O6gEQMLolUSlMMJ3o8Xy398o9fYOWW57vBDncNC/3wPwkOAJwYE+h8tj5b48BK+JqS2AaWbChygj4duPArBWECh1XchOQlpMTOsD3FDvzETlN2x9fEVNO9BPwvBvKXhGX7iWYgubIuWYkNHugX+tUmITmOa58B/C4MolvqKy6BHhGbDQbD5bADS1w0xYIBE4qlwrbwW0/xXxOinwg8xUtsVMdPFV9LKc82NomL7muJjaar2gaGkzzbgikS21s42gsObcFXvqvDy7a1U9g74TC+4rrSBr4xbnRqXIu029mBBXuWLNwa/Kl4XmJiG68hFj3WHuGXZMlsiTvyTGovbQ0lVdzE1kN23wAUhAfd1Fn3dHgksVU06azb7kvCkXSAe0QQbK3h9ymAoy5L8O3mlZzqYxWeHbg7JSVdJFchKzkEsqpQyO40wOHwvD9FsyXYaLD62AhbQCb57QhuYBHAwlHKgCtIQ75tw5ZVCbEN0CQadGdbvivt4MQ4wB0F8EF6WijCE4ax9zCwhG/OxJcE34X/cEP4D4ygKpbiSj6go+T6+h7GSlxs9+gl9q5tkuUg8P7sJQBHPUcBRD8rBK4zTyFH+BH/SJGnAIfxRRj1CeXSb44xDSzh8XtswWlAPtiRnDLhdYM9goNLe0Ac2IyVAsw663D8hCAUWfe9F4AGTKkk9jrgRTrGqPBNOgZCU0oY9g7e3LqStdMIYxqHf9Dx9/pV8XA3dZsAzlVOgY4H/Fgh7k0Kj/iiAbEC5fj4kKzv9whxgLanpAiC6xaMirgKgyE5uInNpCN2u6+mvEnI9i4w4V2CEa+Jia8bBrxBQEwpFAeUYeidD2MhiriMlbiKY3s6rOkGx2IANfoXBf/7PGYM4V4S+h5GuDF+olx3CiEjeEGhOLKzzwojE0ABBNfTWC/wjrILfCSxRMjJXxD79roauOwZKjPg8wdO7XXyIGz9gbIEeB7Bof/5H8AUisEUi6bAVvwQN4CFOcAKkTHKQLyw39dEX8GFErJBqDgOwhkJPZWYgyjc3xL4wA2RQWbMCYYkv1LQhbjjSEDrCFVJPkg72ChdKxlpDG8AD3EUS1as3Q1h4aUpxab9mwMwi3hXOA99GnkewIcde7hlNuYBTzawcAm65+s7QF9Aop3kIYTw3ANDQupKuDqQEaC1a0soJC6u7uMjuFiCopSW8cRQLDuGvgNYU94DO9vCgGRGENt7gJVnSoBZ9EWJopZLsMW+wCkRgb4F9itL7u0TSgJ4C44DmaZlIB/WfcJZXAS0idKFcaltoMIXkkdBtkCAIPvZIW6Rk6eA8TT7gpItehyRATBYIfgBp4DAennC/F3gunggQJ/eznYUQnXIu3E85IBAs7CIiOyvVNClEg39SgYgb8mxKRFcRBjhKh1EN4CZ8QmEse0QoNgBCFwQzoELmycYi8AJAaOH4CeAgOUYhn1JBU4CxRkhRDJ9R1GchGrjKkGc6cY7sh5EY+BaSHMRpNISUR4IaTGgeaGABIwkG0KODO+ayP8RArpMP7fhJJHrJXzgvHTbZCUikDubEjmmqiouOZJrSH0EU17gEeQpeyB1D74HLPM9ymmUkNd8S12h8MZzAbwFGNxSwOEBVbwANBBAG+QubK6XxJlS5lvc8NiWEuRVBMDH6P34U3DgyEzja6GsAQ6FyKOQUxzhAHADAP5oHQjW+KKA2+k7hR6npKquoiLxRHMxHURDCCOtGlQ07iLCJBunXMgDfYFKEqRFNzwUFBsAyQfEqG6VpkKNMl+C0oTLMzYLT1OZCWpPyrdTU1SUQs0oxVSiPVDyVkK9kJccYNP+DY4QFpgydJB5dE+PRe8l3QBgeQQs9DAlU3laDdlMjTBDHSmOKECG5Eb6i4eS6S0GAIwA4Y4AIBjWTuQzCVO3Ap+wxRBj6WZ3yHpA4lD4gRRBIgfxjciNU9Eto3JD2MJF2QI+Se5Oe30IAw0+8Lf4GyreKPBg5g1bikfEJlOYPiZeX18TsHsH0Ocn/N3Ryb8blCEwjuFrNxTQKiID1aOlBCLpa6KrUN7DlHHUq2BPCttRtAbYCioE8hlYEHKdxBDZyyaVAtxUJDNFgZui+Lih/MZA1GH6tQ/CAQEC9LYPgAFRAOC5MRUJhBCqIgiSNAokJCJkkcCRYHku2SqVwmRA0DdwAa4USUtfA9VfpQBkeswRYRTyA1A0QYXcKjsJ1oDMXZOQlcI6QdlRKGLmUsXwSJnsjp5G1TUOc8A3WaGonM+k6EtwtpZsX8CKiDF1ADvBYcLZqL5l6kCSMIQJqrruEM0CHwdEe8D7hT37QDKyIvoh4KG9BQkbeDAmojth4Vs21SeYk0hAQ/H9UAEgJBAdsmlSoWrpHkM5gop4xvSEkO0wuCFGv0aK7U7RQ0HI9CwicJBm8B1YmWI6/o3q0kCrMLOd0FXLdkOtiJw6oPRRkVP4FCAQkI3iSzCWFHJGoi7IeOCfYtRBOCIMcIYtU7kBIInpK6FVQOcIHIqcRI0hu5wwnh3X6QmZGhccV7d2BuCiDCoIIBQydc0ODJkqiqDi4VEZCtjUukl4Z2BRCWbAkK+g6Di260dy4SuZxhQnpkPvkMYVYvqChAbxqFCmzgQiclyqMJhE8QC4ghIC40vArTxpr8AE1FSmOhaeFHLmCAmQQoDaFfdBg+hAQaV9R9VkBBFaFjC5jB9LiEXw9vUGJ+vquAyQ1wp8KaM2CagpE72IrAogqyPGpizFJ0Jasc66a1vI0kN2iM84DjPocE0p3UJdkOjMTd2PpAfTMd5bhxEw1bRGlZ7QXLfO9o5p3zErBWjTA+4Z7PeG0rJVMgGwHgQcaHkJzwIOqdmwQGIXEo0eqFSScYuwLcB0fa/D74hHKBYojdPBiW9AJ5+TM4czBSyAM4jPiHYJaEggr8AWIsYKYpgT+ZESjg1a6y3xlw1RDWCul8A6WqB0bX74hBj3MExQfyPKg7vVfbJ85HgAazlFJAFCl2AXOY4dEf4Ut4CNgJ5NrAYRlUZgWjGYBIT16AQIex2FUsIBuQnQNeEwA5iKmGORb+fTkxkIhOdREUZ0cSTjB2pvQSWDdSKbtx40SvCM6A04UEqnS0L9mtIMsejQbcKoDWBnE5MvtmjgCE5gGCmmYiR4kbqNUCkAYQwigKiGj5V+ihmLKWr/IsZptn2kbC70p7wy4gnlPuPyNh5WpOJ5ihUeJVhPBObMwMPNAfeGQ9WJwwF4H/kMeZmnIMKAbIr0PUKxSE7fQGZQOoC0mSKCdjBdq4e4KCEjUajYi9QN5DJUzDxUOrYKphoRx5SDLg6cAOYGFLYTxHwCnkMVfWKPEJaBJ4teODh9iy0p1Hdh9FCVJMaQhcbIC9WxXJtATkFfqw/K7NYAaSNTe5O6bV/Cz8C2CT+BX00Fduoy3wWR9jEbKHwO4Tkcp1HUvKKGDzbEYzB06wHLVxDVXlB4UUwMF0CITvJCScyW/TH8ZtLiXvCsQr2YzEjcARYM8BoqEmqAjE9iyyXH76I8DQU52QkTYAQvQ1CEQiA0TmJrg3cu8CwZkjBY9OddvAvAU3H/vrX9f2yIwLeo/oOobYZODcIngTcQxS0wUS2lxs4bQw/ENmJcAgSWgkokATTh0Hvd9fxP6B556NEo+BCAIOB2oFgZ6Z20I7YW0B7YoDtccmva64LSCGREZC9itQ//fygVgAYBOpZAOfzfsQ3R9eNeNy+JTdqAJx13Q1Qa4BKK4aWBK/iBl4hWSP12LoIqejcSspvoo8TDzAMY/m/DBpLakI3hwe0RvV9AYN4iCDF+G9cTkQCPqPmDDgr8CU4i5sWDRVpxqwY0hxfKdJnMdSQL1k/dhjETNZQa04dyjRPIlIzf6k4vxGSgeOopBtUGGX8gFjxCG5Qok3BnwlPQ/MJvmEb3TM87DfZJXkIZ6Ol3Qvn43ks0t/e1oeuBRsq4GroImNZEnAXoukWtwYubC8oVBUmGSoTfsO0jakLeLhF3kfusnANjUhU0TSywVN3E5w/Es/v5AzGAXghZoZcUeDcorkgI6FVDzwRCIAwgoIQMKY4aUo/1/plgJ6oiqOLi4kH2AdJJW2CxAEpQC95zSrA9Uz9z5NDwiOMfBJuF2EYcxqguGDfkCFRd5rtiaJ4gn4KDoG6KHir+qbcYxMQSYiCqjK+JGeVmJqXqUMwYt5ilbTOSJ/oiAhGVCo8pNwhfD5XjT9Q0JS4HFbkrFXJMB/GY6/ArF9bXjiZgYS7x51HHcvig5MU1ozQeMhwDoAR99QVVLJTWIOb38CQeJxUOjNpjKjIcCW6UOHwk6rYE8kR91CIBgYfzTgaLmogjwin2AeLwg0ZDbQKJPVz6RtU26SbjbkRBcAF7N8i20XkIEheACLq9SowCIDVUihQZOACi7Cbki2hPoJ8wlTp4trWhVAi4azBTmqjpiECUf8I8GG5hwMQYEcGQUE+RKVFsb0SyE4rUdDN0QrKXqd5FbDZAPM2iXxEvvUftbNhWK9iGO/1qk9JjVcCl9T0qUSC9iAb7woIyaRe9dyDW6jXmNEiAfo4SGN1doLQ9tpZC/VKh+oyN/qhfBRCuO/RzbuhcX+TtFzoHygM28dOH+NImnO8Lme8LlRGbCDGBZRI8lVDG2V8BgvEbJ/C0iMGEbHmIHz5bZiSS8yAtfI2EU9Ig9wKHqB/Mdz8h3tkmslbgyfjhc5gsFs9UiXJBlqG4RF9AjLVD9zaZGJ2YZGhm5FD/OgjoKPIJp67cFeSAZGbEViSijw9HaKgZA9hhkgDm9FGL9Fmk54USKLHlojDgk6/39pIIzYeYbktCTzhud8C/Ej1Qt0Ad0RnvkQw002+prWFTYUYmw5dDTSyaFoBIIjuMmYZbQP1DI46UyIlOOIpB+LNH/mDBKhm4lR+Hk4PY+8SJXh52k+6zAN2PP4pWisENLIGj4v7448enGIZO2BcJOlI1Iu6Mx0WjM2av7Hzv4Up5CztiwcIWtoRfwjChKk2AGnph8KT/7D2il3R9jdCv/s7CCAdEdwQoSTYKI8AdhFQYvIl8/S9RpIA581+owAoc6srCoAqsWJNc0B7JelyJuQ9+/BFFfAq2kEJLEr2ob1cSMRsQzoDjoEr79s7GqCNGwtJInsA200xR5IZitEeU2whDhUDzK7DByLBKtJaZn4wiIXV2AY/3dBXtJlvfKZGZ9xQBYIhP8IJoKg+sIA59oi9GwRGAgyIdiYGLsS4Q+MzjiS/EorqwTQl43wXRlkYuiN2EkHdhdF8hKlO02BAe0QemrobRQaIrvrfHTzhRFPFUXYwXgRDwE7nr8xap28x2n6gxQrDI/IxyIGCh8CFR4nDPdJ6L/XVghIAqsbvtcHzgCgqLiVpnYpV8ggeQjikgI8qi2gI1aRFsb9SF0GLBIHW0xS2uGuMwgNKfP8jKnjiFkczgcQttlQhhKOsDre+JM7BBqSmvWwSddmgq3xSXzEJVjTCv4lmRuRBVwETXPX4PZwq6KpKTgu5DDN9ulQdpPxgk46Sh2hHhLUE2jrhiCVVf7BQBIoXXy8OL/hAwb4H21RojBzO6+t4wrNfEAHd/0T3l4dVjIgs1WQmw5Obp3hvTkERAEfAe9SoQPuwFW+KY2BM7hPBYxuthQotiKxUlUizgF4ZtiGuCZAxE6jzxADALnrCfWESXRl9D2evBhx5bW6iovcbyDkC8747U3gTh/H4Yj8wTeRgJkBhihn5NtM5ZYI9mgBB/FEDNNs6K/EqjlUg0wLLQPUSzKRhm0fglQUxyoDSxgej4FqMmBF2Ml3gvzElLVfUoewTBjeCAf5U4v2Hnx3DVRHnI5FvotSOpSyBiCVVEOQugkNIARkTwH8PwHPE7gMKBmQmu5GkkhH4kaya+tnTgADeicU/CiEK8ohYU8z8/PNcwgQ1ChHpbqCkRJk6w1BpEHeJDtRHdaXiEecnZsi0MxuChw1QXDJiFQVqiQI3ZOmpMX0hwgH/hh0PKJfHRgRUuGbNdfOkFcYR4ejTbB3xAoadaRPDD9GAl3EOnsOPsgJViqtPuCJIpRSQTgibGjon6SiIVVF9hWhaYATvdIcoJse4e/k16TugaCjccDoUuWSY6MBhP6P4NsOF0WKgm/ALYGBxXaH+/MHc0arNEaX95e34U4SSUL2+PnIWHfuUsH/YwShGyJsKHYs7dmL0bUT5Na9og29q8sC1jAhxRRKhSESbnsN0SID27V5huFaoOJLnrwWWpDvFQWyJh6mmS8yxLwVpX0TwOjcAXEtshslqikVbkHkzKMl/7I50jSioKLLJ/L77wRyYDyxvDQADsMb43qlJ/DA+K7DTtKnt6sghOilJoL8HqHEVOEcOcguzlwZCZsyxNpqLcF7CMiTvCNim1E184HMAFtLYU1WRsdhgPe5wcHiItcfWEVjPqjDS8w0iS6VIwJRCQmZADlyp2dGuhwfJCc0OIQycuAIgoREsIbHMrslpDLf/58EMdP8qoQR4Y2U4kKjvELKS/oCBC6/kHorwx89kjD9CcqtDfTlzNxJWNM24+xxN3P3+gFubzp19a3LgvTCb4rW6F0R6Sv0VU6Qtls5qNqWzAzgjxbjYbsEs0WCcyIfRzsNgBXRMbJ7QMULeMJf0REUp9tehj8WBEJD44s8eqfvr84ZV+myZDeukH/aVZGlnso88f3hkj3Nl3jYXaInM0pUD1R8cBDgobfbNfFobnSYrY9+39Wxukeal/zAZ/c6zv3uCE+B0ilwWKL1R40EedJmBM0Um+sas/Yjd/wC6ahr0NzyS20qbQn06+tAY9Aab50z9jf39M/Qn/STNU+eXdNeJLsXf+kKP7zgF/fecLSvLEo/pA0BfM1U5s3uyabpMiDFI9UqYaAxfNvASNwqK66YIka6AApUyAukiZ7Yhet5AlODY6FDXFMP4wxhDPr/8pERHy5890pZ8/x+D8mYHq6cMPT2OEYP8XxnoH7q+Ol33Guued/z4W8dVW2Qn9IVv9rrF+x1b/BWbxdn9/wLb+6N28YRp/4giCtGxQY39Ca+Yvf1Ks88cYOf2Q+Gfi7WeJXxKKAWTyz0TbBvuUCHBCczGU+5D45S1AYg/Hpv0DwPS7Bv5t4IGGMtRBhZsSVY8Yp7oLejRFdLQVnjWFN6pIIkVy+Onj0aA0kKO/TQWi7heaJhiQjJIAFX5VkdPsn4C4RI4keIevfLZC6gpR8xWT8MiUgRWG0eUNHZR5GCSSPiQZusSU+fgaUY9s2G4ieveFWN/4L60UoOaRA9B+ShRkcTX62meLeBipl5bUA1B7N9ITYdodGlYISZyb+gQ+W2GCXWxgotCbNJbE3iAJRsQr9Cj3oOcRVkoQuD5ytF1mn7GnCJyp45iq7Gxb33WSbFupFAkRUZ9cGjXw6HQHYWlOmCaK2UM03ZEsOkWzxVFyYGLGIwmOJYk8LHtkmSmSxooCygs9dlFuCkvSxVSYWF4QGOFs1H9vQ/ARzR1JkQRMRiakhuPVlOHbMKkFvsB8O+UVwzsRGDD32qJOJIBv6Fii6ZMhihO3//Mq8ZOf/vSXRyUbCxuRR8fKvo/WNnx0SrzGPvnhO7f3+QPb4J/wzxid8yG+J1C7MEJX7ndBkCWPpMKkrpbA1Z9onX0er51hgRLmhIt9QqmN4jjsmhl3LCsJlgYkTxCefhHVQm1iB7ehmbWUhUQZmDTaQpyUOAeN3kifLVoXQXxtL1GmtoR+YLrqWJw5SnOIuz+YmxezL8jyaPEYhfcmtPIGUdZBjeIufh5LhcCENWok7hGZKSfchmEdlq1EE9WQ5okDk2WZ0nAv4NRn69uJT1HRgG3RGJRK63LYdhxCkF3qzNyGKyS5VrB5H7kbm82jCYss+Ip08aiNQE6O67Vpuv0ngv/hxgHQBLEoMRF/A/HxhuMT/1J8LARjVB+CL6VJDgfjJrA6UjCHuQq2gcnGFhAncU0bMp2DjGjv96SQcRZJjkfWI9DiZyvKwUwRoLJ6PBqKU3a2ixk8dujBph5VlhzmKpjqw0Iq6IX7bBkscc0jh0QJydFuHnU4IAKSgdmmd67teeFoNM2PDInOGQ9lCIt3SLKsU3+PrBhKFEUJ+aopuUfiOBaITz16jZ3Y9gbAkRwApOtRTw1iMgYL2AKo6PUwYe0UKBYriviMOZ2xvJwocs5w/ZG2x2JhCHWW/kCSAHVQClkOE8pmNDdiCL+DQyDISLJfgMpIKdKb9DvPpkUcYT44LFwL1JDygBNQ/k9zh9GLxV5/FB14nxiwSSwhxdz1hLmwxD9NYdo5lZzUpeUxbwggHElMl46YV4BfpcgpMrIJPOp8ZenRbDkqqUSxnmofSLgDFowAp9iJlc7Ko0hPxpM3GFOKhdRSmiKdb48SGhoToQntcESPDTyVMxJPIatL9IDyMcv5kSDCPIuEaURJlLDjMfrtcb9hMi5xmNEkQN2nQvhR0mfZGH4J+QqNvFBQkOzWz5bs2g5qHEcWP3+8ujOwysR7oS5JUlUVZmHgFgFfTIk6cImdiEQaZrUj8kY7CitVSdqgAt9gUEVzMQk3lnIWqrGSi95GrEinrj1WFGxKLMSGqv+e/E3iNhi9ZsnphGhjtD1lmTnAvwYdkr2AVVKxqima+EASTcmcvyVGw+dSdJDPH/4ar8UK3aN/i8lrsNsjgz1ex715O9gmQeyeKE7G6J2lOCc2O1N+Va4KDBqClRwmifsPafX7hozw09QNQKCRLKyvZkmxSSI7a0N04G8+d/G0Tax48p3NInCHONwE30iRgqG9voPTjA6SAoslYLCCElbmKKGfFssriamKGXCoGQ4mLwlepP5lrKyB40W9NUrvxzQYP2K3pGAXxIKCIYTQwqdhWSwOibznzM6PLx5WScwvmjgooUyTQ78+fY+meDMzAthcLC1fB4FGWa5t+1S86yAOaFRNZipMaGyEvPaRTojZdXTNXuSCYA8+1e98thxXJwVnYfo1Ke2ladfoTxoMhT7f5RZfpsJkWhssf8pibheNKD+iJCy6QGIhSKhRRkIcHi+JuGUTq42IpPGbkgeEGlWnNBRdVrjGaGCKR/CU679R879eduI7CM6xHJMKqo8s7eeZ2IaDibh8iRtmJOnUp30Z2IFNYbCtfU1gV4tYQRTszyWBBDCkQQh4NzAGgfLSvulsPiVqBuglnonqTlQEYyUmk1aIaiAGQXGhGS8Xig84AUvRRqWDiKjdYJLYTHvDujjeEOaFUUokKljBzNKvKTYMKXgmSuErsBBS/Iw6E+bCkI29IGIoe1ZCC3xScd85b9Yjgc73E9kKQRvCOqNlUHSgiukpsP13aBzoMIHQe8KQCKIEksw0YDbUK1WdaT8MfJhlpvhugHlqqUcOdoo2BwiDtR9JCRM6EpjjAV9+QB+lc4R+VERbLN71oE2yHs9+oiqENSpmROlGKvUVI6xQ/2wFoa/jMXpKu8luWPasEXsIHRtk+fTQ9S0CnIbu3SPJDQUTCIQMk4eUvlNb0OkQ3qgMxquFKFKHSfeURaGqjAkxQPTss4jNkCUDgwksiyUgTDG8CqrzRzaUKd2Yz4KmqbLiYYKLNBMynuKNUXLy2sNeMjDaT/StR7uGR3ExzSZ7p/I41LNIFsJv1UpTVeQ1MSD5pxrpH4CD0KRsYjUaNxrPixwxJB04lk0TJaKyfAcb1yCjUWL5lIG7ZlgHwiL35OkhSVkO+7xEhYyP9NvQTkV1a+/ad2RpRD//LdXgMQTJwn+hLt4XR3/4N5GdwfTE7CW8RiPGWeRwJzndzFvNor/wDs2m38QO8znLUnF/W2uBWaNloMyIUriJ6ktPEpCfaNFpZb/H6MjDnv59W2deB9q+4fpTrDENfBNOxr7EFjWP58nrPz23iXl6hz5gSteHE4cmZ3s3YClXWhoJ1I915LAVRWYdCVCVZ9q+WPf+xW19jO3gIy6Y7fPj80I/xpfVsCMQEz7sGSTnAQmOprnvbMBlVLBp5etRudHFmr+1OFZj4egR2ADzNWAb+i7NFuTZwCf8VCEOOlz39xxhbNz3jo9+4+g/fXPSONbHqAsUzgSL9xOcf2H4zqqldNCOXFsHPYSHQQ0bpDEfuF5YTTUALkDCOLTUhPg3MIOBZgHIcdGku1FAB6sZHhW2oS2KPMKKAkJPpYMv1CtJxT+KNGrjhCWje4WWT0ZJFtTXGc+xA4bT+5qy3viSKJP0Qr82QIaG/agDi5Sp0EP+y4b+8hN97AeaNvA41d9+0QAZBy+SOiSFWPGEj+4NSaX1UF8xQrKNsUILHR62OjNfKO38nBDoPE8/PyfqzMahr3zXz89h6Ardtonv//kZV5H6+ifx7qe/8fO7XiLv4Sp+/JFQyo8/Jv7CoPQDDPjckCv1t3daayWibhGk/wO8RPDcwB4BbiTnQsPxN2ABqyAEBcuIAfernlvfcyJcSNt/BsUCffU7ySGS/AK64iNPLGqFQI/7Z+KRAZJD5KL4H7cjHiXa8R4cXmQYo22nP8qJaV1VVOH2hIQxM4lmO+oycViBnmOrRBU6oyq4vYX5aKxW9bs4DLrPGAMhW92j4fv6a1hPCJ6S1NewFGgOz0P4JP6Nn5+xLRTl59+YjgtjaITw/6XJfhdF/V7K+Z3D/VvT/Sq10grKUMAtia2dIB1J3pAyS+t6h5on2PntmaLfPcNNakfR4UvUmu8LVb1+WpHpLNBBscrI1C3dlHDKDRiW5BPQzAMTfyO9/eDfa/gLaB+b7+AEjy1ufoVNvESf2E7gpQqpSuyjUNKnSrEPNUk/BvBZkewA1BSqS64270LgO7fzbV4nIynHNwijfkW18S8bJLHv9kfR4SYFfAMVHHaAz/uF78E2w22ER/kvbDjCUsKlYnv8jR0ytsZ2SKLnivf7d0iMr0iNfuf7tPS7B6c7dPSnA6Rwi+mfy83bL7+pdCIAMZAr6Wmky4K9+a4zfKjHX+Pp4wy/nwy/kshEwDzT4a+fIXnhjznC/8oZkiQjO85rfmOHkZwN5Xb636DI//QOP1tMw4kblURvDxt8hSbYy5bm77EuIjp22CEBZjnqBZYgzmwv8Ze/k3dS1Nv8j79ovu94H9Np4kOieP0K2nea9DJUrHT86R9Ak+dD64YujeaT2z7zqGAw6CUBCzBIkUG86Rgrk0lhtJe52F3J8khGJKmb9UKnS9h6IFw6ezpqBoRqVtgPjVZSu7SyI+WxjhsMVujX2pxzr9nXbKlEY+1/RwzgRKJaIujUQJexxcUDEDKqLjZ2PHqlNE3AITk6BQm+oHhpdI3BZsggP4RlROiyJ2KYekuawynKaPTnwLfob0RFlhwO6btL/f+PnVAmzNb+1EqWNqxjHXUlEv99tFImKd7kVeK1DEuPSOUiaM+ngDRcSsV9Nx6LEmAfBOoiJCU9sCdsC0Wclqh4Ux8uYy7E1UWiRBaL9cU7dAphsniUEhqawSwRI6xfeJs4Tl1QZKaoMi90LMiP7sG/4ot41p2+4e9hDohowj0WDpLslL84rm6T2g9SZ4S+QTirHz6RXk6kiwkZlwZLQy0fQ0f0kPFhLKsxWOwxjObYYQXad6yc/IshLEKvnk8XSnrb0NWSJaQB9o5toZ8hILkeoSUDRP08xoVkcpAWQuGmvuA6ExgL/uG7F8QCUn+OD/HT5w9khR/+zKAZS3INJQa6pTFLhQIOy3+8F3rCj67MMUYV0fmvLeyNa++bPjriBfvdw7zhq2+U0JevNFAKAzAcv4W/0bqIQfQHO9TQxaqnthhH1j9bcc8Xlfwpmnq71VlPgQ0/G08G4y8kS/VLTexvokZLyAd8nZ1HeI57rNV/jPbVODgCczv9DxinD2M7tKmfTXLSCtLBlngy7R5yJh6jd2z0sDjZJd1aPKA1/Bp/JcgTDo/s/WYHbjzYh7WXGJshVTTY4QvDIbFJXllzpjfNrsIhaQIeCY6xYnr6fWwEDKiR0vCwcQ9JQQmzhzav8Ki723x6ztFkbgXaw0AKQ724Umbbz9nef1XdGAaug1zo/9rPt4z0/6xZ/vut7U0sFbo3qAvdzTtQHcSbskYun1jCBPOS0rxEI+qo+cdCNb7UaUvsd8R+c/MtD+eTE/Y/tq7vWWqD63ZrHN95A97HUpmA+Epp3VCF9L+41L8K/abYF/721VKHoJoxNkw58KPR4p5ETKgPLT4WD0Ms6UA/PXla/+ClPmPC01IjURA5NP9rHOBrSPCDfkOM4+vP/4L6gvVJpk5CUqkwKC2/JJRX9TWxeVf5APb60KWjMPdRuT3HZb6x2MlQEOqbxLP3AtcZVwCj5X1MbHDSzUNR/AEs7r2hXGk/tg3jFLCmr7XAKIWJeZBDQUBSj0L18X24drlZXfiKvn5mBEVvDng27v6bQiC+1OF4MBfrwviL0J9/gfUOFpsQqqYpPY4UTALPt03Ql9KRHR7LqQjFP9UYP9F/aK6/QjoikVLdna1aJFE6ngwU7DEf5VtGNMVBTCiNaIaUBb/rBN1El4l8/UboV9yQYMF730dcGdMM4IBCA/4RcnvDBT+FNXegJ4G5fX4c6aOFjI/pESw34OmGDIVFD1g36TAH7jHGw0II76hgeQ8sDI816Y8Geq+JPlBg2GD6qzFeWMNfksETZ1b9QZ9i69/eouvLEznGujpsFdL6IqQX1vD4TdJEdNeMTUMoUYXj2xa2T20EQ83uqRvty+O2hWjzAHGGXoQi8RKF5zI9knLDMqkf91dQEMYS/MOMv/eiND8nxHD1TAv+/+7nZziOsH3Mf0CD/H9AV/xPh43+vTgRDawFvkZZPjMd4lQZJmpFPcRBPpEAUipFCStFLmxhb0YfugH6a1JYmumkVB0L/RybNvnYvNCkIExCoNN6wGcwdfH3Y9GjxWO4OLSONr8fi54CTcSfjhUatOQIfqe5hilasOHRbnWk/74OBG7unAc8ZN0j+cCKTNu6w5dfvvy4oZ2cU6ZiIjcJ61loekaampz0RgJ8H+SW/IlVEkWsJjqQT4mFsp3QnuyPa6ewrTV1TlaTmx8i0U6dKX9HSLkh5f22n3ZnYIdM9vgP70WqMAqFbREpN/74nKdCs1PYThJb29feTVGhOaXRzv/7vIgE0d/BIpaagnpViqxt8/1Y9Ah1vQVRTJq4NEORtP1HdzxpFKO8adUf77jG5EzU7f+/BiLa0TEKyNE0JJqK6v6rnPzrWBkhNMtO0e5pSGnwR+h3J3+wuqMUBQn5CCnC8ggC0edJ0TH9ndVQYg4tcarTT7HXU/T7d57n94MItDeCQgx7Pj2ULfhmc868lquvmeTmXwFRLBT1FosYIaWZpsf4TqTWENx1yPWMSuop2SuBrQfRW+rSTnMhWWKXpf80FkUaejyN7d+L1sXikW9BFLvehhDao/mnx66RIc05o2I+UsNLm93QtpshWGKePWohPTLqQhFGbjZzbO+diN2/KNFouBQB9PfYgmO8mjzwYNPAo9MRCaZjr/wQt1Q274ntDbYjcLwQeVBbJXk4LNhDeCHowk9RIzSWGO+OZbTHQL2BBX3BkN2XhzHl0d6xGFUmGd3yF9Ij/Iup+Joth41m2Vd46Yzq+F8iQfdFlzcJJnpZj+8NNbpJuxG6+lcwAjGejVEt1lMrftEGrZqL+jWydk70DpnwziIizZ/U8ujKFWoQPOp6H8n50So/fuM+FhpYAxR7siNIH/CXf+tSlkcE8664dmRmwFHA3DJiNo3wPW6BeRK6rKUGa8oPu3qNIQlR40L0QLikQ8GNSMGaepGHXmPOuEhV2oRC34sEPrn14YV1gQmbiMEvPX5IXCSkNxu5i4hYfa+m/HTpBQYwDQyFvqfzvFDSDhEyVjwt2wi0FEVZrM+QcYAG4YNk+dHtEbZHvChx2rbDIACRFcQ8J4hAMBB7sNKLOh64EFZZsQumwq1j20OqL4ZKXahZRHLoOxP5fmd+MFPmYwUfUbUgFm6R/SDzewmXzFq4PUsParmGt9TFLnclN6FKxLUSZ7I42F4Pi8VVsGt9qvyHGWWUe9i/SlWPW2hpxU3YizTGkknFGh3yBXtSwtHSXqNvtKkYO2J9lZ9GJP0iFVUCxN5EJsomZPDhyCGikUzqeDHzowEEQZ74DZNYLy2Qe14wEh6/lzcM5YRVfVjkQ4VSlBT+EnosaP/dl/hdAfFLNsOavASrf2b9BUgZDi239TVSJfPohY/FtFibEoAe5+r38BZHeouBHC4uvAiTxPZJUT/pxRtVs+Dlf9EFGaSxffxiBtJl+3F3aLw2tkXGf3Rx9cJCrocbiKngX/eegS+2IJp/q7AAtxCFMKekGyteMsG6zpDbx9C5xsj84mLZn/uIcsNz2DSbFqQ+107/ysyPrncY/NWvpEnxFpQu1XoTFI/X+r1tiMXuw2CXCFBFl1TRsOWw02E3rrFP3+uW9c3bpKPZQzHyBJz3hvpfiffaAKUab/YovLfFR60Aa9FJO355rL0MdY6FZUG0+zC2gH4uK3jur/PrPXXw9ShfgvKo2L02pDGJTq4jCHuebCjXeee95z4fe9YEmojjsNk6vhU54qmeHd4WsyPFDKzVI3PvhRcPPF01QtYEqlzYdpIWILKmuXRXxo3eK8wc1rGaqgQxykn2KhUh5FciREL9KrQmNhHnjcsTIrIe9gPNnvr09Z1/aDfQ1OJHqmx0VYAOZk/oiAAOE6dcGn0i9+mw1+lWyO482DyOq+pk3SQB8dkd/SjLZtQa3XVDxXGoxG+G3LS1wYuR2TXgWH5Hr76K2gJHVnTYwOnTI80CAPojzUpgloBLe5e4jku44teDxO15FEX0LpCwgRDxbYQZ7I/WU8TqIqdPFRv5cSdw2CU5EgXIxd91AjxmZpdgRyTwtjvOXwGt/rZ56oITERLrLhW7HvO52Q1hzqyTMs5D28aQxiV4nZfDLmADYsAEnZc4dmIJm6Zg14SQD9Lb5OKNXfV4HSk8pxjyS5RRRrozRxIMuB+99fPXLttid0jFSI/S/jdu2yJyJKETbsOuK9miIrCniX4MnjjghpXG7ujSN0+9jihsh+M0I3CE6ZvOW8/s6ZEsx3p24wLobcsReXq+jFr6o3ySXe35gr9jf6bHB5iaQvpVkdsWH/cWwRBAyaRIU6F7jGV8yqg9BRYd700Hh5dv9VFg3xCYEyqNt8vaPLWveu9r1r+KjhLpv+FfF2WbotdM0ncVid6XQhTN0Gm8V74R/A27ID1lmh2V208E6zYv8WE2X2fI/Yzx15/DyCu7TiLsIrX33kLv/VtXkb3FuN5kOha4HmN+Xwaz6XA2xZ4G+/DA4nez0obqsebk7+p671zcSm4Mflzbih2zfdbdBVQJBXdAsrHwokVMaiWJiVTtC00gdkkD2MmqQhrLgZIXEg0Jk8U2zy5Iivo4WVFN6KMsOJ2IF0uGvn/nkWoQ5cC8PMU4X+L7+jq0yRid91VOjcekynPmBF0UzTWNgrKJsIsTsRkYOrypfSFXBLFFb94t4gVJB3oVZhh/nRD08n7mzcuvZbnQjccB9CtpJunfyuyIp8A9ArZE9MTq2fCyKyoEEK4quVWWXYusKb9+oyyBbOxW2OiuyU+PcHLsnlo2FoHnu2ELevkBy+T8FbM9LK59d/jwCjTCVIh6gfY6W0+IoDEvxVOshODhexGeDfVShIIlDN6ExvzLs9sgHsV5eUDu6/jNS+gFeJvDRE6JsWtabuB9n3sglJrRBQo6C0gzSzi8IFx3Fflh6j+WzsxiZu/HQuQMkM9+bKIJfdsJEvVTe3LtR5yeeffh78gpAsMzN386dJmEPsmXrzwmTwWTETOIB1SYfzvmKWB10gTZSR8a71t3ef+V0uDfogu9/0qvvfP+5pF7vf8K/wF9ispoFLCYT2ED3oQ3UxOVEXh2eEvGRdL9uG81Uvqfrml/CWV9JMaZ9W27EQNnzD9k49EN2med3jePdIH5D/FNxhxpRLf7+B19LWj9Saxh0tslP3UCSmRwPvorGEfEI0ne/NVZ8IxY9j9zCjRIFzl6wyTthUCug2Y245uZsRCHXG6D2gnt449HSG+iCacI56d35pGLpfEKPKKI38Krcd65VvCh6e/Jmqjxmn6kiLzQi/9uCemde3jwWlFkXzt2QXg4e+ymFXoFI7tZnWGhbbCOYrpJI2GP+ZmADq9WDK8FiS8uEXYegUPKsAgQu1DrN8775XFJE1bUk6sVyPpYD5N4PzNTwUsUQ5vevzlhAxmJ3LaOXWceJSlgKpBmCbClv7Qng35iQhqtJT4HuUy2wLqI+ehUszA3ekcvE/oh9D7Q5qb//GwlEp8/4FSfP3zEfqJbhObnDy/0C+wwo7hgU3j4NXkaP453MI4+fh6IXuDMBqJf0ruIiCSiz9QVVz+Hlt/mT3HvVOBFXYHjIZAQP8MOk5XSKzZ2wvF/wX9+YesOeTHO8/d/fLZ+iXdArj+BBdizQ2De1fc4BYj0LTDn2F03pEeSjDYWNWnwNlvfBrVWcV8dxCnMN6QNfSKrypVJnUmwhTn8ILqnnp6pE511ZMjgR47mftU/ViX/Dx0p8DvaU/jhrzufPrx8AKNbAQ3+w0cLbccP6EP+8PHDI94EjzzW8eHjP2NnjX89jhj/ih0dDPKHnBvMj9CA4SiqfPjll5fo3D58/Ps/ou8pTn6Ar8M+d7Ak/Iv1wJNxhST8gb9sSwV4p1XwRI7+8OnqpJpcdw+3tpBPtirJ2lZu+oaYP1as8snododap1JOnyeH2vwqjPi2ftdE1e/dkteibuX5/bqfOXA6vzLkrFzy17Zc9c15Y3YUVodLZTC0xnn9ODsdl8f7/ngvGMPzoLo+WPdxcRBYjYyRG8+U+3CXuRXWQVssycLtzmW6ydzJdDKj7swYZNrV5NSqXw5Znz+qyYqb9/eCti7q/d3U6pXLlfqwO5ndMn6mcu4sD+NbvnKUzvzkKl4qybN4q1RyglOx25fpzliuVxM32BfsYFeuNHYl5diZy3M/J7i3baE20LeueSsuvfZsvWxksnCeCyfgzoVz3zkvtaZR1Lfb4aDYbZqFY7UbHN304rQvNPNbb1K49C67ZmZ2N8rKonF3clW+sOVvW37e7pRO2177wsvGrN8YNrfZ/FqB1Z5X0/PNLOpuVVNOZ20xcc3F+Vjd9WfVfrkx78/2u0trUJXa7kUVR1NN6lQKPmfslVWhWc8GZqfbty6mUMktW4Xh8naopafzQU1WGnx+r9WW97Ze6KV1s7w120FpUdGUcfV+uByG5rWztY9a8niHgfWSpZ/Pq32z7ndldZ1sm9PA1IPaoSry3W5neZ92lVl+deZWmUNVr92n08pQnWWy/Eg5+7n0cZ+t3HvN7F5QZrP0bS7nRrdDqXfuTDvGqXS4OVo3qK739nZ0zDW9S7Vvd1QpXc8EV2GXv42P2iI3U4XkyJ/eu6o6c89NqTRql1t2p20oauF8scpztVk9FrhlUpLa4nR8aA68Ojesl4rlbsEMuFZlmsvw6Uvv0OmKzqB8abk9tWxZEueN28vbHQC86h+ai1Fp0r2kg4ulTqvKYjxLlm9Cfe5Mgml5f65UHFE/X+rKdSWrV142J+X09lIfizdlePZ2pqkqWbU/73bUnpytar2Vea9w1wpXutcml6ywqO8n8k0UAqlYLvCiwvd3QUflZoPjqiR261VxfBSLlZErC0qjdlEa/ZkuTQcXKz0qjNLSdLneLzV7Ia7Vg5XP9Pvp1XWQvSxbubI/H81qtaV1rQjKRD6oqrNqdVznom87uXWPX9863K05Crhj9dxPyvdaoVcaV0cuEHKhZvETpdJWJMUJzpcaL/jGzNvNxI42HqWbI399MYfOZd33b/21NuX6gaZerqX51UpX81av2RlU2+6ofqhxl9akux+3j2L9flFn1cLIXZ17V26Qa9lWtt9fuUN+0D3bCl9bpo36PFiqyukyvcj9yjifa5YcvrDvtbrXTKZy7K+Sdn/O7xu7QjufTnJpVdid8rd6pjvjx8qtNlA98zraS6rYHtdWi4G/XenTQ1s0bVGYe83csWc72Y7bHLcGl1E7XS9ybYdf9W1xfJtXnOyso3jL42h7G9nda7YoyGvRKRzrd4WrZWpmbiucbp3RWqxN5f56OvVr0/WoU23PC4uz7WZbLW6xXGm20nVmPWU386vCTVGDdcHk/B5fLegVvTSt1fdytuXNnMJCVQeVeu/gLQ7jrVoy7V36Ih0n99OU17NBo+hZi/64KU7bs74rBBy3bzZW3cxgxO+XBbF5KLV6lfXEbO1EI6vJGU0+Zrj15HydnrlGdVqo1MZBbeJ3ZzPFP7V84VjXuuuRcOb9dlftpLlG+douuWtBOjWzwpo3gXeOTq7pyJmV1jhnVgrXk+b8/MzVdd5YOpXV8jySa/ddXeuL8+7cMy82vOrJdW2k8Lw1EMfDbHPbsE8ZuR0UW9btWBuXxWqn06yVdo6Y9WrqdHou1Nf+4soLntfKXBwz15LV0mo8PE5H2mI7GVXtUa9X82W/VHDymZIKBKdrufT5Vu7IM/62E7NqMN2nuZPYm1drmWltktNnV9viqqtucWWO71zWF/ecvhglT8v8YTFqLoal6u6YdI+NXEErdYNm7XRauFfbyIx203Uz22h0bNc7DuHbcbtlDkbzvd0uFWHX5V03f2nyyqS86LYGpyUA3dD6eqFd4a8jkVNrI1BPe9Mst1C5a6nGr6RqaTq/2eNu2eKLO78jCMpVmacPTmmYvti5Znpu7XlnJlb4gdDvTTu2Oj3W0la9MhkW7YZwmFU6jfbFvFmjszKbX9fcstG27CV39U4ZUDvmHXkxE6+C4Mt9eVXp3sSaVNfGfLt6GfdrY+56Uaodcd2ZXfvN7CSvrU/dpbnoNJbZXpffc2Zxbjq1UUcXuKbRHI6KKnfpDjti+uDKtd7Sq235eq9bmrurQRdYe/E+PPNS3R3f+PnSnqvd2X5t993TfDDv8E3vKI0OXqEszGvXzHhSzedLqlCvb/mdWrezp/aeX4Os2Z6FRWa10335VFBLtcyl54xLq/p4fO71t2JuqJ4Csy30ZiNt2ZzVAtHIj4czv6dyp3Tfm1aaFTVZF6VB63C1vLzQXkgTThoO9a2S9y8TLz/aKsmRld6a5+P9npfqY61VrY64+rbDWwJ/7TlVrm5lu/Xm5CTXDur4fBEmxe5aPYnFi2CPOEFdZuo5e6uJ0zl/L885ezVLSv0GP/f1Q/dgmbbU2ptNe6EOp1x3wuWmfkEcnmzl3Fou+heevww5NXmc1E6+AOOVjtvReMpVtdttvjAyN3HAdS2xXh9ft5PZpaV0CuNkvSvtjsJEA85e4Wfa+CjMwHThSktlPtZ2YoaTz6LB+/fTolOwd9fZuFxtajXbGkz5bbvRS95NeVLlW6vFfHBzA+50bY+KszYAtt9wGo3Lummrh3pT4Fq+7HH69FKs1Mx6vpP2/EpyId57eqsgLptqe9VYVxuVtbDUldIix5+TavfcFtdD454594cnIV3qVfvq9TQ55vvO6NpK1mp5c1AYStq12Tenln858LorLsxDsnmydW20atXWuZrumY0yN1v2xM7+stIDrQOGmlbTxXL9eKkK5mJ2Vt1VLTlqytZhNbkk56ItiBm9kJ9XdfvYnImj60Udz6fqRZjpi+ZMGJ6nclrNrWcZfrnkx7uS5BcqvKx3tOR1IWRn1UlNmCy41q7WP/WK81t1Z+iqXbsnG83StqMra6fmd9bnGRjFl2LtzDWL3i0t6Hqa73cX/ZU+apjCaL5ruwW/2Vxd9Ht7XqxcRvapZPR6gipxQ5H31Po1kGuzslUZrVbLWSO5uvDurl2dtoWRosoif7xVivW0ypdOl8NoPDq1j7O6PfL4cnt/W42vEu/kKrVyJzgUJndu2jtfnNX0Iuy1iWjo4pRz7ZPeLDvH+1osr9d9PSmtiqZ9F/p9vZu8bhUpU1hfJ6ZtXQ7J+sEP1g3Z7ml6IW3ae2+mV1dOhrOqu31f10dX+3q9TI6Ct2x05PRgoN2u2a6Y7NSyx+aFK9c6Ab9zxv6ilrwOZ4dCLXM02vJF23KnVWvo273W/riyRmKjXnTs3rSYrRysYk/WrplGy+ZkvVsZL8c8N17w9mWQ0faqdTOu2cas1snVpmp2Mrwa0xtXOw/O836mYoqdfLWeTY7y10KSF8Ucp9m70X4oVhutNSeZRqMu8JPGnV/kRvlxs5vpLJQarzaO0/VN6KrtxqyhXs2zJpQXusBzu/593uJrdq+drQNHymcLjX2zovfNurYSTX3pV8TWLOjPC8Je6vWGV9gVzzUrmVF/ey8IRpdbc6NLYSacDrMM6IGTRXPQrKwaueat5k7uemu3NO8Tm6uel9XxtN5QzWBS6vM6t+Xq4jDXLtQvPbl37m0rl/E4K6/rh7l3LM6uhVnteN+Zg1Krsb66ysXLdex2xjWTjYUK+prUK1YG88tOapZXczEvNIT69birjo7b462n3lbO6GAJS6Mh7e3GWpUK3KrbFzm9dG5Ngu5Z1A85R3A0UJ+1k70q6W1lxhX7atDUZ4fjbbeya26By6sZb8svxMtlJGmldrlg90aHlVDWM0Iu18pNpyurtqyplXG7LqSnrXE6rxu53unKDxpHhcv2CvVewVnU7PbAUWyvXDvVuuV6/7au1IaF061VH2mZha3XcsNgm9O61fruWDSl6ei+LRzcy7JRqItrbZCt53tWV+pc7eBmH7SaeOhVFkVb65uZYWG/v9eD7Lx6Owlcadq/dlutEthKt2Zz1rqC9Xbbdn0DRHrWkXrD9sQ5XEXzsj7qnQzXuxz0Wabfci1+Cig17vp6MCiflnZz5537+cu+m5Qy1d55Ztbq905OmK3OelsU7jNuZOYqaqsDwx/O+7p+yVUMjz+0F71SuzUypYOlJqVCXlN66v2u9q521alVVn2wUI11YaGsW4X5rVYstBadwWA5WB1Uzuc0fty7BBV31EqD9ilUuMbQk4ZcbZl0qzpfGl6v7v68vNZL/uVW9deZNFcfqOJiuZ/atV4ln8kKvdKkNhjJ7cY0s23KWhVoQS/IHuiFyeXWbnDlncXv+pXBrX87r/hbXRfavVxlxYlHd8+PhPRKqI6mLjf2Zqp87zdBKIgg0UvO1VzmssEaqKHQ5ytSJePXjt1aSW0aFXU2NpKHoqPokswF8mQuj+y6uRTV4cGbNJP8dDQf3WeTgy0PhHy9Z1f58sC+HLrtUU7llkp2cK2V9kohr5SXZTfftbnx2uhcShx3nXnHgc2PF6NRb+tfu8dm1R7Xu7Pm+dbsX5NtIXCyFkxhNeVR/ei0j7Jw6O2Esjzu7Cf9e05IN0pL2xBWY3Xm17fcfDzi6+2sJnIdsF1WzUx9dVtJw0EmN7jtb1JPH4PUnuQHLfGiVGreWW0WGj1VVJK82ryM171VRRune6IhLnMXiV/dmuqxKWbKI646ajT48V3Nle3jiYePM+psddTUc36mJNdaUdXX9UJLX+Ta7exaqxWnx0w3b492pYzfDi5CeyLWhNmtUO+P1O08K1wbSbuXcfg6dzrNF+6uOVxfFqvDxczXge8JRqaRGfDyfXxptQqDaqnPlWAVetrjllx9vxfnx/FMkrb1oJZWjbI+y/LHe29VVld9dbqcSGJ5KGYHqsnp/GHePg0rY8cZctpkbeodXVQL6V2yWB8IwkQ1uoN1+TrPWrnC3Z2tVXXUrwQZ2T/MGrzX7XMjr34HZUgY9VYj3jtO9HrhVrqXZ1pS41cCdzGmIOhc0yqo8u50H+7NWe1erJVO/aRQNQVZc3rTWT3XHArtrDiv3QS1r91F+3Ra21PQ4laX8fwsTC6DYJbJlxojqx5UJ1fNnGf3ouBX2162Ylfb6rK7qNv67tJcjXNDt3PUs07t0s+uehdJHq+OE44zx+Wg602ynGQn5864NrtpU2FR0ypJY1kqdKd1dSAp5yBw262bUc5w90ujXKnyQtLn0vtqcVEp37xsfR+InUxjLuhbI7Mdr8tJMAvEux/kTseF0PaHPWEItvH1eBoX9dosOTZEQ9rWcudj5lK7WP175tjzbdhHbXq9Vfx7UQ8WljECwVIDPT3DC+3a3J3y3HRe6tgze2W4R2BKl0HtYHRWlXZwy+/W/rhY7ORF5+aVrXGZu197DW6b1xv1XDoj1Pulrti6T4LFZNAsjpdBxbFqQaV9bFvian2czMT29ZrrBdMdn7yPpgVx3wTEOduZneJwU9n2pe6Zu+zrdmNZbdhqK2Ote1xG6qqtq3Z0+LbRXFm8OrEmmmGkb/WixB1BaitqxoZBc9OkZVSTgi6N7+1gmC6v+vNBb23Xi9Ny914oJPdWVZw2/caqLfZFcdarZMXC9OrUu6Pxqlq9ChdlVskXTi5f5Ra6uGiuhPpoqtrSteHfD8NyMJzzk/VSD3qmVbl0S917b2BzSk/jC5d+T82MOt69PW4PK9mJOrjMhhkXrPjkVOnPTT5Z46WgwmX48bS316T1VL1e02OrI6vcxMo066D4WgX9uLRro8utUl8f1l5m1PUK+ioPsnwsdvRpvS8u2n7Gvi50Y7bq3OzJIn/l+mN73baNfW9lNmfphcbxxUnpdLPsVtaUOsI+yDf6FassVHbctNbmqkmx3yipanA4c7vRSFkPr2K+0aitVzLo8FdO0Wt8xjuO5LmcAWNqemwXNE/LjDOrXLHX7tm22fRFPenVR0a9vh7fwDpLnstckGxXHKWj5o5qZqgpoiWXl1qmr2etwfGiNa3avGg2hDlXuUyH+nhUH8u9pTXInr1sQaiLxlWoC6C0TG/8vSbNS2IxLTT2Nn+bFI6r23jYqMljZ7zuVLmLpM0LXado8TXOK6wrtzN3cyrH5KyunyfartLsTc/rpjiT9FsyPfF4XxezjeFy2ms3RMvlVeWudm66zvc83QpaHWOuwZkMb8l63mufamODF9ZiYbDSrsujdlfTDb47tfhmSe+q80Xn2hydrsLhVF3oDj+cBW5WGF/TzXY3Xxw6pma01KbYL5Sz09ki1+lNytWTe76IuXprqjX5eS29Epe9bLWY1scav53kO7MxV2pnl/OKOlrt6rvpQBybC6k1L9ozvWRo9mC43tf5JXdpD4p8Zn+ZLvXleZhvDfTdoltcrJ1efZHz+GuytG0WAMhBV1f3oH56VukY8Py+UOhm9opgzwb86rgaFVa1SX5SWUjSwDCTo0ltOLr3xbN3Hje9QsXulPhjb1irl27CagaWU7vZaHtOLjOwm5zS7rWFsRg4h/QOrPaKs+AqnXOWW+m9a0GoFF1zuCofhGRfrud6c29xDfrK8qBenONIsl2xrrYvmc640U4qu0t+tuJ5lfO87oErzHPzdq8/BKl21JxtbivXuL6YbRtCWpxVR+mV0TLG94u0NPnaXappjYF90rqzocvbzdxqK4z17FFeu7dVt3EGFWxauQWFwp4/dUpbbtGz5yO507tL3cFOaOo157LcH3QNTFtjvbg1M5V5p7GqpsdKQS2Mz/OKzU0z3YLTPrQulaZz4ZSiZveV3Fjm5UVHOFoe13FW6nzkdoUsX605t2l21BDal6zIVY7LflvjhUGzNDT5pSyu7nlN9PpaRbx07sLMbPSszLk0uHe5c3coTPZqU+Lvq5PccfaLFbe2J06t2Emf5ULh1rTTi+Iwa3q56dBNXvXiQNHvk9pU9Gyrccr1k9vmOOj3b049fzqdM+7illy4tRY32jXqi8ah3jh6drU2uq5G6knj9GMrCLT5zVgoHX56a/GljllJ5zLZy0WbZ5TM8Fx2ZkfJ1uSiaQ0arVnTK6mefC7ZN/FwUpe3abef7N/v3mmc4+dL7bAE2mjOM6trJSlfQO0qZQrFit0POtfOdKe1C6Npr7RwxtOrfwN9XKuUTGGRzgTj+Xwg8Oq9dR8fRkZjKU5y6va2vDS3zkQ7erK2GDcLudzUOM6vnTK/zoJuvcrMKz3hOBFMhR+IB6c52ot7vl8+3TK1LGh6MxmM0+k8bQnVTnPI3Ur55tI8iCsnnT8fR5fMzuhJh7zZkAXv5E1dvl7ir7ZSFY00J9aby2ZnuRcyXXvXFQero3QscZmzmU+XZslscSFWpFKpdN/PrNJhlNzvpeysGPTNc6+47yjr1a7UbDQuY6t1bRiSIy1ax+ZJDQR5m96rpaR2Pl9aJS3oLbp1dVjMdJo3UUhz6nZVmRevQnmy473mpHofdm/ayRPMYWl/z5RW2aRxW9WDwGz5nfn6Mt+VlkerfB/VNcUtWqI4qXUb+ow7TIblc8VaNmsVY3K93p1Gxw2q28pu37X9hZ4utI20suby5YEH+1qOO0LTF0xxVeePFr/OTKqt6zB777ay5Xqr6JcXZUU4DkvD5HaxtSvLipTbVbbDcqY0S6db+7NVrE72FbGSKRTk9H7o2JNlsjPc11vVpFoep8/GVSo56Xa7UCz0astyozlwG+ml7sjN3Axm7sz6+rwpdq6VmlBTZ0e92HZnU4lrOtP+0G4vh5keP2625Vuu159YN9dNdovdu9lrt9PtkTje99Kl0T1dyTSldG5yTO4qBXuaHs39Sv7G7TP77VAuiwPN8rfF4Datpndde3i+17R93hSH6d3FLe6zftIvqkm/YFSyyZzspLOD/rbltrjDtCiU7ek+bU63jULympnqWmWcbgOHNs5aa+RLtfy+Us5sh9xwMs0ZnDa4Cou9cK4W/LS76uaG57TQyyQlpZVuzTvctLSSRF5pqGNDnQT2YFVTOjtPH9rVdem2mx0FfSxZ+9Lkbs+mK80uX3xHavH1hg9WC9+tj/O6f2t0pLTSnB57g3axm74c1/IIFNNAqQxv/b1Yyl/u00y/oxw8c6e0y7P8mS9dD0O71a7sC11pUZxM9HE22dZghRm7XSrZh9Wob1r8AfS8Tmd4XvN2a5QtHV2nWDLaTY+7Kp2T2FKToF1kB1byNvOA0fQnFf4+GvduZa4xMTM9vWunp0JrNMw1BX7kt1vj7bCe5+s5MdPWD732ZNe7LqoNf3vNStOJIwj8JXtzxi0zE2R2WkGeX2yn0+0qmrNqHB3dkGar3Kk18dYtfX5wO65emHYOxjEYq8dKppUrgCEYdAZzNdupSoMr5zgXMJztdDnQdrWW3yvoY8WemWN+ZF+yZ02d7jV1pla42cLxjLNZW2i3yl5at/vNNZzHaj1pZjW9eRYuetFtrQuAJkm/v78MFzlrNF6LXu5+7Kf7xV5PTM/3hVL7WtDz+dslrXglrb/NOunLMnPNBWt+L+QOx+qUE5PG+bgyZ/PTti6d5IHXHxcm93qp17oWNX40W5xtpzo6LcQdaErHsyG6jVXLOY/5wdpItpxMLefJOUmouFPJUPSmPZHmHX483F8a02n7sk2PChdge+eZZEzy92bdNHaFsrHqDL39/Vq5cJ3Doj3gjqV+y9HBtq6O582jsk7WXeO+VpaLlsBlzeq4mww4V7Dn5rVmDo3DtX7Kb0cHwexNq4vdzJraPa7YLVd3NW00vxueeZcFuypwnUVB6zvNLHfJV3tyoygWQD3IHfvGVS4bmUCsGk5fuFrJXf3IZw/dQVbq5YuNSvdQkNr7Ts0fr8DaHthmW/MG00C4Vjqd8V6uF/hW5jQ9qpLZgTG9VamdW/rda9HZCrnJ8NpqZPVtia83VbkeTEf5g3jj7Ao/avM5o6SuerOlfRuV9pnpZN5t2IO521+tQHyM9draXI8Oq+qxO7n7anngNNbX+a7rH5XOYZBruocZSDlTTA5ujVUwKG5dbdWdKofVTZyN8vn2zO5U2p0jkH67VisWjeZRzErL2uCqpvemOam0hplG33PFUZ2v1LejTKvhaNxg3SgMT+Xhcqa6zipoLXPr9UDml1pttFRnJ2HirHtb+ZAUs4Zu8KrbP3ENseNcGrtVeVaRmmItX9mvltz0JlwLx/WEU+fBSLy7ntTvK3r7euBVU1/5ge3akl7tteeDU253rXgDZe9Md0G2srJmVm+4W/K542TuDcT8fLFamXONa6rr22Si1gLxOlvve9a02zo0buZNyVwn+7bc7BhGttcOuiO7qJpCFUyokVURRHs6NyaX0qFRuN8krRYEvTRA+q4Y87aZronJg3gfn0diUFymD618Ozkor1tc8xDUioWOvSrkz3aW54HbiUdbO/H9qrLWDturt2g6knq8CGO3UJ8MF/60lZsupxd13DgJsr21uxNVHoNtqg/Wk7456DYylaDfnu329YZScA9ycrzLjLX+qBPUqweh0DS9410zxPZaG0zl27Y72VV4zuysT9PC2O8NTuqgcao3O6eCXR6M5HrvrnUWI6mmD63lKKc468LIuKbFc8YYcPlB0eUn21tT6xk1xetz80x2qw29s1bo8FpuIqoLrs3xk3S3ubw3R4VZdVIdGsN9IbMfqPZBb1UPVU3eFTx1edCq3bxb2a+LFfVw1GeDRVu/j5ySkD+Pj/3y0Sxf07xiiFW7dDzru1q5PlnN6l1uejm3atl+Y2Ink8rM7Jwnw5uSXp0bnJxOdwfuKVk8tC+99IJfTWSxc7jvm+1G/bjYVeuCX5Tt4k0fL4az2uC+r9XPrSuYPoJXGAqzymTSrYwzhbThqsF5kuMDpVUQ5NpWXWe3jUNltVt25uMbry1nZ/umVWV+66hGZ8j1xtf1Yj295vZJ3+tWVo59HN+GtaPX4arlTG/udu81Ln3qtlfp7bFZtJ3TfHe+nQatRb6mSKuiuOqolqwa/HZ4dC2vrffuvt63WvncpbS7d/Rkzi4K9fmiOe9NTW9yCrq9aeFuHcatfIfPpV3Hvmv7bEWRrG5tdc/I05OY33NqUDiO0tzklLuBsBWzwl6urdQdJx6HZfdU2E9mK+5on5q30dVqitluc6Qliy3tKg3L/qE2SLfnuZw0Ps84K2vKk8Lwtj71itV8X6pez6K+mLeCjH3prv8PB+ex3SgQRcEPYkFOSwECRM5pR8458/WD59hLHxt197u3ygL9ifwPLmGKcXV9KHTGctp2Lok8Kbia2dmpjOzOSI28gAY3e5l9GcVScpY0tJOegsif33PJ51eY35FaIvOTDrBbHAinC4Pd6BI20ONRTZqQkWGHnI2Z2RVLFUg3b5eZVNGTSkWzvxHD66/csZ9qMaj6DjrQTBTuGeUPH+U5x/mJCADDUtQ/5RdcrCeoEPuKCyMIeZEepCldDF5Jv93O/VqupFmtT6PQMLT6fKAL0wFe8+v9ixtVVE8W0V12R6wNqnoi1k+oYu5IYX3EBzOLOhAUzVqR/Z5UmuPUrg30TSonTmWV3y/7xhItmLQhODQ2FlVFFaXs+OZgcNDSzqkQnnD7xg+ahd+JCzTfWQf3SH9geYQcsnQzaw/Mjxlsof9mhdgouK2dz3TP42hSvkIzVIkC92NLiMMqaLk2vvNWUZUwRkP2IdxQH0H5bdxto+G3az7lUggKf8NNOpUUPTBw9r2uL9BABKecOispNhECOkclYx3b+QFsH5JyffLsrtk+3dofUPRr+n2mghxEj59+kzmLnburgW3Nqt7KoboVY86BZje9ibfxQpSv0C+f/sARU++euLVN4lXjUTYR2sYsnaFyYgR+tWBswWKgTexJOthOzTQDyDXLv1kRyym1JMmZeMnGPV5WezhtV1xd7eH4qIs5FNeTnHtgmdmAeaX6UYj8sLjW8u6PDUEdxEl1gWk3VHDva86VmgZBy/bd+qNVPQZaztKdSlHpdBUgytCpxXHnKmgE6ZEHswCu3Gtfd2qWu4KaH/cakRw3jeqqDWP9WFFYFsM3gJ5Cw7ddA8BBBa4+AIU6UeAiIHJMz0a9hpZf3VlLjOvt0Y6OYt4+aX+c66tDpx5LT1+2jwVEnrKqP3azfJOtuojh/aruW/S7uRx2eGbl1HNKIuDuIY/ZgLFc9NpigGgt3LrfjK0aqub3Rj5ONeDdo946hdSfuLqUz+kwZ1gTzEtP1AWhho49zPLtaxMnhFH+itync0AjdrdHiL+ES61sDVDvstKM8ToROuKOBNEC4l3jd/qGaWJpsEn9nMbMI3EHlLmMxtjgLckM48ioN4o7+WxuhJTSS9Vj+Wihx9+vTUeCSQA8fd1jM2ghBSHewcL7ZUzo1UHmTeMvKd2qjUvtco2GKhsx+jR+zEnp1frjAVIyG83Yt6YGvbYz8KI10KjN5LH2kkPBoHgQIWYgva1zECSRPLT0JQGvX1EcYwKCyF5R1aP+2qK4HZbKdaNOqJM9oA/2oGjpLjQZ6roz9mNu8pN1foxvTvpUxhJfvF8gVSQzd/lIv9I97avuDKSHaANNvunW6SH4eZ5PrjQ/hDLz4BRHw52zcTbwTKbBYugY2dXzsT0LBkQMkzKu4oUHXEHqLxHSztLY2ENae7wO5LjhmmKpDq79gE991rNr6qLGSGz6Dd2vpz8kHrgjH8KdGuEsL/7907vYuqxOb2cPRv8ZkdgZ5JM0W3BlQAPRlN88EwXAw5vzWazYoQd0ichL6NB7vQ9UxwzQJoJLc/I5PDQhTLBKffMGULNHUeNJBb76WwPVRPK7a2Toy/Z1+xQv/Z0B0qX6PChBn7FOaT8kFfZzGxkKfnM0VgKmbW4+WKJQeehF8/AHxmNqAGxw8AmxgAzor7HQ36HbEXJ25fl7rKOmz5O7X1yXZboxXL70WT/6V6mwIAF/pgCkjw/OutryuoIBPWcmgAmDva/AssuD9xihcvYJbzYOswM9+AcTm3MJvj7WFuA3b1VfysdpW53CZzknQm5GYtxtJ2mwTK2nPriLoYEByCha5/tyceBNJLyYE7Kd3gEQ/HpnnTucx/bH5H17lk6AHU3OMhTAKFNEbiBAVsHQk7J3Qz3KBaDKPGeKFRPBpoJa3qn8QEWpq/w1xDXFBGgWrZqAmOkD6vd0ssuUrA+VOD8XgOftI9NRqJ6rhpC3OckvWcUvgH/ZpwcbBaXaR7ZGBZwBcJbwYcdBJ7YUdHTeqe0+pBMs4+2HBLivxUexntHSuAlKlJFFDMv9nTKox+VnGCcWA9DDloe8+oUR4VUJlaGDJVEWhd95L5yRcnLiiWVFssysqpnzfopXSiP5YZZnOXWoB7yewIaaA7TDoRy9p7zzeoAXjB502LnMT5rAOq5+kC/2tvmV8RARnaFxx+dnRkeMmyXw49apeWfXXasSPM1hKJiUG6+jcXIowtY3wRvpEwNXUZafLr+12EZlDNUMOmI6G0gAz1Dcbdyawttwd9jpTJS6zhxaKJM67kv9IE2HTT42jr3FIWoWB/jyzbJ4AMOZGQwvTGk51+grqfPPlFYhkLr4Z37ndjkvP102yBJuwQsJ6/bNMS6UuyLZ9tiHvU9j4/4ddUholf3liEzI6SljOZX+EVbBarW9f1/iLT9FbBvoaz+XuFJlxQQ/k9k1bP2qYMHyWfUtRc75zY5nv4uAO3pgLVSaYUCrDfObUQci8wxhATGttA50Dl+Th43obIi4YiVoyYcyqhGAo05go9zuZ+n1Wp4U1QTfgWeELv0S5CBD2FXaQyiS+KHUJ0zrBUY9NH0uHQ0chrITiw6xV3kz9WKy9UUJtgxAI0prYqcRsfkbBuCyepqlGjrsTS2EazDFLrQ/1OwY/s7cUyPrNwJZF2ni6ItKFxg5bxsTfGyvbLoUoW3FxJuLoJV2GhNSRUDT161VoHFMkv3EIEz2ZaEVEvMtUmgrXzAdBbv+oMjjfLAXYmPQTLG+BFC9sHWMwGDCpseQWOG6iIddYj/PmQNaAxkEzug/Fv99B0Iqbm/9loTGNvtZsHkeqjpX4GX5M1NiFX2XVJ5XPzhhPwgqJn5u0zYL7FZ7XaHJtIGi9UI34YrtyqqqnI8/GRWRBGQUi77A3MaLSP4yeWfn3KUv+hes3wgI54Hy9PZ6qzahqQOMCxIsYwM09i0GEcTIL2RmKkATUpIDSzlp8p9hyILpzNBUni4cw3ImgtYATo6tPahjESFJoB5PgtB+3XHx2j0Ybgr+MhIahzx7pAWMXiKqdlL/SQBuGFpFKWhaBekx3ZK9wTcA6PP26zKRs3tOYhwLIrpVXGLJB+u1S1VtgTscx8UeKHgOJ3oirO/7lo61EldohV6A7vOk+ZZMV3Cg+IC9Uyg/AvRtfJlx+0oOgsq4+4MNEBH4yJDcGjZzdq8335R0cUBQv9zfP0hWDsOoGm98Y+Pv6Ommvy642EWKOxiQDTlyokYKoen24k7JBqzAsyqLVcBfIg+4g1Qid5r4qMfrJlDXwQBTJ317CAWBuwCtFS7Q+73oDoN9CIpgIBlpL+h1HDtMeoqrV+eelEGUPX+do7bbDMjk2/w5DsJ/NmAMQFMY6ijT2mqCLN5+eKkMBApdQzD8iL8Lws7IwdY7vNrKukTQYbA9pPahaJDaedWLTRnw9dMGNq/pyKoM+omg9M1yoiCP0R6uz8cpk43K82cYIV2qEFdSWBDMJIB9WAVYGPryeRIRdJUBUi3hvJr+uLuEQcNo3TuyUebPYunVLR5NkIE1vs+p/7XLnPGYxQ9wAtA4XXjveqgb87GjjG9/UejCTwDN3ljtksKP0Khn13AUTOFPggf9sAmL+wUD9MMS2TObVSqs27HOaBw0+ulr83D8BZVmK6Xf4ZVU0W0S3cMBrmdfLaKIkzzA92uNtlpaXUM+LOwARYrlQVqbhgZwYYKfVI125ggflFZKhVWfZ7kBNa1s24OR3k35TGnzeuUjEV9DvOBKYVsqQeqOP3Ft29qAtPOriN2vDpeNCZNzGZAfijKKB5I1K+RKnP4pyIHv4lBJnPSx9elaxt16MJ1AR5vmOa4mtxwK4w1ZSwSLRuPN39jGpjVyO6T6psfxEHSa0qSpp2pvcrzbvVlj+g5hTwHUvhhpPKF8twrw/N6C7cYDxdquUc7pRiiUTO23WFu/U9doScGLjdJrTABnte9y4Mml4GZC1gsriR4UxH6K/vVtY13aDKb0YvhVUqyvP7+tPqsDImcx2n7ihgoIFssvUnZwZEVfh36/uXX77HhZYxjbaCIcQgiFgB91m5t4jLoyTbYtkQxejs2vcI16udJABdDMxbzClyjG23t1zHEAP/cALscVW+qmya+DpDMf/VOE8Z2CPzWD3c76/34tc6kd+TFAB8KD9gCfEXPDuZ3ZMHAcUohcw0FJ+tFIIjV/XMKavws9mvPDD/dzIE5+bz7qiArowJ+xazbigTS13n4q+oLUF/lG59KUdneeB8i71RR8giEMAdEaGVJ7m1gI/t7F4CDfNHi8pMf8jkkRwoJVvmz8+/MUhGCVaZ020ZZAkdDLRE83OScOkxuxyvPlSgdG03CXzNw1PlmAWylyjtPWv6cFx6wyJgoswkrQ5v54yjHmGSNO39N6iOIxVFg0rMajBPlzTQm5VvjNsFLm3goHcxvLlSiRUm9OCY5wiPEaNZVGcpmC1/WOLifqvfGcWc+Hde5+mGSk3cHsfR2Zb59d3JHsTk2tfR0xYFXFPtvF+l3JftVBO9e3uhXPOAOtHSukirya0yXo0z1wghkaX8lL9t5aEUIm8Wyqrb4moMxFS2NQlxXrrBDB4IDsEwSpXyY2pseUD4Jzu8lt8lEAZd1AhUDZGOntVnzyyWe/gzbGZyenz5Tqrd0P0h+8npl3uH54/VgUUhBTmVsT1zVH5QkL/xZH6rFJxQvIWPToCKtG0q6YFMCy2ZFeyhfVdn+rr/b7PMydn+hFbZhK5P3OfE+cmGoK/DTrwSsMV7V3tuDhOjGjnM53/pHYs+Rj69PbhJsHXFfuddR8pWyVTfD5OhWDDtyHxVxmJdzhyNDmhcSqrzP4x7NYlgPTe3jeLbAYx+KSUceOreiLSCmNa3VVD/K/pPHJeHjUZ/LxU3VfXbo/iVlJY7Qv/aDoJHItWtsqu6Vnrvmn+uLc+adkwLJuGgRJjOTCAF4c5hpu2N8bripqD/U6Hg6gNhe62b9c7G8LQzGEVt9jDeMoFLeJWXeMmyPiWOh2QrpKL/6wbLXWOcGgDBQhyGT1lUpq7jtSnpY27g+foYImbcGOljN9l3GURUGWF7sokeZL2haB7NSBPtRnTc6U31nR8voKACXZyghT85zb6V3rpGFDBOTpoamPAOhZSR3ArGck4Z3pzvO1bRoORdAtFe9Q0FoHq+57pzPZ1zY0UB2SaCxoaAS4yUJuvap8+IMaDAqzRnjeBrz5V4CZJfOA7N6BTvX0Y5a2SvyqTsvERMQuc8FCTOsQ885dQJxa8C8uxpzu9o559pS7FvC85roQ9mjdrG1K2fWz8Yr6ltNKKE4K0JFKKtgX7vvc7LrbGD2tBKDvjvVKUUwaescJ2DQ5dEd6vTGqIYlND4nAQ1li41/2EhRLPBDP8s0ZYx8OW9m0Pf57swCGKjdb7d9X1MoNUHYLTKriIW64xvR+LEdxHrZykwiTr6CYgH/5ZhSR26MPiYgaWZ/GwrfXmmi1LFyE/NlbV/9lQYU1Lfnhli/VsJnwRYE5VySqVj/SzSvmMY0O6keRu9sm+POS34pVJ9lPZik28STKnl++kIr8XFMdg/x0cHtCv44ZP+Z5ASXjXsWxoBhXQB9/C0iZ1zVgzRZM9b+m6ZliIFzTr23SJZVz/F4r+dGqOGjW3yRMLSqDOMbdI/Xc0FmPyGbMv69mFh3gdhtEv+KgLMcpmMAOObs51sTdumu61QpB1fX3Iy6Ara+ioEhorK36hca/7diQVqmeZo/5oMQsbQ2rNJzP9HgsE2sx13cO2XvraCqYqoXh3+UbyNFxDUhe0bAMaepQr4IwIONhRA+SE4kdrVlfRttf7CUXALmaR3oQ5CotsbK60OJyCerfiAOnv08W6oYaRxBE8XMiI99P6YkF5Cw8ZsKfrThKu6iLBeo3F4K8GHAjhC3M9CiSCwbwNBxS6Upt3T6gI1Cmr/KxQhk+wyOBWVN9GVD0kEYaMXQiMqkKpsfIDDI4x8jOH03StkmvSb5TjHjvrCWNCZ0ySML2yda3iWG0QwD9floP3YDfBL72wzUncDY/BwpZBSUddF+wb2X+mojJZ+zsanwKrfLmiinVQUJYHsAdKIYuoUpnRDP/5CPoacn0MmU0IBHBllb/QcEs8nlegYeWwxYKdAju90tOqjnMguA7AQ3pPZ9ofW2Zdxi6bQevsYgKeN/oRu2dgdJdIlnH8dV6WmEKN6caAEwtBfJdtHiu+IqER95o1KeC7+2zz3MUZ43KKPZIAEKJ+VaDNk8AABc7gxSRumE7/X2SyleQzk8Y8edHjhp2B+NzlEyX5X8lT47P8lNBQLllR5mbj38qjBk7gSLAK7Hd44bz0eC41CDM2oT8RChVT7BAxmcs5a7DC3cyjjUOaB/2237EaHyVBSmNWiCzmWcc/D2NJk91wpyqy4OKFPIkE1faa4R/0IHGxCpURfUzLDpKb8Mz0LnG9llWzNBcERjp4HAxm5sMeuFqKbBFTvws3WGfiauWNESDMORvxr+TldXCLh8gkcXyd1W+ixnrJLNQFLWylw0tkf+zU/EO8/inUV634O/gobnYwCcgcjHJ/syWN8sAQ3uI/A0JP56wfpcPV1l3HxshhFSfsHsU4uscw7KCa+FQ7+kqGzQxlV4rnB6F07R1kLqeFh9QjgIHfPFqpHmdgSvgpCdONXJ0PLGrsBxAjP5R6C451maj0B/A3JK0N0MHqZFr6i86MNSkS1HBkIAYukgolv78BcQypM71aAgnexrCr+rp09SC9fXHEcdB/TTV5kfEKVmD2897BqDDjhwlGHI4aFl56Bvcc5PASZAFT1YY5zAi7dE3veaj6YJ2fcyuXH46CQsYNY0BhzOCbIBTspMBpFoiPK04NIVO7BM97Rq0mCFpoYmjmKvjF66hL781ClMJmPYM5BuLpktTlzGKRwReLqqn1ifKLZASluojydNPLEC327/Ciks4Rt+orY1oroTN2xald6rmVRiZbBg6C+NQKcgCjQ7icOtQi2VclQMdHOdmHSYP3bDcXvKIR608nJb0t7hZZ0zxCehEk3Kno/isNvgpgnVntHauX5MKk8xobsIYtXxf8x3SEzUiuvWO4r4VHg8DUBVRU3ROA7QKrQEea1I9GQF/Y9vakJmWDtIQF4wMc0O2dH8HHCD55iJG+cEYqzyQWQkNKaTCXq8r7XAa7coP4F7v1lsF41bpBmk9aVxf0pG/j9HaQRAMgAvs2vxaeXXhXZ+IodugmfPTDwqQUUedmkOh+sPfs/TdyLkAaMsDIqB81jIeJfAJyAQU36+tT2J+fk15DR15NFFODZS/NOQPhPw1QygZSUMPwM+SNEBDNkdoL7WiMG/71vtf27SUCH5AkOAeTnEXg2WP98ruB6jpZdcm2OeGxWf60thKVWd9K/pcL59o9lcrbQdq5Yorp9zOq6R0tw5fcd5ZNdnYFlYqWEn81SlSfMQcMwbLyjVoA66Ru1WQ4YDby3N8I3oWvFLBgMkPQEVGUWsfWivA3xnUsj9hQJm+9INTd0DuvHbtTUGKU7wv8pJHLLslFJdHr/xGg3AtVzAdLZd3U4B2CRVkqSOQXBA95pudKTHk2DnTbqQvSpwsIdP/iMDCFd6TLRvD6K6Y4fh0bYrAEH31d0Wa+mV4B1RVFt4jXDwZ7G1/20wvhFMHMgVINTs1+8vA0NdkKUJ0jg/SOS55Z7PBursXXPuVzxYuVOF5UeT1ALAcL9+1easJL4zddriDdrTXEQSQ3yTzYO4AzJWu48aMP6ZnjUz7eKdnOEMmieQlafEQRMFVzIGUlyL8yNI7RxMIfjrk0ZsTA9Oo+omcSC0epBnWreEcPHQCGdFZvvmuASQeLaLbPjUlumhXH1Q0OfmolQ3FraVZlvAApTEJonI1ehmXHzO7001M4QUD023HPSpimSKHKBCugffWW9imImXB7g2Gct7egZ87V8PhNtW7nSb1XIFnJX9uyF+oM74W5tbKVMcL6DdQx4TrpN1Mju7seps/rkaulkddwV5tpP+uP57zPTEB2/305LwUdrsha8ctdB6I7uydPkTd+NkhXkipGDtAJSkzXcJazeeesXX/imD0DqlVd98mHZOY0ELtQp9JVwJzEnBoMV/7TbbaFffeWZrMG4cYWtsaCTbwmPNqSIk1d+Ju9uglcG4eVsgIDTwCXSD+QA1/gwUvE7/3ijtKbDz9rxeAwk6mK9fkCTt6ZuQDeGufITRensZT9Lap7kHJWL+OZafSDICgPifNPTCud+GzQu+eXYsHcNhTD19r4He6TY1jetTyiI4sErmZwRJUcKfem+NXTUQH9SV79Pw0Q9Gekw8+XME6R9i+A4V0an8uCCW/axRPq6MNntT3xOIkX0pwjhOoVVAzlmBEQZeohuEnOV4awMmib94PVveljqMVAWOvXs18/D0+n5V5reHEYCtZ2k9ChN744JxHZPiInwRDqsDIum7A3/14m816ET3gPPJ48jx1qCHBgxyM3tdZdFhq+Xl7fHHI56DyBKxn6X2Rki6f4S/JB1VyUMBOdPx7nPcuvOmfj2ts5kmxx71CC5N/kwsxZuWjy0KkSWytu7HOVdAyWZ9xwiz6i7xySakGZP2GhybQzt49xWRiwjIRxGP3jz3gubZGfeE5x/vH16xO0R4P5lcjeJM0/SjhhkSjXM/waYTo4XvhbLh5WBQ2Sq52FCvb0N6ZCXRVNf1AzK0iBimF4+b6vtmR0ZvvIOBWSedtt0tur/tBPrD31Mg8oRaZUntUA3AmHCps56EBQ/PyKdgBSVr1PgL9zIfZR1BHhmACej1UkXweBj/BieDoCFFPEWkJHHkV5O+w3b10SGt7RXm1hzyK2Yfk3j504vuxUBzAycEGBaBVo2j9vbm75uROEideXK1LEJVJRInDur6n84yEBYUvxvYzUQN2GBg+8uGRCH3Bm93NAvH2kobGsA9vcN9l8DZ047wjcXdVzCwlpBWhjRsj+tVAl9tp9wdBOtjrEw0hL6zt+HlWxjfWEQNefZ8+eKEj4+ux7V4nN8tH0ajWqiKcSbRIlpWFYfh6dgpxe1CHFAqB7rnpkDmL7bSFcG0683aaO0AxkcVULLph4I0paBVBkBZdZnrc0SfmyOBtSTza9foFN4EAjifWoHukEy9DmiKaw1c0QU9+EiVDv9TahU5P1XtAYjKhSe1kDwzU1wiMb9SR6++rga+ApKDPEgRW13c2SWGiKTq5CPq/ZkPugPrirAdsPdNnR655xPtTp9xpL404MpJvOQ9NPh0K3yxJ91vTSQUx5c2d0VAc6TVAdTxPNDoWBjolRTj7WN1sUAtHhVp6JRN6oVbV4XNJ9MQfVhnJyifpWG/vwCSZT8xeDG0fJLGPqVH8V01pg6O11om6NpCDzrMnubiP8W0sCGLBnF2RSu9vVKYPa2ejG/Q6yyYzEV7mXPCtmwIfPOvvtfvB0CA6s+YeQR75yatYzMktODET9/rM/GmLobZS8JKw6ZJcjuLQXpPLFGLvbpK5sWMdKdHM4ACF3O9ODQLf452AoxLT78TEMciGvMMyDDrZuPbzPG7FfB54X+ig8QQ8IcbJg3La6894PxZjn7IszpyB2x4wmBAx9ZIGW+FBgZPBS5O5WAi/B9/fmV/HxZJhz+FKF8zR9VDD4/Sh8KGvSCyfzAdVM08MW9k8tM9nj8CIxABCP9XTRkPtqOlXI8t6XddIDNk1IoUe+8jGPB83sI0GqosV39LnGaYoRJsjWPx8+d0diDXaYzSbJieef6DuOOsLF0iQYQnaWfCiR78uKxysf2fjVaoghl6zqBbR2p9Xzd9pReML0H4pnww5gNrKUS+xn9JDwPkx5xeNnaUpSZDJJ5kzKQRS0CBCZYTRb0dz4ZoMtJ1jxOmjTgsmfJAc7Pkt3/0BZYJe7yKBECH4EkWU9dzbh+ix5QXd1LyB04FMJNWEVEVAUHeCTh+Sc4n+Wzhy7O8oNhVw0bAAVr+0aouFz6eqsXTbg1YdqkvLWfS+E5GpU3MqQwYTzVUwL+c93CZLI1m6WGVUTNoRt2jAtKL42SfJLRECBPc3DD9+tsP8uoTKNgqPQE9OGOcYkCFToH1EAuK9viRcgJhjIY4OMjvWs3HZor63LOxJvEuWqB0W9twA3aYUjwxiytlwBHjNvfChHL60dHZLiHj8QSDQEHkzZN4GD9+55Bh8yEmz+H4lNT92JrgliojSCVhdp4Z5epqQZUiqjEamUDt2Ip7yHvf06PEsCz+hnnD5+77U3Zue1hDn3SO2aWBrN5HJI8dTKHLi+K04Z4WJmD4W7Usvh3OFKJ4ghxPnAXH1N7BGLIjYGJw7uLz4cW9qZPdTpA0VqKZZ5mT79CyMOjP0lDVaZTIdDd/D9+x+vlO/m/8e8tr7qBuYfUeR6+yDu+5XzsjTx4h7Akdlk1TxLHF2pJ9k0sU2Yfz0L7PQpH6ICQSWaw5AS83vYovPno1u7uMv3BBpVru8QsjEXB+P/r2jxKlMz5XYDzHOUbBH9g0/PZz5LkJHogf7WEK63k/SutSM5UgZlaWN3xAC5Huu4VV+FR0pUR+PVvIMS/x1aLhro7df2Fk+EZ0+bJi8jreEF0WiizgqmnY3gg7y37m3gyD2X/aJSQC5aR0n3u8tSfj7b8l9bXGET1X2+334gDgdnkZhS+zWwahZHa5nY/ApOElPhsRdHTTcLJrQPz28PfgRowlLolkH6WiY+p5x3HSrvn9gnHoaTdY21FgiW51gobu8oYInInZXPQNH82YyFcjAx+ZxudPp1B9FriIdNvggtvYi9a4NTpPOTrFXsDfUpTUcgRIs8L6C/Yh9r20G0TW0n0Ha3tEUoyyZC9YVmc1R5BshDonE42ZvvSeBq/+gAE9EGxXs+dj36M3Qc4lo/Wm8RIuiZnSymNOKZ1PieHPxdNmxPXE1v3IGTB7IV8CP58wVWxSi+yLnOAAOmHCnOdtiwTX4zonvvRrzzbtL4aa/PUQBiL3in+7JbV0t5cqNwVVR0lCXXwsTBXSv7xbOMdLhHYJ0YGz4dc/mrEWuwrt1B5rJcTprWKyQ5HGCZrGWMe4K+cSo9+ouyZyTB95n4TLjC8BjkdLCD642NMvKrMdI86fp+twMNrC9kEXSqBovVqin5BhOMAItk7+pRAZtg02+2c77R7zySkjPoxZn6EUKSq9++r1CQjTGl9T2OzUDpUxGbDgmPOCrHKJop0UGSVwnR5tNFssruXrP3kGT4+oCihrul8AT6KwUPtkoYMlRbC9RpLFEDSPcbbcC1JxCy/m+7pwGJHBLp2sQ6fUK1EZFHraWGFsKTpMyfIPMhlfFX+vHWARW5h4jqqVl4N3d569p1VWEDq5E2g5yDs/dRn/HJPMRMWvI4ndND4jmvvnyBDhPbuiOCsKWT/upvPCPzZDMC/n0IiMQcKhTjtb9gujSDpekqrG5kuJLnZFwYGUK8QQfdsZ2/6Pfr8w/5kZFyf1362Q3AnRMmziYmYlyrVwoJ0gPcQ4cFmQcNMEh+ggMCQG8cAnzao2CQfFWdHS/fOAf0DqbIy0KHX+p+Bq2Kpmd60KWexjsVwU7IEXT3jkyBFlCVFgUJ0xRUEmixAOoPbaUvB92LoX9YEKHqnDhly5zZMwc44bGjKI4gt+K4MVUoQLTBUEjpfO1qNdhjC3mOBoBuNwb0vuibRMAiEDOuksmjrArTeIkTzGQ4Ts4XB++y0io13tQ5RIQcZ+MiKFYtpU04MVf073OihfEHHlXfvIRbuTd0b/Um82/+wWCoabTPriWjkk/gpjspAC9Ru99YZWcZIy623Qo7GwNemjJgC3C3XknEE2bp5aILM8n3+OUyJGXJKgsOFgao1cTho+2w0ECBqIhNaE1u0xH3hpLqneX4z8nJDePALea9LfIC309Rwwf/GTEsc9JFzlngtrzG4A/mEAz+BQX+7bu3nG6OJjwEBZFGUUyxuLovEuVeW1acpe0hc0FLM5g/FCKnn3hV05iMdKny1uCZUPpaIKYUikePXDWHdLY92BeAZ8QwYu8MyJ0C7tlCsTL3YlRzsfFZu0n5ZsDzHDXnDSnonrS8SO/GNo5MPQgw1iWuClFG6XWPZ13YNNOYekjRyYMvqMwGGrj6yzaxD2fkOt2xm/CZg+jNPYDPR3umqFW7ThFnFK1mNTDOsudo/O6j0blXsTEQnqHqznMvE295deL+rZ8bPwBzGgVGb/hKbKFp50OvfeIjnzTwR0DT+8lPzzWW7I6WXbPn7pfTKE8qgxQTRT50w8ZDK8rneiYEi+aT5PurHfoZHRdtyhympywBo6fGzWec5eRjvERnI9cslsSZ1k+840lLiiGg+eIezQD86L7Abl0n1u/oul4U4xDxzlZcFSYVAC9Z7iharKHv9dbNs1r3nE+E9M8kppP0ej+tZh5cqoUhV47UWFdXuetTygtGo+3rDHU2244qFe4PD3sERaDoh0AcVTsR4CnTHSFmmOB5Ql9RGsx55KwSelwUnqSij9MyB0ZYMBOcj8bsRuat+LHSxLASp3oQs6OfCV/D8pbSDtR91VqFbL06HSzROALM9GSCXk89houmodax0TGdO/wjzspZLKk7C/IdglcnGLRap8splWL9+g5GKDwbeu5oSWp4M3j4+RVt+3cPHhOcPC+O/XOawD9kCbpL+YxJN+CH7UggZUpJhIGttYZ7wE06NZk91+eiJvuSHHY61yPT6KZce8Fv1Fd2dElAnx5Wx6d93aYWLTx5bsYyrsZ3f0ahTFEReuRaVYqPh32odsvExE5oJKMCgRRQXXI4X2jTZXyD/NIXdCT7QV4KlwVewuwq5ahmsEzw+HyyHyZNxLgDc7Y3+eFO1bqgGIdDOB41YubRlzKl6MTNmrxlGLG4Ho8FiWCM9nnJEng61qJx4lCZWjPlvYSgxc57L6GtqtT+EMAEBwQ3sYJglwuJFVW3XaJy01fpMdwdzwktcTjUsee7nd5IYvk8HFII3aecg1dg2P2/I7QXsnIzsfVhQydl/Ngwq/my2faNcdMG4bXwrSG9khfDUaCEwMExf1cos+bZ6oP7fjV76J64bdDpTy22LtGZsD8nlZ/t7dsyXMIb6BQj/Apacykv/oXoosN9ag6/nS52vtpmz1gVqfE0+kVIlLkMCPck2UjWuYdkV8ifrUZfNWw6M3aKcbIKkMrfAxKVyLMVAq94Z8FM7zJXTRMkqPybUyFaBOxK+IDfw8ICiNOVeglpPzIb6UB2Q3eUtfRAeFHonMR7+VIMfsmxZb38f77YcmNdCf6Jb7wYE5PMkdD008JlJP3AOn2MKwRuuOLXe8MgKz5Qn1T2puG1yJud0T8LVf9FTYcdd1xB2qU7HijYfV6QGMzZECf6kQxZ1Gshd5L1qc9VB9im06yb6CRORn39CsQYIwVTbxwqBIDghRQ68GNgbgpfe7NOQ5vEOJA1DKkm+6hYsf51rNhTnvcoY6g+6JWDdIgxDVfAwKVM0RnzHvqG1fmsqD2gmHeY01AkY0opM/3Sm+pp+H1azukX+CzJMDbfm7IiEmv8AIkjaGcYPrD8yJmhGZmVlk7Ig+HP0kJ9kkWJLHQXr/lKieRXMXSDczZPu0MH8UPFal+dCz4IhqsNznT7OLceL34M/F3Q36qTQBIkrn1VSyCXClvU3GGXDx8c+0Jbl8dgTuY8D2VGEbgIVsCd0g5SiNUUexC8AQgBLsp7ygANwfNZ3Dxhc9guT6WWuigah9JpOOwML1bQ9RzBiS/YXC6RpXRjp0Du1v3lUBhJz4GO6st9OMxsEYUM5yimkMZVZ4pk4d7z/n6yEweej45K7dmQ/IGYeLN3ZlcCD+TUek11jOFp75RboTWbpASmEzi5P3daHAwd1oNBFmvzhF0MF3KqZxiN2frntcb13xD5gx30ihhbajddn0aPWI+7lG4tqrUD3zKAtKX9Rinn9vEsEPNemoioMKHw9elt1Fb4YbfSMW8KCXIjmZ9oeYAY92vl8xGogUJDqgceqNG5iHRCtUJ8iXJqW4jcjgGuYjfzU6/4KwfV1J+Illz8PtgfY99tIH07WDo040gIqqPh+Wtj2UiimbYvDQhJdpyHEcGEj7TvXpHCHQLVox+83cleq2ei+7zgkFj7YufdT+UoiM88Tf2CwXJe3DHS6WfyKCbQhy6+cpHY+P/nqLER0QlPfjK8dw7dLwAo+w9hJK9wNeaI5PvjL6NKsz2OijsmqhSbTn9pd8LAZJA/OaOnMeeT0EcXRCFt+O4uWe4JyRCp2S3Dq7W3HYeGgbGcBRUDxWDQkpkYyUsneIdKsw0slzHVGndgvbj1CrAmMTPr4+gyBRFIqcSY5cDvILXFi04aOaJQAy9RotOJacxAlO4GyRh9xq6xDziGY3300GdRTTh+3hCAsDaMdIdaJphMLGw9Mq0iQ5i3J8KIyFp14O316NQRSC2QtcI/2X3le6jcB/o+AaTwVlGeH4OZV+9Vzv9QZORauz9RVUzZ8sz/CGvFAoyNO/IwOQh5YHFnV42d15Cnk5DlZCeIjdK5qWphU/E3aZwFQJfvSRVqUJB2VqZwb+K5svqztDpRPj4Arimy+ElSLis0AxCILfw4IehyDQf0L97bVLuAIJYVDLESbkSRpiq06IgjDBOyZVkhr1htHwOFOqgT9JFT8AC/wUcIrJx0oObl+/inUSb5gMoKBCkupq4QaNthz9V8H2A1CiSlEJrgPbmdfU73EOaCAg8l3h9YHA+xkPtBNpkUQcAEemTx7zD16bje/Q2LuEnBoDALfz36eImWWsDcXSizsSii6pQhiLVAEzYeUg1vM4/gqLvVX3xvAvMprsuDxfirLuJhSw6RO563vfIIap3Gv64vJeuG0/4Km7BJFLoNNpcuLEVp9rp3QfG6g0hdOerBtZyPwgRDqGMKVEAhsdmLTu5oT6EIDfo2Tr0LE0yrV2/M2RhoP6dZEleL4uU5joV7hu8GUjn7xp1Gmm3b/t99wrxSfGM791vbZB4Tmy4Bc244Co7mS5D9Gz01Rsdlkl+EDyshyN49XZlWCXRzs14Se6bahX31DaYEZ9aZLSQP8wUNaOjQNohMk2DVx0iSQwMH0wPQfkXMX8YBa4RdJyAzUalZ0d8fe/wAsOEaLKzPR4wPNKcfpUzL/eh5XmO8HOuB5xOb9fun00nYVwftA0HwD4fZJNF/QfVhox5fFAHWDeug0RQYtQMAEsk7YwpucmaWs7Tc495R9cfQe2xr58D4Azhc33yQljM29NWR0H7I0o2qy/YGzsKw0RJugJ5GpBdOF8nTJ8EiI8OJxI9vgndRzDBz9dDsNoqi863q4cWYsGtnOkzYHLSm+jl8QlJ9pyQmPSN1hl4c9G3X7z7k6PGRvt3jZz3qAlRstPBTnSCz/LhlmaL4D9atCKOTrxc4QvthRf7Scz57seeu/NWIdY7WOjAUuLSB4yD9JjNLto6ZV0OXNH6CU+GsAuWaD7EJYLJ+1NMgcwJF3xUyXZzLPkkSRQnMKC6xFc+XpTKq1kTCB+I+ED5ElsIReGTTHsuxostR+ABA3diODWTN2++H59huiKB3h05KQzBioQdo/pxg8sRWM4yGr11mXksJmhw+a7b5gGfOCVeBXnJam6iuj4964B3kGQyRyqeeP2Caabb+8eGXLjsMqwAtA5CgYzoIbJFXqO74FxTSjKkjR4KhtyHN2E5v6BKcSn27hjds4NS7vti93KIBqxaLLK37sDTbStGBJmQeAOCLQUnR/66eRjUFNdwquh3em4i24NGhYMfl5Dn+OSPPwTa4gQq5kvO7K/unS5ed1IoBBG5py0A9mSkehDYDHY/H/akPTZRt20GfVH3xI7cB9nxTKBAv8egEk+/SnB2zxpviIKj+ZAXczF4YVZ0XRo4svIRuSfdd62rRpUQHeKJIcQeJMXdFeTFHw1bKGe+XuWD4FdZksUB5YXJ7IXuDmnON4h4Nh/o7NkWYH3OG+PKliLX257ZrzxFDA0ehk50V2VpzUYZpCYG+NDhfkCS7+h8qvBu5FBTYaj4XQOVZSqniyp3vtdux8lYL59EkYJAnJLAmK78soWt98ZMMFMgUOjt9KDG9QiF/qFrTKcDkkLkBfiR+Sx5O/0oQiPqn9IdiL8nPu12kn3T25IDuJYTKOWl241QCktlMe/oHaB2FqmVXzCnpePFnddlfiEXLGysoLtYFgG6PjU5Y/S7ba9lncUjwsqNod8tAvAcg3XX645uUzNh6Z53Y7eXD5lRPt0OSLSPAfL+2d/SMneRpgPbOHvP0PkkQS4noWKwC2wuIZZ4tNhFGhgRhmqZJp3LbVg+TGSBqOE68dw+itaCtNSxpiMbsAf6bKyAOGW8nCErYyjikKHwttApz37HG4WWNS4TD096SrfwZ4FPZvjFyFBr/os39aXveLenzrZNHVRpuJ36AGEGFeHRgUcZX9Bpiv5S72c80h3C5Uo+nwGeYkhXnw116IEKm/RA6yML4Qh62+vy2FZIjyNfXXIxAy6Xv56Zhnp3qA2UNDs9mKAw6LB6vns6gIMeq0fypRl0i4I1A+EnaxpDbMUpDWBawj66SGdzFgxZKy/0sWeBvev5aKcDyp8puvyGJCm3nSoW3IlkZbzmg+YO/ZhxQtkDOmacPghkxBP9NkSZwmG2/ri8/pwe38eSzWUsePbiw0O35+V/mhPQwTs+pxg1b/4EewO6dRmIw27PI4KQD9h3sSevG+lM1Hy6PIkKsVaaeuJ7wxAGm8tSyadQ+kScgKYzf/m2vtoZic0EG1t/bchh6TUBWb3vkGgqY32or8IPQdPGz5IncVaKC54YOYYvg4onYMPTvW/2c7xaTtA39rpRbhPBNK9MZnI7kjdb8Q58dz1YJvJiUWfzbACKZ9dikXzIWamaPFFTX1/5NcRdvwQUe1nBBPEgksctuQ93OEYoOJlICX1x6DqSPIHeZNmuqHxK9NUUer5n3++XaN/hZ0XJHRpsG6OvzQVt8Uy8c4AAcpkvZFc3vGj6ZYlt8p01wh+DBpUlEAsBJsJNNw38ByLUkvSPOWFT7aOdqtMXmyK/1LBlUL2TJsnW+5B3yJD5+yE/StB87GeWtneEgNcOPbq4KeTauk6Wk5VGVv1ioWWCLDy+aUOz1UeG+oUNPcNDJXSbI8D3/z6najvtvRzaCF0m3eU21FLack4hbq0aeIQbnXdEvhKHSTktVZkIHiMZm8TRQ6HT/TlfRAuEB6MWhkh+Dx22/9r6rh5qlWS7v3J1Xrl3yLA50lgi55y3ZVnETc5Zmv9uvrEs+8HP0N1VTVWttaCbjmf4UVKcUvE6i++SuqGr3ZYYcA4cQ+fP1u0l5Y/eSE7r41jkZ2QYNE5Bhe576WVwpAU9hmw/OUQkL1f1ybOcNNElwD/rfbY7oaJ06kkV5Z3gqdEcd1ZtdtMEhl+ZW9B30McXIdMmZoWhpNwoPHAZvM3UIHkcIFYEIWzmgRr+VMp4BgrvVFJx190obpdenlgvtUxzcE2730FAhU4d19GrJi2q0sueTtNc2qW1BiGCW62QXIA3XWmOk5KnNW0QPMtHRWjQVDzHwfybZ3lnuKdjR46NuJElkn4iDYP46eUpIj6Pe6PyssM9RBkbjGPQcTRc+tXxLo9EtJ5Mw79P0/hkdyx/m8m7gfep1Yvnfgc+2dHuPLgHmWIqyOrvgQjpJ92U/QkpzvWobjKpFgi+aRfNsK9DYxFb7iOBHJ7EOndrko6/rNFvqvURkN4v3rKKGGQg3WS39hFCluZSu4m9B1iF+3CzpFGLm0YzQ/RnowrzFynYgoZrhx9KZOx8+nypuephOfKmHN7y0BkCvffhCdWTuY/wUckoEL5KakMXS8bUF7rfkdy+KnsbEc5O3I2hy1N2MATxcMmEqqU+OqfiDqasO4UJXH86+XJXtBM/X2v4LUP450Va6TTYEob7jGA9TPC4ES+cHTFLDgcBjMD7sIDW8cq9QyfIiaA9T/RMCSOz5O5BgovJG2i38sv2cHoNfWh1b6c68sqKN2tXoFG9OTqGo5fyoyDafIaIHTeeRGvmeCLApg42XZ23H3IE8w/QsxQhJXk2Hj+M56P7Lqur9DsIs8OkiKPI7U8fdhqZomGPtrgPcsQX7z+Uqd1hF/lTsXTfM6Pd6dF2oNfhzunyCvrVKt9ksYfsQJ42rWFZ4JzTa1ajPNxwyQIL/gA7J0HefIbS2G7lZ46UUPPsjOQlYCmujmGl1q168S4glGJtMvRQ42Uv/RG4veW+TGAGy2J50nBSaiOqd/MjrPDdH+WSLAPY+SWLD3SIq47zXAz43HlzRWMpkpkf7aRDp2MgWKdCvAJoVV2J4lJQ8/68NcwLiGSz2G3T6zDW7LOn5NCDvL3StKMVthT7JzmU81cQTLJ4s717OCdJnIk3nW/0wyNA7IjC2J7OnsaGoOqQHlrdP/eKf0u3WTIB8sv4kX2KgY9Q6KBXMDnij4AiomtA13xuan3x/ouklGUKr+FKrZGa8HEmdInHnFa0Z0SMU1ZYPByEnrOIa/kkvGCnsFuWVvJN1Cab4mW8pbxFncXHZLA1PljtXaP+0e2GlmIvoW9opqSqoTWcy/+cuGEGvx/A/Hytvk9F6cLTQiVavAWZuNRfpqRl2bTwy6ljAcvag3CYV/L/2ZtBzzoaF7KTK8lD6EIC0hkWz4mSMEIDyqrs0B96cIXQBCWxb4bLEyW9M6JVpyRuuD5EZp2r7lwLbDHJFy/0iSE3DTxTboqiibk54JS7CkGBfgB+bfwzJREqC7UKEwLSd+h2je0e/asunCk7IwFfkWdirSauCKT+Wr0q/ZKcs29F/8rHB8ye4REMKc3ukXVDsE7mw020l+5dbOusOJuVioaVZpv++X2CHn7c32ILZD+z3XLzezXDfc6ilfuFy+5XWsAMKOyFuwxI3USzi9fwKhRToQx/pl8Oa5hjAH1ZcY+qHcBMr93YOzYzf2RB7bgkK4u+q/fUbbQOE1BV0/VGg5JxCdclCFsizzfGo0BU3RC+CAtiPIqnKdmHH/RcVUnubDV04aagGXxq+ld8MuHKq0LfmtD+W0fKOYRq/2xxxgBX6xlXjHyIzhTMvKeNEAp5KfCEMWlZwdH2QkFGLWa+uRUa7vhcWVEU2G0AXUvdEcuDy7TYu8UXhlmIccW6u+bBfTfXtFc9ywSqwDi90srYv1t9VNIU/Oj2p7D3XueSXTDAzfNFoU7faKdNwsgUuruVNCMlUyNKfzT0n60ZSKaT6jtvtgEIGTgWGvvOcGK+zI9MhIxk2aCI0RsIlO27I2CljluF7ivLoCxWvuwQmxjmz1YVftFRa2e1z1h2dVxSnFwUqF+A/HV8pBQxvet3wlx8a/qAcCkDNz19C8daJj+eTXlmHEE4eViqRIO+kBW010KQFvDa90oCO36f6RO4aK1W0KP+OYyic2qdrb8yosr82dFB6GwtDpK7Bo1JhhFE3Y+u0BSlJ9LliqHZLRHLg71aCKAP+QO23C81vm72oKPW199qc25ESj4TtpnQgjylcn0bv9xsBqi4jeWr6LzyPlTNMM9RDozplPDJOq/ghFFtiZjrXwX4d+M4BKBR15eBo8gVR8RVLDIIWNlzNZrbf4GgB0E3EYt+VcBju6e8Na2JvzyphJA+3aMAoITVOGlJsDyBNXOx3XfNdjqsR43lCBWdoYX6s/853YcG5Znb59Ad+PDUHJzoX0vzjBuzWlJBjk+8zgnJNTciclmqHWMKPirL3YbcIvhe/G3Lcmvlb0oT4L6MXwuxC2VwPrOfw7TJlJPkQHL5cWzOzOjd2SBfPZS29gx+N+vLN8+wTmktu8hqZfjs3J3rUS/5o6flwvYSslOO3JI9WIKabZX8WmgMb/g7bwlmxLA4XnEMoojfzA9WC1autiqaF1U+UOSUZmZL/snGRdiUJ5ewVlxwBP1nJcnPa+/FvB4C/yo7jgpIOmtPSvKIJ4+AjFnIndukFYgOUUOCGnMxSuhteicJSrNGPlOONpcBlxu3aEsuC+9cEGUW46cx2SU8ZytpdZSrHdJp4WmI9wJtTdguCaAeDLeYgVbECuwDk+/aK5S/ZiyoHRJN5vG4Y1dDXbyk383J4syK0IgUy8jFxG4dgeOeCbM1EQoolW5Ci89+i7ldH8CZRM/nAglS74gAWG8Q+jIkUb7C4zQ/XkP9NI1thCvurGaKyGTcDWFgrp4ii2dI4FacOKU9vj+tcMOOhKX5K1PxlMbRNW5S4Gjf7fdF0QNpDRpLrusGVM8lF4xXYSZt7M/PQRWWTa/6fukm4Q6u8p1jbdjsSCDLuHvJZgqzDplAg5Hns3JPcPE1BM1OEcD65TbwJGFkTKcutJW9EiA8LSJV7D9xnnHhz5+wU9SndSBAKyEC5Wz5Ub/shzv9rAt2WL8k7tO617wq1Ljn+gPg8Ar481wkLd8wltK9+MFgCnLAfsOukvdb3IVtlgTD/bah3A/tubCG7XboSMUbssAAqSwQCzxw9Ysspl6LUyFXLyp4qkw5UqXqZq7N60/AAQ2iHplTaWoBuBB3Ub8C4b/7hcVpG3ejEhsI6qwF8fCccNUZG6qPvzbpbMrIsDaazn07Kl0htlfZPnz56wKBVq7z1IUlR2jJxlRlQMXAo5p/3Ze0egBoT0WZN9t8vqneG6q9QYlaNJGJlqU6J0tkBMuGIS0L3TSHfZRJX3ANujEjpRMWQDGlhWlL6GpGTlHMyrX1OQqRMSaq+w3mx1qOwzMnHJ+qZwW2fhw6pYqB6JpD2u4cha0Bk1uJIeJPpj8ND9Y/9ciZ4u+jhBpSnX03WZoHFr1Z+qjskxDmI8A0Uuo7TdXJvdplkVEdTF9M8vZMc6kPOtSvfnJDpKjwGtV/2229VXyQVu+OZHV1N10TMgCnbN5wbPIgKr9mXyJ6Ukhpj76lAZCYMcgmUUaoCN/86lwUwIdJKpXnF8yCm7CpmaKidXWwg67HgAsO+014s+GBFilJ3QH0Pm5IDLw/WPH1YOjil4FjFj8OZW9flsNxIy3u5OOgdCHF3fMyZ3RgmnOOheLgaFX/MjqHRamEFoPqSMc4fiPVFoBezHPmk0hjaTEn0r1EZvBuYWZz7YLHzywqb7WnYm4yRnZYhkt+0N6IMMVYOitjUtmnV4eN6N7vUay8v+IvTPG82xM9X5H9vDvREwxR8GoPw7nKfdYBOTHo/IXZz1Nyq45VfNluMWjkY6hO/aeuCvBIE5lK9l0mm2VzUbWk1QbUoUivrQ01VUrYeLe4jWYHsbtxJ3lPfTqfTqpFT/A7PmUgSP2PuC1qne3x4GBocGZZeYJ6JbDAHQbJJb7flj+Iy7aDzlfWlg4wb1F2xdx83D1gCL17w1WrzADy42N/xr38eX6Kjyy6YPIbZfzQFQqhIU+uzikUuaWN7zojwZ5/TxYLXMyLyxX+FVPxO1Q5res/9iqW3BQq4IT7emDYx8N/3eR6XrVHStbRDka5C1qdk1C7QK9M6yEZiAHVET+49rQ158JJLp2VFkLDmWIEM7CB4TmXpsDulP7ZGorqg6+aQL91FxuCH5lL8X4g1NZJKUWjqrsX/1kIoxC+AD5tqcMwsjhkVuzycR3UvmPPcEMn+a8ZQO+ABMeEp7i4TQ71+3vuvQiOnAq4XRc6yp50oAqFP0OgTXijfU1AuY0a1h7R0xLTotWaQflwvcjvn+0dJARCLA5Ku5JhVQa2Ui/LXxip0BfMLhSDuiIFalkZOClHHPiTEgjh0qP5YlEWq2G+Xpyu8L8VUsFam3yZo+XcX+WCGJ7wMG+1zEc3thEu3FjXaufT3NLkJaIeIrMmE/tdZ8A1fOaJyFC3eeI0Q9PJkbbRz+jCo8mXdEltKet+KfRU/KyhzGIYL8ZB+Zt6bcF/SbuZ2xZT92+3f4uHGz+/sN4ZUpmzmrVc49lpghe1qLFPnKyuMoQJzs8UAiZYY8h/3NyfGV+xFcOduszL34ZomqhJd0lEEBQ/5Whr248RYCYdH21ixsTr6QfHmTC1YVi2BBwMUa0Y82LlOjX2sE0mUSTIHDUumwew+EcmotW2LTkEexhlO5QR4UYek57cfGRZoOWDGddbMblPLHRGG9ZKDSV8Zcy0iAIt6BjAz/wMHttVdIsHPckaxX3phcd9hayMt8+guoqzbpz9xdcQiMYYFVpAI9UjDpiNFQb8Jt8gFyex17XljNd5byQb4h31qZJZnX930tLhGHcsGLnmzfHEbN8mIek7f6lW58k5RphIX7gyZECFYrTuk5AlxiveNkBvESSzjtppowkCuFliqZKT9W1povdOYu1B0oxZtOdyZILGyFjOYUXzQZkGiS0MtWaYcIziaBapprMTQQW+tC+9Mje+xPNdT46CT1abuZaBOoYRRimaREQwA0R91UvEDWvJuKWB/17lQ+YSrve9UZSoeXlwSvuwy3RtJi3GOVGVTXbRqDQWh3gLEBm0DIga/IYu1cCYHadLCe4bdSEqV82E2wrbHpWpiVm656LhRu/mV1/BQBT35tvb/VkBcS5AcNmWlkaHEYlJHwqPdg6Umm9FwivPUYVB/Dkgx5AnVvVlAqAO50UlF/ldpMz0zWxoT8E4blMsgSl2Qj75W4NpbyronyIcUX9fijbjKMfrtC35pMpbEuBFwZ1H3cJAs4t+c3+gtHSPGUK5/yCM9LISPoTVP+ejrpHEO3EWRuyvLTlU2PDBK4+2O71sRaRN2Dhizco/6yWgbr5Fs14YEcuZh3xUL3Gq4VKGfbaGVFmAmg6FO5D3bs3vsULqhmYOSpGXu1HDWuMsw+VmWHHukuhkHb2zD6KdTKFY/oGtyTbT13ns4zozKQWnC7gn2OQRGOf3s8kROBodHhTcea257vN5g07awOInMU0/JrBROLCS45MhIunqL1kIioP6o+uaVrPLqq7v1iVRBukmbW0DtxR1BdMglxM5j3kFfhwD+LhSrUhW41kjwLfdgJoARx0/SntnRMnP+wNhbmOq4y1o9wMzP2AgcybIf/HYg5h77bQv3rX9++I+nEqmLuqBwBUe7RYJ+uegudxy8M4wEq8cb/HIWkNebzb9YZuCXC7o+ZDPC3tBBh/+hSdfzmph2vaX0+mAQerW4p1MsmjeGa2j/msZPL5rSuGyFcdhVGFOido/Pg98DS5FCURWlYWW6vkpgIYkxLk+4/I34S+6NvAHlhgUbOX89lZJcuKYhSIJuGea1ASuHUL3nIdiMx+0sfAe2J6hBdAhDKdCsDHkQeTkI+JBs//UAwE1TqIWkEYjI+rGOieyerBfz+1HDXBsPPcPJhpfLYcDrM38s0t8s2dgn1WObvHVz8oZLbavKCH7yFHAT3xCzbWbeH2O6zRvfLRjb80fZ+7O4PR7YrDzBtTx/OZAfKbQNrBURmhRscZTblLy++Qgv0YlixwnFSzx0+XUSwU7bYbxNZHjVOZOoL7x661lJHGwPkIZI9AGuz/Ec0+0jNgnpjnLW5EGZuXbHP1l/AqsAl06RbrJJ1codwINnI9BPKgrN6dPsZgYR2bU4pvS9QpvzyeeYn3gIyr81CORhPVSfHNlSSxiBcODaRG1c0WR98OgECtd/xq7nctQwKbzatBmgr5mx7Tk8o0uo1TZQMj2QUoItb9ETJyMNxy6iUnw96kPoxc18yivlqnS3yA/E1fXWdVr9obxltOCs9v3GDGr+HF/HJJz3HPd5Kowtx9w0npcFpO7wlIDL6P5KfsrsiftcLcPPj2OBrNdUG6naxAQSn8JobdtOcAKNK/WGfh+f9bF/FL51X6hzMhazZJR0cykRHUjBr3RTTSwpAssF071XZUy4SM5xAoOX72Cf2sIHLgtVl1GnRx+ChSOhT2si3GVbU7hOct7oqk92ae004wZzopzCnRA8I+kYJiAwDINHWP//Tx1HSCu0g3AyLiSXQcMlTEM2+aE/wWmqVjb+cE9jX0IWN0eCl7UwATQJXXGDIA2qz3q3guY/M3uuhSo5qnz5PoSYfkzs6uz5suMriviAU92Q63mfISWRQ/u9kOdGFhvO+LepI/I+HKpFUq+kH1IetmxUcYPFMJeDUYqL6NQa7+b6QueSB6rpFwFjGR49VBiq07EGYj1cLsnF+SMChHHaRsLKSsyxY/rZ6JPUyRgUr2MJHdNR/WsmVkIx67Z0I43hmZ014C7KA6mPx+PSnRoyz0DvuVvvD38inJbb1DC1+46WM6QZDURvyMLApZEMARqav0pxSaFOKpXjkOJ3nCobKKgQ5Xd50NClzwqu3Us7G4cXMA79yCBuFbiqrfGuXoALObQNZNmOb/WGqUF+A84Wjgys8xrpacFc55xNIrQ0b4PglHUXJUJl1fSBub1i82f5mltkrI/RYV7j0QuhZSkygE7fYfM80gyMG6Uz+ADKKwktYn6zaupbo9yy9b5IN+8mzBCq33BeH4/DrOtq+BKIWOgY2j5WrORSNDEfmRSVxJMUJFyAGJvBlQmrgIY7E5fzcF/ppZN+gmKGap9fjUSSKt5BVhDVAVyS46kltFPOPaCDlW/J8PfMyedPagPj1GfFkPgphg91PKE9nKmoka7FECVQpihsFqIAzA897yxwjOiZPI6URIxwKr3DmjOiYOFAfbOz/schbQ6HegtwS8/fYGRpiBI59ijPTRDyGgtm9OLaT5B85P7T5xHhFhgEckR9kW/hcqVwGB+C88DLKEerFiV6yCSGQqA4A1iFU6CwnSJldOMemMWy0sZvN67xHUbaXLw9+nqP4v+9q+EPXW0Ighum0vDbSy9w7IAyRSRZB+tFlp5GDX5WyzMVfeNvKt+KO6nmBv0cHkUZw5zxzX2A1yBjEM6/nSjLrpbuxrBz0UNYZ5JMLriGurJn2s70EJiW3gF1GXNfsssNrvrRurTjNWNSQwBu4JFL1zAYkI8cluZ13ma++CpVUkVKWOs7oo5lTcjdHyhJV7J33HbXb9wq493Yju3lCFy8Lzsc4yC0HUzcqpOs85VTXclUrnWCPE388pMZFVZjCCZvLE5OM0uwmb4S0VjwVRwHrje7Rv7kbB1CxLV9CivXnG8n3D/qslAuat34xIESRIFQZD5fJ0NwLjPSNP0P//513/+VdZdMSR98dfff/1jnIoh65Lzv9Klzn8FuLZ1161gsm/jUhx1cYKuKmvaP/r8bbhWCYITb7Miy9BPmsEkBX0gkiLTD07kRYGVyHsdpV41RRE4ln+gIkMyLMVTOPuQyQdKcSQtyAL561//+s+/pmU8XjuG7DXkv/+1FEn+979H//v/GXEbk3X7Oy+W+ijy/5iSJenXf8L/sW7FtP4Tf2/4/zfLxuEolu3v//pv/7701/94b8zq13D4H9C/G03jWr8e3n/9Pexd93rW7b/38v91+4+39ztM/z/fvrbi2v7PnVvyW1973x7fEdZ6HP53r2+///pfbQTOyAQVAQA= -->
