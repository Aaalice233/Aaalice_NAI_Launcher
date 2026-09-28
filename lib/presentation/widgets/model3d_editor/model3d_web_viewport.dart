import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// InAppWebView 视口:加载 editor.html 并接线桥消息
class Model3dWebViewport extends StatelessWidget {
  final Uri editorUrl;
  final void Function(List<dynamic> args) onBridgeMessage;
  final void Function(InAppWebViewController controller) onControllerReady;

  const Model3dWebViewport({
    super.key,
    required this.editorUrl,
    required this.onBridgeMessage,
    required this.onControllerReady,
  });

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(editorUrl)),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
      ),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: 'naiModel3d',
          callback: onBridgeMessage,
        );
        onControllerReady(controller);
      },
    );
  }
}
