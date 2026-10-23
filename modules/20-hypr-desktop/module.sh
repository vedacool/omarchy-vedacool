MOD_DESC="Windows-like Hyprland: float-by-default, snap, resize-on-border, SUPER+M/N, auto-hide dock, scale 1/1"
MOD_SUDO="no"
MOD_DEPS=""
MOD_REQUIRES="hyprctl nwg-dock-hyprland"
EXPORT_PATHS=".local/bin/window-maximise-toggle .local/bin/window-minimise-watch"

# The animations-off + scale 1/1 tweaks were tuned for a 1366x768 laptop with an
# aging Radeon HD 6730M. They are safe anywhere but only matter on weak GPUs.
check() {
  if [[ -n ${PF_GPU:-} ]]; then
    if grep -qi 'radeon\|amd' <<<"$PF_GPU"; then ok "GPU is Radeon/AMD — animations-off tuning is relevant"
    else warn "GPU is '$PF_GPU' — the animations-off/scale-1 tweaks were for an old Radeon; harmless but you may prefer defaults"; fi
  fi
  local sh; sh=$(xrandr 2>/dev/null | grep -oP 'current \K[0-9]+ x [0-9]+' | head -1)
  [[ -n $sh ]] && echo "  info   display $sh (scale 1/1 suits small/low-DPI screens)"
}

apply() {
  # window-maximise/minimise helper scripts (SUPER+M / SUPER+N)
  copy_payload ".local/bin/window-maximise-toggle" && act chmod +x "$HOME/.local/bin/window-maximise-toggle"
  copy_payload ".local/bin/window-minimise-watch"  && act chmod +x "$HOME/.local/bin/window-minimise-watch"
  ok "window-maximise-toggle / window-minimise-watch installed"

  ensure_block "$HYPR/hyprland.lua" 'o\.window\("\.\*",[[:space:]]*\{[[:space:]]*float[[:space:]]*=[[:space:]]*true' "all windows float (SUPER+T tiles one)" \
'-- Windows-style: every window floats. SUPER+T toggles a window back to tiled.
o.window(".*", { float = true })'
  ensure_block "$HYPR/hyprland.lua" 'o\.window\(\{[[:space:]]*tag[[:space:]]*=[[:space:]]*"chromium-based-browser"[[:space:]]*\},[[:space:]]*\{[[:space:]]*float' "Chrome floats too" \
'-- Omarchy tiles chromium-based-browser by default; float it like everything else.
o.window({ tag = "chromium-based-browser" }, { float = true })'

  ensure_block "$HYPR/looknfeel.lua" 'no_warps[[:space:]]*=[[:space:]]*true' "pointer stays put on focus/workspace change" \
'hl.config({ cursor = { no_warps = true, warp_on_change_workspace = 0 } })'
  ensure_block "$HYPR/looknfeel.lua" '^[[:space:]]*enabled[[:space:]]*=[[:space:]]*false' "animations disabled (old-GPU tuning)" \
'hl.config({ animations = { enabled = false } })'
  ensure_block "$HYPR/looknfeel.lua" '^[[:space:]]*snap[[:space:]]*=[[:space:]]*\{' "magnetic window edge-snapping" \
'hl.config({ general = { snap = { enabled = true } } })'
  ensure_block "$HYPR/looknfeel.lua" 'resize_on_border[[:space:]]*=[[:space:]]*true' "border-drag resize" \
'hl.config({ general = { resize_on_border = true } })'

  ensure_block "$HYPR/input.lua" 'numlock_by_default[[:space:]]*=[[:space:]]*false' "NumLock off at start" \
'hl.config({ input = { numlock_by_default = false } })'

  ensure_block "$HYPR/autostart.lua" 'nwg-dock-hyprland -d -i 24' "auto-hiding dock at startup" \
'o.launch_on_start("nwg-dock-hyprland -d -i 24 -lp start -c '"'"'omarchy-menu toggle'"'"'")'
  ensure_block "$HYPR/autostart.lua" 'window-minimise-watch' "minimised-window restore watcher" \
'o.launch_on_start("'"$HOME"'/.local/bin/window-minimise-watch")'

  ensure_block "$HYPR/bindings.lua" 'window-maximise-toggle' "SUPER+M maximise / SUPER+N minimise" \
'o.bind("SUPER + M", "Maximise", "'"$HOME"'/.local/bin/window-maximise-toggle")
o.bind("SUPER + N", "Minimise", hl.dsp.window.move({ workspace = "special:minimized", follow = false }))'

  # Display scale 1/1 — only rewrite Omarchy'\''s default 2/"auto".
  local mon="$HYPR/monitors.lua"
  if [[ -f $mon ]]; then
    if grep -qE '^local omarchy_gdk_scale = 1$' "$mon" && grep -qE '^local omarchy_monitor_scale = 1$' "$mon"; then
      ok "display scale 1 / GDK scale 1"
    elif grep -qE '^local omarchy_gdk_scale = 2$' "$mon" && grep -qE '^local omarchy_monitor_scale = "auto"$' "$mon"; then
      if ((DRY_RUN)); then echo "  [dry-run] set scale 1/1 in monitors.lua"; else
        hypr_touch "$mon"
        sed -i -E 's/^local omarchy_gdk_scale = 2$/local omarchy_gdk_scale = 1/; s/^local omarchy_monitor_scale = "auto"$/local omarchy_monitor_scale = 1/' "$mon"
        fix "display scale set to 1/1"
      fi
    else
      warn "monitors.lua scale is custom (neither 1/1 nor Omarchy default); left alone"
    fi
  fi
  hypr_finish
}
