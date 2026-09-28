#include "flutter_window.h"

#include <cmath>
#include <optional>
#include <set>
#include <string>
#include <vector>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>
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

flutter::EncodableMap EncodeRect(const RECT& rect) {
  return {
      {flutter::EncodableValue("x"),
       flutter::EncodableValue(static_cast<double>(rect.left))},
      {flutter::EncodableValue("y"),
       flutter::EncodableValue(static_cast<double>(rect.top))},
      {flutter::EncodableValue("width"),
       flutter::EncodableValue(static_cast<double>(rect.right - rect.left))},
      {flutter::EncodableValue("height"),
       flutter::EncodableValue(static_cast<double>(rect.bottom - rect.top))},
  };
}

struct WorkAreaCollection {
  flutter::EncodableList areas;
  std::optional<flutter::EncodableMap> primary;
  double primary_scale_factor = 1.0;
};

BOOL CALLBACK CollectWorkArea(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  auto* collection = reinterpret_cast<WorkAreaCollection*>(data);
  MONITORINFO info = {};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfo(monitor, &info)) {
    return TRUE;
  }

  const double scale_factor =
      FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
  auto area = EncodeRect(info.rcWork);
  area[flutter::EncodableValue("scaleFactor")] =
      flutter::EncodableValue(scale_factor);
  collection->areas.push_back(flutter::EncodableValue(area));
  if ((info.dwFlags & MONITORINFOF_PRIMARY) != 0) {
    collection->primary = area;
    collection->primary_scale_factor = scale_factor;
  }
  return TRUE;
}

std::optional<double> ReadFiniteDouble(const flutter::EncodableMap& values,
                                       const char* key) {
  const auto iterator = values.find(flutter::EncodableValue(key));
  if (iterator == values.end()) {
    return std::nullopt;
  }
  const auto* value = std::get_if<double>(&iterator->second);
  if (value == nullptr || !std::isfinite(*value)) {
    return std::nullopt;
  }
  return *value;
}

std::optional<WINDOWPLACEMENT> ReadWindowPlacement(HWND window) {
  WINDOWPLACEMENT placement = {};
  placement.length = sizeof(placement);
  if (!GetWindowPlacement(window, &placement)) {
    return std::nullopt;
  }
  return placement;
}

bool IsMaximizedPlacement(const WINDOWPLACEMENT& placement) {
  return placement.showCmd == SW_SHOWMAXIMIZED;
}

bool IsMinimizedPlacement(const WINDOWPLACEMENT& placement) {
  return placement.showCmd == SW_SHOWMINIMIZED ||
         placement.showCmd == SW_MINIMIZE ||
         placement.showCmd == SW_SHOWMINNOACTIVE;
}

std::optional<MONITORINFO> ReadMonitorInfo(HMONITOR monitor) {
  MONITORINFO info = {};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfo(monitor, &info)) {
    return std::nullopt;
  }
  return info;
}

RECT PlacementToScreenRect(HWND window, const RECT& placement_rect) {
  RECT screen_rect = placement_rect;
  const auto monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  const auto info = ReadMonitorInfo(monitor);
  if (!info.has_value()) {
    return screen_rect;
  }

  const LONG x_offset = info->rcWork.left - info->rcMonitor.left;
  const LONG y_offset = info->rcWork.top - info->rcMonitor.top;
  OffsetRect(&screen_rect, x_offset, y_offset);
  return screen_rect;
}

