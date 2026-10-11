import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../mcp_discovery_file.dart';
import 'mcp_client_config_printer.dart';
import 'mcp_stdio_proxy.dart';

/// Process exit codes shared by every `nai_launcher_mcp` command.
abstract final class McpCliExitCode {
  static const int success = 0;
  static const int launcherUnavailable =
      McpStdioProxy.launcherUnavailableExitCode;
  static const int corruptDiscovery = 3;
  static const int usage = 64;
}

/// Thrown by shared command helpers that already reported the problem.
class McpCliExit implements Exception {
  const McpCliExit(this.code);

  final int code;
}

/// Everything a command needs from the process it runs in.
class McpCliContext {
  const McpCliContext({
    required this.input,
    required this.output,
    required this.diagnostics,
    required this.discoveryStore,
    required this.executablePath,
    required this.environment,
    this.httpClientFactory,
  });

  final Stream<List<int>> input;
  final IOSink output;
  final IOSink diagnostics;
  final McpDiscoveryFileStore discoveryStore;
  final String Function() executablePath;
  final Map<String, String> environment;
  final HttpClient Function()? httpClientFactory;
}

/// Endpoint plus bearer token, resolved from options, environment or the
/// discovery file.
class McpEndpointConfig {
  const McpEndpointConfig({required this.endpoint, required this.token});

  final Uri endpoint;
  final String token;
}

const String _endpointOption = 'endpoint';
const String _tokenOption = 'token';
const String _tokenEnvOption = 'token-env';
const String _discoveryFileOption = 'discovery-file';
const String _verboseFlag = 'verbose';

void _addSharedOptions(ArgParser parser) {
  parser
    ..addOption(
      _endpointOption,
      valueHelp: 'url',
      help: 'Streamable HTTP endpoint of a running launcher.',
    )
    ..addOption(
      _tokenOption,
      valueHelp: 'token',
      help: 'Bearer token accepted by the launcher.',
    )
    ..addOption(
      _tokenEnvOption,
      valueHelp: 'name',
      help: 'Read the bearer token from this environment variable.',
    )
    ..addOption(
      _discoveryFileOption,
      valueHelp: 'path',
      help: 'Discovery file published by the launcher.',
    )
    ..addFlag(
      _verboseFlag,
      negatable: false,
      help: 'Log protocol activity to stderr.',
    );
}

/// Base class for every `nai_launcher_mcp` command: shares the endpoint,
/// token and discovery-file options plus their resolution order.
abstract class McpCliCommand extends Command<int> {
  McpCliCommand(this.context) {
    _addSharedOptions(argParser);
  }

  final McpCliContext context;

  bool get verbose =>
      argResults?[_verboseFlag] == true || globalResults?[_verboseFlag] == true;

  File get discoveryFile {
    final override = _sharedOption(_discoveryFileOption);
    return override == null ? context.discoveryStore.file : File(override);
  }

  /// Returns `null` when no launcher published a discovery file; exits with
  /// [McpCliExitCode.corruptDiscovery] when the file cannot be parsed.
  Future<McpDiscoveryDocument?> readDiscoveryDocument() async {
    final file = discoveryFile;
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('MCP discovery file is not a JSON object');
      }
      return McpDiscoveryDocument.fromJson(decoded);
    } on FormatException catch (error) {
      context.diagnostics.writeln(
        'MCP discovery file is corrupt (${file.path}): ${error.message}',
      );
      throw const McpCliExit(McpCliExitCode.corruptDiscovery);
    }
  }

  Future<McpDiscoveryDocument> requireDiscoveryDocument() async {
    final document = await readDiscoveryDocument();
    if (document != null) {
      return document;
    }
    context.diagnostics.writeln(
      'NAI Launcher is not running or its MCP server is disabled '
      '(looked for ${discoveryFile.path})',
    );
    throw const McpCliExit(McpCliExitCode.launcherUnavailable);
  }

  Future<McpEndpointConfig> resolveEndpointConfig() async {
    var endpoint = explicitEndpoint;
    var token = _sharedOption(_tokenOption) ?? _tokenFromEnvironment();
    if (endpoint == null || token == null) {
      final document = await requireDiscoveryDocument();
      endpoint ??= document.endpoint;
      token ??= document.token;
    }
    return McpEndpointConfig(endpoint: endpoint, token: token);
  }

  Uri? get explicitEndpoint {
    final raw = _sharedOption(_endpointOption);
    if (raw == null) {
      return null;
    }
    final parsed = Uri.tryParse(raw);
    if (parsed == null ||
        !parsed.hasScheme ||
        parsed.host.isEmpty ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      throw UsageException('Invalid --$_endpointOption value: $raw', usage);
    }
    return parsed;
  }

  String? _tokenFromEnvironment() {
    final name = _sharedOption(_tokenEnvOption);
    if (name == null) {
      return null;
    }
    final value = context.environment[name];
    return value == null || value.isEmpty ? null : value;
  }

  String? _sharedOption(String name) {
    final local = argResults?[name];
    if (local is String && local.isNotEmpty) {
      return local;
    }
    final global = globalResults?[name];
    return global is String && global.isNotEmpty ? global : null;
  }
}

