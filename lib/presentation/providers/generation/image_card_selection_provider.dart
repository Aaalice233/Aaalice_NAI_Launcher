import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../selection/card_selection.dart';
import '../../widgets/common/image_card_action.dart';
import '../image_generation_provider.dart';

final generationImageCardSelectionProvider =
    NotifierProvider<GenerationImageCardSelection, SelectionModeState>(
      GenerationImageCardSelection.new,
    );

/// The preview and history are two views of the same generation collection.
class GenerationImageCardSelection extends Notifier<SelectionModeState>
    with CardSelectionCommands {
  final actionRunner = ImageCardActionRunner();

  @override
  SelectionModeState build() {
    ref.onDispose(actionRunner.dispose);
    ref.listen(imageGenerationNotifierProvider, (_, next) {
      final available = next.selectableMergedImages
          .map((image) => image.id)
          .toSet();
      removeDeleted(state.selectedIds.difference(available));
    });
    return const SelectionModeState();
  }
}
