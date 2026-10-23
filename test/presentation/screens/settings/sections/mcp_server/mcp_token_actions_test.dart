import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/mcp_discovery_file.dart';
import 'package:nai_launcher/core/mcp/mcp_server_constants.dart';
import 'package:nai_launcher/core/storage/secure_storage_unavailable_exception.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/mcp/providers/mcp_server_notifier.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/mcp_server/mcp_token_actions.dart';

const _unavailable = SecureStorageUnavailableException(
  SecureStorageStep.replaceFile,
  osErrorCode: 5,
);

void main() {
  late Directory root;
  late _ScriptedTokenStore tokens;
  late BuildContext hostContext;
  late WidgetRef hostRef;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mcp_token_actions_');
    tokens = _ScriptedTokenStore();
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<AppLocalizations> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mcpServerNotifierProvider.overrideWith(
            (ref) => McpServerNotifier(
              ref,
              discovery: McpDiscoveryFileStore(directory: root),
              tokenStore: tokens,
              settingsStore: _DisabledSettings(),
              supportDirectory: root,
              notifyApprovalRequested: () async {},
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                hostContext = context;
                hostRef = ref;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    return lookupAppLocalizations(const Locale('zh'));
  }

  Future<void> dismissToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('读取令牌时存储不可用：提示并返回 null，不补发新令牌', (tester) async {
    final l10n = await pumpHost(tester);
    tokens.readFailure = _unavailable;

    final token = await readMcpTokenOrNotify(hostContext, hostRef);
    await tester.pump();

    expect(token, isNull);
    expect(tokens.writes, 0);
    expect(find.text(l10n.common_secureStorageUnavailable), findsOneWidget);
    await dismissToasts(tester);
  });

  testWidgets('换发令牌写不进存储：提示并返回 false，旧令牌保留', (tester) async {
    final l10n = await pumpHost(tester);
    tokens.token = 'previous';
    tokens.writeFailure = _unavailable;

    final regenerated = await regenerateMcpTokenOrNotify(hostContext, hostRef);
    await tester.pump();

    expect(regenerated, isFalse);
    expect(tokens.token, 'previous');
    expect(find.text(l10n.common_secureStorageUnavailable), findsOneWidget);
    await dismissToasts(tester);
  });

  testWidgets('存储正常时读取与换发都不提示', (tester) async {
    final l10n = await pumpHost(tester);
    tokens.token = 'previous';

    expect(await readMcpTokenOrNotify(hostContext, hostRef), 'previous');
    expect(await regenerateMcpTokenOrNotify(hostContext, hostRef), isTrue);
    await tester.pump();

    expect(tokens.token, isNot('previous'));
    expect(find.text(l10n.common_secureStorageUnavailable), findsNothing);
  });
}

class _ScriptedTokenStore implements McpServerTokenStore {
  String? token;
  Object? readFailure;
  Object? writeFailure;
  int writes = 0;

  @override
  Future<String?> read() async {
    final failure = readFailure;
    if (failure != null) throw failure;
    return token;
  }

  @override
  Future<void> write(String value) async {
    final failure = writeFailure;
    if (failure != null) throw failure;
    writes++;
    token = value;
  }

  @override
  Future<void> delete() async => token = null;
}

class _DisabledSettings implements McpServerSettingsStore {
  @override
  bool get enabled => false;

  @override
  int get port => McpServerDefaults.port;

  @override
  AgentPermissionMode get permissionMode => AgentPermissionMode.safe;

  @override
  Future<void> writeEnabled(bool value) async {}

  @override
  Future<void> writePort(int value) async {}

  @override
  Future<void> writePermissionMode(AgentPermissionMode value) async {}
}
