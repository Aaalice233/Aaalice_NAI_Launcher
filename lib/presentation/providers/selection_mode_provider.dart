import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../selection/card_selection.dart';
export '../selection/card_selection.dart' show SelectionModeState;

part 'selection_mode_provider.g.dart';

@riverpod
class OnlineGallerySelectionNotifier extends _$OnlineGallerySelectionNotifier
    with CardSelectionCommands {
  @override
  SelectionModeState build() => const SelectionModeState();
}

@riverpod
class LocalGallerySelectionNotifier extends _$LocalGallerySelectionNotifier
    with CardSelectionCommands {
  @override
  SelectionModeState build() => const SelectionModeState();
}
