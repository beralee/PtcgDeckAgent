"""Extract small, reproducible loading estimates from the checked-in bench receipt."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "evidence/ptcgdap/performance_20260925.json"
NAVIGATION_SOURCE = ROOT / "evidence/ptcgdap/scene_loading_navigation_20260927.json"
OUTPUT = ROOT / "data/performance/scene_loading_baselines.json"
# Specific entry benches supersede all-group timings (which prewarm resources).
REPORTS = {
    "windows_editor": ["windows_editor_after", "windows_editor_navigation_entry"],
    "windows_release": ["windows_release", "windows_navigation_entry", "windows_release_author_entry"],
    "android_emulator_reference": ["android_emulator_release", "android_navigation_entry", "android_emulator_author_entry"],
}


def build(source: bytes, navigation_source: bytes) -> dict:
    evidence = json.loads(source)
    evidence["reports"].update(json.loads(navigation_source)["reports"])
    profiles = {}
    for profile, report_ids in REPORTS.items():
        events = {}
        for report_id in report_ids:
            report = evidence["reports"][report_id]
            if report["status"] not in {"within_measured_budgets", "needs_optimization"}:
                raise ValueError(f"Invalid bench report: {report_id}")
            for row in report["summary"]:
                event = row["case"]
                if not (event.startswith("navigation.") or event in {"battle.classic_start", "battle.author_start"}):
                    continue
                cache = row["cache_state"]
                duration = row["duration"]
                value = duration["p50_ms"]
                if cache not in {"first_in_process", "warm_in_process"} or duration["count"] < 1 or not math.isfinite(value) or value <= 0:
                    raise ValueError(f"Invalid loading sample: {report_id}/{event}/{cache}")
                events.setdefault(event, {})[cache] = {
                    "expected_ms": value,
                    "sample_count": duration["count"],
                    "source_report": report_id,
                }
        profiles[profile] = events
    return {
        "schema_version": 1,
        "source": SOURCE.relative_to(ROOT).as_posix(),
        "source_canonical_sha256": canonical_sha256(source),
        "navigation_source": NAVIGATION_SOURCE.relative_to(ROOT).as_posix(),
        "navigation_source_canonical_sha256": canonical_sha256(navigation_source),
        "statistic": "p50_ms",
        "usage": "Visual estimate only; Android emulator is a reference, not physical-device qualification.",
        "profiles": profiles,
    }


def canonical_sha256(source: bytes) -> str:
    canonical = json.dumps(json.loads(source), ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    payload = json.dumps(build(SOURCE.read_bytes(), NAVIGATION_SOURCE.read_bytes()), ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_text(encoding="utf-8") != payload:
            raise SystemExit("Loading baselines differ from bench evidence; regenerate them.")
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(payload, encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
