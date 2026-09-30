import base64
import hashlib
import os
import socket
import threading
from typing import Callable, List, Optional, Union
from urllib.parse import urlparse


WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
OPCODE_CONTINUATION = 0x0
OPCODE_TEXT = 0x1
OPCODE_CLOSE = 0x8
OPCODE_PING = 0x9
OPCODE_PONG = 0xA
RECV_CHUNK_BYTES = 4096
# A multiple of 4, so every full block reuses the same mask integer.
MASK_BLOCK_BYTES = 64 * 1024

BytesLike = Union[bytes, bytearray, memoryview]


class ParsedFrame:
    def __init__(self, opcode: int, payload: bytes, consumed: int) -> None:
        self.opcode = opcode
        self.payload = payload
        self.consumed = consumed


class FrameHeader:
    def __init__(
        self,
        opcode: int,
        mask_key: Optional[bytes],
        payload_start: int,
        payload_end: int,
    ) -> None:
        self.opcode = opcode
        self.mask_key = mask_key
        self.payload_start = payload_start
        self.payload_end = payload_end


def accept_key(client_key: str) -> str:
    digest = hashlib.sha1((client_key + WEBSOCKET_GUID).encode("ascii")).digest()
    return base64.b64encode(digest).decode("ascii")


def new_client_key() -> str:
    return base64.b64encode(os.urandom(16)).decode("ascii")


def encode_client_text_frame(text: str) -> bytes:
    return encode_frame(text.encode("utf-8"), opcode=OPCODE_TEXT, mask=True)


def encode_frame(payload: bytes, *, opcode: int, mask: bool = False) -> bytes:
    first = 0x80 | (opcode & 0x0F)
    length = len(payload)
    mask_bit = 0x80 if mask else 0
    if length < 126:
        header = bytes([first, mask_bit | length])
    elif length <= 0xFFFF:
        header = bytes([first, mask_bit | 126]) + length.to_bytes(2, "big")
    else:
        header = bytes([first, mask_bit | 127]) + length.to_bytes(8, "big")

    if not mask:
        return header + payload

    key = os.urandom(4)
    return b"".join([header, key, *_masked_blocks(payload, key)])


def apply_mask(data: BytesLike, mask_key: bytes) -> bytes:
    return b"".join(_masked_blocks(data, mask_key))


def _masked_blocks(data: BytesLike, mask_key: bytes) -> List[bytes]:
    # Big-int XOR runs in C; blocking keeps temporaries from scaling with the frame.
    with memoryview(data) as view:
        length = len(view)
        if length == 0:
            return []
        block_size = min(length, MASK_BLOCK_BYTES)
        block_mask = _repeated_mask(mask_key, block_size)
        blocks = []
        for start in range(0, length, block_size):
            with view[start : start + block_size] as block:
                size = len(block)
                if size == block_size:
                    mask = block_mask
                else:
                    mask = _repeated_mask(mask_key, size)
                masked = int.from_bytes(block, "big") ^ mask
                blocks.append(masked.to_bytes(size, "big"))
        return blocks


