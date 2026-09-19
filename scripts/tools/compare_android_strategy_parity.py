"""Fail closed on missing evidence, dirty matches, or the first public-window difference.

Uses only exported public decision records. Engine RNG/deck/prize internals must
never be added to these records. Run with Python's standard library only.
"""
import argparse
import copy
import html
import json
from pathlib import Path

SEEDS = (84590, 84591, 84592)
GUARD_FIXTURE_SHA = "17B6DFE95383C65A067283BB16FC09FE83128C0D6E73E13B7D969ADC016DF704"
ZERO_COUNTERS = (
    "policy_errors", "invalid_outputs", "engine_rejections",
    "same_window_fallbacks", "policy_worker_stale_results",
    "policy_worker_start_failures", "developer_trace_dropped_records",
)


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def first_difference(left, right, path="$"):
    if type(left) != type(right):
        return {"path": path, "left": left, "right": right}
    if isinstance(left, dict):
        if left.keys() != right.keys():
            return {"path": path, "left_keys": sorted(left), "right_keys": sorted(right)}
        for key in sorted(left):
            difference = first_difference(left[key], right[key], f"{path}.{key}")
            if difference:
                return difference
    elif isinstance(left, list):
        if len(left) != len(right):
            return {"path": path, "left_length": len(left), "right_length": len(right)}
        for index, (a, b) in enumerate(zip(left, right)):
            difference = first_difference(a, b, f"{path}[{index}]")
            if difference:
                return difference
    elif left != right:
        return {"path": path, "left": left, "right": right}
    return None


def semantic_record(record):
    result = copy.deepcopy(record)
    # Duration is measured on different devices and is not policy authority.
    result["host"].pop("latency_usec", None)
    return result


def validate_match(report, expected_sha, seed, seat):
    assert report["package_sha256"] == expected_sha, "package changed"
    assert report["seed"] == seed and report["summary"]["seat"] == seat, "wrong match identity"
    assert report["test_error"] == "", report["test_error"]
    assert report["summary"]["game_over"] is True, "unfinished match"
    assert report["summary"]["failure"] == "", "match failed"
    for key in ZERO_COUNTERS:
        assert type(report["audit"][key]) is int and report["audit"][key] == 0, f"dirty counter: {key}"
    trace = report["trace"]
    assert trace and len(trace) == report["audit"]["policy_successes"], "missing/truncated trace"
    diagnostics = report["audit"]["model_diagnostic_counts"]
    unexpected = set(diagnostics) - {"model_bypassed_empty_rule_result", "model_bypassed_mandatory", "model_bypassed_terminal"}
    # The tiny fixed-output model intentionally exercises these fail-closed
    # guards. This exact fixture exception is never granted to downloaded models.
    if expected_sha == GUARD_FIXTURE_SHA:
        unexpected -= {"model_unknown_uid", "model_desired_count_invalid"}
        assert report["audit"]["model_inference_successes"] > 0, "model was bypassed for the entire match"
    assert not unexpected, f"unexpected model fallback: {sorted(unexpected)}"
    for record in trace:
        frame, host = record["frame"], record["host"]
        assert host["status"] == "accepted" and host["fallback_used"] is False, "fallback/rejection"
        assert host["error_code"] == "", "host error"
        assert record["policy"]["ok"] is True and record["policy"]["error_code"] == "", "policy error"
        assert record["policy"]["reported_public_observation_hash"] == frame["source"]["public_observation_hash"], "stale observation"
        assert record["policy"]["reported_window_id"] == frame["source"]["window_id"], "stale window"
        options = frame["options"]
        evidence = host["model_input_evidence"]
        if evidence.get("status") == "captured":
            assert len(evidence["projector_sha256"]) == 64, "missing projector artifact identity"
        selected = host["accepted_indexes"]
        proposed = record["policy"]["reported_indexes"]
        model = host.get("model_decision", {})
        if model:
            assert model["fallback_indexes"] == proposed, "model lost the rules proposal"
            assert model["selected_indexes"] == selected, "host did not commit the model adjudication"
            if model["invoked"] and model["diagnostic_code"] == "":
                assert evidence["status"] == "captured", "missing model projection"
                assert all(i in evidence["frontier_indexes"] for i in selected), "model escaped the base frontier"
            else:
                assert proposed == selected, "model bypass/failure changed selection"
        else:
            assert proposed == selected, "host changed selection without model adjudication"
        assert all(type(i) is int and 0 <= i < len(options) for i in selected), "illegal index"
        assert host["accepted_option_fingerprints"] == [options[i]["option_fingerprint"] for i in selected], "fingerprint mismatch"
    successful_models = sum(bool(r["host"].get("model_decision", {}).get("invoked")) and r["host"]["model_decision"]["diagnostic_code"] == "" for r in trace)
    assert successful_models == report["audit"]["model_inference_successes"], "missing model adjudication records"


