# Quick Spec: Fix History Panel Row Overflow

## Task
Fix Flutter RenderFlex overflow errors in history_panel.dart when panel width is extremely narrow (27px).

## Files to Modify
- `lib/presentation/screens/generation/widgets/history_panel.dart` - Fix two Row widgets that overflow

## Change Details

### Fix 1: Header Row (line 52)
The header Row contains: collapse button (24px) + spacer (8px) + Flexible Text + Spacer + IconButtons.
When width is only 27px, this overflows by 5px.

**Solution:** Wrap the middle section (Text + counter + Spacer) in an Expanded widget to ensure it properly shares space, and hide action buttons when width is insufficient by wrapping them in a LayoutBuilder or using `OverflowBar`.

Simpler approach: Remove the `const Spacer()` and wrap the Text section with `Expanded`, and add `overflow: TextOverflow.ellipsis` to the counter text as well.

### Fix 2: Empty State Row (line 217)
Two Expanded EmptyStateCards with a 12px SizedBox between them overflow when total width is 27px.

**Solution:** Use a LayoutBuilder to detect narrow width and switch to Column layout when width < 300px, or wrap the Row in a SingleChildScrollView with scrollDirection horizontal.

## Verification
- [ ] No overflow errors when panel is collapsed to minimum width
- [ ] Header text shows ellipsis when truncated
- [ ] Empty state cards display properly in narrow mode
