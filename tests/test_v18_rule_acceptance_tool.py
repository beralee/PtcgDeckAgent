from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
TOOLS_ROOT = REPO_ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOLS_ROOT))

import v18_rule_acceptance as acceptance  # noqa: E402


def _details(reason: str = "normal_game_end", games: int = 100) -> list[dict[str, object]]:
    return [
        {
            "seed": 1000 + index,
            "failure_reason": reason,
            "terminated_by_cap": False,
            "stalled": False,
        }
        for index in range(games)
    ]


def _sweep_entry(deck_id: int, strong: bool, wins: int = 50, games: int = 100) -> dict[str, object]:
    return {
        "deck_id": deck_id,
        "deck_name": f"Deck {deck_id}",
        "tracked_strong_fixed_opening": strong,
        "games": games,
        "wins": wins,
        "losses": games - wins,
        "draws": 0,
        "win_rate": wins / games,
        "failure_reason_counts": {"normal_game_end": games},
        "games_detail": _details(games=games),
    }


def _single_summary(deck_id: int, strong: bool, wins: int = 50) -> dict[str, object]:
    return {
        "deck_id": deck_id,
        "deck_name": f"Deck {deck_id}",
        "deck_strong_fixed_opening": strong,
        "games": 100,
        "wins": wins,
        "losses": 100 - wins,
        "draws": 0,
        "win_rate": wins / 100,
        "failure_reasons": {"normal_game_end": 99, "deck_out": 1},
        "per_game": _details(games=99) + _details(reason="deck_out", games=1),
        "is_clean": True,
    }


