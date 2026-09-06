#pragma once
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <vector>

namespace aaalice::dlss {
// CPU transport is linear-light RGBA float32; only GPU textures use float16.
struct Frame {
  unsigned width = 0;
  unsigned height = 0;
  std::vector<float> pixels;
};
inline Frame ReadFrame(const std::filesystem::path& path) {
  std::ifstream stream(path, std::ios::binary);
  uint32_t header[4]{};
  stream.read(reinterpret_cast<char*>(header), sizeof(header));
  if (!stream || header[0] != 0x31464141 || header[3] != 4 ||
      header[1] == 0 || header[2] == 0 || header[1] > 16384 || header[2] > 16384)
    throw std::runtime_error("Invalid AAF1 float image header");
  Frame frame{header[1], header[2], {}};
  frame.pixels.resize(static_cast<size_t>(frame.width) * frame.height * 4);
  stream.read(reinterpret_cast<char*>(frame.pixels.data()),
              static_cast<std::streamsize>(frame.pixels.size() * sizeof(float)));
  if (!stream || stream.peek() != std::char_traits<char>::eof())
    throw std::runtime_error("Invalid AAF1 float image length");
  for (float value : frame.pixels)
    if (!std::isfinite(value)) throw std::runtime_error("Non-finite input pixel");
  return frame;
}
inline void WriteFrame(const std::filesystem::path& path, const Frame& frame) {
  std::ofstream stream(path, std::ios::binary | std::ios::trunc);
  const uint32_t header[] = {0x31464141, frame.width, frame.height, 4};
  stream.write(reinterpret_cast<const char*>(header), sizeof(header));
  stream.write(reinterpret_cast<const char*>(frame.pixels.data()),
               static_cast<std::streamsize>(frame.pixels.size() * sizeof(float)));
  stream.flush();
  if (!stream) throw std::runtime_error("Failed to write AAF1 float image");
}
inline float ToSrgb(float linear) {
  return linear <= 0.0031308f ? linear * 12.92f
                            : 1.055f * std::pow(linear, 1.0f / 2.4f) - 0.055f;
}
inline float ToLinear(float srgb) {
  return srgb <= 0.04045f ? srgb / 12.92f
                         : std::pow((srgb + 0.055f) / 1.055f, 2.4f);
}
}  // namespace aaalice::dlss
