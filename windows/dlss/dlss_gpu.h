#pragma once
#define NOMINMAX
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <wrl/client.h>

#include <cstdint>
#include <string>
#include <vector>

namespace aaalice::dlss {
using Microsoft::WRL::ComPtr;
void CheckHr(HRESULT result, const char* operation);

struct Texture {
  ComPtr<ID3D12Resource> resource;
  D3D12_RESOURCE_STATES state = D3D12_RESOURCE_STATE_COMMON;
};

// One command queue owns all layers; transfers retain their buffers until its
// fence completes. No layer is downloaded or quantized between evaluations.
class Gpu {
 public:
  explicit Gpu(unsigned adapter);
  ~Gpu();
  Gpu(const Gpu&) = delete;
  Gpu& operator=(const Gpu&) = delete;
  ID3D12Device* device() const { return device_.Get(); }
  ID3D12GraphicsCommandList* Begin();
  void Submit();
  Texture Create(unsigned width, unsigned height, DXGI_FORMAT format);
  void Transition(Texture& texture, D3D12_RESOURCE_STATES state);
  void Upload(Texture& texture, const void* bytes, size_t rowBytes);
  std::vector<float> ReadRgba(Texture& texture);
  void UploadRgba(Texture& texture, const std::vector<float>& values);
  void ClearGuides(Texture& depth, Texture& motion, unsigned width, unsigned height);

 private:
  ComPtr<ID3D12Resource> Buffer(UINT64 bytes, D3D12_HEAP_TYPE heap);
  ComPtr<ID3D12Device> device_;
  ComPtr<ID3D12CommandQueue> queue_;
  ComPtr<ID3D12CommandAllocator> allocator_;
  ComPtr<ID3D12GraphicsCommandList> commands_;
  ComPtr<ID3D12Fence> fence_;
  HANDLE event_ = nullptr;
  UINT64 sequence_ = 0;
  std::vector<ComPtr<ID3D12Resource>> transfers_;
};
}  // namespace aaalice::dlss
