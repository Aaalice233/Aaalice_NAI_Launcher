import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/data/services/discord_share_service.dart';
import 'package:nai_launcher/presentation/providers/discord_share_task_provider.dart';

class _Service extends Mock implements DiscordShareService {
  final calls = <Set<String>>[];
  final results = <Completer<DiscordShareResult>>[];
  @override
  Future<DiscordShareResult> share({
    required DiscordShareSession session,
    required SanitizedShareImage image,
    required Set<String> targetIds,
    required String prompt,
    required String caption,
    required int? width,
    required int? height,
    required bool longPromptAsFile,
  }) {
    calls.add(Set.of(targetIds));
    final result = Completer<DiscordShareResult>();
    results.add(result);
    return result.future;
  }
}

DiscordShareSubmission _submission(Uint8List bytes, Set<String> ids) =>
    DiscordShareSubmission(
      session: const DiscordShareSession(
        token: 'test',
        user: DiscordShareUser(id: '1', username: 'tester'),
      ),
      bytes: bytes,
      fileName: 'image.png',
      stripMetadata: true,
      targetIds: ids,
      prompt: 'original prompt',
      caption: '',
      width: 1,
      height: 1,
      longPromptAsFile: false,
    );

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'snapshot survives caller changes and partial retry sends only failed IDs',
    () async {
      final service = _Service();
      Uint8List? prepared;
      final notifier = DiscordShareTaskNotifier(
        service,
        prepare: (bytes, {required fileName, required stripMetadata}) async {
          prepared = bytes;
          return SanitizedShareImage(
            bytes: bytes,
            fileName: fileName,
            mimeType: 'image/png',
          );
        },
      );
      addTearDown(notifier.dispose);
      final bytes = Uint8List.fromList([1, 2, 3]);
      final ids = {'first', 'second'};
      final snapshot = _submission(bytes, ids);
      bytes[0] = 9;
      ids.clear();
      notifier.submit(snapshot);
      await _flush();
      expect(prepared, orderedEquals([1, 2, 3]));
      expect(service.calls.single, {'first', 'second'});
      expect(notifier.state!.running, isTrue);
      expect(
        () => notifier.submit(snapshot),
        throwsA(isA<DiscordShareException>()),
      );
      service.results.first.complete(
        const DiscordShareResult(
          deliveredTargets: ['First'],
          failedTargets: ['Second'],
          failedTargetIds: ['second'],
        ),
      );
      await _flush();
      expect(notifier.state!.canRetry, isTrue);
      notifier.retry();
      await _flush();
      expect(service.calls.last, {'second'});
      service.results.last.complete(
        const DiscordShareResult(
          deliveredTargets: ['Second'],
          failedTargets: [],
        ),
      );
      await _flush();
      expect(notifier.state!.canRetry, isFalse);
      notifier.retry();
      expect(service.calls, hasLength(2));
    },
  );

  test(
    'rate limit retains manual retry and never automatically resends',
    () async {
      final service = _Service();
      final notifier = DiscordShareTaskNotifier(
        service,
        prepare: (bytes, {required fileName, required stripMetadata}) async =>
            SanitizedShareImage(
              bytes: bytes,
              fileName: fileName,
              mimeType: 'image/png',
            ),
      );
      addTearDown(notifier.dispose);
      notifier.submit(_submission(Uint8List(1), {'first'}));
      await _flush();
      service.results.single.completeError(
        const DiscordShareException(
          code: 'rate_limited',
          message: 'limited',
          retryAfter: Duration(seconds: 5),
        ),
      );
      await _flush();
      expect(notifier.state!.retrySeconds, 5);
      notifier.retry();
      await _flush();
      expect(service.calls, hasLength(1));
      expect(notifier.state!.error, isA<DiscordShareException>());
    },
  );

  test(
    'disposing owner during image preparation does not begin a send',
    () async {
      final service = _Service();
      final prepared = Completer<SanitizedShareImage>();
      final notifier = DiscordShareTaskNotifier(
        service,
        prepare: (bytes, {required fileName, required stripMetadata}) =>
            prepared.future,
      );
      notifier.submit(_submission(Uint8List(1), {'first'}));
      notifier.dispose();
      prepared.complete(
        SanitizedShareImage(
          bytes: Uint8List(1),
          fileName: 'image.png',
          mimeType: 'image/png',
        ),
      );
      await _flush();
      expect(service.calls, isEmpty);
    },
  );
}
