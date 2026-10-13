import 'dart:convert';

import 'agent_chat_resource_reference_validator.dart';

/// Reversible mapping from application ids to opaque reference identifiers.
///
/// Ids the validator already accepts pass through unchanged; any other id is
/// escaped behind [encodedPrefix] so references never carry path-like ids.
abstract final class AgentChatResourceIdentifier {
  // The dot keeps long escaped ids from looking like base64 payloads.
  static const String encodedPrefix = 'enc.';

  static const String _escape = '+';
  static const String _percent = '%';
  // Work ids are often percent-encoded; one stand-in char keeps them short.
  static const String _percentStandIn = '@';
  static final RegExp _kept = RegExp(r'^[A-Za-z0-9._:-]$');
  static final RegExp _hexPair = RegExp(r'^[0-9A-F]{2}$');

  static String encode(String id) {
    if (!id.startsWith(encodedPrefix) &&
        AgentChatResourceReferenceValidator.isOpaqueIdentifier(id)) {
      return id;
    }
    final buffer = StringBuffer(encodedPrefix);
    for (final byte in utf8.encode(id)) {
      final char = String.fromCharCode(byte);
      if (_kept.hasMatch(char)) {
        buffer.write(char);
      } else if (char == _percent) {
        buffer.write(_percentStandIn);
      } else {
        buffer
          ..write(_escape)
          ..write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
    }
    return buffer.toString();
  }

  /// Returns null when [id] is not the canonical encoding of any id.
  static String? decode(String id) {
    if (!id.startsWith(encodedPrefix)) return id;
    final body = id.substring(encodedPrefix.length);
    final bytes = <int>[];
    for (var index = 0; index < body.length; index++) {
      final char = body[index];
      if (char == _percentStandIn) {
        bytes.addAll(utf8.encode(_percent));
      } else if (char == _escape) {
        if (index + 3 > body.length) return null;
        final pair = body.substring(index + 1, index + 3);
        if (!_hexPair.hasMatch(pair)) return null;
        bytes.add(int.parse(pair, radix: 16));
        index += 2;
      } else if (_kept.hasMatch(char)) {
        bytes.addAll(utf8.encode(char));
      } else {
        return null;
      }
    }
    final String decoded;
    try {
      decoded = utf8.decode(bytes);
    } on FormatException {
      return null;
    }
    return encode(decoded) == id ? decoded : null;
  }
}
