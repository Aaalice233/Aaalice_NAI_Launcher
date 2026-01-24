# Icon Usage Guidelines for Developers

**Last Updated:** 2026-01-24
**Related Task:** 002-svg-nai (Fix Material Icons Rendering)

---

## Overview

This guide provides best practices for using Flutter's Material Icons in the NAI Launcher application. Following these guidelines ensures icons render correctly with visible glyphs across all 16 theme presets and prevent the "color block" rendering issue.

## Quick Reference

```dart
// ✅ CORRECT: Icon with theme-aware color
Icon(
  Icons.add,
  color: theme.colorScheme.onPrimary,  // High contrast
)

// ✅ CORRECT: Icon inheriting from iconTheme
Icon(Icons.add)  // Uses theme.iconTheme.color

// ❌ AVOID: Icon with color matching its background
Container(
  color: theme.colorScheme.primaryContainer,
  child: Icon(
    Icons.star,
    color: theme.colorScheme.primary,  // May blend with background!
  ),
)
```

---

## Icon Color Inheritance Chain

Understanding how Flutter determines icon colors is critical for avoiding rendering issues.

### For Icons Without Explicit Color

```dart
Icon(Icons.add)
```

**Color resolution:**
1. `Theme.of(context).iconTheme.color` (if set)
2. `ColorScheme.onSurface` (if iconTheme not set)
3. Falls back to black (87% opacity) by default

**Current Implementation:** `ThemeComposer` sets `iconTheme.color` to `ColorScheme.onPrimary` (lines 112-115 of `theme_composer.dart`)

### For Icons With Explicit Color

```dart
Icon(
  Icons.star,
  color: theme.colorScheme.primary,
)
```

**Color resolution:** Uses the explicitly provided color, ignores theme defaults.

---

## Proper Icon Usage Patterns

### Pattern 1: Standard Icon (Inherits from Theme)

**Use when:** Icon should adapt to theme automatically

```dart
// No color specified - inherits from iconTheme
Icon(Icons.add)

// With size
Icon(
  Icons.settings,
  size: 24,
)
```

**When to use:**
- Navigation icons
- Button icons where contrast is handled by container
- Icons in lists or cards

### Pattern 2: Themed Icon (Explicit Theme Color)

**Use when:** Icon should use a specific theme color

```dart
Icon(
  Icons.favorite,
  color: theme.colorScheme.primary,
)

// High contrast variant
Icon(
  Icons.check,
  color: theme.colorScheme.onPrimary,
)
```

**When to use:**
- Interactive elements (buttons, touch targets)
- Icons needing semantic meaning (favorite, delete, etc.)
- Emphasized icons

### Pattern 3: Colored Icon (Hardcoded Color)

**Use when:** Icon needs a fixed color regardless of theme

```dart
// WARNING: Use sparingly - breaks theme consistency
Icon(
  Icons.error,
  color: Colors.red,
)

Icon(
  Icons.success,
  color: Colors.green,
)
```

**When to use:**
- Status indicators (error, success, warning)
- Brand-specific icons
- Debugging/development

---

## Common Pitfalls to Avoid

### Pitfall 1: Color Blending with Background

**Problem:** Icon color matches or blends with container background

```dart
// ❌ WRONG: May be invisible
Container(
  color: theme.colorScheme.primaryContainer,
  child: Icon(
    Icons.star,
    color: theme.colorScheme.primary,  // Can blend!
  ),
)
```

**Solution:** Use contrasting colors

```dart
// ✅ CORRECT: High contrast
Container(
  color: theme.colorScheme.primaryContainer,
  child: Icon(
    Icons.star,
    color: theme.colorScheme.onPrimaryContainer,  // Contrast!
  ),
)

// ✅ ALSO CORRECT: Inherit from iconTheme
Container(
  color: theme.colorScheme.primaryContainer,
  child: Icon(Icons.star),  // Uses theme.iconTheme.color
)
```

**Root Cause:** In this app's history, missing `primaryContainer` definitions in 15/16 theme presets caused Flutter to calculate `primaryContainer` from `primary`, resulting in insufficient contrast.

### Pitfall 2: Missing Icon Theme

**Problem:** `ThemeData` doesn't set `iconTheme`, causing inconsistent colors

**Solution (Already Implemented):** `ThemeComposer` sets `iconTheme` globally:

```dart
// lib/presentation/themes/core/theme_composer.dart:112-115
iconTheme: IconThemeData(
  color: colorScheme.onPrimary,  // High contrast default
  size: 24,
),
```

**Impact:** All `Icon()` widgets without explicit colors inherit `onPrimary`, ensuring good visibility.

### Pitfall 3: Ignoring Dark Mode

