import copy
import json
import unittest

from scripts.tools.build_scene_loading_baselines import SOURCE, NAVIGATION_SOURCE, OUTPUT, build


class SceneLoadingBaselineTests(unittest.TestCase):
    def test_shipped_estimates_match_bench_receipt(self):
        self.assertEqual(json.loads(OUTPUT.read_text(encoding="utf-8")), build(SOURCE.read_bytes(), NAVIGATION_SOURCE.read_bytes()))

    def test_entry_bench_overrides_prewarmed_all_group(self):
        data = build(SOURCE.read_bytes(), NAVIGATION_SOURCE.read_bytes())["profiles"]
        setup = data["windows_release"]["navigation.battle_setup"]
        self.assertEqual(setup["first_in_process"]["source_report"], "windows_navigation_entry")
        self.assertGreater(setup["first_in_process"]["expected_ms"], 1000)
        self.assertLess(setup["warm_in_process"]["expected_ms"], 150)
        author = data["windows_release"]["battle.author_start"]["first_in_process"]
        self.assertEqual(author["source_report"], "windows_release_author_entry")
        self.assertNotIn("navigation.replay_browser", data["windows_release"])
        editor_setup = data["windows_editor"]["navigation.battle_setup"]["first_in_process"]
        self.assertEqual(editor_setup["source_report"], "windows_editor_navigation_entry")
        self.assertEqual(editor_setup["sample_count"], 3)

    def test_invalid_bench_and_nonfinite_samples_are_rejected(self):
        original = json.loads(SOURCE.read_bytes())
        bad = copy.deepcopy(original)
        bad["reports"]["windows_editor_after"]["status"] = "invalid"
        with self.assertRaises(ValueError):
            build(json.dumps(bad).encode(), NAVIGATION_SOURCE.read_bytes())
        bad = copy.deepcopy(original)
        for row in bad["reports"]["windows_editor_after"]["summary"]:
            if row["case"] == "navigation.battle_setup":
                row["duration"]["p50_ms"] = float("nan")
        with self.assertRaises(ValueError):
            build(json.dumps(bad).encode(), NAVIGATION_SOURCE.read_bytes())


if __name__ == "__main__":
    unittest.main()
