#pragma once

#include <memory>
#include <string>
#include <vector>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <onnxruntime_cxx_api.h>

namespace godot {

class PtcgOrtActor : public RefCounted {
    GDCLASS(PtcgOrtActor, RefCounted)

    Ort::Env environment;
    std::unique_ptr<Ort::Session> session;

    static Dictionary error(const char *code);
    bool verify_contract(std::string &failure) const;

protected:
    static void _bind_methods();

public:
    PtcgOrtActor();
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
