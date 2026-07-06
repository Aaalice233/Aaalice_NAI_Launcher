import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/save_vibe_dialog.dart';

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 1200);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('中文环境下保存多个 Vibe 弹窗不显示硬编码英文', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SaveVibeDialog(
          vibe: _primaryVibe,
          vibes: [_primaryVibe, _secondaryVibe],
        ),
      ),
    );

    expect(find.text('保存为 Bundle'), findsOneWidget);
    expect(find.text('Save as bundle'), findsNothing);
    expect(find.text('将 2 个 Vibe 保存为一个 Bundle'), findsOneWidget);
    expect(find.text('Save 2 Vibes as one bundle'), findsNothing);
    expect(find.text('输入标签后点击添加'), findsOneWidget);
    expect(find.text('Enter a tag, then press Add'), findsNothing);
    expect(find.text('参考强度'), findsOneWidget);
    expect(find.text('Strength'), findsNothing);
    expect(find.text('信息提取'), findsOneWidget);
    expect(find.text('Info'), findsNothing);
    expect(find.text('图片'), findsOneWidget);
    expect(find.text('Image'), findsNothing);
  });
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      vibeLibraryNotifierProvider.overrideWith(_TestVibeLibraryNotifier.new),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

const _primaryVibe = VibeReference(
  displayName: 'Primary',
  vibeEncoding: '',
  sourceType: VibeSourceType.rawImage,
);

const _secondaryVibe = VibeReference(
  displayName: 'Secondary',
  vibeEncoding: '',
  sourceType: VibeSourceType.rawImage,
);

class _TestVibeLibraryNotifier extends VibeLibraryNotifier {
  @override
  VibeLibraryState build() => const VibeLibraryState();
}
