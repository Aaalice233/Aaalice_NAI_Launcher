import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/skill_catalog.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_config_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/provider_remote_models_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/model_services/model_services_settings_section.dart';

import '../../../../../helpers/memory_local_storage.dart';

class _MemorySecureStorage extends SecureStorageService {
  final keys = <String, String>{};

  @override
  Future<String?> getAgentWebAccessExaApiKey() async => null;

  @override
  Future<String?> getPromptAssistantApiKey(String providerId) async =>
      keys[providerId];

  @override
  Future<void> savePromptAssistantApiKey(
    String providerId,
    String apiKey,
  ) async => keys[providerId] = apiKey;

  @override
  Future<void> deletePromptAssistantApiKey(String providerId) async =>
      keys.remove(providerId);
}

class _EmptySkillCatalogService extends SkillCatalogService {
  const _EmptySkillCatalogService();

  @override
  Future<SkillCatalogSnapshot> scan({
    required List<SkillRoot> roots,
    Map<String, bool> skillEnabledOverrides = const {},
  }) async => const SkillCatalogSnapshot();
}

class _FakeRemoteModels extends ProviderRemoteModelsNotifier {
  _FakeRemoteModels(super.ref, this.models);

  final List<String> models;

  @override
  Future<List<String>> fetch(String providerId) async {
    state = {...state, providerId: models};
    return models;
  }
}

final _deepseek = ProviderPreset.deepseek.createConfig();
const _relay = ProviderConfig(
  id: 'relay',
  name: 'Relay',
  baseUrl: 'https://relay.invalid/v1',
);

ModelConfig _model(
  String providerId,
  String name, {
  ModelSource source = ModelSource.manual,
}) => ModelConfig(
  providerId: providerId,
  name: name,
  displayName: name,
  forTask: AssistantTaskType.llm,
  source: source,
);

PromptAssistantConfigState _seed({List<ModelConfig>? relayModels}) =>
    PromptAssistantConfigState.defaults().copyWith(
      providers: [_deepseek, _relay],
      models: [
        _model(_deepseek.id, 'deepseek-flash'),
        _model(_deepseek.id, 'deepseek-v4-pro'),
        _model(_deepseek.id, 'deepseek-v4-flash', source: ModelSource.api),
        _model(_deepseek.id, 'deepseek-relay-only'),
        ...(relayModels ?? [_model(_relay.id, 'gpt-4o')]),
      ],
      routing: PromptAssistantConfigState.defaults().routing.copyWithTask(
        taskType: AssistantTaskType.llm,
        providerId: _deepseek.id,
        model: 'deepseek-flash',
      ),
    );

class _Harness {
  _Harness(this.secure);

  final _MemorySecureStorage secure;

  PromptAssistantConfigState config(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(ModelServicesSettingsSection)),
      ).read(promptAssistantConfigProvider);
}

