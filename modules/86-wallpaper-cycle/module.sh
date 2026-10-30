MOD_DESC="VEDA living wallpaper: slow-cycling twinkling starfield (GPU-free)"
MOD_SUDO="no"
MOD_DEPS="80-themes"
MOD_REQUIRES="systemctl"
EXPORT_PATHS=".local/bin/veda-wallpaper-cycle .local/share/veda-wallpaper .config/systemd/user/veda-wallpaper-cycle.service"

# A pre-rendered "living" wallpaper for the HUD-heavy VEDA desktop. This laptop's
# Radeon HD 6730M can't safely run an animated/live wallpaper (it would bring
# back the GPU crashes + heat), so instead a handful of frames that share one
# fixed starfield are swapped every few seconds -- random particles "twinkle"
# across the field at the cost of one image swap, no continuous rendering. The
# frames ship pre-rendered; regenerate/tune them with generate-frames.sh (needs
# ImageMagick).
check() {
  command -v magick >/dev/null \
    && ok "ImageMagick present (frames can be regenerated with generate-frames.sh)" \
    || echo "  info   ImageMagick not installed; shipped frames are used as-is (regeneration needs 'magick')"
}

apply() {
  copy_payload ".local/bin/veda-wallpaper-cycle" && act chmod +x "$HOME/.local/bin/veda-wallpaper-cycle"
  copy_payload ".local/share/veda-wallpaper"
  [[ -f $HOME/.local/share/veda-wallpaper/generate-frames.sh ]] && act chmod +x "$HOME/.local/share/veda-wallpaper/generate-frames.sh"
  copy_payload ".config/systemd/user/veda-wallpaper-cycle.service"
  ok "veda-wallpaper-cycle installed (cycler + frames + service)"

  if ((DRY_RUN)); then
    echo "  [dry-run] systemctl --user enable --now veda-wallpaper-cycle.service"
  else
    systemctl --user daemon-reload 2>/dev/null
    if systemctl --user enable --now veda-wallpaper-cycle.service 2>/dev/null; then
      fix "wallpaper cycle service enabled + started"
    else
      warn "could not enable the service now (no user systemd session?); later: systemctl --user enable --now veda-wallpaper-cycle"
    fi
  fi
  echo "  info   turn it off any time: systemctl --user disable --now veda-wallpaper-cycle"
  echo "  info   while it runs it drives the wallpaper; disable it first to set a static one"
}
