import importlib.util
import random
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


class FakeRawSelection:
    def __init__(self, data):
        self._data = data

    def x(self):
        return 0

    def y(self):
        return 0

    def pixelData(self, _x, _y, _width, _height):
        return self._data


def _per_pixel_rgba8888_to_krita_bgra(raw):
    converted = bytearray(len(raw))
    for offset in range(0, len(raw), 4):
        red = raw[offset]
        green = raw[offset + 1]
        blue = raw[offset + 2]
        alpha = raw[offset + 3]
        converted[offset] = blue
        converted[offset + 1] = green
        converted[offset + 2] = red
        converted[offset + 3] = alpha
    return bytes(converted)


def _per_pixel_draw_rect_outline_bgra(
    raw, canvas_width, canvas_height, rect, color, *, thickness
):
    def set_pixel(x, y):
        offset = (y * canvas_width + x) * 4
        raw[offset : offset + 4] = bytes(color)

    x = max(0, min(canvas_width - 1, int(rect["x"])))
    y = max(0, min(canvas_height - 1, int(rect["y"])))
    right = max(x, min(canvas_width - 1, x + int(rect["w"]) - 1))
    bottom = max(y, min(canvas_height - 1, y + int(rect["h"]) - 1))
    for offset in range(max(1, thickness)):
        top_y = y + offset
        bottom_y = bottom - offset
        left_x = x + offset
        right_x = right - offset
        if top_y <= bottom:
            for px in range(left_x, right_x + 1):
                set_pixel(px, top_y)
        if bottom_y >= y:
            for px in range(left_x, right_x + 1):
                set_pixel(px, bottom_y)
        if left_x <= right:
            for py in range(top_y, bottom_y + 1):
                set_pixel(left_x, py)
        if right_x >= x:
            for py in range(top_y, bottom_y + 1):
                set_pixel(right_x, py)


def _per_pixel_selection_is_filled(raw, required):
    return len(raw) >= required and all(value > 0 for value in raw[:required])


