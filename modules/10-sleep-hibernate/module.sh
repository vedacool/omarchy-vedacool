MOD_DESC="Lid-close hibernate, ath9k wifi-resume fix, single-password wake"
MOD_SUDO="yes"
MOD_DEPS=""
MOD_REQUIRES=""

# Hardware-specific: the ath9k reload targets an Atheros AR9285. The hibernate
# setup assumes Omarchy already configured a resume swapfile.
check() {
  if [[ -n ${PF_WIFI:-} ]]; then
    if grep -qi 'atheros\|ar92\|ath9k' <<<"$PF_WIFI"; then
      ok "wifi looks like Atheros/ath9k — the resume fix applies"
    else
      warn "wifi is '$PF_WIFI', not Atheros/ath9k — the ath9k-resume fix is harmless but won't help this card"
    fi
  fi
  if ! grep -q resume /proc/cmdline 2>/dev/null && [[ ! -f /swap/swapfile ]]; then
    warn "no obvious resume=/swapfile setup — hibernate needs a swap area Omarchy normally configures at install"
  fi
}

apply() {
  ensure_sysfile /etc/systemd/logind.conf.d/30-lid-hibernate.conf 644 "lid close hibernates" \
'[Login]
HandleLidSwitch=hibernate
HandleLidSwitchExternalPower=hibernate'

  ensure_sysfile /etc/systemd/system-sleep/ath9k-resume 755 "ath9k reload after hibernate" \
'#!/bin/bash

# Reload ath9k after resuming from hibernate.
# The AR9285 comes back in a stale state: it associates, but the WPA 4-way
# handshake times out, which NetworkManager reports as "wrong password".

sleep_action=${SYSTEMD_SLEEP_ACTION:-$2}

if [[ $1 == "post" && ( $sleep_action == "hibernate" || $sleep_action == "suspend-then-hibernate" ) ]]; then
  modprobe -r ath9k && modprobe ath9k
fi'

  # Don'\''t lock on sleep (keep only the LUKS disk password on wake).
  local unit="$HOME/.config/systemd/user/omarchy-sleep-lock.service"
  if [[ "$(readlink "$unit" 2>/dev/null)" == /dev/null ]]; then
    ok "omarchy-sleep-lock.service already masked"
  else
    act systemctl --user mask --now omarchy-sleep-lock.service >/dev/null 2>&1
    fix "omarchy-sleep-lock.service masked"
  fi

  # Skip Omarchy'\''s lock-on-lid-close, keep the monitor/clamshell reconcile.
  ensure_block "$HYPR/bindings.lua" 'hl\.unbind\("switch:on:Lid Switch"\)' "lid-close lock override" \
'-- Lid close hibernates (logind); the LUKS disk password on wake is the only
-- password wanted, so skip Omarchy'"'"'s lock-on-lid-close. Keep the clamshell reconcile.
hl.unbind("switch:on:Lid Switch")
o.bind("switch:on:Lid Switch", nil, "omarchy-hyprland-monitor-clamshell", { locked = true })'
  hypr_finish
}
