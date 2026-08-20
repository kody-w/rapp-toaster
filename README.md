# RAPP Agent Converter

**One conversion boundary: RAPP `agent.py` ↔ Agent Skill. No re-rendering.**

This repository is the standalone home of the
[`rapp-agent-converter`](SKILL.md) skill published to the CAT Agent Skills
gallery. The skill, its converter, its references, and its sample cartridge are
the product:

```text
SKILL.md
scripts/toast.py
references/
assets/hello_rapp_agent.py
```

The converter projects a RAPP single-file agent into an Agent Skill **pair**:

```text
out/
├── SKILL.md              complete Python inline + checksum-verified capsule
└── hello_rapp_agent.py   byte-exact linked copy of the source agent
```

Copilot Studio and Cowork can run the linked file directly. An
instruction-driven host can use the same `SKILL.md` as the exact specification.
If the linked file is missing, the original agent restores byte-exact from the
capsule. The artifact does not change as it moves between hosts.

## The going-home law

A projected agent must stay safe to drop into any RAPP brainstem. A host's
loader conventionally wraps each agent import in `except Exception` — which does
**not** catch `SystemExit`, and nothing catches `os._exit`. Verified against a
live brainstem:

| dropped into a running brainstem | result |
|---|---|
| syntax error | survives — logged, keeps serving |
| raises at import | survives |
| no agent class | survives |
| module-level `sys.exit()` / `os._exit()` | **kills the host process** |

So the converter refuses to project an agent whose module body can terminate the
interpreter on import:

```console
$ toast.py convert lethal_agent.py --to skill
[FAIL] lethal_agent.py: module-level os._exit() would terminate a host brainstem
on import. ... Move the call inside a function, or guard it with
`if __name__ == "__main__":` so it only runs when the file is executed directly.
```

The `__main__` guard is explicitly preserved — that block does not run on
import, and it is exactly what lets a RAPP agent *also* run standalone on a host
with no brainstem. All 113 agents in
[`rapp-skills`](https://github.com/kody-w/rapp-skills) pass unchanged.

`toast.py selftest` asserts both halves: every lethal shape is refused, and the
standalone idiom is not.

## Use it

Python 3.9+, standard library only. No install, network, credentials, or agent
execution is required to convert a file.

```bash
python3 scripts/toast.py convert my_agent.py --to skill -o out/SKILL.md
python3 scripts/toast.py convert out/SKILL.md --to agent
python3 scripts/toast.py roundtrip my_agent.py
python3 scripts/toast.py inspect out/SKILL.md
python3 scripts/toast.py selftest
```

`toast.py` at the repository root is a convenience launcher. The historical
`toaster.py` entry point remains as a launcher too, but contains no conversion
logic. All behavior lives in `scripts/toast.py`.

## Guarantees

- `agent.py → SKILL.md → agent.py` returns the exact original bytes.
- Repeated projections reach and hold a fixed point.
- The `SKILL.md` embeds the complete Python and links a byte-exact agent beside
  it.
- Capsule checksum failures and edits inside generated Python fences stop with
  an explicit refusal.
- Agent files are parsed with `ast`; conversion never imports or executes them.
- Restoration is reported as **RESTORED (byte-exact)**. A first projection is
  reported as **SYNTHESISED**. They are never conflated.

Run the proof:

```bash
python3 scripts/toast.py selftest
python3 scripts/toast.py roundtrip assets/hello_rapp_agent.py
python3 scripts/toast.py roundtrip examples/hacker-news/hacker_news_agent.py
```

## The 2.0 reset

Earlier versions of this repository implemented a broader format laboratory
with `openclaw`, `openrappter`, `rci`, `toast`, and `soak` commands. That was a
different product and a second source of truth.

The repository now follows the submitted Agent Skill exclusively:

- supported shapes are `agent.py` and the `SKILL.md` + linked-agent pair;
- the byte-exact agent is canonical;
- `roundtrip` is the public fidelity oracle;
- the bundled skill is the implementation, not documentation about an
  implementation elsewhere.

This is intentionally a smaller API with a stronger, directly testable
contract.

## Layout

| Path | Role |
|---|---|
| `SKILL.md` | Agent-facing operating procedure. |
| `scripts/toast.py` | Authoritative converter. |
| `toast.py` / `toaster.py` | Thin launchers; no conversion logic. |
| `references/rapp-agent-contract.md` | Single-file agent contract. |
| `references/rapp1-protocol.md` | Live brainstem `/chat` wire. |
| `assets/hello_rapp_agent.py` | Minimal executable cartridge. |
| `examples/hacker-news/` | A second real agent/skill pair. |

Apache-2.0. RAPP is an independent project, named here to describe
interoperability.
