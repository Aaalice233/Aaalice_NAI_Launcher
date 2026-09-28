import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:mocktail/mocktail.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/presentation/widgets/common/card_drag_resource.dart';

class TestCardDropItem extends Fake with Diagnosticable implements DropItem {
  TestCardDropItem({this.localData, this.formats = const []});
  factory TestCardDropItem.resource(
    String id, {
    AgentChatResourceKind kind = AgentChatResourceKind.vibeLibraryEntry,
  }) => TestCardDropItem(
    localData: CardDragResource(
      id: id,
      fileName: id,
      reference: AgentChatResourceReference(
        kind: kind,
        source: 'test',
        resourceId: id,
      ),
    ).payload,
  );
  @override
  final Object? localData;
  final List<DataFormat> formats;
  @override
  DataReader? get dataReader => null;
  @override
  bool canProvide(DataFormat format) => formats.contains(format);
}

class TestCardDropSession extends Fake
    with Diagnosticable
    implements DropSession {
  TestCardDropSession(this.items);
  @override
  final List<DropItem> items;
  @override
  Set<DropOperation> get allowedOperations => {DropOperation.copy};
  final _disposed = ValueNotifier(false);
  @override
  Listenable get onDisposed => _disposed;
  void dispose() => _disposed.dispose();
}

final testCardDropPosition = DropPosition(
  local: Offset.zero,
  global: Offset.zero,
);
