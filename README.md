# rapp-toaster

**Bread goes in. Toast comes out. Same toast, every platform.**

One stdlib-only Python file that converts an AI capability between
`agent.py`, `SKILL.md`, openclaw, and openrappter — **without losing
fidelity in either direction**, no matter how many times you convert.

```bash
python3 toaster.py convert my_agent.py --to skill --bundle
python3 toaster.py convert some/SKILL.md --to agent
python3 toaster.py soak my_agent.py          # prove it doesn't drift
```

No install. No dependencies. No framework. Python 3.9+.

---

## The problem: `.md` drift disease

Agent capabilities are trapped in whatever format birthed them. Convert an
`agent.py` to a `SKILL.md` and you lose the typed tool contract and the code.
Convert it back and you get prose wearing a Python costume. Do it a few more
times and the capability has quietly rotted — every individual hop looked
fine, and the tool contract is gone.

The failure is **accumulation**, so a single clean round trip proves nothing.

## The Toaster pattern

A capability has two layers, and every format shows only some of them:

| Layer | What it is | `agent.py` | `SKILL.md` |
|---|---|---|---|
| **Deterministic** | typed JSON-Schema contract + real code | ✅ | ❌ |
| **Procedural** | markdown instructions a model follows | hidden in a docstring | ✅ |

So conversion is not translation — it is **projection**. Each format is a
shadow of the same object, cast at a different angle.

The pattern has one rule:

> **`agent.py` is the grail.** Every other format is a projection that
> carries the canonical form *inside itself*.

Every artifact the toaster emits embeds an **RCI capsule** — gzip+base64 of
the full canonical record, including the byte-exact original source. In a
`SKILL.md` it rides as an HTML comment. In a `skill.json` it rides as
`x-rci`. In an `agent.py` it rides as a trailing comment. Invisible to the
host, lossless on the way back.

A `SKILL.md` you hand-wrote has no capsule. That is fine — the toaster
synthesises, and tells you plainly that it did.

## Two fidelities (conflating them is how capabilities rot)

**Transport fidelity** — can the original be recovered byte-exact later?
Solved unconditionally by the capsule. Always `LOSSLESS`.

**Behavioural fidelity** — does it still behave deterministically *on the
host*? That depends entirely on what the host can execute, so the toaster
grades it honestly instead of pretending every export is equal:

| Tier | Meaning |
|---|---|
| `EXEC` | The host runs the real agent file. Byte-identical behaviour, no RAPP needed. |
| `CODE` | The code travels in a fenced block; determinism only if the host runs it. |
| `SPEC` | Typed contract + examples travel. The model conforms to the interface but computes the answer itself. |

### Getting `EXEC` on a plain SKILL.md platform

This is the whole trick. `--bundle` ships the runnable agent *next to* the
markdown and rewrites the markdown to **command a call instead of describing
a procedure**:

```bash
python3 toaster.py convert hacker_news_agent.py --to skill --bundle
```

```
hacker-news/
  SKILL.md                 # "## Run this — do not improvise"
  hacker_news_agent.py     # stdlib-only, executable, zero install
```

The emitted agent carries a fallback shim, so it runs with **or** without a
brainstem:

```bash
python3 hacker_news_agent.py '{"count": 3}'   # arguments as one JSON object
echo '{"count": 3}' | python3 hacker_news_agent.py
python3 hacker_news_agent.py --tool           # emit the JSON tool contract
```

Determinism survives because the *same bytes execute*. The host model never
paraphrases the procedure — it shells out. The toaster refuses to claim
`EXEC` without actually running the bundled file first.

## Raw bread must be toasted first

A hand-written `SKILL.md` is **raw bread**. It carries no capsule, so there is
nothing canonical to restore from — every conversion has to *synthesise*, and
synthesis is a re-render, not a recovery. Feed raw bread straight into the loop
and you are measuring whether two renders agree, not whether fidelity held.

**Toasting** is the one-time normalising pass that lets bread enter the loop:

