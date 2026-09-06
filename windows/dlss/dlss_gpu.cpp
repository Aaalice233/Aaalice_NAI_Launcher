// Texture transfer layout adapted from MYT-YEP/DLSS-COM (MIT).
// Copyright (c) 2026 麦芽糖的羟基. See licenses/dlss/dlss-com.txt.
#include "dlss_gpu.h"
#include <DirectXPackedVector.h>

#include <cstring>
#include <sstream>
#include <stdexcept>

namespace aaalice::dlss {
void CheckHr(HRESULT result, const char* operation) {
  if (SUCCEEDED(result)) return;
  std::ostringstream message;
  message << operation << " failed: 0x" << std::hex << result;
  throw std::runtime_error(message.str());
}

Gpu::Gpu(unsigned adapterIndex) {
  ComPtr<IDXGIFactory1> factory;
  CheckHr(CreateDXGIFactory1(IID_PPV_ARGS(&factory)), "CreateDXGIFactory1");
  ComPtr<IDXGIAdapter1> adapter;
  CheckHr(factory->EnumAdapters1(adapterIndex, &adapter), "EnumAdapters1");
  CheckHr(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_12_0,
                           IID_PPV_ARGS(&device_)), "D3D12CreateDevice");
  D3D12_COMMAND_QUEUE_DESC description{};
  description.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
  CheckHr(device_->CreateCommandQueue(&description, IID_PPV_ARGS(&queue_)),
          "CreateCommandQueue");
  CheckHr(device_->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT,
                                          IID_PPV_ARGS(&allocator_)),
          "CreateCommandAllocator");
  CheckHr(device_->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                     allocator_.Get(), nullptr,
                                     IID_PPV_ARGS(&commands_)), "CreateCommandList");
  CheckHr(commands_->Close(), "Close initial command list");
  CheckHr(device_->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&fence_)),
          "CreateFence");
  event_ = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  if (!event_) CheckHr(HRESULT_FROM_WIN32(GetLastError()), "CreateEventW");
}

Gpu::~Gpu() {
  if (event_) CloseHandle(event_);
}

ID3D12GraphicsCommandList* Gpu::Begin() {
  CheckHr(allocator_->Reset(), "Reset allocator");
  CheckHr(commands_->Reset(allocator_.Get(), nullptr), "Reset command list");
  return commands_.Get();
}

void Gpu::Submit() {
  CheckHr(commands_->Close(), "Close command list");
  ID3D12CommandList* lists[] = {commands_.Get()};
  queue_->ExecuteCommandLists(1, lists);
  const UINT64 target = ++sequence_;
  CheckHr(queue_->Signal(fence_.Get(), target), "Signal GPU fence");
  if (fence_->GetCompletedValue() < target) {
    CheckHr(fence_->SetEventOnCompletion(target, event_), "SetEventOnCompletion");
    const DWORD status = WaitForSingleObject(event_, 90000);
    if (status != WAIT_OBJECT_0) {
      CheckHr(device_->GetDeviceRemovedReason(), "GPU device removed");
      throw std::runtime_error("GPU fence wait failed or timed out: " +
                               std::to_string(status));
    }
  }
  CheckHr(device_->GetDeviceRemovedReason(), "GPU device removed");
  transfers_.clear();
}

Texture Gpu::Create(unsigned width, unsigned height, DXGI_FORMAT format) {
  D3D12_HEAP_PROPERTIES heap{};
  heap.Type = D3D12_HEAP_TYPE_DEFAULT;
  heap.CreationNodeMask = heap.VisibleNodeMask = 1;
  D3D12_RESOURCE_DESC desc{};
  desc.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
  desc.Width = width;
  desc.Height = height;
  desc.DepthOrArraySize = desc.MipLevels = 1;
  desc.Format = format;
  desc.SampleDesc.Count = 1;
  desc.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;
  Texture texture;
  CheckHr(device_->CreateCommittedResource(
      &heap, D3D12_HEAP_FLAG_NONE, &desc, texture.state, nullptr,
      IID_PPV_ARGS(&texture.resource)), "Create GPU texture");
  return texture;
}

ComPtr<ID3D12Resource> Gpu::Buffer(UINT64 bytes, D3D12_HEAP_TYPE type) {
  D3D12_HEAP_PROPERTIES heap{};
  heap.Type = type;
  heap.CreationNodeMask = heap.VisibleNodeMask = 1;
  D3D12_RESOURCE_DESC desc{};
  desc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
  desc.Width = bytes;
  desc.Height = 1;
  desc.DepthOrArraySize = desc.MipLevels = 1;
  desc.SampleDesc.Count = 1;
  desc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
  ComPtr<ID3D12Resource> buffer;
  CheckHr(device_->CreateCommittedResource(
      &heap, D3D12_HEAP_FLAG_NONE, &desc,
      type == D3D12_HEAP_TYPE_UPLOAD ? D3D12_RESOURCE_STATE_GENERIC_READ
                                   : D3D12_RESOURCE_STATE_COPY_DEST,
      nullptr, IID_PPV_ARGS(&buffer)), "Create transfer buffer");
  return buffer;
}

