import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/storage/tag_favorite_storage.dart';
import 'package:nai_launcher/data/models/prompt/prompt_tag.dart';
import 'package:nai_launcher/data/models/prompt/tag_favorite.dart';
import 'package:nai_launcher/presentation/providers/tag_favorite_provider.dart';

// Fake storage implementation for testing
class FakeTagFavoriteStorage implements TagFavoriteStorage {
  final Map<String, TagFavorite> _storage = {};

  @override
  Box get _favoritesBox => throw UnimplementedError();

  @override
  Future<void> addFavorite(TagFavorite favorite) async {
    _storage[favorite.id] = favorite;
  }

  @override
  Future<void> removeFavorite(String favoriteId) async {
    _storage.remove(favoriteId);
  }

  @override
  List<TagFavorite> getFavorites() => _storage.values.toList();

  @override
  TagFavorite? getFavoriteByText(String tagText) {
    for (final favorite in _storage.values) {
      if (favorite.tag.text == tagText) {
        return favorite;
      }
    }
    return null;
  }

  @override
  bool isFavorite(String tagText) => getFavoriteByText(tagText) != null;

  @override
  Future<void> clearFavorites() async => _storage.clear();

  @override
  int get favoritesCount => _storage.length;

  @override
  Future<void> close() async {}

  @override
  Future<void> init() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TagFavoriteNotifier', () {
    late FakeTagFavoriteStorage fakeStorage;
    late ProviderContainer container;

