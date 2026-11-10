import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/hive_storage_helper.dart';
import 'replication_queue_blob_store.dart';

part 'replication_queue_blob_store_provider.g.dart';

@Riverpod(keepAlive: true)
ReplicationQueueBlobStore replicationQueueBlobStore(Ref ref) =>
    ReplicationQueueBlobStore(
      resolveDirectory: () async => p.join(
        await HiveStorageHelper.instance.getPath(),
        ReplicationQueueBlobStore.directoryName,
      ),
    );
