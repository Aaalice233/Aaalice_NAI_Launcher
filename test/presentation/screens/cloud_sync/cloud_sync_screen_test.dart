import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/cloud_drive_provider.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_client.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_config.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_models.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_flight_gate.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_provider_wiring.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_screen.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_section.dart';

void main() {
  testWidgets('未连接布局在 320–1600 宽度与 3x 文本下均无 overflow', (tester) async {
    for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1200));
      await tester.pumpWidget(_subject(textScale: 3));
      await tester.pumpAndSettle();

      expect(find.text('备份与恢复'), findsWidgets);
      expect(find.text('尚未连接'), findsOneWidget);
      expect(find.text('WebDAV'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Google Drive'), findsOneWidget);
      expect(find.text('OneDrive'), findsOneWidget);
      expect(find.text('保存连接'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('WebDAV 只填写服务商字段即可保存连接', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final port = _FakePort();
    await tester.pumpWidget(_subject(port: port));
    await tester.pumpAndSettle();

    final urlField = _fieldWithLabel('WebDAV 地址');
    final usernameField = _fieldWithLabel('用户名');
    await tester.enterText(urlField, 'https://dav.test');
    await tester.enterText(usernameField, 'user');
    final passwordField = _fieldWithLabel('密码');
    await tester.enterText(passwordField, 'webdav-secret');
    expect(
      tester.widget<TextField>(urlField).controller!.text,
      'https://dav.test',
    );
    expect(tester.widget<TextField>(usernameField).controller!.text, 'user');
    expect(
      tester.widget<TextField>(passwordField).controller!.text,
      'webdav-secret',
    );
    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
    expect(find.text('选择要保存的内容'), findsOneWidget);
    expect(find.text('图片与其他大文件'), findsNothing);
    expect(find.textContaining('快照'), findsNothing);
    expect(find.textContaining('后端'), findsNothing);
    expect(find.text('设置加密密码'), findsNothing);
    expect(find.text('生成一次性恢复密钥'), findsNothing);
    final save = find.byKey(const ValueKey('cloud-sync-save-connection'));
    await tester.scrollUntilVisible(save, 180, scrollable: _pageScrollable);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(port.request, isNotNull);
    expect(port.request!.dataKinds, {
      CloudSyncDataKind.settings,
      CloudSyncDataKind.prompts,
      CloudSyncDataKind.galleries,
    });
    expect(port.request!.contentSelection.includeAgentSystemPrompt, isTrue);
    expect(port.request!.contentSelection.includeSkills, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GitHub token 始终使用敏感字段并可一键连接', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_subject(port: _FakePort()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    final tokenField = _fieldWithLabel('GitHub 访问令牌');
    expect(tester.widget<TextField>(tokenField).obscureText, isTrue);
    await tester.enterText(tokenField, 'github-sensitive-token');
    await tester.enterText(_fieldWithLabel('GitHub 用户或组织'), 'alice');
    await tester.enterText(_fieldWithLabel('仓库'), 'backup');
    final save = find.byKey(const ValueKey('cloud-sync-save-connection'));
    await tester.scrollUntilVisible(save, 180, scrollable: _pageScrollable);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('高级设置字段名称独立显示且不会被展开区域裁剪', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1180, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    final advancedSettings = find.text('高级设置');
    await tester.scrollUntilVisible(
      advancedSettings,
      180,
      scrollable: _pageScrollable,
    );
    await tester.tap(advancedSettings);
    await tester.pumpAndSettle();

    final label = find.text('备份文件夹');
    final field = _fieldWithLabel('备份文件夹');
    final expansion = find.ancestor(
      of: label,
      matching: find.byType(ExpansionTile),
    );
    expect(label, findsOneWidget);
    expect(field, findsOneWidget);
    expect(expansion, findsOneWidget);

    final labelRect = tester.getRect(label);
    final fieldRect = tester.getRect(field);
    final expansionRect = tester.getRect(expansion);
    expect(labelRect.top, greaterThanOrEqualTo(expansionRect.top));
    expect(labelRect.bottom, lessThan(fieldRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('OAuth 草稿随页面销毁安全清理且不读取已失效 ref', (tester) async {
    final port = _FakePort();
    final registry = CloudDriveProviderRegistry([
      const _ConfiguredCloudDriveProvider(CloudDriveOAuthProvider.oneDrive),
    ]);
    await tester.pumpWidget(_subject(port: port, registry: registry));
    await tester.pumpAndSettle();

    await tester.tap(find.text('OneDrive'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('cloud-sync-authorize-oneDrive')),
    );
    await tester.pumpAndSettle();
    expect(find.text('test@example.com'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(port.discardedAuthorizations.single.accountId, 'account-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('OAuth 等待期间可取消并立即恢复页面操作', (tester) async {
    final port = _FakePort()
      ..authorizationCompleter = Completer<CloudSyncConnectionDraft>();
    await tester.pumpWidget(
      _subject(port: port, registry: _oneDriveRegistry()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OneDrive'));
    await tester.pumpAndSettle();
    final authorize = find.byKey(
      const ValueKey('cloud-sync-authorize-oneDrive'),
    );
    await tester.tap(authorize);
    await tester.pump();

    expect(find.text('取消'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'WebDAV'))
          .onSelected,
      isNull,
    );
    await tester.tap(authorize);
    await tester.pumpAndSettle();

    expect(port.authorizationCancellations, 1);
    expect(find.text('连接账号'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('更换账号时取消会保留原 OAuth 草稿', (tester) async {
    final port = _FakePort();
    await tester.pumpWidget(
      _subject(port: port, registry: _oneDriveRegistry()),
    );
    await tester.pumpAndSettle();
    await _authorizeOneDrive(tester);
    expect(find.text('test@example.com'), findsOneWidget);

    port.authorizationCompleter = Completer<CloudSyncConnectionDraft>();
    final authorize = find.byKey(
      const ValueKey('cloud-sync-authorize-oneDrive'),
    );
    await tester.tap(authorize);
    await tester.pump();
    await tester.tap(authorize);
    await tester.pumpAndSettle();

    expect(port.authorizationCancellations, 1);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(port.discardedAuthorizations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OAuth 等待期间销毁页面会取消后台授权', (tester) async {
    final port = _FakePort()
      ..authorizationCompleter = Completer<CloudSyncConnectionDraft>();
    await tester.pumpWidget(
      _subject(port: port, registry: _oneDriveRegistry()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OneDrive'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('cloud-sync-authorize-oneDrive')),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(port.authorizationCancellations, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存期间页面销毁不会撤销已转交给保存操作的 OAuth', (tester) async {
    final port = _FakePort()..connectCompleter = Completer<void>();
    await tester.pumpWidget(
      _subject(port: port, registry: _oneDriveRegistry()),
    );
    await tester.pumpAndSettle();
    await _authorizeOneDrive(tester);

    await _tapSaveConnection(tester);
    expect(port.request?.connection.accountId, 'account-1');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(port.discardedAuthorizations, isEmpty);
    port.connectCompleter!.complete();
    await tester.pumpAndSettle();
    expect(port.discardedAuthorizations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存失败时恢复 OAuth 草稿以便重试', (tester) async {
    final port = _FakePort()..connectError = StateError('save failed');
    await tester.pumpWidget(
      _subject(port: port, registry: _oneDriveRegistry()),
    );
    await tester.pumpAndSettle();
    await _authorizeOneDrive(tester);

    await _tapSaveConnection(tester);
    await tester.pumpAndSettle();

    expect(find.text('test@example.com'), findsOneWidget);
    expect(port.discardedAuthorizations, isEmpty);
    final save = find.byKey(const ValueKey('cloud-sync-save-connection'));
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存失败且页面已销毁时只清理一次 OAuth', (tester) async {
    final port = _FakePort()..connectCompleter = Completer<void>();
    await tester.pumpWidget(
      _subject(port: port, registry: _oneDriveRegistry()),
    );
    await tester.pumpAndSettle();
    await _authorizeOneDrive(tester);
    await _tapSaveConnection(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    port.connectCompleter!.completeError(StateError('save failed'));
    await tester.pumpAndSettle();

    expect(port.discardedAuthorizations, hasLength(1));
    expect(port.discardedAuthorizations.single.accountId, 'account-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('旧云同步操作占用 gate 时显示明确反馈', (tester) async {
    final port = _FakePort()
      ..connectError = const CloudSyncOperationInProgressException();
    await tester.pumpWidget(
      _subject(port: port, registry: _oneDriveRegistry()),
    );
    await tester.pumpAndSettle();
    await _authorizeOneDrive(tester);

    await _tapSaveConnection(tester);
    await tester.pumpAndSettle();

    expect(find.text('另一项云同步操作正在进行，请稍后重试。'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(port.discardedAuthorizations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已连接状态展示降级能力、完整进度、历史与待处理冲突', (tester) async {
    final state = _connectedState();
    final port = _FakePort();
    for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(_subject(state: state, port: port));
      await tester.pumpAndSettle();

      expect(find.text('只支持手动推送与拉取'), findsOneWidget);
      expect(find.text('GitHub 空间说明'), findsOneWidget);
      expect(find.text('请选择要保留的内容'), findsWidgets);
      expect(find.text('已连接'), findsNothing);
      expect(find.text('settings.json'), findsNothing);
      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('正在上传'), findsOneWidget);
      expect(find.text('暂停'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('以前的备份'), findsOneWidget);
      expect(find.text('包含 12 项内容'), findsOneWidget);
      expect(find.text('大文件会默认保留两个版本，避免丢失。'), findsOneWidget);
      expect(find.text('两者都保留'), findsWidgets);
      expect(find.text('修改加密密码'), findsNothing);
      expect(find.text('删除云端备份'), findsOneWidget);
      expect(find.text('断开连接'), findsOneWidget);
      expect(find.textContaining('namespace'), findsNothing);
      expect(find.textContaining('revision'), findsNothing);
      expect(find.textContaining('Base'), findsNothing);
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
    await tester.pumpWidget(
      _subject(
        state: _connectedState(
          activityStatus: CloudSyncActivityStatus.idle,
          capabilityMode: CloudSyncCapabilityMode.bidirectional,
        ),
        port: port,
      ),
    );
    await tester.pumpAndSettle();
    final bulkRemote = find.byKey(const ValueKey('cloud-sync-bulk-remote'));
    await tester.scrollUntilVisible(
      bulkRemote,
      180,
      scrollable: _pageScrollable,
    );
    await tester.tap(bulkRemote);
    await tester.pump();
    expect(port.bulkChoice, CloudSyncConflictChoice.remote);
    final keepBoth = find.byKey(
      const ValueKey('cloud-sync-conflict-image-1-keepBoth'),
    );
    await tester.scrollUntilVisible(keepBoth, 180, scrollable: _pageScrollable);
    await tester.tap(keepBoth);
    await tester.pump();
    expect(port.conflictChoice, CloudSyncConflictChoice.keepBoth);

    await tester.pumpWidget(
      _subject(
        state: _connectedState(activityStatus: CloudSyncActivityStatus.paused),
        port: port,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('继续'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('合并与恢复预览展示真实摘要且必须确认后应用', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final port = _FakePort();
    final state =
        _connectedState(
          activityStatus: CloudSyncActivityStatus.idle,
          capabilityMode: CloudSyncCapabilityMode.bidirectional,
        ).copyWith(
          clearProgress: true,
          conflicts: const [],
          pendingPreview: const CloudSyncPreviewView(
            changes: [
              CloudSyncChangeSummary(
                kind: CloudSyncDataKind.prompts,
                added: 2,
                modified: 3,
                deleted: 1,
              ),
            ],
          ),
          pendingFfdkjInstall: true,
        );
    await tester.pumpWidget(_subject(state: state, port: port));
    await tester.pumpAndSettle();

    expect(find.text('合并内容确认'), findsOneWidget);
    expect(find.text('新增 2 · 修改 3 · 删除 1'), findsOneWidget);
    expect(find.text('已连接'), findsNothing);
    expect(find.textContaining('词库文件不会通过云端传输'), findsOneWidget);
    final restorePreview = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '查看并恢复'),
    );
    expect(restorePreview.onPressed, isNull);
    final confirm = find.byKey(const ValueKey('cloud-sync-confirm-preview'));
    await tester.scrollUntilVisible(confirm, 180, scrollable: _pageScrollable);
    await tester.tap(confirm);
    await tester.pump();
    expect(port.previewApplied, isTrue);

    await _tapText(tester, '暂不安装并清除提示');
    expect(port.ffdkjInstallChoice, isFalse);
  });

  testWidgets('四语技术详情在五档宽度和大数值下无 overflow', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state =
        _connectedState(
          activityStatus: CloudSyncActivityStatus.syncing,
          capabilityMode: CloudSyncCapabilityMode.bidirectional,
        ).copyWith(
          progress: const CloudSyncProgressView(
            stage: 'hashing',
            objectName: 'object-with-a-very-long-content-addressed-name',
            completedBytes: 9876543210123,
            totalBytes: 98765432101234,
            completedObjects: 987654321,
            totalObjects: 9876543210,
            reusedObjects: 987654321,
          ),
          metrics: const CloudSyncMetricsView(
            elapsedMilliseconds: 987654321,
            requestCount: 987654321,
            bytesRead: 9876543210123,
            bytesWritten: 9876543210123,
            hashPasses: 987654321,
            payloadReads: 987654321,
            localBytesRead: 9876543210123,
            localBytesWritten: 9876543210123,
            flushes: 987654321,
            stageMilliseconds: {'preparing': 123456789, 'uploading': 987654321},
          ),
        );
    final titles = {
      const Locale('en'): ('Technical details', 'Service requests'),
      const Locale('ja'): ('技術的な詳細', 'サービスへのリクエスト'),
      const Locale('zh'): ('技术详情', '服务请求'),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'): (
        '技術詳情',
        '服務要求',
      ),
    };
    for (final entry in titles.entries) {
      for (final width in [390.0, 700.0, 840.0, 1180.0, 1600.0]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(
          _subject(state: state, port: _FakePort(), locale: entry.key),
        );
        await tester.pumpAndSettle();

        final details = find.text(entry.value.$1);
        await tester.scrollUntilVisible(
          details,
          180,
          scrollable: _pageScrollable,
        );
        await tester.tap(details);
        await tester.pumpAndSettle();

        expect(find.text(entry.value.$2), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'locale=${entry.key} width=$width',
        );
      }
    }
  });

  testWidgets('仅手动备份模式允许显式拉取但禁用历史恢复和合并', (tester) async {
    await tester.pumpWidget(
      _subject(
        state: _connectedState(
          activityStatus: CloudSyncActivityStatus.idle,
        ).copyWith(remoteExists: true),
        port: _FakePort(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('查看并恢复'), findsNothing);
    final pull = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '从云端拉取'),
    );
    expect(pull.onPressed, isNotNull);
    final bulk = tester.widget<FilledButton>(
      find.byKey(const ValueKey('cloud-sync-bulk-local')),
    );
    expect(bulk.onPressed, isNull);
  });

  testWidgets('存储服务警告会直接显示在已连接页面', (tester) async {
    final state =
        _connectedState(
          activityStatus: CloudSyncActivityStatus.idle,
          capabilityMode: CloudSyncCapabilityMode.bidirectional,
        ).copyWith(
          capabilityWarnings: const [
            CloudBackendWarning.githubPublicRepository,
          ],
          clearProgress: true,
        );

    await tester.pumpWidget(_subject(state: state, port: _FakePort()));
    await tester.pumpAndSettle();

    expect(find.text('存储服务提示'), findsOneWidget);
    expect(find.textContaining('备份内容也会公开'), findsOneWidget);
  });

  testWidgets('推送和拉取使用独立按钮并在执行前二次确认方向', (tester) async {
    final port = _FakePort();
    final state = _connectedState(
      activityStatus: CloudSyncActivityStatus.idle,
      capabilityMode: CloudSyncCapabilityMode.bidirectional,
    ).copyWith(remoteExists: true, conflicts: const [], clearProgress: true);
    await tester.pumpWidget(_subject(state: state, port: port));
    await tester.pumpAndSettle();

    await _tapText(tester, '推送到云端');
    expect(find.text('推送本机数据？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();
    expect(port.pushes, 1);
    expect(port.pulls, 0);

    await _tapText(tester, '从云端拉取');
    expect(find.text('拉取云端数据？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();
    expect(port.pushes, 1);
    expect(port.pulls, 1);
  });

  testWidgets('云盘连接不显示密钥流程且可直接选择同步方向', (tester) async {
    final state =
        _connectedState(
          activityStatus: CloudSyncActivityStatus.idle,
          capabilityMode: CloudSyncCapabilityMode.bidirectional,
        ).copyWith(
          backend: CloudSyncBackendKind.oneDrive,
          accountId: 'tenant:account',
          accountLabel: 'user@example.test',
          conflicts: const [],
          clearProgress: true,
        );
    await tester.pumpWidget(_subject(state: state, port: _FakePort()));
    await tester.pumpAndSettle();

    expect(find.text('user@example.test'), findsOneWidget);
    expect(find.textContaining('恢复密钥'), findsNothing);
    expect(find.textContaining('加密设置'), findsNothing);
    final push = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '推送到云端'),
    );
    expect(push.onPressed, isNotNull);
  });

  testWidgets('网络失败只显示可读提示且不暴露异常类型', (tester) async {
    final port = _FakePort()
      ..syncError = const CloudBackendException(
        CloudBackendErrorKind.network,
        '无法连接服务器，请检查网络、代理和服务地址后重试。',
      );
    await tester.pumpWidget(
      _subject(
        state: _connectedState(
          activityStatus: CloudSyncActivityStatus.idle,
          capabilityMode: CloudSyncCapabilityMode.bidirectional,
        ),
        port: port,
      ),
    );
    await tester.pumpAndSettle();

    await _tapText(tester, '推送到云端');
    expect(find.text('推送本机数据？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();

    expect(find.text('操作失败：无法连接云存储，请检查网络后重试。'), findsOneWidget);
    expect(find.textContaining('CloudBackendException'), findsNothing);
  });
}

Finder _fieldWithLabel(String label) =>
    find.byKey(ValueKey('cloud-sync-field-$label'));

CloudDriveProviderRegistry _oneDriveRegistry() => CloudDriveProviderRegistry([
  const _ConfiguredCloudDriveProvider(CloudDriveOAuthProvider.oneDrive),
]);

Future<void> _authorizeOneDrive(WidgetTester tester) async {
  await tester.tap(find.text('OneDrive'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('cloud-sync-authorize-oneDrive')));
  await tester.pumpAndSettle();
}

Future<void> _tapSaveConnection(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('cloud-sync-save-connection'));
  await tester.scrollUntilVisible(save, 180, scrollable: _pageScrollable);
  await tester.tap(save);
  await tester.pump();
}

Future<void> _tapText(
  WidgetTester tester,
  String text, {
  bool last = false,
}) async {
  final finder = find.text(text);
  final target = finder.at(last ? finder.evaluate().length - 1 : 0);
  await tester.scrollUntilVisible(target, 180, scrollable: _pageScrollable);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder get _pageScrollable => find
    .descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    )
    .at(0);

Widget _subject({
  CloudSyncUiState? state,
  CloudSyncUiPort? port,
  double textScale = 1,
  CloudDriveProviderRegistry? registry,
  Locale locale = const Locale('zh'),
}) {
  return ProviderScope(
    overrides: [
      if (state != null) cloudSyncUiStateProvider.overrideWithValue(state),
      if (port != null) cloudSyncUiPortProvider.overrideWithValue(port),
      if (registry != null)
        cloudDriveProviderRegistryProvider.overrideWithValue(registry),
      localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
    ],
    child: MaterialApp(
      key: UniqueKey(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const SettingsScreen(initialSection: SettingsSection.cloudSync),
    ),
  );
}

class _MemoryStorage extends LocalStorageService {
  final values = <String, Object?>{};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] as T?) ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}

class _ConfiguredCloudDriveProvider implements CloudDriveProvider {
  const _ConfiguredCloudDriveProvider(this.id);

  @override
  final CloudDriveOAuthProvider id;

  @override
  CloudDriveOAuthConfigDiagnostic diagnose() => CloudDriveOAuthConfigDiagnostic(
    provider: id,
    platform: CloudDriveOAuthPlatform.windows,
    isConfigured: true,
    reasons: const [],
  );

  @override
  Future<CloudDriveOAuthSession> connect() => throw UnimplementedError();

  @override
  Future<void> cancelConnect() async {}

  @override
  CloudSyncBackend createBackend({
    required String accountId,
    required String namespace,
  }) => throw UnimplementedError();

  @override
  Future<void> disconnect(String accountId) async {}
}

CloudSyncUiState _connectedState({
  CloudSyncActivityStatus activityStatus = CloudSyncActivityStatus.syncing,
  CloudSyncCapabilityMode capabilityMode =
      CloudSyncCapabilityMode.manualBackupOnly,
}) => CloudSyncUiState(
  connectionStatus: CloudSyncConnectionStatus.connected,
  activityStatus: activityStatus,
  backend: CloudSyncBackendKind.github,
  deviceName: 'Android tablet',
  lastSync: DateTime.utc(2026, 3, 12, 10, 30),
  remoteRevision: 'rev-42',
  capabilityMode: capabilityMode,
  progress: const CloudSyncProgressView(
    stage: 'uploading',
    objectName: 'settings.json',
    completedBytes: 1024,
    totalBytes: 4096,
    completedObjects: 2,
    totalObjects: 5,
  ),
  logs: [
    CloudSyncLogEntry(
      time: DateTime.utc(2026, 3, 12, 10, 30),
      message: 'Remote head loaded',
    ),
  ],
  snapshots: [
    CloudSyncSnapshotView(
      id: 'snapshot-41',
      createdAt: DateTime.utc(2026, 3, 11),
      objectCount: 12,
    ),
  ],
  conflicts: const [
    CloudSyncConflictView(
      id: 'prompt-1',
      kind: CloudSyncDataKind.prompts,
      title: 'Portrait preset',
      baseSummary: '12 tags',
      localSummary: '14 tags',
      remoteSummary: '13 tags',
    ),
    CloudSyncConflictView(
      id: 'image-1',
      kind: CloudSyncDataKind.largeBinary,
      title: 'reference.png',
      baseSummary: '8 MiB',
      localSummary: '9 MiB',
      remoteSummary: '10 MiB',
    ),
  ],
);

class _FakePort extends CloudSyncUiPortAdapter {
  CloudSyncConnectRequest? request;
  bool remoteDetected = false;
  CloudSyncConflictChoice? conflictChoice;
  CloudSyncConflictChoice? bulkChoice;
  bool previewApplied = false;
  bool? ffdkjInstallChoice;
  Object? syncError;
  Object? connectError;
  Completer<void>? connectCompleter;
  var pushes = 0;
  var pulls = 0;
  Completer<CloudSyncConnectionDraft>? authorizationCompleter;
  final discardedAuthorizations = <CloudSyncConnectionDraft>[];
  var authorizationCancellations = 0;

  @override
  Future<CloudSyncConnectionDraft> authorizeCloudDrive(
    CloudSyncBackendKind backend,
  ) async =>
      authorizationCompleter?.future ??
      CloudSyncConnectionDraft(
        backend: backend,
        path: 'aaalice-sync',
        accountId: 'account-1',
        accountLabel: 'test@example.com',
      );

  @override
  Future<void> cancelCloudDriveAuthorization(
    CloudSyncBackendKind backend,
  ) async {
    authorizationCancellations++;
    final completer = authorizationCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        const CloudDriveOAuthException(
          CloudDriveOAuthFailureCode.cancelled,
          'cancelled by test',
        ),
      );
    }
  }

  @override
  Future<void> discardCloudDriveAuthorization(
    CloudSyncConnectionDraft connection,
  ) async {
    discardedAuthorizations.add(connection);
  }

  @override
  Future<void> pushNow() async {
    pushes++;
    final error = syncError;
    if (error != null) throw error;
  }

  @override
  Future<void> pullNow() async {
    pulls++;
    final error = syncError;
    if (error != null) throw error;
  }

  @override
  Future<void> applyPendingPreview() async => previewApplied = true;

  @override
  Future<void> respondToFfdkjInstallIntent({required bool install}) async {
    ffdkjInstallChoice = install;
  }

  @override
  Future<CloudSyncCapabilityResult> testConnection(
    CloudSyncConnectionDraft connection,
  ) async => const CloudSyncCapabilityResult(
    succeeded: true,
    mode: CloudSyncCapabilityMode.bidirectional,
    message: 'Conditional writes and history are available.',
    supportsHistory: true,
    supportsDelete: true,
    warnings: [CloudBackendWarning.githubPublicRepository],
    limit: '2 GiB',
  );

  @override
  Future<void> detectRemote(CloudSyncConnectionDraft connection) async {
    remoteDetected = true;
  }

  @override
  Future<void> connect(CloudSyncConnectRequest request) async {
    this.request = request;
    final error = connectError;
    if (error != null) throw error;
    await connectCompleter?.future;
  }

  @override
  Future<void> resolveConflict(
    String conflictId,
    CloudSyncConflictChoice choice,
  ) async {
    conflictChoice = choice;
  }

  @override
  Future<void> resolveAllConflicts(CloudSyncConflictChoice choice) async {
    bulkChoice = choice;
  }
}
