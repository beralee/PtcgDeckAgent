#pragma once

#include <string>

namespace ptcgai {

struct OrtRuntimeInfo {
    bool available = false;
    bool library_loaded = false;
    std::string error_code;
    std::string version;
};

// Initializes only the C API on first use. The bundled library deliberately
// remains loaded for process lifetime, including after the last actor is freed.
const OrtRuntimeInfo &get_ort_runtime();

} // namespace ptcgai
