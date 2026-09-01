from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class LocalClientServiceBindingTests(unittest.TestCase):
    def test_client_defaults_to_production_continuous_ladder_view(self) -> None:
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        hub = (
            ROOT / "scenes/ptcgdap_strategy_hub/StrategyHub.gd"
        ).read_text(encoding="utf-8")

        self.assertIn(
            'strategy_platform/base_url="https://api.ptcg.skillserver.cn"',
            project,
        )
        self.assertIn(
            'strategy_platform/ranking_profile_id="godot_v18_ladder_v1"',
            project,
        )
        self.assertIn('"https://api.ptcg.skillserver.cn"', hub)
        self.assertIn('"godot_v18_ladder_v1"', hub)
        self.assertIn('OS.get_environment("PTCGDAP_PLATFORM_BASE_URL")', hub)
        self.assertIn('"PTCGDAP_MARKETPLACE_PROFILE_ID"', hub)
        self.assertGreaterEqual(hub.count("OS.is_debug_build()"), 2)

if __name__ == "__main__":
    unittest.main()
