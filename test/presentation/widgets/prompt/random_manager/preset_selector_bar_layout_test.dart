import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_group_sync_provider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/preset_selector_bar.dart';

// flutter_test 字体每个字形 1em：英文约为真实两倍作压力场景，日文接近真实
const _locales = [Locale('en'), Locale('ja')];
const _widths = [320.0, 600.0, 840.0, 1180.0, 1600.0];
const _textScales = [1.0, 3.0];
const _minTouchExtent = 44.0;
const _landscapePadding = FakeViewPadding(left: 32, right: 32, bottom: 16);

class _FixedPresetNotifier extends RandomPresetNotifier {
  @override
  RandomPresetState build() => const RandomPresetState(
    presets: [
      RandomPreset(id: 'preset', name: 'Preset', isBasedOnDefault: true),
    ],
    selectedPresetId: 'preset',
  );
}

/// 同步服务依赖本地存储，布局测试只需要空闲状态
class _IdleSyncNotifier extends TagGroupSyncNotifier {
  @override
  TagGroupSyncState build() => const TagGroupSyncState();
}

Finder _moreActions() =>
    find.byKey(const ValueKey('random-manager-more-actions'));

Future<void> _pumpBar(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required Locale locale,
  FakeViewPadding padding = FakeViewPadding.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        randomPresetNotifierProvider.overrideWith(_FixedPresetNotifier.new),
        tagGroupSyncNotifierProvider.overrideWith(_IdleSyncNotifier.new),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => InteractionPolicyScope(
          initialPolicy: InteractionPolicy.touchFirst,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topCenter,
                child: PresetSelectorBar(
                  showWorkspaceHeading: true,
                  onImportExport: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectHittable(WidgetTester tester, Finder control, String reason) {
  final rect = tester.getRect(control);
  final target = tester.renderObject(control);
  expect(
    tester
        .hitTestOnBinding(rect.center)
        .path
        .any((entry) => entry.target == target),
    isTrue,
    reason: '可点中 $reason',
  );
  expect(
    rect.shortestSide,
    greaterThanOrEqualTo(_minTouchExtent),
    reason: '命中区 $reason',
  );
}

/// 从更多操作菜单打开确认弹窗，断言无溢出、弹窗在安全区内且取消与确认都能点中
Future<void> _expectConfirmUsable(
  WidgetTester tester, {
  required String menuItem,
  required String title,
  required String confirm,
  required Size size,
  required String reason,
}) async {
  await tester.tap(_moreActions());
  await tester.pumpAndSettle();
  // 放大文字的短横屏里菜单本身也要滚动，末尾的危险操作需先滚到可见
  final item = find.text(menuItem).last;
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
  expect(find.text(title), findsOneWidget, reason: reason);
  expect(tester.takeException(), isNull, reason: reason);

  final dialog = tester.getRect(find.byType(AlertDialog));
  expect(dialog.left, greaterThanOrEqualTo(0), reason: reason);
  expect(dialog.right, lessThanOrEqualTo(size.width), reason: reason);
  expect(dialog.bottom, lessThanOrEqualTo(size.height), reason: reason);
  final l10n = lookupAppLocalizations(const Locale('en'));
  for (final label in [l10n.common_cancel, confirm]) {
    _expectHittable(
      tester,
      find.ancestor(
        of: find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(label),
        ),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      ),
      '$label $reason',
    );
  }
  await tester.tap(find.text(l10n.common_cancel));
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in _locales) {
    for (final textScale in _textScales) {
      testWidgets(
        '${locale.languageCode} 预设栏标题行在 320–1600 宽度、${textScale}x 文字下不溢出且更多操作可点',
        (tester) async {
          for (final width in _widths) {
            final reason = 'width=$width scale=$textScale';
            await _pumpBar(
              tester,
              size: Size(width, 900),
              textScale: textScale,
              locale: locale,
            );
            expect(tester.takeException(), isNull, reason: reason);
            final heading = tester.getRect(
              find.byKey(const ValueKey('random-manager-heading-row')),
            );
            expect(heading.left, greaterThanOrEqualTo(0), reason: reason);
            expect(heading.right, lessThanOrEqualTo(width), reason: reason);
            final more = find.descendant(
              of: _moreActions(),
              matching: find.byType(IconButton),
            );
            final moreRect = tester.getRect(more);
            expect(moreRect.left, greaterThanOrEqualTo(heading.left));
            expect(moreRect.right, lessThanOrEqualTo(heading.right + 0.5));
            _expectHittable(tester, more, 'more $reason');
          }
        },
      );
    }
  }

  testWidgets('删除与重置预设的确认弹窗在短横屏和最窄屏放大文字下操作可点', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    for (final (size, padding) in [
      (const Size(740, 360), _landscapePadding),
      (const Size(320, 568), FakeViewPadding.zero),
    ]) {
      for (final textScale in _textScales) {
        final reason = 'size=$size scale=$textScale';
        await _pumpBar(
          tester,
          size: size,
          textScale: textScale,
          locale: const Locale('en'),
          padding: padding,
        );
        await _expectConfirmUsable(
          tester,
          menuItem: l10n.common_delete,
          title: l10n.config_deletePreset,
          confirm: l10n.common_delete,
          size: size,
          reason: 'delete $reason',
        );
        await _expectConfirmUsable(
          tester,
          menuItem: l10n.randomManager_resetDefaultConfirm,
          title: l10n.randomManager_resetDefaultTitle,
          confirm: l10n.randomManager_resetDefaultConfirm,
          size: size,
          reason: 'reset $reason',
        );
      }
    }
  });
}
