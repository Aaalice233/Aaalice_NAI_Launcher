import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../platform/launcher_discovery_directory.dart';
import 'mcp_server_constants.dart';

/// Contents of `mcp-server.json`, the handshake file the stdio proxy reads.
class McpDiscoveryDocument {
  const McpDiscoveryDocument({
    required this.port,
    required this.pid,
    required this.startedAt,
    required this.token,
    required this.protocolVersions,
    required this.appVersion,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final int port;
  final int pid;
  final DateTime startedAt;
  final String token;
  final List<String> protocolVersions;
  final String appVersion;

  Uri get endpoint => Uri(
    scheme: 'http',
    host: McpServerDefaults.loopbackHost,
    port: port,
    path: McpServerDefaults.endpointPath,
  );

  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'transport': McpServerDefaults.transport,
    'endpoint': endpoint.toString(),
    'port': port,
    'pid': pid,
    'started_at': startedAt.toUtc().toIso8601String(),
    'token': token,
    'protocol_versions': protocolVersions,
    'app_version': appVersion,
  };

  factory McpDiscoveryDocument.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schema_version'];
    if (schemaVersion is! int || schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported MCP discovery schema version: $schemaVersion',
      );
    }
    final port = json['port'];
    final pid = json['pid'];
    final startedAt = json['started_at'];
    final token = json['token'];
    final protocolVersions = json['protocol_versions'];
    final appVersion = json['app_version'];
    if (port is! int ||
        port < McpServerDefaults.minPort ||
        port > McpServerDefaults.maxPort) {
      throw FormatException('Invalid MCP discovery port: $port');
    }
    if (pid is! int || pid <= 0) {
      throw FormatException('Invalid MCP discovery pid: $pid');
    }
    if (startedAt is! String) {
      throw const FormatException('MCP discovery started_at is missing');
    }
    if (token is! String || token.isEmpty) {
      throw const FormatException('MCP discovery token is missing');
    }
    if (protocolVersions is! List ||
        protocolVersions.any((version) => version is! String)) {
      throw const FormatException(
        'MCP discovery protocol_versions is invalid',
      );
    }
    if (appVersion is! String) {
      throw const FormatException('MCP discovery app_version is missing');
    }
    return McpDiscoveryDocument(
      schemaVersion: schemaVersion,
      port: port,
      pid: pid,
      startedAt: DateTime.parse(startedAt),
      token: token,
      protocolVersions: List<String>.unmodifiable(
        protocolVersions.cast<String>(),
      ),
      appVersion: appVersion,
    );
  }
}

/// Atomically publishes and removes the discovery file. It lives in the
/// per-user profile and therefore shares the trust boundary of the app's own
/// storage.
class McpDiscoveryFileStore {
  McpDiscoveryFileStore({Directory? directory})
    : directory = directory ?? resolveLauncherDiscoveryDirectory();

  final Directory directory;

  File get file =>
      File(p.join(directory.path, McpServerDefaults.discoveryFileName));

  Future<void> write(McpDiscoveryDocument document) async {
    await directory.create(recursive: true);
    final target = file;
    final temp = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temp.writeAsString(jsonEncode(document.toJson()), flush: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', temp.path]);
    }
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  /// Returns `null` when no launcher has published a file; a corrupt file
  /// surfaces as [FormatException] so callers can tell the two apart.
  Future<McpDiscoveryDocument?> read() async {
    final target = file;
    if (!await target.exists()) {
      return null;
    }
    final decoded = jsonDecode(await target.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('MCP discovery file is not a JSON object');
    }
    return McpDiscoveryDocument.fromJson(decoded);
  }

  Future<void> delete() async {
    final target = file;
    if (await target.exists()) {
      await target.delete();
    }
  }
}
