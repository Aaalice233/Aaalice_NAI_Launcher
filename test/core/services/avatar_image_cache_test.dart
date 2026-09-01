import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/avatar_image_cache.dart';

void main() {
  test(
    'preload makes avatar bytes synchronously available for first frame',
    () async {
      final directory = await Directory.systemTemp.createTemp('avatar_cache_');
      final file = File('${directory.path}/avatar.png');
      final bytes = <int>[1, 2, 3, 4];
      await file.writeAsBytes(bytes);

      addTearDown(() async {
        AvatarImageCache.instance.evict(file.path);
        await directory.delete(recursive: true);
      });

      expect(AvatarImageCache.instance.get(file.path), isNull);
      await AvatarImageCache.instance.preload([file.path, file.path]);
      expect(AvatarImageCache.instance.get(file.path), bytes);

      AvatarImageCache.instance.evict(file.path);
      expect(AvatarImageCache.instance.get(file.path), isNull);
    },
  );
}
