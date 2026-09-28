import 'dart:convert';
import 'dart:typed_data';

import 'package:super_drag_and_drop/super_drag_and_drop.dart';

final cardDragFormat = CustomValueFormat<String>(
  applicationId: 'application/vnd.aaalice.card-resource+json',
  onEncode: (value, _) => value,
  onDecode: (value, _) async => switch (value) {
    String() => value,
    Uint8List() => utf8.decode(value),
    _ => null,
  },
);
