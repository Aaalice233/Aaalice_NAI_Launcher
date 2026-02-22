#include "flutter_window.h"

#include <optional>
#include <set>
#include <string>
#include <vector>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
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
std::vector<std::string> GetSystemFonts() {
  g_font_names.clear();

  HDC hdc = GetDC(NULL);
  LOGFONTW lf = {};
  lf.lfCharSet = DEFAULT_CHARSET;
  lf.lfFaceName[0] = L'\0';

  EnumFontFamiliesExW(hdc, &lf, EnumFontFamExProc, 0, 0);
  ReleaseDC(NULL, hdc);

  std::vector<std::string> result;
  for (const auto& name : g_font_names) {
    // Convert wstring to UTF-8 string
    int size = WideCharToMultiByte(CP_UTF8, 0, name.c_str(), -1, NULL, 0, NULL, NULL);
    if (size > 0) {
      std::string utf8_name(size - 1, '\0');
      WideCharToMultiByte(CP_UTF8, 0, name.c_str(), -1, &utf8_name[0], size, NULL, NULL);
      result.push_back(utf8_name);
    }
  }

  return result;
}

// 自定义消息：唤醒窗口
constexpr const UINT kWakeUpMessage = WM_USER + 1;

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Register system fonts MethodChannel
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.nailauncher/system_fonts",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getSystemFonts") {
          auto fonts = GetSystemFonts();
          flutter::EncodableList font_list;
          for (const auto& font : fonts) {
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

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case kWakeUpMessage: {
      // 收到唤醒消息，通知 Flutter 侧显示窗口
      auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.nailauncher/window_control",
          &flutter::StandardMethodCodec::GetInstance());
      channel->InvokeMethod("wakeUp", nullptr);
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
