import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/danbooru_login_dialog.dart';

void main() {
  for (final width in [320.0, 1600.0]) {
    testWidgets('form, error, and actions stay reachable with IME at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            danbooruAuthProvider.overrideWith(_FailingDanbooruAuth.new),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(3),
                viewInsets: const EdgeInsets.only(bottom: 280),
              ),
              child: child!,
            ),
            home: const DanbooruLoginDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byType(DanbooruLoginDialog),
            matching: find.byType(Scrollable),
          )
          .first;
      expect(scrollable, findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Login'),
        120,
        scrollable: scrollable,
      );
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump();
      expect(find.text('Authentication failed'), findsOneWidget);
      expect(
        tester.getRect(find.widgetWithText(FilledButton, 'Login')).bottom,
        lessThanOrEqualTo(900),
      );
      tester.state<FormState>(find.byType(Form)).validate();
      await tester.pump();
      expect(
        tester
            .widgetList<InputDecorator>(find.byType(InputDecorator))
            .where((input) => input.decoration.errorText != null),
        hasLength(2),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

class _FailingDanbooruAuth extends DanbooruAuth {
  @override
  DanbooruAuthState build() =>
      const DanbooruAuthState(error: 'Authentication failed');

  @override
  Future<bool> login(String username, String apiKey) async => false;
}
