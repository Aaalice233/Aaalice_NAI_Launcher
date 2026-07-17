import time
from typing import Any, Dict, Optional

from PyQt5.QtCore import QSize, Qt, QTimer
from PyQt5.QtGui import QIcon, QPixmap
from PyQt5.QtWidgets import (
    QAbstractItemView,
    QCheckBox,
    QDoubleSpinBox,
    QFormLayout,
    QHBoxLayout,
    QLabel,
    QListView,
    QListWidget,
    QListWidgetItem,
    QPlainTextEdit,
    QProgressBar,
    QPushButton,
    QSlider,
    QSpinBox,
    QVBoxLayout,
    QWidget,
)
from krita import DockWidget

from . import canvas_io
from . import diagnostics
from .bridge_client import BridgeClient
from .protocol import (
    decode_image_field,
    encode_cancel,
    encode_get_params,
    encode_img2img,
    encode_inpaint,
)


class NAILauncherBridgeDocker(DockWidget):
    _preview_throttle_seconds = 0.35

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("NAI Launcher Bridge")
        self._client = BridgeClient(self)
        self._active_request_id: Optional[str] = None
        self._pending_params_request_id: Optional[str] = None
        self._last_preview_at: Optional[float] = None
        self._last_preview_error_text: Optional[str] = None
        self._last_focus_preview_error_text: Optional[str] = None
        self._last_focus_preview_key: Optional[tuple[int, int, int, int, int]] = None
        self._pending_focus_preview_key: Optional[tuple[int, int, int, int, int]] = None
        self._result_items: Dict[int, tuple[bytes, str]] = {}
        self._preview_frame_count = 0
        self._syncing_numeric_controls = False
        self._focus_preview_timer = QTimer(self)
        self._focus_preview_timer.setInterval(100)
        self._focus_preview_write_timer = QTimer(self)
        self._focus_preview_write_timer.setInterval(140)
        self._focus_preview_write_timer.setSingleShot(True)

        root = QWidget(self)
        layout = QVBoxLayout(root)

        status_row = QHBoxLayout()
        self._status_indicator = QLabel("●")
        status_row.addWidget(self._status_indicator)
        self._status = QLabel("未连接")
        self._status.setWordWrap(True)
        status_row.addWidget(self._status)
        layout.addLayout(status_row)

        form = QFormLayout()
        self._prompt = QPlainTextEdit()
        self._prompt.setMaximumHeight(72)
        self._negative_prompt = QPlainTextEdit()
        self._negative_prompt.setMaximumHeight(72)
        (
            self._strength,
            self._strength_slider,
            strength_control,
        ) = self._create_double_slider_control(value=0.5)
        (
            self._noise,
            self._noise_slider,
            noise_control,
        ) = self._create_double_slider_control(value=0.0)
        (
            self._inpaint_strength,
            self._inpaint_strength_slider,
            inpaint_strength_control,
        ) = self._create_double_slider_control(value=1.0)
        (
            self._minimum_context,
            self._minimum_context_slider,
            minimum_context_control,
        ) = self._create_int_slider_control(minimum=16, maximum=192, value=88)
        self._focused_inpaint = QCheckBox("Focused Inpaint")
        form.addRow("Prompt", self._prompt)
        form.addRow("Negative", self._negative_prompt)
        form.addRow("Strength", strength_control)
        form.addRow("Noise", noise_control)
        form.addRow("Inpaint Strength", inpaint_strength_control)
        form.addRow("Minimum Context", minimum_context_control)
        form.addRow("", self._focused_inpaint)
        layout.addLayout(form)

        self._workflow_hint = QLabel()
        self._workflow_hint.setWordWrap(True)
        layout.addWidget(self._workflow_hint)

        self._focus_rect_label = QLabel("Focus Frame: off")
        self._focus_rect_label.setWordWrap(True)
        layout.addWidget(self._focus_rect_label)

        buttons = QHBoxLayout()
        self._connect_button = QPushButton("Connect")
        self._params_button = QPushButton("Get Params")
        self._diagnostics_button = QPushButton("Diagnostics")
        self._img2img_button = QPushButton("Img2Img")
        self._inpaint_button = QPushButton("Inpaint")
        self._cancel_button = QPushButton("Cancel")
        self._cancel_button.setEnabled(False)
        buttons.addWidget(self._connect_button)
        buttons.addWidget(self._params_button)
        buttons.addWidget(self._diagnostics_button)
        buttons.addWidget(self._img2img_button)
        buttons.addWidget(self._inpaint_button)
        buttons.addWidget(self._cancel_button)
        layout.addLayout(buttons)

        self._progress = QProgressBar()
        self._progress.setRange(0, 100)
        self._progress.setValue(0)
        self._progress.setVisible(False)
        layout.addWidget(self._progress)

        self._result_hint = QLabel("Results: single click preview, double click add layer")
        self._result_hint.setWordWrap(True)
        layout.addWidget(self._result_hint)
        self._result_list = QListWidget()
        self._result_list.setViewMode(QListView.IconMode)
        self._result_list.setIconSize(QSize(96, 96))
        self._result_list.setResizeMode(QListView.Adjust)
        self._result_list.setMovement(QListView.Static)
        self._result_list.setSelectionMode(QAbstractItemView.SingleSelection)
        self._result_list.setMaximumHeight(132)
        layout.addWidget(self._result_list)
        result_buttons = QHBoxLayout()
        self._delete_result_button = QPushButton("Delete")
        self._clear_results_button = QPushButton("Clear")
        result_buttons.addWidget(self._delete_result_button)
        result_buttons.addWidget(self._clear_results_button)
        layout.addLayout(result_buttons)

        self.setWidget(root)
        self._set_connection_indicator("red")
        self._connect_signals()
        self._update_focused_inpaint_controls()
        self._update_buttons()
        self._client.start()

    def _create_double_slider_control(
        self,
        *,
        value: float,
        minimum: float = 0.0,
        maximum: float = 1.0,
        step: float = 0.05,
    ) -> tuple[QDoubleSpinBox, QSlider, QWidget]:
        spinbox = QDoubleSpinBox()
        spinbox.setRange(minimum, maximum)
        spinbox.setDecimals(2)
        spinbox.setSingleStep(step)

        slider = QSlider(Qt.Horizontal)
        scale = 100
        slider.setRange(int(round(minimum * scale)), int(round(maximum * scale)))
        slider.setSingleStep(max(1, int(round(step * scale))))

        spinbox.setValue(value)
        slider.setValue(int(round(value * scale)))
        slider.valueChanged.connect(
            lambda raw_value: self._sync_spinbox_from_slider(
                spinbox,
                raw_value,
                scale=scale,
            )
        )
        spinbox.valueChanged.connect(
            lambda raw_value: self._sync_slider_from_spinbox(
                slider,
                raw_value,
                scale=scale,
            )
        )
        return spinbox, slider, self._build_slider_row(slider, spinbox)

    def _create_int_slider_control(
        self,
        *,
        minimum: int,
        maximum: int,
        value: int,
    ) -> tuple[QSpinBox, QSlider, QWidget]:
        spinbox = QSpinBox()
        spinbox.setRange(minimum, maximum)

        slider = QSlider(Qt.Horizontal)
        slider.setRange(minimum, maximum)

        spinbox.setValue(value)
        slider.setValue(value)
        slider.valueChanged.connect(
            lambda raw_value: self._sync_int_spinbox_from_slider(spinbox, raw_value)
        )
        spinbox.valueChanged.connect(
            lambda raw_value: self._sync_int_slider_from_spinbox(slider, raw_value)
        )
        return spinbox, slider, self._build_slider_row(slider, spinbox)

    def _build_slider_row(self, slider: QSlider, spinbox: QWidget) -> QWidget:
        row = QWidget()
        layout = QHBoxLayout(row)
        if hasattr(layout, "setContentsMargins"):
            layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(slider)
        layout.addWidget(spinbox)
        return row

    def _sync_spinbox_from_slider(
        self,
        spinbox: QDoubleSpinBox,
        raw_value: int,
        *,
        scale: int,
    ) -> None:
        if self._syncing_numeric_controls:
            return
        self._syncing_numeric_controls = True
        try:
            spinbox.setValue(round(float(raw_value) / scale, 2))
        finally:
            self._syncing_numeric_controls = False

    def _sync_slider_from_spinbox(
        self,
        slider: QSlider,
        raw_value: float,
        *,
        scale: int,
    ) -> None:
        if self._syncing_numeric_controls:
            return
        self._syncing_numeric_controls = True
        try:
            slider.setValue(int(round(float(raw_value) * scale)))
        finally:
            self._syncing_numeric_controls = False

    def _sync_int_spinbox_from_slider(
        self,
        spinbox: QSpinBox,
        raw_value: int,
    ) -> None:
        if self._syncing_numeric_controls:
            return
        self._syncing_numeric_controls = True
        try:
            spinbox.setValue(int(raw_value))
        finally:
            self._syncing_numeric_controls = False

    def _sync_int_slider_from_spinbox(
        self,
        slider: QSlider,
        raw_value: int,
    ) -> None:
        if self._syncing_numeric_controls:
            return
        self._syncing_numeric_controls = True
        try:
            slider.setValue(int(raw_value))
        finally:
            self._syncing_numeric_controls = False

    def canvasChanged(self, canvas) -> None:
        self._update_buttons()

    def _connect_signals(self) -> None:
        self._connect_button.clicked.connect(self._client.connect_to_launcher)
        self._params_button.clicked.connect(self._request_params)
        self._diagnostics_button.clicked.connect(self._run_diagnostics)
        self._img2img_button.clicked.connect(self._send_img2img)
        self._inpaint_button.clicked.connect(self._send_inpaint)
        self._cancel_button.clicked.connect(self._cancel)
        self._focused_inpaint.toggled.connect(self._update_focused_inpaint_controls)
        self._minimum_context.valueChanged.connect(self._on_minimum_context_changed)
        self._focus_preview_timer.timeout.connect(self._sync_focus_preview)
        self._focus_preview_write_timer.timeout.connect(self._write_pending_focus_preview)
        self._result_list.itemClicked.connect(self._preview_result_item)
        self._result_list.itemDoubleClicked.connect(self._insert_result_item)
        self._delete_result_button.clicked.connect(self._delete_selected_results)
        self._clear_results_button.clicked.connect(self._clear_results)
        self._client.connected_changed.connect(self._on_connected_changed)
        self._client.status_changed.connect(self._on_client_status_changed)
        self._client.message_received.connect(self._handle_message)

    def _update_focused_inpaint_controls(self, *_args) -> None:
        focused = self._focused_inpaint.isChecked()
        self._minimum_context.setEnabled(focused)
        self._minimum_context_slider.setEnabled(focused)
        if focused:
            self._workflow_hint.setText(
                "Focused：当前选区 = 内层重绘蒙版；"
                "Minimum Context 会自动推导同心外框，并随选区实时更新。"
            )
            self._focus_preview_timer.start()
            self._sync_focus_preview(force=True, quiet=True)
        else:
            self._focus_preview_timer.stop()
            self._focus_preview_write_timer.stop()
            self._last_focus_preview_key = None
            self._pending_focus_preview_key = None
            canvas_io.remove_focus_preview_layer()
            self._focus_rect_label.setText("Focus Frame: off")
            self._workflow_hint.setText(
                "普通 Inpaint：当前 Krita 选区 = 重绘蒙版。"
            )

    def _on_minimum_context_changed(self, *_args) -> None:
        self._sync_focus_preview(force=True, quiet=True)

    def _sync_focus_preview(
        self,
        *_args,
        force: bool = False,
        quiet: bool = False,
        write_now: bool = False,
    ) -> None:
        if not self._focused_inpaint.isChecked():
            return
        try:
            minimum_context = self._minimum_context.value()
            geometry = canvas_io.active_focus_geometry(minimum_context)
            if geometry is None:
                self._last_focus_preview_key = None
                self._pending_focus_preview_key = None
                self._focus_preview_write_timer.stop()
                canvas_io.remove_focus_preview_layer()
                self._last_focus_preview_error_text = None
                self._focus_rect_label.setText("Focus Frame: select inner repaint area")
                return

            selection_rect = geometry["inner"]
            key = (
                int(minimum_context),
                int(selection_rect.get("x", 0)),
                int(selection_rect.get("y", 0)),
                int(selection_rect.get("w", 0)),
                int(selection_rect.get("h", 0)),
            )
            if not force and key == self._last_focus_preview_key:
                return

            inner_rect = geometry["inner"]
            outer_rect = geometry["outer"]
            request_size = geometry["request"]
            self._last_focus_preview_key = key
            self._pending_focus_preview_key = key
            self._last_focus_preview_error_text = None
            self._focus_rect_label.setText(
                "Focus Frame: "
                f"inner {self._format_rect(inner_rect)} / "
                f"outer {self._format_rect(outer_rect)} / "
                f"request {request_size['w']}x{request_size['h']}"
            )
            if write_now:
                self._write_focus_preview_layer(quiet=quiet)
            else:
                self._focus_preview_write_timer.start()
            if not quiet and not write_now:
                self._set_status(
                    "已同步 Focus 同心框："
                    f"内框 {self._format_rect(inner_rect)}，"
                    f"外框 {self._format_rect(outer_rect)}"
                )
        except Exception as error:
            self._last_focus_preview_key = None
            if quiet:
                return
            localized = self._localized_local_error(error)
            if localized == self._last_focus_preview_error_text:
                return
            self._last_focus_preview_error_text = localized
            self._set_status(localized, error=True)

    def _write_pending_focus_preview(self, *_args) -> None:
        self._write_focus_preview_layer(quiet=False)

    def _write_focus_preview_layer(self, *, quiet: bool) -> None:
        if (
            not self._focused_inpaint.isChecked()
            or self._pending_focus_preview_key is None
        ):
            return
        try:
            inner_rect, outer_rect = canvas_io.write_focus_preview(
                self._minimum_context.value()
            )
            request_size = canvas_io.focus_request_size_for_context(outer_rect)
            self._pending_focus_preview_key = None
            self._last_focus_preview_error_text = None
            self._focus_rect_label.setText(
                "Focus Frame: "
                f"inner {self._format_rect(inner_rect)} / "
                f"outer {self._format_rect(outer_rect)} / "
                f"request {request_size['w']}x{request_size['h']}"
            )
            if not quiet:
                self._set_status(
                    "已同步 Focus 同心框："
                    f"内框 {self._format_rect(inner_rect)}，"
                    f"外框 {self._format_rect(outer_rect)}"
                )
        except Exception as error:
            self._last_focus_preview_key = None
            if quiet:
                return
            localized = self._localized_local_error(error)
            if localized == self._last_focus_preview_error_text:
                return
            self._last_focus_preview_error_text = localized
            self._set_status(localized, error=True)

    def _resolve_focus_rect(
        self,
        focused_inpaint: bool,
    ) -> Optional[Dict[str, int]]:
        if not focused_inpaint:
            return None
        selection_rect = canvas_io.constrain_active_focus_selection(
            self._minimum_context.value()
        )
        if selection_rect is None:
            raise RuntimeError(
                "请先框选内层重绘区域；Minimum Context 会自动推导外层 Focus 框"
            )
        return selection_rect

    def _format_rect(self, rect: Dict[str, int]) -> str:
        return (
            f"{rect.get('x', 0)},{rect.get('y', 0)} "
            f"{rect.get('w', 0)}x{rect.get('h', 0)}"
        )

    def _request_params(self) -> None:
        request_id = self._new_request_id("params")
        if self._client.send_text(encode_get_params(request_id)):
            self._pending_params_request_id = request_id

    def _run_diagnostics(self) -> None:
        try:
            report = diagnostics.run_diagnostics()
            self._set_status(diagnostics.format_summary(report))
        except Exception as error:
            self._set_status(f"Diagnostics failed: {error}", error=True)

    def _send_img2img(self) -> None:
        if self._active_request_id is not None:
            return
        try:
            image_png = self._export_clean_canvas()
            request_id = self._new_request_id("img")
            if self._client.send_text(
                encode_img2img(
                    request_id=request_id,
                    image_png=image_png,
                    prompt=self._prompt.toPlainText(),
                    negative_prompt=self._negative_prompt.toPlainText(),
                    strength=self._strength.value(),
                    noise=self._noise.value(),
                )
            ):
                self._start_request(request_id)
        except Exception as error:
            self._set_status(self._localized_local_error(error), error=True)

    def _send_inpaint(self) -> None:
        if self._active_request_id is not None:
            return
        try:
            focused_inpaint = self._focused_inpaint.isChecked()
            selection_rect = self._resolve_focus_rect(focused_inpaint)
            image_png = self._export_clean_canvas()
            mask_png = canvas_io.export_inpaint_mask_png()
            request_id = self._new_request_id("inpaint")
            if self._client.send_text(
                encode_inpaint(
                    request_id=request_id,
                    image_png=image_png,
                    mask_png=mask_png,
                    prompt=self._prompt.toPlainText(),
                    negative_prompt=self._negative_prompt.toPlainText(),
                    strength=self._strength.value(),
                    noise=self._noise.value(),
                    inpaint_strength=self._inpaint_strength.value(),
                    minimum_context_pixels=self._minimum_context.value(),
                    focused_inpaint=focused_inpaint,
                    selection_rect=selection_rect,
                )
            ):
                self._start_request(request_id)
        except Exception as error:
            self._set_status(self._localized_local_error(error), error=True)

    def _export_clean_canvas(self) -> bytes:
        should_restore_focus_preview = self._focused_inpaint.isChecked()
        canvas_io.remove_preview_layer()
        canvas_io.remove_focus_preview_layer()
        self._last_focus_preview_key = None
        try:
            return canvas_io.export_active_document_png()
        finally:
            if should_restore_focus_preview and self._focused_inpaint.isChecked():
                self._sync_focus_preview(force=True, quiet=True, write_now=True)

    def _cancel(self) -> None:
        if self._active_request_id is None:
            return
        self._client.send_text(encode_cancel(self._active_request_id))

    def _handle_message(self, message: Dict[str, Any]) -> None:
        message_type = message.get("type")
        if message_type == "params":
            if not self._is_pending_params_message(message):
                return
            self._apply_params(message)
        elif message_type == "progress":
            if not self._is_current_request_message(message):
                return
            self._apply_progress(message)
        elif message_type == "result":
            if not self._is_current_request_message(message):
                return
            self._try_add_result_message(message)
            self._finish_request(clear_preview=False)
        elif message_type == "push_image":
            item = self._try_add_result_message(message)
            if item is not None:
                self._insert_result_item(item)
        elif message_type == "error":
            if not self._is_current_request_message(message, allow_global=True):
                return
            self._set_status(
                self._localized_error(message),
                error=True,
                auto_clear=True,
            )
            self._finish_request()
        elif message_type == "cancelled":
            if not self._is_current_request_message(message):
                return
            self._set_status("生成已取消")
            self._finish_request()

    def _is_current_request_message(
        self,
        message: Dict[str, Any],
        *,
        allow_global: bool = False,
    ) -> bool:
        message_id = message.get("id")
        if self._active_request_id is None:
            return allow_global and message_id is None
        return message_id == self._active_request_id

    def _is_pending_params_message(self, message: Dict[str, Any]) -> bool:
        return (
            self._pending_params_request_id is not None
            and message.get("id") == self._pending_params_request_id
        )

    def _apply_params(self, message: Dict[str, Any]) -> None:
        self._prompt.setPlainText(str(message.get("prompt", "")))
        self._negative_prompt.setPlainText(str(message.get("negative_prompt", "")))
        self._strength.setValue(float(message.get("strength", 0.5)))
        self._noise.setValue(float(message.get("noise", 0.0)))
        self._inpaint_strength.setValue(float(message.get("inpaint_strength", 1.0)))
        self._minimum_context.setValue(int(message.get("minimum_context_pixels", 88)))
        self._pending_params_request_id = None
        self._set_status("已从 NAI Launcher 复制参数")

    def _apply_progress(self, message: Dict[str, Any]) -> None:
        step = message.get("step")
        total = message.get("total_steps")
        status_text = (
            f"生成中 {step}/{total}"
            if step is not None and total is not None
            else "生成中..."
        )
        progress = float(message.get("progress", 0.0))
        self._progress.setValue(max(0, min(100, int(progress * 100))))
        if "preview_image" in message:
            now = time.monotonic()
            if (
                self._last_preview_at is None
                or now - self._last_preview_at >= self._preview_throttle_seconds
            ):
                if not self._try_write_image_message(
                    message,
                    field="preview_image",
                    name="NAI Preview",
                    preview=True,
                ):
                    return
                self._last_preview_at = now
                self._preview_frame_count += 1
                status_text = (
                    f"{status_text}，预览已更新 {self._preview_frame_count} 帧"
                )
            else:
                status_text = f"{status_text}，预览节流中"
        else:
            status_text = f"{status_text}，等待预览帧"
        self._set_status(status_text)

    def _try_write_image_message(
        self,
        message: Dict[str, Any],
        *,
        field: str = "image",
        name: Optional[str] = None,
        preview: bool = False,
    ) -> bool:
        try:
            self._write_image_message(
                message,
                field=field,
                name=name,
                preview=preview,
            )
            return True
        except Exception as error:
            localized = self._localized_local_error(error)
            if preview and localized == self._last_preview_error_text:
                return False
            self._set_status(
                localized,
                error=True,
                auto_clear=True,
            )
            if preview:
                self._last_preview_error_text = localized
            return False

    def _try_add_result_message(
        self,
        message: Dict[str, Any],
        *,
        field: str = "image",
        name: Optional[str] = None,
    ) -> Optional[QListWidgetItem]:
        try:
            return self._add_result_message(message, field=field, name=name)
        except Exception as error:
            self._set_status(
                self._localized_local_error(error),
                error=True,
                auto_clear=True,
            )
            return None

    def _add_result_message(
        self,
        message: Dict[str, Any],
        *,
        field: str = "image",
        name: Optional[str] = None,
    ) -> QListWidgetItem:
        image = decode_image_field(message, field)
        image_name = name or str(message.get("name") or "NAI Launcher Result")
        item = QListWidgetItem(image_name)
        pixmap = QPixmap()
        if pixmap.loadFromData(image, "PNG"):
            item.setIcon(QIcon(pixmap))
        item.setToolTip("单击预览，双击添加为新图层")
        self._result_items[id(item)] = (image, image_name)
        self._result_list.addItem(item)
        self._set_status(
            f"已加入结果区 {image_name}（单击预览，双击添加为新图层）"
        )
        return item

    def _preview_result_item(self, item: QListWidgetItem) -> None:
        result = self._result_items.get(id(item))
        if result is None:
            return
        image, image_name = result
        try:
            canvas_io.write_png_preview(image)
            self._last_preview_error_text = None
            self._set_status(f"已预览 {image_name}（双击添加为新图层）")
        except Exception as error:
            self._set_status(
                self._localized_local_error(error),
                error=True,
                auto_clear=True,
            )

    def _insert_result_item(self, item: QListWidgetItem) -> None:
        result = self._result_items.get(id(item))
        if result is None:
            return
        image, image_name = result
        try:
            write_mode = canvas_io.write_png_result(image, image_name)
            if write_mode == "document":
                self._set_status(f"已作为新文档打开 {image_name}")
            else:
                self._set_status(f"已添加为新图层 {image_name}")
        except Exception as error:
            self._set_status(
                self._localized_local_error(error),
                error=True,
                auto_clear=True,
            )

    def _delete_selected_results(self) -> None:
        selected_items = list(self._result_list.selectedItems())
        if not selected_items:
            current_item = self._result_list.currentItem()
            if current_item is not None:
                selected_items = [current_item]
        if not selected_items:
            self._set_status("请先选择要删除的结果")
            return

        deleted_count = 0
        for item in selected_items:
            if self._remove_result_item(item):
                deleted_count += 1

        if deleted_count == 0:
            self._set_status("选中的结果已经不存在")
            return
        self._set_status(f"已删除结果 {deleted_count} 个")

    def _remove_result_item(self, item: QListWidgetItem) -> bool:
        removed_payload = self._result_items.pop(id(item), None) is not None
        row = self._result_list.row(item)
        if row >= 0:
            self._result_list.takeItem(row)
            return True
        return removed_payload

    def _clear_results(self) -> None:
        if self._result_list.count() == 0 and not self._result_items:
            self._set_status("结果区已为空")
            return
        self._result_items.clear()
        self._result_list.clear()
        self._set_status("已清空结果区")

    def _write_image_message(
        self,
        message: Dict[str, Any],
        *,
        field: str = "image",
        name: Optional[str] = None,
        preview: bool = False,
    ) -> None:
        image = decode_image_field(message, field)
        if not preview:
            raise RuntimeError("Result images are handled by the result area")
        canvas_io.write_png_preview(image)
        self._last_preview_error_text = None

    def _start_request(self, request_id: str) -> None:
        self._active_request_id = request_id
        self._last_preview_at = None
        self._preview_frame_count = 0
        self._progress.setValue(0)
        self._progress.setVisible(True)
        self._set_status("请求已发送到 NAI Launcher")
        self._update_buttons()

    def _finish_request(self, *, clear_preview: bool = True) -> None:
        if clear_preview:
            canvas_io.remove_preview_layer()
        self._active_request_id = None
        self._progress.setVisible(False)
        self._update_buttons()

    def _on_connected_changed(self, connected: bool) -> None:
        self._connect_button.setText("Reconnect" if connected else "Connect")
        self._set_connection_indicator("green" if connected else "yellow")
        if not connected and self._active_request_id is not None:
            self._finish_request()
            self._set_status("连接中断，已清理预览层")
        self._update_buttons()

    def _on_client_status_changed(self, text: str) -> None:
        if "未找到" in text or "尚未连接" in text or "认证失败" in text:
            self._set_connection_indicator("red")
        elif "正在连接" in text or "重连" in text or "reconnect" in text.lower():
            self._set_connection_indicator("yellow")
        self._set_status(text)

    def _set_connection_indicator(self, state: str) -> None:
        colors = {
            "green": "#2e7d32",
            "yellow": "#f9a825",
            "red": "#d32f2f",
        }
        self._status_indicator.setStyleSheet(
            f"color: {colors.get(state, colors['red'])};"
        )

    def _set_status(
        self,
        text: str,
        *,
        error: bool = False,
        auto_clear: bool = False,
    ) -> None:
        self._status.setText(text)
        self._status.setStyleSheet("color: #d32f2f;" if error else "")
        if auto_clear:
            QTimer.singleShot(3000, lambda: self._clear_status_if_current(text))

    def _clear_status_if_current(self, text: str) -> None:
        if self._status.text() != text:
            return
        self._set_status(
            "已连接 NAI Launcher" if self._client.is_connected else "未连接",
        )

    def _new_request_id(self, prefix: str) -> str:
        return f"{prefix}-{int(time.time() * 1000)}"

    def _update_buttons(self) -> None:
        connected = self._client.is_connected
        busy = self._active_request_id is not None
        has_document = canvas_io.has_active_document()
        self._params_button.setEnabled(connected and not busy)
        self._img2img_button.setEnabled(connected and not busy and has_document)
        self._inpaint_button.setEnabled(connected and not busy and has_document)
        self._cancel_button.setEnabled(connected and busy)
        document_tip = "" if has_document else "请先打开 Krita 文档"
        self._img2img_button.setToolTip(document_tip)
        self._inpaint_button.setToolTip(document_tip)

    def _localized_error(self, message: Dict[str, Any]) -> str:
        code = str(message.get("code") or "")
        translations = {
            "invalid_request": "请求参数无效",
            "unauthorized_bridge_client": "桥接客户端尚未认证",
            "unsupported_message": "当前插件消息不受支持",
            "auth_failed": "认证失败，请在 Launcher 中重新登录",
            "insufficient_anlas": "Anlas 不足，请检查账户余额",
            "rate_limited": "请求过于频繁，请稍后重试",
            "timeout": "网络超时，请稍后重试",
            "stream_interrupted": "生成流中断",
            "streaming_unsupported": "当前生成模式不支持流式预览",
            "server_error": "NovelAI 服务返回错误",
            "busy": "Launcher 正在生成，请等待当前任务结束",
            "empty_mask": "蒙版为空，请先标记重绘区域",
            "payload_too_large": "画布数据过大，无法通过 V1 桥接发送",
            "unsupported_document_format": "当前 Krita 文档格式暂不支持写回",
        }
        return translations.get(code, "请求失败")

    def _localized_local_error(self, error: Exception) -> str:
        text = str(error)
        lower = text.lower()
        if "no active krita document" in lower:
            return "请先打开 Krita 文档"
        if "create a krita selection before inpaint" in lower:
            return "请先标记重绘区域"
        if "inpaint mask is empty" in lower:
            return "蒙版为空，请先标记重绘区域"
        if "canvas is too small" in lower:
            return "画布太小，至少需要 64x64"
        if "canvas is too large" in lower:
            return "画布过大，V1 桥接最大支持 4096x4096"
        if "unsupported" in lower and "document" in lower:
            return "当前 Krita 文档格式暂不支持写回"
        if "failed to add preview layer" in lower:
            return "Krita 预览层写入失败，已跳过本帧"
        return text
