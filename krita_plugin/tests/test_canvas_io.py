import importlib.util
import sys
import types
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parents[1] / "nai_launcher_bridge"


def _install_krita_stubs():
    pyqt5 = types.ModuleType("PyQt5")
    qtcore = types.ModuleType("PyQt5.QtCore")
    qtgui = types.ModuleType("PyQt5.QtGui")
    krita = types.ModuleType("krita")

    class _QByteArray(bytes):
        pass

    class _QBuffer:
        def open(self, *_args):
            return True

        def data(self):
            return b""

    class _QIODevice:
        WriteOnly = 1

    class _QImage:
        Format_Grayscale8 = 1
        Format_RGBA8888 = 2

    class _InfoObject:
        pass

    class _Krita:
        @staticmethod
        def instance():
            return None

    qtcore.QByteArray = _QByteArray
    qtcore.QBuffer = _QBuffer
    qtcore.QIODevice = _QIODevice
    qtgui.QImage = _QImage
    krita.InfoObject = _InfoObject
    krita.Krita = _Krita

    sys.modules["PyQt5"] = pyqt5
    sys.modules["PyQt5.QtCore"] = qtcore
    sys.modules["PyQt5.QtGui"] = qtgui
    sys.modules["krita"] = krita


def _load_canvas_io():
    _install_krita_stubs()
    spec = importlib.util.spec_from_file_location(
        "krita_bridge_canvas_io_test",
        PLUGIN_ROOT / "canvas_io.py",
    )
    module = importlib.util.module_from_spec(spec)
    assert spec is not None and spec.loader is not None
    spec.loader.exec_module(module)
    return module


canvas_io = _load_canvas_io()


class FakeSizedDoc:
    def __init__(self, width, height):
        self._width = width
        self._height = height

    def width(self):
        return self._width

    def height(self):
        return self._height


class FakeProjection:
    def __init__(self, data=b"projection-png", succeeds=True):
        self._data = data
        self._succeeds = succeeds

    def save(self, buffer, fmt):
        if fmt != "PNG" or not self._succeeds:
            return False
        buffer._data = self._data
        return True


class FakeProjectionBuffer:
    def __init__(self):
        self._data = b""

    def open(self, *_args):
        return True

    def data(self):
        return self._data


class FakeExportDoc(FakeSizedDoc):
    def __init__(self, width, height, *, projection_succeeds=True):
        super().__init__(width, height)
        self.projection_succeeds = projection_succeeds
        self.exported = False

    def projection(self, x, y, width, height):
        if (x, y, width, height) != (0, 0, self.width(), self.height()):
            raise AssertionError("projection should use full document bounds")
        return FakeProjection(succeeds=self.projection_succeeds)

    def exportImage(self, path, _info):
        Path(path).write_bytes(b"temp-export-png")
        self.exported = True
        return True


class FakeSelection:
    def __init__(self, width, height, *, empty_pixels=None):
        self._width = width
        self._height = height
        self._empty_pixels = set(empty_pixels or [])

    def x(self):
        return 10

    def y(self):
        return 20

    def width(self):
        return self._width

    def height(self):
        return self._height

    def pixelData(self, x, y, width, height):
        values = []
        for row in range(y, y + height):
            for column in range(x, x + width):
                values.append(0 if (column, row) in self._empty_pixels else 255)
        return bytes(values)


class FakeQByteArrayLike:
    def __init__(self, data):
        self._data = bytes(data)

    def __bytes__(self):
        return self._data

    def __getitem__(self, index):
        if isinstance(index, slice):
            return self._data[index]
        return self._data[index : index + 1]


class FakeSelectionWithQByteArrayLikePixel(FakeSelection):
    def pixelData(self, x, y, width, height):
        return FakeQByteArrayLike(super().pixelData(x, y, width, height))


class FakeMutableSelection:
    def __init__(self, rect=None):
        self.rect = rect or {"x": 0, "y": 0, "w": 0, "h": 0}

    def select(self, x, y, width, height, opacity):
        if opacity != 255:
            raise AssertionError("focused selection must be fully opaque")
        self.rect = {"x": x, "y": y, "w": width, "h": height}

    def x(self):
        return self.rect["x"]

    def y(self):
        return self.rect["y"]

    def width(self):
        return self.rect["w"]

    def height(self):
        return self.rect["h"]

    def pixelData(self, _x, _y, width, height):
        return bytes([255]) * (width * height)


class FakeSelectionDoc:
    def __init__(self, selection):
        self._selection = selection

    def selection(self):
        return self._selection


