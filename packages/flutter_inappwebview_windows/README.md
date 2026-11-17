# flutter_inappwebview_windows（启动器修补版）

上游 [flutter_inappwebview_windows](https://pub.dev/packages/flutter_inappwebview_windows) 0.6.0 的副本，经根目录 `pubspec.yaml` 的 `dependency_overrides` 替换上游包。`lib/`、`windows/`、`LICENSE`、`analysis_options.yaml` 取自 pub.dev 发布包，未带上游的 `example/`、`test/` 与 `CHANGELOG.md`。

## 修改

- `windows/in_app_webview/in_app_webview_manager.h`：`rohelper_`、`dispatcher_queue_controller_`、`graphics_context_`、`compositor_` 改为指向永不释放对象的引用，进程结束时由系统回收。
- `pubspec.yaml`：版本改为 `0.6.0+launcher`，增加 `publish_to: none`，描述注明修补版。

其余保留的文件与上游内容相同（忽略行尾）。

## 原因

插件注册时就在主线程创建这四个进程级对象，上游只在插件 DLL 的 `DLL_PROCESS_DETACH` 中析构它们。CoreMessaging 由插件动态加载，比插件先卸载并释放 TLS 索引，之后 `compositor_` 的最终 `Release` 经 dcomp 进入 CoreMessaging，访问空的线程上下文，进程退出时可能以 `0xC0000005` 崩溃。上游问题：[pichillilorenzo/flutter_inappwebview#2733](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2733)。

## 升级与移除

- 升级 `flutter_inappwebview` 时，`test/windows/flutter_inappwebview_windows_override_test.dart` 会因版本锁定失败。届时从新版本发布包重新复制 `lib/`、`windows/`、`LICENSE`、`analysis_options.yaml`，重新应用上述修改，并在测试中同步更新版本。
- 上游修复后删除本目录与对应的 `dependency_overrides` 条目，并同时删除契约测试。

## 许可

Apache License 2.0，见 `LICENSE`。
