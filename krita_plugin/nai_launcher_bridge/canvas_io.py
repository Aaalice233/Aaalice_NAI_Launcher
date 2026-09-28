import os
import math
import tempfile
from pathlib import Path
from typing import Optional

from PyQt5.QtCore import QByteArray, QBuffer, QIODevice
from PyQt5.QtGui import QImage
from krita import InfoObject, Krita


MAX_V1_CANVAS_EDGE = 4096
PREVIEW_LAYER_NAME = "NAI Preview"
FOCUS_PREVIEW_LAYER_NAME = "NAI Focus Preview"
MASK_SOURCE_SELECTION = "selection"
# NovelAI web build d7e955f-production, verified 2026-07-14.
FOCUS_DIMENSION_STEP = 64
FOCUS_TARGET_AREA_PIXELS = 1048576
FOCUS_MAX_REQUEST_AREA_PIXELS = 3145728


def active_document():
    app = Krita.instance()
    if app is None:
        return None
    return app.activeDocument()


def has_active_document() -> bool:
    return active_document() is not None


def export_active_document_png() -> bytes:
    doc = active_document()
    if doc is None:
        raise RuntimeError("No active Krita document")
    _validate_v1_canvas(doc)

    try:
        return _export_projection_png(doc)
    except Exception:
        return _export_document_to_temp_png(doc)


def _export_projection_png(doc) -> bytes:
    # Use Krita's visible projection instead of raw pixel data to avoid
    # color-channel assumptions across document color spaces.
    projection = doc.projection(0, 0, doc.width(), doc.height())
    buffer = QBuffer()
    buffer.open(QIODevice.WriteOnly)
    if not projection.save(buffer, "PNG"):
        raise RuntimeError("Krita failed to encode the visible projection")
    return bytes(buffer.data())


def _export_document_to_temp_png(doc) -> bytes:
    with tempfile.NamedTemporaryFile(delete=False, suffix=".png") as handle:
        path = Path(handle.name)

    try:
        if not doc.exportImage(str(path), InfoObject()):
            raise RuntimeError("Krita failed to export the active document")
        return path.read_bytes()
    finally:
        try:
            path.unlink()
        except OSError:
            pass


def active_selection_rect() -> Optional[dict]:
    rect = active_selection_bounds()
    if rect is None:
        return None
    doc = active_document()
    if doc is None:
        return None
    selection = doc.selection()
    if selection is None:
        return None
    if not _selection_bounds_are_filled(selection, rect["w"], rect["h"]):
        return None
    return rect


def active_selection_bounds() -> Optional[dict]:
    doc = active_document()
    if doc is None:
        return None
    selection = doc.selection()
    if selection is None:
        return None
    width = selection.width()
    height = selection.height()
    if width <= 0 or height <= 0:
        return None
    return {
        "x": selection.x(),
        "y": selection.y(),
        "w": width,
        "h": height,
    }


def export_active_selection_mask_png() -> bytes:
    doc = active_document()
    if doc is None:
        raise RuntimeError("No active Krita document")
    _validate_v1_canvas(doc)
    selection = doc.selection()
    if selection is None or selection.width() <= 0 or selection.height() <= 0:
        raise RuntimeError("Create a Krita selection before inpaint")

    image = QImage(doc.width(), doc.height(), QImage.Format_Grayscale8)
    image.fill(0)
    has_repaint_pixels = False
    for y in range(selection.y(), selection.y() + selection.height()):
        for x in range(selection.x(), selection.x() + selection.width()):
            if _selection_pixel_value(selection, x, y) > 0:
                image.setPixel(x, y, 255)
                has_repaint_pixels = True

    if not has_repaint_pixels:
        raise RuntimeError("Inpaint mask is empty")

    buffer = QBuffer()
    buffer.open(QIODevice.WriteOnly)
    image.save(buffer, "PNG")
    return bytes(buffer.data())


def export_inpaint_mask_png(source: str = MASK_SOURCE_SELECTION) -> bytes:
    if source == MASK_SOURCE_SELECTION:
        return export_active_selection_mask_png()
    raise RuntimeError(f"Unknown inpaint mask source: {source}")


def write_png_preview(image_png: bytes) -> None:
    if not _write_png_as_layer(image_png, PREVIEW_LAYER_NAME, replace_existing=True):
        raise RuntimeError("Krita failed to add preview layer")