class FakeSelectionReplaceDoc(FakeSizedDoc):
    def __init__(self, width, height, selection):
        super().__init__(width, height)
        self._selection = selection
        self.set_selection_calls = []
        self.refresh_count = 0

    def selection(self):
        return self._selection

    def setSelection(self, selection):
        self._selection = selection
        self.set_selection_calls.append(selection.rect.copy())

    def refreshProjection(self):
        self.refresh_count += 1


class FakeOpenedDocument:
    def __init__(self):
        self.file_name = None
        self.name_value = None

    def setFileName(self, value):
        self.file_name = value

    def setName(self, value):
        self.name_value = value


class FakeWindow:
    def __init__(self):
        self.views = []

    def addView(self, doc):
        self.views.append(doc)


class FakeKritaApp:
    def __init__(self):
        self.window = FakeWindow()
        self.opened_paths = []
        self.opened_bytes = []
        self.opened_docs = []

    def openDocument(self, path):
        self.opened_paths.append(path)
        self.opened_bytes.append(Path(path).read_bytes())
        doc = FakeOpenedDocument()
        self.opened_docs.append(doc)
        return doc

    def activeWindow(self):
        return self.window


class FakeImageBits:
    def __init__(self, data):
        self._data = bytes(data)

    def setsize(self, _size):
        pass

    def asstring(self, _size):
        return self._data


class FakeLayer:
    def __init__(self, name):
        self._name = name
        self.pixel_data_calls = []

    def name(self):
        return self._name

    def setPixelData(self, value, x, y, width, height):
        self.pixel_data_calls.append((bytes(value), x, y, width, height))


class FakeLayerRoot:
    def __init__(self, *, accepts_child=True):
        self.accepts_child = accepts_child
        self.added = []

    def addChildNode(self, layer, above):
        if self.accepts_child:
            self.added.append((layer, above))
        return self.accepts_child

    def childNodes(self):
        return [layer for layer, _above in self.added]

    def removeChildNode(self, node):
        self.added = [
            (layer, above) for layer, above in self.added if layer is not node
        ]


class FakeLayerDoc(FakeSizedDoc):
    def __init__(self, width, height, *, accepts_child=True):
        super().__init__(width, height)
        self.root = FakeLayerRoot(accepts_child=accepts_child)
        self.layers = []
        self.refresh_count = 0
        self.wait_count = 0

    def rootNode(self):
        return self.root

    def createNode(self, name, _node_type):
        layer = FakeLayer(name)
        self.layers.append(layer)
        return layer

    def refreshProjection(self):
        self.refresh_count += 1

    def waitForDone(self):
        self.wait_count += 1


class FakeLoadedQImage:
    Format_RGBA8888 = 2

    def __init__(self):
        self._width = 64
        self._height = 64
        self._data = bytes([1, 2, 3, 4] * self._width * self._height)

    def loadFromData(self, _data, fmt):
        return fmt == "PNG"

    def convertToFormat(self, _fmt):
        return self

    def width(self):
        return self._width

    def height(self):
        return self._height

    def sizeInBytes(self):
        return len(self._data)

    def bits(self):
        return FakeImageBits(self._data)


class FakeGrayImage:
    Format_Grayscale8 = 1
    PNG_HEADER = b"fake-gray8-png"

    def __init__(self, *args):
        if len(args) == 3:
            width, height, fmt = args
            self._pixels = bytearray(width * height)
        else:
            data, width, height, bytes_per_line, fmt = args
            if bytes_per_line < width:
                raise AssertionError("scanline shorter than image width")
            if len(data) < bytes_per_line * (height - 1) + width:
                raise AssertionError("QImage would read past the pixel buffer")
            self._pixels = bytearray(
                b"".join(
                    bytes(data[row * bytes_per_line : row * bytes_per_line + width])
                    for row in range(height)
                )
            )
        if fmt != FakeGrayImage.Format_Grayscale8:
            raise AssertionError("selection masks must be Grayscale8")
        self._width = width
        self._height = height

    def setPixel(self, _x, _y, _rgb):
        raise AssertionError(
            "Grayscale8 setPixel converts through QRgb and differs across Qt builds"
        )

    def copy(self, x, y, width, height):
        result = FakeGrayImage(width, height, FakeGrayImage.Format_Grayscale8)
        for row in range(height):
            source_y = y + row
            if not 0 <= source_y < self._height:
                continue
            for column in range(width):
                source_x = x + column
                if 0 <= source_x < self._width:
                    result._pixels[row * width + column] = self._pixels[
                        source_y * self._width + source_x
                    ]
        return result

    def save(self, buffer, fmt):
        if fmt != "PNG":
            return False
        buffer._data = (
            FakeGrayImage.PNG_HEADER
            + self._width.to_bytes(4, "big")
            + self._height.to_bytes(4, "big")
            + bytes(self._pixels)
        )
        return True


