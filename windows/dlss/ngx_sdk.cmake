# Build inputs are pinned independently of the user's downloadable model bundle.
set(AAALICE_NGX_REVISION "a291cc7d2cc642a51566f3dfd5376f635cd1b284")
set(AAALICE_NGX_SDK "${CMAKE_CURRENT_BINARY_DIR}/ngx-sdk")
function(aaalice_ngx_input remote local sha256)
  set(output "${AAALICE_NGX_SDK}/${local}")
  if(EXISTS "${output}")
    file(SHA256 "${output}" actual)
    if(actual STREQUAL sha256)
      return()
    endif()
  endif()
  get_filename_component(parent "${output}" DIRECTORY)
  file(MAKE_DIRECTORY "${parent}")
  file(DOWNLOAD
    "https://raw.githubusercontent.com/NVIDIA/DLSS/${AAALICE_NGX_REVISION}/${remote}"
    "${output}" EXPECTED_HASH "SHA256=${sha256}" TLS_VERIFY ON
    TIMEOUT 120 STATUS download_status)
  list(GET download_status 0 status_code)
  if(NOT status_code EQUAL 0)
    message(FATAL_ERROR "NGX SDK download failed: ${remote}: ${download_status}")
  endif()
endfunction()
aaalice_ngx_input("include/nvsdk_ngx.h" "include/nvsdk_ngx.h"
  "f6014a256f9d75ccec1278ac6e23d596b398a76cc3960048ca1a274b378b1989")
aaalice_ngx_input("include/nvsdk_ngx_defs.h" "include/nvsdk_ngx_defs.h"
  "ea23f33497cd274860d1c25a97644fce807dcb0037c594547203343103fad03e")
aaalice_ngx_input("include/nvsdk_ngx_params.h" "include/nvsdk_ngx_params.h"
  "943bc8cc5cdae03b6303016fbad3183636f2335ae27a2d18776798c3b4efabbc")
aaalice_ngx_input("include/nvsdk_ngx_helpers.h" "include/nvsdk_ngx_helpers.h"
  "2d5661f8b5ab55e1223e485f24146274d48077e09051873826b653d4384fe7d8")
aaalice_ngx_input("lib/Windows_x86_64/khr/x64/nvsdk_ngx_khr_s.lib" "lib/nvsdk_ngx_khr_s.lib"
  "2534d5fb31a38a7b37b11869272915d1f18c4b484ffd61a0b36956bab9ab739e")
aaalice_ngx_input("LICENSE.txt" "LICENSE.txt"
  "21b5daec892b12bea692e66bc8fe45cf5902ccaf3a7b831e78050d8859881c37")
