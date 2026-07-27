"""Pure logic for detecting single-character-typed / backspace events from
consecutive kitty screen snapshots. No kitty dependency — testable standalone
with `python3 -m unittest`. See docs/superpowers/specs/2026-07-26-kitty-typing-particles-design.md.
"""
from __future__ import annotations

import re
from typing import NamedTuple, Optional

_CURSOR_RE = re.compile(r"\x1b\[(\d+);(\d+)H")
_CURSOR_INTRO = "\x1b[?25"


class Snapshot(NamedTuple):
    row: int
    col: int
    lines: list[str]


def parse_snapshot(as_text_output: str) -> Optional[Snapshot]:
    """Parse the string returned by kitty's window.as_text(add_cursor=True)."""
    match = _CURSOR_RE.search(as_text_output)
    if match is None:
        return None
    row = int(match.group(1)) - 1
    col = int(match.group(2)) - 1
    plain = as_text_output[: match.start()]
    intro = plain.rfind(_CURSOR_INTRO)
    if intro != -1:
        plain = plain[:intro]
    lines = plain.rstrip("\n").split("\n")
    return Snapshot(row=row, col=col, lines=lines)


def char_at(lines: list[str], row: int, col: int) -> str:
    if row < 0 or row >= len(lines):
        return " "
    line = lines[row]
    if col < 0 or col >= len(line):
        return " "
    return line[col]


def detect_event(prev: Optional[Snapshot], curr: Snapshot) -> Optional[tuple[int, int, str]]:
    """Returns (row, col, kind) where kind is 'char' or 'backspace', or None."""
    if prev is None or curr.row != prev.row:
        return None
    if curr.col == prev.col + 1:
        old_char = char_at(prev.lines, prev.row, prev.col)
        new_char = char_at(curr.lines, curr.row, prev.col)
        if new_char != " " and new_char != old_char:
            return (prev.row, prev.col, "char")
        return None
    if curr.col == prev.col - 1:
        old_char = char_at(prev.lines, prev.row, curr.col)
        new_char = char_at(curr.lines, curr.row, curr.col)
        if old_char != " " and new_char == " ":
            return (curr.row, curr.col, "backspace")
        return None
    return None
