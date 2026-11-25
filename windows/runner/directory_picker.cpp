#include "directory_picker.h"

#include <objbase.h>
#include <shobjidl.h>

#include <cstdint>
#include <cstdio>
#include <cwchar>
#include <limits>
#include <string>

namespace {

template <typename T>
class ComPtr {
 public:
  ComPtr() = default;
  ~ComPtr() { Reset(); }

  ComPtr(const ComPtr&) = delete;
  ComPtr& operator=(const ComPtr&) = delete;

  void Reset() {
    if (ptr_ != nullptr) {
      ptr_->Release();
      ptr_ = nullptr;
    }
  }

  T** ReleaseAndGetAddressOf() {
    Reset();
    return &ptr_;
  }

  T* Get() const { return ptr_; }
  T* operator->() const { return ptr_; }
  explicit operator bool() const { return ptr_ != nullptr; }

 private:
  T* ptr_ = nullptr;
};

class CoTaskMemString {
 public:
  CoTaskMemString() = default;
  ~CoTaskMemString() { Reset(); }

  CoTaskMemString(const CoTaskMemString&) = delete;
  CoTaskMemString& operator=(const CoTaskMemString&) = delete;

  void Reset() {
    if (ptr_ != nullptr) {
      ::CoTaskMemFree(ptr_);
      ptr_ = nullptr;
    }
  }

  PWSTR* ReleaseAndGetAddressOf() {
    Reset();
    return &ptr_;
  }

  PWSTR Get() const { return ptr_; }
  explicit operator bool() const { return ptr_ != nullptr; }

 private:
  PWSTR ptr_ = nullptr;
};

std::string FormatHresultHex(HRESULT hr) {
  char buffer[16] = {};
  std::snprintf(buffer, sizeof(buffer), "0x%08lX",
                static_cast<unsigned long>(static_cast<uint32_t>(hr)));
  return std::string(buffer);
}

WindowsDirectoryPickResult MakeErrorResult(const char* error_code,
                                           const char* message_prefix,
                                           HRESULT hr) {
  WindowsDirectoryPickResult result;
  result.error_code = error_code;
  result.error_message =
      std::string(message_prefix) + " (" + FormatHresultHex(hr) + ")";
  return result;
}

std::string Utf8FromWide(const wchar_t* wide) {
  if (wide == nullptr || wide[0] == L'\0') {
    return std::string();
  }

  const size_t wide_length = std::wcslen(wide);
  if (wide_length > static_cast<size_t>((std::numeric_limits<int>::max)())) {
    return std::string();
  }

  const int input_length = static_cast<int>(wide_length);
  const int required = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, wide, input_length, nullptr, 0, nullptr,
      nullptr);
  if (required <= 0) {
    return std::string();
  }

  std::string utf8(static_cast<size_t>(required), '\0');
  const int written = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, wide, input_length, utf8.data(), required,
      nullptr, nullptr);
  if (written != required) {
    return std::string();
  }

  return utf8;
}

}  // namespace

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty() ||
      utf8.size() > static_cast<size_t>((std::numeric_limits<int>::max)())) {
    return std::wstring();
  }

  const int input_length = static_cast<int>(utf8.size());
  DWORD flags = MB_ERR_INVALID_CHARS;
  int required = ::MultiByteToWideChar(CP_UTF8, flags, utf8.data(),
                                       input_length, nullptr, 0);
  if (required <= 0) {
    flags = 0;
    required = ::MultiByteToWideChar(CP_UTF8, flags, utf8.data(), input_length,
                                     nullptr, 0);
    if (required <= 0) {
      return std::wstring();
    }
  }

  std::wstring wide(static_cast<size_t>(required), L'\0');
  const int written = ::MultiByteToWideChar(
      CP_UTF8, flags, utf8.data(), input_length, wide.data(), required);
  if (written != required) {
    return std::wstring();
  }

  return wide;
}

WindowsDirectoryPickResult PickDirectoryOnWindowThread(
    HWND owner,
    const std::wstring& dialog_title) {
  // 主线程已在 wWinMain 初始化 STA COM，此处直接复用避免失配 CoUninitialize。
  ComPtr<IFileOpenDialog> dialog;
  HRESULT hr = ::CoCreateInstance(
      CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
      IID_PPV_ARGS(dialog.ReleaseAndGetAddressOf()));
  if (FAILED(hr) || !dialog) {
    return MakeErrorResult("directory_picker_create_failed",
                           "Unable to create the Windows directory picker dialog.",
                           hr);
  }

  DWORD options = 0;
  hr = dialog->GetOptions(&options);
  if (FAILED(hr)) {
    return MakeErrorResult("directory_picker_options_failed",
                           "Unable to read directory picker options.", hr);
  }

  options |= FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM | FOS_NOCHANGEDIR;
  hr = dialog->SetOptions(options);
  if (FAILED(hr)) {
    return MakeErrorResult("directory_picker_options_failed",
                           "Unable to configure directory picker options.", hr);
  }

  if (!dialog_title.empty()) {
    hr = dialog->SetTitle(dialog_title.c_str());
    if (FAILED(hr)) {
      return MakeErrorResult("directory_picker_title_failed",
                             "Unable to set the directory picker dialog title.",
                             hr);
    }
  }

  hr = dialog->Show(owner);
  if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    WindowsDirectoryPickResult cancelled;
    cancelled.cancelled = true;
    return cancelled;
  }
  if (FAILED(hr)) {
    return MakeErrorResult("directory_picker_show_failed",
                           "Unable to display the Windows directory picker.",
                           hr);
  }

  ComPtr<IShellItem> item;
  hr = dialog->GetResult(item.ReleaseAndGetAddressOf());
  if (FAILED(hr)) {
    return MakeErrorResult("directory_picker_result_failed",
                           "Unable to read the selected directory item.", hr);
  }
  if (!item) {
    WindowsDirectoryPickResult cancelled;
    cancelled.cancelled = true;
    return cancelled;
  }

  CoTaskMemString raw_path;
  hr = item->GetDisplayName(SIGDN_FILESYSPATH,
                            raw_path.ReleaseAndGetAddressOf());
  if (FAILED(hr)) {
    return MakeErrorResult("directory_picker_path_failed",
                           "Unable to resolve the selected directory path.",
                           hr);
  }
  if (!raw_path) {
    WindowsDirectoryPickResult cancelled;
    cancelled.cancelled = true;
    return cancelled;
  }

  const std::string utf8_path = Utf8FromWide(raw_path.Get());
  if (utf8_path.empty()) {
    WindowsDirectoryPickResult encoding_error;
    encoding_error.error_code = "directory_picker_encoding_failed";
    encoding_error.error_message =
        "Unable to encode the selected directory path as UTF-8.";
    return encoding_error;
  }

  WindowsDirectoryPickResult success;
  success.succeeded = true;
  success.path = utf8_path;
  return success;
}
