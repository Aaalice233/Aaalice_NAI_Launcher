import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'hive2_compatibility_test_',
    );
    await File('test/fixtures/hive2/hive2_compat.hive').copy(
      '${hiveDirectory.path}${Platform.pathSeparator}hive2_compat.hive',
    );
    Hive.init(hiveDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('opens a box written by hive 2.2.3 and reads all primitive and collection values', () async {
    final box = await Hive.openBox<dynamic>('hive2_compat');

    expect(box.get('string'), 'NAI Launcher 旧数据兼容');
    expect(box.get('int'), 42);
    expect(box.get('negativeInt'), -9001);
    expect(box.get('double'), 3.141592653589793);
    expect(box.get('boolTrue'), isTrue);
    expect(box.get('boolFalse'), isFalse);

    final dateTime = box.get('dateTimeUtc');
    expect(dateTime, isA<DateTime>());
    expect(
      dateTime as DateTime,
      DateTime.utc(2026, 5, 18, 12, 30, 45, 123),
    );
    expect(dateTime.isUtc, isTrue);

    expect(
      box.get('list'),
      <Object?>['1girl', 'solo', 7, true, 0.75],
    );
    expect(
      box.get('map'),
      <Object?, Object?>{
        'model': 'nai-diffusion-4-full',
        'steps': 28,
        'scale': 5.5,
        'smToggle': false,
        'tags': <Object?>['masterpiece', 'best quality'],
      },
    );
  });
}
