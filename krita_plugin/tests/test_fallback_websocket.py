import builtins
import importlib.util
import random
import socket
import threading
import unittest
from pathlib import Path
from unittest import mock

PLUGIN_ROOT = Path(__file__).resolve().parents[1] / "nai_launcher_bridge"


def _load_module(name: str, file_name: str):
    spec = importlib.util.spec_from_file_location(name, PLUGIN_ROOT / file_name)
    module = importlib.util.module_from_spec(spec)
    assert spec is not None and spec.loader is not None
    spec.loader.exec_module(module)
    return module


fallback = _load_module("krita_bridge_fallback_websocket_test", "fallback_websocket.py")


class FallbackWebSocketTests(unittest.TestCase):
    def test_client_text_frame_is_masked_and_round_trips(self):
        frame = fallback.encode_client_text_frame("hello")

        self.assertNotEqual(frame[1] & 0x80, 0)
        parsed = fallback.parse_frame(frame, expect_masked=True)

        self.assertEqual(parsed.opcode, fallback.OPCODE_TEXT)
        self.assertEqual(parsed.payload, b"hello")
        self.assertEqual(parsed.consumed, len(frame))

    def test_server_text_frame_round_trips_without_mask(self):
        frame = fallback.encode_frame(b'{"type":"pong"}', opcode=fallback.OPCODE_TEXT)

        self.assertEqual(frame[1] & 0x80, 0)
        parsed = fallback.parse_frame(frame, expect_masked=False)

        self.assertEqual(parsed.opcode, fallback.OPCODE_TEXT)
        self.assertEqual(parsed.payload, b'{"type":"pong"}')

    def test_apply_mask_matches_per_byte_reference(self):
        block = fallback.MASK_BLOCK_BYTES
        lengths = [0, 1, 2, 3, 4, 5, 7, 125, 126, 65535, 65536]
        lengths += [block - 1, block, block + 1, 2 * block + 3]
        keys = [b"\x00\x00\x00\x00", b"\xff\xff\xff\xff", b"\x12\x34\x56\x78"]
        for length in lengths:
            payload = random.Random(length).randbytes(length)
            for key in keys:
                with self.subTest(length=length, key=key.hex()):
                    self.assertEqual(
                        fallback._apply_mask(payload, key),
                        _reference_mask(payload, key),
                    )

    def test_masked_frame_matches_reference_for_every_length_encoding(self):
        for length, length_code, header_size in [
            (0, 0, 2),
            (125, 125, 2),
            (126, 126, 4),
            (65535, 126, 4),
            (65536, 127, 10),
            (70001, 127, 10),
        ]:
            payload = random.Random(length).randbytes(length)
            with self.subTest(length=length):
                frame = fallback.encode_frame(
                    payload,
                    opcode=fallback.OPCODE_TEXT,
                    mask=True,
                )

                self.assertEqual(frame[1], 0x80 | length_code)
                key = frame[header_size : header_size + 4]
                self.assertEqual(
                    frame[header_size + 4 :],
                    _reference_mask(payload, key),
                )
                parsed = fallback.parse_frame(frame, expect_masked=True)
                self.assertEqual(parsed.payload, payload)
                self.assertEqual(parsed.consumed, len(frame))

    def test_parse_frame_reports_every_truncation_as_incomplete(self):
        frame = fallback.encode_frame(
            b"z" * 65536,
            opcode=fallback.OPCODE_TEXT,
            mask=True,
        )

        for size in [0, 1, 2, 9, 10, 13, 14, len(frame) - 1]:
            with self.subTest(size=size):
                with self.assertRaisesRegex(ValueError, "^Incomplete "):
                    fallback.parse_frame(frame[:size], expect_masked=True)

    def test_frame_buffer_materializes_payload_only_once_complete(self):
        payload = b"x" * (1024 * 1024 + 3)
        frame = fallback.encode_frame(payload, opcode=fallback.OPCODE_TEXT)
        frames = fallback.FrameBuffer(expect_masked=False)
        copies = _CopyCounter()

        last = len(frame) - 1
        with mock.patch.object(fallback, "bytes", copies, create=True):
            for start in range(0, last, 4096):
                frames.feed(frame[start : min(start + 4096, last)])
                self.assertIsNone(frames.pop_frame())
            self.assertEqual(copies.copied, 0)

            frames.feed(frame[last:])
            parsed = frames.pop_frame()

        self.assertEqual(parsed.payload, payload)
        self.assertEqual(parsed.consumed, len(frame))
        self.assertLessEqual(copies.copied, len(payload))
        self.assertIsNone(frames.pop_frame())

    def test_read_loop_copy_volume_stays_linear_for_large_frames(self):
        payload = b"y" * (2 * 1024 * 1024)
        stream = fallback.encode_frame(payload, opcode=fallback.OPCODE_TEXT)
        client, received = _recording_client()
        copies = _CopyCounter()

        with mock.patch.object(fallback, "bytes", copies, create=True):
            client._read_loop(_ChunkedSocket(stream, 4096))

        self.assertEqual(received, [payload.decode("ascii")])
        self.assertLessEqual(copies.copied, len(payload))

    def test_read_loop_reassembles_frames_across_any_chunk_boundary(self):
        long_text = "界" * 21846
        stream = b"".join(
            [
                _server_text("a"),
                _server_text("b" * 125),
                fallback.encode_frame(b"hb", opcode=fallback.OPCODE_PING),
                _server_text("c" * 126),
                _server_text(long_text),
                fallback.encode_frame(b"", opcode=fallback.OPCODE_PONG),
                _server_text("d"),
                fallback.encode_frame(b"", opcode=fallback.OPCODE_CLOSE),
                _server_text("after close"),
            ]
        )

        for chunk_size in [1, 2, 3, 7, 4096, len(stream)]:
            with self.subTest(chunk_size=chunk_size):
                client, received = _recording_client()
                sock = _ChunkedSocket(stream, chunk_size)
                client._socket = sock

                client._read_loop(sock)

                self.assertEqual(
                    received,
                    ["a", "b" * 125, "c" * 126, long_text, "d"],
                )
                self.assertEqual(len(sock.sent), 1)
                pong = fallback.parse_frame(sock.sent[0], expect_masked=True)
                self.assertEqual(pong.opcode, fallback.OPCODE_PONG)
                self.assertEqual(pong.payload, b"hb")

    def test_read_loop_rejects_protocol_violations_from_header_alone(self):
        for header, message in [
            (bytes([0xC1, 0x05]), "RSV"),
            (bytes([0x01, 0x05]), "Fragmented"),
            (bytes([0x81, 0x85]), "mask bit"),
        ]:
            with self.subTest(message=message):
                client, _received = _recording_client()

                with self.assertRaisesRegex(ValueError, message):
                    client._read_loop(_ChunkedSocket(header, 4096))

    def test_read_loop_propagates_invalid_utf8_text(self):
        stream = fallback.encode_frame(b"\xff\xfe", opcode=fallback.OPCODE_TEXT)
        client, _received = _recording_client()

        with self.assertRaises(UnicodeDecodeError):
            client._read_loop(_ChunkedSocket(stream, 4096))

    def test_accept_key_matches_rfc_example(self):
        accept = fallback.accept_key("dGhlIHNhbXBsZSBub25jZQ==")

        self.assertEqual(accept, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")

    def test_connect_rejects_non_loopback_hosts_before_socket_open(self):
        client = _new_client()

        with self.assertRaisesRegex(ValueError, "loopback"):
            client._connect("ws://192.0.2.10:52381/krita")

    def test_connect_rejects_unsupported_scheme_and_missing_port(self):
        client = _new_client()

        with self.assertRaisesRegex(ValueError, "ws://"):
            client._connect("wss://127.0.0.1:52381/krita")

        with self.assertRaisesRegex(ValueError, "Missing WebSocket port"):
            client._connect("ws://127.0.0.1/krita")

    def test_handshake_rejects_accept_key_mismatch(self):
        client = _new_client()
        response = (
            "HTTP/1.1 101 Switching Protocols\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            "Sec-WebSocket-Accept: wrong\r\n"
            "\r\n"
        ).encode("ascii")

        with self.assertRaisesRegex(ValueError, "accept key mismatch"):
            client._validate_handshake_response(response, "client-key")

    def test_fallback_client_connects_sends_and_receives_text(self):
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        port = server.getsockname()[1]
        received = []
        errors = []
        message_received = threading.Event()

        def serve_once():
            try:
                conn, _addr = server.accept()
                with conn:
                    request = _recv_until(conn, b"\r\n\r\n")
                    key = _header_value(request, "Sec-WebSocket-Key")
                    response = (
                        "HTTP/1.1 101 Switching Protocols\r\n"
                        "Upgrade: websocket\r\n"
                        "Connection: Upgrade\r\n"
                        f"Sec-WebSocket-Accept: {fallback.accept_key(key)}\r\n"
                        "\r\n"
                    )
                    conn.sendall(response.encode("ascii"))
                    frame = _recv_frame(conn, expect_masked=True)
                    received.append(frame.payload.decode("utf-8"))
                    conn.sendall(
                        fallback.encode_frame(
                            b'{"type":"pong"}',
                            opcode=fallback.OPCODE_TEXT,
                        )
                    )
            except Exception as error:
                errors.append(error)
            finally:
                server.close()

        thread = threading.Thread(target=serve_once, daemon=True)
        thread.start()

        client = None

        def on_connected():
            client.send_text('{"type":"ping"}')

        def on_text_message(text):
            received.append(text)
            message_received.set()

        client = fallback.FallbackWebSocketClient(
            on_connected=on_connected,
            on_text_message=on_text_message,
            on_disconnected=lambda: None,
            on_error=errors.append,
        )
        try:
            client.open(f"ws://127.0.0.1:{port}/krita")
            self.assertTrue(message_received.wait(2))
            self.assertEqual(received[0], '{"type":"ping"}')
            self.assertEqual(received[1], '{"type":"pong"}')
            self.assertEqual(errors, [])
        finally:
            client.close()
            thread.join(timeout=2)


def _new_client():
    return fallback.FallbackWebSocketClient(
        on_connected=lambda: None,
        on_text_message=lambda _text: None,
        on_disconnected=lambda: None,
        on_error=lambda _error: None,
    )


def _recording_client():
    received = []
    client = fallback.FallbackWebSocketClient(
        on_connected=lambda: None,
        on_text_message=received.append,
        on_disconnected=lambda: None,
        on_error=lambda _error: None,
    )
    return client, received


def _server_text(text: str) -> bytes:
    return fallback.encode_frame(text.encode("utf-8"), opcode=fallback.OPCODE_TEXT)


def _reference_mask(payload: bytes, key: bytes) -> bytes:
    return bytes(byte ^ key[index % 4] for index, byte in enumerate(payload))


class _ChunkedSocket:
    def __init__(self, data: bytes, chunk_size: int) -> None:
        self._data = data
        self._offset = 0
        self._chunk_size = chunk_size
        self.sent = []

    def recv(self, size: int) -> bytes:
        end = self._offset + min(size, self._chunk_size)
        chunk = self._data[self._offset : end]
        self._offset += len(chunk)
        return chunk

    def sendall(self, data: bytes) -> None:
        self.sent.append(bytes(data))


class _CopyCounter:
    def __init__(self) -> None:
        self.copied = 0

    def __call__(self, *args):
        if args and isinstance(args[0], (bytearray, memoryview)):
            self.copied += len(args[0])
        return builtins.bytes(*args)


def _recv_until(conn, marker: bytes) -> bytes:
    data = bytearray()
    while marker not in data:
        chunk = conn.recv(4096)
        if not chunk:
            raise RuntimeError("Connection closed before marker")
        data.extend(chunk)
    return bytes(data)


def _recv_frame(conn, *, expect_masked: bool):
    data = bytearray()
    while True:
        chunk = conn.recv(4096)
        if not chunk:
            raise RuntimeError("Connection closed before frame")
        data.extend(chunk)
        try:
            return fallback.parse_frame(bytes(data), expect_masked=expect_masked)
        except ValueError as error:
            if str(error).startswith("Incomplete "):
                continue
            raise


def _header_value(request: bytes, name: str) -> str:
    prefix = name.lower() + ":"
    for line in request.decode("iso-8859-1").split("\r\n"):
        if line.lower().startswith(prefix):
            return line.split(":", 1)[1].strip()
    raise RuntimeError(f"Missing {name} header")


if __name__ == "__main__":
    unittest.main()
