MOD_DESC="Gundam 00 themes (veda-terminal, gundam-00-raiser, gundam-00) + HUD fonts"
MOD_SUDO="no"
MOD_DEPS=""
MOD_REQUIRES=""
EXPORT_PATHS=".config/omarchy/themes/veda-terminal .config/omarchy/themes/gundam-00-raiser .config/omarchy/themes/gundam-00 .local/share/fonts/gn-hud"

apply() {
  for t in veda-terminal gundam-00-raiser gundam-00; do
    copy_payload ".config/omarchy/themes/$t" && ok "installed theme: $t"
  done
  copy_payload ".local/share/fonts/gn-hud" && ok "installed HUD fonts (Orbitron, Michroma)"
  act fc-cache -f "$HOME/.local/share/fonts/gn-hud" >/dev/null 2>&1
  echo "  info   switch with: omarchy theme set veda-terminal"
}