```bash
toaster.py toast some/SKILL.md      # embeds the capsule; idempotent
toaster.py soak  some/SKILL.md      # now every guarantee below applies
```

`soak` refuses raw bread rather than quietly reporting a meaningless pass
(`--allow-raw` overrides if you really want to watch synthesis wobble).

After toasting, the toasted artifact is the canonical form for that format —
the raw original is superseded, not lost: every other format's bytes are still
vaulted in the capsule. Toasting toast is a no-op.

> Bread goes in. **Toast** comes out. Only toast plays in the loop.

## Proving it doesn't drift

`soak` tests three properties a single round trip cannot see:

1. **Fixed point** — after one normalising pass, repeated conversion must stop
   changing bytes. If cycle 7 ≠ cycle 6, it drifts.
2. **Path independence** — `agent→skill→agent` and
   `agent→openrappter→openclaw→rci→agent` must land on the *same bytes*. If
   the route changes the destination, the format is lying about being a
   projection.
3. **Idempotence** — converting to a format twice in a row is a no-op.

```bash
python3 toaster.py soak my_agent.py another/SKILL.md --depth 3 --cycles 25
```

```
6138 conversions across 32 artifact(s)
NO DRIFT — path-independent, idempotent, and fixed-point stable in every direction.
```

This is not decoration. It found a real bug: the plain-skill projection was
emitting `metadata.openclaw` in its frontmatter, so format detection
reclassified the projection *as* openclaw and the derived file overwrote the
true original in the capsule vault. 26 chains failed on it. A single round
trip passed every time.

> **A projection must never be mistakable for the thing it projects from.**

### What round-trips, and what doesn't (stated plainly)

**Canonical artifacts** — a hand-written `agent.py`, `SKILL.md`, or
`skill.json` — round-trip **byte-exact** through any route, any number of hops.

**A `--bundle` export does not round-trip to itself**, and it is not meant to.
It is a derived, one-way projection: the markdown gains a "run this" section and
the sidecar gains a standalone shim. What *is* guaranteed — and enforced in CI —
is that **every route out of a bundled export converges on the byte-exact
grail**:

```
bundled SKILL.md -> agent                                  == original agent.py
bundled SKILL.md -> openrappter -> openclaw -> rci -> agent == original agent.py
```

That is the promise that matters. You can hand someone a bundled folder, they
can push it through three foreign platforms, and what comes back out the far
end is your `agent.py`, byte for byte.

## Commands

```
toaster.py convert <path> --to agent|skill|openclaw|openrappter|rci [--bundle] [-o OUT]
toaster.py inspect <path>               # what survives, layer by layer
toaster.py roundtrip <path> --via FMT   # byte-exact check, exit 1 on drift
toaster.py toast <path>...              # raw bread -> loop-safe toast (idempotent)
toaster.py soak <path>... [--depth N] [--cycles N] [--allow-raw]
toaster.py selftest
```

## Formats

| Format | Shape |
|---|---|
| `agent` | RAPP brainstem `agent.py` — `BasicAgent` subclass, `self.metadata`, `perform()` |
| `skill` | `SKILL.md` — YAML frontmatter + markdown body |
| `openclaw` | `SKILL.md` + `metadata.openclaw` |
| `openrappter` | `skill.json` + `skill.md` (ClawHub layout) |
| `rci` | the canonical record itself, as JSON |

Parsing is **AST-only** — the toaster never imports or executes an agent to
read it.

## Why this exists

A brainstem colonises a host runtime the way a mitochondrion colonises a
cell: it does not rewrite the host, it trades across a narrow membrane. A
capability format *is* that membrane, and this is the transport protein.
Convert a capability into whatever the host natively eats, and the host runs
it without ever knowing it was RAPP.

That is what keeps single-file agent drops universally tradable — and what
keeps `agent.py` the grail.

---

Apache-2.0. RAPP™ compound marks are claimed by Wildhaven Homes LLC; the
`RAPP` stem standing alone is deliberately unclaimed. See
[TRADEMARKS.md](https://kody-w.github.io/rapp-train/TRADEMARKS.md).