def _fake_png_pixels(png):
    header = FakeGrayImage.PNG_HEADER
    if not png.startswith(header):
        raise AssertionError("not a fake Grayscale8 PNG")
    width = int.from_bytes(png[len(header) : len(header) + 4], "big")
    height = int.from_bytes(png[len(header) + 4 : len(header) + 8], "big")
    return width, height, png[len(header) + 8 :]


class FakeCoverageSelection:
    def __init__(self, x, y, width, height, coverage, *, short_by=0):
        self._x = x
        self._y = y
        self._width = width
        self._height = height
        self._coverage = bytes(coverage)
        self._short_by = short_by
        self.pixel_data_calls = []

    def x(self):
        return self._x

    def y(self):
        return self._y

    def width(self):
        return self._width

    def height(self):
        return self._height

    def value_at(self, x, y):
        column = x - self._x
        row = y - self._y
        if 0 <= column < self._width and 0 <= row < self._height:
            return self._coverage[row * self._width + column]
        return 0

    def pixelData(self, x, y, width, height):
        self.pixel_data_calls.append((x, y, width, height))
        values = bytes(
            self.value_at(column, row)
            for row in range(y, y + height)
            for column in range(x, x + width)
        )
        return values[: max(0, len(values) - self._short_by)]


class FakeMaskDoc(FakeSizedDoc):
    def __init__(self, width, height, selection):
        super().__init__(width, height)
        self._selection = selection

    def selection(self):
        return self._selection


def _canvas_io_line_events(function, *args):
    events = 0
    source = canvas_io.__file__

    def tracer(frame, event, _arg):
        nonlocal events
        if event == "line" and frame.f_code.co_filename == source:
            events += 1
        return tracer

    previous = sys.gettrace()
    sys.settrace(tracer)
    try:
        function(*args)
    finally:
        sys.settrace(previous)
    return events


def _bgra_canvas(width, height, colored, color):
    raw = bytearray(width * height * 4)
    for x, y in colored:
        offset = (y * width + x) * 4
        raw[offset : offset + 4] = bytes(color)
    return raw


def _gray_canvas(width, height, selected):
    pixels = bytearray(width * height)
    for x, y in selected:
        pixels[y * width + x] = 255
    return bytes(pixels)