def _repeated_mask(mask_key: bytes, size: int) -> int:
    return int.from_bytes((mask_key * (size // 4 + 1))[:size], "big")


def read_frame_header(
    data: BytesLike, *, expect_masked: bool
) -> Optional[FrameHeader]:
    available = len(data)
    if available < 2:
        return None

    first = data[0]
    second = data[1]
    if first & 0x70:
        raise ValueError("Unsupported WebSocket RSV bits")
    if first & 0x80 == 0:
        raise ValueError("Fragmented WebSocket frames are not supported")

    opcode = first & 0x0F
    masked = second & 0x80 != 0
    if masked != expect_masked:
        raise ValueError("Unexpected WebSocket mask bit")

    length = second & 0x7F
    if length == 126:
        length_end = 4
    elif length == 127:
        length_end = 10
    else:
        length_end = 2
    header_end = length_end + 4 if masked else length_end
    if available < header_end:
        return None

    if length_end > 2:
        length = int.from_bytes(data[2:length_end], "big")
    mask_key = bytes(data[length_end:header_end]) if masked else None
    return FrameHeader(
        opcode=opcode,
        mask_key=mask_key,
        payload_start=header_end,
        payload_end=header_end + length,
    )


def parse_frame(data: BytesLike, *, expect_masked: bool) -> ParsedFrame:
    header = read_frame_header(data, expect_masked=expect_masked)
    if header is None:
        raise ValueError("Incomplete WebSocket frame header")
    if len(data) < header.payload_end:
        raise ValueError("Incomplete WebSocket payload")
    return _materialize_frame(data, header)


def _materialize_frame(data: BytesLike, header: FrameHeader) -> ParsedFrame:
    with memoryview(data)[header.payload_start : header.payload_end] as payload_view:
        if header.mask_key is None:
            payload = bytes(payload_view)
        else:
            payload = apply_mask(payload_view, header.mask_key)
    return ParsedFrame(
        opcode=header.opcode,
        payload=payload,
        consumed=header.payload_end,
    )


class FrameBuffer:
    def __init__(self, *, expect_masked: bool) -> None:
        self._data = bytearray()
        self._expect_masked = expect_masked
        self._header: Optional[FrameHeader] = None

    def feed(self, chunk: BytesLike) -> None:
        self._data += chunk

    def pop_frame(self) -> Optional[ParsedFrame]:
        header = self._header
        if header is None:
            header = read_frame_header(self._data, expect_masked=self._expect_masked)
            if header is None:
                return None
            self._header = header
        if len(self._data) < header.payload_end:
            return None
        frame = _materialize_frame(self._data, header)
        del self._data[: header.payload_end]
        self._header = None
        return frame


class FallbackWebSocketClient:
    def __init__(
        self,
        *,
        on_connected: Callable[[], None],
        on_text_message: Callable[[str], None],
        on_disconnected: Callable[[], None],
        on_error: Callable[[str], None],
    ) -> None:
        self._on_connected = on_connected
        self._on_text_message = on_text_message
        self._on_disconnected = on_disconnected
        self._on_error = on_error
        self._socket: Optional[socket.socket] = None
        self._thread: Optional[threading.Thread] = None
        self._closed = False
        self._send_lock = threading.Lock()

    def open(self, url: str) -> None:
        self.close()
        self._closed = False
        self._thread = threading.Thread(
            target=self._run,
            args=(url,),
            name="NAILauncherBridgeFallbackWebSocket",
            daemon=True,
        )
        self._thread.start()

    def send_text(self, text: str) -> bool:
        sock = self._socket
        if sock is None:
            self._on_error("Fallback WebSocket is not connected")
            return False
        try:
            frame = encode_client_text_frame(text)
            with self._send_lock:
                sock.sendall(frame)
            return True
        except OSError as error:
            self._on_error(str(error))
            self.close()
            return False

    def close(self) -> None:
        self._closed = True
        sock = self._socket
        self._socket = None
        if sock is not None:
            try:
                sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            try:
                sock.close()
            except OSError:
                pass

    def _run(self, url: str) -> None:
        try:
            sock = self._connect(url)
            self._socket = sock
            self._on_connected()
            self._read_loop(sock)
        except Exception as error:
            if not self._closed:
                self._on_error(str(error))
        finally:
            self.close()
            self._on_disconnected()

    def _connect(self, url: str) -> socket.socket:
        parsed = urlparse(url)
        if parsed.scheme != "ws":
            raise ValueError("Fallback WebSocket only supports ws:// URLs")
        if parsed.hostname not in {"127.0.0.1", "localhost"}:
            raise ValueError("Fallback WebSocket only connects to loopback hosts")
        if parsed.port is None:
            raise ValueError("Missing WebSocket port")

        path = parsed.path or "/"
        if parsed.query:
            path = f"{path}?{parsed.query}"
        key = new_client_key()

        sock = socket.create_connection((parsed.hostname, parsed.port), timeout=5)
        request = (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: {parsed.hostname}:{parsed.port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n"
            "\r\n"
        )
        sock.sendall(request.encode("ascii"))
        response = self._read_http_response(sock)
        self._validate_handshake_response(response, key)
        sock.settimeout(None)
        return sock

    def _read_http_response(self, sock: socket.socket) -> bytes:
        data = bytearray()
        while b"\r\n\r\n" not in data:
            chunk = sock.recv(4096)
            if not chunk:
                raise ValueError("WebSocket handshake closed early")
            data.extend(chunk)
            if len(data) > 32 * 1024:
                raise ValueError("WebSocket handshake response is too large")
        return bytes(data)

    def _validate_handshake_response(self, response: bytes, key: str) -> None:
        header_text = response.split(b"\r\n\r\n", 1)[0].decode(
            "iso-8859-1",
            errors="replace",
        )
        lines = header_text.split("\r\n")
        if not lines or " 101 " not in lines[0]:
            raise ValueError("WebSocket handshake was not accepted")

        headers = {}
        for line in lines[1:]:
            if ":" not in line:
                continue
            name, value = line.split(":", 1)
            headers[name.strip().lower()] = value.strip()

        if headers.get("sec-websocket-accept") != accept_key(key):
            raise ValueError("WebSocket handshake accept key mismatch")

    def _read_loop(self, sock: socket.socket) -> None:
        frames = FrameBuffer(expect_masked=False)
        while not self._closed:
            chunk = sock.recv(RECV_CHUNK_BYTES)
            if not chunk:
                return
            frames.feed(chunk)
            frame = frames.pop_frame()
            while frame is not None:
                if frame.opcode == OPCODE_TEXT:
                    self._on_text_message(frame.payload.decode("utf-8"))
                elif frame.opcode == OPCODE_CLOSE:
                    return
                elif frame.opcode == OPCODE_PING:
                    self._send_control(OPCODE_PONG, frame.payload)
                frame = frames.pop_frame()

    def _send_control(self, opcode: int, payload: bytes) -> None:
        sock = self._socket
        if sock is None:
            return
        frame = encode_frame(payload, opcode=opcode, mask=True)
        with self._send_lock:
            sock.sendall(frame)
