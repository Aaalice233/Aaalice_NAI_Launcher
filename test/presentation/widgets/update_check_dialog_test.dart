import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/update_check_service.dart';
import 'package:nai_launcher/data/models/version/release_asset_info.dart';
import 'package:nai_launcher/data/models/version/version_info.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/update_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/update_check_dialog.dart';

class _DialogUpdateNotifier extends UpdateStateNotifier {
  _DialogUpdateNotifier(this.initialState);

  final UpdateState initialState;

  @override
  UpdateState build() => initialState;
}

void main() {
  testWidgets('renders GitHub Flavored Markdown release notes', (tester) async {
    const asset = ReleaseAssetInfo(
      type: ReleaseAssetType.windowsPortable,
      platform: 'windows',
      fileName: 'update.zip',
      downloadUrl: 'https://example.com/update.zip',
      sha256: 'abc',
    );
    const info = VersionInfo(
      version: '2.0.0',
      currentVersion: '1.0.0',
      primaryAsset: asset,
      assets: [asset],
      isNewer: true,
      releaseNotes: '''
# Major Update

- [x] Persistent notifications
- **Safe** rollback

| Feature | Status |
| --- | --- |
| Resume | Ready |

> Important note

```dart
print('updated');
```

[Release details](https://example.com/release)
''',
    );
    const state = UpdateState(
      status: UpdateStatus.available,
      versionInfo: info,
      notificationVisible: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateStateNotifierProvider.overrideWith(
            () => _DialogUpdateNotifier(state),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: UpdateCheckDialog()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('Major Update'), findsOneWidget);
    expect(find.text('Persistent notifications'), findsOneWidget);
    expect(find.text('Feature'), findsOneWidget);
    expect(find.text('Important note'), findsOneWidget);
    expect(find.text("print('updated');"), findsOneWidget);
    expect(find.text('Release details'), findsOneWidget);
  });

  testWidgets('keeps release notes readable with a mismatched custom theme', (
    tester,
  ) async {
    const info = VersionInfo(
      version: '2.0.0',
      currentVersion: '1.0.0',
      isNewer: true,
      releaseNotes: '# Visible heading\n\n- Visible body',
    );
    const state = UpdateState(
      status: UpdateStatus.available,
      versionInfo: info,
      notificationVisible: true,
    );
    final colorScheme = const ColorScheme.dark().copyWith(
      surfaceContainerLowest: Colors.white,
      surfaceContainerHigh: const Color(0xFFF2F2F2),
      surfaceContainerHighest: const Color(0xFFE8E8E8),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateStateNotifierProvider.overrideWith(
            () => _DialogUpdateNotifier(state),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: colorScheme,
            textTheme: ThemeData.dark().textTheme,
          ),
          home: const Scaffold(body: UpdateCheckDialog()),
        ),
      ),
    );
    await tester.pump();

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.styleSheet?.p?.color, Colors.black);
    expect(markdown.styleSheet?.h1?.color, Colors.black);
    expect(markdown.styleSheet?.listBullet?.color, Colors.black);
    expect(find.text('Visible heading'), findsOneWidget);
    expect(find.text('Visible body'), findsOneWidget);
  });

  testWidgets('shows a localized bounded error instead of raw exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const state = UpdateState(
      status: UpdateStatus.error,
      checkFailureType: UpdateCheckFailureType.rateLimited,
      errorMessage: 'DioException with a very long internal stack trace',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateStateNotifierProvider.overrideWith(
            () => _DialogUpdateNotifier(state),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: UpdateCheckDialog()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('更新服务器请求繁忙，请稍后重试。'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a compact action grid on a narrow Android-sized view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    const info = VersionInfo(
      version: '2.0.0',
      currentVersion: '1.0.0',
      isNewer: true,
      htmlUrl: 'https://example.com/release',
      downloadUrl: 'https://example.com/update.apk',
      releaseNotes: '''
## 新機能

- 長い更新内容でも独立してスクロールできます。
- 操作ボタンはすべて表示されたままです。
- 狭い画面でも更新履歴を読みやすくします。
- セーフエリアとタッチ操作に対応します。
- 追加のリリースノートです。
- さらに長いリリースノートです。
''',
    );
    const state = UpdateState(
      status: UpdateStatus.available,
      versionInfo: info,
      notificationVisible: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateStateNotifierProvider.overrideWith(
            () => _DialogUpdateNotifier(state),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => UpdateCheckDialog.show(context),
                  child: const Text('show'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    const labels = ['4時間後に通知', 'このバージョンをスキップ', 'Release を表示', 'ダウンロードに移動'];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
      expect(find.text(label).hitTestable(), findsOneWidget);
    }

    Rect buttonRect(String label) => tester.getRect(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      ),
    );

    final firstRowLeft = buttonRect(labels[0]);
    final firstRowRight = buttonRect(labels[1]);
    final secondRowLeft = buttonRect(labels[2]);
    final secondRowRight = buttonRect(labels[3]);
    expect(firstRowLeft.top, closeTo(firstRowRight.top, 0.1));
    expect(secondRowLeft.top, closeTo(secondRowRight.top, 0.1));
    expect(firstRowLeft.left, lessThan(firstRowRight.left));
    expect(secondRowLeft.left, lessThan(secondRowRight.left));
    expect(firstRowLeft.height, greaterThanOrEqualTo(48));
    expect(secondRowLeft.height, greaterThanOrEqualTo(48));

    final actionRect = tester.getRect(
      find.byKey(const ValueKey('update-dialog-actions')),
    );
    final notesRect = tester.getRect(
      find.byKey(const ValueKey('update-release-notes-region')),
    );
    expect(actionRect.height, lessThanOrEqualTo(144));
    expect(notesRect.height, greaterThan(actionRect.height));
    expect(
      find.byKey(const ValueKey('update-release-notes-scroll-view')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps desktop update actions horizontally grouped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const info = VersionInfo(
      version: '2.0.0',
      currentVersion: '1.0.0',
      isNewer: true,
      htmlUrl: 'https://example.com/release',
      downloadUrl: 'https://example.com/update.zip',
      releaseNotes: '- Desktop release note',
    );
    const state = UpdateState(
      status: UpdateStatus.available,
      versionInfo: info,
      notificationVisible: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateStateNotifierProvider.overrideWith(
            () => _DialogUpdateNotifier(state),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: UpdateCheckDialog()),
        ),
      ),
    );
    await tester.pump();

    final actionButtons = find.descendant(
      of: find.byKey(const ValueKey('update-dialog-actions')),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(actionButtons, findsNWidgets(4));
    final buttonRects = [
      for (var index = 0; index < 4; index++)
        tester.getRect(actionButtons.at(index)),
    ];
    final rowTops = buttonRects.map((rect) => rect.top).toSet();
    expect(rowTops.length, lessThanOrEqualTo(2));
    expect(
      buttonRects.any(
        (left) => buttonRects.any(
          (right) =>
              left != right &&
              (left.top - right.top).abs() < 0.1 &&
              left.left < right.left,
        ),
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows changelog content without release download sections', (
    tester,
  ) async {
    const asset = ReleaseAssetInfo(
      type: ReleaseAssetType.windowsPortable,
      platform: 'windows',
      fileName: 'update.zip',
      downloadUrl: 'https://example.com/update.zip',
      sha256: 'abc',
    );
    const info = VersionInfo(
      version: '2.0.0+33',
      currentVersion: '1.0.0+32',
      primaryAsset: asset,
      assets: [asset],
      isNewer: true,
      releaseNotes: '''
# NAI Launcher v2.0.0

## 📥 按系统下载

点击对应按钮直接下载。

## 📝 更新内容

### 🚨 必看

> [!IMPORTANT]
> **这是重要升级说明。**

### 🐛 修复

- 修复实际问题。

## 🔐 文件校验

SHA256 校验说明。
''',
    );
    const state = UpdateState(
      status: UpdateStatus.available,
      versionInfo: info,
      notificationVisible: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateStateNotifierProvider.overrideWith(
            () => _DialogUpdateNotifier(state),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: UpdateCheckDialog()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('修复实际问题。'), findsOneWidget);
    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.data, contains('> **IMPORTANT**'));
    expect(tester.takeException(), isNull);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.text('v2.0.0'), findsOneWidget);
    expect(find.text('查看 Release'), findsOneWidget);
    expect(find.textContaining('+32'), findsNothing);
    expect(find.textContaining('+33'), findsNothing);
    expect(find.text('按系统下载'), findsNothing);
    expect(find.text('点击对应按钮直接下载。'), findsNothing);
    expect(find.text('文件校验'), findsNothing);
    expect(find.text('SHA256 校验说明。'), findsNothing);
  });
}
