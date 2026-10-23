MOD_DESC="Chrome flags: software GPU, Wayland IME, 80% UI scale"
MOD_SUDO="no"
MOD_DEPS=""
MOD_REQUIRES=""

# --disable-gpu and --force-device-scale-factor=0.8 are for the old Radeon + the
# short 768px screen. On capable hardware you may want GPU on and scale 1.
check() {
  if [[ -n ${PF_GPU:-} ]] && ! grep -qi 'radeon' <<<"$PF_GPU"; then
    warn "GPU is '$PF_GPU' — '--disable-gpu' sacrifices acceleration; drop it on a capable GPU"
  fi
}

apply() {
  local f="$HOME/.config/chrome-flags.conf"
  ensure_line "$f" "--disable-gpu" "Chrome --disable-gpu (old GPU)"
  ensure_line "$f" "--enable-wayland-ime" "Chrome --enable-wayland-ime"
  ensure_line "$f" "--wayland-text-input-version=3" "Chrome --wayland-text-input-version=3"
  ensure_line "$f" "--force-device-scale-factor=0.8" "Chrome UI at 80%"
}
