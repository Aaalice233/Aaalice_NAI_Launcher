import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_screen.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_section.dart';

void main() {
  testWidgets('未连接布局在五档宽度均无 overflow', (tester) async {
    for (final width in [390.0, 700.0, 840.0, 1180.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(_subject());
      await tester.pumpAndSettle();

      expect(find.text('同步与备份'), findsWidgets);
      expect(find.text('尚未连接'), findsOneWidget);
      expect(find.text('WebDAV'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('保存并同步'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('WebDAV 只填写服务商字段即可保存并同步', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final port = _FakePort();
    await tester.pumpWidget(_subject(port: port));
    await tester.pumpAndSettle();

    final urlField = _fieldWithLabel('WebDAV URL');
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
    expect(find.text('选择同步数据'), findsOneWidget);
    expect(find.text('大二进制文件'), findsOneWidget);
    expect(find.text('设置加密密码'), findsNothing);
    expect(find.text('生成一次性恢复密钥'), findsNothing);
    final save = find.byKey(const ValueKey('cloud-sync-save-and-sync'));
    await tester.scrollUntilVisible(save, 180, scrollable: _pageScrollable);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(port.request, isNotNull);
    expect(port.request!.legacyPassword, isEmpty);
    expect(port.request!.dataKinds, {
      CloudSyncDataKind.settings,
      CloudSyncDataKind.prompts,
      CloudSyncDataKind.galleries,
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('GitHub token 始终使用敏感字段并可一键连接', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_subject(port: _FakePort()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    final tokenField = _fieldWithLabel('GitHub Token');
    expect(tester.widget<TextField>(tokenField).obscureText, isTrue);
    await tester.enterText(tokenField, 'github-sensitive-token');
    await tester.enterText(_fieldWithLabel('Owner'), 'alice');
    await tester.enterText(_fieldWithLabel('仓库'), 'backup');
    final save = find.byKey(const ValueKey('cloud-sync-save-and-sync'));
    await tester.scrollUntilVisible(save, 180, scrollable: _pageScrollable);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('已连接状态展示降级能力、完整进度、历史与待处理冲突', (tester) async {
    final state = _connectedState();
    final port = _FakePort();
    for (final width in [390.0, 700.0, 840.0, 1180.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(_subject(state: state, port: port));
      await tester.pumpAndSettle();

      expect(find.text('仅手动云备份'), findsOneWidget);
      expect(find.text('GitHub 历史保留'), findsOneWidget);
      expect(find.text('远端维护提示'), findsOneWidget);
      expect(find.text('cleanup delayed'), findsOneWidget);
      expect(find.text('需处理冲突'), findsWidgets);
      expect(find.text('已完全同步'), findsNothing);
      expect(find.text('settings.json'), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('暂停'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('历史快照'), findsOneWidget);
      expect(find.text('大二进制冲突默认保留两个副本。'), findsOneWidget);
      expect(find.text('两者都保留'), findsWidgets);
      expect(find.text('修改加密密码'), findsNothing);
      expect(find.text('仅删除云端 namespace'), findsOneWidget);
      expect(find.text('断开此设备'), findsOneWidget);
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
            title: 'initial',
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

    expect(find.text('首次合并预览'), findsOneWidget);
    expect(find.text('新增 2 · 修改 3 · 删除 1'), findsOneWidget);
    expect(find.text('已完全同步'), findsNothing);
    expect(find.textContaining('不包含或传输 tag.sqlite'), findsOneWidget);
    final restorePreview = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '预览恢复'),
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

  testWidgets('仅手动备份模式隐藏恢复并禁用冲突应用', (tester) async {
    await tester.pumpWidget(
      _subject(
        state: _connectedState(activityStatus: CloudSyncActivityStatus.idle),
        port: _FakePort(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('预览恢复'), findsNothing);
    final bulk = tester.widget<FilledButton>(
      find.byKey(const ValueKey('cloud-sync-bulk-local')),
    );
    expect(bulk.onPressed, isNull);
  });

  testWidgets('旧加密备份只在缺少本机密钥时显示兼容解锁', (tester) async {
    final port = _FakePort();
    const state = CloudSyncUiState(
      remoteExists: true,
      legacyEncryptedBackup: true,
      legacyUnlockRequired: true,
    );
    await tester.pumpWidget(_subject(state: state, port: port));
    await tester.pumpAndSettle();

    expect(find.text('旧加密备份'), findsOneWidget);
    expect(_fieldWithLabel('旧备份加密密码'), findsOneWidget);
    expect(find.text('使用旧恢复密钥'), findsOneWidget);
    expect(find.text('设置加密密码'), findsNothing);
  });
}

Finder _fieldWithLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

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

Widget _subject({CloudSyncUiState? state, CloudSyncUiPort? port}) {
  return ProviderScope(
    overrides: [
      if (state != null) cloudSyncUiStateProvider.overrideWithValue(state),
      if (port != null) cloudSyncUiPortProvider.overrideWithValue(port),
    ],
    child: const MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(initialSection: SettingsSection.cloudSync),
    ),
  );
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
  maintenanceWarning: 'cleanup delayed',
  progress: const CloudSyncProgressView(
    stage: 'Uploading',
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
      summary: 'Before tablet sync',
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
    warnings: ['provider warning'],
    limit: '2 GiB',
  );

  @override
  Future<void> detectRemote(CloudSyncConnectionDraft connection) async {
    remoteDetected = true;
  }

  @override
  Future<void> connect(CloudSyncConnectRequest request) async {
    this.request = request;
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