class V18RuleAcceptanceToolTests(unittest.TestCase):
    def _load(self, payloads: list[tuple[str, dict[str, object], str | None]]) -> tuple[list[dict[str, object]], list[str]]:
        tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(tempdir.cleanup)
        root = Path(tempdir.name)
        paths_by_mode: dict[str | None, list[Path]] = {None: [], "normal": [], "strong": []}
        for filename, payload, mode_hint in payloads:
            path = root / filename
            path.write_text(json.dumps(payload), encoding="utf-8")
            paths_by_mode[mode_hint].append(path)
        return acceptance.load_records(paths_by_mode)

    def test_accepts_sweep_and_single_summary_schemas_at_exact_threshold(self) -> None:
        deck_id = 800018509
        normal_payload = {"mode": "matchup_sweep", "error_count": 0, "errors": [], "results": [_sweep_entry(deck_id, False)]}
        records, errors = self._load(
            [
                ("normal.json", normal_payload, None),
                ("strong.json", _single_summary(deck_id, True), None),
            ]
        )

        report = acceptance.evaluate_acceptance(records, [deck_id], input_errors=errors)

        self.assertTrue(report["overall_pass"])
        self.assertEqual(report["summary"]["passed_results"], 2)
        self.assertTrue(all(row["clean"] for row in report["rows"]))

    def test_fails_when_a_mode_is_missing(self) -> None:
        deck_id = 800018509
        records, errors = self._load([("normal.json", _single_summary(deck_id, False, 60), None)])

        report = acceptance.evaluate_acceptance(records, [deck_id], input_errors=errors)

        self.assertFalse(report["overall_pass"])
        self.assertIn(f"missing strong result for deck {deck_id}", report["errors"])

    def test_fails_low_win_rate_and_wrong_game_count(self) -> None:
        deck_id = 800018509
        short_normal = _sweep_entry(deck_id, False, wins=49, games=99)
        records, errors = self._load(
            [
                ("normal.json", short_normal, None),
                ("strong.json", _single_summary(deck_id, True, 55), None),
            ]
        )

        report = acceptance.evaluate_acceptance(records, [deck_id], input_errors=errors)
        normal_row = next(row for row in report["rows"] if row["mode"] == "normal")

        self.assertFalse(report["overall_pass"])
        self.assertTrue(any("exactly 100 games" in failure for failure in normal_row["failures"]))
        self.assertTrue(any("below 50.0%" in failure for failure in normal_row["failures"]))

    def test_fails_unclean_reason_even_when_summary_claims_clean(self) -> None:
        deck_id = 800018509
        dirty = _single_summary(deck_id, False, 60)
        dirty["failure_reasons"] = {"normal_game_end": 99, "action_cap": 1}
        dirty["per_game"] = _details(games=99) + _details(reason="action_cap", games=1)
        records, errors = self._load(
            [
                ("normal.json", dirty, None),
                ("strong.json", _single_summary(deck_id, True, 60), None),
            ]
        )

        report = acceptance.evaluate_acceptance(records, [deck_id], input_errors=errors)
        normal_row = next(row for row in report["rows"] if row["mode"] == "normal")

        self.assertFalse(report["overall_pass"])
        self.assertIn("unclean end reasons: action_cap", normal_row["failures"])

    def test_fails_formal_100_game_report_when_per_game_details_are_missing(self) -> None:
        deck_id = 800018509
        normal = _single_summary(deck_id, False, 60)
        del normal["per_game"]
        records, errors = self._load(
            [("normal.json", normal, None), ("strong.json", _single_summary(deck_id, True, 60), None)]
        )

        report = acceptance.evaluate_acceptance(records, [deck_id], input_errors=errors)
        normal_row = next(row for row in report["rows"] if row["mode"] == "normal")

        self.assertFalse(report["overall_pass"])
        self.assertTrue(any("per-game detail count 0 does not match games 100" in failure for failure in normal_row["failures"]))

    def test_fails_formal_100_game_report_when_per_game_length_is_wrong(self) -> None:
        deck_id = 800018509
        normal = _single_summary(deck_id, False, 60)
        normal["per_game"] = _details(games=99)
        records, errors = self._load(
            [("normal.json", normal, None), ("strong.json", _single_summary(deck_id, True, 60), None)]
        )

        report = acceptance.evaluate_acceptance(records, [deck_id], input_errors=errors)
        normal_row = next(row for row in report["rows"] if row["mode"] == "normal")

        self.assertFalse(report["overall_pass"])
        self.assertTrue(any("per-game detail count 99 does not match games 100" in failure for failure in normal_row["failures"]))

    def test_fails_when_any_per_game_result_is_stalled_or_terminated_by_cap(self) -> None:
        deck_id = 800018509
        normal = _single_summary(deck_id, False, 60)
        normal["per_game"][0]["stalled"] = True
        normal["per_game"][1]["terminated_by_cap"] = True
        records, errors = self._load(
            [("normal.json", normal, None), ("strong.json", _single_summary(deck_id, True, 60), None)]
        )

        report = acceptance.evaluate_acceptance(records, [deck_id], input_errors=errors)
        normal_row = next(row for row in report["rows"] if row["mode"] == "normal")

        self.assertFalse(report["overall_pass"])
        self.assertIn("2 games are marked stalled or terminated by cap", normal_row["failures"])

    def test_fails_when_any_per_game_failure_reason_is_invalid(self) -> None:
        deck_id = 800018509
        normal = _single_summary(deck_id, False, 60)
        normal["per_game"][0]["failure_reason"] = "action_cap"
        records, errors = self._load(
            [("normal.json", normal, None), ("strong.json", _single_summary(deck_id, True, 60), None)]
        )

        report = acceptance.evaluate_acceptance(records, [deck_id], input_errors=errors)
        normal_row = next(row for row in report["rows"] if row["mode"] == "normal")

        self.assertFalse(report["overall_pass"])
        self.assertIn("per-game unclean end reasons: action_cap", normal_row["failures"])

    def test_fails_duplicate_result_instead_of_summing_iterations(self) -> None:
        deck_id = 800018509
        records, errors = self._load(
            [
                ("normal_a.json", _single_summary(deck_id, False, 55), None),
                ("normal_b.json", _single_summary(deck_id, False, 60), None),
                ("strong.json", _single_summary(deck_id, True, 60), None),
            ]
        )

        report = acceptance.evaluate_acceptance(records, [deck_id], input_errors=errors)

        self.assertFalse(report["overall_pass"])
        self.assertTrue(any("duplicate normal results" in error for error in report["errors"]))

    def test_cli_writes_machine_report_and_returns_nonzero_on_failure(self) -> None:
        deck_id = 800018509
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            normal_path = root / "normal.json"
            strong_path = root / "strong.json"
            output_path = root / "acceptance.json"
            normal_path.write_text(json.dumps(_single_summary(deck_id, False, 49)), encoding="utf-8")
            strong_path.write_text(json.dumps(_single_summary(deck_id, True, 60)), encoding="utf-8")

            exit_code = acceptance.main(
                [
                    "--normal",
                    str(normal_path),
                    "--strong",
                    str(strong_path),
                    "--deck-ids",
                    str(deck_id),
                    "--json-output",
                    str(output_path),
                    "--json-only",
                ]
            )

            machine_report = json.loads(output_path.read_text(encoding="utf-8"))
            self.assertEqual(exit_code, 1)
            self.assertFalse(machine_report["overall_pass"])
            self.assertEqual(machine_report["summary"]["failed_results"], 1)


if __name__ == "__main__":
    unittest.main()
