MOD_DESC="Shell bar: opaque bar, custom bar layout, 12pt font"
MOD_SUDO="no"
MOD_DEPS="70-bar-plugins"
MOD_REQUIRES="jq"

# The saved bar layout (data file, refreshed by ./export.sh) references the
# vedacool.* bar plugins (module 70). Restore that module too, or slots render empty.

# export.sh hook: re-capture the live bar layout into this module's data file.
export_extra() {
  jq -c '.bar.layout' "$HOME/.config/omarchy/shell.json" > "$MODULE_DIR/bar-layout.json" 2>/dev/null \
    && echo "  ok       bar-layout.json captured from live shell.json" \
    || echo "  MISSING  could not read .bar.layout from live shell.json"
}

apply() {
  local sj="$HOME/.config/omarchy/shell.json"
  jq_set "$sj" '.bar.transparent = false' "bar.transparent = false (opaque, old-GPU)"
  local layout_file="$MODULE_DIR/bar-layout.json"
  if [[ -f $layout_file ]]; then
    jq_set "$sj" ".bar.layout = ($(cat "$layout_file"))" "bar layout restored (netspeed, network, monitor, zoom-controls)"
  else
    warn "bar-layout.json missing in the repo; bar layout not restored"
  fi

  # Font base size 12 in shell.toml.
  local st="$HOME/.config/omarchy/shell.toml"
  if [[ -f $st ]]; then
    if grep -qE '^base-size = 12$' "$st"; then ok "font base-size 12"
    elif grep -qE '^base-size = ' "$st"; then backup "$st"; act sed -i -E 's/^base-size = .*/base-size = 12/' "$st"; fix "font base-size set to 12"
    elif grep -q '^\[font\]' "$st"; then backup "$st"; act sed -i '/^\[font\]/a base-size = 12' "$st"; fix "font base-size 12 added"
    else backup "$st"; ((DRY_RUN)) || printf '\n[font]\nbase-size = 12\n' >>"$st"; fix "[font] base-size 12 added"; fi
  else
    if ((DRY_RUN)); then echo "  [dry-run] create $st with [font] base-size 12"; else printf '[font]\nbase-size = 12\n' >"$st"; fi
    fix "shell.toml created with font base-size 12"
  fi
  echo "  info   restart the shell to apply: omarchy restart shell"
}
