# Plan: Zigshell Unification - Replace Noctalia and Zigshell-cairo-pango

## Executive Summary

**Goal:** Deprecate `noctalia` and `zigshell-cairo-pango` external shells by achieving full feature parity with the custom `zigshell-cairo-pango`-based OCWS. Retain multi-shell switcher as fallback during transition, but eventually phase out external dependencies.

**Current State:** Shell modes exist:
- `zigshell-cairo-pango` -- labwc + zigshell-cairo-pango only (merged panel + dock)
- `both` -- labwc + zigshell-cairo-pango (doublepanel) + zigshell-cairo-pango (single binary, two instances)
- `doublepanel` -- labwc + double-panel zigshell-cairo-pango (top status bar + bottom dock/taskbar)
- `minimal` -- labwc + minimal zigshell-cairo-pango
- `noctalia` -- labwc + noctalia shell
- `dms` -- labwc + dankmaterialshell
- `lxqt-*` -- labwc + lxqt-panel variants with zigshell-cairo-pango

Note: the legacy `crystal` mode (crystal-dock) was removed; its role is covered by `zigshell-cairo-pango`.

**Target State:** Single mode -- `ocws` (labwc + zigshell-cairo-pango OCWS only)

---

## Phase 0: Keep Current Modes (NOW)

**Status:** Active -- no changes to runtime behavior

All three modes remain functional. The shell switcher (`toggle-shell`) continues to work. This phase is about planning only.

---

## Phase 1: Feature Gap Analysis

### 1.1 What Zigshell-cairo-pango Provides

| Feature | Zigshell-cairo-pango | OCWS Current | Gap |
|---------|--------------|--------------|-----|
| Dock-style launcher | [x] Pinned app icons | [x] `dock.widget` + `dock-apps.widget` | Done |
| Magnification effect | [x] Mac-like zoom | [ ] Not supported | **NEED** |
| Running app indicators | [x] Dot indicators | [~] Taskbar has focused state | Partial |
| Show desktop | [x] Click action | [x] `showdesktop.widget` | Done |
| Icon rendering | [x] High-res icons | [x] Taskbar icons | Done |

### 1.2 What Noctalia Provides

| Feature | Noctalia | OCWS Current | Gap |
|---------|----------|--------------|-----|
| Top bar | [x] Launcher, workspaces, clock, media, tray, system | [x] Same layout | Done |
| Control center | [x] Toggle panel with WiFi, BT, volume, brightness | [x] `ocws-control-center.widget` | Done |
| Notification daemon | [x] Built-in | [x] `ocws-notify` + `ocws-osd-notify` | Done |
| OSD popups | [x] Volume, brightness, etc. | [x] `ocws-osd-notify` | Done |
| Dock | [x] Optional bottom dock | [x] `dock.widget` | Done |
| Desktop widgets | [x] Clock, weather, etc. | [x] `desktop-*.widget` | Done |
| Lock screen | [x] Built-in blur | [x] `ocws-lock` (swaylock) | Done |
| Weather | [x] API integration | [x] `weather.widget` | Done |
| System monitor | [x] CPU, memory, disk graphs | [x] `ocws-sysmon` | Done |
| Wallpaper management | [x] Transitions, automation | [x] `ocws-wallpaper` | Done |
| Theme engine | [x] Builtin + community | [x] INI-based theme engine | Done |
| Animations | [x] CSS transitions | [~] Basic GTK3 transitions | Partial |
| Glassmorphism | [x] Blur, translucency | [~] CSS-only (no real blur) | Partial |

### 1.3 Critical Gaps to Close

**Must-have for parity:**
1. Dock widget -- Pinned apps with magnification effect (Completed)
2. Desktop widgets -- Floating clock, weather, system stats (Completed)
3. Animation polish -- Smooth hover states, transitions
4. Glassmorphism -- Real blur via gtk-layer-shell (if possible)

**Nice-to-have:**
- Live lyrics display
- AI assistant integration
- Advanced applets (crypto, GitHub notifications)

---

## Phase 2: Dock Widget Implementation (COMPLETED)

### 2.1 Requirements

- Pinned application launcher (configurable list)
- Mac-like magnification effect on hover
- Running application indicators (dot or glow)
- Auto-hide option
- Position: bottom (default), top, left, right

### 2.2 Technical Approach

**Option A: Pure zigshell-cairo-pango widget**
- Use `button` widgets with icon images
- CSS `transform: scale()` for magnification (GTK3 supports basic transforms)
- `Exec()` action for launching apps
- Draw running indicators via CSS pseudo-classes

**Option B: C plugin (recommended for magnification)**
- GTK layer shell surface
- Custom rendering for smooth magnification
- Better performance than CSS transforms

**Recommendation**: Start with Option A (zigshell-cairo-pango widget), migrate to Option B if performance is insufficient.

### 2.3 Implementation Steps

1. Create `dock.widget` with pinned app list
2. Add magnification CSS (scale on hover)
3. Add running app detection via `Exec("wmctrl -l")` or wlr-foreign-toplevel
4. Add auto-hide behavior
5. Test with 10+ pinned apps

---

## Phase 3: Desktop Widgets (COMPLETED)

### 3.1 Requirements

- Floating clock (large, centered)
- Weather widget
- System stats (CPU, memory, network)
- Sticky notes (optional)

### 3.2 Technical Approach

**GTK Layer Shell surfaces:**
- Each widget is a separate layer surface
- Position via `zwlr_layer_shell_v1`
- Transparent background
- Draggable (optional)

**zigshell-cairo-pango integration:**
- Widget files with `layer = "background"` or `layer = "overlay"`
- Configurable position and size

