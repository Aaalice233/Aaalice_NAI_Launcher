import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/themes/app_theme.dart';
import 'package:nai_launcher/presentation/widgets/anlas/opus_usage_chip.dart';

class _SubscriptionStub extends SubscriptionNotifier {
  _SubscriptionStub(this._state);

  final SubscriptionState _state;

  @override
  SubscriptionState build() => _state;

  @override
  void schedulePostBillingRefresh({Duration delay = Duration.zero}) {}
}

Future<void> _pumpChip(
  WidgetTester tester,
  SubscriptionState subscription,
  String model, {
  void Function(ProviderContainer container)? configure,
  ThemeData? theme,
}) async {
  final container = ProviderContainer(
    overrides: [
      subscriptionNotifierProvider.overrideWith(
        () => _SubscriptionStub(subscription),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: OpusUsageChip())),
      ),
    ),
  );
  // pumpWidget 之后再切模型，避免 auto-dispose 调度的 Timer 悬挂在帧外。
  container
      .read(generationParamsNotifierProvider.notifier)
      .updateModel(model, persist: false, followDefaults: false);
  configure?.call(container);
  await tester.pump();
}

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

/// 徽章文字实际所在的底色：主题色（耗尽时为错误色）10% 叠在 surface 上。
Color _chipSurface(WidgetTester tester, {bool exhausted = false}) {
  final colors = Theme.of(
    tester.element(find.byType(OpusUsageChip)),
  ).colorScheme;
  final accent = exhausted ? colors.error : colors.primary;
  return Color.alphaBlend(accent.withValues(alpha: 0.1), colors.surface);
}

double _textContrast(
  WidgetTester tester,
  Finder text, {
  bool exhausted = false,
}) => _contrast(
  tester.widget<Text>(text).style!.color!,
  _chipSurface(tester, exhausted: exhausted),
);

