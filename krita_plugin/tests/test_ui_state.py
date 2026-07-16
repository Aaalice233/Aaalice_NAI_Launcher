import base64
import importlib
import json
import sys
import types
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parents[1] / "nai_launcher_bridge"


class FakeSignal:
    def __init__(self):
        self._callbacks = []

    def connect(self, callback):
        self._callbacks.append(callback)

    def emit(self, *args):
        for callback in list(self._callbacks):
            callback(*args)


class FakeWidget:
    def __init__(self, *_args, **_kwargs):
        self._enabled = True
        self._visible = True
        self._text = ""
        self._style_sheet = ""
        self._tooltip = ""

    def setEnabled(self, enabled):
        self._enabled = bool(enabled)

    def setVisible(self, visible):
        self._visible = bool(visible)

    def setText(self, text):
        self._text = text

    def text(self):
        return self._text

    def setToolTip(self, text):
        self._tooltip = text

    def setStyleSheet(self, style_sheet):
        self._style_sheet = style_sheet

    def styleSheet(self):
        return self._style_sheet

    def setWordWrap(self, _enabled):
        pass

    def setWindowTitle(self, title):
        self._window_title = title

    def setWidget(self, widget):
        self._widget = widget

    def deleteLater(self):
        pass


class FakePixmap:
    def __init__(self):
        self._data = b""

    def loadFromData(self, data, *_args):
        self._data = bytes(data)
        return bool(data)


class FakeIcon:
    def __init__(self, pixmap=None):
        self.pixmap = pixmap


class FakeLayout:
    def __init__(self, *_args, **_kwargs):
        pass

    def addWidget(self, *_args):
        pass

    def addLayout(self, *_args):
        pass

    def addRow(self, *_args):
        pass


class FakeTextEdit(FakeWidget):
    def setMaximumHeight(self, _height):
        pass

    def setPlainText(self, text):
        self._text = text

    def toPlainText(self):
        return self._text


class FakeSpinBox(FakeWidget):
    def __init__(self, *_args, **_kwargs):
        super().__init__()
        self._value = 0
        self.valueChanged = FakeSignal()

    def setRange(self, *_args):
        pass

    def setSingleStep(self, *_args):
        pass

    def setDecimals(self, *_args):
        pass

    def setValue(self, value):
        self._value = value
        self.valueChanged.emit(value)

    def value(self):
        return self._value


class FakeSlider(FakeSpinBox):
    pass


class FakeCheckBox(FakeWidget):
    def __init__(self, *_args, **_kwargs):
        super().__init__()
        self._checked = False
        self.toggled = FakeSignal()

    def isChecked(self):
        return self._checked

    def setChecked(self, checked):
        self._checked = bool(checked)
        self.toggled.emit(self._checked)


class FakeComboBox(FakeWidget):
    def __init__(self, *_args, **_kwargs):
        super().__init__()
        self._items = []
        self._current_index = 0

    def addItem(self, label, data):
        self._items.append((label, data))

    def currentData(self):
        return self._items[self._current_index][1] if self._items else None

    def setCurrentIndex(self, index):
        self._current_index = index

    def findData(self, data):
        for index, (_label, item_data) in enumerate(self._items):
            if item_data == data:
                return index
        return -1


class FakeButton(FakeWidget):
    def __init__(self, text="", *_args, **_kwargs):
        super().__init__()
        self._text = text
        self.clicked = FakeSignal()


class FakeProgressBar(FakeWidget):
    def setRange(self, *_args):
        pass

    def setValue(self, value):
        self._value = value


class FakeListWidgetItem:
    def __init__(self, text=""):
        self._text = text
        self._icon = None
        self._tooltip = ""

    def text(self):
        return self._text

    def setIcon(self, icon):
        self._icon = icon

    def setToolTip(self, tooltip):
        self._tooltip = tooltip


class FakeListWidget(FakeWidget):
    IconMode = 1
    Adjust = 2
    Static = 3

    def __init__(self, *_args, **_kwargs):
        super().__init__()
        self._items = []
        self._current_item = None
        self.itemClicked = FakeSignal()
        self.itemDoubleClicked = FakeSignal()

    def addItem(self, item):
        self._items.append(item)

    def clear(self):
        self._items.clear()
        self._current_item = None

    def count(self):
        return len(self._items)

    def item(self, index):
        return self._items[index]

    def row(self, item):
        try:
            return self._items.index(item)
        except ValueError:
            return -1

    def takeItem(self, index):
        if index < 0 or index >= len(self._items):
            return None
        item = self._items.pop(index)
        if self._current_item is item:
            self._current_item = self._items[index] if index < len(self._items) else None
        return item

    def setCurrentItem(self, item):
        self._current_item = item

    def currentItem(self):
        return self._current_item

    def selectedItems(self):
        return [self._current_item] if self._current_item is not None else []

    def setViewMode(self, *_args):
        pass

    def setIconSize(self, *_args):
        pass

    def setResizeMode(self, *_args):
        pass

    def setMovement(self, *_args):
        pass

    def setSelectionMode(self, *_args):
        pass

    def setMaximumHeight(self, *_args):
        pass


