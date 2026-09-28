import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/comfyui/workflow_template.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/comfyui/comfyui_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/comfyui_settings_section.dart';

void main() {
  testWidgets(
    'SeedVR2 metadata setting defaults off and persists user choice',
    (tester) async {
      final storage = _MemoryLocalStorageService();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          comfyUISettingsProvider.overrideWith(_EnabledComfyUISettings.new),
          comfyUIWorkflowsProvider.overrideWith(_EmptyComfyUIWorkflows.new),
        ],
      );
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SingleChildScrollView(child: ComfyUISettingsSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const title = '在 SeedVR2 结果中写入 NAI 生成参数';
      expect(find.text(title), findsOneWidget);
      expect(
        container
            .read(imageWorkflowControllerProvider)
            .upscale
            .seedvr2EmbedNaiMetadata,
        isFalse,
      );

      await tester.tap(find.text(title));
      await tester.pumpAndSettle();

      expect(
        container
            .read(imageWorkflowControllerProvider)
            .upscale
            .seedvr2EmbedNaiMetadata,
        isTrue,
      );
      expect(storage.values['comfyui_seedvr2_embed_nai_metadata'], isTrue);
    },
  );
}

class _EnabledComfyUISettings extends ComfyUISettings {
  @override
  ComfyUISettingsState build() {
    return const ComfyUISettingsState(enabled: true);
  }
}

class _EmptyComfyUIWorkflows extends ComfyUIWorkflows {
  @override
  List<WorkflowTemplate> build() => const [];
}

class _MemoryLocalStorageService extends LocalStorageService {
  final Map<String, Object?> values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = values.containsKey(key) ? values[key] : defaultValue;
    return value as T?;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
