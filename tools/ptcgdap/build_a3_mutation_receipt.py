from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.a3_mutation import build_mutation_receipt
from scripts.ai.ptcgdap.source_lock import load_json_strict


SCOPE = ROOT / "data/ptcgdap/a3/five_deck_scope_v2.json"
VECTORS = ROOT / "contracts/ptcgdap/a3_comparator_conformance_v2.json"
OUTPUT = ROOT / "evidence/ptcgdap/a3/mutation_receipt_v2.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--godot-exe",
        default=r"D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe",
    )
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="ptcgdap-a3-comparator-") as temporary:
        godot_output = Path(temporary) / "godot.json"
        completed = subprocess.run(
            [
                args.godot_exe, "--headless", "--path", str(ROOT), "--script",
                "res://tools/ptcgdap/run_a3_comparator_vectors.gd", "--",
                f"--output={godot_output}",
            ],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=120,
        )
        if completed.returncode != 0 or not godot_output.is_file():
            print(completed.stdout, file=sys.stderr)
            print("a3_godot_comparator_run_failed", file=sys.stderr)
            return 1
        godot_result = load_json_strict(godot_output)
    receipt = build_mutation_receipt(load_json_strict(SCOPE), VECTORS, godot_result)
    if receipt["python_godot_comparator_consistent"] is not True:
        print("a3_comparator_cross_runtime_mismatch", file=sys.stderr)
        return 1
    encoded = (
        json.dumps(receipt, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
    ).encode("utf-8")
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(encoded)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
