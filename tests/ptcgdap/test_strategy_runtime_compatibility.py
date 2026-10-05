import copy
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageLoader
from scripts.ai.ptcgdap.strategy_runtime_compatibility import requirements


class StrategyRuntimeCompatibilityTests(unittest.TestCase):
    def test_signed_dragapult_metadata_retains_exact_identity_and_requirement(self):
        path = Path(__file__).parent / "fixtures/strategy_profiles/dragapult-0.29.0.ptcgai"
        metadata = AuthorStrategyPackageLoader().load_path(path).to_dict()
        self.assertEqual(metadata["archive_sha256"], "AD8396CA9C9D15058A9507D4D2CA450636E638CE4298B12902D232C515531629")
        self.assertEqual(metadata["runtime_compatibility"], {
            "minimum_client_version": "0.6.3", "minimum_client_build": 63,
            "required_profiles": ["damage_forecast_profile:reviewed-gust-v1", "plan_comparison_profile:resource-continuity-v2"],
        })
        self.assertFalse(metadata["execution_trusted"])

    def test_legacy_requirements_remain_empty(self):
        self.assertEqual(requirements({}), {})
        self.assertEqual(requirements({"plan_comparison_profile": "legacy-v1"}), {})

    def test_unknown_profile_fails_without_claiming_a_version(self):
        for value in (None, False, 3, [], {}, "resource-continuity-v999"):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "package_runtime_profile_unknown"):
                requirements({"plan_comparison_profile": value})

    def test_requirement_inspection_is_read_only(self):
        policy = {"plan_comparison_profile": "resource-continuity-v2"}
        original = copy.deepcopy(policy)
        requirements(policy)
        self.assertEqual(policy, original)
