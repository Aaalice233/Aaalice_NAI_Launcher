import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_view.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/prompt_scroll_coordinator.dart';

import '../../../../helpers/memory_local_storage.dart';

void main() {
  for (final scenario in [
    (name: 'text', tags: false, short: false, readOnly: false),
    (name: 'tags', tags: true, short: false, readOnly: false),
    (name: 'short text', tags: false, short: true, readOnly: false),
    (name: 'short tags', tags: true, short: true, readOnly: false),
    (name: 'read-only text', tags: false, short: false, readOnly: true),
    (name: 'short read-only text', tags: false, short: true, readOnly: true),
  ]) {
    testWidgets(
      '${scenario.name} contains overflow and reveals clipped editor edges',
      (tester) async {
        final prompt = TextEditingController(
          text: scenario.short
              ? 'cat'
              : List.generate(120, (i) => 'tag_$i').join(',\n'),
        );
        final page = ScrollController(initialScrollOffset: 100);
        final height = ValueNotifier<double>(160);
        addTearDown(height.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWith(
                (ref) => MemoryLocalStorage(),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: SingleChildScrollView(
                  controller: page,
                  child: Column(
                    children: [
                      const SizedBox(height: 200),
                      ValueListenableBuilder<double>(
                        valueListenable: height,
                        builder: (context, value, child) =>
                            SizedBox(height: value, child: child),
                        child: UnifiedPromptInput(
                          controller: prompt,
                          expands: true,
                          enableAssistant: false,
                          config: UnifiedPromptConfig(
                            enableAutocomplete: false,
                            enableSyntaxHighlight: false,
                            enableTagMode: true,
                            readOnly: scenario.readOnly,
                          ),
                        ),
                      ),
                      const SizedBox(height: 1400),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        if (scenario.tags) {
          await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
        }
        await tester.pumpAndSettle();
        // 本组断言描述未聚焦时的归属：标签模式挂载即自动聚焦，先让开
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final editor = find.byType(UnifiedPromptInput);
        final pointer = TestPointer(1, PointerDeviceKind.mouse)
          ..hover(tester.getCenter(editor));
        final initialPageOffset = page.offset;
        // 归属与锁存都按事件时间戳判定"同一串滚动"，测试显式推进这个时钟
        const sameRun = Duration(milliseconds: 30);
        const newRun = Duration(milliseconds: 200);
        var clock = Duration.zero;
        Future<bool?> sendWheel(
          double delta, {
          Duration gap = newRun,
          Offset? at,
        }) async {
          clock += gap;
          pointer.hover(at ?? tester.getCenter(editor));
          bool? platformDefault;
          await tester.sendEventToBinding(
            pointer.scroll(
              Offset(0, delta),
              timeStamp: clock,
              onRespond: ({required bool allowPlatformDefault}) =>
                  platformDefault = allowPlatformDefault,
            ),
          );
          await tester.pump();
          return platformDefault;
        }

        // 编辑器吃下滚动量（短内容没有内部滚动，直接归页面）
        Future<void> wheel(double delta, {Duration gap = newRun}) async {
          final beforePageOffset = page.offset;
          final platformDefault = await sendWheel(delta, gap: gap);
          if (scenario.short) {
            expect(
              page.offset,
              delta > 0
                  ? greaterThan(beforePageOffset)
                  : lessThan(beforePageOffset),
            );
          } else {
            expect(page.offset, beforePageOffset);
          }
          expect(platformDefault, isFalse);
        }

        // 编辑器停在边界超过锁存窗口后，余量交还页面
        Future<void> chainedWheel(double delta) async {
          final beforePageOffset = page.offset;
          final platformDefault = await sendWheel(delta, gap: newRun);
          expect(
            page.offset,
            delta > 0
                ? greaterThan(beforePageOffset)
                : lessThan(beforePageOffset),
          );
          expect(platformDefault, isFalse);
        }

        // 编辑器已在顶端且锁存未武装：第一格滚轮就归页面
        await chainedWheel(-60);
        if (!scenario.short) {
          final inner = tester
              .stateList<ScrollableState>(
                find.descendant(
                  of: scenario.tags ? find.byType(TagEditorView) : editor,
                  matching: find.byType(Scrollable),
                ),
              )
              .firstWhere((state) => state.position.maxScrollExtent > 0);
          final before = inner.position.pixels;
          await wheel(60);
          expect(inner.position.pixels, greaterThan(before));
          inner.position.jumpTo(inner.position.maxScrollExtent);
        }
        // 同一串滚动里撞上底部：锁存吸收，页面不动
        await wheel(60, gap: sameRun);
        await wheel(60, gap: sameRun);

        if (!scenario.short) {
          final longText = prompt.text;
          final beforeShortText = page.offset;
          prompt.text = 'cat';
          await tester.pumpAndSettle();
          await sendWheel(60);
          expect(page.offset, greaterThan(beforeShortText));
          prompt.text = longText;
          await tester.pumpAndSettle();
          page.jumpTo(initialPageOffset);
          await tester.pump();
          // 长文本恢复后编辑器重新接管
          await wheel(60);

          final inner = tester
              .stateList<ScrollableState>(
                find.descendant(
                  of: scenario.tags ? find.byType(TagEditorView) : editor,
                  matching: find.byType(Scrollable),
                ),
              )
              .firstWhere((state) => state.position.maxScrollExtent > 0);
          inner.position.jumpTo(100);
          final coordinator = find.byType(PromptScrollCoordinator);
          final top = tester.getTopLeft(coordinator).dy;
          page.jumpTo(page.offset + top + 30);
          await tester.pump();
          final clippedPage = page.offset;
          await sendWheel(
            -60,
            at: Offset(tester.getCenter(coordinator).dx, 20),
          );
          expect(page.offset, closeTo(clippedPage - 30, .01));
          expect(inner.position.pixels, closeTo(70, .01));
          expect(tester.getTopLeft(coordinator).dy, closeTo(0, .01));
          inner.position.jumpTo(0);
          await tester.pump();
          // 编辑器刚滚动过又撞上顶端：锁存窗口内吸收，过期后余量交还页面
          final revealedPage = page.offset;
          await sendWheel(
            -60,
            gap: sameRun,
            at: tester.getCenter(coordinator),
          );
          expect(page.offset, revealedPage);
          await chainedWheel(-60);
          page.jumpTo(revealedPage);
          await tester.pump();

          inner.position.jumpTo(100);
          final trackpad = await tester.createGesture(
            kind: PointerDeviceKind.trackpad,
          );
          await trackpad.panZoomStart(
            tester.getCenter(coordinator),
            timeStamp: clock,
          );
          await trackpad.panZoomUpdate(
            tester.getCenter(coordinator),
            pan: const Offset(0, -40),
            timeStamp: clock,
          );
          await tester.pump();
          await trackpad.panZoomUpdate(
            tester.getCenter(coordinator),
            pan: const Offset(0, -70),
            timeStamp: clock,
          );
          await tester.pump();
          await trackpad.panZoomEnd();
          await tester.pumpAndSettle();
          expect(page.offset, revealedPage);
          expect(inner.position.pixels, closeTo(170, .01));

          // 触控板与滚轮共用同一套锁存：撞上底部后余量同样交还页面
          inner.position.jumpTo(inner.position.maxScrollExtent);
          await tester.pump();
          await trackpad.panZoomStart(
            tester.getCenter(coordinator),
            timeStamp: clock,
          );
          await trackpad.panZoomUpdate(
            tester.getCenter(coordinator),
            pan: const Offset(0, -40),
            timeStamp: clock,
          );
          await tester.pump();
          expect(page.offset, revealedPage);
          clock += const Duration(milliseconds: 200);
          await trackpad.panZoomUpdate(
            tester.getCenter(coordinator),
            pan: const Offset(0, -80),
            timeStamp: clock,
          );
          await tester.pump();
          expect(page.offset, greaterThan(revealedPage));
          await trackpad.panZoomEnd();
          await tester.pumpAndSettle();
          page.jumpTo(revealedPage);
          await tester.pump();

          page.jumpTo(page.offset + 30);
          inner.position.jumpTo(100);
          await tester.pump();
          await trackpad.panZoomStart(const Offset(400, 20), timeStamp: clock);
          await trackpad.panZoomUpdate(
            const Offset(400, 20),
            pan: const Offset(0, 60),
            timeStamp: clock,
          );
          await tester.pump();
          await trackpad.panZoomEnd();
          await tester.pumpAndSettle();
          expect(page.offset, closeTo(revealedPage, .01));
          expect(inner.position.pixels, closeTo(70, .01));

          // A short landscape viewport clips the bottom of the same editor.
          await tester.binding.setSurfaceSize(const Size(800, 240));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          page.jumpTo(0);
          inner.position.jumpTo(100);
          await tester.pumpAndSettle();
          final hiddenBottom = tester.getBottomRight(coordinator).dy - 240;
          expect(hiddenBottom, greaterThan(0));
          await sendWheel(hiddenBottom + 35, at: const Offset(400, 220));
          expect(page.offset, closeTo(hiddenBottom, .01));
          expect(inner.position.pixels, closeTo(135, .01));
          expect(tester.getBottomRight(coordinator).dy, closeTo(240, .01));
          await tester.binding.setSurfaceSize(null);
          await tester.pumpAndSettle();

          // Manual height changes update the live viewport, not cached extents.
          height.value = 900;
          page.jumpTo(200);
          await tester.pumpAndSettle();
          inner.position.jumpTo(100);
          final hiddenTallBottom = tester.getBottomRight(coordinator).dy - 600;
          final tallPage = page.offset;
          await sendWheel(hiddenTallBottom + 25, at: const Offset(400, 300));
          expect(page.offset, closeTo(tallPage + hiddenTallBottom, .01));
          expect(inner.position.pixels, closeTo(125, .01));
          height.value = 120;
          page.jumpTo(100);
          await tester.pumpAndSettle();
          inner.position.jumpTo(inner.position.maxScrollExtent);
          // 手动高度下同样先吸收一拍，再把余量交还页面
          await wheel(60, gap: sameRun);
          await chainedWheel(60);

          if (!scenario.readOnly) {
            inner.position.jumpTo(0);
            await tester.pump();
            if (scenario.tags) {
              await tester.tap(find.text('tag_0'));
            } else {
              prompt.selection = const TextSelection(
                baseOffset: 0,
                extentOffset: 5,
              );
            }
            await tester.pumpAndSettle();
            final beforeWeight = prompt.text;
            final beforeWeightPage = page.offset;
            final beforeWeightInner = inner.position.pixels;
            pointer.hover(
              scenario.tags
                  ? tester.getCenter(find.text('tag_0'))
                  : tester.getCenter(coordinator),
            );
            await tester.sendEventToBinding(
              pointer.scroll(const Offset(0, -20)),
            );
            await tester.pumpAndSettle();
            expect(prompt.text, isNot(beforeWeight));
            expect(page.offset, beforeWeightPage);
            expect(inner.position.pixels, beforeWeightInner);
          }
        }

        final beforeOutsideScroll = page.offset;
        pointer.hover(const Offset(20, 450));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, 60)));
        await tester.pump();
        expect(page.offset, greaterThan(beforeOutsideScroll));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 250));
        page.dispose();
        prompt.dispose();
      },
    );
  }

  for (final focused in [false, true]) {
    testWidgets(
      'page keeps a scroll run when the editor slides under the cursor'
      '${focused ? ' while focused' : ''}',
      (tester) async {
        final prompt = TextEditingController(
          text: List.generate(120, (i) => 'tag_$i').join(',\n'),
        );
        final focusNode = FocusNode();
        final page = await _pumpScrollPage(tester, prompt, focusNode: focusNode);
        if (focused) {
          focusNode.requestFocus();
          await tester.pumpAndSettle();
        }

        // 指针钉死不动，页面滚动时提示词框从它下面经过
        const cursor = Offset(400, 300);
        final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(cursor);
        var clock = Duration.zero;
        Future<void> run(double delta, int ticks) async {
          for (var tick = 0; tick < ticks; tick++) {
            clock += const Duration(milliseconds: 30);
            final before = page.offset;
            pointer.hover(cursor);
            await tester.sendEventToBinding(
              pointer.scroll(Offset(0, delta), timeStamp: clock),
            );
            await tester.pump();
            expect(
              page.offset,
              isNot(before),
              reason: 'delta $delta tick $tick stalled at $before',
            );
          }
        }

        await run(60, 8);
        await run(-60, 8);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 250));
        page.dispose();
        focusNode.dispose();
        prompt.dispose();
      },
    );
  }

  for (final tags in [false, true]) {
    testWidgets(
      'a focused ${tags ? 'tag' : 'text'} editor never hands its boundary '
      'to the page',
      (tester) async {
        final prompt = TextEditingController(
          text: List.generate(120, (i) => 'tag_$i').join(',\n'),
        );
        final focusNode = FocusNode();
        final page = await _pumpScrollPage(
          tester,
          prompt,
          focusNode: focusNode,
          tagMode: tags,
        );
        final editor = find.byType(UnifiedPromptInput);
        final inner = tester
            .stateList<ScrollableState>(
              find.descendant(
                of: tags ? find.byType(TagEditorView) : editor,
                matching: find.byType(Scrollable),
              ),
            )
            .firstWhere((state) => state.position.maxScrollExtent > 0);

        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        var clock = Duration.zero;
        Future<void> wheel(double delta) async {
          clock += const Duration(milliseconds: 200);
          pointer.hover(tester.getCenter(editor));
          await tester.sendEventToBinding(
            pointer.scroll(Offset(0, delta), timeStamp: clock),
          );
          await tester.pump();
        }

        // 标签编辑器挂载即自动聚焦，文本编辑器要显式聚焦
        if (!tags) focusNode.requestFocus();
        await tester.pumpAndSettle();

        // 有焦点：两端都不交棒，页面纹丝不动
        page.jumpTo(200);
        inner.position.jumpTo(0);
        await tester.pump();
        await wheel(-60);
        expect(page.offset, 200);
        expect(inner.position.pixels, 0);

        inner.position.jumpTo(inner.position.maxScrollExtent);
        final atBottom = inner.position.pixels;
        await tester.pump();
        await wheel(60);
        expect(page.offset, 200);
        expect(inner.position.pixels, atBottom);

        // 失去焦点后同一个动作恢复交棒
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        page.jumpTo(200);
        inner.position.jumpTo(0);
        await tester.pump();
        await wheel(-60);
        expect(page.offset, lessThan(200));

        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 250));
        page.dispose();
        focusNode.dispose();
        prompt.dispose();
      },
    );
  }
}

Future<ScrollController> _pumpScrollPage(
  WidgetTester tester,
  TextEditingController prompt, {
  FocusNode? focusNode,
  bool tagMode = false,
}) async {
  final page = ScrollController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => MemoryLocalStorage()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            controller: page,
            child: Column(
              children: [
                const SizedBox(height: 400),
                SizedBox(
                  height: 160,
                  child: UnifiedPromptInput(
                    controller: prompt,
                    focusNode: focusNode,
                    expands: true,
                    enableAssistant: false,
                    config: UnifiedPromptConfig(
                      enableAutocomplete: false,
                      enableSyntaxHighlight: false,
                      enableTagMode: tagMode,
                    ),
                  ),
                ),
                const SizedBox(height: 1400),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (tagMode) {
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
  }
  return page;
}