RECT ScreenToPlacementRect(const RECT& screen_rect) {
  RECT placement_rect = screen_rect;
  const auto monitor = MonitorFromRect(&screen_rect, MONITOR_DEFAULTTONEAREST);
  const auto info = ReadMonitorInfo(monitor);
  if (!info.has_value()) {
    return placement_rect;
  }

  const LONG x_offset = info->rcWork.left - info->rcMonitor.left;
  const LONG y_offset = info->rcWork.top - info->rcMonitor.top;
  OffsetRect(&placement_rect, -x_offset, -y_offset);
  return placement_rect;
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

  window_state_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.nailauncher/window_state",
          &flutter::StandardMethodCodec::GetInstance());
  window_state_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        HWND window = GetHandle();
        if (window == nullptr) {
          result->Error("window_unavailable", "The main window is unavailable.");
          return;
        }

        if (call.method_name() == "getWorkAreas") {
          WorkAreaCollection collection;
          if (!EnumDisplayMonitors(nullptr, nullptr, CollectWorkArea,
                                   reinterpret_cast<LPARAM>(&collection)) ||
              collection.areas.empty() || !collection.primary.has_value()) {
            result->Error("work_area_query_failed",
                          "Unable to enumerate Windows work areas.");
            return;
          }
          flutter::EncodableMap response = {
              {flutter::EncodableValue("areas"),
               flutter::EncodableValue(collection.areas)},
              {flutter::EncodableValue("primary"),
               flutter::EncodableValue(collection.primary.value())},
              {flutter::EncodableValue("primaryScaleFactor"),
               flutter::EncodableValue(collection.primary_scale_factor)},
          };
          result->Success(flutter::EncodableValue(response));
          return;
        }

        if (call.method_name() == "readState") {
          const auto placement = ReadWindowPlacement(window);
          if (!placement.has_value()) {
            result->Error("window_placement_query_failed",
                          "Unable to read the Windows window placement.");
            return;
          }
          flutter::EncodableMap response = {
              {flutter::EncodableValue("bounds"),
               flutter::EncodableValue(
                   EncodeRect(PlacementToScreenRect(
                       window, placement->rcNormalPosition)))},
              {flutter::EncodableValue("maximized"),
               flutter::EncodableValue(IsMaximizedPlacement(*placement))},
              {flutter::EncodableValue("minimized"),
               flutter::EncodableValue(IsMinimizedPlacement(*placement))},
              {flutter::EncodableValue("scaleFactor"),
               flutter::EncodableValue(
                   FlutterDesktopGetDpiForMonitor(MonitorFromWindow(
                       window, MONITOR_DEFAULTTONEAREST)) /
                   96.0)},
          };
          result->Success(flutter::EncodableValue(response));
          return;
        }

        if (call.method_name() == "synchronizeViewMetrics") {
          SynchronizeChildContentMetrics();
          result->Success();
          return;
        }

        if (call.method_name() == "restore") {
          const auto* arguments = call.arguments();
          const auto* values = arguments == nullptr
                                   ? nullptr
                                   : std::get_if<flutter::EncodableMap>(arguments);
          if (values == nullptr) {
            result->Error("invalid_window_state",
                          "Window restore arguments are missing.");
            return;
          }
          const auto x = ReadFiniteDouble(*values, "x");
          const auto y = ReadFiniteDouble(*values, "y");
          const auto width = ReadFiniteDouble(*values, "width");
          const auto height = ReadFiniteDouble(*values, "height");
          const auto maximized_iterator =
              values->find(flutter::EncodableValue("maximized"));
          const auto* maximized =
              maximized_iterator == values->end()
                  ? nullptr
                  : std::get_if<bool>(&maximized_iterator->second);
          if (!x.has_value() || !y.has_value() || !width.has_value() ||
              !height.has_value() || width.value() <= 0 ||
              height.value() <= 0 || maximized == nullptr) {
            result->Error("invalid_window_state",
                          "Window restore arguments are invalid.");
            return;
          }

          const auto current_placement = ReadWindowPlacement(window);
          if (!current_placement.has_value()) {
            result->Error("window_placement_query_failed",
                          "Unable to read the Windows window placement.");
            return;
          }

          WINDOWPLACEMENT restored_placement = *current_placement;
          restored_placement.flags = 0;
          restored_placement.showCmd =
              *maximized ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL;
          const RECT screen_bounds = {
              static_cast<LONG>(std::round(*x)),
              static_cast<LONG>(std::round(*y)),
              static_cast<LONG>(std::round(*x + *width)),
              static_cast<LONG>(std::round(*y + *height)),
          };
          restored_placement.rcNormalPosition =
              ScreenToPlacementRect(screen_bounds);
          if (!SetWindowPlacement(window, &restored_placement)) {
            result->Error("window_restore_failed",
                          "Unable to restore the Windows window placement.");
            return;
          }
          result->Success();
          return;
        }

        result->NotImplemented();
      });

  // Auto-show would race the atomic bounds/maximize restore.
  return true;
}

void FlutterWindow::OnDestroy() {
  window_state_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::NotifyWindowBoundsChanged() {
  if (window_state_channel_) {
    window_state_channel_->InvokeMethod("boundsChanged", nullptr);
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_ENTERSIZEMOVE) {
    in_window_move_size_ = true;
  } else if (message == WM_EXITSIZEMOVE) {
    in_window_move_size_ = false;
    NotifyWindowBoundsChanged();
  } else if (message == WM_WINDOWPOSCHANGED && !in_window_move_size_) {
    NotifyWindowBoundsChanged();
  }

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