def _python_line_events(function, *args, **kwargs):
    events = 0

    def tracer(_frame, event, _arg):
        nonlocal events
        if event == "line":
            events += 1
        return tracer

    previous = sys.gettrace()
    sys.settrace(tracer)
    try:
        function(*args, **kwargs)
    finally:
        sys.settrace(previous)
    return events


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

    def test_selection_pixel_value_accepts_qbytearray_like_indexing(self):
        selection = FakeSelectionWithQByteArrayLikePixel(1, 1)

        self.assertEqual(canvas_io._selection_pixel_value(selection, 10, 20), 255)

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
    def test_rgba8888_to_krita_bgra_matches_per_pixel_swap_on_random_pixels(self):
        rng = random.Random(20260930)
        for pixel_count in (0, 1, 2, 3, 63, 64, 65, 4095, 4096, 4097, 65 * 63):
            raw = rng.randbytes(pixel_count * 4)
            with self.subTest(pixel_count=pixel_count):
                self.assertEqual(
                    canvas_io._rgba8888_to_krita_bgra(raw),
                    _per_pixel_rgba8888_to_krita_bgra(raw),
                )

    def test_rgba8888_to_krita_bgra_matches_per_pixel_swap_for_uniform_alpha(self):
        rng = random.Random(4096)
        pixel_count = 64 * 64
        for alpha in (0, 255):
            raw = bytearray(rng.randbytes(pixel_count * 4))
            raw[3::4] = bytes([alpha]) * pixel_count
            with self.subTest(alpha=alpha):
                converted = canvas_io._rgba8888_to_krita_bgra(bytes(raw))
                self.assertEqual(converted, _per_pixel_rgba8888_to_krita_bgra(raw))
                self.assertEqual(converted[3::4], bytes([alpha]) * pixel_count)

    def test_rgba8888_to_krita_bgra_accepts_bytearray_and_returns_bytes(self):
        raw = bytearray(random.Random(7).randbytes(16 * 4))

        converted = canvas_io._rgba8888_to_krita_bgra(raw)

        self.assertIs(type(converted), bytes)
        self.assertEqual(converted, _per_pixel_rgba8888_to_krita_bgra(raw))

    def test_rgba8888_to_krita_bgra_rejects_partial_pixel_like_per_pixel_swap(self):
        for length in (1, 2, 3, 5, 6, 7, 4097, 4098, 4099):
            raw = bytes(index % 256 for index in range(length))
            with self.subTest(length=length):
                with self.assertRaises(IndexError):
                    _per_pixel_rgba8888_to_krita_bgra(raw)
                with self.assertRaises(IndexError):
                    canvas_io._rgba8888_to_krita_bgra(raw)

    def test_rgba8888_to_krita_bgra_python_work_does_not_grow_with_pixels(self):
        small = bytes(4)
        large = bytes(256 * 256 * 4)

        self.assertEqual(
            _python_line_events(canvas_io._rgba8888_to_krita_bgra, small),
            _python_line_events(canvas_io._rgba8888_to_krita_bgra, large),
        )
        self.assertGreater(
            _python_line_events(_per_pixel_rgba8888_to_krita_bgra, bytes(64 * 4)),
            _python_line_events(_per_pixel_rgba8888_to_krita_bgra, small),
        )

    def test_rect_outline_matches_per_pixel_drawing(self):
        rng = random.Random(20260930)
        for canvas_width, canvas_height in (
            (1, 1),
            (1, 9),
            (9, 1),
            (7, 5),
            (16, 16),
            (33, 17),
        ):
            for _ in range(60):
                rect = {
                    "x": rng.randint(-5, canvas_width + 5),
                    "y": rng.randint(-5, canvas_height + 5),
                    "w": rng.randint(-3, canvas_width + 6),
                    "h": rng.randint(-3, canvas_height + 6),
                }
                thickness = rng.randint(0, 5)
                color = tuple(rng.randrange(256) for _ in range(4))
                background = rng.randbytes(canvas_width * canvas_height * 4)
                expected = bytearray(background)
                actual = bytearray(background)
                _per_pixel_draw_rect_outline_bgra(
                    expected,
                    canvas_width,
                    canvas_height,
                    rect,
                    color,
                    thickness=thickness,
                )
                canvas_io._draw_rect_outline_bgra(
                    actual,
                    canvas_width,
                    canvas_height,
                    rect,
                    color,
                    thickness=thickness,
                )
                with self.subTest(
                    canvas=(canvas_width, canvas_height),
                    rect=rect,
                    thickness=thickness,
                ):
                    self.assertEqual(actual, expected)

    def test_rect_outline_layer_matches_per_pixel_drawing(self):
        doc = FakeLayerDoc(40, 30)
        inner_rect = {"x": 12, "y": 9, "w": 10, "h": 7}
        outer_rect = {"x": 4, "y": 2, "w": 30, "h": 22}
        expected = bytearray(40 * 30 * 4)
        _per_pixel_draw_rect_outline_bgra(
            expected, 40, 30, outer_rect, (255, 190, 0, 210), thickness=2
        )
        _per_pixel_draw_rect_outline_bgra(
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

        self.assertEqual(_python_line_events(draw, 8), _python_line_events(draw, 240))

    def test_selection_bounds_filled_matches_per_pixel_check(self):
        rng = random.Random(20260930)
        width = 9
        height = 7
        required = width * height
        filled = bytes(rng.randint(1, 255) for _ in range(required))
        cases = [
            filled,
            filled + b"\x00" * 5,
            b"\x00" + filled[1:],
            filled[:-1] + b"\x00",
            filled[:30] + b"\x00" + filled[31:],
            filled[:-1],
            b"",
        ]
        for data in cases:
            with self.subTest(data=data):
                self.assertEqual(
                    canvas_io._selection_bounds_are_filled(
                        FakeRawSelection(data), width, height
                    ),
                    _per_pixel_selection_is_filled(data, required),
                )

    def test_selection_bounds_filled_python_work_does_not_grow_with_area(self):
        small = FakeRawSelection(b"\xff")
        large = FakeRawSelection(b"\xff" * (256 * 256))

        self.assertEqual(
            _python_line_events(canvas_io._selection_bounds_are_filled, small, 1, 1),
            _python_line_events(
                canvas_io._selection_bounds_are_filled, large, 256, 256
            ),
        )


if __name__ == "__main__":
    unittest.main()
