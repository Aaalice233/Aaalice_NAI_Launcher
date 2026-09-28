// Direct NR calls use the DLSS-COM bridge (MIT); see licenses/dlss/dlss-com.txt.
#include "dlss_ngx.h"
#include "bridge/bridge.h"
#include "nvsdk_ngx_helpers.h"

#include <algorithm>
#include <iostream>
#include <sstream>
#include <stdexcept>

namespace aaalice::dlss {
namespace {
void CheckNgx(NVSDK_NGX_Result result, const char* operation) {
  if (NVSDK_NGX_SUCCEED(result)) return;
  std::ostringstream message;
  message << operation << " failed: 0x" << std::hex << result;
  throw std::runtime_error(message.str());
}
struct Parameters {
  NVSDK_NGX_Parameter* value = nullptr;
  Parameters() {
    CheckNgx(NVSDK_NGX_D3D12_AllocateParameters(&value), "AllocateParameters");
  }
  ~Parameters() { if (value) NVSDK_NGX_D3D12_DestroyParameters(value); }
  Parameters(const Parameters&) = delete;
  Parameters& operator=(const Parameters&) = delete;
};
struct Feature {
  NVSDK_NGX_Handle* value = nullptr;
  void* directRelease = nullptr;
  ~Feature() {
    if (!value) return;
    if (directRelease) ProbeNvngxReleaseFeature(directRelease, value);
    else NVSDK_NGX_D3D12_ReleaseFeature(value);
  }
};
NVSDK_NGX_PerfQuality_Value Quality(unsigned inWidth, unsigned inHeight,
                                   unsigned outWidth, unsigned outHeight) {
  const double ratio = std::max(static_cast<double>(outWidth) / inWidth,
                                static_cast<double>(outHeight) / inHeight);
  if (ratio <= 1.6) return NVSDK_NGX_PerfQuality_Value_MaxQuality;
  if (ratio <= 1.85) return NVSDK_NGX_PerfQuality_Value_Balanced;
  if (ratio <= 2.5) return NVSDK_NGX_PerfQuality_Value_MaxPerf;
  return NVSDK_NGX_PerfQuality_Value_UltraPerformance;
}
}  // namespace

Ngx::Ngx(Gpu& gpu, const std::filesystem::path& runtime,
         const std::filesystem::path& logPath)
    : gpu_(gpu), runtime_(runtime), logPath_(logPath) {
  const wchar_t* paths[] = {runtime_.c_str()};
  NVSDK_NGX_FeatureCommonInfo info{};
  info.PathListInfo.Path = paths;
  info.PathListInfo.Length = 1;
  CheckNgx(NVSDK_NGX_D3D12_Init_with_ProjectID(
      "3d89c3dd-3704-4593-93ad-cdf647285ac3", NVSDK_NGX_ENGINE_TYPE_CUSTOM,
      "Aaalice-1", logPath_.c_str(), gpu_.device(), &info,
      NVSDK_NGX_Version_API), "NGX Init_with_ProjectID");
  initialized_ = true;
  model_ = LoadLibraryExW((runtime_ / "nvngx_dlssnr.dll").c_str(), nullptr,
                          LOAD_WITH_ALTERED_SEARCH_PATH);
  if (!model_) CheckHr(HRESULT_FROM_WIN32(GetLastError()), "Load NR runtime");
  init_ = reinterpret_cast<void*>(GetProcAddress(model_, "NVSDK_NGX_D3D12_Init_Ext"));
  create_ = reinterpret_cast<void*>(GetProcAddress(model_, "NVSDK_NGX_D3D12_CreateFeature"));
  evaluate_ = reinterpret_cast<void*>(GetProcAddress(model_, "NVSDK_NGX_D3D12_EvaluateFeature"));
  release_ = reinterpret_cast<void*>(GetProcAddress(model_, "NVSDK_NGX_D3D12_ReleaseFeature"));
  if (!init_ || !create_ || !evaluate_ || !release_)
    throw std::runtime_error("NR runtime is missing required entry points");
}

Ngx::~Ngx() {
  if (initialized_) NVSDK_NGX_D3D12_Shutdown1(gpu_.device());
  if (model_) FreeLibrary(model_);
}

Frame Ngx::SrPass(const Frame& input, unsigned width, unsigned height) {
  auto color = gpu_.Create(input.width, input.height, DXGI_FORMAT_R16G16B16A16_FLOAT);
  auto depth = gpu_.Create(input.width, input.height, DXGI_FORMAT_R32_FLOAT);
  auto motion = gpu_.Create(input.width, input.height, DXGI_FORMAT_R16G16_FLOAT);
  auto output = gpu_.Create(width, height, DXGI_FORMAT_R16G16B16A16_FLOAT);
  Parameters params;
  Feature feature;
  NVSDK_NGX_DLSS_Create_Params create{};
  create.Feature.InWidth = input.width;
  create.Feature.InHeight = input.height;
  create.Feature.InTargetWidth = width;
  create.Feature.InTargetHeight = height;
  create.Feature.InPerfQualityValue = Quality(input.width, input.height, width, height);
  create.InFeatureCreateFlags = NVSDK_NGX_DLSS_Feature_Flags_MVLowRes |
                                NVSDK_NGX_DLSS_Feature_Flags_AutoExposure;
  auto* commands = gpu_.Begin();
  gpu_.UploadRgba(color, input.pixels);
  gpu_.ClearGuides(depth, motion, input.width, input.height);
  gpu_.Transition(output, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
  CheckNgx(NGX_D3D12_CREATE_DLSS_EXT(commands, 1, 1, &feature.value,
                                    params.value, &create), "Create DLSS SR");
  gpu_.Submit();
  NVSDK_NGX_D3D12_DLSS_Eval_Params eval{};
  eval.Feature.pInColor = color.resource.Get();
  eval.Feature.pInOutput = output.resource.Get();
  eval.pInDepth = depth.resource.Get();
  eval.pInMotionVectors = motion.resource.Get();
  eval.InRenderSubrectDimensions.Width = input.width;
  eval.InRenderSubrectDimensions.Height = input.height;
  eval.InReset = 1;
  eval.InMVScaleX = eval.InMVScaleY = 1;
  eval.InPreExposure = eval.InExposureScale = 1;
  eval.InFrameTimeDeltaInMsec = 16.667f;
  commands = gpu_.Begin();
  CheckNgx(NGX_D3D12_EVALUATE_DLSS_EXT(commands, feature.value, params.value,
                                      &eval), "Evaluate DLSS SR");
  gpu_.Submit();
  std::cout << "SR " << input.width << 'x' << input.height << " -> "
            << width << 'x' << height << std::endl;
  return Frame{width, height, gpu_.ReadRgba(output)};
}

Frame Ngx::Upscale(Frame input, unsigned width, unsigned height) {
  // SR networks support bounded ratios per evaluation, while the requested
  // image size can be larger. Every stage remains a real SR evaluation.
  while (input.width != width || input.height != height) {
    const unsigned nextWidth = std::min(width, input.width * 3);
    const unsigned nextHeight = std::min(height, input.height * 3);
    input = SrPass(input, nextWidth, nextHeight);
  }
  return input;
}

void Ngx::SetNrParameters(NVSDK_NGX_Parameter* p, unsigned width,
                          unsigned height, const NrOptions& options) {
  p->Set("Width", width);
  p->Set("Height", height);
  p->Set("OutWidth", width);
  p->Set("OutHeight", height);
  p->Set("CreationNodeMask", 1u);
  p->Set("VisibilityNodeMask", 1u);
  p->Set("PerfQualityValue", 2u);
  p->Set("DLSSNR.Width", width);
  p->Set("DLSSNR.Height", height);
  p->Set("DLSSNR.Enabled", 1u);
  p->Set("DLSSNR.Upscaling", 0u);
  p->Set("DLSSNR.Style", options.style);
  p->Set("DLSSNR.Intensity", options.intensity);
  p->Set("DLSSNR.LocalStructureStrength", options.structure);
  p->Set("DLSSNR.LocalToneStrength", options.tone);
  if (options.skin >= 0) p->Set("DLSSNR.SkinStructureStrength", options.skin);
  p->Set("DLSSNR.UseAutoMask", options.autoMask ? 1u : 0u);
}

Frame Ngx::Refine(const Frame& input, const NrOptions& options,
                  const Frame* depthGuide) {
  if (depthGuide && (depthGuide->width != input.width || depthGuide->height != input.height))
    throw std::runtime_error("Depth guide dimensions must match the NR input");
  auto color = gpu_.Create(input.width, input.height, DXGI_FORMAT_R16G16B16A16_FLOAT);
  auto depth = gpu_.Create(input.width, input.height, DXGI_FORMAT_R32_FLOAT);
  auto motion = gpu_.Create(input.width, input.height, DXGI_FORMAT_R16G16_FLOAT);
  auto output = gpu_.Create(input.width, input.height, DXGI_FORMAT_R16G16B16A16_FLOAT);
  auto encoded = input.pixels;
  for (size_t i = 0; i < encoded.size(); ++i)
    if (i % 4 != 3) encoded[i] = ToSrgb(encoded[i]);
  auto* commands = gpu_.Begin();
  gpu_.UploadRgba(color, encoded);
  gpu_.ClearGuides(depth, motion, input.width, input.height);
  if (depthGuide) {
    std::vector<float> values(static_cast<size_t>(input.width) * input.height);
    for (size_t i = 0; i < values.size(); ++i) values[i] = depthGuide->pixels[i * 4];
    gpu_.Upload(depth, values.data(), static_cast<size_t>(input.width) * 4);
  }
  gpu_.Submit();
  // The core primes NVAPI integration for the separately loaded NR runtime.
  // Some drivers reject core feature 18 after wiring it; the direct call below
  // must independently succeed before any output can be accepted.
  {
    Parameters prime;
    Feature feature;
    SetNrParameters(prime.value, input.width, input.height, options);
    commands = gpu_.Begin();
    const auto result = NVSDK_NGX_D3D12_CreateFeature(
        commands, static_cast<NVSDK_NGX_Feature>(18), prime.value, &feature.value);
    gpu_.Submit();
    std::cout << "NR core priming: 0x" << std::hex << result << std::dec << std::endl;
  }
  Parameters initParameters;
  CheckNgx(ProbeNvngxInitExt(init_, 0x24480451ull, logPath_.c_str(), gpu_.device(),
                            NVSDK_NGX_Version_API, initParameters.value), "NR Init_Ext");
  Parameters params;
  Feature feature;
  feature.directRelease = release_;
  SetNrParameters(params.value, input.width, input.height, options);
  commands = gpu_.Begin();
  CheckNgx(ProbeNvngxCreateFeature(create_, commands,
      static_cast<NVSDK_NGX_Feature>(18), params.value, &feature.value), "Create NR feature");
  gpu_.Submit();
  params.value->Set("DLSSNR.Color", color.resource.Get());
  params.value->Set("DLSSNR.Depth", depth.resource.Get());
  params.value->Set("DLSSNR.MVec", motion.resource.Get());
  params.value->Set("DLSSNR.Output", output.resource.Get());
  params.value->Set("DLSSNR.DepthInverted", 0u);
  params.value->Set("DLSSNR.Reset", 1u);
  params.value->Set("DLSSNR.MVecScaleX", 1.0f);
  params.value->Set("DLSSNR.MVecScaleY", 1.0f);
  params.value->Set("DLSSNR.ColorSubrectWidth", input.width);
  params.value->Set("DLSSNR.ColorSubrectHeight", input.height);
  params.value->Set("DLSSNR.OutputSubrectWidth", input.width);
  params.value->Set("DLSSNR.OutputSubrectHeight", input.height);
  params.value->Set("DLSSNR.DepthSubrectWidth", input.width);
  params.value->Set("DLSSNR.DepthSubrectHeight", input.height);
  params.value->Set("DLSSNR.MVecSubrectWidth", input.width);
  params.value->Set("DLSSNR.MVecSubrectHeight", input.height);
  commands = gpu_.Begin();
  gpu_.Transition(color, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
  gpu_.Transition(output, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
  CheckNgx(ProbeNvngxEvaluateFeature(evaluate_, commands, feature.value,
                                     params.value, nullptr), "Evaluate NR");
  // Order output writes before readback even when the driver does
  // not insert its own barrier.
  gpu_.Transition(output, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
  gpu_.Submit();
  auto result = gpu_.ReadRgba(output);
  for (size_t i = 0; i < result.size(); ++i)
    if (i % 4 != 3) result[i] = ToLinear(result[i]);
  return Frame{input.width, input.height, std::move(result)};
}
}  // namespace aaalice::dlss
