import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/github_cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/data_source.dart';
import 'package:nai_launcher/core/cloud_sync/journal.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';
import 'package:nai_launcher/core/cloud_sync/snapshot_transfer.dart';
import 'package:nai_launcher/core/cloud_sync/snapshot_uploader.dart';

import 'github_fake_api.dart';

void main() {
  for (final empty in [false, true]) {
    for (final defaultBranch in ['sync', 'main']) {
      test(
        'upload then fresh download: empty=$empty default=$defaultBranch',
        () async {
          final api = FakeGitHubApi(
            emptyRepository: empty,
            defaultBranch: defaultBranch,
          );
          final backend = _backend(api);
          await backend.testCapability();
          expect(await backend.readHead(), isNull);
          expect(await backend.listSnapshotIds(), isEmpty);
          expect(
            api.requests.every((request) => request.method == 'GET'),
            isTrue,
          );

          for (var index = 0; index < 2; index++) {
            final source = _Artifacts();
            final expectedRevision = (await backend.readHead())?.revision;
            final snapshot = CloudSyncSnapshotData([
              CloudSyncRecord(
                id: 'settings',
                kind: 'settings',
                binary: false,
                deleted: false,
                bytes: Uint8List.fromList(utf8.encode('{"value":$index}')),
              ),
              CloudSyncRecord(
                id: 'preview',
                kind: 'image',
                binary: true,
                deleted: false,
                bytes: Uint8List.fromList([0, 1, 255, index]),
              ),
            ]);
            final journal = SyncJournal(
              operationId: 'upload-$index',
              operation: JournalOperation.uploadLocal,
              phase: JournalPhase.prepared,
              updatedAt: DateTime.utc(2026, 9, 5),
              snapshotId: 'snapshot-$index',
              targetFingerprint: 'a' * 64,
              expectedRevision: expectedRevision,
              uploadRequired: true,
            );
            final result =
                await ResumableSnapshotUploader(
                  backend: backend,
                  dataSource: source,
                  now: () => DateTime.utc(2026, 9, 5),
                ).resume(
                  journal: journal,
                  snapshot: snapshot,
                  token: OperationToken(),
                  checkpoint: (_) async {},
                );
            expect(result.phase, JournalPhase.savingBase);

            // Use a new backend so no in-memory staging can disguise a missing
            // manifest or object in the published commit.
            final reader = _backend(api);
            final head = SnapshotHead.decode((await reader.readHead())!.bytes);
            final downloaded = await CloudSnapshotTransfer(
              backend: reader,
              dataSource: _Artifacts(),
            ).downloadHead(head, OperationToken(), null);
            expect(
              downloaded.records.keys,
              unorderedEquals(snapshot.records.keys),
            );
            for (final record in snapshot.records.values) {
              expect(
                await downloaded.records[record.id]!.payload!.readBytes(),
                await record.payload!.readBytes(),
              );
            }
            expect(api.snapshotCommitCount, index + 1);
          }
          expect(
            api.requests.where((r) => r.method == 'PUT').length,
            empty ? 1 : 0,
          );
        },
      );
    }
  }

  test(
    'missing requested branch in an initialized repository is not empty',
    () async {
      final api = FakeGitHubApi(
        defaultBranch: 'main',
        requestedBranchMissing: true,
      );
      await expectLater(
        _backend(api).readHead(),
        throwsA(
          isA<CloudBackendException>().having(
            (error) => error.kind,
            'kind',
            CloudBackendErrorKind.notFound,
          ),
        ),
      );
      expect(api.requests.every((request) => request.method == 'GET'), isTrue);
    },
  );

  test(
    'missing-manifest backup stays invalid until an explicit new upload',
    () async {
      final api = FakeGitHubApi();
      final backend = _backend(api);
      final brokenHead = SnapshotHead(
        snapshotId: 'missing',
        manifestSha256: 'b' * 64,
        updatedAt: DateTime.utc(2026, 9, 5),
      );
      await backend.commitHead(
        Uint8List.fromList(brokenHead.encode()),
        expectedRevision: null,
      );
      await expectLater(
        CloudSnapshotTransfer(
          backend: _backend(api),
          dataSource: _Artifacts(),
        ).downloadHead(brokenHead, OperationToken(), null),
        throwsA(
          isA<CloudFormatException>().having(
            (error) => error.toString(),
            'reason',
            contains('snapshot manifest is missing'),
          ),
        ),
      );
      final snapshot = CloudSyncSnapshotData([
        CloudSyncRecord(
          id: 'settings',
          kind: 'settings',
          binary: false,
          deleted: false,
          bytes: Uint8List.fromList(utf8.encode('{"restored":true}')),
        ),
      ]);
      final revision = (await backend.readHead())!.revision;
      await ResumableSnapshotUploader(
        backend: backend,
        dataSource: _Artifacts(),
        now: () => DateTime.utc(2026, 9, 5),
      ).resume(
        journal: SyncJournal(
          operationId: 'repair',
          operation: JournalOperation.uploadLocal,
          phase: JournalPhase.prepared,
          updatedAt: DateTime.utc(2026, 9, 5),
          snapshotId: 'repaired',
          targetFingerprint: 'a' * 64,
          expectedRevision: revision,
          uploadRequired: true,
        ),
        snapshot: snapshot,
        token: OperationToken(),
        checkpoint: (_) async {},
      );
      final reader = _backend(api);
      final head = SnapshotHead.decode((await reader.readHead())!.bytes);
      final restored = await CloudSnapshotTransfer(
        backend: reader,
        dataSource: _Artifacts(),
      ).downloadHead(head, OperationToken(), null);
      expect(
        await restored.records['settings']!.payload!.readBytes(),
        await snapshot.records['settings']!.payload!.readBytes(),
      );
    },
  );
}

GitHubCloudSyncBackend _backend(FakeGitHubApi api) => GitHubCloudSyncBackend(
  owner: 'alice',
  repository: 'private',
  branch: 'sync',
  token: 'test-token',
  namespace: 'aaalice-sync-v3',
  apiBaseUri: Uri.parse('https://api.github.test/'),
  dio: Dio()..httpClientAdapter = api,
);

class _Artifacts extends Fake implements CloudSyncDataSource {
  final Map<String, List<int>> artifacts = {};

  @override
  Future<List<int>?> readUploadArtifact(
    String operationId,
    String name,
  ) async => artifacts['$operationId/$name'];

  @override
  Future<void> writeUploadArtifact(
    String operationId,
    String name,
    List<int> bytes,
  ) async {
    artifacts['$operationId/$name'] = List.of(bytes);
  }
}
