cmake_minimum_required(VERSION 3.20)
project(ptcgai_ort_actor LANGUAGES CXX)

set(PTCGAI_GODOT_CPP_COMMIT "58d1de720b8ffe9f8ffcdfe3a85148582cfd2e74")
set(PTCGAI_ORT_SOURCE_COMMIT "8c546c37b43caaca1fa25db430dab94b901cf277")

if(NOT DEFINED GODOT_CPP_ROOT)
    message(FATAL_ERROR "GODOT_CPP_ROOT must point to the pinned godot-cpp checkout")
endif()
if(NOT DEFINED ONNXRUNTIME_ROOT)
    message(FATAL_ERROR "ONNXRUNTIME_ROOT must point to an ONNX Runtime C/C++ distribution")
endif()

find_package(Git REQUIRED)
execute_process(COMMAND "${GIT_EXECUTABLE}" -C "${GODOT_CPP_ROOT}" rev-parse HEAD
    OUTPUT_VARIABLE _godot_cpp_commit OUTPUT_STRIP_TRAILING_WHITESPACE RESULT_VARIABLE _git_result)
if(NOT _git_result EQUAL 0 OR NOT _godot_cpp_commit STREQUAL PTCGAI_GODOT_CPP_COMMIT)
    message(FATAL_ERROR "godot-cpp must be pinned to ${PTCGAI_GODOT_CPP_COMMIT}")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(GODOTCPP_TARGET template_release CACHE STRING "Godot target" FORCE)
set(GODOTCPP_PRECISION single CACHE STRING "Godot real_t precision" FORCE)
add_subdirectory("${GODOT_CPP_ROOT}" godot-cpp)

add_library(ptcgai_ort_actor SHARED
    src/ptcg_ort_actor.cpp
    src/ort_runtime.cpp
    src/register_types.cpp
)
target_include_directories(ptcgai_ort_actor PRIVATE
    "${ONNXRUNTIME_ROOT}/include"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
)
target_link_libraries(ptcgai_ort_actor PRIVATE godot::cpp)
# ORT_NO_EXCEPTIONS must be absent, even defining it as zero makes ORT abort.
# Manual initialization also prevents any eager ORT API call at library load.
target_compile_definitions(ptcgai_ort_actor PRIVATE ORT_API_MANUAL_INIT
    PTCGAI_ORT_SOURCE_COMMIT="${PTCGAI_ORT_SOURCE_COMMIT}")

if(WIN32)
    enable_testing()
    add_executable(ptcgai_inference_worker_test tests/inference_worker_test.cpp)
    add_test(NAME inference_worker COMMAND ptcgai_inference_worker_test)
    target_link_directories(ptcgai_ort_actor PRIVATE "${ONNXRUNTIME_ROOT}/lib")
    target_link_libraries(ptcgai_ort_actor PRIVATE onnxruntime)
    set_target_properties(ptcgai_ort_actor PROPERTIES
        PREFIX ""
        OUTPUT_NAME "ptcgai_ort.windows.template_release.x86_64.v4"
    )
elseif(APPLE)
    if("arm64" IN_LIST CMAKE_OSX_ARCHITECTURES AND "x86_64" IN_LIST CMAKE_OSX_ARCHITECTURES)
        set(_ptcgai_arch "universal")
    else()
        set(_ptcgai_arch "${CMAKE_OSX_ARCHITECTURES}")
    endif()
    set_target_properties(ptcgai_ort_actor PROPERTIES
        PREFIX "lib"
        OUTPUT_NAME "ptcgai_ort.macos.template_release.${_ptcgai_arch}"
        BUILD_RPATH "@loader_path"
        INSTALL_RPATH "@loader_path"
    )
elseif(ANDROID)
    if(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
        set(_ptcgai_arch "arm64")
    elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "x86_64")
        set(_ptcgai_arch "x86_64")
    else()
        message(FATAL_ERROR "The local Android model backend requires a supported 64-bit ABI")
    endif()
    target_link_libraries(ptcgai_ort_actor PRIVATE dl)
    target_link_options(ptcgai_ort_actor PRIVATE "-Wl,-z,max-page-size=16384" "-Wl,-z,common-page-size=16384")
    set_target_properties(ptcgai_ort_actor PROPERTIES
        PREFIX "lib"
        OUTPUT_NAME "ptcgai_ort.android.template_release.${_ptcgai_arch}"
    )
else()
    message(FATAL_ERROR "This extension is shipped only on Windows, macOS and Android")
endif()
