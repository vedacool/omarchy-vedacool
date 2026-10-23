MOD_DESC="Bar plugins: netspeed, network, monitor, zoom-controls (the top-bar pills)"
MOD_SUDO="no"
MOD_DEPS=""
MOD_REQUIRES="jq"
EXPORT_PATHS=".config/omarchy/plugins/vedacool.netspeed .config/omarchy/plugins/vedacool.network .config/omarchy/plugins/vedacool.monitor .config/omarchy/plugins/vedacool.zoom-controls"

# vedacool.network and vedacool.monitor are clones of omarchy.network/monitor with
# edits; vedacool.netspeed and vedacool.zoom-controls are built from scratch.
apply() {
  for p in vedacool.netspeed vedacool.network vedacool.monitor vedacool.zoom-controls; do
    copy_payload ".config/omarchy/plugins/$p" && ok "installed plugin: $p"
  done
  # These are placed by the bar layout (module 60-shell-bar). Enabling them in
  # .plugins is harmless and makes them available even without the layout.
  echo "  info   these appear in the bar via module 60-shell-bar's layout"
  echo "  info   restart the shell to load them: omarchy restart shell"
}
