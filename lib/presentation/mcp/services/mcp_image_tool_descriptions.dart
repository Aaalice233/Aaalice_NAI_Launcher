const _imageContract =
    'Images are returned directly as full-resolution MCP ImageContent, not '
    'thumbnails. ImageContent is data, not confirmation of visible display: '
    'clients such as Codex desktop may hide it in collapsed tool details. '
    'For inline display call display_images and render its display_markdown '
    'in the final answer, not in a code block or as a plain link. Cherry Studio '
    'must use the returned display_url_markdown (HTTP), never a local file path. '
    'Codex desktop should request include_display_file=true and use '
    'display_file_markdown. Both require the client to be on the same machine. '
    'Claude Desktop renders the same image Markdown but reveals it only after '
    'one click, so add display_link_markdown below the image as a clickable '
    'way to open it; that gate is expected and must not be retried. Claude '
    'Code draws no images, so present only display_link_markdown there. '
    'Otherwise forward image '
    'content with the client media renderer or explain how to expand the tool '
    'result. Never claim an image is shown based only on a successful call. '
    'When Protection Mode and Remove all '
    'metadata when copying or dragging are enabled, returned image bytes '
    'are sanitized (including NAI stealth metadata); local originals remain '
    'unchanged. Use resource_ref for later image actions. Original file paths '
    'are never returned; display URLs and optional files contain only the '
    'already prepared outgoing image bytes. HTTP links expire within one hour '
    'and may be revoked sooner on cache eviction, stricter privacy settings or '
    'server shutdown. Retrieve again instead of regenerating. ';

/// Internal read paths and chat visibility promises do not apply to MCP hosts.
const mcpImageToolDescriptions = <String, String>{
  'save_generated_image':
      'Export a generated image resource to one explicit destination_path '
      'inside the configured file scope. The destination must not exist and '
      'its extension must match the prepared image format. This MCP export '
      'follows Protection Mode and Remove all metadata when copying or dragging: '
      'when both are enabled the exported copy is sanitized PNG, including '
      'NAI stealth metadata removal. Use a .png destination in that case. '
      'The result reports metadata_stripped; local gallery originals remain '
      'unchanged. To display images only, prefer display_images instead of '
      'creating another saved copy.',
  'copy_generated_image_to_clipboard':
      'Copy a stable generated-image resource_ref to the system clipboard. '
      'This external mutation follows Protection Mode and Remove all metadata '
      'when copying or dragging, just like MCP image display and export. '
      'The result reports metadata_stripped. Local originals remain unchanged.',
  'generate_image':
      'Synchronous image generation using the current generation page settings. '
      'For ordinary draw requests use this instead of queue_image_task. '
      'count is 1-8 variations of the same prompt and follows the app batch '
      'size; use separate calls for different prompts. Omit width/height to '
      'reuse the page size, or use multiples of 64 up to 4096 per side and '
      '3145728 total pixels (832x1216, 1216x832, or 1024x1024 recommended). '
      'seed is random when omitted or -1, and fixed only for count=1. '
      'source_image enables img2img; mask_image also enables inpaint; both '
      'affect only this call, not the page source panel. Without a source '
      'this is text-to-image. Paid requests return a preparation_id; submit '
      'it with confirmed=true for application approval without regenerating '
      'the preparation. Exact zero-cost requests proceed without confirmation. '
      'New image content is included in this result. $_imageContract',
  'submit_generation':
      'Submit a previously prepared transaction exactly once. Zero-cost '
      'preparations need no confirmed flag. Paid preparations require '
      'confirmed=true and approval in the launcher, not duplicate chat '
      'confirmation. A generate preparation returns the completed images; '
      'a queue preparation returns queue status. $_imageContract',
  'get_recent_images':
      'List the newest saved generation-history images, including queue '
      'outputs, as stable resource_ref handles. limit is required (1-20); '
      'use the exact number the user requests. This call returns metadata '
      'only, not image bytes or local paths. To show the images, call '
      'display_images with the returned references; for analysis use '
      'inspect_images. Neither retrieval call generates images or spends Anlas.',
  'display_images':
      'Retrieve 1-12 images by resource_refs for user-facing display without '
      'generating images or spending Anlas. include_display_url defaults to '
      'true and returns a temporary loopback HTTP URL with per-image access, '
      'not the MCP master token. include_display_file defaults to '
      'false. When true, also prepare reusable local display-cache files and '
      'return display_file_markdown for the final answer. display_markdown '
      'follows the connected client: a clickable display_link_markdown for '
      'clients that draw no images, a local file for Codex, otherwise the HTTP '
      'URL, and display_link_markdown accompanies the image for clients that '
      'gate it behind a click. Both display references are prepared for link '
      'clients regardless of these flags. It does not save new '
      'gallery images or modify originals. Display files require a client '
      'that can read the same machine, not a remote host. '
      '$_imageContract',
  'inspect_images':
      'Retrieve 1-12 images by resource_refs for visual analysis, including '
      'fine details at original resolution. Prefer display_images when the '
      'user asks to see images. The MCP client decides whether inspection '
      'images are visible to the user; the server cannot guarantee privacy '
      'from the client UI. $_imageContract',
};
