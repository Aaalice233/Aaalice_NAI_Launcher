import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_options.dart';
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_service.dart';
import 'package:nai_launcher/data/models/director/director_tool_type.dart';
import 'package:nai_launcher/presentation/providers/director_tools_notifier.dart';

final Uint8List _resultBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

final PixelSnapOutput _pixelSnapOutput = PixelSnapOutput(
  pngBytes: _resultBytes,
  snappedWidth: 64,
  snappedHeight: 48,
  outputWidth: 64,
  outputHeight: 48,
  pitchX: 8,
  pitchY: 8,
  paletteSize: 12,
  downscaledForAnalysis: false,
);

/// 直接带着"已经跑出结果"的状态开局，免得为了造结果去真跑一遍引擎。
class _SeededDirectorToolsNotifier extends DirectorToolsNotifier {
  @override
  DirectorToolsState build() {
    return DirectorToolsState(
      selectedTool: DirectorToolType.pixelSnap,
      sourceImage: _resultBytes,
      result: _resultBytes,
      pixelSnapResult: _pixelSnapOutput,
      imageWidth: 512,
      imageHeight: 512,
    );
  }
}

DirectorToolsNotifier _seededNotifier(ProviderContainer container) =>
    container.read(directorToolsNotifierProvider.notifier);

void main() {
  group('DirectorToolsState.estimatedAnlasCost', () {
    test('本地工具恒为 0', () {
      const DirectorToolsState state = DirectorToolsState(
        selectedTool: DirectorToolType.pixelSnap,
        imageWidth: 1024,
        imageHeight: 1024,
      );
      expect(state.estimatedAnlasCost(), 0);
      expect(state.estimatedAnlasCost(isOpus: true), 0);
    });

    test('同尺寸下走 API 的工具仍然计费', () {
      const DirectorToolsState state = DirectorToolsState(
        selectedTool: DirectorToolType.declutter,
        imageWidth: 1024,
        imageHeight: 1024,
      );
      expect(state.estimatedAnlasCost(), greaterThan(0));
    });
  });

  group('DirectorToolType', () {
    test('只有 Pixel Snap 是本地工具且产出像素画', () {
      for (final DirectorToolType tool in DirectorToolType.values) {
        final bool isPixelSnap = tool == DirectorToolType.pixelSnap;
        expect(tool.runsLocally, isPixelSnap, reason: '$tool');
        expect(tool.producesPixelArt, isPixelSnap, reason: '$tool');
      }
    });

    test('Pixel Snap 不需要提示词也没有 defry', () {
      expect(DirectorToolType.pixelSnap.needsPrompt, isFalse);
      expect(DirectorToolType.pixelSnap.supportsDefry, isFalse);
    });
  });

  group('PixelSnapOptions.copyWith', () {
    test('逐字段覆盖且不误伤其它字段', () {
      const PixelSnapOptions base = PixelSnapOptions();
      expect(base.paletteMode, PixelSnapPaletteMode.auto);
      expect(base.colors, PixelSnapOptions.defaultColors);

      final PixelSnapOptions custom = base.copyWith(
        paletteMode: PixelSnapPaletteMode.custom,
        colors: 32,
      );
      expect(custom.paletteMode, PixelSnapPaletteMode.custom);
      expect(custom.colors, 32);
      expect(custom.avoidOverRefining, base.avoidOverRefining);
      expect(custom.upscale, base.upscale);
      expect(custom == base, isFalse);
      expect(base.copyWith() == base, isTrue);
    });
  });

  group('DirectorToolsNotifier 结果保留', () {
    ProviderContainer buildContainer() {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          directorToolsNotifierProvider.overrideWith(
            _SeededDirectorToolsNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('改 Pixel Snap 参数不会清掉已生成的结果', () {
      final ProviderContainer container = buildContainer();
      _seededNotifier(container).updatePixelSnapOptions(
        const PixelSnapOptions(paletteMode: PixelSnapPaletteMode.custom),
      );

      final DirectorToolsState state = container.read(
        directorToolsNotifierProvider,
      );
      expect(state.result, isNotNull);
      expect(state.pixelSnapResult, isNotNull);
      expect(state.pixelSnap.paletteMode, PixelSnapPaletteMode.custom);
    });

    test('切换工具才清结果', () {
      final ProviderContainer container = buildContainer();
      _seededNotifier(container).selectTool(DirectorToolType.declutter);

      final DirectorToolsState state = container.read(
        directorToolsNotifierProvider,
      );
      expect(state.result, isNull);
      expect(state.pixelSnapResult, isNull);
    });
  });
}
