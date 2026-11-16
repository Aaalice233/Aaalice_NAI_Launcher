import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_preview_publication.dart';

import '../../../helpers/controlled_preview_images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ControlledPreviewImages images;
  late StreamPreviewPublication owner;
  late AppLifecycleState? lifecycle;
  late bool current;
  late List<(int, bool)> published;

  setUp(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    images = ControlledPreviewImages();
    lifecycle = AppLifecycleState.resumed;
    current = true;
    published = [];
    owner = StreamPreviewPublication(
      resolve: images.resolve,
      lifecycle: () => lifecycle,
    );
  });
  tearDown(() {
    owner.clear();
    images.dispose();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  void add(int value, {int slot = 0}) => owner.add(
    slot: slot,
    frame: StreamPreviewFrame(bytes: Uint8List.fromList([value])),
    isCurrent: () => current,
    publish: (latest) => published.add((value, latest)),
  );

  test('slow decodes publish monotonically despite newer arrivals', () async {
    add(1);
    add(2);
    add(3);
    expect(images.requests, hasLength(2));
    images.complete(0);
    await pumpEventQueue();
    expect(published, [(1, true)]);
    expect(images.requests, hasLength(3));
    add(4);
    for (var index = 1; index < 4; index++) {
      images.complete(index);
      await pumpEventQueue();
      expect(published.last, (index + 1, true));
      expect(images.listeners, lessThanOrEqualTo(3));
    }
    expect(published.map((entry) => entry.$1), [1, 2, 3, 4]);
  });

  test(
    'out of order completion discards only already superseded decodes',
    () async {
      add(1);
      add(2);
      images.complete(1);
      await pumpEventQueue();
      images.complete(0);
      await pumpEventQueue();
      expect(published, [(2, true)]);
      expect(images.listeners, 1);
    },
  );

  test('slot and global published sequence advance independently', () async {
    add(1);
    add(2, slot: 1);
    images.complete(1);
    await pumpEventQueue();
    images.complete(0);
    await pumpEventQueue();
    expect(published, [(2, true), (1, false)]);
    expect(images.listeners, 2);
  });

  test(
    'newer non-preview global state cannot be rolled back by pending decodes',
    () async {
      add(1);
      add(2, slot: 1);
      owner.markGlobalPublished();
      images.complete(0);
      images.complete(1);
      await pumpEventQueue();
      expect(published, [(1, false), (2, false)]);
      add(3);
      images.complete(2);
      await pumpEventQueue();
      expect(published.last, (3, true));
    },
  );

  test(
    'thirty queued chunks retain at most three decodes without frames',
    () async {
      for (var value = 1; value <= 30; value++) {
        add(value);
        expect(images.listeners, lessThanOrEqualTo(3));
      }
      expect(images.requests, hasLength(2));
      for (var index = 0; index < 3; index++) {
        images.complete(index);
        await pumpEventQueue();
        expect(images.listeners, lessThanOrEqualTo(3));
      }
      expect(images.requests.last.single, 30);
      expect(published, [(1, true), (2, true), (30, true)]);
      owner.clear();
      expect(images.listeners, 0);
    },
  );

  test(
    'thirty published chunks retain only the latest decode without frames',
    () async {
      for (var value = 1; value <= 30; value++) {
        add(value);
        images.complete(value - 1);
        await pumpEventQueue();
        expect(images.listeners, 1);
      }
      owner.closeSlot(0);
      expect(images.listeners, 0);
      add(31);
      expect(images.requests, hasLength(30));
      owner.clear();
      add(32);
      images.complete(30);
      await pumpEventQueue();
      expect(published.last, (32, true));
    },
  );

  test(
    'focused previews hold at most nine images per slot without frames',
    () async {
      for (var value = 1; value <= 30; value++) {
        owner.add(
          slot: 0,
          frame: StreamPreviewFrame(
            bytes: Uint8List.fromList([value]),
            placement: FocusedStreamPreviewPlacement(
              sourceImage: Uint8List.fromList([100, value]),
              maskImage: Uint8List.fromList([200, value]),
              xPercent: 0,
              yPercent: 0,
              widthPercent: 1,
              heightPercent: 1,
            ),
          ),
          isCurrent: () => current,
          publish: (latest) => published.add((value, latest)),
        );
        expect(images.listeners, lessThanOrEqualTo(9));
      }
      expect(images.requests, hasLength(6));
      for (var frame = 0; frame < 3; frame++) {
        for (var image = 0; image < 3; image++) {
          images.complete(frame * 3 + image);
        }
        await pumpEventQueue();
        expect(images.listeners, lessThanOrEqualTo(9));
      }
      expect(published, [(1, true), (2, true), (30, true)]);
      expect(images.listeners, 3);
      owner.clear();
      expect(images.listeners, 0);
    },
  );

  test(
    'clear releases pending listeners and cannot publish into reused slots',
    () async {
      add(1);
      add(2);
      add(3);
      owner.clear();
      expect(images.listeners, 0);
      add(4);
      images.complete(0);
      images.complete(1);
      await pumpEventQueue();
      expect(published, isEmpty);
      expect(images.requests, hasLength(3));
      images.complete(2);
      await pumpEventQueue();
      expect(published, [(4, true)]);
    },
  );

  test('invalid current request never starts or publishes decoding', () async {
    current = false;
    add(1);
    expect(images.requests, isEmpty);
    current = true;
    add(2);
    current = false;
    images.complete(0);
    await pumpEventQueue();
    expect(published, isEmpty);
    expect(images.listeners, 0);
  });

  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.detached,
  ]) {
    test(
      '$state publishes immediately and resumes predecoding when visible',
      () async {
        lifecycle = state;
        add(1);
        expect(published, [(1, true)]);
        expect(images.requests, isEmpty);
        lifecycle = AppLifecycleState.resumed;
        add(2);
        expect(published, [(1, true)]);
        expect(images.requests, hasLength(1));
        images.complete(0);
        await pumpEventQueue();
        expect(published, [(1, true), (2, true)]);
      },
    );
  }

  for (final state in [null, AppLifecycleState.inactive]) {
    test('$state remains eligible for predecoding', () async {
      lifecycle = state;
      add(1);
      expect(published, isEmpty);
      images.complete(0);
      await pumpEventQueue();
      expect(published, [(1, true)]);
    });
  }

  test(
    'hidden publication supersedes in-flight and queued visible chunks',
    () async {
      add(1);
      add(2);
      add(3);
      lifecycle = AppLifecycleState.hidden;
      add(4);
      expect(published, [(4, true)]);
      images.complete(0);
      images.complete(1);
      await pumpEventQueue();
      expect(published, [(4, true)]);
      expect(images.requests, hasLength(2));
      expect(images.listeners, 0);
    },
  );

  test('queued work rechecks visibility before starting a decode', () async {
    add(1);
    add(2);
    add(3);
    lifecycle = AppLifecycleState.paused;
    images.complete(0);
    await pumpEventQueue();
    expect(published, [(1, true), (3, true)]);
    expect(images.requests, hasLength(2));
    images.complete(1);
    await pumpEventQueue();
    expect(images.listeners, 0);
  });

  test('production lifecycle reader reads WidgetsBinding', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(streamPreviewLifecycleReaderProvider)(),
      WidgetsBinding.instance.lifecycleState,
    );
  });

  testWidgets('a consumer frame releases held decodes early', (tester) async {
    add(1);
    images.complete(0);
    await tester.idle();
    expect(images.listeners, 1);
    await tester.pumpWidget(const SizedBox());
    expect(images.listeners, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
