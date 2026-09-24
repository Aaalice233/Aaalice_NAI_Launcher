import 'dart:io';

/// Starts a loopback HTTP server that hangs up on every request without
/// responding. The test owns the port until it closes the server, so no other
/// process can answer in its place.
Future<HttpServer> bindHangUpServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    // Unread request bytes turn the close into a reset, which clients report
    // as a different error than a hang-up.
    await request.drain<void>();
    final socket = await request.response.detachSocket(writeHeaders: false);
    socket.destroy();
  });
  return server;
}

/// A loopback port that refuses connections. The client end of a live loopback
/// connection occupies it, so ephemeral binds cannot hand it out the way they
/// can reuse a port freed by closing a server.
class RefusingLoopbackPort {
  RefusingLoopbackPort._(this._holder, this._peer);

  final Socket _holder;
  final Socket _peer;

  int get port => _holder.port;

  static Future<RefusingLoopbackPort> reserve() async {
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final pair = await Future.wait([
        Socket.connect(InternetAddress.loopbackIPv4, listener.port),
        listener.first,
      ], eagerError: true);
      return RefusingLoopbackPort._(pair[0], pair[1]);
    } finally {
      await listener.close();
    }
  }

  void release() {
    _holder.destroy();
    _peer.destroy();
  }
}
