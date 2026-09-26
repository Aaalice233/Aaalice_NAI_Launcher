import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/system_gallery_publisher.dart';
import 'package:nai_launcher/core/utils/image_save_utils.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/services/generation_result_saver.dart';
import 'package:nai_launcher/presentation/screens/generation/services/generation_save_service.dart';

void main() {
  const root = 'gallery-root';
  final failed = SystemGalleryPublishFailed(
    StateError('media store'),
    StackTrace.empty,
  );

  GenerationResultNewlySaved newlySaved(SystemGalleryPublishOutcome outcome) =>
      GenerationResultNewlySaved(
        rootPath: root,
        saved: SavedResultImage(
          path: '$root/a.png',
          bytes: Uint8List(0),
          contentHash: 'hash',
        ),
        systemGalleryOutcome: outcome,
      );
  const alreadySaved = GenerationResultAlreadySaved(
    rootPath: root,
    path: '$root/a.png',
  );
  GenerationResultSaveReport report(
    List<GenerationResultFile> files, {
    List<GenerationResultSaveFailure> failures = const [],
  }) => GenerationResultSaveReport(
    rootPath: root,
    files: files,
    failures: failures,
  );

  /// 返回本次弹出的全部提示文案。
  Future<List<String>> toastsOf(
    WidgetTester tester,
    void Function(BuildContext context) show,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold();
          },
        ),
      ),
    );
    show(hostContext);
    await tester.pump(const Duration(milliseconds: 301));
    final texts = [
      for (final widget in tester.widgetList<Text>(find.byType(Text)))
        if (widget.data case final String data) data,
    ];
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 301));
    return texts;
  }

  group('保存汇总提示', () {
    testWidgets('图库根目录未设置', (tester) async {
      expect(
        await toastsOf(
          tester,
          (context) => GenerationSaveService.showSaveReport(context, null),
        ),
        ['未设置保存目录'],
      );
    });

    testWidgets('有失败时只报第一条错误', (tester) async {
      expect(
        await toastsOf(
          tester,
          (context) => GenerationSaveService.showSaveReport(
            context,
            report(
              [newlySaved(const SystemGalleryUnsupported())],
              failures: [
                (
                  imageId: 'b',
                  error: StateError('disk full'),
                  stackTrace: StackTrace.empty,
                ),
                (
                  imageId: 'c',
                  error: StateError('other'),
                  stackTrace: StackTrace.empty,
                ),
              ],
            ),
          ),
        ),
        ['保存失败: Bad state: disk full'],
      );
    });

    testWidgets('新写入时按系统相册结果提示', (tester) async {
      expect(
        await toastsOf(
          tester,
          (context) => GenerationSaveService.showSaveReport(
            context,
            report([newlySaved(const SystemGalleryUnsupported())]),
          ),
        ),
        ['图片已保存到: $root'],
      );
      expect(
        await toastsOf(
          tester,
          (context) => GenerationSaveService.showSaveReport(
            context,
            report([alreadySaved, newlySaved(failed)]),
          ),
        ),
        ['已保存到应用图库，但无法导出到系统相册：Bad state: media store'],
      );
    });

    testWidgets('全部复用已有文件时提示所在图库', (tester) async {
      expect(
        await toastsOf(
          tester,
          (context) => GenerationSaveService.showSaveReport(
            context,
            report([alreadySaved]),
          ),
        ),
        ['图片已保存到: $root'],
      );
    });
  });

  group('收藏与定位前补存的提示', () {
    testWidgets('定位文件夹只在新写入时提示', (tester) async {
      expect(
        await toastsOf(
          tester,
          (context) => GenerationSaveService.showNewlySavedFeedback(
            context,
            alreadySaved,
          ),
        ),
        isEmpty,
      );
      expect(
        await toastsOf(
          tester,
          (context) => GenerationSaveService.showNewlySavedFeedback(
            context,
            newlySaved(const SystemGallerySyncDisabled()),
          ),
        ),
        ['已保存到应用图库'],
      );
    });

    testWidgets('收藏只补报系统相册发布失败', (tester) async {
      for (final file in [
        alreadySaved,
        newlySaved(const SystemGalleryPublished()),
      ]) {
        expect(
          await toastsOf(
            tester,
            (context) =>
                GenerationSaveService.showSystemGalleryFailure(context, file),
          ),
          isEmpty,
        );
      }
      expect(
        await toastsOf(
          tester,
          (context) => GenerationSaveService.showSystemGalleryFailure(
            context,
            newlySaved(failed),
          ),
        ),
        ['已保存到应用图库，但无法导出到系统相册：Bad state: media store'],
      );
    });
  });
}
