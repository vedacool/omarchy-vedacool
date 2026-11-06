MOD_DESC="veda-mod-check: one terminal command to verify + auto-repair all mods"
MOD_SUDO="no"
MOD_DEPS=""
MOD_REQUIRES=""
EXPORT_PATHS=".local/bin/veda-mod-check"

# Installs the `veda-mod-check` convenience command on PATH. It wraps
# `setup.sh --fix`: run it anytime (after a kernel bump or `omarchy update`) to
# verify every mod, auto-repair whatever drifted or isn't enabled, and get a
# plain report of anything it couldn't fix.
check() {
  if command -v veda-mod-check >/dev/null 2>&1; then
    ok "veda-mod-check on PATH"
  else
    echo "  info   veda-mod-check not installed yet; apply adds it to ~/.local/bin"
  fi
}

apply() {
  copy_payload ".local/bin/veda-mod-check" && act chmod +x "$HOME/.local/bin/veda-mod-check"
  ok "veda-mod-check installed (~/.local/bin/veda-mod-check)"
  if ! command -v veda-mod-check >/dev/null 2>&1; then
    echo "  info   make sure ~/.local/bin is on your PATH, then: veda-mod-check"
  fi
}
