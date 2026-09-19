#include "ort_runtime.hpp"

#include <cstdlib>
#include <cstdio>
#include <mutex>
#include <onnxruntime_cxx_api.h>

#if defined(__APPLE__) || defined(__ANDROID__)
#include <dlfcn.h>
#endif
#if defined(__APPLE__)
#include <sys/sysctl.h>
#elif defined(__ANDROID__)
#include <sys/system_properties.h>
#endif

namespace ptcgai {
namespace {

bool platform_supported() {
#if defined(__APPLE__)
    char version[64] = {};
    size_t size = sizeof(version);
    // sysctl is available on the game's old macOS floor. Do not call an API
    // whose strong import would make the small extension itself require 13.3.
    if (sysctlbyname("kern.osproductversion", version, &size, nullptr, 0) != 0) {
        return false;
    }
    int major = 0;
    int minor = 0;
    return std::sscanf(version, "%d.%d", &major, &minor) >= 1 &&
        (major > 13 || (major == 13 && minor >= 3));
#elif defined(__ANDROID__)
    char api[PROP_VALUE_MAX] = {};
    return __system_property_get("ro.build.version.sdk", api) > 0 && std::atoi(api) >= 29;
#elif defined(_WIN32) && defined(_WIN64)
    return true;
#else
    return false;
#endif
}

#if defined(__APPLE__) || defined(__ANDROID__)
const OrtApiBase *load_bundled_api(OrtRuntimeInfo &info) {
    Dl_info extension = {};
    if (dladdr(reinterpret_cast<const void *>(&get_ort_runtime), &extension) == 0 || !extension.dli_fname) {
        info.error_code = "model_runtime_library_missing";
        return nullptr;
    }
    const std::string own_path(extension.dli_fname);
    const size_t slash = own_path.find_last_of('/');
    if (slash == std::string::npos || own_path.empty() || own_path.front() != '/') {
        info.error_code = "model_runtime_library_missing";
        return nullptr;
    }
#if defined(__APPLE__)
    const char *library_name = "libonnxruntime.dylib";
#else
    const char *library_name = "libonnxruntime.so";
#endif
    // Android also supports the absolute APK !/lib/... path returned by dladdr.
    // Never search PATH, an author's archive, or an untrusted working directory.
    const std::string library_path = own_path.substr(0, slash + 1) + library_name;
    void *library = dlopen(library_path.c_str(), RTLD_NOW | RTLD_LOCAL);
    if (!library) {
        info.error_code = "model_runtime_library_missing";
        return nullptr;
    }
    info.library_loaded = true;
    using GetApiBase = const OrtApiBase *(ORT_API_CALL *)();
    auto get_api_base = reinterpret_cast<GetApiBase>(dlsym(library, "OrtGetApiBase"));
    if (!get_api_base) {
        info.error_code = "model_runtime_api_incompatible";
        return nullptr;
    }
    return get_api_base();
}
#endif

} // namespace

const OrtRuntimeInfo &get_ort_runtime() {
    static OrtRuntimeInfo info;
    static std::once_flag initialized;
    std::call_once(initialized, []() {
        if (!platform_supported()) {
            info.error_code = "model_platform_not_supported";
            return;
        }
        const OrtApiBase *base = nullptr;
#if defined(__APPLE__) || defined(__ANDROID__)
        base = load_bundled_api(info);
#elif defined(_WIN32)
        base = OrtGetApiBase();
        info.library_loaded = true;
#endif
        if (!base) {
            if (info.error_code.empty()) {
                info.error_code = "model_runtime_api_incompatible";
            }
            return;
        }
        const OrtApi *api = base->GetApi(ORT_API_VERSION);
        if (!api) {
            info.error_code = "model_runtime_api_incompatible";
            return;
        }
        Ort::InitApi(api);
        info.version = base->GetVersionString();
        info.available = true;
    });
    return info;
}

} // namespace ptcgai
