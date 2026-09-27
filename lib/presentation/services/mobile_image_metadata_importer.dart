import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/localization_extension.dart';
import '../adaptive/adaptive_presenter.dart';
import '../adaptive/content_sized_adaptive_form.dart';
import '../utils/clipboard_image.dart';
import '../utils/dropped_file_reader.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/drop/global_drop_action_coordinator.dart';
import 'image_metadata_import_workflow.dart';

class PickedImageData {
  const PickedImageData({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

typedef ImageBytesPicker = Future<PickedImageData?> Function();
typedef PickedImageProcessor =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      PickedImageData image,
    );

/// Adapts a system-picked image to the shared desktop drop action flow.
class MobileImageMetadataImporter {
  MobileImageMetadataImporter({
    ImageBytesPicker? imageBytesPicker,
    PickedImageProcessor? imageProcessor,
  }) : _imageBytesPicker = imageBytesPicker ?? _pickImageBytes,
       _imageProcessor = imageProcessor ?? _processImage;

  static final MobileImageMetadataImporter shared =
      MobileImageMetadataImporter();

  /// 剪贴板取到的图没有文件名，给一个固定名字让下游的扩展名判断有据可依。
  static const String clipboardImageFileName = 'clipboard.png';

  /// iOS 上放行的图片扩展名（见 [_pickImageBytes] 的注释）。
  static const Set<String> _allowedImageExtensions = {'png', 'webp'};

  final ImageBytesPicker _imageBytesPicker;
  final PickedImageProcessor _imageProcessor;

  Future<void> run({
    required BuildContext context,
    required WidgetRef ref,
    VoidCallback? onNothingPicked,
  }) async {
    final PickedImageData image;
    try {
      final selectedImage = await _imageBytesPicker();
      // 偏离上游：上游把「用户取消」和「取不到图」合并成一条静默早退。剪贴板
      // 来源下这两件事必须区分——剪贴板里没有图片是要告诉用户的，否则点了按钮
      // 什么都不发生。
      if (selectedImage == null) {
        if (context.mounted) onNothingPicked?.call();
        return;
      }
      if (!context.mounted) return;
      image = selectedImage;
      if (image.bytes.isEmpty) {
        throw const FormatException('Selected image is empty');
      }
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to read selected image',
        error,
        stackTrace,
        'MobileMetadataImport',
      );
      if (context.mounted) {
        AppToast.error(context, context.l10n.metadataImport_readFailed);
      }
      return;
    }

    try {
      await _imageProcessor(context, ref, image);
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to process selected image',
        error,
        stackTrace,
        'MobileMetadataImport',
      );
      if (context.mounted) {
        AppToast.error(context, context.l10n.metadataImport_processFailed);
      }
    }
  }

  static Future<PickedImageData?> _pickImageBytes() async {
    // 偏离上游：上游恒用 FileType.custom + allowedExtensions。file_picker 在
    // iOS 上把 allowedExtensions 翻译成 UTI，未在 Info.plist 里声明过的扩展名
    // 会让对应文件在「文件」App 里整片置灰选不中。iOS 改成 FileType.any 再自
    // 己校验扩展名，行为等价而不依赖 UTI 注册；其余平台保持上游的原生过滤。
    final useSystemExtensionFilter = !PlatformCapabilities.current.isIOS;
    final result = await FilePicker.platform.pickFiles(
      type: useSystemExtensionFilter ? FileType.custom : FileType.any,
      allowedExtensions: useSystemExtensionFilter
          ? _allowedImageExtensions.toList()
          : null,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    if (!useSystemExtensionFilter &&
        !_allowedImageExtensions.contains(file.extension?.toLowerCase())) {
      throw const FormatException('The selected file is not a supported image');
    }
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError(
        'The system picker did not provide readable image bytes',
      );
    }
    return PickedImageData(fileName: file.name, bytes: bytes);
  }

