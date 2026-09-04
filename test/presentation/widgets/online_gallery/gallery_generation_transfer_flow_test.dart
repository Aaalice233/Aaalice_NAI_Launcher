import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/services/generation_prompt_transfer_service.dart';
import 'package:nai_launcher/presentation/widgets/danbooru_post_card.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/gallery_generation_transfer_dialog.dart';

void main() {
  setUp(() {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
  });

  tearDown(() {
    PlatformCapabilities.debugOverride = null;
  });

  testWidgets('AI TAG card send offers selective configuration replacement', (
    tester,
  ) async {
    const post = DanbooruPost(
      id: 130,
      sourceId: GallerySourceId.aiTag,
      width: 600,
      height: 900,
      rating: 'g',
      previewFileUrl: 'https://example.com/ai-tag.jpg',
      tagString: '1girl blue_hair',
    );
    const configuration = GenerationTransferConfiguration(
      model: ImageModels.animeDiffusionV45Curated,
      width: 1024,
      height: 1024,
      sampler: Samplers.kDpmpp2m,
      seed: 123456,
    );
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
        characterPromptNotifierProvider.overrideWith(
          _TestCharacterPromptNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/gallery',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/gallery',
          builder: (_, _) => Scaffold(
            body: DanbooruPostCard(
              post: post,
              itemWidth: 400,
              isFavorited: false,
              generationTransferOptions: const GenerationTransferOptions(
                configuration: configuration,
              ),
              onTap: () {},
              onTagTap: (_) {},
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          builder: (context, child) => InteractionPolicyScope(
            initialPolicy: const InteractionPolicy(
              modality: InteractionModality.pointer,
              touchAvailable: false,
              precisePointerAvailable: true,
            ),
            child: child!,
          ),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    final card = find.byType(DanbooruPostCard);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(card));
    await mouse.moveTo(tester.getCenter(card));
    await tester.pump();

    await tester.tap(find.byTooltip('Send to Text to Image'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('gallery-generation-transfer-dialog')),
      findsOneWidget,
    );
    expect(router.routeInformationProvider.value.uri.path, '/gallery');

    final seedOption = find.byKey(
      const ValueKey('gallery-generation-setting-seed'),
    );
    await tester.ensureVisible(seedOption);
    await tester.pump();
    await tester.tap(seedOption);
    await tester.tap(
      find.byKey(const ValueKey('gallery-generation-transfer-submit')),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final params = container.read(generationParamsNotifierProvider);
    expect(params.prompt, '1girl, blue_hair');
    expect(params.seed, 123456);
    expect(params.model, ImageModels.animeDiffusionV5Full);
    expect((params.width, params.height), (832, 1216));
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('compact non-NAI dialog keeps send available and settings off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Set<GenerationTransferSetting>? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await GalleryGenerationTransferDialog.show(
                context,
                configuration: null,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    final optionsList = tester.widget<ListView>(find.byType(ListView));
    optionsList.controller!.jumpTo(
      optionsList.controller!.position.maxScrollExtent,
    );
    await tester.pump();
    final seedTile = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('gallery-generation-setting-seed')),
    );
    expect(seedTile.onChanged, isNull);
    final submit = find.byKey(
      const ValueKey('gallery-generation-transfer-submit'),
    );
    expect(submit.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(result, isEmpty);
  });
}

class _TestCharacterPromptNotifier extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() => const CharacterPromptConfig();

  @override
  void replaceAll(List<CharacterPrompt> characters) {
    state = CharacterPromptConfig(characters: characters);
  }
}

class _MemoryStorage extends LocalStorageService {
  final Map<String, Object?> _values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (_values[key] ?? defaultValue) as T?;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  Future<void> setSettings(Map<String, Object?> values) async {
    _values.addAll(values);
  }

  @override
  Future<void> deleteSetting(String key) async {
    _values.remove(key);
  }
}
