MOD_DESC="Desktop entries: Claude opens in ~/Work, WhatsApp pinned to Chrome profile, agent-window icon, Tinkercad app"
MOD_SUDO="no"
MOD_DEPS=""
MOD_REQUIRES=""
EXPORT_PATHS=".local/share/applications/Claude.desktop .local/share/applications/WhatsApp.desktop .local/share/applications/org.omarchy.agent.desktop .local/share/applications/Tinkercad.desktop"

apply() {
  local appdir="$HOME/.local/share/applications"
  act mkdir -p "$appdir"

  # Claude.desktop -> working directory ~/Work (uses the current user's $HOME, not a
  # hard-coded path, so it works for anyone). Edit in place if Omarchy made it,
  # otherwise drop the shipped copy and then fix its Path.
  local claude="$appdir/Claude.desktop"
  local workdir="$HOME/Work"
  [[ -f $claude ]] || { [[ -f $PAYLOAD/.local/share/applications/Claude.desktop ]] && copy_payload ".local/share/applications/Claude.desktop"; }
  if [[ -f $claude ]]; then
    if grep -qxF "Path=$workdir" "$claude"; then ok "Claude.desktop opens in ~/Work"
    else backup "$claude"; act sed -i "/^Path=/d; /^Exec=/a Path=$workdir" "$claude"; fix "Claude.desktop working directory set to $workdir"; fi
  fi

  # WhatsApp webapp -> fixed Chrome profile + window-class icon.
  local wa="$appdir/WhatsApp.desktop"
  if [[ -f $wa ]]; then
    if grep -q '^Exec=omarchy-launch-webapp https://web.whatsapp.com/ --profile-directory=Default$' "$wa"; then ok "WhatsApp pinned to Chrome profile Default"
    elif grep -qE '^Exec=omarchy-launch-webapp https://web.whatsapp.com/ *$' "$wa"; then
      backup "$wa"; act sed -i 's|^Exec=omarchy-launch-webapp https://web.whatsapp.com/ *$|Exec=omarchy-launch-webapp https://web.whatsapp.com/ --profile-directory=Default|' "$wa"; fix "WhatsApp pinned to profile Default"
    else warn "WhatsApp.desktop Exec is a different form; check it has --profile-directory=Default"; fi
  elif [[ -f $PAYLOAD/.local/share/applications/WhatsApp.desktop ]]; then
    copy_payload ".local/share/applications/WhatsApp.desktop"; fix "WhatsApp.desktop installed (from repo)"
  fi
  ensure_line "$wa" "StartupWMClass=chrome-web.whatsapp.com__-Default" "WhatsApp window gets its dock icon"

  # Claude icon for the Omarchy agent window.
  local agent="$appdir/org.omarchy.agent.desktop"
  if [[ -f $agent ]] && grep -q '^StartupWMClass=org.omarchy.agent$' "$agent"; then ok "agent window gets the Claude icon"
  elif [[ -f $PAYLOAD/.local/share/applications/org.omarchy.agent.desktop ]]; then
    copy_payload ".local/share/applications/org.omarchy.agent.desktop"; fix "org.omarchy.agent.desktop installed (Claude icon)"
  fi

  # Tinkercad app launcher (software WebGL for 3D; needs module 30's chrome flags).
  if [[ -f $PAYLOAD/.local/share/applications/Tinkercad.desktop ]]; then
    copy_payload ".local/share/applications/Tinkercad.desktop"; ok "Tinkercad launcher installed"
  fi

  act update-desktop-database "$appdir" >/dev/null 2>&1
}
