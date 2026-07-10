// lib/dev/model3d_spike_main.dart
//
// 3D 编辑器链路 spike:LocalAssetServer + InAppWebView + three.js + 桥往返。
// 运行:flutter run -d windows -t lib/dev/model3d_spike_main.dart
// 不被 lib/main.dart 引用,release 构建自动剔除。
import 'dart:convert';

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

  void _onJsMessage(List<dynamic> args) {
    final msg = (args.first as Map).cast<String, dynamic>();
    if (msg['type'] == 'onReady') {
      setState(() => _status = 'bridge ready (onReady received)');
    } else if (msg['type'] == 'response') {
      final png = base64Decode((msg['data'] as Map)['png'] as String);
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
                url: WebUri('${_base}editor/spike.html'),
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
                controller.addJavaScriptHandler(
                  handlerName: 'naiModel3d',
                  callback: _onJsMessage,
                );
              },
            ),
    );
  }
}
