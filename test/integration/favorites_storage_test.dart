import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/data/services/favorites_storage_service.dart';

void main() {
  group('FavoritesStorageService', () {
    late FavoritesStorageService service;

    setUp(() async {
      // Initialize Hive for testing
      Hive.init('./test_hive');

      // 创建服务实例
      service = FavoritesStorageService();
      await service.init();
    });

    tearDown(() async {
      // 清理测试数据
      await service.clearAllFavorites();
      await Hive.close();
    });

    test('should be empty initially', () async {
      final favorites = await service.loadFavorites();
      expect(favorites, isEmpty);
      expect(await service.getFavoritesCount(), 0);
    });

    test('should add and retrieve favorite', () async {
      const imagePath = '/path/to/image1.png';

      final added = await service.addFavorite(imagePath);
      expect(added, true);

      final favorites = await service.loadFavorites();
      expect(favorites, contains(imagePath));
      expect(favorites.length, 1);

      final isFavorite = await service.isFavorite(imagePath);
      expect(isFavorite, true);
    });

    test('should return false when adding duplicate favorite', () async {
      const imagePath = '/path/to/image1.png';

      final added1 = await service.addFavorite(imagePath);
      expect(added1, true);

      final added2 = await service.addFavorite(imagePath);
      expect(added2, false);

      final count = await service.getFavoritesCount();
      expect(count, 1);
    });

    test('should remove favorite', () async {
      const imagePath = '/path/to/image1.png';

      await service.addFavorite(imagePath);
      expect(await service.isFavorite(imagePath), true);

      final removed = await service.removeFavorite(imagePath);
      expect(removed, true);

      expect(await service.isFavorite(imagePath), false);
      expect(await service.getFavoritesCount(), 0);
    });

    test('should return false when removing non-existent favorite', () async {
      const imagePath = '/path/to/nonexistent.png';

      final removed = await service.removeFavorite(imagePath);
      expect(removed, false);
    });

    test('should toggle favorite status', () async {
      const imagePath = '/path/to/image1.png';

      // 初始状态：未收藏
      expect(await service.isFavorite(imagePath), false);

      // 切换到已收藏
      final status1 = await service.toggleFavorite(imagePath);
      expect(status1, true);
      expect(await service.isFavorite(imagePath), true);

      // 切换回未收藏
      final status2 = await service.toggleFavorite(imagePath);
      expect(status2, false);
      expect(await service.isFavorite(imagePath), false);
    });

    test('should handle multiple favorites', () async {
      final paths = [
        '/path/to/image1.png',
        '/path/to/image2.png',
        '/path/to/image3.png',
      ];

      for (final path in paths) {
        await service.addFavorite(path);
      }

      final favorites = await service.loadFavorites();
      expect(favorites.length, 3);
      expect(favorites, containsAll(paths));

      expect(await service.getFavoritesCount(), 3);
    });

    test('should check favorite status correctly', () async {
      const path1 = '/path/to/image1.png';
      const path2 = '/path/to/image2.png';

      await service.addFavorite(path1);

      expect(await service.isFavorite(path1), true);
      expect(await service.isFavorite(path2), false);
    });

    test('should clear all favorites', () async {
      final paths = [
        '/path/to/image1.png',
        '/path/to/image2.png',
        '/path/to/image3.png',
      ];

      for (final path in paths) {
        await service.addFavorite(path);
      }

      expect(await service.getFavoritesCount(), 3);

      await service.clearAllFavorites();

      expect(await service.getFavoritesCount(), 0);

      final favorites = await service.loadFavorites();
      expect(favorites, isEmpty);
    });

    test('should add multiple favorites', () async {
      final paths = [
        '/path/to/image1.png',
        '/path/to/image2.png',
        '/path/to/image3.png',
      ];

      final addedCount = await service.addMultipleFavorites(paths);
      expect(addedCount, 3);
      expect(await service.getFavoritesCount(), 3);
    });

    test('should only add new items when adding multiple favorites', () async {
      final paths1 = ['/path/to/image1.png', '/path/to/image2.png'];
      final paths2 = ['/path/to/image2.png', '/path/to/image3.png'];

      await service.addMultipleFavorites(paths1);
      final addedCount = await service.addMultipleFavorites(paths2);

      // 只有 image3.png 是新的
      expect(addedCount, 1);
      expect(await service.getFavoritesCount(), 3);
    });

    test('should remove multiple favorites', () async {
      final paths = [
        '/path/to/image1.png',
        '/path/to/image2.png',
        '/path/to/image3.png',
        '/path/to/image4.png',
      ];

      await service.addMultipleFavorites(paths);

      final toRemove = ['/path/to/image1.png', '/path/to/image3.png'];
      final removedCount = await service.removeMultipleFavorites(toRemove);

      expect(removedCount, 2);
      expect(await service.getFavoritesCount(), 2);

      expect(await service.isFavorite('/path/to/image1.png'), false);
      expect(await service.isFavorite('/path/to/image2.png'), true);
      expect(await service.isFavorite('/path/to/image3.png'), false);
      expect(await service.isFavorite('/path/to/image4.png'), true);
    });

    test('should handle empty list when adding multiple', () async {
      final addedCount = await service.addMultipleFavorites([]);
      expect(addedCount, 0);
      expect(await service.getFavoritesCount(), 0);
    });

    test('should handle empty list when removing multiple', () async {
      await service.addFavorite('/path/to/image1.png');

      final removedCount = await service.removeMultipleFavorites([]);
      expect(removedCount, 0);
      expect(await service.getFavoritesCount(), 1);
    });

    test('should persist favorites across service instances', () async {
      const imagePath = '/path/to/image1.png';

      // 在第一个服务实例中添加收藏
      await service.addFavorite(imagePath);
      expect(await service.isFavorite(imagePath), true);

      // 创建新的服务实例
      final newService = FavoritesStorageService();
      await newService.init();

      // 新实例应该能读取到之前保存的收藏
      expect(await newService.isFavorite(imagePath), true);
      expect(await newService.getFavoritesCount(), 1);
    });

    test('should handle special characters in paths', () async {
      final specialPaths = [
        '/path/to/image with spaces.png',
        '/path/to/image_with_中文.png',
        '/path/to/image-with-emoji-😀.png',
      ];

      for (final path in specialPaths) {
        await service.addFavorite(path);
      }

      final favorites = await service.loadFavorites();
      expect(favorites.length, 3);

      for (final path in specialPaths) {
        expect(await service.isFavorite(path), true);
      }
    });

    test('should handle rapid add and remove operations', () async {
      // 快速添加和删除
      for (var i = 0; i < 100; i++) {
        final path = '/path/to/image$i.png';
        await service.addFavorite(path);
        if (i % 2 == 0) {
          await service.removeFavorite(path);
        }
      }

      // 应该只有 50 个（奇数索引的）
      expect(await service.getFavoritesCount(), 50);
    });

    test('should return correct count after operations', () async {
      expect(await service.getFavoritesCount(), 0);

      await service.addFavorite('/path/to/image1.png');
      expect(await service.getFavoritesCount(), 1);

      await service.addFavorite('/path/to/image2.png');
      expect(await service.getFavoritesCount(), 2);

      await service.removeFavorite('/path/to/image1.png');
      expect(await service.getFavoritesCount(), 1);

      await service.clearAllFavorites();
      expect(await service.getFavoritesCount(), 0);
    });

    test('should handle Windows paths correctly', () async {
      final windowsPaths = [
        r'C:\Users\Test\Pictures\image1.png',
        r'D:\Images\测试\image2.png',
        r'E:\Gallery\my image.png',
      ];

      await service.addMultipleFavorites(windowsPaths);

      final favorites = await service.loadFavorites();
      expect(favorites.length, 3);

      for (final path in windowsPaths) {
        expect(await service.isFavorite(path), true);
      }
    });

    test('should handle Unix/Mac paths correctly', () async {
      final unixPaths = [
        '/home/user/Pictures/image1.png',
        '/Users/test/Gallery/image2.png',
        '/mnt/data/images/my image.png',
      ];

      await service.addMultipleFavorites(unixPaths);

      final favorites = await service.loadFavorites();
      expect(favorites.length, 3);

      for (final path in unixPaths) {
        expect(await service.isFavorite(path), true);
      }
    });
  });
}
