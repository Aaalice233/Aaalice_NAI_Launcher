import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/themes/core/input_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/auth/auth_mode_switcher.dart';
import 'package:nai_launcher/presentation/widgets/auth/credentials_login_form.dart';
import 'package:nai_launcher/presentation/widgets/auth/login_form_container.dart';
import 'package:nai_launcher/presentation/widgets/auth/third_party_api_login_card.dart';
import 'package:nai_launcher/presentation/widgets/common/floating_label_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _ErrorAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.error,
    errorCode: AuthErrorCode.tokenInvalid,
  );
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
    expect(find.text(l10n.auth_tokenLoginCompact), findsOneWidget);
    _expectSingleRowInTokenFirstOrder(tester);

    final context = tester.element(find.byKey(const Key('token_form')));
    final expectedFill = inputSurfaceFillColor(Theme.of(context).colorScheme);
    final decorators = tester.widgetList<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('token_form')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(decorators, isNotEmpty);
    for (final decorator in decorators) {
      expect(decorator.decoration.filled, isTrue);
      expect(decorator.decoration.fillColor, expectedFill);
    }
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
        expect(find.text(l10n.auth_tokenLoginCompact), findsOneWidget);
        expect(find.text(l10n.auth_credentialsLogin), findsOneWidget);
        expect(find.text(l10n.auth_thirdPartyLogin), findsOneWidget);
        _expectSingleRowInTokenFirstOrder(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('wide auth modes retain the recommended token label', (
    tester,
  ) async {
    await _pumpModeSwitcher(tester, const Locale('zh'), width: 520);

    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const Key('auth_mode_switcher'))),
    )!;
    expect(find.text(l10n.auth_tokenLoginRecommended), findsOneWidget);
    expect(find.text(l10n.auth_tokenLoginCompact), findsNothing);
  });

  testWidgets(
    'credentials actions reflow at 320 width with 3x text and keep touch targets',
    (tester) async {
      await _pumpCredentialsForm(
        tester,
        width: 320,
        textScaler: const TextScaler.linear(3),
        policy: const InteractionPolicy(
          modality: InteractionModality.touch,
          touchAvailable: true,
          precisePointerAvailable: false,
        ),
      );

      final checkbox = find.byKey(const Key('credentials_auto_login_checkbox'));
      final forgotPassword = find.byKey(
        const Key('credentials_forgot_password'),
      );
      expect(tester.getSize(checkbox), const Size.square(48));
      expect(tester.getSize(forgotPassword).height, greaterThanOrEqualTo(48));
      expect(
        tester.getTopLeft(forgotPassword).dy,
        greaterThan(tester.getTopLeft(checkbox).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'login forms do not mutate a pre-existing auth error while building',
    (tester) async {
      await _pumpLoginForm(
        tester,
        const Locale('zh'),
        startsWithAuthError: true,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('auth_mode_credentials')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('auth_mode_third_party')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'third-party streaming hint keeps the exact settings path on narrow layouts for $locale',
      (tester) async {
        await _pumpThirdPartyCard(tester, locale);

        final hintFinder = find.byKey(const Key('third_party_streaming_hint'));
        final l10n = AppLocalizations.of(tester.element(hintFinder))!;
        final hint = l10n.auth_thirdPartyStreamingHint;

        expect(find.text(hint), findsOneWidget);
        expect(hint, contains(l10n.settings_title));
        expect(hint, contains(l10n.settings_generation));
        expect(hint, contains(l10n.settings_generationOutputSection));
        expect(hint, contains(l10n.settings_generationStreamPreview));

        final hintRect = tester.getRect(hintFinder);
        final cardRect = tester.getRect(find.byType(ThirdPartyApiLoginCard));
        expect(hintRect.left, greaterThanOrEqualTo(cardRect.left));
        expect(hintRect.right, lessThanOrEqualTo(cardRect.right));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pumpLoginForm(
  WidgetTester tester,
  Locale locale, {
  bool startsWithAuthError = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(450, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          startsWithAuthError ? _ErrorAuthNotifier.new : _FakeAuthNotifier.new,
        ),
      ],
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

Future<void> _pumpCredentialsForm(
  WidgetTester tester, {
  required double width,
  required TextScaler textScaler,
  required InteractionPolicy policy,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authNotifierProvider.overrideWith(_FakeAuthNotifier.new)],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InteractionPolicyScope(
          initialPolicy: policy,
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1200),
              textScaler: textScaler,
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: CredentialsLoginForm(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpThirdPartyCard(WidgetTester tester, Locale locale) async {
  await tester.binding.setSurfaceSize(const Size(360, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authNotifierProvider.overrideWith(_FakeAuthNotifier.new)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: ThirdPartyApiLoginCard(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpModeSwitcher(
  WidgetTester tester,
  Locale locale, {
  double width = 370,
}) async {
  await tester.binding.setSurfaceSize(Size(width + 80, 300));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: const AuthModeSwitcher()),
          ),
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
