import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_drag_session.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class _Session extends Mock implements DragSession {}

class _ObservableNotifier<T> extends ValueNotifier<T> {
  _ObservableNotifier(super.value);

  bool get hasRegisteredListeners => hasListeners;
}

void main() {
  test(
    'preparation stays opaque and each completed drag permits a new session',
    () {
      final state = GalleryDragSessionState();
      addTearDown(state.dispose);
      for (var i = 0; i < 3; i++) {
        final session = _Session();
        final dragging = _ObservableNotifier(false);
        final completed = _ObservableNotifier<DropOperation?>(null);
        addTearDown(dragging.dispose);
        addTearDown(completed.dispose);
        when(() => session.dragging).thenReturn(dragging);
        when(() => session.dragCompleted).thenReturn(completed);
        state.track(session);
        expect(state.value, isFalse);
        dragging.value = true;
        expect(state.value, isTrue);
        completed.value = DropOperation.copy;
        expect(state.value, isFalse);
        expect(dragging.hasRegisteredListeners, isFalse);
        expect(completed.hasRegisteredListeners, isFalse);
      }
    },
  );

  test('source disposal detaches callbacks before native drag finishes', () {
    final state = GalleryDragSessionState();
    final session = _Session();
    final dragging = _ObservableNotifier(false);
    final completed = _ObservableNotifier<DropOperation?>(null);
    addTearDown(dragging.dispose);
    addTearDown(completed.dispose);
    when(() => session.dragging).thenReturn(dragging);
    when(() => session.dragCompleted).thenReturn(completed);
    state.track(session);
    dragging.value = true;
    state.dispose();
    expect(dragging.hasRegisteredListeners, isFalse);
    expect(completed.hasRegisteredListeners, isFalse);
    completed.value = DropOperation.none;
    dragging.value = false;
  });
}
