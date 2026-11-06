MOD_DESC="Ookla Speedtest CLI (official 'speedtest' command) from the AUR"
MOD_SUDO="yes"
MOD_DEPS=""
MOD_REQUIRES="yay"

# Ookla's official Speedtest CLI (`speedtest`) — accurate down/up/latency/jitter
# with a shareable result URL. It lives in the AUR as the pre-built package
# `ookla-speedtest-bin`, so it needs an AUR helper (yay) rather than plain
# pacman. yay will ask for the sudo password during install; this runs
# interactively as part of setup. The one-time licence/GDPR prompts are
# pre-accepted so the first `speedtest` run goes straight to testing.
PKG="ookla-speedtest-bin"

check() {
  if command -v speedtest >/dev/null 2>&1; then
    ok "speedtest already installed ($(speedtest --version 2>/dev/null | head -1))"
  else
    echo "  info   speedtest not installed yet; apply will try 'yay -S $PKG' (needs sudo)"
  fi
}

apply() {
  if ! command -v speedtest >/dev/null 2>&1; then
    if ((DRY_RUN)); then
      echo "  [dry-run] yay -S --needed --noconfirm $PKG"
    elif command -v yay >/dev/null && yay -S --needed --noconfirm "$PKG"; then
      fix "speedtest installed ($PKG)"
    else
      warn "could not install speedtest automatically; run: yay -S $PKG"
    fi
  else
    ok "speedtest installed"
  fi

  # Pre-accept the one-time licence/GDPR prompts (per-user config; harmless).
  if command -v speedtest >/dev/null 2>&1; then
    if ((DRY_RUN)); then
      echo "  [dry-run] speedtest --servers --accept-license --accept-gdpr (record acceptance, no test run)"
    else
      # --servers only lists nearby servers; it records the licence/GDPR
      # acceptance without running (and paying bandwidth for) a full test.
      speedtest --servers --accept-license --accept-gdpr >/dev/null 2>&1 || true
      ok "speedtest licence/GDPR acceptance recorded"
    fi
  fi
}