def remove_preview_layer() -> None:
    doc = active_document()
    if doc is not None:
        _remove_layers_named(doc, PREVIEW_LAYER_NAME)
        doc.refreshProjection()


def remove_focus_preview_layer() -> None:
    doc = active_document()
    if doc is not None:
        _remove_layers_named(doc, FOCUS_PREVIEW_LAYER_NAME)
        doc.refreshProjection()


def focus_context_rect_for_selection(
    selection_rect: dict,
    canvas_width: int,
    canvas_height: int,
    minimum_context_pixels: int,
) -> dict:
    padding = max(16, min(192, int(round(minimum_context_pixels))))
    width = max(1, min(canvas_width, int(selection_rect["w"]) + padding * 2))
    height = max(1, min(canvas_height, int(selection_rect["h"]) + padding * 2))
    center_x = int(selection_rect["x"]) + int(selection_rect["w"]) / 2
    center_y = int(selection_rect["y"]) + int(selection_rect["h"]) / 2
    x = int(center_x - width / 2)
    y = int(center_y - height / 2)
    x = max(0, min(canvas_width - width, x))
    y = max(0, min(canvas_height - height, y))
    return {"x": x, "y": y, "w": width, "h": height}


def focus_request_size_for_context(context_rect: dict) -> dict:
    width = max(1, int(context_rect["w"]))
    height = max(1, int(context_rect["h"]))
    area = width * height
    upscale = area <= FOCUS_TARGET_AREA_PIXELS
    scale = math.sqrt(FOCUS_TARGET_AREA_PIXELS / area) if upscale else 1.0
    request_width = _floor_focus_dimension(int(math.floor(width * scale)))
    request_height = _floor_focus_dimension(int(math.floor(height * scale)))
    area_limit = (
        FOCUS_TARGET_AREA_PIXELS if upscale else FOCUS_MAX_REQUEST_AREA_PIXELS
    )
    if request_width * request_height > area_limit:
        if request_width >= request_height:
            request_width = _largest_focus_dimension_for_area(
                area_limit, request_height
            )
        else:
            request_height = _largest_focus_dimension_for_area(
                area_limit, request_width
            )
    return {
        "w": request_width,
        "h": request_height,
        "mode": "upscale_to_target" if upscale else "preserve_crop",
    }


def constrain_focus_selection_rect(
    selection_rect: dict,
    canvas_width: int,
    canvas_height: int,
    minimum_context_pixels: int,
) -> dict:
    original = _clamp_selection_rect(selection_rect, canvas_width, canvas_height)
    original_context = focus_context_rect_for_selection(
        original,
        canvas_width,
        canvas_height,
        minimum_context_pixels,
    )
    if _rect_area(original_context) <= FOCUS_MAX_REQUEST_AREA_PIXELS:
        return original

    center_x = original["x"] + original["w"] / 2
    center_y = original["y"] + original["h"] / 2
    low = 0.0
    high = 1.0
    best = _centered_selection_rect(
        center_x,
        center_y,
        3,
        3,
        canvas_width,
        canvas_height,
    )
    for _ in range(48):
        scale = (low + high) / 2
        width = max(3, int(round(original["w"] * scale)))
        height = max(3, int(round(original["h"] * scale)))
        candidate = _centered_selection_rect(
            center_x,
            center_y,
            width,
            height,
            canvas_width,
            canvas_height,
        )
        context = focus_context_rect_for_selection(
            candidate,
            canvas_width,
            canvas_height,
            minimum_context_pixels,
        )
        if _rect_area(context) <= FOCUS_MAX_REQUEST_AREA_PIXELS:
            low = scale
            best = candidate
        else:
            high = scale
    return best


def constrain_active_focus_selection(minimum_context_pixels: int) -> Optional[dict]:
    doc = active_document()
    selection_rect = active_selection_bounds()
    if doc is None or selection_rect is None:
        return None
    constrained = constrain_focus_selection_rect(
        selection_rect,
        doc.width(),
        doc.height(),
        minimum_context_pixels,
    )
    if constrained == selection_rect:
        return constrained

    selection = _create_krita_selection()
    selection.select(
        constrained["x"],
        constrained["y"],
        constrained["w"],
        constrained["h"],
        255,
    )
    doc.setSelection(selection)
    doc.refreshProjection()
    return constrained


