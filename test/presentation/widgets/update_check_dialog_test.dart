import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
