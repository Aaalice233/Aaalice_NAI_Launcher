# Theme Testing Quick Checklist

**Print this or keep open while testing**

---

## Icons to Check on Each Theme

### ✅ Primary Icons (MUST CHECK)
- [ ] **Icons.auto_awesome** (Top header, 80x80 container)
- [ ] **Icons.add** (Add Account button)

### ✅ Secondary Icons (QUICK SAMPLE)
- [ ] **Icons.close** (Dialog close button)
- [ ] **Icons.help_outline** (Troubleshooting)
- [ ] **Icons.login** (Quick Login button)

---

## 16 Theme Presets - Mark as You Go

### Light Mode Testing

| # | Theme | Icons.auto_awesome | Icons.add | Notes |
|---|-------|-------------------|-----------|-------|
| 1 | Minimal Glass | ⬜ | ⬜ | |
| 2 | Social | ⬜ | ⬜ | |
| 3 | Neo Dark | ⬜ | ⬜ | |
| 4 | Material You | ⬜ | ⬜ | |
| 5 | Pro AI | ⬜ | ⬜ | |
| 6 | Brutalist | ⬜ | ⬜ | |
| 7 | Hand Drawn | ⬜ | ⬜ | |
| 8 | Retro | ⬜ | ⬜ | |
| 9 | Apple Light | ⬜ | ⬜ | |
| 10 | Retro Wave | ⬜ | ⬜ | |
| 11 | Grunge Collage | ⬜ | ⬜ | |
| 12 | Fluid Saturated | ⬜ | ⬜ | |
| 13 | Flat Design | ⬜ | ⬜ | |
| 14 | Midnight Editorial | ⬜ | ⬜ | |
| 15 | System | ⬜ | ⬜ | |
| 16 | Zen Minimalist | ⬜ | ⬜ | |

**Mark each box:**
- ✅ = Icon clearly visible (PASS)
- ⚠️ = Icon faint/low contrast (PARTIAL)
- ❌ = Color block, no glyph visible (FAIL)

---

## Dark Mode Testing (if theme supports)

| # | Theme | Icons.auto_awesome | Icons.add | Notes |
|---|-------|-------------------|-----------|-------|
| 1 | Minimal Glass | ⬜ | ⬜ | |
| 2 | Social | ⬜ | ⬜ | |
| 3 | Neo Dark | ⬜ | ⬜ | |
| 4 | Material You | ⬜ | ⬜ | |
| 5 | Pro AI | ⬜ | ⬜ | |
| 6 | Brutalist | ⬜ | ⬜ | |
| 7 | Hand Drawn | ⬜ | ⬜ | |
| 8 | Retro | ⬜ | ⬜ | |
| 9 | Apple Light | ⬜ | ⬜ | |
| 10 | Retro Wave | ⬜ | ⬜ | |
| 11 | Grunge Collage | ⬜ | ⬜ | |
| 12 | Fluid Saturated | ⬜ | ⬜ | |
| 13 | Flat Design | ⬜ | ⬜ | |
| 14 | Midnight Editorial | ⬜ | ⬜ | |
| 15 | System | ⬜ | ⬜ | |
| 16 | Zen Minimalist | ⬜ | ⬜ | |

---

## Quick Decision Guide

### If Icon is Clearly Visible ✅
- Mark ✅ in checklist
- Move to next theme
- No notes needed

### If Icon is Faint/Low Contrast ⚠️
- Mark ⚠️ in checklist
- Add note: "Low contrast" or "Faint"
- Note which icon (auto_awesome or add)
- Continue testing

### If Icon is Color Block (No Glyph) ❌
- Mark ❌ in checklist
- **Take screenshot**
- Note exact theme name and mode
- Note which icon affected
- **Stop and report** (this is a regression)

---

## Summary Totals

After testing complete, count:

**Light Mode:**
- ✅ Pass: ___ / 32 icons (16 themes × 2 primary icons)
- ⚠️ Partial: ___ / 32
- ❌ Fail: ___ / 32

**Dark Mode:**
- ✅ Pass: ___ / 32 icons
- ⚠️ Partial: ___ / 32
- ❌ Fail: ___ / 32

**Overall Result:**
- If ❌ > 0: **REGRESSION** - Fix not working
- If ⚠️ > 5: **NEEDS REFINEMENT** - Contrast too low
- If ✅ ≥ 28/32: **PASS** - Fix working well
- If ✅ = 32/32: **PERFECT** - All icons visible

---

## Troubleshooting

### Icons Still Color Blocks (❌)
1. Verify fix applied: `git log --oneline -3`
2. Check for commit `0184a4f`
3. Restart app completely (no hot reload)
4. Check console for errors

### Icons Faint (⚠️)
1. Expected behavior - some themes have low contrast design
2. Note which themes for possible refinement
3. Check if glyph is visible (even if faint)
4. Differentiate between "faint" and "invisible"

### Can't Switch Themes
1. Check app settings/theme selector
2. Look for theme dropdown or picker
3. May need to navigate to settings page
4. Check app documentation for theme switching

---

## Completion

**When finished:**
1. Count totals above
2. Transfer results to SUBTASK-3-3-THEME-TESTING-GUIDE.md
3. Note any themes with issues
4. Report summary status

**Expected:** All themes should show ✅ (icons visible)

**Time Estimate:** 30-45 minutes for all themes (both modes)

---

*Happy Testing! 🎨*
