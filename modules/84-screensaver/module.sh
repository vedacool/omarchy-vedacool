MOD_DESC="VEDA screensaver wired into idle (replaces the stock screensaver)"
MOD_SUDO="no"
MOD_DEPS="82-hud-plugins"
MOD_REQUIRES="foot socat jq hyprctl python3"
EXPORT_PATHS=".config/omarchy/plugins/vedacool.idle .local/bin/veda-launch-screensaver .local/bin/veda-screensaver-session .local/share/veda-screensaver Work/bin/veda-screensaver"

check() {
  for c in foot socat; do command -v "$c" >/dev/null || warn "'$c' missing — the VEDA screensaver falls back to the stock one without it"; done
  python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$PAYLOAD/Work/bin/veda-screensaver" 2>/dev/null \
    && ok "veda-screensaver parses with $(python3 -V 2>&1)" \
    || warn "veda-screensaver does not parse with this python3 — it may need a fix after restore"
}

apply() {
  copy_payload ".config/omarchy/plugins/vedacool.idle"       && ok "installed vedacool.idle (cloned idle service)"
  copy_payload ".local/bin/veda-launch-screensaver"          && act chmod +x "$HOME/.local/bin/veda-launch-screensaver"
  copy_payload ".local/bin/veda-screensaver-session"         && act chmod +x "$HOME/.local/bin/veda-screensaver-session"
  copy_payload ".local/share/veda-screensaver"               && ok "installed screensaver assets (foot.ini, mode)"
  copy_payload "Work/bin/veda-screensaver"                   && act chmod +x "$HOME/Work/bin/veda-screensaver"
  ok "VEDA screensaver scripts installed"

  # Use the clone, disable the stock idle service (double-lock otherwise).
  if command -v omarchy-plugin-enable >/dev/null && ! ((DRY_RUN)); then
    omarchy-plugin-enable vedacool.idle >/dev/null 2>&1 && fix "vedacool.idle enabled" || register_plugin "vedacool.idle"
  else
    register_plugin "vedacool.idle"
  fi
  jq_set "$HOME/.config/omarchy/shell.json" '.disabledPlugins = ((.disabledPlugins // []) - ["omarchy.idle"] + ["omarchy.idle"])' "stock omarchy.idle disabled"
  echo "  info   restart the shell: omarchy restart shell"
}