    setUp(() {
      fakeStorage = FakeTagFavoriteStorage();
      container = ProviderContainer(
        overrides: [
          tagFavoriteStorageProvider.overrideWithValue(fakeStorage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('Initial State', () {
      test('should initialize with empty state', () {
        final state = container.read(tagFavoriteNotifierProvider);

        expect(
          state.favorites,
          isEmpty,
          reason: 'Initial favorites should be empty',
        );
        expect(
          state.isLoading,
          isFalse,
          reason: 'Should not be loading initially',
        );
        expect(
          state.error,
          isNull,
          reason: 'Should have no error initially',
        );
      });
    });

    group('addFavorite', () {
      test('should add favorite and update state', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);
        final tag = PromptTag.create(text: 'test_tag');

        await notifier.addFavorite(tag);

        final state = container.read(tagFavoriteNotifierProvider);
        expect(
          state.favorites.length,
          equals(1),
          reason: 'Should have one favorite',
        );
        expect(
          state.favorites.first.tag.text,
          equals('test_tag'),
          reason: 'Tag text should match',
        );
      });

      test('should add favorite with notes', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);
        final tag = PromptTag.create(text: 'tag_with_notes');
        const notes = 'My notes';

        await notifier.addFavorite(tag, notes: notes);

        final state = container.read(tagFavoriteNotifierProvider);
        expect(
          state.favorites.first.notes,
          equals(notes),
          reason: 'Notes should be saved',
        );
      });

      test('should handle adding duplicate tag', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);
        final tag = PromptTag.create(text: 'duplicate_tag');

        // Add twice
        await notifier.addFavorite(tag);
        await notifier.addFavorite(tag, update: true);

        final state = container.read(tagFavoriteNotifierProvider);
        // Should have updated the existing favorite, not added a duplicate
        expect(
          state.favorites.length,
          equals(1),
          reason: 'Should update existing favorite',
        );
      });
    });

    group('removeFavorite', () {
      test('should remove favorite by ID', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);
        final tag = PromptTag.create(text: 'to_remove');

        await notifier.addFavorite(tag);

        final favorite = container
            .read(tagFavoriteNotifierProvider)
            .favorites
            .first;

        await notifier.removeFavorite(favorite.id);

        final state = container.read(tagFavoriteNotifierProvider);
        expect(
          state.favorites,
          isEmpty,
          reason: 'Favorite should be removed',
        );
      });

      test('should handle removing non-existent favorite gracefully', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);

        // Should not throw
        await notifier.removeFavorite('non-existent-id');

        final state = container.read(tagFavoriteNotifierProvider);
        expect(
          state.favorites,
          isEmpty,
          reason: 'State should remain unchanged',
        );
      });
    });

    group('removeFavoriteByTag', () {
      test('should remove favorite by tag', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);
        final tag = PromptTag.create(text: 'tag_to_remove');

        await notifier.addFavorite(tag);
        await notifier.removeFavoriteByTag(tag);

        final state = container.read(tagFavoriteNotifierProvider);
        expect(
          state.favorites,
          isEmpty,
          reason: 'Favorite should be removed',
        );
      });
    });

    group('toggleFavorite', () {
      test('should add favorite when not exists', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);
        final tag = PromptTag.create(text: 'toggle_test');

        await notifier.toggleFavorite(tag);

        final state = container.read(tagFavoriteNotifierProvider);
        expect(
          state.favorites.length,
          equals(1),
          reason: 'Favorite should be added',
        );
        expect(
          notifier.isFavorite(tag: tag),
          isTrue,
          reason: 'Tag should be marked as favorite',
        );
      });

      test('should remove favorite when exists', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);
        final tag = PromptTag.create(text: 'toggle_test');

        await notifier.toggleFavorite(tag);
        await notifier.toggleFavorite(tag);

        final state = container.read(tagFavoriteNotifierProvider);
        expect(
          state.favorites,
          isEmpty,
          reason: 'Favorite should be removed',
        );
      });
    });

    group('isFavorite', () {
      test('should return true for favorited tag', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);
        final tag = PromptTag.create(text: 'test_tag');

        await notifier.addFavorite(tag);

        expect(
          notifier.isFavorite(tag: tag),
          isTrue,
          reason: 'Should return true for favorited tag',
        );
      });

      test('should return true for favorited tag by text', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);
        final tag = PromptTag.create(text: 'test_tag');

        await notifier.addFavorite(tag);

        expect(
          notifier.isFavorite(tagText: 'test_tag'),
          isTrue,
          reason: 'Should return true when searching by text',
        );
      });

      test('should return false for non-favorited tag', () {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);
        final tag = PromptTag.create(text: 'non_favorited');

        expect(
          notifier.isFavorite(tag: tag),
          isFalse,
          reason: 'Should return false for non-favorited tag',
        );
      });
    });

    group('clearFavorites', () {
      test('should clear all favorites', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);

        await notifier.addFavorite(PromptTag.create(text: 'tag1'));
        await notifier.addFavorite(PromptTag.create(text: 'tag2'));
        await notifier.addFavorite(PromptTag.create(text: 'tag3'));

        expect(
          container.read(tagFavoriteNotifierProvider).favorites.length,
          equals(3),
          reason: 'Should have 3 favorites',
        );

        await notifier.clearFavorites();

        final state = container.read(tagFavoriteNotifierProvider);
        expect(
          state.favorites,
          isEmpty,
          reason: 'All favorites should be cleared',
        );
      });
    });

    group('refresh', () {
      test('should reload favorites from storage', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);

        // Add favorite directly to storage (bypassing provider)
        final favorite = TagFavorite.create(
          tag: PromptTag.create(text: 'direct_add'),
        );
        await fakeStorage.addFavorite(favorite);

        // Before refresh, state is empty
        expect(
          container.read(tagFavoriteNotifierProvider).favorites,
          isEmpty,
          reason: 'State should be empty before refresh',
        );

        // Refresh
        notifier.refresh();

        // After refresh, state should have the favorite
        final state = container.read(tagFavoriteNotifierProvider);
        expect(
          state.favorites.length,
          equals(1),
          reason: 'State should be updated after refresh',
        );
        expect(
          state.favorites.first.tag.text,
          equals('direct_add'),
          reason: 'Should load favorite from storage',
        );
      });
    });

    group('Getters', () {
      test('favoritesCount should return correct count', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);

        await notifier.addFavorite(PromptTag.create(text: 'tag1'));
        await notifier.addFavorite(PromptTag.create(text: 'tag2'));

        expect(
          notifier.favoritesCount,
          equals(2),
          reason: 'Count should match number of favorites',
        );
      });
    });

    group('clearError', () {
      test('should clear error state', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);

        // Manually set an error state
        container.read(tagFavoriteNotifierProvider.notifier).state =
            TagFavoriteState(
          favorites: [],
          error: 'Test error',
        );

        expect(
          container.read(tagFavoriteNotifierProvider).error,
          isNotNull,
          reason: 'Error should be set',
        );

        notifier.clearError();

        expect(
          container.read(tagFavoriteNotifierProvider).error,
          isNull,
          reason: 'Error should be cleared',
        );
      });
    });

    group('Convenience Providers', () {
      test('currentFavorites should return favorites list', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);

        await notifier.addFavorite(PromptTag.create(text: 'tag1'));

        final favorites = container.read(currentFavoritesProvider);
        expect(
          favorites.length,
          equals(1),
          reason: 'Should return current favorites',
        );
        expect(
          favorites.first.tag.text,
          equals('tag1'),
          reason: 'Should return correct favorite',
        );
      });

      test('isFavoriteLoading should reflect loading state', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);

        // Add a favorite
        await notifier.addFavorite(PromptTag.create(text: 'tag'));

        // After operation completes, should not be loading
        expect(
          container.read(isFavoriteLoadingProvider),
          isFalse,
          reason: 'Should not be loading after operation completes',
        );
      });

      test('favoritesCount provider should return count', () async {
        final notifier = container.read(tagFavoriteNotifierProvider.notifier);

        await notifier.addFavorite(PromptTag.create(text: 'tag1'));
        await notifier.addFavorite(PromptTag.create(text: 'tag2'));

        final count = container.read(favoritesCountProvider);
        expect(
          count,
          equals(2),
          reason: 'Should return correct count',
        );
      });
    });
  });
}
