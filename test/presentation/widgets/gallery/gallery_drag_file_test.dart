import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_drag_file.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

void main() {
  final image = SanitizedShareImage(
    bytes: Uint8List.fromList([1, 2, 3]),
    fileName: 'shared.png',
    mimeType: 'image/png',
  );
  final file = File('tool/.tmp/gallery-drag-test.png');
  late _Item item;
  late _Session session;
  late List<File> deleted;

  setUp(() {
    item = _Item();
    session = _Session();
    deleted = [];
  });
  tearDown(() {
    item.dispose();
    session.dispose();
  });

  GalleryDragFile transfer({
    Future<File> Function(SanitizedShareImage)? write,
  }) => GalleryDragFile(
    item: item,
    session: session,
    writeFile: write ?? (_) async => file,
    deleteFile: (file) async => deleted.add(file),
  );

  test('registered file survives drop until native data is disposed', () async {
    final owner = transfer();
    expect(await owner.addImage(image), isTrue);
    expect(item.data, hasLength(2));
    item.registered.signal();
    session.completed.value = DropOperation.copy;
    expect(deleted, isEmpty);
    item.disposed.signal();
    await owner.release();
    await owner.release();
    expect(deleted, [file]);
    expect(item.registered.observing, isFalse);
    expect(item.disposed.observing, isFalse);
    expect(session.completed.observing, isFalse);
  });

  test('unregistered file is reclaimed when the gesture ends', () async {
    final owner = transfer();
    expect(await owner.addImage(image), isTrue);
    session.completed.value = DropOperation.none;
    await owner.release();
    expect(deleted, [file]);
    expect(item.disposed.observing, isFalse);
  });

  test('cancellation during writing waits for and reclaims the file', () async {
    final pending = Completer<File>();
    final owner = transfer(write: (_) => pending.future);
    final preparing = owner.addImage(image);
    session.completed.value = DropOperation.none;
    expect(deleted, isEmpty);
    pending.complete(file);
    expect(await preparing, isFalse);
    await owner.release();
    expect(item.data, isEmpty);
    expect(deleted, [file]);
  });

  test('already cancelled gesture does not write a file', () async {
    session.completed.value = DropOperation.none;
    var writes = 0;
    final owner = transfer(
      write: (_) async {
        writes++;
        return file;
      },
    );
    expect(await owner.addImage(image), isFalse);
    await owner.release();
    expect(writes, 0);
    expect(deleted, isEmpty);
  });

  test('each data item receives its own temporary file name', () async {
    final names = <String>[];
    final first = transfer(
      write: (image) async {
        names.add(image.fileName);
        return file;
      },
    );
    final second = transfer(
      write: (image) async {
        names.add(image.fileName);
        return file;
      },
    );
    await Future.wait([first.addImage(image), second.addImage(image)]);
    expect(names.toSet(), hasLength(2));
    session.completed.value = DropOperation.none;
    await Future.wait([first.release(), second.release()]);
  });
  test('write failure propagates and removes lifecycle listeners', () async {
    const error = FileSystemException('synthetic write failure');
    final owner = transfer(write: (_) async => throw error);
    await expectLater(owner.addImage(image), throwsA(same(error)));
    await owner.release();
    expect(item.data, isEmpty);
    expect(deleted, isEmpty);
    expect(item.registered.observing, isFalse);
    expect(item.disposed.observing, isFalse);
    expect(session.completed.observing, isFalse);
  });
}

class _Signal extends ChangeNotifier {
  bool get observing => hasListeners;
  void signal() => notifyListeners();
}

class _Item extends DragItem {
  final registered = _Signal();
  final disposed = _Signal();
  @override
  Listenable get onRegistered => registered;
  @override
  Listenable get onDisposed => disposed;
  void dispose() {
    registered.dispose();
    disposed.dispose();
  }
}

class _Session extends DragSession {
  final completed = _Completion();
  final _dragging = ValueNotifier(false);
  final _location = ValueNotifier<Offset?>(null);
  @override
  ValueListenable<DropOperation?> get dragCompleted => completed;
  @override
  ValueListenable<bool> get dragging => _dragging;
  @override
  ValueListenable<Offset?> get lastScreenLocation => _location;
  @override
  Future<List<Object?>?> getLocalData() async => null;
  void dispose() {
    completed.dispose();
    _dragging.dispose();
    _location.dispose();
  }
}

class _Completion extends ValueNotifier<DropOperation?> {
  _Completion() : super(null);
  bool get observing => hasListeners;
}
