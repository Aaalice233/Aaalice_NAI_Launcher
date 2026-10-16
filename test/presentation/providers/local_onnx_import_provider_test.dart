import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/local_onnx_model_service.dart';
import 'package:nai_launcher/presentation/providers/local_onnx_import_provider.dart';

import '../../helpers/memory_local_storage.dart';

const _sources = [
  LocalOnnxImportSource(name: 'tagger.zip', path: 'tagger.zip'),
];

void main() {
  late _PendingOnnxModelService service;
  late ProviderContainer container;

  setUp(() {
    service = _PendingOnnxModelService();
    container = ProviderContainer(
      overrides: [localOnnxModelServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
  });

  LocalOnnxImportNotifier importer() =>
      container.read(localOnnxImportProvider.notifier);

  test('stays busy for every reader until the import settles', () async {
    final pending = importer().importSelections(_sources);

    // 离开设置页再进入时新的监听者读到的仍是进行中
    final reentered = container.listen(localOnnxImportProvider, (_, _) {});
    expect(reentered.read(), isTrue);
    await expectLater(importer().importSelections(_sources), throwsStateError);
    expect(service.imports, 1);

    service.finish(2);

    expect(await pending, 2);
    expect(reentered.read(), isFalse);
  });

  test('a failed import still clears the busy state', () async {
    final pending = importer().importSelections(_sources);

    service.fail(const FormatException('Invalid ONNX model ZIP'));

    await expectLater(pending, throwsFormatException);
    expect(container.read(localOnnxImportProvider), isFalse);
    service.reset();
    final next = importer().importSelections(_sources);
    service.finish(1);
    expect(await next, 1);
  });
}

class _PendingOnnxModelService extends LocalOnnxModelService {
  _PendingOnnxModelService() : super(MemoryLocalStorage());

  var _pending = Completer<int>();
  var imports = 0;

  void finish(int count) => _pending.complete(count);

  void fail(Object error) => _pending.completeError(error);

  void reset() => _pending = Completer<int>();

  @override
  Future<int> importTaggerSelections(List<LocalOnnxImportSource> sources) {
    imports++;
    return _pending.future;
  }
}
