import unittest

from particles_detect import Snapshot, char_at, detect_event, parse_snapshot


def make_as_text_output(lines, row, col):
    text = "\n".join(lines) + "\n"
    text += f"\x1b[?25h\x1b[{row + 1};{col + 1}H"
    return text


class ParseSnapshotTests(unittest.TestCase):
    def test_parses_cursor_position_and_lines(self):
        output = make_as_text_output(["hello", "world"], row=1, col=3)
        snap = parse_snapshot(output, cols=80)
        self.assertEqual(snap.row, 1)
        self.assertEqual(snap.col, 3)
        self.assertEqual(snap.lines, ["hello", "world"])
        self.assertEqual(snap.cols, 80)

    def test_returns_none_without_a_cursor_sequence(self):
        self.assertIsNone(parse_snapshot("hello\nworld\n", cols=80))


class CharAtTests(unittest.TestCase):
    def test_in_bounds(self):
        self.assertEqual(char_at(["hello"], 0, 1), "e")

    def test_out_of_bounds_row_returns_space(self):
        self.assertEqual(char_at(["hello"], 5, 0), " ")

    def test_out_of_bounds_col_returns_space(self):
        self.assertEqual(char_at(["hi"], 0, 10), " ")


class DetectEventTests(unittest.TestCase):
    def test_no_event_on_first_snapshot(self):
        curr = Snapshot(row=0, col=1, lines=["h"], cols=80)
        self.assertIsNone(detect_event(None, curr))

    def test_typing_a_character(self):
        prev = Snapshot(row=0, col=0, lines=[""], cols=80)
        curr = Snapshot(row=0, col=1, lines=["h"], cols=80)
        self.assertEqual(detect_event(prev, curr), (0, 0, "char"))

    def test_backspace(self):
        prev = Snapshot(row=0, col=1, lines=["h"], cols=80)
        curr = Snapshot(row=0, col=0, lines=[""], cols=80)
        self.assertEqual(detect_event(prev, curr), (0, 0, "backspace"))

    def test_arrow_key_over_existing_text_is_ignored(self):
        prev = Snapshot(row=0, col=0, lines=["hi"], cols=80)
        curr = Snapshot(row=0, col=1, lines=["hi"], cols=80)
        self.assertIsNone(detect_event(prev, curr))

    def test_row_change_is_ignored(self):
        prev = Snapshot(row=0, col=5, lines=["hello", ""], cols=80)
        curr = Snapshot(row=1, col=0, lines=["hello", ""], cols=80)
        self.assertIsNone(detect_event(prev, curr))

    def test_multi_cell_jump_is_ignored(self):
        prev = Snapshot(row=0, col=0, lines=["hello"], cols=80)
        curr = Snapshot(row=0, col=5, lines=["hello"], cols=80)
        self.assertIsNone(detect_event(prev, curr))

    def test_overwriting_a_character_fires_a_char_event(self):
        prev = Snapshot(row=0, col=0, lines=["x"], cols=80)
        curr = Snapshot(row=0, col=1, lines=["y"], cols=80)
        self.assertEqual(detect_event(prev, curr), (0, 0, "char"))

    def test_typing_past_the_last_column_wraps_and_still_fires(self):
        # cols=10: columns 0-9. Cursor was at the last column (9) and the
        # new glyph landed there; typing one more char wraps to row+1, col 0.
        prev = Snapshot(row=0, col=9, lines=["123456789"], cols=10)
        curr = Snapshot(row=1, col=0, lines=["1234567890", ""], cols=10)
        self.assertEqual(detect_event(prev, curr), (0, 9, "char"))

    def test_row_change_not_at_last_column_is_not_treated_as_a_wrap(self):
        # A real Enter/newline: prev.col isn't the last column, so this must
        # not be misread as a same-line wrap.
        prev = Snapshot(row=0, col=5, lines=["hello"], cols=80)
        curr = Snapshot(row=1, col=0, lines=["hello", ""], cols=80)
        self.assertIsNone(detect_event(prev, curr))

    def test_wrap_landing_col_nonzero_is_ignored(self):
        # row advanced from the last column but curr.col isn't 0 — not the
        # wrap shape, don't fire.
        prev = Snapshot(row=0, col=9, lines=["123456789"], cols=10)
        curr = Snapshot(row=1, col=3, lines=["123456789", "abc"], cols=10)
        self.assertIsNone(detect_event(prev, curr))


if __name__ == "__main__":
    unittest.main()
