import '../../data/services/vibe_bulk_operation_service.dart';
import '../../l10n/app_localizations.dart';

extension VibeBulkOperationErrorL10n on VibeBulkOperationError {
  String localized(AppLocalizations l10n) {
    final item = itemName ?? '';
    final error = details;

    return switch (code) {
      VibeBulkOperationErrorCode.entryNotFoundOrDeleteFailed =>
        l10n.vibeBulk_errorEntryNotFoundOrDeleteFailed(item),
      VibeBulkOperationErrorCode.deleteFailed =>
        l10n.vibeBulk_errorDeleteFailed(item, error ?? ''),
      VibeBulkOperationErrorCode.entryNotFound =>
        l10n.vibeBulk_errorEntryNotFound(item),
      VibeBulkOperationErrorCode.moveFailed => l10n.vibeBulk_errorMoveFailed(
        item,
        error ?? '',
      ),
      VibeBulkOperationErrorCode.favoriteFailed =>
        error == null || error.isEmpty
            ? l10n.vibeBulk_errorFavoriteFailed(item)
            : l10n.vibeBulk_errorFavoriteFailedWithDetails(item, error),
      VibeBulkOperationErrorCode.addTagsFailed =>
        error == null || error.isEmpty
            ? l10n.vibeBulk_errorAddTagsFailed(item)
            : l10n.vibeBulk_errorAddTagsFailedWithDetails(item, error),
      VibeBulkOperationErrorCode.removeTagsFailed =>
        error == null || error.isEmpty
            ? l10n.vibeBulk_errorRemoveTagsFailed(item)
            : l10n.vibeBulk_errorRemoveTagsFailedWithDetails(item, error),
      VibeBulkOperationErrorCode.exportNoFile =>
        l10n.vibeBulk_errorExportNoFile,
      VibeBulkOperationErrorCode.exportFailed =>
        l10n.vibeBulk_errorExportFailed(error ?? ''),
      VibeBulkOperationErrorCode.fileNotFound =>
        l10n.vibeBulk_errorFileNotFound(item),
      VibeBulkOperationErrorCode.noVibeData => l10n.vibeBulk_errorNoVibeData(
        item,
      ),
      VibeBulkOperationErrorCode.importFailed =>
        l10n.vibeBulk_errorImportFailed(item, error ?? ''),
      VibeBulkOperationErrorCode.processFileFailed =>
        l10n.vibeBulk_errorProcessFileFailed(item, error ?? ''),
    };
  }
}
