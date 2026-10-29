"""Unit tests for figma_to_roblox.py (stdlib unittest).

    py -I test_figma_to_roblox.py
"""
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import figma_to_roblox as f2r  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def H(x0, y0, x1, y1):
    return [{"x": x0, "y": y0}, {"x": x1, "y": y1}, {"x": 0, "y": 0}]


class GradientRotation(unittest.TestCase):
    def test_left_to_right_is_zero(self):
        self.assertEqual(f2r.gradient_rotation(H(0, 0.5, 1, 0.5), 300, 80), 0.0)

    def test_top_to_bottom_is_90(self):
        self.assertEqual(f2r.gradient_rotation(H(0.5, 0, 0.5, 1), 300, 80), 90.0)

    def test_bottom_to_top_is_minus_90(self):
        self.assertEqual(f2r.gradient_rotation(H(0.5, 1, 0.5, 0), 300, 80), -90.0)

    def test_diagonal_uses_pixel_space(self):
        # (0,0) -> (1,1) in a 200 x 100 box is atan2(100, 200), not 45 degrees
        self.assertAlmostEqual(f2r.gradient_rotation(H(0, 0, 1, 1), 200, 100), 26.565, places=3)

    def test_stops_remapped_to_edges(self):
        # handles cover the middle half of the width: stops at 0 and 1 land at 0.25 and 0.75
        stops = [{"position": 0, "color": {"r": 1, "g": 0, "b": 0, "a": 1}},
                 {"position": 1, "color": {"r": 0, "g": 0, "b": 1, "a": 1}}]
        keys = f2r.remap_stops(H(0.25, 0.5, 0.75, 0.5), stops, 400, 100)
        times = [t for t, _ in keys]
        self.assertEqual(times, [0.0, 0.25, 0.75, 1.0])
        self.assertEqual(keys[0][1][:3], (1.0, 0.0, 0.0))
        self.assertEqual(keys[-1][1][:3], (0.0, 0.0, 1.0))

    def test_keypoint_cap(self):
        stops = [{"position": i / 29, "color": {"r": i / 29, "g": 0, "b": 0, "a": 1}} for i in range(30)]
        keys = f2r.remap_stops(H(0, 0.5, 1, 0.5), stops, 100, 100)
        self.assertLessEqual(len(keys), 20)
        self.assertEqual(keys[0][0], 0.0)
        self.assertEqual(keys[-1][0], 1.0)


class Constraints(unittest.TestCase):
    # child at x = 40, width 100, in a 500 wide parent (right gap 360)
    def test_left(self):
        self.assertEqual(f2r.map_constraint_axis("LEFT", 40, 100, 500), (0.0, 0.0, 40, 0.0, 100))

    def test_right(self):
        self.assertEqual(f2r.map_constraint_axis("RIGHT", 40, 100, 500), (1.0, 1.0, -360, 0.0, 100))

    def test_center(self):
        self.assertEqual(f2r.map_constraint_axis("CENTER", 40, 100, 500), (0.5, 0.5, -160, 0.0, 100))

    def test_left_right_stretches(self):
        self.assertEqual(f2r.map_constraint_axis("LEFT_RIGHT", 40, 100, 500), (0.0, 0.0, 40, 1.0, -400))

    def test_scale(self):
        self.assertEqual(f2r.map_constraint_axis("SCALE", 50, 100, 500), (0.0, 0.1, 0.0, 0.2, 0.0))

    def test_vertical_names(self):
        self.assertEqual(f2r.map_constraint_axis("BOTTOM", 10, 20, 100)[:3], (1.0, 1.0, -70))
        self.assertEqual(f2r.map_constraint_axis("TOP_BOTTOM", 10, 20, 100)[3:], (1.0, -80))


