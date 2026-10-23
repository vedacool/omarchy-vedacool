MOD_DESC="Dock pins: Chrome, Zoom, WhatsApp (pinned to one Chrome profile)"
MOD_SUDO="no"
MOD_DEPS=""
MOD_REQUIRES="nwg-dock-hyprland"

apply() {
  local pins="$HOME/.cache/nwg-dock-pinned"
  local whatsapp_pin="chrome-web.whatsapp.com__-Default"
  [[ -f $pins ]] || { act mkdir -p "$(dirname "$pins")"; act touch "$pins"; }
  for app in google-chrome zoom "$whatsapp_pin"; do
    ensure_line "$pins" "$app" "dock pin: $app"
  done
  # Remove the old bare WhatsApp pin (shows a duplicate icon).
  if grep -qx "WhatsApp" "$pins" 2>/dev/null; then
    backup "$pins"; act sed -i '/^WhatsApp$/d' "$pins"; fix "removed duplicate 'WhatsApp' pin"
  fi
  echo "  info   restart the dock to see changes: pkill -f nwg-dock-hyprland (it autostarts)"
}
