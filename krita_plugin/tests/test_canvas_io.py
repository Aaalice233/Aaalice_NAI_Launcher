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


if __name__ == "__main__":
    unittest.main()
