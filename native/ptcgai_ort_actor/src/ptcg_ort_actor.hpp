#pragma once

#include <memory>
#include <string>
#include <vector>
#include "inference_worker.hpp"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <onnxruntime_cxx_api.h>

namespace godot {

class PtcgOrtActor : public RefCounted {
    GDCLASS(PtcgOrtActor, RefCounted)

    // Keep the extension loadable before the optional model backend is checked.
    // Members are destroyed in reverse order: session before environment.
    std::unique_ptr<Ort::Env> environment;
    std::unique_ptr<Ort::Session> session;
    // Destroy/join the worker before its session and environment.
    std::unique_ptr<ptcgai::InferenceWorker> worker;
    std::mutex invocation_mutex;

    static Dictionary error(const char *code);
    int64_t frame_width = 24;
    int64_t option_width = 16;
    bool verify_contract(std::string &failure);
    Dictionary run_unlocked(
        const PackedInt32Array &frame_i32, const PackedInt32Array &frame_presence_i32,
        const PackedInt32Array &option_i32, const PackedInt32Array &option_presence_i32,
        const PackedInt32Array &option_mask_i32, int64_t timeout_us);

protected:
    static void _bind_methods();

public:
    PtcgOrtActor();
    Dictionary get_runtime_info() const;
    Dictionary load_actor(const PackedByteArray &artifact);
    Dictionary run(
        const PackedInt32Array &frame_i32,
        const PackedInt32Array &frame_presence_i32,
        const PackedInt32Array &option_i32,
        const PackedInt32Array &option_presence_i32,
        const PackedInt32Array &option_mask_i32
    );
};

} // namespace godot
