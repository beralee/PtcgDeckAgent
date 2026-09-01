#include "ptcg_ort_actor.hpp"

#include <array>
#include <chrono>
#include <cstring>
#include <future>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>

namespace godot {

namespace {
constexpr size_t kMaxArtifactBytes = 8U * 1024U * 1024U;
constexpr int64_t kFrameWidth = 24;
constexpr int64_t kMaxOptions = 1024;
constexpr int64_t kOptionWidth = 16;
constexpr int64_t kTimeoutMicroseconds = 25000;

struct IoSpec {
    const char *name;
    std::vector<int64_t> shape;
};

const std::array<IoSpec, 5> kInputs{{
    {"frame_i32", {1, kFrameWidth}},
    {"frame_presence_i32", {1, kFrameWidth}},
    {"option_i32", {1, kMaxOptions, kOptionWidth}},
    {"option_presence_i32", {1, kMaxOptions, kOptionWidth}},
    {"option_mask_i32", {1, kMaxOptions}},
}};
const std::array<IoSpec, 2> kOutputs{{
    {"option_scores", {1, kMaxOptions}},
    {"desired_count", {1}},
}};

template <size_t N>
bool verify_io(const Ort::Session &session, const std::array<IoSpec, N> &expected, bool input, std::string &failure) {
    Ort::AllocatorWithDefaultOptions allocator;
    const size_t count = input ? session.GetInputCount() : session.GetOutputCount();
    if (count != expected.size()) {
        failure = "model_tensor_profile_invalid";
        return false;
    }
    for (size_t index = 0; index < count; ++index) {
        auto name = input ? session.GetInputNameAllocated(index, allocator) : session.GetOutputNameAllocated(index, allocator);
        if (std::strcmp(name.get(), expected[index].name) != 0) {
            failure = "model_tensor_profile_invalid";
            return false;
        }
        Ort::TypeInfo type = input ? session.GetInputTypeInfo(index) : session.GetOutputTypeInfo(index);
        auto tensor = type.GetTensorTypeAndShapeInfo();
        if (tensor.GetElementType() != ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32 || tensor.GetShape() != expected[index].shape) {
            failure = "model_tensor_profile_invalid";
            return false;
        }
    }
    return true;
}

std::vector<int32_t> copy_values(const PackedInt32Array &source) {
    const int32_t *data = source.ptr();
    return std::vector<int32_t>(data, data + source.size());
}
} // namespace

PtcgOrtActor::PtcgOrtActor() : environment(ORT_LOGGING_LEVEL_ERROR, "ptcgai_actor") {}

void PtcgOrtActor::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load_actor", "artifact"), &PtcgOrtActor::load_actor);
    ClassDB::bind_method(
        D_METHOD("run", "frame_i32", "frame_presence_i32", "option_i32", "option_presence_i32", "option_mask_i32"),
        &PtcgOrtActor::run
    );
}

Dictionary PtcgOrtActor::error(const char *code) {
    Dictionary result;
    result["ok"] = false;
    result["error_code"] = String(code);
    return result;
}

bool PtcgOrtActor::verify_contract(std::string &failure) const {
    return session && verify_io(*session, kInputs, true, failure) && verify_io(*session, kOutputs, false, failure);
}

Dictionary PtcgOrtActor::load_actor(const PackedByteArray &artifact) {
    session.reset();
    if (artifact.is_empty() || static_cast<size_t>(artifact.size()) > kMaxArtifactBytes) {
        return error("model_resource_limit_exceeded");
    }
    try {
        Ort::SessionOptions options;
        options.SetIntraOpNumThreads(1);
        options.SetInterOpNumThreads(1);
        options.SetExecutionMode(ExecutionMode::ORT_SEQUENTIAL);
        options.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_BASIC);
        options.DisableMemPattern();
        session = std::make_unique<Ort::Session>(environment, artifact.ptr(), static_cast<size_t>(artifact.size()), options);
        std::string failure;
        if (!verify_contract(failure)) {
            session.reset();
            return error(failure.c_str());
        }
    } catch (const Ort::Exception &) {
        session.reset();
        return error("model_unavailable");
    } catch (...) {
        session.reset();
        return error("model_unavailable");
    }
    Dictionary result;
    result["ok"] = true;
    result["error_code"] = "";
    result["runtime"] = "onnxruntime";
    result["execution_provider"] = "CPUExecutionProvider";
    return result;
}

