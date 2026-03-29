#!/usr/bin/env bash
# Iterative self-play training with benchmark-gated promotion.

set -euo pipefail

GODOT="${GODOT:-godot}"
PYTHON_BIN="${PYTHON:-python}"
ITERATIONS=5
GENERATIONS=10
EPOCHS=100
DATA_DIR=""
MODEL_DIR="./models"
LANE_RECIPE_ID=""
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PIPELINE_NAME="fixed_three_deck_training"

while [[ $# -gt 0 ]]; do
    case $1 in
        --godot) GODOT="$2"; shift 2 ;;
        --iterations) ITERATIONS="$2"; shift 2 ;;
        --generations) GENERATIONS="$2"; shift 2 ;;
        --epochs) EPOCHS="$2"; shift 2 ;;
        --data-dir) DATA_DIR="$2"; shift 2 ;;
        --model-dir) MODEL_DIR="$2"; shift 2 ;;
        --lane-recipe-id) LANE_RECIPE_ID="$2"; shift 2 ;;
        *) echo "[error] unknown argument: $1"; exit 1 ;;
    esac
done

resolve_user_root() {
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        echo "$APPDATA/Godot/app_userdata/PTCG Train"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "$HOME/Library/Application Support/Godot/app_userdata/PTCG Train"
    else
        echo "$HOME/.local/share/godot/app_userdata/PTCG Train"
    fi
}

USER_ROOT="$(resolve_user_root)"
GLOBAL_DATA_DIR_DEFAULT="$USER_ROOT/training_data"
AI_AGENTS_DIR="$USER_ROOT/ai_agents"
AI_VERSIONS_GLOBAL_DIR="$USER_ROOT/ai_versions"
AI_VERSIONS_DIR="user://ai_versions"
TRAIN_RUNS_DIR="user://training_runs"

if [[ -z "$DATA_DIR" ]]; then
    DATA_DIR="$GLOBAL_DATA_DIR_DEFAULT"
fi

mkdir -p "$MODEL_DIR"
mkdir -p "$DATA_DIR"
mkdir -p "$AI_AGENTS_DIR"
mkdir -p "$AI_VERSIONS_GLOBAL_DIR"

PYTHON_CMD=()

resolve_python_cmd() {
    if command -v py >/dev/null 2>&1 && py -3.13 -c "import numpy, torch" >/dev/null 2>&1; then
        PYTHON_CMD=(py -3.13)
        return 0
    fi
    if command -v py >/dev/null 2>&1 && py -3.10 -c "import numpy, torch" >/dev/null 2>&1; then
        PYTHON_CMD=(py -3.10)
        return 0
    fi
    if command -v "$PYTHON_BIN" >/dev/null 2>&1 && "$PYTHON_BIN" -c "import numpy, torch" >/dev/null 2>&1; then
        PYTHON_CMD=("$PYTHON_BIN")
        return 0
    fi

    echo "[error] no Python interpreter with numpy and torch is available"
    return 1
}

resolve_python_cmd

latest_agent_config() {
    find "$AI_AGENTS_DIR" -maxdepth 1 -type f -name 'agent_*.json' | sort | tail -n 1
}

