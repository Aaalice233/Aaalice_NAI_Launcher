#ifndef RUNNER_DIRECTORY_PICKER_H_
#define RUNNER_DIRECTORY_PICKER_H_

#include <windows.h>

#include <string>

struct WindowsDirectoryPickResult {
  bool cancelled = false;
  bool succeeded = false;
  std::string path;
  std::string error_code;
  std::string error_message;
};

// 将 UTF-8 字符串转换为 UTF-16，供 Win32/COM 对话框标题等接口使用。
std::wstring Utf16FromUtf8(const std::string& utf8);

// 在所属窗口主线程上同步弹出原生目录选择对话框。
WindowsDirectoryPickResult PickDirectoryOnWindowThread(
    HWND owner,
    const std::wstring& dialog_title);

#endif  // RUNNER_DIRECTORY_PICKER_H_