### 3.3 Implementation Steps

1. Create `desktop-clock.widget` (large clock, centered)
2. Create `desktop-weather.widget` (weather display)
3. Create `desktop-sysmon.widget` (system stats)
4. Add positioning config to `ocws.config`
5. Add toggle keybinding to show/hide desktop widgets

---

## Phase 4: Animation and Glassmorphism Polish

### 4.1 Animations

**Current**: Basic GTK3 transitions (`transition: all 0.2s ease-in-out`)

**Target**: Smooth, Noctalia-like animations
- Hover state transitions (scale, opacity)
- Popup open/close animations
- Workspace switch animations

**Approach**:
- Use GTK3 `transition` property (already in CSS)
- Add `transition-duration` and `transition-timing-function`
- Test on low-end hardware for performance

### 4.2 Glassmorphism

**Current**: CSS-only translucency (`rgba()` backgrounds)

**Target**: Real blur effect (like Noctalia)

**Approach**:
- `gtk-layer-shell` supports `blur` region
- zigshell-cairo-pango does not expose blur API directly
- **Option A**: Use `ocws-live-bg` for background blur
- **Option B**: Patch zigshell-cairo-pango to support blur (complex)
- **Option C**: Accept CSS-only translucency (simpler, less resource-intensive)

**Recommendation**: Option C (CSS-only) for now. Real blur is complex and may not be worth the effort.

---

## Phase 5: Mode Switcher Cleanup

### 5.1 Current Switcher Scripts

- `toggle-shell` -- Simple switcher (zigshell-cairo-pango/doublepanel/minimal/both/noctalia/dms/lxqt-*)
- `shell-switcher.sh` -- Complex switcher (reads `~/.config/ocws/mode`, defaults to zigshell-cairo-pango)
- `labwc-shell-wrapper` -- Legacy wrapper

### 5.2 Target Switcher

Single script: `ocws-shell` with modes:
- `ocws` -- labwc + zigshell-cairo-pango OCWS (default, recommended)
- `legacy-noctalia` -- labwc + noctalia (deprecated)

### 5.3 Implementation Steps

1. Create `scripts/ocws-shell` with mode selection
2. Update `dotfiles/labwc/autostart` to use `ocws-shell`
3. Deprecate `toggle-shell`, `shell-switcher.sh`, `labwc-shell-wrapper`
4. Remove zigshell-cairo-pango and noctalia from optional dependencies

---

## Phase 6: Deprecation and Removal

### 6.1 Deprecation Timeline

| Month | Action |
|-------|--------|
| Month 1 | Dock widget implemented, desktop widgets beta |
| Month 2 | Animation polish, glassmorphism finalized |
| Month 3 | Mode switcher updated, deprecation warnings added |
| Month 4 | Remove zigshell-cairo-pango from autostart |
| Month 5 | Remove noctalia from autostart |
| Month 6 | Remove legacy modes from switcher |

### 6.2 Removal Checklist

- [ ] Remove `dotfiles/zigshell-cairo-pango/` directory
- [ ] Remove `dotfiles/noctalia/` directory
- [ ] Remove zigshell-cairo-pango from `install-dependencies.sh`
- [ ] Remove noctalia from `install-dependencies.sh`
- [ ] Update `install.sh` to skip legacy configs
- [ ] Update `validate.sh` to check OCWS-only mode
- [ ] Update documentation to reflect single-mode architecture

---

## Phase 7: Testing and Validation

### 7.1 Feature Parity Tests

| Test | Zigshell-cairo-pango | Noctalia | OCWS |
|------|--------------|----------|------|
| Launch app from dock | [x] | N/A | [x] |
| Magnification effect | [x] | N/A | [~] |
| Running app indicator | [x] | N/A | [x] |
| Control center toggle | N/A | [x] | [x] |
| Notification display | N/A | [x] | [x] |
| OSD popup | N/A | [x] | [x] |
| Desktop widget | N/A | [x] | [x] |
| Animation smoothness | [x] | [x] | [~] |

### 7.2 Performance Benchmarks

| Metric | Zigshell-cairo-pango | Noctalia | OCWS Target |
|--------|--------------|----------|-------------|
| Memory usage | ~40MB | ~40MB | <30MB |
| Startup time | ~1s | ~1s | <0.5s |
| CPU usage (idle) | ~1% | ~1% | <1% |
| CPU usage (active) | ~5% | ~5% | <3% |

---

## Risk Mitigation

1. **Keep fallback modes** -- Do not remove zigshell-cairo-pango or noctalia until OCWS reaches parity.
2. **Incremental rollout** -- Implement one feature at a time, test thoroughly.
3. **Performance monitoring** -- Track memory and CPU usage during development.
4. **User feedback** -- Get community input before deprecating popular features.
5. **Documentation** -- Update README, TODOS.md, and user guides.

---

## Success Criteria

- [x] Dock widget with magnification effect
- [x] Desktop widgets (clock, weather, sysmon)
- [ ] Animation polish matching Noctalia
- [ ] Single-mode switcher (`ocws-shell`)
- [ ] Zigshell-cairo-pango-dock and noctalia removed from autostart
- [ ] Performance benchmarks meet targets
- [ ] All existing features preserved

---

## References

- `TODOS.md` -- Phase 1.5: zigshell-cairo-pango Unification
- `dotfiles/noctalia/config.toml` -- Noctalia configuration reference
- `dotfiles/zigshell-cairo-pango/panel_1.conf` -- Zigshell-cairo-pango configuration reference
- `dotfiles/ocws/ocws.config` -- Current OCWS configuration
