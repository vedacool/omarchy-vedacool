MOD_DESC="Animated desktop HUDs (GN HUD + VEDA terminal) with live data + shared news feed"
MOD_SUDO="no"
MOD_DEPS="80-themes"
MOD_REQUIRES="jq python3 quickshell"
EXPORT_PATHS=".config/omarchy/plugins/vedacool.gn-hud .config/omarchy/plugins/vedacool.veda-terminal .local/share/veda-news"

check() {
  python3 -c 'import ast' 2>/dev/null && ok "python3 can parse the news fetcher" || warn "python3 missing — the news feed won't run"
}

apply() {
  copy_payload ".config/omarchy/plugins/vedacool.gn-hud"        && ok "installed GN HUD plugin"
  copy_payload ".config/omarchy/plugins/vedacool.veda-terminal" && ok "installed VEDA terminal plugin"
  copy_payload ".local/share/veda-news"                         && ok "installed shared news fetcher"
  register_plugin "vedacool.gn-hud"
  register_plugin "vedacool.veda-terminal"
  echo "  info   the HUD for a theme only runs while that theme is active"
  echo "  info   restart the shell: omarchy restart shell"
}
