import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/panels/layer_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<EditorState> pumpPanel(
    WidgetTester tester, {
    required bool inpaint,
  }) async {
    final state = EditorState();
    addTearDown(state.dispose);
    final layers = state.layerManager;
    final base = layers.addLayer(name: 'Base Layer');
    layers.addLayer(
      name: 'Mask Layer',
      index: 0,
      role: inpaint ? LayerRole.mask : LayerRole.image,
    );
    if (inpaint) {
      state.setRolePolicy(LayerRolePolicy.inpaint(protectedLayerId: base.id));
    }

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LayerPanel(state: state)),
      ),
    );
    // 消化图层变动触发的快照防抖与缩略图批处理计时器
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    return state;
  }

  testWidgets('the list shows the top layer first, like the canvas', (
    tester,
  ) async {
    await pumpPanel(tester, inpaint: false);

    final top = tester.getTopLeft(find.text('Mask Layer')).dy;
    final bottom = tester.getTopLeft(find.text('Base Layer')).dy;
    expect(top, lessThan(bottom));
    expect(find.text('Mask'), findsNothing);
  });

  testWidgets('inpaint sessions badge mask layers', (tester) async {
    await pumpPanel(tester, inpaint: true);

    expect(find.text('Mask'), findsOneWidget);
    final badge = tester.getCenter(find.text('Mask')).dy;
    final maskRow = tester.getCenter(find.text('Mask Layer')).dy;
    expect((badge - maskRow).abs(), lessThan(8));
  });

  testWidgets('the add button asks for the layer role in inpaint sessions', (
    tester,
  ) async {
    final state = await pumpPanel(tester, inpaint: true);
    final layers = state.layerManager;
    layers.setActiveLayer(layers.layers.last.id);

    await tester.tap(find.byTooltip('Add Layer'));
    await tester.pumpAndSettle();
    expect(find.text('Add Image Layer'), findsOneWidget);
    expect(find.text('Add Mask Layer'), findsOneWidget);

    await tester.tap(find.text('Add Mask Layer'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(layers.layers.first.isMask, isTrue);
    expect(layers.maskLayers, hasLength(2));
    expect(state.rolePolicy.isValidOrder(layers.layers), isTrue);
  });

  testWidgets('the add button adds a plain layer in edit sessions', (
    tester,
  ) async {
    final state = await pumpPanel(tester, inpaint: false);

    await tester.tap(find.byTooltip('Add Layer'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(find.text('Add Mask Layer'), findsNothing);
    expect(state.layerManager.layerCount, 3);
    expect(state.layerManager.maskLayers, isEmpty);
  });
}