class _ProxyCommand extends McpCliCommand {
  _ProxyCommand(super.context);

  @override
  String get name => 'proxy';

  @override
  String get description =>
      'Proxy newline-delimited JSON-RPC on stdin/stdout to the launcher.';

  @override
  Future<int> run() async {
    final config = await resolveEndpointConfig();
    final proxy = McpStdioProxy(
      endpoint: config.endpoint,
      token: config.token,
      input: context.input,
      output: context.output,
      diagnostics: context.diagnostics,
      client: context.httpClientFactory?.call(),
      verbose: verbose,
    );
    return proxy.run();
  }
}

class _StatusCommand extends McpCliCommand {
  _StatusCommand(super.context);

  static const Duration _probeTimeout = Duration(seconds: 2);

  @override
  String get name => 'status';

  @override
  String get description =>
      'Report the launcher endpoint published on this machine.';

  @override
  Future<int> run() async {
    final explicit = explicitEndpoint;
    final document = explicit == null
        ? await requireDiscoveryDocument()
        : await readDiscoveryDocument();
    final endpoint = explicit ?? document!.endpoint;
    final output = context.output;
    output.writeln('endpoint: $endpoint');
    if (document != null) {
      output
        ..writeln('pid: ${document.pid}')
        ..writeln('started_at: ${document.startedAt.toUtc().toIso8601String()}')
        ..writeln('app_version: ${document.appVersion}')
        ..writeln('protocol_versions: ${document.protocolVersions.join(', ')}')
        ..writeln('token: hidden (${document.token.length} characters)')
        ..writeln('discovery_file: ${discoveryFile.path}');
    }
    output.writeln('reachable: ${await _isReachable(endpoint) ? 'yes' : 'no'}');
    return McpCliExitCode.success;
  }

  // A TCP connect avoids sending the token just to learn whether the launcher
  // is listening.
  Future<bool> _isReachable(Uri endpoint) async {
    try {
      final socket = await Socket.connect(
        endpoint.host,
        endpoint.port,
        timeout: _probeTimeout,
      );
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    }
  }
}

class _PrintConfigCommand extends McpCliCommand {
  _PrintConfigCommand(super.context);

  @override
  String get name => 'print-config';

  @override
  String get description =>
      'Print the configuration snippet for an MCP client.';

  @override
  String get invocation => 'nai_launcher_mcp print-config <${_clientNames()}>';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.length != 1) {
      throw UsageException(
        'Specify exactly one client: ${_clientNames()}',
        usage,
      );
    }
    final kind = McpClientKind.fromCliName(rest.single);
    if (kind == null) {
      throw UsageException('Unknown MCP client: ${rest.single}', usage);
    }
    final config = await resolveEndpointConfig();
    context.output.writeln(
      renderMcpClientConfig(
        kind,
        endpoint: config.endpoint,
        token: config.token,
        cliPath: context.executablePath(),
      ),
    );
    return McpCliExitCode.success;
  }

  static String _clientNames() =>
      McpClientKind.values.map((kind) => kind.cliName).join('|');
}

/// Runs the `nai_launcher_mcp` command line and returns its process exit code.
Future<int> runNaiLauncherMcpCli(
  List<String> args, {
  required Stream<List<int>> input,
  required IOSink output,
  required IOSink diagnostics,
  McpDiscoveryFileStore? discovery,
  HttpClient Function()? httpClientFactory,
  String Function()? executablePath,
  Map<String, String>? environment,
}) async {
  final context = McpCliContext(
    input: input,
    output: output,
    diagnostics: diagnostics,
    discoveryStore: discovery ?? McpDiscoveryFileStore(),
    executablePath: executablePath ?? () => Platform.resolvedExecutable,
    environment: environment ?? Platform.environment,
    httpClientFactory: httpClientFactory,
  );
  final runner =
      CommandRunner<int>(
          'nai_launcher_mcp',
          'Bridges MCP clients to a running NAI Launcher.',
        )
        ..addCommand(_ProxyCommand(context))
        ..addCommand(_StatusCommand(context))
        ..addCommand(_PrintConfigCommand(context));
  _addSharedOptions(runner.argParser);

  try {
    var parsed = runner.parse(args);
    // Bare invocation is the stdio proxy; a leftover positional still has to
    // reach CommandRunner so it reports the unknown command.
    if (parsed.command == null &&
        parsed.rest.isEmpty &&
        parsed['help'] != true) {
      parsed = runner.parse(['proxy', ...args]);
    }
    return await runner.runCommand(parsed) ?? McpCliExitCode.success;
  } on McpCliExit catch (exit) {
    return exit.code;
  } on UsageException catch (error) {
    diagnostics.writeln(error);
    return McpCliExitCode.usage;
  } finally {
    await output.flush();
  }
}
