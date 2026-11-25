#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <optional>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  struct PendingDirectoryPick {
    std::wstring dialog_title;
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  };

  void HandlePendingDirectoryPick(HWND hwnd);
  void NotifyWindowBoundsChanged();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_state_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      directory_picker_channel_;
  std::optional<PendingDirectoryPick> pending_directory_pick_;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
      active_directory_pick_result_;
  bool directory_pick_in_progress_ = false;
  bool in_window_move_size_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
