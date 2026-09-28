import 'package:flutter_riverpod/flutter_riverpod.dart';

/// View-only state that must survive responsive generation layout replacements.
final generationComparisonEnabledProvider = StateProvider<bool>((ref) => false);
