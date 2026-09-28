#include <windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <wrl/client.h>

#include <iostream>
#include <sstream>
#include <string>

using Microsoft::WRL::ComPtr;

namespace {
std::string JsonString(const wchar_t* text) {
  const int size = WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0,
                                       nullptr, nullptr);
  std::string utf8(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text, -1, utf8.data(), size, nullptr, nullptr);
  std::ostringstream result;
  result << '"';
  for (const unsigned char c : utf8) {
    if (c == 0) break;
    if (c == '"' || c == '\\') result << '\\';
    if (c < 0x20) {
      const char hex[] = "0123456789abcdef";
      result << "\\u00" << hex[c >> 4] << hex[c & 15];
    } else {
      result << c;
    }
  }
  result << '"';
  return result.str();
}

std::string DriverVersion(LARGE_INTEGER version) {
  std::ostringstream value;
  value << HIWORD(version.HighPart) << '.' << LOWORD(version.HighPart)
        << '.' << HIWORD(version.LowPart) << '.' << LOWORD(version.LowPart);
  return value.str();
}
}  // namespace

int main() {
  ComPtr<IDXGIFactory1> factory;
  HRESULT hr = CreateDXGIFactory1(IID_PPV_ARGS(&factory));
  if (FAILED(hr)) {
    std::cerr << "CreateDXGIFactory1 failed: 0x" << std::hex << hr << '\n';
    return 1;
  }
  std::cout << "{\"schema\":1,\"workerVersion\":1,\"adapters\":[";
  bool first = true;
  for (UINT index = 0;; ++index) {
    ComPtr<IDXGIAdapter1> adapter;
    hr = factory->EnumAdapters1(index, &adapter);
    if (hr == DXGI_ERROR_NOT_FOUND) break;
    if (FAILED(hr)) {
      std::cerr << "EnumAdapters1 failed: 0x" << std::hex << hr << '\n';
      return 2;
    }
    DXGI_ADAPTER_DESC1 desc{};
    hr = adapter->GetDesc1(&desc);
    if (FAILED(hr)) {
      std::cerr << "GetDesc1 failed: 0x" << std::hex << hr << '\n';
      return 3;
    }
    if ((desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) != 0) continue;
    ComPtr<ID3D12Device> device;
    const HRESULT device_result = D3D12CreateDevice(
        adapter.Get(), D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&device));
    LARGE_INTEGER driver{};
    const HRESULT driver_result = adapter->CheckInterfaceSupport(
        __uuidof(IDXGIDevice), &driver);
    if (!first) std::cout << ',';
    first = false;
    std::cout << "{\"index\":" << index << ",\"name\":"
              << JsonString(desc.Description)
              << ",\"vendorId\":" << desc.VendorId
              << ",\"deviceId\":" << desc.DeviceId
              << ",\"luid\":\"" << desc.AdapterLuid.HighPart << ':'
              << desc.AdapterLuid.LowPart << "\",\"memoryBytes\":"
              << desc.DedicatedVideoMemory
              << ",\"d3d12\":" << (SUCCEEDED(device_result) ? "true" : "false")
              << ",\"d3d12Result\":" << device_result
              << ",\"driver\":";
    if (SUCCEEDED(driver_result)) {
      std::cout << '"' << DriverVersion(driver) << '"';
    } else {
      std::cout << "null";
    }
    std::cout << ",\"driverResult\":" << driver_result << '}';
  }
  std::cout << "]}\n";
  return 0;
}
