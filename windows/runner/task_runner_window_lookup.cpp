#include "task_runner_window_lookup.h"

#include <windows.h>

#include <cstring>

namespace {

constexpr wchar_t kPluginModule[] = L"super_native_extensions.dll";
constexpr wchar_t kTaskRunnerWindowClass[] = L"FlutterTaskRunnerWindow";

using FindWindowExWFunction = HWND(WINAPI*)(HWND, HWND, LPCWSTR, LPCWSTR);
FindWindowExWFunction original_find_window_ex = nullptr;

bool IsTaskRunnerWindowLookup(HWND parent,
                              HWND child_after,
                              LPCWSTR class_name,
                              LPCWSTR window_name) {
  return parent == HWND_MESSAGE && child_after == nullptr &&
         window_name == nullptr && class_name != nullptr &&
         !IS_INTRESOURCE(class_name) &&
         wcscmp(class_name, kTaskRunnerWindowClass) == 0;
}

HWND WINAPI FindTaskRunnerWindowOfThread(HWND parent,
                                         HWND child_after,
                                         LPCWSTR class_name,
                                         LPCWSTR window_name) {
  if (IsTaskRunnerWindowLookup(parent, child_after, class_name,
                               window_name)) {
    const DWORD thread_id = GetCurrentThreadId();
    HWND window = nullptr;
    while ((window = original_find_window_ex(HWND_MESSAGE, window, class_name,
                                             nullptr)) != nullptr) {
      if (GetWindowThreadProcessId(window, nullptr) == thread_id) {
        return window;
      }
    }
  }
  // 找不到本线程窗口时保留原查询，避免空句柄让消息泵处理全部消息。
  return original_find_window_ex(parent, child_after, class_name, window_name);
}

bool RedirectFindWindowExImport(HMODULE module) {
  auto* base = reinterpret_cast<BYTE*>(module);
  const auto* dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(base);
  const auto* nt = reinterpret_cast<const IMAGE_NT_HEADERS*>(base + dos->e_lfanew);
  const IMAGE_DATA_DIRECTORY& imports =
      nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
  if (imports.VirtualAddress == 0) {
    return false;
  }
  bool redirected = false;
  for (auto* descriptor = reinterpret_cast<IMAGE_IMPORT_DESCRIPTOR*>(
           base + imports.VirtualAddress);
       descriptor->Name != 0; ++descriptor) {
    if (_stricmp(reinterpret_cast<const char*>(base + descriptor->Name),
                 "user32.dll") != 0 ||
        descriptor->OriginalFirstThunk == 0) {
      continue;
    }
    auto* name = reinterpret_cast<IMAGE_THUNK_DATA*>(
        base + descriptor->OriginalFirstThunk);
    auto* slot =
        reinterpret_cast<IMAGE_THUNK_DATA*>(base + descriptor->FirstThunk);
    for (; name->u1.AddressOfData != 0; ++name, ++slot) {
      if (IMAGE_SNAP_BY_ORDINAL(name->u1.Ordinal)) {
        continue;
      }
      const auto* import =
          reinterpret_cast<const IMAGE_IMPORT_BY_NAME*>(
              base + name->u1.AddressOfData);
      if (strcmp(reinterpret_cast<const char*>(import->Name),
                 "FindWindowExW") != 0) {
        continue;
      }
      DWORD protection = 0;
      if (!VirtualProtect(&slot->u1.Function, sizeof(slot->u1.Function),
                          PAGE_READWRITE, &protection)) {
        return false;
      }
      if (original_find_window_ex == nullptr) {
        original_find_window_ex =
            reinterpret_cast<FindWindowExWFunction>(slot->u1.Function);
      }
      slot->u1.Function =
          reinterpret_cast<ULONG_PTR>(&FindTaskRunnerWindowOfThread);
      VirtualProtect(&slot->u1.Function, sizeof(slot->u1.Function), protection,
                     &protection);
      redirected = true;
    }
  }
  return redirected;
}

}

void InstallTaskRunnerWindowLookup() {
  HMODULE module = GetModuleHandleW(kPluginModule);
  if (module == nullptr || !RedirectFindWindowExImport(module)) {
    OutputDebugStringW(
        L"NAI Launcher: task runner window lookup not installed\n");
  }
}