class FakeTimer(FakeWidget):
    single_shots = []
    instances = []

    def __init__(self, *_args, **_kwargs):
        super().__init__()
        self.timeout = FakeSignal()
        self.interval = None
        self.single_shot = False
        self.started = False
        self.start_count = 0
        self.stop_count = 0
        FakeTimer.instances.append(self)

    def setInterval(self, value):
        self.interval = value

    def setSingleShot(self, value):
        self.single_shot = bool(value)

    def start(self, *_args):
        self.started = True
        self.start_count += 1

    def stop(self):
        self.started = False
        self.stop_count += 1

    @staticmethod
    def singleShot(msecs, callback):
        FakeTimer.single_shots.append((msecs, callback))

    @staticmethod
    def flush_single_shots():
        callbacks = list(FakeTimer.single_shots)
        FakeTimer.single_shots.clear()
        for _msecs, callback in callbacks:
            callback()


class FakeClient:
    def __init__(self, *_args, **_kwargs):
        self.connected_changed = FakeSignal()
        self.status_changed = FakeSignal()
        self.message_received = FakeSignal()
        self.is_connected = True
        self.sent = []

    def start(self):
        pass

    def connect_to_launcher(self):
        pass

    def send_text(self, text):
        self.sent.append(text)
        return True


class FakeCanvasIO:
    MASK_SOURCE_SELECTION = "selection"

    def __init__(self):
        self.removed_preview = 0
        self.removed_focus_preview = 0
        self.previews = []
        self.focus_previews = []
        self.results = []
        self.mask_error = None
        self.preview_error = None
        self.focus_preview_error = None
        self.write_error = None
        self.write_result_mode = "layer"
        self.active_document = True
        self.selection_bounds = None
        self.focus_constraint_calls = 0
        self.mask_sources = []
        self.events = []

    def has_active_document(self):
        return self.active_document

    def export_active_document_png(self):
        self.events.append("export_canvas")
        return b"canvas"

    def export_inpaint_mask_png(self, _source=MASK_SOURCE_SELECTION):
        if self.mask_error is not None:
            raise RuntimeError(self.mask_error)
        self.mask_sources.append(_source)
        return b"mask"

    def active_selection_rect(self):
        return None

    def active_selection_bounds(self):
        return self.selection_bounds

    def constrain_active_focus_selection(self, _minimum_context_pixels):
        self.focus_constraint_calls += 1
        return self.selection_bounds

    def active_focus_preview_rects(self, minimum_context_pixels):
        inner = self.selection_bounds
        if inner is None:
            return None
        outer = {
            "x": max(0, inner["x"] - minimum_context_pixels),
            "y": max(0, inner["y"] - minimum_context_pixels),
            "w": inner["w"] + minimum_context_pixels * 2,
            "h": inner["h"] + minimum_context_pixels * 2,
        }
        return inner, outer

    def focus_request_size_for_context(self, outer):
        import math

        area = outer["w"] * outer["h"]
        scale = math.sqrt(1048576 / area) if area <= 1048576 else 1.0
        width = max(64, int(outer["w"] * scale) // 64 * 64)
        height = max(64, int(outer["h"] * scale) // 64 * 64)
        return {"w": width, "h": height}

    def active_focus_geometry(self, minimum_context_pixels):
        inner = self.constrain_active_focus_selection(minimum_context_pixels)
        rects = self.active_focus_preview_rects(minimum_context_pixels)
        if inner is None or rects is None:
            return None
        _, outer = rects
        return {
            "inner": inner,
            "outer": outer,
            "request": self.focus_request_size_for_context(outer),
        }

    def write_focus_preview(self, minimum_context_pixels):
        self.events.append("write_focus_preview")
        if self.focus_preview_error is not None:
            raise RuntimeError(self.focus_preview_error)
        rects = self.active_focus_preview_rects(minimum_context_pixels)
        if rects is None:
            raise RuntimeError("Create a Krita selection before inpaint")
        inner, outer = rects
        self.focus_previews.append((minimum_context_pixels, inner, outer))
        return inner, outer

    def remove_preview_layer(self):
        self.events.append("remove_preview")
        self.removed_preview += 1

    def remove_focus_preview_layer(self):
        self.events.append("remove_focus_preview")
        self.removed_focus_preview += 1

    def write_png_preview(self, image):
        if self.preview_error is not None:
            raise RuntimeError(self.preview_error)
        self.previews.append(image)

    def write_png_result(self, image, name):
        if self.write_error is not None:
            raise RuntimeError(self.write_error)
        self.results.append((image, name))
        return self.write_result_mode


def _install_stubs():
    FakeTimer.single_shots.clear()
    FakeTimer.instances.clear()
    pyqt5 = types.ModuleType("PyQt5")
    qtcore = types.ModuleType("PyQt5.QtCore")
    qtwidgets = types.ModuleType("PyQt5.QtWidgets")
    qtgui = types.ModuleType("PyQt5.QtGui")
    krita = types.ModuleType("krita")

    qtcore.Qt = types.SimpleNamespace(Horizontal=1)
    qtcore.QSize = lambda width, height: (width, height)
    qtcore.QTimer = FakeTimer
    qtcore.QUrl = str
    qtcore.QObject = FakeWidget
    qtcore.pyqtSignal = lambda *_args, **_kwargs: FakeSignal()
    qtcore.QByteArray = bytes
    qtcore.QBuffer = FakeWidget
    qtcore.QIODevice = types.SimpleNamespace(WriteOnly=1)

    qtgui.QIcon = FakeIcon
    qtgui.QImage = FakeWidget
    qtgui.QPixmap = FakePixmap

    qtwidgets.QAbstractItemView = types.SimpleNamespace(SingleSelection=1)
    qtwidgets.QCheckBox = FakeCheckBox
    qtwidgets.QComboBox = FakeComboBox
    qtwidgets.QDoubleSpinBox = FakeSpinBox
    qtwidgets.QFormLayout = FakeLayout
    qtwidgets.QHBoxLayout = FakeLayout
    qtwidgets.QLabel = FakeWidget
    qtwidgets.QListView = FakeListWidget
    qtwidgets.QPlainTextEdit = FakeTextEdit
    qtwidgets.QProgressBar = FakeProgressBar
    qtwidgets.QPushButton = FakeButton
    qtwidgets.QListWidget = FakeListWidget
    qtwidgets.QListWidgetItem = FakeListWidgetItem
    qtwidgets.QSpinBox = FakeSpinBox
    qtwidgets.QSlider = FakeSlider
    qtwidgets.QVBoxLayout = FakeLayout
    qtwidgets.QWidget = FakeWidget

    krita.DockWidget = FakeWidget
    krita.InfoObject = FakeWidget
    krita.Krita = types.SimpleNamespace(instance=lambda: None)

    sys.modules["PyQt5"] = pyqt5
    sys.modules["PyQt5.QtCore"] = qtcore
    sys.modules["PyQt5.QtWidgets"] = qtwidgets
    sys.modules["PyQt5.QtGui"] = qtgui
    sys.modules["krita"] = krita
    package = types.ModuleType("nai_launcher_bridge")
    package.__path__ = [str(PLUGIN_ROOT)]
    sys.modules["nai_launcher_bridge"] = package


def _load_ui_module():
    _install_stubs()
    for name in list(sys.modules):
        if name.startswith("nai_launcher_bridge."):
            del sys.modules[name]
    module = importlib.import_module("nai_launcher_bridge.ui")
    module.BridgeClient = FakeClient
    return module


class DockerStateTests(unittest.TestCase):
    def test_status_indicator_tracks_connection_states(self):
        ui = _load_ui_module()
        docker = ui.NAILauncherBridgeDocker()

        self.assertIn("#d32f2f", docker._status_indicator.styleSheet())

        docker._on_connected_changed(True)

        self.assertIn("#2e7d32", docker._status_indicator.styleSheet())

        docker._on_connected_changed(False)

        self.assertIn("#f9a825", docker._status_indicator.styleSheet())

        docker._on_client_status_changed("未找到 Launcher 桥接：missing")

        self.assertIn("#d32f2f", docker._status_indicator.styleSheet())

        docker._on_client_status_changed("正在连接 NAI Launcher...")

        self.assertIn("#f9a825", docker._status_indicator.styleSheet())

    def test_minimum_context_controls_are_enabled_only_for_focused_inpaint(self):
        ui = _load_ui_module()
        docker = ui.NAILauncherBridgeDocker()

        self.assertFalse(docker._focused_inpaint.isChecked())
        self.assertFalse(docker._minimum_context._enabled)
        self.assertFalse(docker._minimum_context_slider._enabled)

        docker._focused_inpaint.setChecked(True)

        self.assertTrue(docker._minimum_context._enabled)
        self.assertTrue(docker._minimum_context_slider._enabled)

        docker._focused_inpaint.setChecked(False)

        self.assertFalse(docker._minimum_context._enabled)
        self.assertFalse(docker._minimum_context_slider._enabled)

    def test_inpaint_mask_layer_source_is_not_exposed(self):
        ui = _load_ui_module()
        docker = ui.NAILauncherBridgeDocker()

        self.assertFalse(hasattr(docker, "_mask_source"))
        self.assertFalse(hasattr(docker, "_mask_source_before_focus"))

    def test_numeric_parameters_have_linked_sliders_and_spin_boxes(self):
        ui = _load_ui_module()
        docker = ui.NAILauncherBridgeDocker()

        docker._strength_slider.setValue(65)
        self.assertAlmostEqual(docker._strength.value(), 0.65)
        docker._strength.setValue(0.35)
        self.assertEqual(docker._strength_slider.value(), 35)

        docker._noise_slider.setValue(25)
        self.assertAlmostEqual(docker._noise.value(), 0.25)
        docker._noise.setValue(0.4)
        self.assertEqual(docker._noise_slider.value(), 40)

        docker._inpaint_strength_slider.setValue(80)
        self.assertAlmostEqual(docker._inpaint_strength.value(), 0.8)
        docker._inpaint_strength.setValue(0.55)
        self.assertEqual(docker._inpaint_strength_slider.value(), 55)

        docker._minimum_context_slider.setValue(24)
        self.assertEqual(docker._minimum_context.value(), 24)
        docker._minimum_context.setValue(96)
        self.assertEqual(docker._minimum_context_slider.value(), 96)

    def test_workflow_hint_explains_selection_mask_and_live_focus_frame(self):
        ui = _load_ui_module()
        docker = ui.NAILauncherBridgeDocker()

        self.assertIn("当前 Krita 选区 = 重绘蒙版", docker._workflow_hint.text())
        self.assertNotIn("Inpaint Mask", docker._workflow_hint.text())

        docker._focused_inpaint.setChecked(True)

        self.assertIn("当前选区 = 内层重绘蒙版", docker._workflow_hint.text())
        self.assertIn("Minimum Context", docker._workflow_hint.text())
        self.assertIn("自动推导同心外框", docker._workflow_hint.text())
        self.assertIn("实时", docker._workflow_hint.text())

    def test_focused_inpaint_live_preview_starts_and_syncs_selection(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.selection_bounds = {"x": 8, "y": 9, "w": 64, "h": 72}
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()
        docker._focused_inpaint.setChecked(True)

        self.assertTrue(docker._focus_preview_timer.started)
        self.assertEqual(fake_canvas.focus_previews, [])
        self.assertTrue(docker._focus_preview_write_timer.started)
        self.assertIn("inner 8,9 64x72", docker._focus_rect_label.text())
        self.assertIn("outer 0,0 240x248", docker._focus_rect_label.text())
        self.assertIn("request ", docker._focus_rect_label.text())

        docker._focus_preview_write_timer.timeout.emit()

        self.assertEqual(fake_canvas.focus_previews[0][0], 88)
        self.assertIn("inner 8,9 64x72", docker._focus_rect_label.text())
        self.assertIn("outer 0,0 240x248", docker._focus_rect_label.text())

        fake_canvas.selection_bounds = {"x": 20, "y": 30, "w": 40, "h": 50}
        docker._focus_preview_timer.timeout.emit()

        self.assertEqual(len(fake_canvas.focus_previews), 1)
        self.assertIn("inner 20,30 40x50", docker._focus_rect_label.text())

        docker._focus_preview_write_timer.timeout.emit()

        self.assertEqual(fake_canvas.focus_previews[-1][1], fake_canvas.selection_bounds)
        self.assertIn("inner 20,30 40x50", docker._focus_rect_label.text())

    def test_minimum_context_change_updates_live_focus_outer_frame(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.selection_bounds = {"x": 20, "y": 30, "w": 40, "h": 50}
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()
        docker._focused_inpaint.setChecked(True)
        docker._focus_preview_write_timer.timeout.emit()
        fake_canvas.focus_previews.clear()

        docker._minimum_context.setValue(24)

        self.assertEqual(fake_canvas.focus_previews, [])
        self.assertIn("inner 20,30 40x50", docker._focus_rect_label.text())
        self.assertIn("outer 0,6 88x98", docker._focus_rect_label.text())

        docker._focus_preview_write_timer.timeout.emit()

        self.assertEqual(fake_canvas.focus_previews[-1][0], 24)
        self.assertIn("inner 20,30 40x50", docker._focus_rect_label.text())
        self.assertIn("outer 0,6 88x98", docker._focus_rect_label.text())

    def test_disabling_focused_inpaint_clears_live_double_frame(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.selection_bounds = {"x": 8, "y": 9, "w": 64, "h": 72}
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._focused_inpaint.setChecked(True)
        docker._focus_preview_write_timer.timeout.emit()
        docker._focused_inpaint.setChecked(False)
        fake_canvas.selection_bounds = {"x": 20, "y": 30, "w": 40, "h": 50}
        docker._focus_preview_timer.timeout.emit()
        docker._focus_preview_write_timer.timeout.emit()

        self.assertFalse(docker._focus_preview_timer.started)
        self.assertFalse(docker._focus_preview_write_timer.started)
        self.assertGreaterEqual(fake_canvas.removed_focus_preview, 1)
        self.assertIn("Focus Frame: off", docker._focus_rect_label.text())
        self.assertEqual(len(fake_canvas.focus_previews), 1)

    def test_buttons_require_connection_and_active_document(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        self.assertTrue(docker._params_button._enabled)
        self.assertTrue(docker._img2img_button._enabled)
        self.assertTrue(docker._inpaint_button._enabled)
        self.assertFalse(docker._cancel_button._enabled)

        fake_canvas.active_document = False
        docker._update_buttons()

        self.assertTrue(docker._params_button._enabled)
        self.assertFalse(docker._img2img_button._enabled)
        self.assertFalse(docker._inpaint_button._enabled)
        self.assertIn("请先打开 Krita 文档", docker._img2img_button._tooltip)

        docker._client.is_connected = False
        fake_canvas.active_document = True
        docker._update_buttons()

        self.assertFalse(docker._params_button._enabled)
        self.assertFalse(docker._img2img_button._enabled)
        self.assertFalse(docker._inpaint_button._enabled)
        self.assertFalse(docker._cancel_button._enabled)

    def test_mismatched_request_response_does_not_clear_active_request(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._start_request("img-active")
        docker._handle_message({"type": "cancelled", "id": "img-stale"})

        self.assertEqual(docker._active_request_id, "img-active")
        self.assertTrue(docker._progress._visible)
        self.assertEqual(fake_canvas.removed_preview, 0)

    def test_result_without_active_request_is_ignored(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._handle_message(
            {
                "type": "result",
                "id": "stale-result",
                "image": base64.b64encode(b"image").decode("ascii"),
                "name": "Stale Result",
            }
        )

        self.assertEqual(fake_canvas.results, [])
        self.assertEqual(fake_canvas.removed_preview, 0)
        self.assertIsNone(docker._active_request_id)

    def test_push_image_without_active_request_adds_result_item_and_inserts(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._handle_message(
            {
                "type": "push_image",
                "image": base64.b64encode(b"pushed-image").decode("ascii"),
                "name": "From Launcher",
            }
        )

        self.assertEqual(fake_canvas.results, [(b"pushed-image", "From Launcher")])
        self.assertEqual(docker._result_list.count(), 1)
        self.assertIn("From Launcher", docker._result_list.item(0).text())
        self.assertIsNone(docker._active_request_id)
        self.assertIn("已添加为新图层 From Launcher", docker._status.text())

    def test_push_image_write_failure_still_keeps_result_item(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.write_error = "Unsupported document format"
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._handle_message(
            {
                "type": "push_image",
                "image": base64.b64encode(b"pushed-image").decode("ascii"),
                "name": "From Launcher",
            }
        )

        self.assertEqual(docker._result_list.count(), 1)
        self.assertIn("From Launcher", docker._result_list.item(0).text())
        self.assertIn("文档格式暂不支持写回", docker._status.text())
        self.assertIn("#d32f2f", docker._status.styleSheet())

    def test_result_message_adds_result_item_without_writing_layer(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._start_request("img-active")
        docker._handle_message(
            {
                "type": "result",
                "id": "img-active",
                "image": base64.b64encode(b"image").decode("ascii"),
                "name": "NAI Result",
            }
        )

        self.assertIsNone(docker._active_request_id)
        self.assertEqual(fake_canvas.results, [])
        self.assertEqual(fake_canvas.removed_preview, 0)
        self.assertEqual(docker._result_list.count(), 1)
        self.assertIn("NAI Result", docker._result_list.item(0).text())
        self.assertIn("结果区", docker._status.text())

    def test_result_keeps_last_progress_preview_visible(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._start_request("img-active")
        docker._handle_message(
            {
                "type": "progress",
                "id": "img-active",
                "preview_image": base64.b64encode(b"preview-frame").decode("ascii"),
            }
        )
        docker._handle_message(
            {
                "type": "result",
                "id": "img-active",
                "image": base64.b64encode(b"final-image").decode("ascii"),
                "name": "NAI Result",
            }
        )

        self.assertIsNone(docker._active_request_id)
        self.assertEqual(fake_canvas.previews, [b"preview-frame"])
        self.assertEqual(fake_canvas.removed_preview, 0)
        self.assertEqual(docker._result_list.count(), 1)

    def test_clicking_result_item_previews_image(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._start_request("img-active")
        docker._handle_message(
            {
                "type": "result",
                "id": "img-active",
                "image": base64.b64encode(b"preview-me").decode("ascii"),
                "name": "Preview Me",
            }
        )
        item = docker._result_list.item(0)

        docker._result_list.itemClicked.emit(item)

        self.assertEqual(fake_canvas.previews, [b"preview-me"])
        self.assertEqual(fake_canvas.results, [])
        self.assertIn("已预览 Preview Me", docker._status.text())

    def test_deleting_selected_result_removes_item_and_payload(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        for name, image in (("First", b"first-image"), ("Second", b"second-image")):
            docker._handle_message(
                {
                    "type": "push_image",
                    "image": base64.b64encode(image).decode("ascii"),
                    "name": name,
                }
            )
        first_item = docker._result_list.item(0)
        docker._result_list.setCurrentItem(first_item)

        docker._delete_selected_results()
        docker._result_list.itemClicked.emit(first_item)

        self.assertEqual(docker._result_list.count(), 1)
        self.assertIn("Second", docker._result_list.item(0).text())
        self.assertEqual(fake_canvas.previews, [])
        self.assertEqual(len(docker._result_items), 1)
        self.assertIn("已删除结果", docker._status.text())

    def test_clearing_results_removes_all_items_and_payloads(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        for name, image in (("First", b"first-image"), ("Second", b"second-image")):
            docker._handle_message(
                {
                    "type": "push_image",
                    "image": base64.b64encode(image).decode("ascii"),
                    "name": name,
                }
            )

        docker._clear_results()

        self.assertEqual(docker._result_list.count(), 0)
        self.assertEqual(docker._result_items, {})
        self.assertIn("已清空结果区", docker._status.text())

    def test_double_clicking_result_item_adds_new_layer(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._start_request("img-active")
        docker._handle_message(
            {
                "type": "result",
                "id": "img-active",
                "image": base64.b64encode(b"insert-me").decode("ascii"),
                "name": "Insert Me",
            }
        )
        item = docker._result_list.item(0)

        docker._result_list.itemDoubleClicked.emit(item)

        self.assertEqual(fake_canvas.results, [(b"insert-me", "Insert Me")])
        self.assertIn("已添加为新图层 Insert Me", docker._status.text())

    def test_double_clicking_result_opened_as_document_has_explicit_status(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.write_result_mode = "document"
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._start_request("img-active")
        docker._handle_message(
            {
                "type": "result",
                "id": "img-active",
                "image": base64.b64encode(b"image").decode("ascii"),
                "name": "NAI Result",
            }
        )
        item = docker._result_list.item(0)

        docker._result_list.itemDoubleClicked.emit(item)

        self.assertEqual(fake_canvas.results, [(b"image", "NAI Result")])
        self.assertIn("已作为新文档打开 NAI Result", docker._status.text())

    def test_double_clicking_result_write_failure_is_localized(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.write_error = "Unsupported document format"
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._start_request("img-active")
        docker._handle_message(
            {
                "type": "result",
                "id": "img-active",
                "image": base64.b64encode(b"image").decode("ascii"),
                "name": "NAI Result",
            }
        )
        item = docker._result_list.item(0)

        docker._result_list.itemDoubleClicked.emit(item)

        self.assertIn("文档格式暂不支持写回", docker._status.text())
        self.assertIn("#d32f2f", docker._status.styleSheet())

    def test_mismatched_params_response_is_ignored(self):
        ui = _load_ui_module()
        docker = ui.NAILauncherBridgeDocker()
        docker._prompt.setPlainText("keep me")
        docker._pending_params_request_id = "params-current"

        docker._handle_message(
            {
                "type": "params",
                "id": "params-stale",
                "prompt": "stale prompt",
            }
        )

        self.assertEqual(docker._prompt.toPlainText(), "keep me")
        self.assertEqual(docker._pending_params_request_id, "params-current")

    def test_matching_params_response_is_applied_and_clears_pending_id(self):
        ui = _load_ui_module()
        docker = ui.NAILauncherBridgeDocker()
        docker._pending_params_request_id = "params-current"

        docker._handle_message(
            {
                "type": "params",
                "id": "params-current",
                "prompt": "fresh prompt",
            }
        )

        self.assertEqual(docker._prompt.toPlainText(), "fresh prompt")
        self.assertIsNone(docker._pending_params_request_id)

    def test_params_without_pending_request_is_ignored(self):
        ui = _load_ui_module()
        docker = ui.NAILauncherBridgeDocker()
        docker._prompt.setPlainText("manual prompt")

        docker._handle_message(
            {
                "type": "params",
                "prompt": "unsolicited prompt",
            }
        )

        self.assertEqual(docker._prompt.toPlainText(), "manual prompt")

    def test_inpaint_without_mask_shows_chinese_local_validation_message(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.mask_error = "Create a Krita selection before inpaint"
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._send_inpaint()

        self.assertIn("请先标记重绘区域", docker._status.text())
        self.assertNotIn("Create a Krita selection", docker._status.text())

    def test_non_focused_inpaint_does_not_read_selection_rect(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()

        def fail_if_called():
            raise RuntimeError("selection rect should not be read")

        fake_canvas.active_selection_rect = fail_if_called
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._send_inpaint()

        self.assertIsNotNone(docker._active_request_id)
        self.assertNotIn("selection rect should not be read", docker._status.text())

    def test_focused_inpaint_requires_current_selection_before_sending(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()
        docker._focused_inpaint.setChecked(True)

        docker._send_inpaint()

        self.assertIsNone(docker._active_request_id)
        self.assertEqual(docker._client.sent, [])
        self.assertIn("Minimum Context", docker._status.text())

    def test_focused_inpaint_sends_current_selection_as_inner_focus_rect(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.selection_bounds = {"x": 8, "y": 9, "w": 64, "h": 72}
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()
        docker._focused_inpaint.setChecked(True)
        calls_before_send = fake_canvas.focus_constraint_calls

        docker._send_inpaint()

        self.assertIsNotNone(docker._active_request_id)
        payload = json.loads(docker._client.sent[-1])
        self.assertEqual(payload["selection_rect"], {"x": 8, "y": 9, "w": 64, "h": 72})
        self.assertEqual(payload["minimum_context_pixels"], 88)
        self.assertGreater(fake_canvas.focus_constraint_calls, calls_before_send)

    def test_inpaint_always_uses_selection_mask_source(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.selection_bounds = {"x": 8, "y": 9, "w": 64, "h": 72}
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()
        docker._focused_inpaint.setChecked(True)

        docker._send_inpaint()

        self.assertEqual(fake_canvas.mask_sources, [fake_canvas.MASK_SOURCE_SELECTION])

    def test_non_focused_inpaint_uses_selection_mask_source(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.selection_bounds = {"x": 8, "y": 9, "w": 64, "h": 72}
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()
        docker._focused_inpaint.setChecked(True)
        docker._focused_inpaint.setChecked(False)

        docker._send_inpaint()

        payload = json.loads(docker._client.sent[-1])
        self.assertFalse(payload["focused_inpaint"])
        self.assertIsNone(payload["selection_rect"])
        self.assertEqual(fake_canvas.mask_sources, [fake_canvas.MASK_SOURCE_SELECTION])

    def test_non_focused_inpaint_does_not_constrain_native_selection(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.selection_bounds = {"x": 0, "y": 0, "w": 2400, "h": 1600}
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._send_inpaint()

        self.assertEqual(fake_canvas.focus_constraint_calls, 0)
        payload = json.loads(docker._client.sent[-1])
        self.assertFalse(payload["focused_inpaint"])
        self.assertIsNone(payload["selection_rect"])

    def test_focused_inpaint_send_exports_clean_canvas_and_restores_live_frame(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.selection_bounds = {"x": 8, "y": 9, "w": 64, "h": 72}
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()
        docker._focused_inpaint.setChecked(True)
        docker._focus_preview_write_timer.timeout.emit()
        fake_canvas.events.clear()

        docker._send_inpaint()

        self.assertIsNotNone(docker._active_request_id)
        self.assertEqual(
            fake_canvas.events[:4],
            [
                "remove_preview",
                "remove_focus_preview",
                "export_canvas",
                "write_focus_preview",
            ],
        )
        self.assertEqual(fake_canvas.focus_previews[-1][0], 88)
        self.assertIn("inner 8,9 64x72", docker._focus_rect_label.text())

    def test_focused_inpaint_send_continues_when_restoring_live_frame_fails(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.selection_bounds = {"x": 8, "y": 9, "w": 64, "h": 72}
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()
        docker._focused_inpaint.setChecked(True)
        docker._focus_preview_write_timer.timeout.emit()
        fake_canvas.events.clear()
        fake_canvas.focus_preview_error = "Krita failed to add preview layer"

        docker._send_inpaint()

        self.assertIsNotNone(docker._active_request_id)
        payload = json.loads(docker._client.sent[-1])
        self.assertTrue(payload["focused_inpaint"])
        self.assertEqual(payload["selection_rect"], {"x": 8, "y": 9, "w": 64, "h": 72})
        self.assertEqual(fake_canvas.mask_sources, [fake_canvas.MASK_SOURCE_SELECTION])
        self.assertEqual(
            fake_canvas.events[:4],
            [
                "remove_preview",
                "remove_focus_preview",
                "export_canvas",
                "write_focus_preview",
            ],
        )
        self.assertNotIn("Krita failed", docker._status.text())

    def test_repeated_focus_preview_layer_failure_is_not_reported_every_timer_tick(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.selection_bounds = {"x": 8, "y": 9, "w": 64, "h": 72}
        fake_canvas.focus_preview_error = "Krita failed to add preview layer"
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()
        status_updates = []
        original_set_status = docker._set_status

        def capture_status(text, *args, **kwargs):
            status_updates.append(text)
            original_set_status(text, *args, **kwargs)

        docker._set_status = capture_status

        docker._focused_inpaint.setChecked(True)
        docker._focus_preview_write_timer.timeout.emit()
        docker._focus_preview_write_timer.timeout.emit()

        self.assertEqual(status_updates, ["Krita 预览层写入失败，已跳过本帧"])
        self.assertIn("预览层写入失败", docker._status.text())
        self.assertNotIn("Krita failed", docker._status.text())

    def test_img2img_export_removes_stale_bridge_preview_layer(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()
        fake_canvas.events.clear()

        docker._send_img2img()

        self.assertIsNotNone(docker._active_request_id)
        self.assertEqual(
            fake_canvas.events[:3],
            ["remove_preview", "remove_focus_preview", "export_canvas"],
        )

    def test_cancel_sends_current_request_id_only(self):
        ui = _load_ui_module()
        docker = ui.NAILauncherBridgeDocker()

        docker._start_request("img-active")
        docker._cancel()

        self.assertEqual(
            json.loads(docker._client.sent[-1]),
            {"type": "cancel", "id": "img-active"},
        )

    def test_disconnect_during_request_cleans_preview_and_unblocks_controls(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._start_request("img-1")
        docker._on_connected_changed(False)

        self.assertIsNone(docker._active_request_id)
        self.assertEqual(fake_canvas.removed_preview, 1)
        self.assertIn("连接中断", docker._status.text())

    def test_preview_throttle_writes_first_frame_immediately(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        times = iter([0.0, 0.1, 0.4])
        original_monotonic = ui.time.monotonic
        try:
            ui.time.monotonic = lambda: next(times)
            docker = ui.NAILauncherBridgeDocker()
            docker._start_request("img-1")

            for image in (b"preview-1", b"preview-2", b"preview-3"):
                docker._handle_message(
                    {
                        "type": "progress",
                        "id": "img-1",
                        "progress": 0.5,
                        "preview_image": base64.b64encode(image).decode("ascii"),
                    }
                )

            self.assertEqual(fake_canvas.previews, [b"preview-1", b"preview-3"])
            self.assertIn("预览已更新 2 帧", docker._status.text())
        finally:
            ui.time.monotonic = original_monotonic

    def test_progress_without_preview_explains_waiting_for_preview_frame(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()
        docker._start_request("img-1")

        docker._handle_message(
            {
                "type": "progress",
                "id": "img-1",
                "progress": 0.5,
                "step": 2,
                "total_steps": 4,
            }
        )

        self.assertEqual(fake_canvas.previews, [])
        self.assertIn("生成中 2/4", docker._status.text())
        self.assertIn("等待预览帧", docker._status.text())

    def test_preview_write_failure_keeps_visible_error_status(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.preview_error = "Unsupported document format"
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()
        docker._start_request("img-1")

        docker._handle_message(
            {
                "type": "progress",
                "id": "img-1",
                "progress": 0.5,
                "step": 2,
                "total_steps": 4,
                "preview_image": base64.b64encode(b"preview").decode("ascii"),
            }
        )

        self.assertEqual(fake_canvas.previews, [])
        self.assertIn("文档格式暂不支持写回", docker._status.text())
        self.assertIn("#d32f2f", docker._status.styleSheet())

    def test_preview_write_failure_does_not_throttle_next_retry(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.preview_error = "Unsupported document format"
        ui.canvas_io = fake_canvas
        times = iter([0.0, 0.1])
        original_monotonic = ui.time.monotonic
        try:
            ui.time.monotonic = lambda: next(times)
            docker = ui.NAILauncherBridgeDocker()
            docker._start_request("img-1")

            docker._handle_message(
                {
                    "type": "progress",
                    "id": "img-1",
                    "progress": 0.25,
                    "preview_image": base64.b64encode(b"preview-1").decode("ascii"),
                }
            )
            fake_canvas.preview_error = None
            docker._handle_message(
                {
                    "type": "progress",
                    "id": "img-1",
                    "progress": 0.5,
                    "preview_image": base64.b64encode(b"preview-2").decode("ascii"),
                }
            )

            self.assertEqual(fake_canvas.previews, [b"preview-2"])
            self.assertIn("预览已更新 1 帧", docker._status.text())
        finally:
            ui.time.monotonic = original_monotonic

    def test_repeated_preview_layer_failure_is_not_reported_every_frame(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        fake_canvas.preview_error = "Krita failed to add preview layer"
        ui.canvas_io = fake_canvas
        times = iter([0.0, 0.4])
        original_monotonic = ui.time.monotonic
        try:
            ui.time.monotonic = lambda: next(times)
            docker = ui.NAILauncherBridgeDocker()
            docker._start_request("img-1")

            for image in (b"preview-1", b"preview-2"):
                docker._handle_message(
                    {
                        "type": "progress",
                        "id": "img-1",
                        "progress": 0.5,
                        "preview_image": base64.b64encode(image).decode("ascii"),
                    }
                )

            self.assertEqual(fake_canvas.previews, [])
            self.assertEqual(len(FakeTimer.single_shots), 1)
            self.assertIn("预览层写入失败", docker._status.text())
            self.assertNotIn("Krita failed", docker._status.text())
        finally:
            ui.time.monotonic = original_monotonic

    def test_launcher_error_is_red_and_auto_clears(self):
        ui = _load_ui_module()
        fake_canvas = FakeCanvasIO()
        ui.canvas_io = fake_canvas
        docker = ui.NAILauncherBridgeDocker()

        docker._handle_message({"type": "error", "code": "busy", "message": "busy"})

        self.assertIn("Launcher 正在生成", docker._status.text())
        self.assertIn("#d32f2f", docker._status.styleSheet())

        FakeTimer.flush_single_shots()

        self.assertEqual(docker._status.text(), "已连接 NAI Launcher")
        self.assertEqual(docker._status.styleSheet(), "")

    def test_bridge_protocol_errors_are_localized(self):
        ui = _load_ui_module()
        docker = ui.NAILauncherBridgeDocker()

        cases = {
            "invalid_request": "请求参数无效",
            "unauthorized_bridge_client": "桥接客户端尚未认证",
            "unsupported_message": "当前插件消息不受支持",
            "stream_interrupted": "生成流中断",
        }

        for code, expected in cases.items():
            with self.subTest(code=code):
                text = docker._localized_error(
                    {
                        "type": "error",
                        "code": code,
                        "message": "fallback",
                    }
                )

                self.assertEqual(text, expected)

    def test_unknown_launcher_error_does_not_echo_sensitive_message(self):
        ui = _load_ui_module()
        docker = ui.NAILauncherBridgeDocker()

        text = docker._localized_error(
            {
                "type": "error",
                "code": "new_server_error",
                "message": "token pst-secret endpoint https://nai.local",
            }
        )

        self.assertEqual(text, "请求失败")
        self.assertNotIn("token", text)
        self.assertNotIn("pst-secret", text)
        self.assertNotIn("endpoint", text)


if __name__ == "__main__":
    unittest.main()
