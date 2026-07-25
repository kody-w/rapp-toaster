---
name: "handoff"
description: "Clipboard-ready handoff prompt for another agent to investigate or continue a task."
---

# Handoff

Write a clipboard-ready prompt for another agent to investigate, discuss, or work
on a specific task.

Use when the user asks for `handoff <task>`, "write a handoff", "delegate this",
or wants a prompt for another agent.

## Workflow

1. Identify the task from the user text. If the user gives only a short label,
   infer from the current repo, recent discussion, branch name, linked issue/PR,
   docs, and obvious nearby context.
2. Gather enough context to write a useful handoff: repo/product identity,
   relevant issue/PR/branch names, likely modules, constraints, and known
   symptoms. Do not perform the receiving agent's full independent review or
   decide the final technical direction for them.
3. Write a standalone prompt for a fresh agent.
4. Copy the full prompt to the clipboard.
5. Final reply: terse confirmation with the task title. Do not paste the full
   prompt unless the user asks.

## Handoff Prompt Rules

The prompt must:

- Start a discussion, not a command-only work order.
- Ask the receiving agent to do an extensive independent review before changing
  anything.
- Make clear that the receiving agent owns that review; the handoff only gives
  starting context and known constraints.
- Ask the agent to decide whether the task is a good idea, stale, already
  solved, over-scoped, or better handled differently.
- Assume the agent starts in the repo, a parent directory, a workspace directory,
  or a home directory and can find the repo itself.
- Avoid filesystem paths. No absolute paths, home-directory paths, checkout
  names, or repo-relative file paths unless the user explicitly requests them.
- Use portable anchors instead: repo owner/name, product/module names, issue/PR
  URLs, branch names, package/plugin names, public symbols, command names, config
  keys, exact error text, docs titles, and search terms.
- Include enough context for the receiving agent to get the right repo, boundary,
  and desired outcome.
- Include constraints, non-goals, validation expectations, and the desired
  output shape.
- Tell the receiving agent to re-check live repo/GitHub/CI state where relevant.
- Tell the receiving agent not to push, merge, close issues/PRs, label, or post
  public comments unless the handoff explicitly asks for it.

## Prompt Template

Use this shape by default:

```text
I want to discuss and possibly work on: <short task title>

Context:
- <portable repo/product context>
- <what triggered this task>
- <known current state, branch/issue/PR names or URLs if relevant>
- <important constraints and ownership boundaries>

Before doing any implementation:
- Find the right repository from the current directory, a parent directory, or the usual workspace.
- Read the local agent/repo instructions.
- Inspect the relevant code, docs, tests, recent commits, and linked issue/PR state.
- Decide whether this task is still real, whether the proposed direction is a good idea, and whether a smaller/better fix exists.
- Call out stale assumptions, hidden risks, and anything that should stop the work.

Task:
- <what to investigate or implement if the review supports it>
- <expected behavior or decision criteria>
- <non-goals>

Validation:
- <focused tests/checks/live proof expected>
- <what evidence should be included>
- <what is explicitly not required>

Output:
- Start with your review findings and recommendation.
- Then give the proposed plan or patch summary.
- If you edit code, keep changes scoped and report exact proof run.
- Do not push, merge, close issues/PRs, label, or post public comments unless explicitly told.
```

## Clipboard

On macOS:

```sh
pbcopy < /tmp/handoff-prompt.txt
```

Use a temp file or pipe. Avoid inline shell quoting for prompts containing
backticks, `$`, quotes, or user text.

If `pbcopy` is unavailable, use the obvious platform clipboard tool (`wl-copy`,
`xclip`, `clip.exe`) or print the prompt and say clipboard copy was unavailable.

## Quality Bar

- No invented facts. Mark reviewed facts as such only after checking them.
- No path leakage. Rewrite any accidental path as a symbol, module, command,
  issue/PR URL, or search term.
- Enough context for a fresh agent to orient; no giant brain dump.
- First real instruction to the receiving agent: review, discuss, assess.

<!-- rci-capsule:v1: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 -->