**Problem:** Icon color works in light theme but invisible in dark theme

```dart
// ❌ WRONG: Fails in dark mode
Icon(
  Icons.search,
  color: Colors.black,  // Invisible on dark backgrounds!
)
```

**Solution:** Use theme colors

```dart
// ✅ CORRECT: Adapts to theme
Icon(
  Icons.search,
  color: theme.colorScheme.onSurface,  // Light in dark mode, dark in light
)

// ✅ ALSO CORRECT: Let theme handle it
Icon(Icons.search)  // Inherits appropriate color
```

---

## Theme-Aware Color Selection

### Safe Color Pairs for Icons

| Icon Color | Background Color | Contrast | Use Case |
|------------|------------------|----------|----------|
| `primary` | `surface` | ⚠️ Medium | Standard icons |
| `onPrimary` | `primary` | ✅ High | Icons on colored buttons |
| `onPrimaryContainer` | `primaryContainer` | ✅ High | Icons in primary containers |
| `onSurface` | `surface` | ✅ High | General icons |
| `onSurfaceVariant` | `surfaceVariant` | ✅ High | Subtle icons |

### Forbidden Color Combinations

| Icon Color | Background Color | Why It Fails |
|------------|------------------|--------------|
| `primary` | `primaryContainer` | May blend (unless explicit) |
| `primary` | `primary` | Invisible (same color) |
| `onSurface` | `onSurface` | Invisible (same color) |

---

## Windows-Specific Considerations

### Material Icons Font Bundling

The Windows build automatically bundles the Material Icons font from the Flutter SDK.

**Location:** `E:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf`

**Verification:**
```bash
# Verify font is bundled in release build
E:\flutter\bin\flutter.bat build windows --release
find build/windows/Runner/Release -name "*.ttf" -o -name "*.otf" | grep -i material
```

**Important:** No manual font configuration needed. Ensure `pubspec.yaml` contains:

```yaml
flutter:
  uses-material-design: true
```

### High DPI/Scaling

Windows supports display scaling (125%, 150%, 200%). Icons render correctly at all scales when using:
- Logical sizes (24, 32, 48, 64)
- Theme colors instead of hardcoded values

---

## Icon Size Guidelines

### Standard Icon Sizes

| Size | Use Case | Example |
|------|----------|---------|
| 16px | Small inline icons | Text decorations |
| 24px | Standard size (default) | Buttons, list items |
| 32px | Medium emphasis | Section headers |
| 48px | Large emphasis | Empty states, featured content |
| 64px+ | Hero icons | Onboarding, splash screens |

**Current Default:** `theme.iconTheme.size` is set to 24px (line 114 of `theme_composer.dart`)

### Size Best Practices

```dart
// ✅ CORRECT: Use standard sizes
Icon(Icons.add, size: 24)
Icon(Icons.check, size: 48)

// ❌ AVOID: Arbitrary sizes
Icon(Icons.star, size: 27)  // Non-standard
```

---

## Testing Icon Visibility

### Manual Verification

1. **Run the app:** `E:\flutter\bin\flutter.bat run -d windows`
2. **Navigate to screens with icons**
3. **Check icon visibility:**
   - Icon glyph is clearly visible (not just a colored block)
   - Icon contrasts with background
   - Icon is not clipped or overlapping
4. **Test across themes:**
   - Switch between all 16 theme presets
   - Test both light and dark modes (where applicable)

### Automated Testing

Use the integration test for icon rendering:

```bash
E:\flutter\bin\flutter.bat test test/integration/icon_rendering_test.dart
```

**What it verifies:**
- Material Icons font loads correctly
- Icons render with visible glyphs (not color blocks)
- Icons work in light and dark themes
- Critical icons (Icons.auto_awesome, Icons.add) render properly

---

## Code Examples from Fix Implementation

### Example 1: Login Screen App Icon

**Location:** `lib/presentation/screens/auth/login_screen.dart` (around line 278)

**Before (BROKEN):**
```dart
Container(
  decoration: BoxDecoration(
    color: theme.colorScheme.primaryContainer,  // Undefined in 15/16 themes!
  ),
  child: Icon(
    Icons.auto_awesome,
    color: theme.colorScheme.primary,  // Blends with primaryContainer!
  ),
)
```

**After (FIXED):**
```dart
// Approach 1: Use onPrimaryContainer for contrast
Container(
  decoration: BoxDecoration(
    color: theme.colorScheme.primaryContainer,
  ),
  child: Icon(
    Icons.auto_awesome,
    color: theme.colorScheme.onPrimaryContainer,  // High contrast!
  ),
)

// Approach 2: Let iconTheme handle color
Container(
  decoration: BoxDecoration(
    color: theme.colorScheme.primaryContainer,
  ),
  child: Icon(Icons.auto_awesome),  // Uses theme.iconTheme.color
)
```