  /// 从系统剪贴板取图；剪贴板里没有图片时返回 null（由 [run] 的
  /// `onNothingPicked` 提示）。
  @visibleForTesting
  static Future<PickedImageData?> pickClipboardImageBytes() async {
    final bytes = await readImageBytesFromClipboard();
    if (bytes == null || bytes.isEmpty) return null;
    return PickedImageData(fileName: clipboardImageFileName, bytes: bytes);
  }

  /// 从系统相册取图（iOS 的 PHPicker）。用户取消时返回 null。
  ///
  /// 偏离上游：上游只有 FilePicker 一条来源，而 iOS 的 [_pickImageBytes] 打开
  /// 的是「文件」App——看不到相册。生成的图在 iOS 上存进的是相册，所以相册必须
  /// 是一条独立来源。
  ///
  /// `allowCompression: false` 是这条来源能用的前提，不能删：file_picker 默认
  /// 的 true 会把 PHPicker 的 preferredAssetRepresentationMode 设成 Compatible，
  /// 系统可能把原图转码成兼容格式，PNG 的文本块与透明通道隐写一起丢，读出来就
  /// 没有生成参数了。false 对应 Current，拿到的是相册里存的原始文件字节。
  @visibleForTesting
  static Future<PickedImageData?> pickPhotoLibraryImageBytes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowCompression: false,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    // 相册里也有 JPEG/HEIC 照片，那些不可能带 NovelAI 参数；与文件来源同一套
    // 扩展名白名单，选错了走 run() 的「读取失败」提示而不是进勾选对话框。
    if (!_allowedImageExtensions.contains(file.extension?.toLowerCase())) {
      throw const FormatException(
        'The selected photo is not a supported image',
      );
    }
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError('The photo picker did not provide readable bytes');
    }
    return PickedImageData(fileName: file.name, bytes: bytes);
  }

  /// 直接进「选择要导入哪些参数」的勾选对话框。
  ///
  /// 偏离上游：上游的 [_processImage] 先弹 ImageDestinationDialog 问这张图的
  /// 去向（img2img / 反推 / Vibe / 解析参数…），选了「解析参数」才走到同一个
  /// 勾选对话框。生成页顶栏那个按钮的语义本身就是「解析参数」，所以跳过去向
  /// 这一问；勾选与落地仍然复用上游的 ImageMetadataImportWorkflow，不另起一
  /// 套（上一轮我们是自己拼 MetadataImportDialog + MetadataImportCoordinator，
  /// 现在上游把这条链路抽成了 workflow，直接采用）。
  static Future<void> _processMetadataImport(
    BuildContext context,
    WidgetRef ref,
    PickedImageData image,
  ) async {
    await ImageMetadataImportWorkflow.shared.run(
      context: context,
      read: ref.read,
      bytes: image.bytes,
    );
  }

  static Future<void> _processImage(
    BuildContext context,
    WidgetRef ref,
    PickedImageData image,
  ) {
    return GlobalDropActionCoordinator(
      context: context,
      ref: ref,
      openGenerationAfterAction: true,
      respectCurrentRouteDropTarget: false,
    ).processDroppedFile(
      DroppedFileData(fileName: image.fileName, bytes: image.bytes),
    );
  }
}

/// 「导入图片解析参数」的取图来源。
enum MobileImageImportSource {
  /// 系统相册（仅 iOS，见 [MobileImageMetadataImporter.pickPhotoLibraryImageBytes]）。
  photoLibrary,

  /// 系统文件选择器（iOS 上是「文件」App）。
  file,

  /// 系统剪贴板。
  ///
  /// 偏离上游：上游只有 FilePicker 一条来源。移动端没有 OS 级文件拖入，
  /// 「从别处复制一张图再粘进来」是最短的取图路径，必须补上。
  clipboard,
}