void Gpu::Transition(Texture& texture, D3D12_RESOURCE_STATES state) {
  if (texture.state == state) return;
  D3D12_RESOURCE_BARRIER barrier{};
  barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
  barrier.Transition.pResource = texture.resource.Get();
  barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
  barrier.Transition.StateBefore = texture.state;
  barrier.Transition.StateAfter = state;
  commands_->ResourceBarrier(1, &barrier);
  texture.state = state;
}

void Gpu::Upload(Texture& texture, const void* bytes, size_t rowBytes) {
  const auto desc = texture.resource->GetDesc();
  D3D12_PLACED_SUBRESOURCE_FOOTPRINT footprint{};
  UINT64 size = 0;
  device_->GetCopyableFootprints(&desc, 0, 1, 0, &footprint, nullptr, nullptr, &size);
  auto buffer = Buffer(size, D3D12_HEAP_TYPE_UPLOAD);
  void* mapped = nullptr;
  const D3D12_RANGE noRead{0, 0};
  CheckHr(buffer->Map(0, &noRead, &mapped), "Map upload");
  for (unsigned y = 0; y < desc.Height; ++y) {
    std::memcpy(static_cast<uint8_t*>(mapped) + footprint.Offset +
                    static_cast<size_t>(y) * footprint.Footprint.RowPitch,
                static_cast<const uint8_t*>(bytes) + y * rowBytes, rowBytes);
  }
  buffer->Unmap(0, nullptr);
  Transition(texture, D3D12_RESOURCE_STATE_COPY_DEST);
  D3D12_TEXTURE_COPY_LOCATION destination{};
  destination.pResource = texture.resource.Get();
  destination.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
  D3D12_TEXTURE_COPY_LOCATION source{};
  source.pResource = buffer.Get();
  source.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;
  source.PlacedFootprint = footprint;
  commands_->CopyTextureRegion(&destination, 0, 0, 0, &source, nullptr);
  Transition(texture, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
  transfers_.push_back(buffer);
}

void Gpu::UploadRgba(Texture& texture, const std::vector<float>& values) {
  std::vector<uint16_t> half(values.size());
  for (size_t i = 0; i < values.size(); ++i)
    half[i] = DirectX::PackedVector::XMConvertFloatToHalf(values[i]);
  Upload(texture, half.data(), static_cast<size_t>(texture.resource->GetDesc().Width) * 8);
}

void Gpu::ClearGuides(Texture& depth, Texture& motion, unsigned width, unsigned height) {
  const std::vector<float> zeros(static_cast<size_t>(width) * height, 0.0f);
  Upload(depth, zeros.data(), static_cast<size_t>(width) * 4);
  Upload(motion, zeros.data(), static_cast<size_t>(width) * 4);
}

std::vector<float> Gpu::ReadRgba(Texture& texture) {
  const auto desc = texture.resource->GetDesc();
  D3D12_PLACED_SUBRESOURCE_FOOTPRINT footprint{};
  UINT64 bytes = 0;
  device_->GetCopyableFootprints(&desc, 0, 1, 0, &footprint, nullptr, nullptr, &bytes);
  auto buffer = Buffer(bytes, D3D12_HEAP_TYPE_READBACK);
  Begin();
  Transition(texture, D3D12_RESOURCE_STATE_COPY_SOURCE);
  D3D12_TEXTURE_COPY_LOCATION source{};
  source.pResource = texture.resource.Get();
  source.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
  D3D12_TEXTURE_COPY_LOCATION destination{};
  destination.pResource = buffer.Get();
  destination.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;
  destination.PlacedFootprint = footprint;
  commands_->CopyTextureRegion(&destination, 0, 0, 0, &source, nullptr);
  Submit();
  const D3D12_RANGE readRange{0, static_cast<SIZE_T>(bytes)};
  void* mapped = nullptr;
  CheckHr(buffer->Map(0, &readRange, &mapped), "Map readback");
  std::vector<float> output(static_cast<size_t>(desc.Width) * desc.Height * 4);
  for (unsigned y = 0; y < desc.Height; ++y) {
    const auto* row = reinterpret_cast<const uint16_t*>(
        static_cast<const uint8_t*>(mapped) + footprint.Offset +
        static_cast<size_t>(y) * footprint.Footprint.RowPitch);
    for (size_t x = 0; x < desc.Width * 4; ++x)
      output[(y * desc.Width * 4) + x] = DirectX::PackedVector::XMConvertHalfToFloat(row[x]);
  }
  const D3D12_RANGE noWrite{0, 0};
  buffer->Unmap(0, &noWrite);
  return output;
}
}  // namespace aaalice::dlss
