import 'package:flutter/foundation.dart';

/// Lets an enclosing editor consume Back before ending the active edit.
class AutocompleteOverlayHandle extends ChangeNotifier {
  VoidCallback? _dismiss;
  bool get isOpen => _dismiss != null;
  void attach(VoidCallback dismiss) {
    _dismiss = dismiss;
    notifyListeners();
  }

  void detach(VoidCallback dismiss) {
    if (_dismiss != dismiss) return;
    _dismiss = null;
    notifyListeners();
  }

  void dismiss() => _dismiss?.call();
}
