import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/app_version.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/services/update_check_service.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/version/release_asset_info.dart';
import 'package:nai_launcher/data/models/version/version_info.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/update_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/about_settings_section.dart';
import 'package:nai_launcher/presentation/screens/splash/app_bootstrap.dart';
import 'package:nai_launcher/presentation/widgets/common/update_check_dialog.dart';
import 'package:nai_launcher/presentation/widgets/common/update_notice_banner.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// iOS 是未签名 IPA 自签侧载：Release 里没有 iOS 资产，整条应用内更新链路
/// （自动检查 / 提示横幅 / 弹窗下载 / 设置入口）必须在 iOS 上整体关闭，而在
/// Android 与桌面上保持上游行为——上游新增了 Android APK 应用内安装，门控
/// 一旦写成「非 Windows 就禁用」就会误伤 Android。
class _FakeUpdateNotifier extends UpdateStateNotifier {
  _FakeUpdateNotifier(this.initialState);

  final UpdateState initialState;

  @override
  UpdateState build() => initialState;
}

class _MockUpdateCheckService extends Mock implements UpdateCheckService {}

class _MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  // 关于页标题行读 AppVersion.versionName，未初始化会直接抛 StateError。
  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'NAI Launcher',
      packageName: 'nai_launcher',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await AppVersion.initialize();
  });

  const windowsAsset = ReleaseAssetInfo(
    type: ReleaseAssetType.windowsPortable,
    platform: 'windows',
    fileName: 'app-windows.zip',
    downloadUrl: 'https://example.com/app-windows.zip',
    sha256: 'abc',
    size: 100,
    label: 'Windows 便携版',
    description: '解压覆盖即可',
  );
  const windowsVersion = VersionInfo(
    version: '2.0.0',
    currentVersion: '1.0.0',
    assets: [windowsAsset],
    primaryAsset: windowsAsset,
    downloadUrl: 'https://example.com/app-windows.zip',
    htmlUrl: 'https://example.com/releases/v2.0.0',
    isNewer: true,
  );

  /// 只覆盖能力矩阵，不动 `defaultTargetPlatform`：后者会连带改变 Material
  /// 的滚动物理与返回手势，让断言失败的原因变得不可辨认。
  Future<void> onPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      platform,
    );
    try {
      await body();
    } finally {
      PlatformCapabilities.debugOverride = null;
    }
  }

  Widget host(UpdateState state, Widget child) {
    return ProviderScope(
      overrides: [
        updateStateNotifierProvider.overrideWith(
          () => _FakeUpdateNotifier(state),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('iOS 上自动更新检查从不被调度，回到前台也不会绕过', (tester) async {
    await onPlatform(TargetPlatform.iOS, () async {
      var checks = 0;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        ProviderScope(
          child: AutomaticUpdateCheck(
            delay: const Duration(seconds: 1),
            checkRunner: (_) async => checks++,
            child: const SizedBox(),
          ),
        ),
      );

      // initState 的首次调度。
      await tester.pump(const Duration(seconds: 1));
      expect(checks, 0);

      // 上游 4.2.1 新增的 didChangeAppLifecycleState 补查路径——守卫写在
      // initState 而不是 _schedule() 时，正是这里会把 iOS 重新拉回检查。
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      expect(checks, 0);

      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('Android 上自动更新检查照常按上游周期执行', (tester) async {
    await onPlatform(TargetPlatform.android, () async {
      var checks = 0;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        ProviderScope(
          child: AutomaticUpdateCheck(
            delay: const Duration(seconds: 1),
            checkRunner: (_) async => checks++,
            child: const SizedBox(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(checks, 1);

      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('iOS 上更新提示横幅整体不渲染，桌面照常显示', (tester) async {
    const state = UpdateState(
      status: UpdateStatus.available,
      versionInfo: windowsVersion,
      notificationVisible: true,
    );

    await onPlatform(TargetPlatform.iOS, () async {
      await tester.pumpWidget(host(state, const UpdateNoticeBanner()));
      await tester.pump();
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('查看更新'), findsNothing);
    });

    await onPlatform(TargetPlatform.windows, () async {
      await tester.pumpWidget(host(state, const UpdateNoticeBanner()));
      await tester.pump();
      expect(find.text('查看更新'), findsOneWidget);
    });
  });

  testWidgets('iOS 上更新弹窗不展示桌面安装包资产卡，按钮降级为前往下载', (tester) async {
    await onPlatform(TargetPlatform.iOS, () async {
      await tester.pumpWidget(
        host(
          const UpdateState(
            status: UpdateStatus.available,
            versionInfo: windowsVersion,
            notificationVisible: true,
          ),
          const UpdateCheckDialog(presentationManaged: true),
        ),
      );
      await tester.pump();

      expect(find.text('Windows 便携版'), findsNothing);
      expect(find.text('解压覆盖即可'), findsNothing);
      expect(
        find.byKey(const ValueKey('update-manual-release-hint')),
        findsOneWidget,
      );
      expect(find.text('下载更新'), findsNothing);
      expect(find.text('前往下载'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Android 与桌面保留资产卡与应用内下载按钮', (tester) async {
    for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
      await onPlatform(platform, () async {
        await tester.pumpWidget(
          host(
            const UpdateState(
              status: UpdateStatus.available,
              versionInfo: windowsVersion,
              notificationVisible: true,
            ),
            const UpdateCheckDialog(presentationManaged: true),
          ),
        );
        await tester.pump();

        expect(find.text('Windows 便携版'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('update-manual-release-hint')),
          findsNothing,
        );
        expect(find.text('下载更新'), findsOneWidget);
      });
    }
  });

  testWidgets('iOS 的「关于」页用 Release 外链替换检查更新与预发布开关', (tester) async {
    final updateService = _MockUpdateCheckService();
    final storage = _MockLocalStorageService();
    when(() => updateService.getLastCheckTime()).thenAnswer((_) async => null);
    when(() => updateService.shouldIncludePrerelease()).thenReturn(false);
    when(() => storage.getFileLoggingEnabled()).thenReturn(false);

    Widget aboutHost() => ProviderScope(
      overrides: [
        updateStateNotifierProvider.overrideWith(
          () => _FakeUpdateNotifier(const UpdateState()),
        ),
        updateCheckServiceProvider.overrideWithValue(updateService),
        localStorageServiceProvider.overrideWithValue(storage),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(child: AboutSettingsSection()),
        ),
      ),
    );

    await onPlatform(TargetPlatform.iOS, () async {
      await tester.pumpWidget(aboutHost());
      await tester.pump();

      expect(find.byKey(const ValueKey('about-release-page')), findsOneWidget);
      expect(find.text('检查更新'), findsNothing);
      expect(find.byType(SwitchListTile), findsOneWidget); // 只剩文件日志开关
    });

    await onPlatform(TargetPlatform.android, () async {
      // aboutHost 里的 MaterialApp 是 const 子树，直接再 pump 会被原样复用、
      // 不会重新 build，能力位切换就体现不出来。先卸掉整棵树再挂回去。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(aboutHost());
      await tester.pump();

      expect(find.byKey(const ValueKey('about-release-page')), findsNothing);
      expect(find.text('检查更新'), findsOneWidget);
    });
  });
}
