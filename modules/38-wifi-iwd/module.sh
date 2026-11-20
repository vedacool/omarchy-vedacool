MOD_DESC="Wi-Fi backend = iwd (proactive roaming for the old AR9285 on a Deco mesh)"
MOD_SUDO="yes"
MOD_DEPS=""
MOD_REQUIRES="nmcli systemctl pacman"

# NetworkManager's default Wi-Fi backend (wpa_supplicant) only roams reactively
# — it clings to the connected access point until the link nearly dies. On this
# laptop's Atheros AR9285 (2.4GHz-only 802.11n, no 802.11k/v/r offload) that made
# it a sticky client on the 3-node TP-Link Deco X10 mesh: stuck on a weak node
# while a stronger one was in range. iwd roams PROACTIVELY on RSSI and honours the
# 802.11k/v neighbour hints the mesh advertises, so the laptop moves to the
# strongest node on its own (no manual BSSID pin needed). See [[laptop-wifi-deco-mesh]].
#
# Note: iwd ships a systemd .link rule that renames the wireless interface to
# wlanN (so wlp3s0 becomes wlan0). NetworkManager is device-agnostic, so profiles
# keep working; only scripts that hard-code the old name need updating.
PKG="iwd"
CONF="/etc/NetworkManager/conf.d/wifi_backend.conf"
CONF_CONTENT='# Wi-Fi backend = iwd instead of wpa_supplicant. iwd does proactive
# RSSI-based roaming (moves to a stronger mesh node before the link degrades)
# and honours 802.11k/v neighbour hints, which the old Atheros AR9285 +
# wpa_supplicant default ignored (sticky client). Managed by omarchy-vedacool
# module 38-wifi-iwd.
#
# Rollback: remove this file, then
#   sudo systemctl disable --now iwd
#   sudo systemctl restart NetworkManager
# (NetworkManager falls back to wpa_supplicant).
[device]
wifi.backend=iwd'

# True when NetworkManager is actually driving the radio through iwd right now
# (iwd renames the device to wlanN; wpa_supplicant leaves the predictable wlpXsY).
_nm_on_iwd() { nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep -q '^wlan[0-9]*:wifi'; }

check() {
  command -v iwctl >/dev/null 2>&1 && ok "iwd installed ($(pacman -Q iwd 2>/dev/null | awk '{print $2}'))" \
    || { echo "  info   iwd not installed yet; apply will 'pacman -S $PKG' (needs sudo)"; return; }

  if [[ -f $CONF ]] && grep -qE '^[[:space:]]*wifi\.backend[[:space:]]*=[[:space:]]*iwd' "$CONF"; then
    ok "NetworkManager wifi.backend=iwd configured"
  else
    warn "wifi.backend not set to iwd in $CONF (apply will write it)"
  fi

  [[ "$(systemctl is-enabled iwd 2>/dev/null)" == enabled ]] && ok "iwd service enabled" \
    || warn "iwd service not enabled (apply will: systemctl enable --now iwd)"

  if _nm_on_iwd; then
    ok "NetworkManager is live on iwd (interface renamed to wlanN)"
  elif [[ -f $CONF ]]; then
    warn "iwd configured but NetworkManager not on it yet — restart to activate: sudo systemctl restart NetworkManager (wifi will blip)"
  fi
}

apply() {
  # 1) install iwd (official repo — pacman, not an AUR helper)
  if ! command -v iwctl >/dev/null 2>&1; then
    if ((DRY_RUN)); then echo "  [dry-run] sudo pacman -S --needed --noconfirm $PKG"
    elif sudo pacman -S --needed --noconfirm "$PKG"; then fix "iwd installed"
    else warn "could not install iwd; run: sudo pacman -S $PKG"; return; fi
  else
    ok "iwd installed"
  fi

  # 2) point NetworkManager at iwd
  ensure_sysfile "$CONF" 0644 "NetworkManager wifi.backend=iwd" "$CONF_CONTENT"

  # 3) enable + start the iwd service (idempotent)
  if [[ "$(systemctl is-enabled iwd 2>/dev/null)" == enabled ]] && systemctl is-active --quiet iwd; then
    ok "iwd service enabled and running"
  elif ((DRY_RUN)); then
    echo "  [dry-run] sudo systemctl enable --now iwd"
  elif sudo systemctl enable --now iwd; then
    fix "iwd service enabled and started"
  else
    warn "could not enable iwd service; run: sudo systemctl enable --now iwd"
  fi

  # 4) activate the backend. Restarting NetworkManager drops the only link on a
  # wifi-only laptop, so never do it unprompted — only tell the user when the
  # backend isn't live yet (iwd hasn't taken the radio; device still wlpXsY).
  if _nm_on_iwd; then
    ok "NetworkManager live on iwd — roaming active, no BSSID pin needed"
  else
    warn "backend set but not active yet — run once: sudo systemctl restart NetworkManager (wifi blips ~10s, reconnects via iwd)"
  fi
}