class CanvasIOMaskTests(unittest.TestCase):
    def test_has_active_document_returns_false_without_document(self):
        self.assertFalse(canvas_io.has_active_document())

    def test_export_inpaint_mask_routes_selection_source(self):
        original = canvas_io.export_active_selection_mask_png
        try:
            canvas_io.export_active_selection_mask_png = lambda: b"selection"

            self.assertEqual(canvas_io.export_inpaint_mask_png(), b"selection")
            self.assertEqual(
                canvas_io.export_inpaint_mask_png(canvas_io.MASK_SOURCE_SELECTION),
                b"selection",
            )
        finally:
            canvas_io.export_active_selection_mask_png = original

    def test_export_inpaint_mask_rejects_non_selection_source(self):
        with self.assertRaisesRegex(RuntimeError, "Unknown inpaint mask source"):
            canvas_io.export_inpaint_mask_png("mask_layer")

    def test_v1_canvas_validation_accepts_supported_bounds(self):
        canvas_io._validate_v1_canvas(FakeSizedDoc(64, 64))
        canvas_io._validate_v1_canvas(FakeSizedDoc(4096, 4096))

    def test_v1_canvas_validation_rejects_small_or_large_documents(self):
        with self.assertRaisesRegex(RuntimeError, "too small"):
            canvas_io._validate_v1_canvas(FakeSizedDoc(63, 64))

        with self.assertRaisesRegex(RuntimeError, "too large"):
            canvas_io._validate_v1_canvas(FakeSizedDoc(4097, 4096))

    def test_export_active_document_png_prefers_visible_projection(self):
        original_doc = canvas_io.active_document
        original_buffer = canvas_io.QBuffer
        try:
            doc = FakeExportDoc(128, 128)
            canvas_io.active_document = lambda: doc
            canvas_io.QBuffer = FakeProjectionBuffer

            self.assertEqual(canvas_io.export_active_document_png(), b"projection-png")
            self.assertFalse(doc.exported)
        finally:
            canvas_io.active_document = original_doc
            canvas_io.QBuffer = original_buffer

    def test_export_active_document_png_falls_back_to_temp_export(self):
        original_doc = canvas_io.active_document
        original_buffer = canvas_io.QBuffer
        try:
            doc = FakeExportDoc(128, 128, projection_succeeds=False)
            canvas_io.active_document = lambda: doc
            canvas_io.QBuffer = FakeProjectionBuffer

            self.assertEqual(canvas_io.export_active_document_png(), b"temp-export-png")
            self.assertTrue(doc.exported)
        finally:
            canvas_io.active_document = original_doc
            canvas_io.QBuffer = original_buffer

    def test_active_selection_rect_accepts_filled_rectangle(self):
        original = canvas_io.active_document
        try:
            canvas_io.active_document = lambda: FakeSelectionDoc(FakeSelection(4, 3))

            self.assertEqual(
                canvas_io.active_selection_rect(),
                {"x": 10, "y": 20, "w": 4, "h": 3},
            )
        finally:
            canvas_io.active_document = original

    def test_active_selection_rect_rejects_non_rectangular_selection(self):
        original = canvas_io.active_document
        try:
            canvas_io.active_document = lambda: FakeSelectionDoc(
                FakeSelection(4, 3, empty_pixels={(12, 21)})
            )

            self.assertIsNone(canvas_io.active_selection_rect())
        finally:
            canvas_io.active_document = original

    def test_active_selection_bounds_accepts_non_rectangular_selection_bounds(self):
        original = canvas_io.active_document
        try:
            canvas_io.active_document = lambda: FakeSelectionDoc(
                FakeSelection(4, 3, empty_pixels={(12, 21)})
            )

            self.assertEqual(
                canvas_io.active_selection_bounds(),
                {"x": 10, "y": 20, "w": 4, "h": 3},
            )
        finally:
            canvas_io.active_document = original

    def test_focus_context_rect_expands_selection_by_minimum_context(self):
        self.assertEqual(
            canvas_io.focus_context_rect_for_selection(
                {"x": 50, "y": 60, "w": 20, "h": 30},
                200,
                180,
                16,
            ),
            {"x": 34, "y": 44, "w": 52, "h": 62},
        )

    def test_focus_context_rect_enforces_minimum_context(self):
        self.assertEqual(
            canvas_io.focus_context_rect_for_selection(
                {"x": 50, "y": 60, "w": 20, "h": 30},
                200,
                180,
                0,
            ),
            {"x": 34, "y": 44, "w": 52, "h": 62},
        )

    def test_focus_context_rect_matches_launcher_focused_crop_golden_case(self):
        self.assertEqual(
            canvas_io.focus_context_rect_for_selection(
                {"x": 420, "y": 180, "w": 120, "h": 96},
                1200,
                800,
                88,
            ),
            {"x": 332, "y": 92, "w": 296, "h": 272},
        )

    def test_focus_context_rect_clamps_to_canvas_edges(self):
        self.assertEqual(
            canvas_io.focus_context_rect_for_selection(
                {"x": 5, "y": 6, "w": 20, "h": 30},
                100,
                90,
                32,
            ),
            {"x": 0, "y": 0, "w": 84, "h": 90},
        )

    def test_focus_request_size_upscales_small_crop_to_one_megapixel(self):
        self.assertEqual(
            canvas_io.focus_request_size_for_context(
                {"x": 0, "y": 0, "w": 512, "h": 512}
            ),
            {"w": 1024, "h": 1024, "mode": "upscale_to_target"},
        )

    def test_focus_request_size_preserves_paid_crop_and_floors_to_grid(self):
        self.assertEqual(
            canvas_io.focus_request_size_for_context(
                {"x": 0, "y": 0, "w": 1300, "h": 1000}
            ),
            {"w": 1280, "h": 960, "mode": "preserve_crop"},
        )

    def test_focus_request_size_accepts_side_longer_than_2048(self):
        self.assertEqual(
            canvas_io.focus_request_size_for_context(
                {"x": 0, "y": 0, "w": 3072, "h": 1024}
            ),
            {"w": 3072, "h": 1024, "mode": "preserve_crop"},
        )

    def test_focus_selection_constraint_keeps_exact_total_area_boundary(self):
        selection = {"x": 0, "y": 0, "w": 2048, "h": 1536}

        self.assertEqual(
            canvas_io.constrain_focus_selection_rect(
                selection, 2048, 1536, 88
            ),
            selection,
        )

    def test_focus_selection_constraint_shrinks_outer_rect_above_limit(self):
        constrained = canvas_io.constrain_focus_selection_rect(
            {"x": 0, "y": 0, "w": 2400, "h": 1600},
            2400,
            1600,
            88,
        )
        context = canvas_io.focus_context_rect_for_selection(
            constrained, 2400, 1600, 88
        )

        self.assertLessEqual(
            context["w"] * context["h"],
            canvas_io.FOCUS_MAX_REQUEST_AREA_PIXELS,
        )
        self.assertLess(constrained["w"], 2400)
        self.assertLess(constrained["h"], 1600)

    def test_active_focus_constraint_replaces_native_selection_once(self):
        original_doc = canvas_io.active_document
        original_factory = canvas_io._create_krita_selection
        try:
            doc = FakeSelectionReplaceDoc(
                2400,
                1600,
                FakeMutableSelection({"x": 0, "y": 0, "w": 2400, "h": 1600}),
            )
            canvas_io.active_document = lambda: doc
            canvas_io._create_krita_selection = FakeMutableSelection

            constrained = canvas_io.constrain_active_focus_selection(88)
            second = canvas_io.constrain_active_focus_selection(88)

            self.assertEqual(len(doc.set_selection_calls), 1)
            self.assertEqual(doc.refresh_count, 1)
            self.assertEqual(constrained, second)
            context = canvas_io.focus_context_rect_for_selection(
                constrained, doc.width(), doc.height(), 88
            )
            self.assertLessEqual(
                context["w"] * context["h"],
                canvas_io.FOCUS_MAX_REQUEST_AREA_PIXELS,
            )
        finally:
            canvas_io.active_document = original_doc
            canvas_io._create_krita_selection = original_factory

    def test_rgba8888_to_krita_bgra_preserves_alpha_and_swaps_color_channels(self):
        self.assertEqual(
            canvas_io._rgba8888_to_krita_bgra(
                bytes([1, 2, 3, 4, 10, 20, 30, 0])
            ),
            bytes([3, 2, 1, 4, 30, 20, 10, 0]),
        )

    def test_write_png_as_layer_reports_failure_when_krita_rejects_new_layer(self):
        original_doc = canvas_io.active_document
        original_qimage = canvas_io.QImage
        try:
            doc = FakeLayerDoc(64, 64, accepts_child=False)
            canvas_io.active_document = lambda: doc
            canvas_io.QImage = FakeLoadedQImage

            self.assertFalse(canvas_io._write_png_as_layer(b"png", "NAI Preview"))
            self.assertEqual(doc.refresh_count, 0)
        finally:
            canvas_io.active_document = original_doc
            canvas_io.QImage = original_qimage

    def test_write_png_preview_waits_for_krita_after_replacing_existing_layer(self):
        original_doc = canvas_io.active_document
        original_qimage = canvas_io.QImage
        try:
            doc = FakeLayerDoc(64, 64)
            doc.root.added.append((FakeLayer(canvas_io.PREVIEW_LAYER_NAME), None))
            canvas_io.active_document = lambda: doc
            canvas_io.QImage = FakeLoadedQImage

            canvas_io.write_png_preview(b"png")

            self.assertGreaterEqual(doc.wait_count, 1)
            self.assertEqual(doc.refresh_count, 1)
            self.assertEqual(len(doc.root.added), 1)
            self.assertEqual(doc.root.added[0][0].name(), canvas_io.PREVIEW_LAYER_NAME)
        finally:
            canvas_io.active_document = original_doc
            canvas_io.QImage = original_qimage

    def test_write_png_preview_raises_when_preview_layer_cannot_be_added(self):
        original_write_layer = canvas_io._write_png_as_layer
        try:
            canvas_io._write_png_as_layer = lambda *_args, **_kwargs: False

            with self.assertRaisesRegex(RuntimeError, "failed to add preview"):
                canvas_io.write_png_preview(b"preview")
        finally:
            canvas_io._write_png_as_layer = original_write_layer

    def test_write_focus_preview_reports_failure_when_krita_rejects_new_layer(self):
        doc = FakeLayerDoc(8, 8, accepts_child=False)

        with self.assertRaisesRegex(RuntimeError, "failed to add"):
            canvas_io._write_rect_outline_layer(
                doc,
                inner_rect={"x": 2, "y": 2, "w": 3, "h": 3},
                outer_rect={"x": 1, "y": 1, "w": 5, "h": 5},
                name=canvas_io.FOCUS_PREVIEW_LAYER_NAME,
            )

        self.assertEqual(doc.refresh_count, 0)

    def test_write_png_result_prefers_layer_write_when_dimensions_match(self):
        original_write_layer = canvas_io._write_png_as_layer
        original_krita = canvas_io.Krita
        calls = []
        fake_app = FakeKritaApp()
        try:
            canvas_io._write_png_as_layer = lambda image, name: calls.append(
                (image, name)
            ) or True
            canvas_io.Krita = types.SimpleNamespace(instance=lambda: fake_app)

            result = canvas_io.write_png_as_new_document(b"result-png", "NAI Result")

            self.assertEqual(result, "layer")
            self.assertEqual(calls, [(b"result-png", "NAI Result")])
            self.assertEqual(fake_app.opened_paths, [])
            self.assertEqual(fake_app.window.views, [])
        finally:
            canvas_io._write_png_as_layer = original_write_layer
            canvas_io.Krita = original_krita

    def test_write_png_result_falls_back_to_new_document_when_layer_write_fails(self):
        original_write_layer = canvas_io._write_png_as_layer
        original_krita = canvas_io.Krita
        fake_app = FakeKritaApp()
        try:
            canvas_io._write_png_as_layer = lambda _image, _name: False
            canvas_io.Krita = types.SimpleNamespace(instance=lambda: fake_app)

            result = canvas_io.write_png_as_new_document(b"result-png", "NAI Result")

            self.assertEqual(result, "document")
            self.assertEqual(fake_app.opened_bytes, [b"result-png"])
            self.assertEqual(fake_app.opened_docs, fake_app.window.views)
            self.assertEqual(fake_app.opened_docs[0].file_name, "")
            self.assertEqual(fake_app.opened_docs[0].name_value, "NAI Result")
            self.assertFalse(Path(fake_app.opened_paths[0]).exists())
        finally:
            canvas_io._write_png_as_layer = original_write_layer
            canvas_io.Krita = original_krita


