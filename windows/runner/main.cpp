#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

// 单实例互斥体名称（使用应用唯一标识）
constexpr const wchar_t kSingleInstanceMutexName[] =
    L"NAI_Launcher_SingleInstance_Mutex";
constexpr const wchar_t kFlutterRunnerWindowClassName[] =
    L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kLauncherWindowTitle[] = L"NAI Launcher";
constexpr const wchar_t kWakeUpMessageName[] =
    L"NAI_Launcher_WakeUp_Message";
constexpr DWORD kExistingWindowWaitTimeoutMs = 3000;
constexpr DWORD kExistingWindowPollIntervalMs = 200;
constexpr const wchar_t kAlreadyStartingMessage[] =
    L"NAI Launcher is already starting.\n"
    L"Please wait a few seconds and try again.";

static UINT GetWakeUpMessage() {
  static const UINT message = RegisterWindowMessage(kWakeUpMessageName);
  return message;
}

bool EqualsOrdinalIgnoreCase(const std::wstring& left,
                             const std::wstring& right) {
  if (left.empty() || right.empty()) {
    return false;
  }

  return CompareStringOrdinal(left.c_str(), -1, right.c_str(), -1, TRUE) ==
         CSTR_EQUAL;
}

std::wstring GetCurrentExecutablePath() {
  std::wstring path(MAX_PATH, L'\0');
  DWORD length = 0;

  while (true) {
    length = GetModuleFileNameW(
        nullptr, path.data(), static_cast<DWORD>(path.size()));
    if (length == 0) {
      return L"";
    }
    if (length < path.size()) {
      path.resize(length);
      return path;
    }
    path.resize(path.size() * 2);
  }
}

std::wstring GetProcessExecutablePath(DWORD process_id) {
  HANDLE process =
      OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (process == nullptr) {
    return L"";
  }

  std::wstring path(MAX_PATH, L'\0');
  while (true) {
    DWORD size = static_cast<DWORD>(path.size());
    if (QueryFullProcessImageNameW(process, 0, path.data(), &size)) {
      path.resize(size);
      CloseHandle(process);
      return path;
    }

    if (GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
      CloseHandle(process);
      return L"";
    }

    path.resize(path.size() * 2);
  }
}

std::wstring GetWindowTitle(HWND hwnd) {
  const int length = GetWindowTextLengthW(hwnd);
  if (length <= 0) {
    return L"";
  }

  std::wstring title(length + 1, L'\0');
  const int copied =
      GetWindowTextW(hwnd, title.data(), static_cast<int>(title.size()));
  if (copied <= 0) {
    return L"";
  }

  title.resize(copied);
  return title;
}

std::wstring GetWindowClassName(HWND hwnd) {
  wchar_t class_name[256] = {};
  const int copied = GetClassNameW(hwnd, class_name, 256);
  if (copied <= 0) {
    return L"";
  }
  return std::wstring(class_name, copied);
}

bool IsLauncherWindow(HWND hwnd) {
  if (GetWindowClassName(hwnd) != kFlutterRunnerWindowClassName) {
    return false;
  }

  if (GetWindowTitle(hwnd) != kLauncherWindowTitle) {
    return false;
  }

  DWORD process_id = 0;
  GetWindowThreadProcessId(hwnd, &process_id);
  if (process_id == 0) {
    return false;
  }

  return EqualsOrdinalIgnoreCase(
      GetProcessExecutablePath(process_id), GetCurrentExecutablePath());
}

// 查找已存在的 Flutter 窗口
HWND FindExistingFlutterWindow() {
  HWND hwnd = nullptr;
  while ((hwnd = FindWindowEx(nullptr, hwnd, nullptr, nullptr)) != nullptr) {
    if (IsLauncherWindow(hwnd)) {
      return hwnd;
    }
  }
  return nullptr;
}

HWND WaitForExistingFlutterWindow(DWORD timeout_ms) {
  const DWORD started_at = GetTickCount();

  while (true) {
    HWND existing_window = FindExistingFlutterWindow();
    if (existing_window != nullptr) {
      return existing_window;
    }

    const DWORD elapsed_ms = GetTickCount() - started_at;
    if (elapsed_ms >= timeout_ms) {
      return nullptr;
    }

    DWORD sleep_ms = kExistingWindowPollIntervalMs;
    const DWORD remaining_ms = timeout_ms - elapsed_ms;
    if (sleep_ms > remaining_ms) {
      sleep_ms = remaining_ms;
    }
    Sleep(sleep_ms);
  }
}

// 唤醒已存在的窗口
bool WakeUpExistingWindow(DWORD wait_timeout_ms) {
  HWND existing_window = wait_timeout_ms > 0
      ? WaitForExistingFlutterWindow(wait_timeout_ms)
      : FindExistingFlutterWindow();
  if (existing_window == nullptr) {
    return false;
  }

  if (IsIconic(existing_window)) {
    ShowWindow(existing_window, SW_RESTORE);
  } else {
    ShowWindow(existing_window, SW_SHOW);
  }

  SetForegroundWindow(existing_window);

  const UINT wake_up_message = GetWakeUpMessage();
  if (wake_up_message != 0) {
    DWORD_PTR result = 0;
    SendMessageTimeout(existing_window, wake_up_message, 0, 0, SMTO_ABORTIFHUNG,
                       5000, &result);
  }

  return true;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // 单实例检测
  HANDLE single_instance_mutex =
      CreateMutex(nullptr, TRUE, kSingleInstanceMutexName);

  bool is_another_instance_running = (GetLastError() == ERROR_ALREADY_EXISTS);

  if (is_another_instance_running) {
    // 已有实例在运行时，先等待首实例窗口完成创建，避免并发初始化数据文件。
    if (WakeUpExistingWindow(kExistingWindowWaitTimeoutMs)) {
      if (single_instance_mutex != nullptr) {
        CloseHandle(single_instance_mutex);
      }
      return EXIT_SUCCESS;
    }

    if (single_instance_mutex != nullptr) {
      CloseHandle(single_instance_mutex);
      single_instance_mutex = nullptr;
    }
    MessageBoxW(nullptr, kAlreadyStartingMessage, kLauncherWindowTitle,
                MB_OK | MB_ICONINFORMATION | MB_SETFOREGROUND);
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
    if (single_instance_mutex != nullptr) {
      CloseHandle(single_instance_mutex);
    }
    ::CoUninitialize();
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