Future<_Harness> _pump(
  WidgetTester tester, {
  Size size = const Size(1180, 900),
  double textScale = 1,
  PromptAssistantConfigState? config,
  List<String> remote = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final storage = MemoryLocalStorage();
  if (config != null) {
    storage.values[StorageKeys.promptAssistantConfigJson] = config.encode();
  }
  final secure = _MemorySecureStorage();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        secureStorageServiceProvider.overrideWithValue(secure),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: Directory.systemTemp,
            workspaceDirectory: Directory.systemTemp,
            environment: const {},
            skillCatalogService: const _EmptySkillCatalogService(),
          ),
        ),
        providerRemoteModelsProvider.overrideWith(
          (ref) => _FakeRemoteModels(ref, remote),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            key: ValueKey('host-scroll'),
            padding: EdgeInsets.all(16),
            child: ModelServicesSettingsSection(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(secure);
}

Finder _key(String value) => find.byKey(ValueKey(value));

Finder _inRow(String modelId, Finder matching) => find.descendant(
  of: _key('model-services-model-$modelId'),
  matching: matching,
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('宽屏左右分栏，模型显示官方名、ID 与能力标签', (tester) async {
    await _pump(tester, config: _seed());

    final list = _key('model-services-provider-list');
    final detail = _key('model-services-detail-deepseek');
    expect(list, findsOneWidget);
    expect(detail, findsOneWidget);
    expect(tester.getTopLeft(list).dx, lessThan(tester.getTopLeft(detail).dx));

    expect(
      _inRow('deepseek-flash', find.text('DeepSeek V4.1 Flash')),
      findsOne,
    );
    expect(_inRow('deepseek-flash', find.text('deepseek-flash')), findsOne);
    expect(_inRow('deepseek-flash', find.text('推理')), findsOne);
    expect(_inRow('deepseek-flash', find.text('视觉')), findsOne);
    expect(_inRow('deepseek-flash', find.text('上下文 1M')), findsOne);
    expect(_inRow('deepseek-v4-pro', find.text('视觉')), findsNothing);

    await tester.tap(_key('model-services-provider-relay'));
    await tester.pumpAndSettle();
    expect(_key('model-services-detail-relay'), findsOneWidget);
    expect(_inRow('gpt-4o', find.text('GPT-4o')), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏点服务商进入详情页，返回回到列表', (tester) async {
    await _pump(tester, size: const Size(390, 844), config: _seed());

    expect(_key('model-services-detail-deepseek'), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));

    await tester.tap(_key('model-services-provider-deepseek'));
    await tester.pumpAndSettle();
    expect(find.byType(ProviderDetailPage), findsOneWidget);
    expect(_key('model-services-detail-deepseek'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ProviderDetailPage), findsNothing);
    expect(_key('model-services-provider-list'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手动添加模型并修改、清空显示名', (tester) async {
    final harness = await _pump(tester, config: _seed());

    await _tapVisible(tester, _key('model-services-add-model'));
    await tester.enterText(_key('model-services-model-id'), 'my-deepseek');
    await tester.enterText(_key('model-services-model-display-name'), '自定义');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(_inRow('my-deepseek', find.text('自定义')), findsOne);
    expect(
      harness
          .config(tester)
          .models
          .where((model) => model.name == 'my-deepseek')
          .every((model) => model.source == ModelSource.manual),
      isTrue,
    );

    await _tapVisible(tester, _key('model-services-model-edit-deepseek-flash'));
    await tester.enterText(_key('model-services-model-display-name'), '日常');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(_inRow('deepseek-flash', find.text('日常')), findsOne);

    await _tapVisible(tester, _key('model-services-model-edit-deepseek-flash'));
    await tester.enterText(_key('model-services-model-display-name'), '');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(
      _inRow('deepseek-flash', find.text('DeepSeek V4.1 Flash')),
      findsOne,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('移除正在被任务路由使用的模型前说明影响，取消不改动', (tester) async {
    final harness = await _pump(tester, config: _seed());

    await _tapVisible(
      tester,
      _key('model-services-model-remove-deepseek-v4-pro'),
    );
    expect(find.textContaining('从这个服务商移除'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(_key('model-services-model-deepseek-v4-pro'), findsOneWidget);

    await _tapVisible(
      tester,
      _key('model-services-model-remove-deepseek-flash'),
    );
    // 未单独设置的任务路由读取时继承“优化”，智能体也从这里迁移了模型引用。
    expect(find.textContaining('正被优化、反推、角色替换、自定义、智能体使用'), findsOneWidget);
    await tester.tap(find.text('移除模型').last);
    await tester.pumpAndSettle();

    expect(_key('model-services-model-deepseek-flash'), findsNothing);
    final routing = harness.config(tester).routing;
    expect(routing.providerIdFor(AssistantTaskType.llm), 'deepseek');
    expect(routing.modelFor(AssistantTaskType.llm), 'deepseek-relay-only');
    expect(tester.takeException(), isNull);
  });

  testWidgets('管理面板可逐个或整组添加，接口不再列出的模型被标出', (tester) async {
    final harness = await _pump(
      tester,
      config: _seed(),
      remote: const [
        'deepseek-flash',
        'deepseek-v4-pro',
        'deepseek-r2',
        'deepseek-r2-lite',
        'deepseek-coder',
      ],
    );

    await _tapVisible(tester, _key('model-services-manage-models'));
    expect(_key('model-services-manage-results'), findsOneWidget);

    await tester.tap(_key('model-services-manage-option-deepseek-coder'));
    await tester.pumpAndSettle();
    await tester.tap(_key('model-services-manage-group-add-deepseek-r2'));
    await tester.pumpAndSettle();
    expect(
      _key('model-services-manage-group-remove-deepseek-r2'),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_key('model-services-manage-results'), findsNothing);

    for (final id in ['deepseek-coder', 'deepseek-r2', 'deepseek-r2-lite']) {
      expect(_key('model-services-model-$id'), findsOneWidget, reason: id);
      expect(
        harness
            .config(tester)
            .models
            .where((model) => model.name == id)
            .every((model) => model.source == ModelSource.api),
        isTrue,
      );
    }
    expect(_inRow('deepseek-v4-flash', find.text('接口已不再列出')), findsOne);
    expect(_inRow('deepseek-flash', find.text('接口已不再列出')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('连接编辑在切换服务商时提交到原服务商，密钥回车即保存', (tester) async {
    final harness = await _pump(tester, config: _seed());

    await tester.enterText(
      _key('model-services-base-url'),
      'https://mirror.invalid/v1',
    );
    await tester.tap(_key('model-services-provider-relay'));
    await tester.pumpAndSettle();
    final deepseek = harness
        .config(tester)
        .providers
        .singleWhere((provider) => provider.id == 'deepseek');
    expect(deepseek.baseUrl, 'https://mirror.invalid/v1');

    expect(_key('model-services-clear-api-key'), findsNothing);
    await tester.enterText(_key('model-services-api-key'), ' sk-relay ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(harness.secure.keys['relay'], 'sk-relay');
    expect(_key('model-services-clear-api-key'), findsOneWidget);
    expect(
      tester.widget<TextField>(_key('model-services-api-key')).controller!.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('模型很多时分组默认折叠，搜索时展开匹配项', (tester) async {
    await _pump(
      tester,
      config: _seed(
        relayModels: [
          for (var i = 0; i < 20; i++) _model('relay', 'alpha-x-$i'),
          for (var i = 0; i < 20; i++) _model('relay', 'beta-y-$i'),
        ],
      ),
    );
    await tester.tap(_key('model-services-provider-relay'));
    await tester.pumpAndSettle();

    expect(_key('model-services-group-alpha-x'), findsOneWidget);
    expect(_key('model-services-model-alpha-x-0'), findsNothing);

    await _tapVisible(tester, _key('model-services-group-alpha-x'));
    expect(_key('model-services-model-alpha-x-0'), findsOneWidget);
    expect(_key('model-services-model-beta-y-0'), findsNothing);

    await tester.enterText(_key('model-services-model-search'), 'beta-y-7');
    await tester.pumpAndSettle();
    expect(_key('model-services-model-beta-y-7'), findsOneWidget);
    expect(_key('model-services-model-alpha-x-0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('清理失效模型只移除从列表加入且已下架的模型', (tester) async {
    final harness = await _pump(
      tester,
      config: _seed(),
      remote: const ['deepseek-flash', 'deepseek-v4-pro'],
    );
    await _tapVisible(tester, _key('model-services-manage-models'));

    expect(_key('model-services-manage-title-badge'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('model-services-manage-title-badge'),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await tester.tap(_key('model-services-manage-clean'));
    await tester.pumpAndSettle();
    expect(find.textContaining('移除 deepseek-v4-flash？'), findsOneWidget);
    await tester.tap(find.text('移除模型').last);
    await tester.pumpAndSettle();

    final remaining = {
      for (final model in harness.config(tester).models)
        if (model.providerId == 'deepseek') model.name,
    };
    expect(remaining, isNot(contains('deepseek-v4-flash')));
    expect(remaining, contains('deepseek-relay-only'));
    expect(
      tester.widget<TextButton>(_key('model-services-manage-clean')).onPressed,
      isNull,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // 手动添加的模型不在接口列表里是常态，不标为失效。
    expect(_inRow('deepseek-relay-only', find.text('接口已不再列出')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('添加全部模型：少量直接加入', (tester) async {
    final harness = await _pump(
      tester,
      config: _seed(),
      remote: const ['deepseek-flash', 'deepseek-r2', 'deepseek-r2-lite'],
    );
    await _tapVisible(tester, _key('model-services-manage-models'));

    await tester.tap(_key('model-services-manage-add-all'));
    await tester.pumpAndSettle();
    final names = {
      for (final model in harness.config(tester).models)
        if (model.providerId == 'deepseek') model.name,
    };
    expect(names, containsAll(['deepseek-r2', 'deepseek-r2-lite']));
    expect(
      tester
          .widget<TextButton>(_key('model-services-manage-add-all'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('添加全部模型：超过 20 个先确认，取消不改动', (tester) async {
    final harness = await _pump(
      tester,
      config: _seed(),
      remote: [for (var i = 0; i < 25; i++) 'bulk-model-$i'],
    );
    await _tapVisible(tester, _key('model-services-manage-models'));
    int bulkCount() => {
      for (final model in harness.config(tester).models)
        if (model.name.startsWith('bulk-model-')) model.name,
    }.length;

    await tester.tap(_key('model-services-manage-add-all'));
    await tester.pumpAndSettle();
    expect(find.text('要向这个服务商添加 25 个模型吗？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(bulkCount(), 0);

    await tester.tap(_key('model-services-manage-add-all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加全部模型').last);
    await tester.pumpAndSettle();
    expect(bulkCount(), 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('没有服务商时显示添加入口', (tester) async {
    await _pump(tester);

    expect(_key('model-services-empty'), findsOneWidget);
    expect(_key('model-services-add-provider'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (width, textScale) in [
    (320.0, 3.0),
    (600.0, 1.0),
    (840.0, 1.0),
    (1180.0, 3.0),
    (1600.0, 1.0),
  ]) {
    testWidgets(
      '${width.toInt()} 宽 ${textScale.toInt()}x 文本下无溢出、操作可达且没有第二个纵向滚动',
      (tester) async {
        await _pump(
          tester,
          size: Size(width, 900),
          textScale: textScale,
          config: _seed(),
        );
        if (find.byType(ProviderDetailPage).evaluate().isEmpty &&
            _key('model-services-detail-deepseek').evaluate().isEmpty) {
          await tester.tap(_key('model-services-provider-deepseek'));
          await tester.pumpAndSettle();
        }

        expect(tester.takeException(), isNull);
        for (final action in [
          'model-services-manage-models',
          'model-services-add-model',
          'model-services-check-connection',
          'model-services-provider-menu',
          'model-services-model-remove-deepseek-flash',
        ]) {
          expect(_key(action), findsOneWidget, reason: action);
        }
        final verticalScrollables = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        );
        expect(
          verticalScrollables,
          findsOneWidget,
          reason: '详情内容只能由宿主页或详情页的唯一滚动容器承载',
        );
      },
    );
  }
}