class CanvasIOPixelBufferTests(unittest.TestCase):
    def test_rgba8888_to_krita_bgra_swaps_large_buffers_and_returns_bytes(self):
        pixel_count = 4097
        raw = bytearray(bytes([1, 2, 3, 4]) * pixel_count)

        converted = canvas_io._rgba8888_to_krita_bgra(raw)

        self.assertIs(type(converted), bytes)
        self.assertEqual(converted, bytes([3, 2, 1, 4]) * pixel_count)
        self.assertEqual(canvas_io._rgba8888_to_krita_bgra(b""), b"")

    def test_rgba8888_to_krita_bgra_rejects_partial_pixels(self):
        for length in (1, 2, 3, 5, 4099):
            with self.subTest(length=length):
                with self.assertRaises(IndexError):
                    canvas_io._rgba8888_to_krita_bgra(bytes(length))

    def test_rgba8888_to_krita_bgra_python_work_does_not_grow_with_pixels(self):
        self.assertEqual(
            _canvas_io_line_events(canvas_io._rgba8888_to_krita_bgra, bytes(4)),
            _canvas_io_line_events(
                canvas_io._rgba8888_to_krita_bgra, bytes(256 * 256 * 4)
            ),
        )

    def test_rect_outline_draws_clamped_borders(self):
        color = (9, 8, 7, 6)
        border_5x4 = {(x, y) for x in range(5) for y in (0, 3)} | {
            (x, y) for x in (0, 4) for y in range(4)
        }
        thick_7x6 = {
            (x, y)
            for x in range(7)
            for y in range(6)
            if not (2 <= x <= 4 and 2 <= y <= 3)
        }
        cases = [
            ("canvas-sized rect", (5, 4), (0, 0, 5, 4), 1, border_5x4),
            ("overhang clamps to canvas", (5, 4), (-2, -1, 20, 20), 0, border_5x4),
            ("thickness keeps the interior", (7, 6), (0, 0, 7, 6), 2, thick_7x6),
            ("empty rect marks its origin", (7, 6), (2, 1, 0, 0), 3, {(2, 1)}),
        ]
        for name, (width, height), (x, y, w, h), thickness, colored in cases:
            with self.subTest(name):
                rect = {"x": x, "y": y, "w": w, "h": h}
                raw = bytearray(width * height * 4)

                canvas_io._draw_rect_outline_bgra(
                    raw, width, height, rect, color, thickness=thickness
                )

                self.assertEqual(raw, _bgra_canvas(width, height, colored, color))

    def test_rect_outline_layer_writes_both_outlines_in_one_call(self):
        doc = FakeLayerDoc(40, 30)
        inner_rect = {"x": 12, "y": 9, "w": 10, "h": 7}
        outer_rect = {"x": 4, "y": 2, "w": 30, "h": 22}
        expected = bytearray(40 * 30 * 4)
        canvas_io._draw_rect_outline_bgra(
            expected, 40, 30, outer_rect, (255, 190, 0, 210), thickness=2
        )
        canvas_io._draw_rect_outline_bgra(
            expected, 40, 30, inner_rect, (255, 255, 255, 235), thickness=2
        )

        canvas_io._write_rect_outline_layer(
            doc,
            inner_rect=inner_rect,
            outer_rect=outer_rect,
            name=canvas_io.FOCUS_PREVIEW_LAYER_NAME,
        )

        self.assertEqual(
            doc.layers[0].pixel_data_calls,
            [(bytes(expected), 0, 0, 40, 30)],
        )

    def test_rect_outline_python_work_does_not_grow_with_rect_size(self):
        raw = bytearray(256 * 256 * 4)

        def draw(size):
            canvas_io._draw_rect_outline_bgra(
                raw,
                256,
                256,
                {"x": 8, "y": 8, "w": size, "h": size},
                (1, 2, 3, 4),
                thickness=2,
            )

        self.assertEqual(
            _canvas_io_line_events(draw, 8), _canvas_io_line_events(draw, 240)
        )

    def test_selection_bounds_filled_requires_every_pixel(self):
        filled = bytes(range(1, 64))
        cases = {
            "every pixel selected": (filled, 0, True),
            "first pixel blank": (b"\x00" + filled[1:], 0, False),
            "last pixel blank": (filled[:-1] + b"\x00", 0, False),
            "middle pixel blank": (filled[:30] + b"\x00" + filled[31:], 0, False),
            "truncated pixel data": (filled, 1, False),
            "no pixel data": (filled, len(filled), False),
        }
        for name, (coverage, short_by, expected) in cases.items():
            with self.subTest(name):
                selection = FakeCoverageSelection(
                    0, 0, 9, 7, coverage, short_by=short_by
                )

                self.assertIs(
                    canvas_io._selection_bounds_are_filled(selection, 9, 7),
                    expected,
                )


