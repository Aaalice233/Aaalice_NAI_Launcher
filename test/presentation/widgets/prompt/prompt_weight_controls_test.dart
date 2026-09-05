import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/grunge_palette.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/prompt/prompt_action_overlay.dart';
import 'package:nai_launcher/presentation/widgets/prompt/prompt_weight_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('short translation keeps actions compact and aligned', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: resolveLayeredSurfaceColors(
            const GrungePalette().darkScheme,
          ),
        ),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('toolbar-preview'),
              child: ColoredBox(
                color: const Color(0xff292929),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: PromptActionSurface(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: PromptWeightControls(
                          weight: 1,
                          onWeight: (_) {},
                          onStep: (_) {},
                          caption: const Text(
                            '黑衬衫',
                            style: TextStyle(fontSize: 13),
                          ),
                          trailing: [
                            IconButton(
                              tooltip: '停用',
                              onPressed: () {},
                              icon: const Icon(
                                Icons.visibility_off_outlined,
                                size: 18,
                              ),
                            ),
                          ],
                          onClose: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final surface = tester.getSize(find.byType(PromptActionSurface));
    expect(surface.width, lessThan(340));
    expect(surface.height, lessThan(70));
    final y = tester.getCenter(find.byIcon(Icons.remove)).dy;
    for (final icon in [
      Icons.add,
      Icons.refresh,
      Icons.visibility_off_outlined,
      Icons.close,
    ]) {
      expect(tester.getCenter(find.byIcon(icon)).dy, closeTo(y, 1));
    }
    expect(
      tester.getBottomLeft(find.text('黑衬衫')).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(const ValueKey('prompt-weight-value'))).dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
