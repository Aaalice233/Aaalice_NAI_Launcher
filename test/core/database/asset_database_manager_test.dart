import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/asset_database_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory appSupportDir;
  late Map<String, int> assetLoadCounts;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'asset_database_manager_test_',
    );
    appSupportDir = await Directory(
      p.join(tempDir.path, 'app_support'),
    ).create(recursive: true);
    PathProviderPlatform.instance = _TestPathProviderPlatform(
      appSupportPath: appSupportDir.path,
    );

    assetLoadCounts = <String, int>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(
            message!.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          );
          assetLoadCounts[key] = (assetLoadCounts[key] ?? 0) + 1;
          return ByteData.sublistView(Uint8List.fromList(utf8.encode(key)));
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'does not load bundled assets when local databases already exist',
    () async {
      final dbDir = await Directory(
        p.join(appSupportDir.path, 'asset_databases'),
      ).create(recursive: true);
      await File(
        p.join(dbDir.path, AssetDatabaseManager.translationDb),
      ).writeAsBytes(const [1, 2, 3]);
      await File(
        p.join(dbDir.path, AssetDatabaseManager.cooccurrenceDb),
      ).writeAsBytes(const [4, 5, 6]);

      await AssetDatabaseManager.initialize();

      expect(assetLoadCounts, isEmpty);
      expect(
        await File(
          p.join(dbDir.path, AssetDatabaseManager.translationDb),
        ).readAsBytes(),
        const [1, 2, 3],
      );
      expect(
        await File(
          p.join(dbDir.path, AssetDatabaseManager.cooccurrenceDb),
        ).readAsBytes(),
        const [4, 5, 6],
      );
    },
  );

  test(
    'copies missing bundled assets once and writes version sidecars',
    () async {
      await AssetDatabaseManager.initialize();

      final dbDir = Directory(p.join(appSupportDir.path, 'asset_databases'));
      final translationPath = p.join(
        dbDir.path,
        AssetDatabaseManager.translationDb,
      );
      final cooccurrencePath = p.join(
        dbDir.path,
        AssetDatabaseManager.cooccurrenceDb,
      );

      expect(assetLoadCounts, {
        'assets/databases/${AssetDatabaseManager.translationDb}': 1,
        'assets/databases/${AssetDatabaseManager.cooccurrenceDb}': 1,
      });
      expect(await File(translationPath).exists(), isTrue);
      expect(await File(cooccurrencePath).exists(), isTrue);
      expect(await File('$translationPath.version').exists(), isTrue);
      expect(await File('$cooccurrencePath.version').exists(), isTrue);
    },
  );
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform({required this.appSupportPath});

  final String appSupportPath;

  @override
  Future<String?> getApplicationSupportPath() async => appSupportPath;
}