class AutoLayout(unittest.TestCase):
    def test_none(self):
        self.assertIsNone(f2r.map_auto_layout({"layoutMode": "NONE"}))

    def test_horizontal_centre(self):
        al = f2r.map_auto_layout({"layoutMode": "HORIZONTAL", "itemSpacing": 12, "primaryAxisAlignItems": "CENTER",
                                  "counterAxisAlignItems": "MAX", "paddingLeft": 8, "paddingTop": 4})
        self.assertEqual(al["FillDirection"], "Horizontal")
        self.assertEqual(al["HorizontalAlignment"], "Center")
        self.assertEqual(al["VerticalAlignment"], "Bottom")
        self.assertEqual(al["Padding"], 12)
        self.assertEqual(al["padding"], [4, 0, 8, 0])
        self.assertFalse(al["Wraps"])

    def test_vertical_space_between_and_wrap(self):
        al = f2r.map_auto_layout({"layoutMode": "VERTICAL", "itemSpacing": 20, "primaryAxisAlignItems": "SPACE_BETWEEN",
                                  "counterAxisAlignItems": "CENTER", "layoutWrap": "WRAP"})
        self.assertEqual(al["VerticalFlex"], "SpaceBetween")
        self.assertEqual(al["Padding"], 0)  # Figma ignores itemSpacing under SPACE_BETWEEN
        self.assertEqual(al["HorizontalAlignment"], "Center")
        self.assertTrue(al["Wraps"])

    def test_child_sizing_axes(self):
        child = {"layoutSizingHorizontal": "FILL", "layoutSizingVertical": "HUG"}
        self.assertEqual(f2r.child_sizing(child, True), ("FILL", "HUG"))
        self.assertEqual(f2r.child_sizing(child, False), ("HUG", "FILL"))

    def test_legacy_layout_grow(self):
        self.assertEqual(f2r.child_sizing({"layoutGrow": 1}, True), ("FILL", "FIXED"))


class Fonts(unittest.TestCase):
    def test_weight_names(self):
        for w, name in [(100, "Thin"), (300, "Light"), (400, "Regular"), (600, "SemiBold"), (900, "Heavy")]:
            self.assertEqual(f2r.map_font_weight(w)[0], name)

    def test_weight_rounds_to_nearest(self):
        self.assertEqual(f2r.map_font_weight(640), ("SemiBold", 600))
        self.assertEqual(f2r.map_font_weight("bad"), ("Regular", 400))

    def test_weight_snaps_to_shipped_face(self):
        # Builder Sans ships no 900: Heavy falls back to ExtraBold
        _, _, weights, _ = f2r.map_family("Builder Sans")
        self.assertEqual(f2r.map_font_weight(900, weights), ("ExtraBold", 800))
        # Fredoka One has one face
        self.assertEqual(f2r.map_font_weight(700, f2r.map_family("Fredoka One")[2]), ("Regular", 400))

    def test_family_fallback_warns(self):
        fam, stem, _, warn = f2r.map_family("Inter")
        self.assertEqual((fam, stem), ("Builder Sans", "BuilderSans"))
        self.assertIsNotNone(warn)
        self.assertIsNone(f2r.map_family("Montserrat")[3])


class Sample(unittest.TestCase):
    def test_sample_converts_deterministically(self):
        with open(os.path.join(HERE, "sample", "settings_panel.json"), encoding="utf-8") as fh:
            data = json.load(fh)
        root = f2r.load_root(data, "Settings")
        a = f2r.Converter().module(root, "test")
        b = f2r.Converter().module(root, "test")
        self.assertEqual(a, b)
        self.assertIn('Instance.new("UIListLayout")', a)
        self.assertIn('Instance.new("UIFlexItem")', a)
        self.assertIn("Enum.BorderStrokePosition.Inner", a)
        self.assertIn('Instance.new("TextButton")', a)
        self.assertIn("REPLACE_ME", a)
        self.assertNotIn("rbxassetid://", a)


if __name__ == "__main__":
    unittest.main(verbosity=1)
