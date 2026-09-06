cmake_minimum_required(VERSION 3.15)
project(aaalice_dlss_probe LANGUAGES CXX)

add_executable(aaalice_dlss_probe dlss_probe.cpp)
target_compile_features(aaalice_dlss_probe PRIVATE cxx_std_17)
target_compile_definitions(aaalice_dlss_probe PRIVATE UNICODE _UNICODE)
target_compile_options(aaalice_dlss_probe PRIVATE /W4 /WX /EHsc)
target_link_libraries(aaalice_dlss_probe PRIVATE dxgi d3d12)
set_property(TARGET aaalice_dlss_probe PROPERTY
  MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

include(ngx_sdk.cmake)
add_library(aaalice_nr_bridge SHARED bridge/bridge.cpp)
# Feature 18 resolves its caller module; keep the documented NGX module name.
set_target_properties(aaalice_nr_bridge PROPERTIES OUTPUT_NAME "aaalice_nvngx")
target_include_directories(aaalice_nr_bridge PRIVATE "${AAALICE_NGX_SDK}/include")
target_compile_options(aaalice_nr_bridge PRIVATE /W4 /EHsc /Ob0)
target_compile_definitions(aaalice_nr_bridge PRIVATE UNICODE _UNICODE)
set_property(TARGET aaalice_nr_bridge PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded")

add_executable(aaalice_dlss_worker dlss_worker.cpp dlss_gpu.cpp dlss_ngx.cpp)
target_compile_features(aaalice_dlss_worker PRIVATE cxx_std_17)
target_include_directories(aaalice_dlss_worker PRIVATE "${AAALICE_NGX_SDK}/include")
target_compile_definitions(aaalice_dlss_worker PRIVATE UNICODE _UNICODE)
target_compile_options(aaalice_dlss_worker PRIVATE /W4 /WX /EHsc /U_DEBUG)
target_link_libraries(aaalice_dlss_worker PRIVATE aaalice_nr_bridge
  "${AAALICE_NGX_SDK}/lib/nvsdk_ngx_khr_s.lib" d3d12 dxgi advapi32 user32)
set_property(TARGET aaalice_dlss_worker PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded")
