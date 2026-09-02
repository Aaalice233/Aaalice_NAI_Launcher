import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/thumbnail_crop_dialog.dart';

void main() {
  final testImage = File('assets/icons/android/playstore-icon.png').absolute;

  testWidgets('手机竖屏完整显示可操作预览与 SafeArea 内动作', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    await _cacheFileImage(tester, testImage);
    ThumbnailCropResult? result;
    await _pumpDialog(
      tester,
      imagePath: testImage.path,
      onConfirm: (value) => result = value,
    );

    final preview = tester.getRect(
      find.byKey(const ValueKey('thumbnail-crop-preview')),
    );
    final image = tester.getRect(
      find.byKey(const ValueKey('thumbnail-crop-image')),
    );
    expect(preview.left, greaterThanOrEqualTo(12));
    expect(preview.right, lessThanOrEqualTo(348));
    expect(preview.width, greaterThan(300));
    expect(image.left, greaterThanOrEqualTo(preview.left));
    expect(image.right, lessThanOrEqualTo(preview.right));
    expect(image.top, greaterThanOrEqualTo(preview.top));
    expect(image.bottom, lessThanOrEqualTo(preview.bottom));
    expect(image.width, greaterThan(150));

    for (final label in ['重置', '取消', '确定']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.top, greaterThanOrEqualTo(24));
      expect(rect.bottom, lessThanOrEqualTo(776));
    }

    final center = preview.center;
    final first = await tester.startGesture(
      center.translate(-30, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center.translate(30, 0),
      pointer: 2,
    );
    await first.moveBy(const Offset(-30, 0));
    await second.moveBy(const Offset(30, 0));
    await tester.pump();
    await first.up();
    await second.up();

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.scale, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('桌面保留 640x360 预览并支持滚轮缩放与拖拽', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _cacheFileImage(tester, testImage);
    ThumbnailCropResult? result;
    await _pumpDialog(
      tester,
      imagePath: testImage.path,
      onConfirm: (value) => result = value,
    );

    final previewFinder = find.byKey(const ValueKey('thumbnail-crop-preview'));
    expect(tester.getSize(previewFinder), const Size(640, 360));
    final center = tester.getCenter(previewFinder);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, -40),
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.dragFrom(center, const Offset(30, 20));
    await tester.pump();

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.scale, greaterThan(1));
    expect(result!.offsetX.abs() + result!.offsetY.abs(), greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('复杂裁剪通过 AdaptivePresenter 呈现并由系统返回取消', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    await _cacheFileImage(tester, testImage);
    ThumbnailCropResult? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showThumbnailCropDialog(
                context: context,
                imagePath: testImage.path,
                onConfirm: (value) => result = value,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('adaptive-full-screen-form'));
    expect(panel, findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(
      find.byKey(const ValueKey('thumbnail-crop-preview')),
      findsOneWidget,
    );
    for (final tooltip in ['重置', '取消', '确定']) {
      expect(find.byTooltip(tooltip), findsAtLeastNWidgets(1));
    }
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(result, isNull);
  });

  testWidgets('320 宽 3x 文本与 IME 下保留预览和全部动作', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    await _cacheFileImage(tester, testImage);
    ThumbnailCropResult? result;
    await _pumpDialog(
      tester,
      imagePath: testImage.path,
      textScale: 3,
      onConfirm: (value) => result = value,
    );

    final preview = tester.getRect(
      find.byKey(const ValueKey('thumbnail-crop-preview')),
    );
    expect(preview.width, greaterThan(200));
    expect(preview.height, greaterThan(40));
    expect(preview.left, greaterThanOrEqualTo(12));
    expect(preview.right, lessThanOrEqualTo(308));
    for (final tooltip in ['重置', '取消', '确定']) {
      expect(find.byTooltip(tooltip), findsAtLeastNWidgets(1));
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('确定'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
  });

  testWidgets('1600 宽视口限制桌面内容宽度与预览尺寸', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _cacheFileImage(tester, testImage);
    await _pumpDialog(tester, imagePath: testImage.path, onConfirm: (_) {});

    expect(
      tester.getSize(find.byKey(const ValueKey('thumbnail-crop-frame'))).width,
      lessThanOrEqualTo(720),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('thumbnail-crop-preview'))),
      const Size(640, 360),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机横屏大字体无横向或纵向溢出', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(left: 24, right: 24);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    await _cacheFileImage(tester, testImage);
    await _pumpDialog(
      tester,
      imagePath: testImage.path,
      textScale: 1.6,
      onConfirm: (_) {},
    );

    final preview = tester.getRect(
      find.byKey(const ValueKey('thumbnail-crop-preview')),
    );
    expect(preview.width, greaterThan(300));
    expect(preview.height, greaterThan(80));
    expect(tester.getRect(find.text('确定')).right, lessThanOrEqualTo(776));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required String imagePath,
  required ValueChanged<ThumbnailCropResult> onConfirm,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: ThumbnailCropDialog(imagePath: imagePath, onConfirm: onConfirm),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _cacheFileImage(WidgetTester tester, File file) async {
  await tester.runAsync(() async {
    final completed = Completer<void>();
    final stream = FileImage(file).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, __) {
        if (!completed.isCompleted) completed.complete();
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completed.isCompleted) {
          completed.completeError(error, stackTrace);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    await completed.future;
  });
}
