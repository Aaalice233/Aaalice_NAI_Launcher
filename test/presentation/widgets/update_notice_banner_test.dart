import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/update_installer_service.dart';
import 'package:nai_launcher/data/models/version/release_asset_info.dart';
import 'package:nai_launcher/data/models/version/version_info.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/update_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/update_notice_banner.dart';

class _FakeUpdateNotifier extends UpdateStateNotifier {
  _FakeUpdateNotifier(this.initialState);

  final UpdateState initialState;

  @override
  UpdateState build() => initialState;

  @override
  Future<void> remindLater({Duration? delay}) async {
    state = state.copyWith(notificationVisible: false);
  }
}

void main() {
  const asset = ReleaseAssetInfo(
    type: ReleaseAssetType.windowsPortable,
    platform: 'windows',
    fileName: 'update.zip',
    downloadUrl: 'https://example.com/update.zip',
    sha256: 'abc',
    size: 100,
  );
  const info = VersionInfo(
    version: '2.0.0+33',
    currentVersion: '1.0.0+32',
    assets: [asset],
    primaryAsset: asset,
    isNewer: true,
  );

  Widget app(UpdateState state, {double textScale = 1}) {
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: UpdateNoticeBanner(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('shows a persistent available update notice and can snooze it', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const UpdateState(
          status: UpdateStatus.available,
          versionInfo: info,
          notificationVisible: true,
        ),
      ),
    );

    expect(find.text('新版本 v2.0.0 可用'), findsOneWidget);
    expect(find.textContaining('+33'), findsNothing);
    expect(find.text('查看更新'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(find.text('新版本 v2.0.0 可用'), findsNothing);
  });

  testWidgets('uses a stacked compact layout without horizontal overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(
        const UpdateState(
          status: UpdateStatus.available,
          versionInfo: info,
          notificationVisible: true,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final actionSize = tester.getSize(
      find.widgetWithText(FilledButton, '查看更新'),
    );
    expect(actionSize.width, greaterThan(280));
  });

  testWidgets('uses the stacked layout at 3x text scale', (tester) async {
    tester.view.physicalSize = const Size(640, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(
        const UpdateState(
          status: UpdateStatus.available,
          versionInfo: info,
          notificationVisible: true,
        ),
        textScale: 3,
      ),
    );

    expect(tester.takeException(), isNull);
    final action = find.widgetWithText(FilledButton, '查看更新');
    expect(action, findsOneWidget);
    expect(tester.getSize(action).width, greaterThan(500));
    expect(find.text('新版本 v2.0.0 可用'), findsOneWidget);
  });

  testWidgets('distinguishes a verified package ready to install', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        UpdateState(
          status: UpdateStatus.downloaded,
          versionInfo: info,
          downloadedUpdate: DownloadedUpdate(
            file: File('update.zip'),
            asset: asset,
            version: '2.0.0',
          ),
          notificationVisible: true,
        ),
      ),
    );

    expect(find.text('新版本 v2.0.0 已准备好'), findsOneWidget);
    expect(find.textContaining('+33'), findsNothing);
    expect(find.text('立即安装'), findsOneWidget);
  });
}
