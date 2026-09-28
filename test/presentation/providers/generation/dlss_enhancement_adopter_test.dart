import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/generation/dlss_enhancement_adopter.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';

void main() {
  test(
    'adopting registers the result as the latest saved generation result',
    () async {
      final registrar = _Registrar()
        ..savedPath = 'gallery/2026-09-06/enhanced.png';
      final container = ProviderContainer(
        overrides: [
          imageGenerationNotifierProvider.overrideWith(() => registrar),
        ],
      );
      addTearDown(container.dispose);
      final source = Uint8List.fromList([1]);
      final result = Uint8List.fromList([2]);

      final path = await container
          .read(dlssEnhancementAdopterProvider)
          .adopt(result: result, source: source);

      expect(path, 'gallery/2026-09-06/enhanced.png');
      expect(registrar.restoreCalls, 1);
      final registration = registrar.registrations.single;
      expect(registration.restoredFirst, isTrue);
      expect(registration.bytes, same(result));
      expect(registration.comparisonSource, same(source));
      expect(registration.params, const ImageParams());
      expect(registration.saveToLocal, isTrue);
      expect(registration.replaceCurrentDisplay, isTrue);
      expect(registration.addToDisplay, isFalse);
      expect(registration.embedNaiMetadata, isFalse);
    },
  );

  test('a result that could not be written reports no file path', () async {
    final registrar = _Registrar();
    final container = ProviderContainer(
      overrides: [
        imageGenerationNotifierProvider.overrideWith(() => registrar),
      ],
    );
    addTearDown(container.dispose);

    final path = await container
        .read(dlssEnhancementAdopterProvider)
        .adopt(
          result: Uint8List.fromList([2]),
          source: Uint8List.fromList([1]),
        );

    expect(path, isNull);
    expect(registrar.registrations, hasLength(1));
  });
}

class _Registration {
  const _Registration({
    required this.restoredFirst,
    required this.bytes,
    required this.params,
    required this.comparisonSource,
    required this.saveToLocal,
    required this.addToDisplay,
    required this.replaceCurrentDisplay,
    required this.embedNaiMetadata,
  });

  final bool restoredFirst;
  final Uint8List bytes;
  final ImageParams params;
  final Uint8List? comparisonSource;
  final bool saveToLocal;
  final bool addToDisplay;
  final bool replaceCurrentDisplay;
  final bool embedNaiMetadata;
}

class _Registrar extends ImageGenerationNotifier {
  String? savedPath;
  int restoreCalls = 0;
  final registrations = <_Registration>[];

  @override
  ImageGenerationState build() => const ImageGenerationState();

  @override
  Future<void> ensureGenerationHistoryRestored() async {
    restoreCalls++;
  }

  @override
  Future<String?> registerExternalImage(
    Uint8List imageBytes, {
    required ImageParams params,
    int? width,
    int? height,
    Uint8List? comparisonSourceImage,
    bool saveToLocal = false,
    String? saveDirectoryPath,
    bool syncToGalleryIndex = true,
    bool addToDisplay = false,
    bool replaceCurrentDisplay = false,
    bool embedNaiMetadata = true,
  }) async {
    registrations.add(
      _Registration(
        restoredFirst: restoreCalls > 0,
        bytes: imageBytes,
        params: params,
        comparisonSource: comparisonSourceImage,
        saveToLocal: saveToLocal,
        addToDisplay: addToDisplay,
        replaceCurrentDisplay: replaceCurrentDisplay,
        embedNaiMetadata: embedNaiMetadata,
      ),
    );
    return savedPath;
  }
}
