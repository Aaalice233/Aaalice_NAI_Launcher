import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'backend_test_support.dart';

class FakeGitHubApi implements HttpClientAdapter {
  FakeGitHubApi({
    Map<String, Uint8List>? initialFiles,
    this.repositoryPrivate = true,
  }) {
    final files = Map<String, Uint8List>.from(initialFiles ?? {});
    _commits['c0'] = files;
    _trees['t0'] = files;
    _commitTrees['c0'] = 't0';
    _trees['4b825dc642cb6eb9a060e54bf8d69288fbee4904'] = {};
  }

  final bool repositoryPrivate;
  final List<RequestOptions> requests = [];
  final Map<String, Uint8List> blobs = {};
  final Map<String, Map<String, Uint8List>> _commits = {};
  final Map<String, Map<String, Uint8List>> _trees = {};
  final Map<String, String> _commitTrees = {};
  final Map<String, String> _parents = {};
  String branch = 'c0';
  int _sequence = 1;
  bool conflictNextRefUpdate = false;
  String? staleInlinePath;
  Uint8List? staleInlineBytes;

  Map<String, Uint8List> get files => _commits[branch]!;
  int get snapshotCommitCount =>
      requests.where((r) => r.method == 'PATCH').length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(request);
    final result = _handle(request);
    return ResponseBody.fromString(
      result.body,
      result.status,
      headers: result.headers,
    );
  }

  TestHttpResponse _handle(RequestOptions request) {
    final path = request.uri.path;
    if (path == '/repos/alice/private') {
      return TestHttpResponse(
        200,
        jsonBody({
          'size': 1,
          'private': repositoryPrivate,
          'permissions': {'push': true},
        }),
      );
    }
    if (path.endsWith('/branches/sync')) {
      return TestHttpResponse(
        200,
        jsonBody({
          'commit': {'sha': branch},
        }),
      );
    }
    if (request.method == 'GET' && path.contains('/git/commits/')) {
      final commit = Uri.decodeComponent(path.split('/').last);
      final tree = _commitTrees[commit];
      return tree == null
          ? const TestHttpResponse(404, '{}')
          : TestHttpResponse(
              200,
              jsonBody({
                'sha': commit,
                'tree': {'sha': tree},
              }),
            );
    }
    if (request.method == 'GET' && path.contains('/contents/')) {
      return _readContents(request);
    }
    if (request.method == 'GET' && path.contains('/git/blobs/')) {
      final sha = path.split('/').last;
      final bytes = blobs[sha];
      return bytes == null
          ? const TestHttpResponse(404, '{}')
          : TestHttpResponse(
              200,
              jsonBody({
                'sha': sha,
                'encoding': 'base64',
                'content': base64Encode(bytes),
              }),
            );
    }
    if (request.method == 'GET' && path.contains('/git/trees/')) {
      final treeSha = path.split('/').last;
      final files = _trees[treeSha];
      return files == null
          ? const TestHttpResponse(404, '{}')
          : TestHttpResponse(
              200,
              jsonBody({'sha': treeSha, 'tree': _topLevelTree(files)}),
            );
    }
    if (request.method == 'POST' && path.endsWith('/git/blobs')) {
      final body = _body(request);
      final bytes = base64Decode(body['content'] as String);
      final sha = _blobSha(bytes);
      blobs[sha] = bytes;
      return TestHttpResponse(201, jsonBody({'sha': sha}));
    }
    if (request.method == 'POST' && path.endsWith('/git/trees')) {
      return _createTree(request);
    }
    if (request.method == 'POST' && path.endsWith('/git/commits')) {
      final body = _body(request);
      final commit = 'c${_sequence++}';
      final tree = body['tree'] as String;
      final parent = (body['parents'] as List).single as String;
      _commits[commit] = Map.from(_trees[tree]!);
      _commitTrees[commit] = tree;
      _parents[commit] = parent;
      return TestHttpResponse(201, jsonBody({'sha': commit}));
    }
    if (request.method == 'PATCH' && path.contains('/git/refs/heads/')) {
      final body = _body(request);
      final target = body['sha'] as String;
      if (conflictNextRefUpdate) {
        conflictNextRefUpdate = false;
        _advanceExternal();
      }
      if (body['force'] != false || _parents[target] != branch) {
        return const TestHttpResponse(422, '{}');
      }
      branch = target;
      return TestHttpResponse(
        200,
        jsonBody({
          'object': {'sha': target},
        }),
      );
    }
    if (request.method == 'PUT' && path.endsWith('/contents/cloud/KEY.json')) {
      return _putKey(request);
    }
    return TestHttpResponse(
      500,
      jsonBody({'unexpected': '${request.method} $path'}),
    );
  }

  TestHttpResponse _readContents(RequestOptions request) {
    const marker = '/contents/';
    final path = Uri.decodeComponent(
      request.uri.path.substring(
        request.uri.path.indexOf(marker) + marker.length,
      ),
    );
    final requestedRef = request.uri.queryParameters['ref'];
    final ref = requestedRef == null || requestedRef == 'sync'
        ? branch
        : requestedRef;
    final files = _commits[ref];
    if (files == null) return const TestHttpResponse(404, '{}');
    final bytes = files[path];
    if (bytes != null) {
      final sha = _blobSha(bytes);
      blobs[sha] = bytes;
      final inline = staleInlinePath == path ? staleInlineBytes! : bytes;
      return TestHttpResponse(
        200,
        jsonBody({
          'sha': sha,
          'encoding': 'base64',
          'content': base64Encode(inline),
        }),
      );
    }
    final prefix = '$path/';
    if (files.keys.any((key) => key.startsWith(prefix))) {
      return TestHttpResponse(
        200,
        jsonBody([
          {'type': 'dir', 'path': path},
        ]),
      );
    }
    return const TestHttpResponse(404, '{}');
  }

  TestHttpResponse _createTree(RequestOptions request) {
    final body = _body(request);
    final baseTree = body['base_tree'];
    final base = baseTree == null
        ? <String, Uint8List>{}
        : Map<String, Uint8List>.from(_trees[baseTree]!);
    for (final raw in body['tree'] as List) {
      final entry = raw as Map<String, dynamic>;
      final path = entry['path'] as String;
      final sha = entry['sha'];
      if (sha == null) {
        base.removeWhere((key, _) => key == path || key.startsWith('$path/'));
      } else {
        base[path] = blobs[sha]!;
      }
    }
    final tree = 't${_sequence++}';
    _trees[tree] = base;
    return TestHttpResponse(201, jsonBody({'sha': tree}));
  }

  TestHttpResponse _putKey(RequestOptions request) {
    final body = _body(request);
    final current = files['cloud/KEY.json'];
    if (current != null && body['sha'] != _blobSha(current)) {
      return const TestHttpResponse(409, '{}');
    }
    if (current == null && body.containsKey('sha')) {
      return const TestHttpResponse(409, '{}');
    }
    final bytes = base64Decode(body['content'] as String);
    final next = Map<String, Uint8List>.from(files)..['cloud/KEY.json'] = bytes;
    _advance(next);
    return TestHttpResponse(
      current == null ? 201 : 200,
      jsonBody({
        'content': {'sha': _blobSha(bytes)},
        'commit': {'sha': branch},
      }),
    );
  }

  void _advanceExternal() => _advance(Map<String, Uint8List>.from(files));

  void _advance(Map<String, Uint8List> next) {
    final parent = branch;
    final tree = 't${_sequence++}';
    final commit = 'c${_sequence++}';
    _trees[tree] = next;
    _commits[commit] = next;
    _commitTrees[commit] = tree;
    _parents[commit] = parent;
    branch = commit;
  }

  static Map<String, dynamic> _body(RequestOptions request) =>
      jsonDecode(request.data as String) as Map<String, dynamic>;

  static String _blobSha(Uint8List bytes) {
    final header = utf8.encode('blob ${bytes.length}\u0000');
    return sha1.convert([...header, ...bytes]).toString();
  }

  List<Map<String, Object>> _topLevelTree(Map<String, Uint8List> files) {
    final entries = <String, Map<String, Object>>{};
    for (final entry in files.entries) {
      final slash = entry.key.indexOf('/');
      final name = slash < 0 ? entry.key : entry.key.substring(0, slash);
      if (slash < 0) {
        final sha = _blobSha(entry.value);
        blobs[sha] = entry.value;
        entries[name] = {
          'path': name,
          'mode': '100644',
          'type': 'blob',
          'sha': sha,
        };
      } else {
        entries[name] = {
          'path': name,
          'mode': '040000',
          'type': 'tree',
          'sha': 'directory-$name',
        };
      }
    }
    return entries.values.toList();
  }

  @override
  void close({bool force = false}) {}
}
