// Copyright (c) 2026 麦芽糖的羟基
// SPDX-License-Identifier: MIT

#pragma once

#include <d3d12.h>

#include "nvsdk_ngx.h"

#ifdef PROBE_NVNGX_EXPORTS
#define PROBE_NVNGX_API extern "C" __declspec(dllexport)
#else
#define PROBE_NVNGX_API extern "C" __declspec(dllimport)
#endif

PROBE_NVNGX_API NVSDK_NGX_Result NVSDK_CONV ProbeNvngxInitExt(
    void* function,
    unsigned long long application_id,
    const wchar_t* application_data_path,
    ID3D12Device* device,
    NVSDK_NGX_Version sdk_version,
    const NVSDK_NGX_Parameter* parameters);

PROBE_NVNGX_API NVSDK_NGX_Result NVSDK_CONV ProbeNvngxCreateFeature(
    void* function,
    ID3D12GraphicsCommandList* command_list,
    NVSDK_NGX_Feature feature,
    const NVSDK_NGX_Parameter* parameters,
    NVSDK_NGX_Handle** handle);

PROBE_NVNGX_API NVSDK_NGX_Result NVSDK_CONV ProbeNvngxReleaseFeature(
    void* function,
    NVSDK_NGX_Handle* handle);

PROBE_NVNGX_API NVSDK_NGX_Result NVSDK_CONV ProbeNvngxEvaluateFeature(
    void* function,
    ID3D12GraphicsCommandList* command_list,
    const NVSDK_NGX_Handle* handle,
    const NVSDK_NGX_Parameter* parameters,
    PFN_NVSDK_NGX_ProgressCallback callback);
