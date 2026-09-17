"""Catch broken local MQL dependencies after moving strategy directories."""
from pathlib import Path
import re
import unittest

class LayoutTests(unittest.TestCase):
    def test_entry_dependencies_resolve(self):
        root = Path(__file__).resolve().parents[1]
        entries = list((root / "strategies").rglob("*.mq5"))
        self.assertEqual({p.name for p in entries}, {"XAU_Session_Fade.mq5", "EMA_Pullback_Long.mq5", "Compression_Breakout_Long.mq5"})
        seen = set()
        def visit(path):
            path = path.resolve()
            if path in seen:
                return
            seen.add(path)
            for name in re.findall(r'^#include\s+"([^"]+)"', path.read_text(), re.M):
                included = (path.parent / name.replace("\\", "/")).resolve()
                self.assertTrue(included.is_file(), f"{path}: missing {name}")
                visit(included)
        for entry in entries:
            visit(entry)
        headers = {p.resolve() for p in (root / "strategies").rglob("*.mqh")}
        self.assertFalse(headers - seen, f"Unused headers: {headers - seen}")
