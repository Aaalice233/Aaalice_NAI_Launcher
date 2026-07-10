// lib/dev/model3d_spike_main.dart
//
// 3D 编辑器链路 spike:LocalAssetServer + InAppWebView + three.js + 桥往返。
// 运行:flutter run -d windows -t lib/dev/model3d_spike_main.dart
// 不被 lib/main.dart 引用,release 构建自动剔除。
//
// 无人值守自检:onReady 时写 %TEMP%/model3d_spike_ready.txt 并自动请求一次
// 渲染,PNG 落盘 %TEMP%/model3d_spike_render.png,供无屏环境验证全链路。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../presentation/widgets/model3d_editor/local_asset_server.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _SpikePage()));
}

class _SpikePage extends StatefulWidget {
  const _SpikePage();

  @override
  State<_SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<_SpikePage> {
  final _server = LocalAssetServer();
  InAppWebViewController? _controller;
  Uri? _base;
  String _status = 'starting server...';
  int _nextRequestId = 0;

  @override
  void initState() {
    super.initState();
    _server.start().then((base) => setState(() {
          _base = base;
          _status = 'server at $base';
        }));
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  void _diagLog(String line) {
    File('${Directory.systemTemp.path}/model3d_spike_log.txt').writeAsStringSync(
      '${DateTime.now().toIso8601String()} $line\n',
      mode: FileMode.append,
    );
  }

  void _onJsMessage(List<dynamic> args) {
    _diagLog('jsMessage: ${jsonEncode(args)}');
    final msg = (args.first as Map).cast<String, dynamic>();
    if (msg['type'] == 'onReady') {
      if (mounted) {
        setState(() => _status = 'bridge ready (onReady received)');
      }
      File('${Directory.systemTemp.path}/model3d_spike_ready.txt')
          .writeAsStringSync(DateTime.now().toIso8601String());
      _requestRender();
    } else if (msg['type'] == 'response') {
      if (msg['ok'] != true) {
        _diagLog('response error: ${jsonEncode(msg['data'])}');
        return;
      }
      final png = base64Decode((msg['data'] as Map)['png'] as String);
      File('${Directory.systemTemp.path}/model3d_spike_render.png')
          .writeAsBytesSync(png);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(child: Image.memory(png)),
      );
    }
  }

  Future<void> _requestRender() async {
    final id = ++_nextRequestId;
    final command = jsonEncode({'type': 'render', 'requestId': id});
    await _controller?.evaluateJavascript(
      source: 'window.naiEditor.dispatch(${jsonEncode(command)})',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_status)),
      floatingActionButton: FloatingActionButton(
        onPressed: _requestRender,
        child: const Icon(Icons.camera_alt),
      ),
      body: _base == null
          ? const Center(child: CircularProgressIndicator())
          : InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(
                  '$_base'
                  'editor/${const String.fromEnvironment('MODEL3D_PAGE', defaultValue: 'spike.html')}',
                ),
              ),
              onWebViewCreated: (controller) {
                _diagLog('webViewCreated');
                _controller = controller;
                controller.addJavaScriptHandler(
                  handlerName: 'naiModel3d',
                  callback: _onJsMessage,
                );
              },
              onLoadStop: (controller, url) => _diagLog('loadStop: $url'),
              onReceivedError: (controller, request, error) =>
                  _diagLog('loadError: ${request.url} -> ${error.description}'),
              onConsoleMessage: (controller, message) => _diagLog(
                'console[${message.messageLevel}]: ${message.message}',
              ),
            ),
    );
  }
}