### Example 2: Add Account Button Icon

**Location:** `lib/presentation/screens/auth/login_screen.dart` (around line 716)

**Before (MAY BLEND):**
```dart
TextButton.icon(
  onPressed: () => _showAddAccountDialog(context),
  icon: Icon(Icons.add),  // Inherits from iconTheme
  label: Text(context.l10n.auth_addAccount),
)
```

**After (NO CHANGE NEEDED - iconTheme handles it):**
```dart
// Still works - ThemeComposer sets iconTheme.color to onPrimary
TextButton.icon(
  onPressed: () => _showAddAccountDialog(context),
  icon: Icon(Icons.add),  // Inherits high-contrast color
  label: Text(context.l10n.auth_addAccount),
)
```

---

## Creating New Theme Presets

When adding a new theme preset, **always define these colors explicitly** to prevent icon visibility issues:

### Required ColorScheme Properties

```dart
ColorScheme lightScheme = const ColorScheme.light(
  // Required for icon containers
  primary: Color(0xFF......),
  primaryContainer: Color(0xFF......),  // ✅ MANDATORY for icon containers
  onPrimaryContainer: Color(0xFF......), // ✅ MANDATORY for icons on primaryContainer

  // Required for general icon visibility
  onSurface: Color(0xFF......),
  surface: Color(0xFF......),

  // ... other colors
);
```

### Contrast Requirements

Ensure **minimum 3:1 contrast ratio** between:
- `primary` and `primaryContainer`
- `onPrimaryContainer` and `primaryContainer`
- `onSurface` and `surface`

**Reference:** MaterialYouPalette is the only theme with explicit `primaryContainer` - use it as a template.

---

## Quick Checklist for Adding Icons

Before committing code with new `Icon()` widgets:

- [ ] Icon uses theme color (not hardcoded) unless intentionally fixed color
- [ ] Icon color contrasts with its background
- [ ] Icon size uses standard value (16, 24, 32, 48, 64)
- [ ] Icon works in both light and dark themes (if applicable)
- [ ] Icon not in `primaryContainer` with `primary` color (use `onPrimaryContainer`)
- [ ] If custom color needed, add comment explaining why

---

## Debugging Icon Issues

### Icon appears as "color block" (invisible glyph)

**Symptoms:** Container visible, icon shape not visible

**Diagnosis:**
```dart
// Temporary: Add contrasting color to confirm blending
Icon(
  Icons.your_icon,
  color: Colors.red,  // High contrast test
)

// If icon becomes visible with Colors.red, it's a color blending issue
```

**Solutions:**
1. Use `theme.iconTheme` (let theme handle color)
2. Use `theme.colorScheme.onPrimaryContainer` for icons in `primaryContainer`
3. Use `theme.colorScheme.onSurface` for icons on surfaces
4. Define `primaryContainer` in theme palette if missing

### Icon not rendering at all

**Symptoms:** No icon, no colored block

**Diagnosis:**
```dart
// Check Material Icons font is bundled
// Run: flutter doctor -v
// Verify: pubspec.yaml has "uses-material-design: true"
```

**Solutions:**
1. Run `flutter clean` and rebuild
2. Verify `pubspec.yaml` configuration
3. Check icon name is correct (case-sensitive)
4. Try using `Icons.help` as a test

---

## Related Documentation

- **Root Cause Analysis:** `.auto-claude/specs/002-svg-nai/ROOT_CAUSE_ANALYSIS.md` - Deep dive into the color blending issue
- **Theme System:** `lib/presentation/themes/core/theme_composer.dart` - Icon theme configuration
- **Material Icons:** https://api.flutter.dev/flutter/material/Icons-class.html - Available icons
- **ColorScheme:** https://api.flutter.dev/flutter/material/ColorScheme-class.html - Theme color definitions

---

## Summary

**Key Takeaways:**

1. ✅ **Let theme handle colors** when possible - use `Icon(Icons.add)` without explicit color
2. ✅ **Use contrasting colors** - `onPrimaryContainer` on `primaryContainer`, not `primary` on `primaryContainer`
3. ✅ **Test across themes** - verify icons render correctly in all 16 presets
4. ✅ **Define container colors** - always set `primaryContainer` explicitly in theme palettes
5. ✅ **Prefer theme colors** - `theme.colorScheme.*` instead of hardcoded `Colors.*`

**Remember:** The app's iconTheme is configured to use `onPrimary` by default, providing good contrast for most cases. Only override this when you have a specific semantic or design reason.

---

**Questions?** Refer to the root cause analysis for historical context on why these guidelines exist.
