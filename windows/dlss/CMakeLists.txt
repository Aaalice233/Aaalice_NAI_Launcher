cmake_minimum_required(VERSION 3.14)
project(aaalice_dlss_probe LANGUAGES CXX)

add_executable(aaalice_dlss_probe dlss_probe.cpp)
target_compile_features(aaalice_dlss_probe PRIVATE cxx_std_17)
target_compile_definitions(aaalice_dlss_probe PRIVATE UNICODE _UNICODE)
target_compile_options(aaalice_dlss_probe PRIVATE /W4 /WX /EHsc)
target_link_libraries(aaalice_dlss_probe PRIVATE dxgi d3d12)
set_property(TARGET aaalice_dlss_probe PROPERTY
  MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
