#pragma once
#include "dlss_frame.h"
#include "dlss_gpu.h"
#include "nvsdk_ngx.h"

namespace aaalice::dlss {
struct NrOptions {
  unsigned preset = 0;
  unsigned style = 0;
  float intensity = 1;
  float structure = 1;
  float tone = 1;
  float skin = -1;
  float globalTone = -1;
  bool autoMask = true;
  bool uiCorrection = false;
};

class Ngx {
 public:
  Ngx(Gpu& gpu, const std::filesystem::path& runtime,
      const std::filesystem::path& logPath);
  ~Ngx();
  Ngx(const Ngx&) = delete;
  Ngx& operator=(const Ngx&) = delete;
  Frame Upscale(Frame input, unsigned width, unsigned height);
  Frame Refine(const Frame& input, const NrOptions& options,
               const Frame* depthGuide = nullptr);

 private:
  Frame SrPass(const Frame& input, unsigned width, unsigned height);
  void SetNrParameters(NVSDK_NGX_Parameter* params, unsigned width,
                       unsigned height, const NrOptions& options);
  Gpu& gpu_;
  std::filesystem::path runtime_;
  std::filesystem::path logPath_;
  HMODULE model_ = nullptr;
  void* init_ = nullptr;
  void* create_ = nullptr;
  void* evaluate_ = nullptr;
  void* release_ = nullptr;
  bool initialized_ = false;
};
}  // namespace aaalice::dlss
