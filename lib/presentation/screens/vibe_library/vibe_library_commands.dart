import 'package:flutter/widgets.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../providers/vibe_library_provider.dart';

sealed class VibeLibraryCommand {
  const VibeLibraryCommand();
}

final class ClassifyVibeEntryCommand extends VibeLibraryCommand {
  const ClassifyVibeEntryCommand(this.entryId, this.categoryId);
  final String entryId;
  final String? categoryId;
}

final class FavoriteVibeEntryCommand extends VibeLibraryCommand {
  const FavoriteVibeEntryCommand(this.entryId);
  final String entryId;
}

final class ImportVibesCommand extends VibeLibraryCommand {
  const ImportVibesCommand();
}

final class PerformVibeDropCommand extends VibeLibraryCommand {
  const PerformVibeDropCommand(this.event);

  final PerformDropEvent event;
}

final class ImportImagesCommand extends VibeLibraryCommand {
  const ImportImagesCommand();
}

final class ImportClipboardCommand extends VibeLibraryCommand {
  const ImportClipboardCommand();
}

final class ShowImportMenuCommand extends VibeLibraryCommand {
  const ShowImportMenuCommand(this.position);

  final Offset position;
}

final class ExportVibesCommand extends VibeLibraryCommand {
  const ExportVibesCommand([this.entries]);

  final List<VibeLibraryEntry>? entries;
}

final class OpenLibraryFolderCommand extends VibeLibraryCommand {
  const OpenLibraryFolderCommand();
}

final class RefreshLibraryCommand extends VibeLibraryCommand {
  const RefreshLibraryCommand();
}

final class ToggleCategoryPanelCommand extends VibeLibraryCommand {
  const ToggleCategoryPanelCommand();
}

final class ShowCategoryPanelCommand extends VibeLibraryCommand {
  const ShowCategoryPanelCommand();
}

final class SelectCategoryCommand extends VibeLibraryCommand {
  const SelectCategoryCommand(this.categoryId);

  final String? categoryId;
}

final class CreateCategoryCommand extends VibeLibraryCommand {
  const CreateCategoryCommand();
}

final class RenameCategoryCommand extends VibeLibraryCommand {
  const RenameCategoryCommand(this.categoryId, this.name);

  final String categoryId;
  final String name;
}

final class DeleteCategoryCommand extends VibeLibraryCommand {
  const DeleteCategoryCommand(this.categoryId);

  final String categoryId;
}

final class EnterSelectionModeCommand extends VibeLibraryCommand {
  const EnterSelectionModeCommand();
}

final class ExitSelectionModeCommand extends VibeLibraryCommand {
  const ExitSelectionModeCommand();
}

final class ToggleCurrentPageSelectionCommand extends VibeLibraryCommand {
  const ToggleCurrentPageSelectionCommand({required this.select});

  final bool select;
}

final class ChangeSortCommand extends VibeLibraryCommand {
  const ChangeSortCommand(this.order);

  final VibeLibrarySortOrder order;
}

final class ChangePageSizeCommand extends VibeLibraryCommand {
  const ChangePageSizeCommand(this.size);

  final int size;
}

final class ChangePageCommand extends VibeLibraryCommand {
  const ChangePageCommand(this.page);

  final int page;
}

final class SendSelectionToGenerationCommand extends VibeLibraryCommand {
  const SendSelectionToGenerationCommand();
}

final class MoveSelectionCommand extends VibeLibraryCommand {
  const MoveSelectionCommand();
}

final class ExportSelectionCommand extends VibeLibraryCommand {
  const ExportSelectionCommand();
}

final class ToggleSelectionFavoriteCommand extends VibeLibraryCommand {
  const ToggleSelectionFavoriteCommand();
}

final class MarkSelectionEncodingModelCommand extends VibeLibraryCommand {
  const MarkSelectionEncodingModelCommand();
}

final class DeleteSelectionCommand extends VibeLibraryCommand {
  const DeleteSelectionCommand();
}
