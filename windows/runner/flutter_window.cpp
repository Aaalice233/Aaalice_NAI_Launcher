#include "flutter_window.h"

#include <optional>
#include <set>
#include <string>
#include <vector>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include "flutter/generated_plugin_registrant.h"

// Global set to store font names
static std::set<std::wstring> g_font_names;

// Font enumeration callback function
int CALLBACK EnumFontFamExProc(
    const LOGFONTW* lpelfe,
    const TEXTMETRICW* lpntme,
    DWORD FontType,
    LPARAM lParam) {
  // Skip vertical fonts (starting with @)
  if (lpelfe->lfFaceName[0] != L'@') {
    g_font_names.insert(lpelfe->lfFaceName);
  }
  return 1; // Continue enumeration
}

// Get system font list
std::optional<std::vector<std::string>> GetSystemFonts(
    std::string* error_message) {
  g_font_names.clear();

  HDC hdc = GetDC(NULL);
  if (hdc == NULL) {
    *error_message = "Failed to acquire the Windows screen device context.";
    return std::nullopt;
  }

  LOGFONTW lf = {};
  lf.lfCharSet = DEFAULT_CHARSET;
  lf.lfFaceName[0] = L'\0';

  // The return value is callback-controlled and does not distinguish an empty
  // enumeration from failure.
  EnumFontFamiliesExW(hdc, &lf, EnumFontFamExProc, 0, 0);
  if (ReleaseDC(NULL, hdc) == 0) {
    *error_message = "Failed to release the Windows screen device context.";
    return std::nullopt;
  }

  std::vector<std::string> result;
  for (const auto& name : g_font_names) {
    // Convert without the terminating NUL so the destination buffer is exact.
    int name_length = static_cast<int>(name.length());
    int size = WideCharToMultiByte(
        CP_UTF8, 0, name.c_str(), name_length, NULL, 0, NULL, NULL);
    if (size > 0) {
      std::string utf8_name(size, '\0');
      int written = WideCharToMultiByte(
          CP_UTF8, 0, name.c_str(), name_length, utf8_name.data(), size,
          NULL, NULL);
      if (written > 0) {
        result.push_back(utf8_name);
      }
    }
  }

  return result;
}

constexpr const wchar_t kWakeUpMessageName[] =
    L"NAI_Launcher_WakeUp_Message";

static UINT GetWakeUpMessage() {
  static const UINT message = RegisterWindowMessage(kWakeUpMessageName);
  return message;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
    auto* flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController*>(controller);
    RegisterPlugins(flutter_view_controller->engine());
  });
  if (!SetChildContent(flutter_controller_->view()->GetNativeWindow())) {
    return false;
  }

  // Register system fonts MethodChannel
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.nailauncher/system_fonts",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getSystemFonts") {
          std::string error_message;
          auto fonts = GetSystemFonts(&error_message);
          if (!fonts.has_value()) {
            result->Error("system_font_enumeration_failed", error_message);
            return;
          }
          flutter::EncodableList font_list;
          for (const auto& font : fonts.value()) {
            font_list.push_back(flutter::EncodableValue(font));
          }
          result->Success(flutter::EncodableValue(font_list));
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  const UINT wake_up_message = GetWakeUpMessage();
  if (wake_up_message != 0 && message == wake_up_message) {
    // 收到唤醒消息，通知 Flutter 侧显示窗口
    if (flutter_controller_ && flutter_controller_->engine()) {
      auto channel =
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              flutter_controller_->engine()->messenger(),
              "com.nailauncher/window_control",
              &flutter::StandardMethodCodec::GetInstance());
      channel->InvokeMethod("wakeUp", nullptr);
    }
    return 0;
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_ && flutter_controller_->engine()) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
