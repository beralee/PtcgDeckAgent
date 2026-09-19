"""Generate the synthetic CPU/int32 cross-platform inference fixture (no training).

Development dependencies: onnx==1.20.1, onnxruntime==1.26.0, cryptography==46.0.3.
The .ort output is test data, never an admitted player strategy.
"""
from pathlib import Path
import json
import sys
import zipfile
import onnx
from onnx import TensorProto, helper
import onnxruntime as ort


def main() -> None:
    output = Path(__file__).parent / "fixtures" / "platform_actor.ort"
    output.parent.mkdir(parents=True, exist_ok=True)
    shapes = {
        "frame_i32": [1, 24], "frame_presence_i32": [1, 24],
        "option_i32": [1, 1024, 16], "option_presence_i32": [1, 1024, 16],
        "option_mask_i32": [1, 1024],
    }
    nodes = []
    initializers = [helper.make_tensor("axis1", TensorProto.INT64, [1], [1]),
                    helper.make_tensor("axis2", TensorProto.INT64, [1], [2]),
                    helper.make_tensor("one", TensorProto.INT32, [1], [1])]
    for source, result, axis in [
        ("frame_i32", "f", "axis1"), ("frame_presence_i32", "fp", "axis1"),
        ("option_i32", "o", "axis2"), ("option_presence_i32", "op", "axis2"),
    ]:
        nodes.append(helper.make_node("ReduceSum", [source, axis], [result], keepdims=0))
    nodes.extend([
        helper.make_node("Add", ["f", "fp"], ["frame_sum"]),
        helper.make_node("Add", ["o", "op"], ["option_sum"]),
        helper.make_node("Add", ["option_sum", "frame_sum"], ["scores"]),
        helper.make_node("Mul", ["scores", "option_mask_i32"], ["option_scores"]),
        helper.make_node("Cast", ["one"], ["desired_count"], to=TensorProto.INT32),
    ])
    graph = helper.make_graph(nodes, "platform_fixture", [
        helper.make_tensor_value_info(name, TensorProto.INT32, shape) for name, shape in shapes.items()
    ], [helper.make_tensor_value_info("option_scores", TensorProto.INT32, [1, 1024]),
        helper.make_tensor_value_info("desired_count", TensorProto.INT32, [1])], initializers)
    model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 18)], ir_version=10)
    onnx.checker.check_model(model)
    options = ort.SessionOptions()
    options.intra_op_num_threads = options.inter_op_num_threads = 1
    options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_BASIC
    options.optimized_model_filepath = str(output)
    options.add_session_config_entry("session.save_model_format", "ORT")
    ort.InferenceSession(model.SerializeToString(), options, providers=["CPUExecutionProvider"])
    print(output)
    root = Path(__file__).resolve().parents[3]
    sys.path.insert(0, str(root))
    from tools.ptcgdap import build_author_strategy_package as builder
    from scripts.ai.ptcgdap.ptcgai_model_package import build_model_manifest, canonical_bytes
    source = root / "data/ptcgdap/author_strategy_package_backups/reviewed-raging-bolt-ogerpon-1.0.0-round30-20ED94DE.ptcgai"
    with zipfile.ZipFile(source) as archive:
        payloads = {name: archive.read(name) for name in archive.namelist()
                    if name not in ("signature.json", "files.sha256.json", "policy/weights.bin")}
    manifest = json.loads(payloads["strategy_package.json"])
    manifest.update(document_type="strategy_package_v2", schema_version=2)
    manifest["compatibility"]["minimum_game_api"] = "ptcgdap-author-host-v2"
    manifest["compatibility"]["required_capabilities"] = ["learned_policy_head_v1"]
    manifest["policy"].update(policy_mode="rules_with_model", weights_path=None,
                              model_manifest_path="model/model_manifest.json", model_artifact_path="model/actor.ort")
    payloads["strategy_package.json"] = canonical_bytes(manifest)
    payloads["model/actor.ort"] = output.read_bytes()
    payloads["model/model_manifest.json"] = canonical_bytes(build_model_manifest(
        output.read_bytes(), model_id="test.platform-integer-fixture",
        cabt_contract_sha256=manifest["compatibility"]["cabt_contract_sha256"],
        card_catalog_sha256=manifest["compatibility"]["card_catalog_sha256"],
    ))
    # The legacy fixture builder predates optional model members. Extend its local
    # test-only kind table; the production schema and trust keys are unchanged.
    builder.OPTIONAL_PAYLOAD_KINDS.update({"model/actor.ort":"weights", "model/model_manifest.json":"json"})
    package = output.with_name("platform_model.ptcgai")
    package.write_bytes(builder.build_package_bytes(payloads, bytes(range(32)), key_id=builder.TEST_FIXTURE_KEY_ID))
    print(package)


if __name__ == "__main__":
    main()
