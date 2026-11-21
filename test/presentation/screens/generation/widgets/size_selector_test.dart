import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/focused_inpaint_utils.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/size_selector.dart';

void main() {
  testWidgets(
    'focused request size and resolution controls remain visible on desktop and Android',
    (tester) async {
      const selection = Rect.fromLTWH(288, 900, 1088, 576);
      final geometry = FocusedInpaintUtils.resolveGeometryForSelection(
        sourceWidth: 1664,
        sourceHeight: 2432,
        selectionRect: selection,
        minContextMegaPixels: 96,
      );
      for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
        (int, int)? requestedSize;
        await tester.binding.setSurfaceSize(Size(width, 720));
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizeSelector(
                  key: ValueKey(width),
                  width: 1664,
                  height: 2432,
                  onChanged: (width, height) => requestedSize = (width, height),
                  requestGeometry: AsyncData(geometry),
                ),
              ),
            ),
          ),
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(SizeSelector)),
        )!;
        expect(find.text(l10n.editor_requestedSize(1280, 768)), findsOneWidget);
        expect(
          find.byKey(const ValueKey('invalid-resolution-hint')),
          findsNothing,
        );
        expect(find.text('1664'), findsOneWidget);
        expect(find.text('2432'), findsOneWidget);
        final swap = find.byTooltip(l10n.common_swap);
        await tester.ensureVisible(swap);
        await tester.tap(swap);
        expect(requestedSize, (2432, 1664));
        expect(tester.takeException(), isNull, reason: 'width=$width');
      }
      await tester.binding.setSurfaceSize(null);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets('shows a valid 64-grid suggestion for custom resolution', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizeSelector(width: 1080, height: 1920, onChanged: (_, _) {}),
        ),
      ),
    );

    expect(
      find.text(
        '1080×1920 无法用于生成。宽度和高度必须是 64 的倍数、单边不能超过 4096，且总像素'
        '不能超过 3,145,728。最接近的可用尺寸是 1088×1920。',
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not warn for a valid 64-grid resolution', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizeSelector(width: 1088, height: 1920, onChanged: (_, _) {}),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('invalid-resolution-hint')), findsNothing);
  });
}
