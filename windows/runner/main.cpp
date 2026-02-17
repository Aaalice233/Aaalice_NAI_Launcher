#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

// 单实例互斥体名称（使用应用唯一标识）
constexpr const wchar_t kSingleInstanceMutexName[] = L"NAI_Launcher_SingleInstance_Mutex";
// 自定义消息：唤醒已存在的窗口
constexpr const UINT kWakeUpMessage = WM_USER + 1;

// 查找已存在的 Flutter 窗口
HWND FindExistingFlutterWindow() {
  // Flutter 窗口类名通常是 "FLUTTER_RUNNER_WIN32_WINDOW"
  // 但为了更可靠，我们遍历所有顶级窗口查找窗口标题
  HWND hwnd = nullptr;
  while ((hwnd = FindWindowEx(nullptr, hwnd, nullptr, nullptr)) != nullptr) {
    wchar_t title[256];
    GetWindowText(hwnd, title, 256);
    // 匹配窗口标题（与创建时传入的标题一致）
    if (wcsstr(title, L"NAI Launcher") != nullptr) {
      return hwnd;
    }
  }
  return nullptr;
}

// 唤醒已存在的窗口
void WakeUpExistingWindow() {
  HWND existing_window = FindExistingFlutterWindow();
  if (existing_window != nullptr) {
    // 如果窗口最小化，恢复它
    if (IsIconic(existing_window)) {
      ShowWindow(existing_window, SW_RESTORE);
    }
    // 将窗口带到前台
    SetForegroundWindow(existing_window);
    // 发送自定义消息通知 Flutter 侧（可选，用于更复杂的通信）
    SendMessage(existing_window, kWakeUpMessage, 0, 0);
  }
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // 单实例检测
  HANDLE single_instance_mutex = CreateMutex(
      nullptr, TRUE, kSingleInstanceMutexName);
  
  bool is_another_instance_running = (GetLastError() == ERROR_ALREADY_EXISTS);
  
  if (is_another_instance_running) {
    // 已有实例在运行，唤醒它并退出
    WakeUpExistingWindow();
    
    if (single_instance_mutex != nullptr) {
      CloseHandle(single_instance_mutex);
    }
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"NAI Launcher", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // 清理互斥体
  if (single_instance_mutex != nullptr) {
    CloseHandle(single_instance_mutex);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
