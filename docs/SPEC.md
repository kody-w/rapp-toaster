# Toasted Skills — `rapp-capability-interchange/1.0`

**A skill that can prove it still means what it meant.**

Status: **1.0**, implemented and in production use. Reference implementation:
[`kody-w/rapp-toaster`](https://github.com/kody-w/rapp-toaster) — one
stdlib-only Python file, Apache-2.0.

---

## 0. What this is, in one paragraph

A **toasted skill** is an ordinary `SKILL.md` that additionally carries a
compressed canonical record of itself. That record makes three things possible
that a plain skill cannot do: it can be recovered byte-exact after travelling
through other platforms, it can be *tested* for drift, and it can be projected
into a single-file executable agent without a migration. Toasting adds **no
frontmatter fields** and changes nothing about how existing hosts load the file.

This specification is additive to, and compatible with, the plain `SKILL.md`
shape already in wide use. **A toasted skill is a valid skill everywhere.**

## 1. The problem being solved

Skills became production infrastructure without acquiring the safety properties
production infrastructure has. A skill is prose; the systems it drives execute
against real credentials. Between those two facts sits an unmeasured gap:

- **No canonical form.** Nothing underneath the prose says what the capability
  accepts or runs, so every platform boundary is a lossy re-render.
- **No integrity boundary.** A skill edited, re-rendered, or pasted through
  three platforms is indistinguishable from the one that was reviewed.
- **Drift never fails loudly.** A drifted dependency crashes. A drifted skill
  keeps working and does the wrong thing confidently.
- **Agents now edit skills.** Autonomous mutation of production behaviour, with
  no oracle watching.

The question no current format can answer:

> **Does this capability mean today exactly what it meant when we approved it?**

`rapp-capability-interchange/1.0` answers it with a byte comparison.

## 2. Two layers, and why formats are projections

Every capability has two layers:

| Layer | What it is | Present in `agent.py` | Present in `SKILL.md` |
|---|---|---|---|
| **Deterministic** | typed JSON-Schema contract + real code | ✅ authored | ❌ |
| **Procedural** | markdown instructions a model follows | in a docstring | ✅ |

So conversion between formats is not translation — it is **projection**. Each
format is a shadow of one underlying object, cast at a different angle.

> **A projection must never be mistakable for the thing it projects from.**

That rule is load-bearing. Violating it is how a derived copy overwrites an
original, which is the single most common way these systems lose data.

## 3. Bread and toast

A hand-written `SKILL.md` is **raw bread**: prose with no canonical form. It
cannot be *tested* for fidelity, because there is nothing to be faithful to —
comparing two renders and asking whether they agree is not a fidelity test.

**Toasting** is the one-time normalising pass that admits a skill to the loop:

1. **Scan** the prose for evidence of a deterministic layer.
2. **Derive** typed parameters and ordered steps — conservatively (§5).
3. **Freeze** the result as a canonical record carried inside the file.

Everything after that stake is measurable. Nothing before it is. Toasting is
**idempotent**: toasting toast is a no-op.

**`agent.py` is never toasted.** It is already canonical — authored contract,
authored code. Toasting is strictly the bread operation.

## 4. The capsule

The canonical record travels **inside the artifact**:

| Format | Where the capsule rides |
|---|---|
| `SKILL.md` | an HTML comment — invisible to every renderer |
| `skill.json` | an `x-rci` key |
| `agent.py` | a trailing comment |

Encoding: `rci-capsule:v1:` + base64(gzip(JSON)) of the canonical record.

A conforming reader **MUST** ignore an unrecognised capsule rather than error.
A conforming writer **MUST NOT** add frontmatter fields to carry it.

### 4.1 The canonical record

```json
{ "rci": "1.0",
  "name": "…", "slug": "…", "version": "…", "description": "…",
  "parameters": { "type": "object", "properties": {}, "required": [] },
  "instructions": "…markdown…",
  "impl": { "lang": "python", "steps": [ {"cmd": "…", "line": 12} ] },
  "preserved": { "<format>": {"sha256": "…", "b64": "…"} },
  "provenance": [ "read:skill:…", "toast:derived params=4 steps=9" ] }
```

## 5. Derivation rules (normative)

Derivation is **evidence-based and conservative**. Inventing a contract the
author never implied is worse than deriving nothing: it silently changes what
the capability claims to accept.

1. A parameter counts **only if** its placeholder appears inside a command the
   document actually gives. A placeholder mentioned in a sentence is
   documentation, not an input.
2. Steps are **lifted verbatim** from inline code spans and fenced blocks. They
   are never paraphrased, reordered, or synthesised.
3. An **explicit author-supplied contract is never overridden.** Derivation
   only fills gaps.
4. Every derived element **records its source** — token, line, and kind — so
   toast is auditable.
5. Deriving nothing is a valid, reportable outcome. It is a finding about the
   skill, not a failure of the tool.

## 6. Two fidelities — grade them, never assume them

**Transport fidelity** — can the original be recovered byte-exact later?
Solved unconditionally by the capsule. Always `LOSSLESS`.

**Behavioural fidelity** — does it still behave deterministically *on the
host*? Not always solvable; it depends on what the host can execute. Conforming
implementations **MUST** grade it and **MUST NOT** claim uniformity:

| Tier | Meaning |
|---|---|
| `EXEC` | The host runs the real code. Byte-identical behaviour. |
| `CODE` | The code travels in a fenced block; determinism only if the host runs it. |
| `SPEC` | The typed contract travels; the model conforms to the interface but computes the answer itself. |

An implementation **MUST NOT** report `EXEC` without having executed the
artifact. A tool claiming uniform fidelity across demonstrably different
platforms is selling drift with a confidence interval of zero.

## 7. Capability identity vs artifact identity

Two artifacts that mean the same thing will legitimately differ in `preserved`
(each vaults *itself*, so it can round-trip to itself) and in `provenance` (each
took a different route). **Neither is the capability.**

`capability_id` = SHA-256 over `{name, slug, version, description, parameters,
instructions, system_context, author, tags, license, examples, impl}`, where
`impl` uses `steps` when present and otherwise authored code only.

Authored code **MUST** be canonicalised to a single form before hashing. A skill
vaults a code block as `perform_body`; the agent projection of that same block
wraps it in a `def perform(...)` header and stores it as `perform`. These are one
article in two encodings, and hashing them as distinct fields makes identity
depend on which projection is in hand — the precise failure this section exists
to forbid.

Generated content **MUST** be excluded from identity. Conflating artifact
identity with capability identity makes a true statement ("the capability is
intact") report as a false one.

## 8. Generated content must be identifiable

Anything a tool writes into an artifact **MUST** be delimited:

```markdown
<!-- toaster:generated:begin -->
## Run this — do not improvise
…
<!-- toaster:generated:end -->
```

Readers **MUST** strip delimited regions before treating body text as authored
instructions. Generated `perform()` bodies carry `# toaster:generated-perform`.

This is §2's rule applied inside a single file: **generated content must never
be mistakable for authored content.** Omitting it means a capability acquires a
contract merely by being looked at.

## 9. The drift oracle (normative)

A single round trip proves nothing — drift is an **accumulation** failure. A
conforming implementation **MUST** provide a test of these three properties:

1. **Fixed point** — after one normalising pass, repeated conversion stops
   changing bytes.
2. **Path independence** — `A→B→A` and `A→C→D→E→A` land on the *same bytes*.
3. **Idempotence** — converting to a format twice in a row is a no-op.

Raw bread **MUST** be refused by the oracle, or the result is meaningless.

## 10. Conformance

An implementation is conforming if it:

- reads and writes the capsule per §4 without adding frontmatter;
- derives per §5 and records provenance;
- grades behavioural fidelity per §6 and never overclaims `EXEC`;
- computes `capability_id` per §7, excluding generated content per §8;
- provides the §9 oracle and refuses raw bread.

## 11. Field evidence

Measured, reproducible, against real corpora — not fixtures.

| Corpus | Result |
|---|---|
| 50 skills from a major public registry | 3,600 conversions, **zero drift**; 50/50 projected to single-file agents; 50/50 recovered byte-exact |
| 22 skills, `kody-w/rapp-skills` | 1,584 conversions, **zero drift**; 110 routes all preserve `capability_id` |
| 32 mixed real agents + skills | 6,138 conversions, **zero drift** |

The oracle earned its place by catching a bug that **every single round trip had
passed**: a projection re-emitted a platform-specific metadata key, so format
detection reclassified it as the thing it was projecting from and overwrote the
original with a derived copy. 26 chains failed; one round trip never would have.

Honest counter-evidence, reported because §5.5 requires it: **9 of those 50
skills yielded nothing machine-recoverable.** Prose-heavy skills declare little
that can be derived conservatively. That is a finding about the corpus — most
skills in circulation carry almost no machine-recoverable contract — and it is
the strongest argument for anchoring them.

## 12. Relationship to plain `SKILL.md`

This spec **does not compete with** and **does not replace** the plain skill
shape. It is a strict superset:

- a toasted skill is a valid skill on every host that reads `SKILL.md`;
- no frontmatter field is added, changed, or required;
- hosts that ignore the capsule lose nothing they had;
- nothing is migrated, deprecated, or cut over.

**A shim needs nobody's permission.** That property is what makes adoption
free — and it is why this can be applied to an existing registry today, by a
consumer of that registry, without the registry changing anything.

---

*RAPP™ compound marks are claimed by Wildhaven Homes LLC; the `RAPP` stem
standing alone is deliberately unclaimed. This specification is published for
free use by anyone, including implementations that have nothing to do with
RAPP.*
