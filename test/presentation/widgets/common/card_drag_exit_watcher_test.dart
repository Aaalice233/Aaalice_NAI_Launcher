import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/card_drag_exit_watcher.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class _Notifier<T> extends ValueNotifier<T> {
  _Notifier(super.value);
  bool get observed => hasListeners;
}

class _Session extends DragSession {
  final completed = _Notifier<DropOperation?>(null);
  final location = _Notifier<Offset?>(null);
  final _dragging = ValueNotifier(true);

  @override
  ValueListenable<DropOperation?> get dragCompleted => completed;
  @override
  ValueListenable<bool> get dragging => _dragging;
  @override
  ValueListenable<Offset?> get lastScreenLocation => location;
  @override
  Future<List<Object?>?> getLocalData() async => null;

  bool get observed => location.observed || completed.observed;

  void dispose() {
    completed.dispose();
    location.dispose();
    _dragging.dispose();
  }
}

void main() {
  late _Session session;
  late int exits;

  setUp(() {
    session = _Session();
    exits = 0;
  });
  tearDown(() => session.dispose());

  // A 200x100 logical view at 1.5x, placed at physical (1000, 500), with the
  // drag starting at logical (20, 10) = physical (1030, 515).
  CardDragExitWatcher watch() => CardDragExitWatcher(
    session: session,
    startLocation: const Offset(20, 10),
    devicePixelRatio: 1.5,
    physicalSize: const Size(300, 150),
    onExit: () => exits++,
  );

  test('moving inside the view never fires', () {
    watch();
    session.location.value = const Offset(1030, 515);
    session.location.value = const Offset(1299, 649);
    session.location.value = const Offset(1000, 500);
    expect(exits, 0);
    expect(session.observed, isTrue);
  });

  test('leaving the view fires once and stops listening', () {
    watch();
    session.location.value = const Offset(1030, 515);
    session.location.value = const Offset(1301, 600);
    session.location.value = const Offset(2000, 600);
    expect(exits, 1);
    expect(session.observed, isFalse);
  });

  test('a finished drag stops listening without firing', () {
    watch();
    session.location.value = const Offset(1030, 515);
    session.completed.value = DropOperation.copy;
    expect(session.observed, isFalse);
    session.location.value = const Offset(5000, 5000);
    expect(exits, 0);
  });

  test('a drag that already ended is never watched', () {
    session.completed.value = DropOperation.none;
    watch();
    expect(session.observed, isFalse);
  });
}