def active_focus_geometry(minimum_context_pixels: int) -> Optional[dict]:
    doc = active_document()
    selection_rect = constrain_active_focus_selection(minimum_context_pixels)
    if doc is None or selection_rect is None:
        return None
    context_rect = focus_context_rect_for_selection(
        selection_rect,
        doc.width(),
        doc.height(),
        minimum_context_pixels,
    )
    return {
        "inner": selection_rect,
        "outer": context_rect,
        "request": focus_request_size_for_context(context_rect),
    }


def active_focus_preview_rects(minimum_context_pixels: int) -> Optional[tuple[dict, dict]]:
    geometry = active_focus_geometry(minimum_context_pixels)
    if geometry is None:
        return None
    return geometry["inner"], geometry["outer"]


def write_focus_preview(minimum_context_pixels: int) -> tuple[dict, dict]:
    doc = active_document()
    rects = active_focus_preview_rects(minimum_context_pixels)
    if doc is None or rects is None:
        raise RuntimeError("Create a Krita selection before inpaint")
    selection_rect, context_rect = rects
    _write_rect_outline_layer(
        doc,
        inner_rect=selection_rect,
        outer_rect=context_rect,
        name=FOCUS_PREVIEW_LAYER_NAME,
    )
    return rects


def write_png_result(image_png: bytes, name: str) -> str:
    remove_preview_layer()
    remove_focus_preview_layer()
    return write_png_as_new_document(image_png, name)


def write_png_as_new_document(image_png: bytes, name: str) -> str:
    try:
        if _write_png_as_layer(image_png, name):
            return "layer"
    except Exception:
        pass

    with tempfile.NamedTemporaryFile(delete=False, suffix=".png") as handle:
        path = Path(handle.name)
        handle.write(image_png)

    try:
        doc = Krita.instance().openDocument(str(path))
        if doc is None:
            raise RuntimeError("Krita failed to open returned image")
        doc.setFileName("")
        if hasattr(doc, "setName"):
            doc.setName(name)
        window = Krita.instance().activeWindow()
        if window is None:
            raise RuntimeError("No active Krita window")
        window.addView(doc)
        return "document"
    finally:
        try:
            os.remove(str(path))
        except OSError:
            pass


def _write_png_as_layer(
    image_png: bytes,
    name: str,
    *,
    replace_existing: bool = False,
) -> bool:
    doc = active_document()
    if doc is None:
        return False
    _validate_v1_canvas(doc)

    image = QImage()
    if not image.loadFromData(QByteArray(image_png), "PNG"):
        return False
    image = image.convertToFormat(QImage.Format_RGBA8888)

    width = image.width()
    height = image.height()
    if width <= 0 or height <= 0:
        return False
    if width != doc.width() or height != doc.height():
        return False

    if replace_existing:
        _remove_layers_named(doc, name)
        _wait_for_done(doc)

    byte_count = (
        image.sizeInBytes() if hasattr(image, "sizeInBytes") else image.byteCount()
    )
    bits = image.bits()
    bits.setsize(byte_count)

    layer = doc.createNode(name, "paintLayer")
    layer.setPixelData(
        QByteArray(_rgba8888_to_krita_bgra(bits.asstring(byte_count))),
        0,
        0,
        width,
        height,
    )
    if not doc.rootNode().addChildNode(layer, None):
        return False
    _wait_for_done(doc)
    doc.refreshProjection()
    return True


def _write_rect_outline_layer(
    doc,
    *,
    inner_rect: dict,
    outer_rect: dict,
    name: str,
) -> None:
    width = doc.width()
    height = doc.height()
    raw = bytearray(width * height * 4)
    _draw_rect_outline_bgra(
        raw,
        width,
        height,
        outer_rect,
        # Cyan in BGRA.
        (255, 190, 0, 210),
        thickness=2,
    )
    _draw_rect_outline_bgra(
        raw,
        width,
        height,
        inner_rect,
        # White in BGRA.
        (255, 255, 255, 235),
        thickness=2,
    )
    _remove_layers_named(doc, name)
    _wait_for_done(doc)
    layer = doc.createNode(name, "paintLayer")
    layer.setPixelData(QByteArray(bytes(raw)), 0, 0, width, height)
    if not doc.rootNode().addChildNode(layer, None):
        raise RuntimeError("Krita failed to add preview layer")
    _wait_for_done(doc)
    doc.refreshProjection()