def compare(left_dir, right_dir):
    left_complete, right_complete = (read(p / "complete.json") for p in (left_dir, right_dir))
    expected = {(seed, seat) for seed in SEEDS for seat in (0, 1)}
    assert {left_complete["platform"], right_complete["platform"]} == {"Android", "Windows"}, "expected Android and Windows"
    for completion in (left_complete, right_complete):
        assert completion["standalone_export"] is True, "not an exported runtime"
        assert completion["script_errors"] == [], "runtime script errors"
        assert completion["ok"] is True, "run did not pass"
        identities = [(x["seed"], x["seat"]) for x in completion["matches"]]
        assert len(identities) == len(expected) and set(identities) == expected, "incomplete/duplicate suite"
        assert all(x["error"] == "" for x in completion["matches"]), "completion contains failure"
    for directory in (left_dir, right_dir):
        smoke = read(directory / "smoke.json")
        assert len(smoke) == 12 and len({x["test"] for x in smoke}) == 12, "missing smoke checks"
        assert all(x["error"] == "" for x in smoke), "native/lifecycle smoke failed"
    sha = left_complete["package_sha256"]
    assert sha == right_complete["package_sha256"] and len(sha) == 64, "different package binaries"
    comparisons = []
    for seed, seat in sorted(expected):
        name = f"match-{seed}-{seat}.json"
        left, right = (read(p / name) for p in (left_dir, right_dir))
        for report in (left, right):
            validate_match(report, sha, seed, seat)
        difference = first_difference(
            [semantic_record(r) for r in left["trace"]],
            [semantic_record(r) for r in right["trace"]],
        )
        if difference:
            return {"ok": False, "match": name, "first_difference": difference}
        assert left["winner"] == right["winner"], "terminal winner differs"
        assert left["summary"]["steps"] == right["summary"]["steps"], "engine progress differs"
        for key in ("model_inference_successes", "model_fallbacks", "model_diagnostic_counts", "prompt_counts"):
            assert left["audit"][key] == right["audit"][key], f"audit difference: {key}"
        comparisons.append({"seed": seed, "seat": seat, "windows": len(left["trace"]), "winner": left["winner"], "steps": left["summary"]["steps"], "model_successes":left["audit"]["model_inference_successes"], "model_diagnostics":left["audit"]["model_diagnostic_counts"]})
    return {"ok": True, "package_sha256": sha, "platforms": [left_complete["platform"], right_complete["platform"]], "matches": comparisons, "ignored_fields": ["host.latency_usec"]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("left", type=Path)
    parser.add_argument("right", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = compare(args.left, args.right)
    except (AssertionError, KeyError, ValueError, OSError) as error:
        result = {"ok": False, "error": f"{type(error).__name__}: {error}"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    write_review(args.output.with_suffix(".html"), result, args.left, args.right)
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["ok"] else 1


def write_review(path, result, left_dir, right_dir):
    """Searchable, device-local review; no CDN, telemetry, or external resources."""
    esc = lambda value: html.escape(str(value))
    rows = []
    for seed in SEEDS:
        for seat in (0, 1):
            name = f"match-{seed}-{seat}.json"
            try:
                left, right = read(left_dir / name), read(right_dir / name)
                rows.append(f'<h2>种子 {seed} · 策略座位 {seat}</h2>')
                rows.append(f'<p>{len(left["trace"])} 个决策窗口 · 胜方 {esc(left["winner"])} · {esc(left["summary"]["steps"])} 步</p>')
                for index, record in enumerate(left["trace"]):
                    peer = right["trace"][index] if index < len(right["trace"]) else None
                    difference = first_difference(semantic_record(record), semantic_record(peer)) if peer else {"error": "missing peer"}
                    frame, policy, host = record["frame"], record["policy"], record["host"]
                    title = f'#{frame.get("sequence", index+1)} {frame.get("prompt_kind", "")} → {host["accepted_indexes"]} · {policy.get("selection_source", "")} · {"差异" if difference else "一致"}'
                    body = {"android_record": record, "difference": difference}
                    rows.append('<details class="window"><summary>' + esc(title) + '</summary><pre>' + esc(json.dumps(body, ensure_ascii=False, indent=2)) + '</pre></details>')
            except (OSError, KeyError, ValueError) as error:
                rows.append(f'<p class="failure">{esc(name)}: {esc(error)}</p>')
    status = "通过" if result["ok"] else "失败"
    page = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>安卓策略执行对照回顾</title><style>body{max-width:1100px;margin:40px auto;padding:0 20px;font:16px/1.6 system-ui;background:#f6f7f8;color:#18202a}h1{font-size:28px}h2{margin-top:36px}input{width:95%;padding:12px;font:inherit}details{background:white;margin:8px 0;border:1px solid #dce1e6;border-radius:6px}summary{padding:12px;cursor:pointer}pre{overflow:auto;padding:16px;font-size:12px;max-height:650px}.failure{color:#a22}</style>'
    page += f'<h1>安卓策略执行对照：{status}</h1><p>逐项比较公开状态、当前合法选项、策略输出和主机提交；只忽略耗时。所有数据保留在本机。</p><pre>{esc(json.dumps(result,ensure_ascii=False,indent=2))}</pre><label>搜索窗口、卡牌标识或规则<input id="search" placeholder="例如 search、assignment_target、卡牌 UID"></label>'
    page += ''.join(rows)
    page += '<script>document.querySelector("#search").addEventListener("input",e=>{const q=e.target.value.toLowerCase();document.querySelectorAll(".window").forEach(x=>{x.hidden=!x.textContent.toLowerCase().includes(q)})});</script></html>'
    path.write_text(page, encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
