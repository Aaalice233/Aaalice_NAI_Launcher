import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/secure_storage_unavailable_exception.dart';
import 'package:nai_launcher/data/models/auth/saved_account.dart';
import 'package:nai_launcher/data/services/account_manager_provider.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/auth/saved_account_token_reader.dart';

const _unavailable = SecureStorageUnavailableException(
  SecureStorageStep.readFile,
  osErrorCode: 32,
);

final _alice = SavedAccount(
  id: 'alice',
  email: 'alice@example.invalid',
  createdAt: DateTime.utc(2026),
);

void main() {
  late BuildContext hostContext;
  late WidgetRef hostRef;

  Widget capturingHost() => Consumer(
    builder: (context, ref, _) {
      hostContext = context;
      hostRef = ref;
      return const SizedBox.expand();
    },
  );

  Future<AppLocalizations> pumpApp(
    WidgetTester tester,
    Future<String?> Function() readToken, {
    Widget? home,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountManagerNotifierProvider.overrideWith(
            () => _ScriptedAccounts(readToken),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: home ?? capturingHost()),
        ),
      ),
    );
    return lookupAppLocalizations(const Locale('zh'));
  }

  Future<String?> readFor(WidgetTester tester) async {
    final token = await readSavedAccountTokenForSwitch(
      context: hostContext,
      ref: hostRef,
      account: _alice,
    );
    await tester.pump();
    return token;
  }

  Future<void> dismissToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('存储暂不可用时提示原因并返回 null', (tester) async {
    final l10n = await pumpApp(tester, () async => throw _unavailable);

    expect(await readFor(tester), isNull);
    expect(find.text(l10n.common_secureStorageUnavailable), findsOneWidget);
    expect(find.text(l10n.auth_tokenNotFound), findsNothing);

    await dismissToasts(tester);
  });

  testWidgets('Token 缺失或为空时提示未找到', (tester) async {
    for (final missing in <String?>[null, '']) {
      final l10n = await pumpApp(tester, () async => missing);

      expect(await readFor(tester), isNull, reason: '$missing');
      expect(find.text(l10n.auth_tokenNotFound), findsOneWidget);

      await dismissToasts(tester);
    }
  });

  testWidgets('读到 Token 时原样返回且不提示', (tester) async {
    final l10n = await pumpApp(tester, () async => 'pst-alice');

    expect(await readFor(tester), 'pst-alice');
    expect(find.text(l10n.auth_tokenNotFound), findsNothing);
    expect(find.text(l10n.common_secureStorageUnavailable), findsNothing);
  });

  testWidgets('所在页面在读取期间关闭后提示仍然显示', (tester) async {
    final gate = Completer<String?>();
    final l10n = await pumpApp(
      tester,
      () => gate.future,
      home: const SizedBox.expand(),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(MaterialPageRoute<void>(builder: (_) => capturingHost())),
    );
    await tester.pumpAndSettle();

    final reading = readSavedAccountTokenForSwitch(
      context: hostContext,
      ref: hostRef,
      account: _alice,
    );
    navigator.pop();
    await tester.pumpAndSettle();
    expect(hostContext.mounted, isFalse);

    gate.completeError(_unavailable);
    expect(await reading, isNull);
    await tester.pump();
    expect(find.text(l10n.common_secureStorageUnavailable), findsOneWidget);

    await dismissToasts(tester);
  });
}

class _ScriptedAccounts extends AccountManagerNotifier {
  _ScriptedAccounts(this._readToken);

  final Future<String?> Function() _readToken;

  @override
  AccountManagerState build() => AccountManagerState(accounts: [_alice]);

  @override
  Future<String?> getAccountToken(String accountId) => _readToken();
}
