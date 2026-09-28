import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../selection/card_selection.dart';
export '../selection/card_selection.dart' show SelectionModeState;

part 'vibe_library_selection_provider.g.dart';

@riverpod
class VibeLibrarySelectionNotifier extends _$VibeLibrarySelectionNotifier
    with CardSelectionCommands {
  @override
  SelectionModeState build() => const SelectionModeState();
}
