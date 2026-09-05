import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/presentation/widgets/prompt/prompt_translation_controller.dart';

void main() {
  testWidgets(
    'debounces committed input, deduplicates and rejects stale responses',
    (tester) async {
      final requests = <String, Completer<Map<String, String>>>{};
      final controller = PromptTranslationController(
        TagTranslationLookup.fromResolver((tags) {
          final request = Completer<Map<String, String>>();
          requests[tags.join(',')] = request;
          return request.future;
        }),
      );
      addTearDown(controller.dispose);
      controller.update(['cat', 'cat'], immediate: true);
      await tester.pump();
      controller.update(['dog'], composing: true);
      await tester.pump(const Duration(milliseconds: 200));
      expect(requests.keys, ['cat']);
      requests['cat']!.complete({'cat': '猫'});
      await tester.pump();
      expect(controller.values.keys, ['dog']);
      expect(controller.values['dog']!.status, PromptTranslationStatus.pending);
      controller.update(['dog']);
      await tester.pump(const Duration(milliseconds: 149));
      expect(requests.containsKey('dog'), isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      requests['dog']!.complete({'dog': '狗'});
      await tester.pump();
      expect(controller.values['dog']!.text, '狗');
    },
  );
  testWidgets('failed lookup can retry and absence has its own status', (
    tester,
  ) async {
    var fail = true;
    final controller = PromptTranslationController(
      TagTranslationLookup.fromResolver((tags) async {
        if (fail) throw StateError('dictionary unavailable');
        return {};
      }),
    );
    addTearDown(controller.dispose);
    controller.update(['missing'], immediate: true);
    await tester.pump();
    expect(
      controller.values['missing']!.status,
      PromptTranslationStatus.failed,
    );
    fail = false;
    controller.retry();
    await tester.pump();
    expect(
      controller.values['missing']!.status,
      PromptTranslationStatus.missing,
    );
  });
}
