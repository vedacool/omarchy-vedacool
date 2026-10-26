MOD_DESC="Audio notifications: toast on 3.5mm headphone + HDMI plug/unplug"
MOD_SUDO="no"
MOD_DEPS=""
MOD_REQUIRES="alsactl amixer systemctl"
EXPORT_PATHS=".local/bin/av-jack-notify .config/systemd/user/av-jack-notify.service"

# Needs something to show toasts; Omarchy's shell provides omarchy-notification-send.
check() {
  if command -v omarchy-notification-send >/dev/null || command -v notify-send >/dev/null; then
    ok "a notification sender is available"
  else
    warn "no omarchy-notification-send / notify-send — toasts won't appear"
  fi
}

apply() {
  copy_payload ".local/bin/av-jack-notify" && act chmod +x "$HOME/.local/bin/av-jack-notify"
  copy_payload ".config/systemd/user/av-jack-notify.service"
  ok "av-jack-notify installed"
  if ((DRY_RUN)); then
    echo "  [dry-run] systemctl --user enable --now av-jack-notify.service"
  elif systemctl --user daemon-reload 2>/dev/null \
    && systemctl --user enable --now av-jack-notify.service >/dev/null 2>&1; then
    fix "av-jack-notify service enabled + started"
  else
    warn "installed, but could not enable the user service (no user systemd session here?); run: systemctl --user enable --now av-jack-notify.service"
  fi
}
