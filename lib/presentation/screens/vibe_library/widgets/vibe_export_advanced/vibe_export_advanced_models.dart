import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../core/utils/vibe_export_utils.dart';
import '../../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../adaptive/interaction_policy.dart';

/// 计算切换载体图片按钮在当前交互策略下的最小命中尺寸。
Size resolveVibeExportChangeImageMinimumSize(InteractionPolicy policy) {
  return policy.touchAvailable ? const Size(48, 48) : Size.zero;
}

/// 导出验证结果
class VibeExportValidationResult {
  final bool isValid;
  final String? errorMessage;

  const VibeExportValidationResult({required this.isValid, this.errorMessage});
}

/// 载体图片候选项
class VibeExportCarrierImageOption {
  const VibeExportCarrierImageOption({
    required this.id,
    required this.label,
    required this.bytes,
  });

  final String id;
  final String label;
  final Uint8List bytes;
}

/// 构建当前选中条目可用的载体图片候选项列表。
List<VibeExportCarrierImageOption> buildVibeCarrierImageOptions(
  List<VibeLibraryEntry> entries,
) {
  if (entries.length != 1) {
    return const [];
  }

  final options = <VibeExportCarrierImageOption>[];
  for (final entry in entries) {
    for (final candidate in VibeExportUtils.collectImageCandidates(entry)) {
      final label = entries.length == 1
          ? candidate.label
          : '${entry.displayName} - ${candidate.label}';
      options.add(
        VibeExportCarrierImageOption(
          id: '${entry.id}:${candidate.id}',
          label: label,
          bytes: candidate.bytes,
        ),
      );
    }
  }
  return options;
}

/// 从已选外部预览图或候选列表中解析当前使用的载体图片字节。
Uint8List? findVibeCarrierImageBytes({
  required Uint8List? selectedImagePreview,
  required List<VibeExportCarrierImageOption> carrierImageOptions,
  required String? selectedCarrierImageId,
}) {
  if (selectedImagePreview != null && selectedImagePreview.isNotEmpty) {
    return selectedImagePreview;
  }

  if (selectedCarrierImageId == null) {
    return null;
  }

  for (final option in carrierImageOptions) {
    if (option.id == selectedCarrierImageId) {
      return option.bytes;
    }
  }
  return null;
}

/// 验证高级导出对话框的当前选项组合。
VibeExportValidationResult validateVibeExportOptions(
  BuildContext context, {
  required bool isExporting,
  required bool exportBundle,
  required bool embedIntoImage,
  required bool exportEncoding,
  required bool exportZip,
  required int entryCount,
  required Uint8List? currentCarrierImageBytes,
  required bool isSingleBundle,
  required bool exportWholeBundle,
  required List<bool> selectedInternalVibes,
}) {
  // 检查是否正在导出
  if (isExporting) {
    return const VibeExportValidationResult(isValid: false, errorMessage: null);
  }

  // 确保至少选择一种导出方式
  if (!exportBundle && !embedIntoImage && !exportEncoding && !exportZip) {
    return VibeExportValidationResult(
      isValid: false,
      errorMessage: context.l10n.vibe_export_selectAtLeastOneMethod,
    );
  }

  if (embedIntoImage && entryCount > 1) {
    return VibeExportValidationResult(
      isValid: false,
      errorMessage: context.l10n.vibe_export_batchPngUnsupported,
    );
  }

  // 嵌入图片需要选择图片
  if (embedIntoImage && currentCarrierImageBytes == null) {
    return VibeExportValidationResult(
      isValid: false,
      errorMessage: context.l10n.vibe_export_selectPngCarrier,
    );
  }

  // 如果是导出 bundle 内部单个 vibe，需要至少选择一个
  if (isSingleBundle && !exportWholeBundle && exportBundle) {
    final hasSelection = selectedInternalVibes.any((v) => v);
    if (!hasSelection) {
      return VibeExportValidationResult(
        isValid: false,
        errorMessage: context.l10n.vibe_export_selectAtLeastOneInternalVibe,
      );
    }
  }

  return const VibeExportValidationResult(isValid: true);
}

String displayVibeExportError(Object error) {
  return error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^Bad state:\s*'), '');
}
