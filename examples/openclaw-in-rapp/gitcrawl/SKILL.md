---
name: "gitcrawl"
description: "GitHub archive: issue/PR search, sync freshness, duplicate clusters, gh-shim PR status, and Gitcrawl repo work."
---

# Gitcrawl

Use local GitHub issue/PR archives before live GitHub search. Check freshness first:

```bash
gitcrawl doctor --json
```

Find candidates:

```bash
gitcrawl threads openclaw/openclaw --numbers <issue-or-pr-number> --include-closed --json
gitcrawl neighbors openclaw/openclaw --number <issue-or-pr-number> --limit 12 --json
gitcrawl search issues "query" -R openclaw/openclaw --state open --json number,title,url
gitcrawl clusters openclaw/openclaw --sort size --min-size 5
gitcrawl cluster-detail openclaw/openclaw --id <cluster-id>
```

For PR triage, start cached and go live only before mutation/merge decisions:

```bash
gitcrawl gh pr status <number-or-url> -R openclaw/openclaw --compact
gitcrawl gh pr view <number-or-url> -R openclaw/openclaw --json number,title,state,url,isDraft,headRef,headSha
gitcrawl gh --live pr status <number-or-url> -R openclaw/openclaw --compact
```

Use live `gh` plus checkout proof before commenting, labeling, closing, reopening, merging, or filing a PR review:

```bash
gh pr view <number> --json number,title,state,mergedAt,body,files,comments,reviews,statusCheckRollup
gh issue view <number> --json number,title,state,body,comments,closedAt
```

Report absolute dates, repo names, issue/PR numbers, cluster ids, and source gaps. Do not close/label from similarity alone; require matching intent plus live verification.

## Parameters

The typed contract this capability answers to (JSON Schema — the deterministic layer):

```json
{
  "type": "object",
  "properties": {
    "number": {
      "type": "string",
      "description": "Derived from `<number>` used in the documented command at line 30."
    }
  },
  "required": []
}
```

## Deterministic steps

Lifted verbatim from the procedure above by `toaster.py toast`. Run them in order, substituting the typed parameters; do not paraphrase:

```bash
gh
gh pr view <number> --json number,title,state,mergedAt,body,files,comments,reviews,statusCheckRollup
gh issue view <number> --json number,title,state,body,comments,closedAt
```

<!-- toaster:generated:begin -->

## Parameters

The typed contract this capability answers to (JSON Schema — the deterministic layer):

```json
{
  "properties": {
    "number": {
      "description": "Derived from `<number>` used in the documented command at line 30.",
      "type": "string"
    }
  },
  "required": [],
  "type": "object"
}
```

<!-- toaster:generated:end -->

<!-- rci-capsule:v1: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 -->