def _draw_rect_outline_bgra(
    raw: bytearray,
    canvas_width: int,
    canvas_height: int,
    rect: dict,
    color: tuple[int, int, int, int],
    *,
    thickness: int,
) -> None:
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
                _set_bgra(raw, canvas_width, px, top_y, color)
        if bottom_y >= y:
            for px in range(left_x, right_x + 1):
                _set_bgra(raw, canvas_width, px, bottom_y, color)
        if left_x <= right:
            for py in range(top_y, bottom_y + 1):
                _set_bgra(raw, canvas_width, left_x, py, color)
        if right_x >= x:
            for py in range(top_y, bottom_y + 1):
                _set_bgra(raw, canvas_width, right_x, py, color)


def _set_bgra(
    raw: bytearray,
    canvas_width: int,
    x: int,
    y: int,
    color: tuple[int, int, int, int],
) -> None:
    offset = (y * canvas_width + x) * 4
    raw[offset : offset + 4] = bytes(color)


def _rgba8888_to_krita_bgra(raw: bytes) -> bytes:
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


def _validate_v1_canvas(doc) -> None:
    if doc.width() < 64 or doc.height() < 64:
        raise RuntimeError("Canvas is too small for NAI Launcher bridge")
    if doc.width() > MAX_V1_CANVAS_EDGE or doc.height() > MAX_V1_CANVAS_EDGE:
        raise RuntimeError(
            "Canvas is too large for bridge V1; use a canvas up to 4096x4096"
        )


def _selection_bounds_are_filled(selection, width: int, height: int) -> bool:
    raw = bytes(selection.pixelData(selection.x(), selection.y(), width, height))
    required = width * height
    if len(raw) < required:
        return False
    return all(value > 0 for value in raw[:required])


def _selection_pixel_value(selection, x: int, y: int) -> int:
    raw = bytes(selection.pixelData(x, y, 1, 1))
    if not raw:
        return 0
    return raw[0]


def _remove_layers_named(doc, name: str) -> None:
    root = doc.rootNode()
    stack = list(root.childNodes())
    while stack:
        node = stack.pop()
        node_name = node.name() if hasattr(node, "name") else ""
        if node_name == name:
            _remove_node(root, node)
            continue
        if hasattr(node, "childNodes"):
            stack.extend(node.childNodes())


def _remove_node(root, node) -> None:
    if hasattr(node, "remove"):
        node.remove()
        return
    if hasattr(root, "removeChildNode"):
        root.removeChildNode(node)


def _wait_for_done(doc) -> None:
    if hasattr(doc, "waitForDone"):
        doc.waitForDone()


def _floor_focus_dimension(value: int) -> int:
    return max(FOCUS_DIMENSION_STEP, (value // FOCUS_DIMENSION_STEP) * FOCUS_DIMENSION_STEP)


def _largest_focus_dimension_for_area(area_limit: int, other_dimension: int) -> int:
    grid_units = area_limit // other_dimension // FOCUS_DIMENSION_STEP
    return max(FOCUS_DIMENSION_STEP, grid_units * FOCUS_DIMENSION_STEP)


def _rect_area(rect: dict) -> int:
    return int(rect["w"]) * int(rect["h"])


def _clamp_selection_rect(rect: dict, canvas_width: int, canvas_height: int) -> dict:
    x = max(0, min(canvas_width - 1, int(rect["x"])))
    y = max(0, min(canvas_height - 1, int(rect["y"])))
    width = max(1, min(canvas_width - x, int(rect["w"])))
    height = max(1, min(canvas_height - y, int(rect["h"])))
    return {"x": x, "y": y, "w": width, "h": height}


def _centered_selection_rect(
    center_x: float,
    center_y: float,
    width: int,
    height: int,
    canvas_width: int,
    canvas_height: int,
) -> dict:
    resolved_width = max(1, min(canvas_width, int(width)))
    resolved_height = max(1, min(canvas_height, int(height)))
    x = int(math.floor(center_x - resolved_width / 2))
    y = int(math.floor(center_y - resolved_height / 2))
    x = max(0, min(canvas_width - resolved_width, x))
    y = max(0, min(canvas_height - resolved_height, y))
    return {"x": x, "y": y, "w": resolved_width, "h": resolved_height}


def _create_krita_selection():
    from krita import Selection

    return Selection()
