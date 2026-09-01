cmake_minimum_required(VERSION 3.20)
project(ptcgai_ort_actor LANGUAGES CXX)

if(NOT DEFINED GODOT_CPP_ROOT)
    message(FATAL_ERROR "GODOT_CPP_ROOT must point to the pinned godot-cpp checkout")
endif()
if(NOT DEFINED ONNXRUNTIME_ROOT)
    message(FATAL_ERROR "ONNXRUNTIME_ROOT must point to an ONNX Runtime C/C++ distribution")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(GODOTCPP_TARGET template_release CACHE STRING "Godot target" FORCE)
set(GODOTCPP_PRECISION single CACHE STRING "Godot real_t precision" FORCE)
add_subdirectory("${GODOT_CPP_ROOT}" godot-cpp)

add_library(ptcgai_ort_actor SHARED
    src/ptcg_ort_actor.cpp
    src/register_types.cpp
)
target_include_directories(ptcgai_ort_actor PRIVATE
    "${ONNXRUNTIME_ROOT}/include"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
)
target_link_directories(ptcgai_ort_actor PRIVATE "${ONNXRUNTIME_ROOT}/lib")
target_link_libraries(ptcgai_ort_actor PRIVATE godot::cpp onnxruntime)
target_compile_definitions(ptcgai_ort_actor PRIVATE ORT_NO_EXCEPTIONS=0)

if(WIN32)
    set_target_properties(ptcgai_ort_actor PROPERTIES
        PREFIX ""
        OUTPUT_NAME "ptcgai_ort.windows.template_release.x86_64"
    )
elseif(APPLE)
    if(CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
        set(_ptcgai_arch "arm64")
    else()
        set(_ptcgai_arch "x86_64")
    endif()
    set_target_properties(ptcgai_ort_actor PROPERTIES
        PREFIX "lib"
        OUTPUT_NAME "ptcgai_ort.macos.template_release.${_ptcgai_arch}"
        BUILD_RPATH "@loader_path"
        INSTALL_RPATH "@loader_path"
    )
endif()
