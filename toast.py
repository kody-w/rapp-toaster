#!/usr/bin/env python3
"""Run the authoritative converter bundled in the Agent Skill."""

from pathlib import Path
import runpy


runpy.run_path(
    str(Path(__file__).resolve().parent / "scripts" / "toast.py"),
    run_name="__main__",
)