/// 「读取图片元数据」的来源选择面板：相册（仅 iOS）/ 文件 / 剪贴板。
///
/// 两个入口共用：
/// - 生成页顶栏一击入口（[askDestination] 为 false）：取到图后直接进参数勾选
///   对话框。偏离上游：上游唯一的移动端入口在「更多」底部面板里，要点两次才
///   够得着；而且上游的落地会先弹「这张图要做什么」的去向对话框，顶栏这个按钮
///   的语义本身就是「解析参数」，再问一次去向是多余的一步。勾选与落地仍复用
///   上游的 ImageMetadataImportWorkflow。
/// - iOS 上「更多」面板的同名入口（[askDestination] 为 true）：只把取图来源换
///   成这个面板，落地保持上游的去向对话框。上游那里直接开 FilePicker，iOS 上
///   只能进「文件」App、选不了相册。
///
/// 弹层走 [AdaptivePresenter.showForm]，窄屏是底部 sheet、宽屏是居中对话框
/// ——与上游其它多选一弹层一致，不自己 showModalBottomSheet。
Future<void> showMobileImageMetadataImportSheet({
  required BuildContext context,
  required WidgetRef ref,
  bool askDestination = false,
}) async {
  // 生成页的提示词输入框常处于聚焦态，先收键盘再弹面板，否则 sheet 会被软键盘
  // 顶掉一半。
  FocusManager.instance.primaryFocus?.unfocus();
  final offerPhotoLibrary = PlatformCapabilities.current.isIOS;
  final source = await AdaptivePresenter.showForm<MobileImageImportSource>(
    context: context,
    title: context.l10n.metadataImport_readImageMetadata,
    dialogWidth: 420,
    builder: (sheetContext, scrollController) => ContentSizedAdaptiveForm(
      scrollController: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      content: [
        if (offerPhotoLibrary)
          ListTile(
            key: const ValueKey('mobile-metadata-import-photo-library'),
            leading: const Icon(Icons.photo_library_outlined),
            // 复用上游已有的「从相册选择」文案（头像选择在用），不另起 key
            title: Text(sheetContext.l10n.auth_selectFromGallery),
            onTap: () => Navigator.of(
              sheetContext,
            ).pop(MobileImageImportSource.photoLibrary),
          ),
        ListTile(
          key: const ValueKey('mobile-metadata-import-file'),
          leading: const Icon(Icons.folder_open_outlined),
          title: Text(sheetContext.l10n.generation_importImageFromFile),
          onTap: () =>
              Navigator.of(sheetContext).pop(MobileImageImportSource.file),
        ),
        ListTile(
          key: const ValueKey('mobile-metadata-import-clipboard'),
          leading: const Icon(Icons.content_paste_go),
          title: Text(sheetContext.l10n.generation_pasteImageFromClipboard),
          onTap: () =>
              Navigator.of(sheetContext).pop(MobileImageImportSource.clipboard),
        ),
      ],
    ),
  );
  if (source == null || !context.mounted) return;

  final importer = MobileImageMetadataImporter(
    imageBytesPicker: switch (source) {
      MobileImageImportSource.photoLibrary =>
        MobileImageMetadataImporter.pickPhotoLibraryImageBytes,
      MobileImageImportSource.file =>
        MobileImageMetadataImporter._pickImageBytes,
      MobileImageImportSource.clipboard =>
        MobileImageMetadataImporter.pickClipboardImageBytes,
    },
    imageProcessor: askDestination
        ? MobileImageMetadataImporter._processImage
        : MobileImageMetadataImporter._processMetadataImport,
  );
  await importer.run(
    context: context,
    ref: ref,
    // 剪贴板里没有图片必须说出来，否则点了按钮什么都不发生；相册 / 文件
    // 返回 null 只可能是用户自己取消，静默即可。
    onNothingPicked: source == MobileImageImportSource.clipboard
        ? () => AppToast.info(context, context.l10n.generation_clipboardNoImage)
        : null,
  );
}
