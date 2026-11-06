MOD_DESC="VEDA boot splash (Plymouth) — the one thing that reverts on every kernel/omarchy update"
MOD_SUDO="yes"
MOD_DEPS="80-themes"
MOD_REQUIRES=""

check() {
  [[ -d $HOME/.config/omarchy/themes/veda-terminal ]] && ok "veda-terminal theme present (boot logo source)" \
    || warn "veda-terminal theme not found — restore module 80-themes first"
  command -v omarchy >/dev/null && ok "omarchy CLI present" || warn "omarchy CLI not found"
  # The splash only renders if the initramfs carries the 'plymouth' hook. A kernel
  # or omarchy update can rebuild the initramfs from a HOOKS set that dropped it,
  # silently killing the boot screen (this bit us on a kernel bump). Verify the
  # config set still declares it — read-only, no sudo. (The built image itself can
  # only be confirmed with root: sudo lsinitcpio <img> | grep plymouth.)
  if grep -rhsE '^[[:space:]]*HOOKS=.*[( ]plymouth[ )]' /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/ 2>/dev/null | grep -q plymouth; then
    ok "plymouth hook present in mkinitcpio config"
  else
    warn "plymouth hook MISSING from mkinitcpio config — boot splash won't render; rebuild: omarchy plymouth set by theme veda-terminal"
  fi
}

apply() {
  if ! command -v omarchy >/dev/null; then warn "omarchy CLI not found; cannot set the boot theme"; return; fi
  local cur; cur=$(omarchy plymouth current 2>/dev/null)
  if [[ $cur == veda-terminal ]]; then ok "boot splash already veda-terminal"; return; fi
  if ((DRY_RUN)); then echo "  [dry-run] sudo: omarchy plymouth set by theme veda-terminal"; fix "boot splash (dry-run)"; return; fi
  if omarchy plymouth set by theme veda-terminal; then
    fix "boot splash set to veda-terminal ($(omarchy plymouth current 2>/dev/null))"
  else
    warn "could not set the boot splash; run manually: omarchy plymouth set by theme veda-terminal"
  fi
  echo "  info   switch to the Exia splash instead with: omarchy plymouth set by theme gundam-00-raiser"
}
