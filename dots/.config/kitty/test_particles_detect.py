import unittest

from particles_detect import Snapshot, char_at, detect_event, parse_snapshot


def make_as_text_output(lines, row, col):
    text = "\n".join(lines) + "\n"
    text += f"\x1b[?25h\x1b[{row + 1};{col + 1}H"
    return text


class ParseSnapshotTests(unittest.TestCase):
    def test_parses_cursor_position_and_lines(self):
        output = make_as_text_output(["hello", "world"], row=1, col=3)
        snap = parse_snapshot(output)
        self.assertEqual(snap.row, 1)
        self.assertEqual(snap.col, 3)
        self.assertEqual(snap.lines, ["hello", "world"])

    def test_returns_none_without_a_cursor_sequence(self):
        self.assertIsNone(parse_snapshot("hello\nworld\n"))


class CharAtTests(unittest.TestCase):
    def test_in_bounds(self):
        self.assertEqual(char_at(["hello"], 0, 1), "e")

    def test_out_of_bounds_row_returns_space(self):
        self.assertEqual(char_at(["hello"], 5, 0), " ")

    def test_out_of_bounds_col_returns_space(self):
        self.assertEqual(char_at(["hi"], 0, 10), " ")


class DetectEventTests(unittest.TestCase):
    def test_no_event_on_first_snapshot(self):
        curr = Snapshot(row=0, col=1, lines=["h"])
        self.assertIsNone(detect_event(None, curr))

    def test_typing_a_character(self):
        prev = Snapshot(row=0, col=0, lines=[""])
        curr = Snapshot(row=0, col=1, lines=["h"])
        self.assertEqual(detect_event(prev, curr), (0, 0, "char"))

    def test_backspace(self):
        prev = Snapshot(row=0, col=1, lines=["h"])
        curr = Snapshot(row=0, col=0, lines=[""])
        self.assertEqual(detect_event(prev, curr), (0, 0, "backspace"))

    def test_arrow_key_over_existing_text_is_ignored(self):
        prev = Snapshot(row=0, col=0, lines=["hi"])
        curr = Snapshot(row=0, col=1, lines=["hi"])
        self.assertIsNone(detect_event(prev, curr))

    def test_row_change_is_ignored(self):
        prev = Snapshot(row=0, col=5, lines=["hello", ""])
        curr = Snapshot(row=1, col=0, lines=["hello", ""])
        self.assertIsNone(detect_event(prev, curr))

    def test_multi_cell_jump_is_ignored(self):
        prev = Snapshot(row=0, col=0, lines=["hello"])
        curr = Snapshot(row=0, col=5, lines=["hello"])
        self.assertIsNone(detect_event(prev, curr))

    def test_overwriting_a_character_fires_a_char_event(self):
        prev = Snapshot(row=0, col=0, lines=["x"])
        curr = Snapshot(row=0, col=1, lines=["y"])
        self.assertEqual(detect_event(prev, curr), (0, 0, "char"))


if __name__ == "__main__":
    unittest.main()