const _drained = SubscriptionState.loaded(
  UserSubscription(
    tier: 3,
    active: true,
    usage: OpusUsageInfo(percent: 0, purchasedPercent: 200),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const opusWithUsage = SubscriptionState.loaded(
    UserSubscription(
      tier: 3,
      active: true,
      usage: OpusUsageInfo(percent: 98, timeUntilNextPercent: 4800),
    ),
  );

  testWidgets('shows the remaining percent on V5 for Opus accounts', (
    tester,
  ) async {
    await _pumpChip(tester, opusWithUsage, ImageModels.animeDiffusionV5Curated);

    expect(find.text('98%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('shows overflow quota without capping the text or estimate', (
    tester,
  ) async {
    const overflowUsage = SubscriptionState.loaded(
      UserSubscription(
        tier: 3,
        active: true,
        usage: OpusUsageInfo(percent: 192),
      ),
    );

    await _pumpChip(tester, overflowUsage, ImageModels.animeDiffusionV5Curated);

    expect(find.text('192%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, contains('About 3322 images left'));
  });

  testWidgets('uses the max enhance billing area for the image estimate', (
    tester,
  ) async {
    await _pumpChip(
      tester,
      opusWithUsage,
      ImageModels.animeDiffusionV5Curated,
      configure: (container) {
        final notifier = container.read(
          generationParamsNotifierProvider.notifier,
        );
        notifier.updateSize(832, 1216, persist: false);
        notifier.updateUpscaledEnhance(true);
      },
    );

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, contains('About 424 images left'));
  });

  testWidgets('stays hidden on models without the quota pool', (tester) async {
    await _pumpChip(tester, opusWithUsage, ImageModels.animeDiffusionV45Full);

    expect(find.byType(Tooltip), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('stays hidden when the subscription has no usage info', (
    tester,
  ) async {
    const opusWithoutUsage = SubscriptionState.loaded(
      UserSubscription(tier: 3, active: true),
    );

    await _pumpChip(
      tester,
      opusWithoutUsage,
      ImageModels.animeDiffusionV5Curated,
    );

    expect(find.byType(Tooltip), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('switches to the exhausted style when the quota is negative', (
    tester,
  ) async {
    const exhausted = SubscriptionState.loaded(
      UserSubscription(
        tier: 3,
        active: true,
        usage: OpusUsageInfo(percent: -2, isNegative: true),
      ),
    );

    await _pumpChip(tester, exhausted, ImageModels.animeDiffusionV5Curated);

    expect(find.text('0%'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_bottom_rounded), findsOneWidget);
  });

  testWidgets('keeps the regular-only chip unchanged without extra usage', (
    tester,
  ) async {
    await _pumpChip(tester, opusWithUsage, ImageModels.animeDiffusionV5Curated);

    expect(
      find.byKey(const ValueKey('opus-usage-extra-percent')),
      findsNothing,
    );
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(
      tooltip.message,
      '98% of Opus Generations remaining\n'
      'About 1695 images left\n'
      'The allowance refills automatically over time',
    );
  });

  testWidgets('appends the extra usage pool once the regular pool is empty', (
    tester,
  ) async {
    await _pumpChip(tester, _drained, ImageModels.animeDiffusionV5Curated);

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('+200%'), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_bottom_rounded), findsNothing);
    expect(_textContrast(tester, find.text('0%')), greaterThanOrEqualTo(4.5));
    expect(
      _textContrast(tester, find.text('+200%')),
      greaterThanOrEqualTo(4.5),
    );

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(
      tooltip.message,
      'Opus Generations remaining\n'
      'Regular: 0% (refills over time)\n'
      'Extra Usage: +200% (does not refill)\n'
      'About 3460 images left across both',
    );
  });

  testWidgets('shows a nearly empty extra pool as 1% everywhere', (
    tester,
  ) async {
    const nearlyEmpty = SubscriptionState.loaded(
      UserSubscription(
        tier: 3,
        active: true,
        usage: OpusUsageInfo(percent: 0, purchasedPercent: 0.3),
      ),
    );

    await _pumpChip(tester, nearlyEmpty, ImageModels.animeDiffusionV5Curated);

    expect(find.text('+0%'), findsNothing);
    expect(find.text('+1%'), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, contains('Extra Usage: +1% (does not refill)'));
    expect(tooltip.message, isNot(contains('+0%')));
    // 0.3 × 17.3 ≈ 5 张，估算仍按真实余量。
    expect(tooltip.message, contains('About 5 images left across both'));
  });

  for (final style in AppStyle.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${style.name}/${brightness.name}: chip percents stay legible',
        (tester) async {
          await _pumpChip(
            tester,
            _drained,
            ImageModels.animeDiffusionV5Curated,
            theme: AppTheme.getTheme(style, brightness),
          );

          expect(
            _textContrast(tester, find.text('+200%')),
            greaterThanOrEqualTo(4.5),
            reason: 'extra usage',
          );
          expect(
            _textContrast(tester, find.text('0%')),
            greaterThanOrEqualTo(4.5),
            reason: 'regular allowance',
          );
        },
      );

      testWidgets(
        '${style.name}/${brightness.name}: exhausted percent stays legible',
        (tester) async {
          await _pumpChip(
            tester,
            const SubscriptionState.loaded(
              UserSubscription(
                tier: 3,
                active: true,
                usage: OpusUsageInfo(percent: -1, isNegative: true),
              ),
            ),
            ImageModels.animeDiffusionV5Curated,
            theme: AppTheme.getTheme(style, brightness),
          );

          expect(
            _textContrast(tester, find.text('0%'), exhausted: true),
            greaterThanOrEqualTo(4.5),
            reason: 'exhausted allowance',
          );
        },
      );
    }
  }

  testWidgets('estimates images from both pools and the billing area', (
    tester,
  ) async {
    const boosted = SubscriptionState.loaded(
      UserSubscription(
        tier: 3,
        active: true,
        usage: OpusUsageInfo(percent: 192, purchasedPercent: 100),
      ),
    );

    await _pumpChip(
      tester,
      boosted,
      ImageModels.animeDiffusionV5Curated,
      configure: (container) {
        final notifier = container.read(
          generationParamsNotifierProvider.notifier,
        );
        notifier.updateSize(832, 1216, persist: false);
        notifier.updateUpscaledEnhance(true);
      },
    );

    expect(find.text('192%'), findsOneWidget);
    expect(find.text('+100%'), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    // (192 + 100) × 17.3 ÷ 4 份。
    expect(tooltip.message, contains('About 1263 images left'));
  });

  testWidgets('keeps the exhausted style even when extra usage is reported', (
    tester,
  ) async {
    const exhausted = SubscriptionState.loaded(
      UserSubscription(
        tier: 3,
        active: true,
        usage: OpusUsageInfo(
          percent: -1,
          isNegative: true,
          purchasedPercent: 100,
        ),
      ),
    );

    await _pumpChip(tester, exhausted, ImageModels.animeDiffusionV5Curated);

    expect(find.text('0%'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('opus-usage-extra-percent')),
      findsNothing,
    );
    expect(find.byIcon(Icons.hourglass_bottom_rounded), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(
      tooltip.message,
      'Your Opus allowance is used up. '
      'V5 generations will cost Anlas until it refills.',
    );
  });

  testWidgets('stays hidden for non-Opus tiers', (tester) async {
    const scroll = SubscriptionState.loaded(
      UserSubscription(
        tier: 2,
        active: true,
        usage: OpusUsageInfo(percent: 50),
      ),
    );

    await _pumpChip(tester, scroll, ImageModels.animeDiffusionV5Curated);

    expect(find.byType(Tooltip), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
