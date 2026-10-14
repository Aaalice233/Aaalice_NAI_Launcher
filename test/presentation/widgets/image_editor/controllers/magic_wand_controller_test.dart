import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/controllers/magic_wand_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layers/layer_pixel_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'mask mode writes only newly selected pixels into the active mask layer',
    (tester) async {
      final session = ImageEditorController();
      addTearDown(session.dispose);
      final state = session.editorState;
      final layers = state.layerManager;
      state.initNewCanvas(const Size(32, 32), initialLayerName: 'image');
      final image = layers.activeLayer!;
      session.sourceLayerId = image.id;
      state.setRolePolicy(LayerRolePolicy.inpaint(protectedLayerId: image.id));
      final other = layers.addLayer(
        name: 'other',
        index: 0,
        role: LayerRole.mask,
      );
      final active = layers.addLayer(
        name: 'active',
        index: 0,
        role: LayerRole.mask,
      );
      final magicWand = MagicWandController(
        session: session,
        editorState: state,
        config: const ImageEditorSessionConfig.empty(),
      );
      addTearDown(magicWand.dispose);
      final context = await _pumpContext(tester);

      await tester.runAsync(() async {
        await fillLayer(
          layers,
          image,
          size: const Size(32, 32),
          color: const Color(0xFF00FF00),
        );
        await fillLayer(
          layers,
          other,
          size: const Size(8, 8),
          color: const Color(0xFFFFFFFF),
          offset: const Offset(4, 4),
        );
        layers.setActiveLayer(active.id);

        await magicWand.apply(
          context,
          const Offset(20, 20),
          mode: MagicWandSelectionMode.colorArea,
          tolerance: 10,
          invert: false,
        );

        expect(layers.maskLayers.toList(), [active, other]);
        expect(other.contentBounds, const Rect.fromLTWH(4, 4, 8, 8));
        final written = await LayerPixels.of(
          active,
          const Rect.fromLTWH(0, 0, 32, 32),
        );
        expect(written.alphaAt(20, 20), greaterThan(0));
        // 已被别的蒙版层盖住的像素不再抄进当前层，隐藏那一层时它才会真正消失
        expect(written.alphaAt(6, 6), 0);

        expect(state.undo(), isTrue);
        expect(active.hasContent, isFalse);
      });
    },
  );
}

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}
