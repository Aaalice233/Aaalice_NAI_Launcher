/// 浅色主题可读性检查工具。
///
/// 生成页的折叠面板（[CollapsibleImagePanel] 家族）在折叠且有图时，会在
/// 缩略图上盖一层深色渐变，此时 header 用白色文字是正确的。但面板展开后
/// 背景图不再渲染，内容直接贴在 Card 表面上——那里写死 `Colors.white`
/// 就会在浅色主题下变成白底白字。
///
/// 这组工具在浅色主题下渲染面板，找出所有"贴着面板底色却是近白色"的文字。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 判定"近白色"的相对亮度阈值。
///
/// 浅色主题的 `onSurface` / `onSurfaceVariant` 亮度通常在 0.05 以下，
/// 而 `Colors.white70` 这类值的 `computeLuminance()` 仍为 1.0（该方法
/// 不计 alpha），因此 0.5 能干净地把两类分开。
const double _nearWhiteLuminance = 0.5;

/// 创建一个不触碰真实存储的 [ProviderContainer]。
///
/// 生成页面板会在构建时读写设置（放大参数、增强开关等），未初始化 Hive
/// 时会抛 `Box not found`。这里统一替换成内存实现，让面板能独立渲染。
ProviderContainer createStorageFreeContainer({
  List<Override> overrides = const [],
}) {
  SharedPreferences.setMockInitialValues(const {});
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWith(
        (ref) => InMemoryLocalStorageService(),
      ),
      ...overrides,
    ],
  );
}

/// 把 Hive 指向一个临时目录，并在测试结束后清理。
///
/// 少数面板（如 Vibe 参考面板）会直接通过存储服务打开 box，无法只靠
/// 替换 [LocalStorageService] 绕开，需要一个真实但一次性的 Hive 根目录。
Future<void> setUpTemporaryHive() async {
  final tempDir = await Directory.systemTemp.createTemp('nai_light_theme_test');
  Hive.init(tempDir.path);
  addTearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });
}

/// 纯内存的 [LocalStorageService]，供 widget 测试替换真实 Hive 实现。
class InMemoryLocalStorageService extends LocalStorageService {
  final Map<String, Object?> _values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = _values.containsKey(key) ? _values[key] : defaultValue;
    return value as T?;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _values.remove(key);
  }
}

/// 在浅色主题下渲染 [panel]。
///
/// 统一注入本地化与 [ThemeData.light]，避免每个面板测试重复样板。
Future<void> pumpPanelInLightTheme(
  WidgetTester tester, {
  required ProviderContainer container,
  required Widget panel,
  Size surfaceSize = const Size(1400, 1600),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.light(),
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: SingleChildScrollView(child: panel)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 收集"画在面板底色上却是近白色"的文字，返回可读的问题描述列表。
///
/// 画在自带深色底的控件（FilledButton、SegmentedButton 选中段、Chip、
/// Tooltip 等）内部的白字是合法的——那是 `onPrimary` 一类前景色，本就
/// 该与深色控件底配对，因此按祖先控件类型排除。
List<String> findUnreadableLightText(WidgetTester tester) {
  final offenders = <String>[];

  for (final element in tester.elementList(find.byType(RichText))) {
    final richText = element.widget as RichText;
    final color = richText.text.style?.color;
    if (color == null || color.computeLuminance() <= _nearWhiteLuminance) {
      continue;
    }
    // Icon 内部同样是 RichText（字体图标为私用区码点），图标的配色语义
    // 与文字可读性不同（例如禁用态本就该是灰的），不在此检查范围内。
    if (_isIconGlyph(element)) {
      continue;
    }
    // 空白文本谈不上可读性（例如未选中的下拉占位符）。
    final label = richText.text.toPlainText();
    if (label.trim().isEmpty) {
      continue;
    }
    if (_hasColoredControlAncestor(element)) {
      continue;
    }
    offenders.add('"$label" -> $color');
  }

  return offenders;
}

/// 断言浅色主题下不存在贴着面板底色的近白色文字。
void expectNoUnreadableLightText(WidgetTester tester, {String? panelName}) {
  final offenders = findUnreadableLightText(tester);
  expect(
    offenders,
    isEmpty,
    reason:
        '${panelName ?? '该面板'}在浅色主题下有文字贴着面板底色显示为近白色，'
        '无法阅读：\n${offenders.join('\n')}',
  );
}

/// 判断该 [RichText] 是否是 [Icon] 渲染出的字体图标。
bool _isIconGlyph(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget is Icon) {
      found = true;
      return false;
    }
    // Icon 到其 RichText 之间只隔几层，超出后即可停止上溯。
    return ancestor.widget is! Material;
  });
  return found;
}

/// 判断该文字是否位于自带深色底的控件内部。
bool _hasColoredControlAncestor(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    final typeName = widget.runtimeType.toString();
    if (widget is ButtonStyleButton ||
        widget is Tooltip ||
        typeName.startsWith('SegmentedButton') ||
        typeName.startsWith('RawChip') ||
        typeName.startsWith('ChoiceChip') ||
        typeName.startsWith('FilterChip') ||
        typeName.startsWith('ActionChip') ||
        typeName.startsWith('InputChip')) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}
