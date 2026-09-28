import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/model3d_editor/model3d_library_service.dart';

void main() {
  late Directory tempDir;
  late Directory libraryDir;
  late Model3dLibraryService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('model3d_lib_test');
    libraryDir = Directory('${tempDir.path}/library');
    service = Model3dLibraryService(libraryDir: libraryDir);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<File> sourceFile(String name, List<int> bytes) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  test('imports model and returns content-addressed ref', () async {
    final source = await sourceFile('a.glb', [1, 2, 3]);
    final ref = await service.importModel(source);
    expect(ref, startsWith('lib:'));
    final hash = ref.substring(4);
    expect(hash, hasLength(64));
    expect(File('${libraryDir.path}/$hash.glb').existsSync(), isTrue);
  });

  test('deduplicates identical content', () async {
    final s1 = await sourceFile('a.glb', [1, 2, 3]);
    final s2 = await sourceFile('b.glb', [1, 2, 3]);
    final ref1 = await service.importModel(s1);
    final ref2 = await service.importModel(s2);
    expect(ref1, ref2);
    expect(
      libraryDir.listSync().whereType<File>(),
      hasLength(1),
    );
  });

  test('rejects oversized file', () async {
    final small = Model3dLibraryService(
      libraryDir: libraryDir,
      maxFileBytes: 2,
    );
    final source = await sourceFile('big.glb', [1, 2, 3]);
    expect(
      () => small.importModel(source),
      throwsA(isA<Model3dImportException>()),
    );
  });

  test('urlPathFor maps refs', () {
    final hash = 'c' * 64;
    expect(service.urlPathFor('lib:$hash'), '/models/$hash.glb');
    expect(
      service.urlPathFor(Model3dLibraryService.builtinMannequinRef),
      isNull,
    );
    expect(service.urlPathFor('bogus:x'), isNull);
  });

  test('resolveFile maps only lib refs', () {
    final hash = 'd' * 64;
    expect(service.resolveFile('lib:$hash')?.path, contains('$hash.glb'));
    expect(
      service.resolveFile(Model3dLibraryService.builtinMannequinRef),
      isNull,
    );
  });

  test('rejects path traversal and malformed lib refs', () {
    expect(service.urlPathFor('lib:../evil'), isNull);
    expect(service.resolveFile('lib:../evil'), isNull);
    expect(service.urlPathFor('lib:not-a-hash'), isNull);
    expect(service.resolveFile('lib:not-a-hash'), isNull);
  });

  test('rejects uppercase hex hash', () {
    final hash = 'C' * 64;
    expect(service.resolveFile('lib:$hash'), isNull);
  });

  test('import leaves only the final file and no temp files', () async {
    final source = await sourceFile('a.glb', [1, 2, 3]);
    final ref = await service.importModel(source);
    final hash = ref.substring(4);
    final files = libraryDir.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    expect(files.single.path, endsWith('$hash.glb'));
    expect(files.single.path, isNot(contains('.tmp')));
  });
}
