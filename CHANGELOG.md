# Changelog

## 2.0.0

- Make the published `rapp-agent-converter` Agent Skill the repository's sole
  implementation.
- Emit a `SKILL.md` + byte-exact linked-agent pair by default.
- Add checksum-verified restoration and inline-Python drift detection.
- Replace the legacy multi-format laboratory with the focused
  `agent.py ↔ Agent Skill` contract.
- Keep `toast.py` and `toaster.py` as thin compatibility launchers.
