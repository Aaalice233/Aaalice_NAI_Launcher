const _imageContract =
    'Returns full-resolution MCP ImageContent and resource_ref. Read top-level '
    'display_markdown from structuredContent or JSON text and embed it in the '
    'final answer, not a code block or plain link. ImageContent alone is not '
    'visible display. Codex uses local display_file_markdown; Cherry Studio '
    'uses HTTP display_url_markdown. Re-fetch only missing, expired or broken '
    'display references, never regenerate. References are same-machine only; '
    'outgoing bytes follow privacy settings, originals are unchanged.';

// Hosts only lift an image out of a tool block that holds a single call.
const _ownTurn =
    ' Give this call its own turn: write text before it and after its result, '
    'or the image stays inside a merged tool block.';

/// Internal read paths and chat visibility promises do not apply to MCP hosts.
const mcpImageToolDescriptions = <String, String>{
  'get_application_context':
      'Read navigation, galleries, queue and compact draft summaries. Not a '
      'generation prerequisite. Use get_generation_settings or get_prompt_state '
      'only when those values are needed. include_draft_details returns full drafts.',
  'prepare_generation':
      'Pass the whole request here: prompt, negative_prompt, width/height, '
      'count, seed, characters and references are one-shot arguments that '
      'leave the launcher page untouched, so do not edit the page first; '
      'omitted fields inherit the page. Validate and snapshot a generation '
      'without running it. Returns a compact '
      'preparation_id, exact estimated_anlas and next_action. Submit that ID '
      'directly; do not poll status or history while prepared. operation is '
      'generate (waits for images on submission) or queue. Full parameters are '
      'available through inspect_generation_preparation or include_parameters=true. '
      'Without save_path the launcher returns saved_path pointing at its '
      'gallery original; pass save_path (optional .png target, '
      '{index}/{seed}/{id} for batches) only to put a copy inside your own '
      'working directory for inline display.',
  'update_generation_preparation':
      'Replace supplied fields, cancel the old preparation and return a new '
      'compact preparation with its recalculated cost and next_action. '
      'include_parameters=true returns the full snapshot. Does not generate.',
  'queue_image_task':
      'Compatibility queue preparation; prefer prepare_generation(operation=queue). '
      'Without preparation_id this only prepares; follow next_action to submit. '
      'With an ID it enqueues the stored snapshot, without waiting for images. '
      'auto_start controls queue startup AFTER submission, not preparation. '
      'Use only for explicit background/queue requests.',
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
      'Compatibility entry point; prefer prepare_generation then '
      'submit_generation. Without preparation_id this ONLY prepares, even at '
      'zero cost; follow next_action, not status/history polling. With an ID it '
      'submits the stored snapshot; prompt is then unnecessary. Paid submissions '
      'need confirmed=true and launcher approval. count is 1-8 variations of '
      'one prompt. Omitted size/settings inherit the generation page; source_image '
      'and mask_image affect only this request. $_imageContract$_ownTurn',
  'submit_generation':
      'Execute a prepared transaction once. Omit confirmed at exact zero cost; '
      'paid requests need confirmed=true and approval inside the launcher, not '
      'another chat confirmation. generate waits for completion and returns new '
      'images WITH top-level display_markdown; no status/history/display call '
      'is needed when that reference works. queue returns queue status instead. '
      '$_imageContract$_ownTurn',
  'get_recent_images':
      'List saved generation-history resource_ref handles only, newest first; '
      'not image bytes or local paths. limit is required (1-20). Not needed '
      'after a successful submission; prepared transactions have no new images. '
      'Use display_images for requested historical images, inspect_images for analysis.',
  'display_images':
      'Retrieve 1-12 existing resource_refs for display, without generating. '
      'Use for historical images or missing, expired or broken display references. '
      'Codex includes a safe local display file by default; Cherry Studio uses '
      'the default HTTP reference. '
      '$_imageContract$_ownTurn',
  'inspect_images':
      'Retrieve 1-12 existing resource_refs for visual analysis. Do not call '
      'again for images already returned by generation or display. This does '
      'not generate, and client-controlled visibility is not guaranteed. '
      '$_imageContract',
  'create_inpaint_mask':
      'Author an inpaint mask from geometry and store it as a ready draft. '
      'Regions are normalized 0-1 fractions of the source image, so call '
      'inspect_images with its resource_ref first: a source this session has '
      'not received at full resolution is refused, and a reported size or a '
      'display thumbnail does not count. Pass source_ref rather than a bare '
      'path; there is no path-based inspect entry point here. Returns an '
      'overlay preview; check the mask lands on the target before '
      'submit_manual_inpaint_draft, which is what spends Anlas. Re-authoring a '
      'mask is free, so prefer another attempt over submitting a doubtful one.',
};

// MCP hosts read page editors as generation prerequisites; state the split.
const _pageEditSuffix =
    ' Edits the launcher page for the user; not a generation step, pass '
    'values to prepare_generation instead.';
const _pageReadSuffix =
    ' Not needed before prepare_generation unless the user refers to current '
    'page values.';

/// Appended to the chat description rather than replacing it, so the tool
/// itself keeps one source of truth.
const mcpToolDescriptionSuffixes = <String, String>{
  'get_prompt_state': _pageReadSuffix,
  'get_generation_settings': _pageReadSuffix,
  'set_positive_prompt': _pageEditSuffix,
  'set_negative_prompt': _pageEditSuffix,
  'add_character': _pageEditSuffix,
  'update_character': _pageEditSuffix,
  'remove_character': _pageEditSuffix,
  'clear_characters': _pageEditSuffix,
  'reorder_characters': _pageEditSuffix,
  'set_character_layout_mode': _pageEditSuffix,
  'update_generation_settings': _pageEditSuffix,
  'set_generation_source_image': _pageEditSuffix,
  'clear_generation_source_image': _pageEditSuffix,
  'update_generation_source_settings': _pageEditSuffix,
};
