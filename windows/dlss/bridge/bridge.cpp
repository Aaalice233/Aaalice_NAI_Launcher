// Copyright (c) 2026 麦芽糖的羟基
// SPDX-License-Identifier: MIT

#define PROBE_NVNGX_EXPORTS
#include "bridge.h"

namespace {

// NR checks its caller module. A volatile result prevents tail-call optimization
// from moving that return address back into the executable in Release builds.

using InitExtFn = NVSDK_NGX_Result(NVSDK_CONV*)(
    unsigned long long,
    const wchar_t*,
    ID3D12Device*,
    NVSDK_NGX_Version,
    const NVSDK_NGX_Parameter*);

using CreateFeatureFn = NVSDK_NGX_Result(NVSDK_CONV*)(
    ID3D12GraphicsCommandList*,
    NVSDK_NGX_Feature,
    const NVSDK_NGX_Parameter*,
    NVSDK_NGX_Handle**);

using ReleaseFeatureFn =
    NVSDK_NGX_Result(NVSDK_CONV*)(NVSDK_NGX_Handle*);

using EvaluateFeatureFn = NVSDK_NGX_Result(NVSDK_CONV*)(
    ID3D12GraphicsCommandList*,
    const NVSDK_NGX_Handle*,
    const NVSDK_NGX_Parameter*,
    PFN_NVSDK_NGX_ProgressCallback);

}  // namespace

NVSDK_NGX_Result NVSDK_CONV ProbeNvngxInitExt(
    void* function,
    unsigned long long application_id,
    const wchar_t* application_data_path,
    ID3D12Device* device,
    NVSDK_NGX_Version sdk_version,
    const NVSDK_NGX_Parameter* parameters) {
    volatile NVSDK_NGX_Result result = reinterpret_cast<InitExtFn>(function)(
        application_id, application_data_path, device, sdk_version, parameters);
    return result;
}

NVSDK_NGX_Result NVSDK_CONV ProbeNvngxCreateFeature(
    void* function,
    ID3D12GraphicsCommandList* command_list,
    NVSDK_NGX_Feature feature,
    const NVSDK_NGX_Parameter* parameters,
    NVSDK_NGX_Handle** handle) {
    volatile NVSDK_NGX_Result result = reinterpret_cast<CreateFeatureFn>(function)(
        command_list, feature, parameters, handle);
    return result;
}

NVSDK_NGX_Result NVSDK_CONV ProbeNvngxReleaseFeature(
    void* function,
    NVSDK_NGX_Handle* handle) {
    volatile NVSDK_NGX_Result result = reinterpret_cast<ReleaseFeatureFn>(function)(handle);
    return result;
}

NVSDK_NGX_Result NVSDK_CONV ProbeNvngxEvaluateFeature(
    void* function,
    ID3D12GraphicsCommandList* command_list,
    const NVSDK_NGX_Handle* handle,
    const NVSDK_NGX_Parameter* parameters,
    PFN_NVSDK_NGX_ProgressCallback callback) {
    volatile NVSDK_NGX_Result result = reinterpret_cast<EvaluateFeatureFn>(function)(
        command_list, handle, parameters, callback);
    return result;
}
