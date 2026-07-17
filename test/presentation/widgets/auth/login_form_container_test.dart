import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/widgets/auth/auth_mode_switcher.dart';
import 'package:nai_launcher/presentation/widgets/auth/login_form_container.dart';
import 'package:nai_launcher/presentation/widgets/common/floating_label_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('API Token is recommended, first, and selected by default', (
    tester,
  ) async {
    await _pumpLoginForm(tester, const Locale('zh'));

    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const Key('auth_mode_switcher'))),
    )!;

    expect(find.byKey(const Key('token_form')), findsOneWidget);
    expect(find.text(l10n.auth_tokenLoginRecommended), findsOneWidget);
    _expectSingleRowInTokenFirstOrder(tester);
  });

  testWidgets('email and password mode is enabled and opens its form', (
    tester,
  ) async {
    await _pumpLoginForm(tester, const Locale('zh'));

    await tester.tap(find.byKey(const Key('auth_mode_credentials')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('credentials_form')), findsOneWidget);
    expect(find.byType(FloatingLabelInput), findsNWidgets(2));
    expect(find.byType(FloatingLabelPasswordInput), findsOneWidget);

    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const Key('credentials_form'))),
    )!;
    final labels = tester
        .widgetList<FloatingLabelInput>(find.byType(FloatingLabelInput))
        .map((input) => input.label);
    expect(labels, containsAll(<String>[l10n.auth_email, l10n.auth_password]));
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'auth modes stay in one row at dialog width for ${locale.languageCode}',
      (tester) async {
        await _pumpModeSwitcher(tester, locale);

        final l10n = AppLocalizations.of(
          tester.element(find.byKey(const Key('auth_mode_switcher'))),
        )!;
        expect(find.text(l10n.auth_tokenLoginRecommended), findsOneWidget);
        expect(find.text(l10n.auth_credentialsLogin), findsOneWidget);
        expect(find.text(l10n.auth_thirdPartyLogin), findsOneWidget);
        _expectSingleRowInTokenFirstOrder(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pumpLoginForm(WidgetTester tester, Locale locale) async {
  await tester.binding.setSurfaceSize(const Size(450, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authNotifierProvider.overrideWith(_FakeAuthNotifier.new)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 402,
              child: SingleChildScrollView(child: LoginFormContainer()),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpModeSwitcher(WidgetTester tester, Locale locale) async {
  await tester.binding.setSurfaceSize(const Size(450, 300));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(child: SizedBox(width: 370, child: AuthModeSwitcher())),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectSingleRowInTokenFirstOrder(WidgetTester tester) {
  final token = find.byKey(const Key('auth_mode_token'));
  final credentials = find.byKey(const Key('auth_mode_credentials'));
  final thirdParty = find.byKey(const Key('auth_mode_third_party'));

  final tokenTopLeft = tester.getTopLeft(token);
  final credentialsTopLeft = tester.getTopLeft(credentials);
  final thirdPartyTopLeft = tester.getTopLeft(thirdParty);
  expect(tokenTopLeft.dx, lessThan(credentialsTopLeft.dx));
  expect(credentialsTopLeft.dx, lessThan(thirdPartyTopLeft.dx));
  expect(tokenTopLeft.dy, moreOrLessEquals(credentialsTopLeft.dy));
  expect(credentialsTopLeft.dy, moreOrLessEquals(thirdPartyTopLeft.dy));

  final tokenWidth = tester.getSize(token).width;
  expect(tokenWidth, moreOrLessEquals(tester.getSize(credentials).width));
  expect(tokenWidth, moreOrLessEquals(tester.getSize(thirdParty).width));
}
