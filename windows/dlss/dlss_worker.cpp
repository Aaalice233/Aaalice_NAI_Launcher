#include "dlss_ngx.h"

#include <algorithm>
#include <iostream>
#include <optional>
#include <stdexcept>
#include <string>

namespace {
struct Job {
  std::filesystem::path runtime, input, output, baseline, depth;
  unsigned width = 0, height = 0, adapter = 0;
  aaalice::dlss::NrOptions nr;
};
unsigned Unsigned(const std::wstring& text) {
  size_t used = 0;
  const auto value = std::stoul(text, &used);
  if (used != text.size() || text.empty() || text.front() == L'-')
    throw std::runtime_error("Invalid unsigned argument");
  return value;
}
float Strength(const std::wstring& text, float minimum = 0) {
  size_t used = 0;
  const float value = std::stof(text, &used);
  if (used != text.size() || !std::isfinite(value) || value < minimum)
    throw std::runtime_error("Invalid NR strength");
  return value;
}
Job Parse(int argc, wchar_t** argv) {
  Job job;
  for (int i = 1; i < argc; ++i) {
    const std::wstring key = argv[i];
    if (i + 1 >= argc) throw std::runtime_error("Missing argument value");
    const std::wstring value = argv[++i];
    if (key == L"--runtime") job.runtime = value;
    else if (key == L"--input") job.input = value;
    else if (key == L"--output") job.output = value;
    else if (key == L"--baseline") job.baseline = value;
    else if (key == L"--depth") job.depth = value;
    else if (key == L"--width") job.width = Unsigned(value);
    else if (key == L"--height") job.height = Unsigned(value);
    else if (key == L"--adapter") job.adapter = Unsigned(value);
    else if (key == L"--preset") job.nr.preset = Unsigned(value);
    else if (key == L"--style") job.nr.style = Unsigned(value);
    else if (key == L"--intensity") job.nr.intensity = Strength(value);
    else if (key == L"--structure") job.nr.structure = Strength(value);
    else if (key == L"--tone") job.nr.tone = Strength(value);
    else if (key == L"--skin") job.nr.skin = Strength(value, -1);
    else if (key == L"--global-tone") job.nr.globalTone = Strength(value, -1);
    else if (key == L"--auto-mask") job.nr.autoMask = Unsigned(value) != 0;
    else if (key == L"--ui-correction") job.nr.uiCorrection = Unsigned(value) != 0;
    else throw std::runtime_error("Unknown worker argument");
  }
  if (job.runtime.empty() || job.input.empty() || job.output.empty() ||
      job.baseline.empty() || job.width < 1 || job.height < 1 ||
      job.width > 16384 || job.height > 16384 || job.nr.preset > 3 || job.nr.style > 2)
    throw std::runtime_error("Invalid DLSS job parameters");
  return job;
}
}  // namespace

int wmain(int argc, wchar_t** argv) {
  try {
    const Job job = Parse(argc, argv);
    auto source = aaalice::dlss::ReadFrame(job.input);
    if (job.width < source.width || job.height < source.height)
      throw std::runtime_error("DLSS target cannot be smaller than its source");
    std::optional<aaalice::dlss::Frame> depth;
    if (!job.depth.empty()) depth = aaalice::dlss::ReadFrame(job.depth);
    aaalice::dlss::Gpu gpu(job.adapter);
    aaalice::dlss::Ngx ngx(gpu, std::filesystem::absolute(job.runtime),
                          std::filesystem::absolute(job.output).parent_path());
    std::cout << "AAALICE_NR_START" << std::endl;
    auto baseline = ngx.Upscale(std::move(source), job.width, job.height);
    aaalice::dlss::WriteFrame(job.baseline, baseline);
    auto result = ngx.Refine(baseline, job.nr, depth ? &*depth : nullptr);
    aaalice::dlss::WriteFrame(job.output, result);
    std::cout << "AAALICE_NR_DONE fp16-single" << std::endl;
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "Aaalice DLSS worker: " << error.what() << std::endl;
    return 1;
  }
}
