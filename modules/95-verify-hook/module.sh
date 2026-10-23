MOD_DESC="Post-update self-heal hook (personal: hard-codes vedacool paths) — re-checks all customisations after omarchy update"
MOD_SUDO="no"
MOD_DEPS=""
MOD_REQUIRES="jq"
EXPORT_PATHS=".config/omarchy/hooks/post-update.d/verify-customisations.hook"

# This hook is tailored to my machine: it contains absolute /home/vedacool paths
# and expects my exact set of customisations. It's great for me, but of little use
# on another account.
check() {
  if [[ $HOME != /home/vedacool ]]; then
    warn "this hook hard-codes /home/vedacool paths and my customisation set — it won't fit your account; skip this module unless you're adapting it"
  else
    ok "running as vedacool — the hook fits this machine"
  fi
}

apply() {
  copy_payload ".config/omarchy/hooks/post-update.d/verify-customisations.hook" \
    && act chmod +x "$HOME/.config/omarchy/hooks/post-update.d/verify-customisations.hook" \
    && ok "verify-customisations hook installed"
  echo "  info   preview any time with: DRY_RUN=1 ~/.config/omarchy/hooks/post-update.d/verify-customisations.hook"
  echo "  info   it runs automatically after 'omarchy update'"
}
