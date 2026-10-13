import 'package:flutter/widgets.dart';

/// Dispatched when a descendant starts consuming a pointer drag without
/// emitting [ScrollNotification], so ancestor drag shortcuts can yield to it.
class DragClaimNotification extends Notification {
  const DragClaimNotification();
}
