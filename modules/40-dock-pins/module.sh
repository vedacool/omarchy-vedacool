MOD_DESC="Dock pins: Chrome, Zoom, WhatsApp (pinned to one Chrome profile), Remmina"
MOD_SUDO="no"
MOD_DEPS=""
MOD_REQUIRES="nwg-dock-hyprland"

apply() {
  local pins="$HOME/.cache/nwg-dock-pinned"
  local whatsapp_pin="chrome-web.whatsapp.com__-Default"
  [[ -f $pins ]] || { act mkdir -p "$(dirname "$pins")"; act touch "$pins"; }
  for app in google-chrome zoom "$whatsapp_pin" org.remmina.Remmina; do
    ensure_line "$pins" "$app" "dock pin: $app"
  done

  # Remmina ships a tray applet (remmina -i) that registers a menu-only Ayatana
  # AppIndicator — left/double-click can't open its window on Hyprland, which is
  # confusing. Launch it from the dock pin instead; drop the autostart applet.
  local applet="$HOME/.config/autostart/remmina-applet.desktop"
  if [[ -f $applet ]]; then
    if ((DRY_RUN)); then echo "  [dry-run] rm $applet"; else rm -f "$applet"; fix "removed Remmina tray applet autostart (use the dock pin)"; fi
  else
    ok "Remmina tray applet autostart not present"
  fi
  # Remove the old bare WhatsApp pin (shows a duplicate icon).
  if grep -qx "WhatsApp" "$pins" 2>/dev/null; then
    backup "$pins"; act sed -i '/^WhatsApp$/d' "$pins"; fix "removed duplicate 'WhatsApp' pin"
  fi
  echo "  info   restart the dock to see changes: pkill -f nwg-dock-hyprland (it autostarts)"
}
