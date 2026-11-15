import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../selection/card_selection.dart';
export '../selection/card_selection.dart' show SelectionModeState;

final preciseRefLibrarySelectionNotifierProvider =
    NotifierProvider.autoDispose<
      PreciseRefLibrarySelectionNotifier,
      SelectionModeState
    >(PreciseRefLibrarySelectionNotifier.new);

class PreciseRefLibrarySelectionNotifier extends Notifier<SelectionModeState>
    with CardSelectionCommands {
  @override
  SelectionModeState build() => const SelectionModeState();
}