Dictionary PtcgOrtActor::run(
    const PackedInt32Array &frame_i32,
    const PackedInt32Array &frame_presence_i32,
    const PackedInt32Array &option_i32,
    const PackedInt32Array &option_presence_i32,
    const PackedInt32Array &option_mask_i32
) {
    if (!session) {
        return error("model_unavailable");
    }
    if (frame_i32.size() != kFrameWidth || frame_presence_i32.size() != kFrameWidth ||
        option_i32.size() != kMaxOptions * kOptionWidth || option_presence_i32.size() != kMaxOptions * kOptionWidth ||
        option_mask_i32.size() != kMaxOptions) {
        return error("model_tensor_profile_invalid");
    }
    try {
        auto frame = copy_values(frame_i32);
        auto frame_presence = copy_values(frame_presence_i32);
        auto options = copy_values(option_i32);
        auto option_presence = copy_values(option_presence_i32);
        auto mask = copy_values(option_mask_i32);
        Ort::MemoryInfo memory = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
        const std::array<int64_t, 2> frame_shape{1, kFrameWidth};
        const std::array<int64_t, 3> option_shape{1, kMaxOptions, kOptionWidth};
        const std::array<int64_t, 2> mask_shape{1, kMaxOptions};
        std::array<Ort::Value, 5> inputs{
            Ort::Value::CreateTensor<int32_t>(memory, frame.data(), frame.size(), frame_shape.data(), frame_shape.size()),
            Ort::Value::CreateTensor<int32_t>(memory, frame_presence.data(), frame_presence.size(), frame_shape.data(), frame_shape.size()),
            Ort::Value::CreateTensor<int32_t>(memory, options.data(), options.size(), option_shape.data(), option_shape.size()),
            Ort::Value::CreateTensor<int32_t>(memory, option_presence.data(), option_presence.size(), option_shape.data(), option_shape.size()),
            Ort::Value::CreateTensor<int32_t>(memory, mask.data(), mask.size(), mask_shape.data(), mask_shape.size()),
        };
        const std::array<const char *, 5> input_names{"frame_i32", "frame_presence_i32", "option_i32", "option_presence_i32", "option_mask_i32"};
        const std::array<const char *, 2> output_names{"option_scores", "desired_count"};
        const auto started = std::chrono::steady_clock::now();
        Ort::RunOptions run_options;
        auto inference = std::async(std::launch::async, [&]() {
            return session->Run(
                run_options,
                input_names.data(),
                inputs.data(),
                inputs.size(),
                output_names.data(),
                output_names.size()
            );
        });
        if (inference.wait_for(std::chrono::microseconds(kTimeoutMicroseconds)) == std::future_status::timeout) {
            run_options.SetTerminate();
            try {
                inference.get();
            } catch (...) {
                // Cancellation is expected to surface as an ORT exception.
            }
            return error("model_timeout");
        }
        auto outputs = inference.get();
        const auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - started).count();
        if (elapsed > kTimeoutMicroseconds) {
            return error("model_timeout");
        }
        if (outputs.size() != 2 || !outputs[0].IsTensor() || !outputs[1].IsTensor()) {
            return error("model_output_shape_invalid");
        }
        auto score_info = outputs[0].GetTensorTypeAndShapeInfo();
        auto count_info = outputs[1].GetTensorTypeAndShapeInfo();
        if (score_info.GetElementType() != ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32 || score_info.GetShape() != kOutputs[0].shape ||
            count_info.GetElementType() != ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32 || count_info.GetShape() != kOutputs[1].shape) {
            return error("model_output_shape_invalid");
        }
        const int32_t *score_data = outputs[0].GetTensorData<int32_t>();
        const int32_t *count_data = outputs[1].GetTensorData<int32_t>();
        PackedInt32Array scores;
        scores.resize(kMaxOptions);
        std::memcpy(scores.ptrw(), score_data, sizeof(int32_t) * kMaxOptions);
        Dictionary result;
        result["ok"] = true;
        result["error_code"] = "";
        result["option_scores"] = scores;
        result["desired_count"] = count_data[0];
        result["elapsed_us"] = static_cast<int64_t>(elapsed);
        return result;
    } catch (const Ort::Exception &) {
        return error("model_inference_failed");
    } catch (...) {
        return error("model_inference_failed");
    }
}

} // namespace godot
