import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

import '../../../../helpers/memory_local_storage.dart';

Future<void> _pumpInput(
  WidgetTester tester,
  TextEditingController host,
  ValueNotifier<bool> separate, {
  FocusNode? focusNode,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => MemoryLocalStorage()),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.pointer,
            touchAvailable: false,
            precisePointerAvailable: true,
          ),
          child: Scaffold(
            body: SizedBox(
              width: 720,
              height: 160,
              child: ValueListenableBuilder<bool>(
                valueListenable: separate,
                builder: (context, enabled, _) => UnifiedPromptInput(
                  controller: host,
                  focusNode: focusNode,
                  enableAssistant: false,
                  config: UnifiedPromptConfig(
                    enableAutocomplete: false,
                    enableAutoFormat: false,
                    enableRegexReplace: false,
                    separateNumericWeightClosing: enabled,
                  ),
                  maxLines: null,
                  expands: true,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _wheelWeight(WidgetTester tester, String text, String part) async {
  await tester.tap(find.byType(EditableText).first);
  await tester.pump();
  final start = text.indexOf(part);
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + part.length,
      ),
    ),
  );
  await tester.pump();
  final pointer = TestPointer(1, PointerDeviceKind.mouse)
    ..hover(tester.getCenter(find.byType(EditableText).first));
  await tester.sendEventToBinding(pointer.scroll(const Offset(0, -40)));
  await tester.pump();
}

void main() {
  testWidgets('wheel weights follow the option, including later toggles', (
    tester,
  ) async {
    const text = 'year_2025, b';
    final host = TextEditingController(text: text);
    final separate = ValueNotifier(false);
    addTearDown(host.dispose);
    addTearDown(separate.dispose);
    await _pumpInput(tester, host, separate);

    await _wheelWeight(tester, text, 'year_2025');
    expect(host.text, '1.05::year_2025::, b');

    host.text = text;
    separate.value = true;
    await tester.pump();
    await _wheelWeight(tester, text, 'year_2025');
    expect(host.text, '1.05::year_2025 ::, b');
  });

  testWidgets('blur separates existing closings only when enabled', (
    tester,
  ) async {
    const text = '1.05::year_2025::, b';
    final host = TextEditingController();
    final focusNode = FocusNode();
    final separate = ValueNotifier(false);
    addTearDown(host.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(separate.dispose);
    await _pumpInput(tester, host, separate, focusNode: focusNode);

    Future<void> typeAndBlur() async {
      host.text = text;
      focusNode.requestFocus();
      await tester.pump();
      focusNode.unfocus();
      await tester.pump();
      // 改写后弹 Toast，推过它的自动关闭，避免残留定时器
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    }

    await typeAndBlur();
    expect(host.text, text);

    separate.value = true;
    await tester.pump();
    await typeAndBlur();
    expect(host.text, '1.05::year_2025 ::, b');
  });
}
