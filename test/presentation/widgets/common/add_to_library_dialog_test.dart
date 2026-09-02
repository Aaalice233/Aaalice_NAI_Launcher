import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/tag_library_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/add_to_library_dialog.dart';

void main() {
  testWidgets('320 宽 3x 字体、IME 与 SafeArea 下使用全屏表单且字段可达', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.reset);
    bool? result;

    await tester.pumpWidget(
      _buildTestApp(
        textScaler: const TextScaler.linear(3),
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-full-screen-form'));
    expect(surface, findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    final surfaceRect = tester.getRect(surface);
    expect(surfaceRect.left, greaterThanOrEqualTo(0));
    expect(surfaceRect.top, greaterThanOrEqualTo(24));
    expect(surfaceRect.right, lessThanOrEqualTo(320));
    expect(surfaceRect.bottom, lessThanOrEqualTo(568 - 16 - 240));

    expect(find.byKey(const ValueKey('add-to-library-name')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add-to-library-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('add-to-library-category')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('add-to-library-tags')), findsOneWidget);
    expect(find.text('source-tag'), findsOneWidget);

    final saveButton = find.descendant(
      of: surface,
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(saveButton);
    await tester.pump();
    expect(saveButton.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('取消'));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('宽屏使用有界侧边表单并保留全部字段与返回语义', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bool? result;

    await tester.pumpWidget(_buildTestApp(onResult: (value) => result = value));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-side-sheet'));
    expect(surface, findsOneWidget);
    expect(tester.getSize(surface).width, lessThan(1200));
    expect(tester.getSize(surface).width, lessThanOrEqualTo(520));
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('add-to-library-name')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add-to-library-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('add-to-library-category')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('add-to-library-tags')), findsOneWidget);
    expect(find.text('source-tag'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}

Widget _buildTestApp({
  TextScaler textScaler = TextScaler.noScaling,
  ValueChanged<bool>? onResult,
}) {
  return ProviderScope(
    overrides: [
      tagLibraryNotifierProvider.overrideWith(_TestTagLibraryNotifier.new),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              final result = await AddToLibraryDialog.show(
                context,
                content: '1girl, blue hair, detailed background',
                defaultName: 'A long localized library entry name',
                sourceTag: 'source-tag',
              );
              onResult?.call(result);
            },
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
}

class _TestTagLibraryNotifier extends TagLibraryNotifier {
  @override
  TagLibraryState build() => const TagLibraryState();
}
