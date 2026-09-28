import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../selection/card_selection.dart';
export '../selection/card_selection.dart' show SelectionModeState;

part 'tag_library_selection_provider.g.dart';

@riverpod
class TagLibrarySelectionNotifier extends _$TagLibrarySelectionNotifier
    with CardSelectionCommands {
  @override
  SelectionModeState build() => const SelectionModeState();
}