latest_approved_baseline() {
    local index_path="$AI_VERSIONS_GLOBAL_DIR/index.json"
    if [[ ! -f "$index_path" ]]; then
        return 1
    fi

    "${PYTHON_CMD[@]}" - "$index_path" <<'PY'
import json
import sys

index_path = sys.argv[1]
try:
    with open(index_path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    sys.exit(1)

if not isinstance(data, dict):
    sys.exit(1)

playable = [
    value for value in data.values()
    if isinstance(value, dict) and str(value.get("status", "")) == "playable"
]
if not playable:
    sys.exit(1)

def sort_key(record):
    return (
        str(record.get("created_at", "")),
        int(record.get("save_order", 0)),
        str(record.get("version_id", "")),
    )

latest = sorted(playable, key=sort_key)[-1]
print(str(latest.get("version_id", "")))
print(str(latest.get("display_name", "")))
print(str(latest.get("agent_config_path", "")))
print(str(latest.get("value_net_path", "")))
PY
}

move_exported_games() {
    local destination="$1"
    mkdir -p "$destination"
    find "$DATA_DIR" -maxdepth 1 -type f -name 'game_*.json' -print0 | while IFS= read -r -d '' file; do
        mv "$file" "$destination/"
    done
}

summarize_training_data() {
    local source_dir="$1"
    find "$source_dir" -maxdepth 1 -type f -name 'game_*.json' 2>/dev/null | wc -l | tr -d ' '
}

echo "===== PTCG Train Iterative Training ====="
echo "Godot:           $GODOT"
echo "Project dir:     $PROJECT_DIR"
echo "Global data dir: $DATA_DIR"
echo "Model dir:       $MODEL_DIR"
echo "Python:          $("${PYTHON_CMD[@]}" -c 'import sys; print(sys.executable)')"
echo "Iterations:      $ITERATIONS"
echo "Generations:     $GENERATIONS"
echo "Epochs:          $EPOCHS"
if [[ -n "$LANE_RECIPE_ID" ]]; then
    echo "Lane recipe:     $LANE_RECIPE_ID"
fi
echo ""

CURRENT_WEIGHTS=""
CURRENT_AGENT_CONFIG=""
CURRENT_BASELINE_VERSION_ID=""
CURRENT_BASELINE_DISPLAY_NAME=""
CURRENT_BASELINE_SOURCE="default"
LAST_PUBLISHED_RUN=""

if APPROVED_BASELINE_RAW="$(latest_approved_baseline 2>/dev/null)" && [[ -n "$APPROVED_BASELINE_RAW" ]]; then
    mapfile -t APPROVED_BASELINE_LINES <<<"$APPROVED_BASELINE_RAW"
    CURRENT_BASELINE_VERSION_ID="${APPROVED_BASELINE_LINES[0]:-}"
    CURRENT_BASELINE_DISPLAY_NAME="${APPROVED_BASELINE_LINES[1]:-}"
    CURRENT_AGENT_CONFIG="${APPROVED_BASELINE_LINES[2]:-}"
    CURRENT_WEIGHTS="${APPROVED_BASELINE_LINES[3]:-}"
    CURRENT_BASELINE_SOURCE="approved-playable"
elif CURRENT_AGENT_CONFIG="$(latest_agent_config || true)"; [[ -n "${CURRENT_AGENT_CONFIG:-}" ]]; then
    CURRENT_BASELINE_SOURCE="bootstrap-latest-agent"
else
    CURRENT_AGENT_CONFIG=""
    CURRENT_BASELINE_SOURCE="default-config"
fi

echo "Baseline source: $CURRENT_BASELINE_SOURCE"
if [[ -n "$CURRENT_BASELINE_VERSION_ID" ]]; then
    echo "Baseline version:$CURRENT_BASELINE_VERSION_ID"
fi
if [[ -n "$CURRENT_AGENT_CONFIG" ]]; then
    echo "Baseline agent:  $CURRENT_AGENT_CONFIG"
else
    echo "Baseline agent:  <default-config>"
fi
if [[ -n "$CURRENT_WEIGHTS" ]]; then
    echo "Baseline value:  $CURRENT_WEIGHTS"
else
    echo "Baseline value:  <none>"
fi

for i in $(seq 1 "$ITERATIONS"); do
    echo ""
    echo "===== Iteration $i / $ITERATIONS ====="

    RUN_ID="run_$(date +%Y%m%d_%H%M%S)_$(printf '%02d' "$i")"
    RUN_DIR="$DATA_DIR/runs/$RUN_ID"
    RUN_DATA_DIR="$RUN_DIR/self_play"
    RUN_MODEL_DIR="$RUN_DIR/models"
    RUN_BENCHMARK_DIR="$RUN_DIR/benchmark"
    SUMMARY_FILE="$RUN_BENCHMARK_DIR/summary.json"
    mkdir -p "$RUN_DATA_DIR" "$RUN_MODEL_DIR" "$RUN_BENCHMARK_DIR"

    BASELINE_AGENT_CONFIG="$CURRENT_AGENT_CONFIG"
    BASELINE_WEIGHTS="$CURRENT_WEIGHTS"
    BASELINE_VERSION_ID="$CURRENT_BASELINE_VERSION_ID"
    BASELINE_DISPLAY_NAME="$CURRENT_BASELINE_DISPLAY_NAME"
    BASELINE_SOURCE="$CURRENT_BASELINE_SOURCE"
    STALE_STAGE_DIR="$RUN_DIR/stale_stage"
    move_exported_games "$STALE_STAGE_DIR"
    echo "[phase 1] self-play evolution ($GENERATIONS generations)"
    echo "  baseline source: ${BASELINE_SOURCE}"
    if [[ -n "$BASELINE_VERSION_ID" ]]; then
        echo "  baseline version: ${BASELINE_VERSION_ID} (${BASELINE_DISPLAY_NAME:-unnamed})"
    fi
    TUNER_ARGS=(
        --headless
        --quit-after 3600
        --path "$PROJECT_DIR"
        res://scenes/tuner/TunerRunner.tscn
        --
        --generations="$GENERATIONS"
        --progress-output="$RUN_DIR/status.json"
        --export-data
    )
    if [[ -n "$CURRENT_AGENT_CONFIG" ]]; then
        TUNER_ARGS+=(--agent-config="$CURRENT_AGENT_CONFIG")
        echo "  using promoted agent config: $CURRENT_AGENT_CONFIG"
    fi
    if [[ -n "$CURRENT_WEIGHTS" ]]; then
        TUNER_ARGS+=(--value-net="$CURRENT_WEIGHTS")
        echo "  using promoted value net: $CURRENT_WEIGHTS"
    fi
    "$GODOT" "${TUNER_ARGS[@]}" || {
        echo "[warn] TunerRunner exited non-zero; continuing to artifact handling"
    }

    CANDIDATE_AGENT_CONFIG="$(latest_agent_config || true)"
    if [[ -z "$CANDIDATE_AGENT_CONFIG" ]]; then
        CANDIDATE_AGENT_CONFIG="$BASELINE_AGENT_CONFIG"
    fi
    echo "  candidate agent config: ${CANDIDATE_AGENT_CONFIG:-<default-config>}"

    move_exported_games "$RUN_DATA_DIR"
    DATA_COUNT="$(summarize_training_data "$RUN_DATA_DIR")"
    echo "  run training samples: $DATA_COUNT"
    if [[ "$DATA_COUNT" -eq 0 ]]; then
        echo "[warn] no training data exported for $RUN_ID; skipping iteration"
        continue
    fi

    CANDIDATE_WEIGHTS="$RUN_MODEL_DIR/value_net_v${i}.json"
    echo "[phase 2] train value net ($EPOCHS epochs)"
    "${PYTHON_CMD[@]}" "$PROJECT_DIR/scripts/training/train_value_net.py" \
        --data-dir "$RUN_DATA_DIR" \
        --output "$CANDIDATE_WEIGHTS" \
        --epochs "$EPOCHS" \
        --batch-size 256 \
        --lr 0.001

    if [[ ! -f "$CANDIDATE_WEIGHTS" ]]; then
        echo "[warn] value net output missing: $CANDIDATE_WEIGHTS"
        continue
    fi
    echo "  candidate value net: $CANDIDATE_WEIGHTS"

    echo "[phase 3] fixed benchmark gate"
    BENCHMARK_ARGS=(
        --headless
        --path "$PROJECT_DIR"
        res://scenes/tuner/BenchmarkRunner.tscn
        --
        --agent-a-config="$CANDIDATE_AGENT_CONFIG"
        --agent-b-config="$BASELINE_AGENT_CONFIG"
        --value-net-a="$CANDIDATE_WEIGHTS"
        --value-net-b="$BASELINE_WEIGHTS"
        --summary-output="$SUMMARY_FILE"
        --run-id="$RUN_ID"
        --pipeline-name="$PIPELINE_NAME"
        --run-dir="$RUN_DIR"
        --run-registry-dir="$TRAIN_RUNS_DIR"
        --version-registry-dir="$AI_VERSIONS_DIR"
        --publish-display-name="iter-${i} candidate"
        --lane-recipe-id="$LANE_RECIPE_ID"
        --baseline-source="$BASELINE_SOURCE"
        --baseline-version-id="$BASELINE_VERSION_ID"
        --baseline-display-name="$BASELINE_DISPLAY_NAME"
        --baseline-agent-config="$BASELINE_AGENT_CONFIG"
        --baseline-value-net="$BASELINE_WEIGHTS"
    )

    if "$GODOT" "${BENCHMARK_ARGS[@]}"; then
        CURRENT_WEIGHTS="$CANDIDATE_WEIGHTS"
        if [[ -n "$CANDIDATE_AGENT_CONFIG" ]]; then
            CURRENT_AGENT_CONFIG="$CANDIDATE_AGENT_CONFIG"
        fi
        if PROMOTED_BASELINE_RAW="$(latest_approved_baseline 2>/dev/null)" && [[ -n "$PROMOTED_BASELINE_RAW" ]]; then
            mapfile -t PROMOTED_BASELINE_LINES <<<"$PROMOTED_BASELINE_RAW"
            CURRENT_BASELINE_VERSION_ID="${PROMOTED_BASELINE_LINES[0]:-}"
            CURRENT_BASELINE_DISPLAY_NAME="${PROMOTED_BASELINE_LINES[1]:-}"
            CURRENT_AGENT_CONFIG="${PROMOTED_BASELINE_LINES[2]:-$CURRENT_AGENT_CONFIG}"
            CURRENT_WEIGHTS="${PROMOTED_BASELINE_LINES[3]:-$CURRENT_WEIGHTS}"
            CURRENT_BASELINE_SOURCE="approved-playable"
        else
            CURRENT_BASELINE_VERSION_ID=""
            CURRENT_BASELINE_DISPLAY_NAME=""
            CURRENT_BASELINE_SOURCE="promoted-candidate"
        fi
        LAST_PUBLISHED_RUN="$RUN_ID"
        echo "  benchmark decision: published"
        if [[ -n "$CURRENT_BASELINE_VERSION_ID" ]]; then
            echo "  promoted approved version: $CURRENT_BASELINE_VERSION_ID"
        fi
    else
        echo "  benchmark decision: benchmark_failed"
        echo "  keeping baseline source: ${CURRENT_BASELINE_SOURCE}"
    fi
done

echo ""
echo "===== Training Complete ====="
echo "Promoted agent config: ${CURRENT_AGENT_CONFIG:-<default>}"
echo "Promoted value net:    ${CURRENT_WEIGHTS:-<none>}"
echo "Last published run:    ${LAST_PUBLISHED_RUN:-<none>}"