class CanvasIOSelectionMaskTests(unittest.TestCase):
    def setUp(self):
        self._original_doc = canvas_io.active_document
        self._original_qimage = canvas_io.QImage
        self._original_buffer = canvas_io.QBuffer
        canvas_io.QImage = FakeGrayImage
        canvas_io.QBuffer = FakeProjectionBuffer

    def tearDown(self):
        canvas_io.active_document = self._original_doc
        canvas_io.QImage = self._original_qimage
        canvas_io.QBuffer = self._original_buffer

    def _export(self, doc):
        canvas_io.active_document = lambda: doc
        return canvas_io.export_active_selection_mask_png()

    def test_mask_clips_selections_to_the_canvas(self):
        cases = [
            (
                "overhangs every edge",
                64,
                64,
                (-7, -9, 80, 81),
                b"\xff" * (80 * 81),
                {(x, y) for x in range(64) for y in range(64)},
            ),
            (
                "starts left of the canvas",
                64,
                64,
                (-30, 10, 32, 2),
                b"\xff" * 64,
                {(x, y) for x in (0, 1) for y in (10, 11)},
            ),
            (
                "ends below the canvas",
                64,
                64,
                (10, 62, 3, 5),
                b"\xff" * 15,
                {(x, y) for x in (10, 11, 12) for y in (62, 63)},
            ),
            (
                "odd canvas stride",
                67,
                65,
                (5, 3, 3, 1),
                bytes([7, 0, 200]),
                {(5, 3), (7, 3)},
            ),
        ]
        for name, canvas_width, canvas_height, rect, coverage, selected in cases:
            with self.subTest(name):
                doc = FakeMaskDoc(
                    canvas_width,
                    canvas_height,
                    FakeCoverageSelection(*rect, coverage),
                )

                width, height, pixels = _fake_png_pixels(self._export(doc))

                self.assertEqual((width, height), (canvas_width, canvas_height))
                self.assertEqual(
                    pixels, _gray_canvas(canvas_width, canvas_height, selected)
                )

    def test_mask_marks_non_binary_selection_values_as_repaint(self):
        coverage = bytes([0, 1, 2, 127, 128, 254, 255, 0])
        doc = FakeMaskDoc(64, 64, FakeCoverageSelection(3, 4, 4, 2, coverage))

        width, height, pixels = _fake_png_pixels(self._export(doc))

        self.assertEqual((width, height), (64, 64))
        row_4 = pixels[4 * 64 + 3 : 4 * 64 + 7]
        row_5 = pixels[5 * 64 + 3 : 5 * 64 + 7]
        self.assertEqual(row_4, bytes([0, 255, 255, 255]))
        self.assertEqual(row_5, bytes([255, 255, 255, 0]))
        self.assertEqual(pixels.count(0), 64 * 64 - 6)

    def test_mask_writes_255_for_every_selected_value_without_qrgb_setpixel(self):
        doc = FakeMaskDoc(64, 64, FakeCoverageSelection(0, 0, 16, 16, bytes(range(256))))

        _width, _height, pixels = _fake_png_pixels(self._export(doc))

        selection_rows = b"".join(pixels[row * 64 : row * 64 + 16] for row in range(16))
        self.assertEqual(selection_rows, b"\x00" + b"\xff" * 255)
        self.assertEqual(set(pixels), {0, 255})
        self.assertEqual(pixels.count(255), 255)

    def test_mask_selection_outside_canvas_exports_blank_mask(self):
        doc = FakeMaskDoc(
            64, 64, FakeCoverageSelection(80, 90, 10, 10, b"\xff" * 100)
        )

        _width, _height, pixels = _fake_png_pixels(self._export(doc))

        self.assertEqual(pixels, bytes(64 * 64))

    def test_mask_rejects_missing_or_zero_sized_selection(self):
        for selection in (
            None,
            FakeCoverageSelection(1, 1, 0, 5, b""),
            FakeCoverageSelection(1, 1, 5, 0, b""),
        ):
            with self.subTest(selection=selection):
                doc = FakeMaskDoc(64, 64, selection)
                with self.assertRaisesRegex(
                    RuntimeError, "Create a Krita selection before inpaint"
                ):
                    self._export(doc)

    def test_mask_reports_empty_when_selection_pixels_are_blank(self):
        blank = FakeCoverageSelection(2, 3, 5, 4, bytes(20))
        unreadable = FakeCoverageSelection(2, 3, 5, 4, b"\xff" * 20, short_by=20)
        for selection in (blank, unreadable):
            with self.subTest(short_by=selection._short_by):
                doc = FakeMaskDoc(64, 64, selection)
                with self.assertRaisesRegex(RuntimeError, "Inpaint mask is empty"):
                    self._export(doc)

    def test_mask_treats_truncated_pixel_data_as_unselected(self):
        selection = FakeCoverageSelection(2, 3, 5, 4, b"\xff" * 20, short_by=7)

        _width, _height, pixels = _fake_png_pixels(
            self._export(FakeMaskDoc(64, 64, selection))
        )

        self.assertEqual(pixels.count(255), 13)
        self.assertEqual(pixels[6 * 64 + 2 : 6 * 64 + 7], bytes(5))

    def test_mask_reads_selection_pixels_in_one_call(self):
        selection = FakeCoverageSelection(-3, 7, 40, 30, b"\x80" * 1200)

        self._export(FakeMaskDoc(64, 64, selection))

        self.assertEqual(selection.pixel_data_calls, [(-3, 7, 40, 30)])

    def test_mask_accepts_qbytearray_like_pixel_data(self):
        selection = FakeSelectionWithQByteArrayLikePixel(
            4, 3, empty_pixels={(12, 21)}
        )

        _width, _height, pixels = _fake_png_pixels(
            self._export(FakeMaskDoc(64, 64, selection))
        )

        self.assertEqual(pixels[20 * 64 + 10 : 20 * 64 + 14], b"\xff" * 4)
        self.assertEqual(pixels[21 * 64 + 10 : 21 * 64 + 14], b"\xff\xff\x00\xff")
        self.assertEqual(pixels.count(255), 11)

    def test_mask_python_work_does_not_grow_with_selection_area(self):
        small = FakeMaskDoc(64, 64, FakeCoverageSelection(5, 5, 1, 1, b"\xff"))
        large = FakeMaskDoc(
            256, 256, FakeCoverageSelection(-8, -8, 272, 272, b"\x40" * (272 * 272))
        )

        self.assertEqual(
            _canvas_io_line_events(self._export, small),
            _canvas_io_line_events(self._export, large),
        )


if __name__ == "__main__":
    unittest.main()
