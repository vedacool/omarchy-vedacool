#!/bin/bash
# Preflight: dependency + compatibility checks run BEFORE any module changes
# anything. Sourced by setup.sh. Prints a report and returns non-zero if there
# are hard blockers (missing base system) so restore can stop unless --force.

# --- base environment (always checked) ----------------------------------------
preflight_base() {
  local blockers=0
  echo -e "\033[1mEnvironment\033[0m"
  # Is this Omarchy?
  if [[ -d /usr/share/omarchy ]]; then
    local ov; ov=$(omarchy --version 2>/dev/null || cat /usr/share/omarchy/version 2>/dev/null || echo "?")
    ok "Omarchy present (version ${ov})"
  else
    warn "/usr/share/omarchy not found — this does not look like an Omarchy install. Many modules edit Omarchy-seeded files and will skip."
    blockers=$((blockers+1))
  fi
  # Arch base tooling the repo relies on
  for c in bash jq git; do
    command -v "$c" >/dev/null && ok "base tool: $c" || { warn "missing base tool: $c (install it first)"; blockers=$((blockers+1)); }
  done
  command -v pacman >/dev/null && ok "pacman present" || warn "pacman not found (package checks will be skipped)"
  # Kernel / GPU / wifi fingerprint — informational, drives per-module compat
  echo "  info   kernel $(uname -r)"
  PF_GPU=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | sed 's/.*: //' | head -1)
  [[ -n ${PF_GPU:-} ]] && echo "  info   gpu $PF_GPU"
  PF_WIFI=$(lspci 2>/dev/null | grep -iE 'network|wireless' | sed 's/.*: //' | head -1)
  [[ -n ${PF_WIFI:-} ]] && echo "  info   wifi $PF_WIFI"
  export PF_GPU PF_WIFI
  return $blockers
}

# require_cmds "cmd1 cmd2" — report each; returns count missing.
require_cmds() {
  local missing=0 c
  for c in $1; do
    if command -v "$c" >/dev/null; then ok "needs '$c' — present"; else warn "needs '$c' — NOT installed"; missing=$((missing+1)); fi
  done
  return $missing
}

# preflight_module ID — source its metadata + optional check(), report readiness.
# Prints a verdict line; returns 0 ready, 1 has warnings/blockers.
preflight_module() {
  local id=$1
  ( source "$ROOT/lib/common.sh"; source "$ROOT/lib/preflight.sh"
    WARN_COUNT=0
    MOD_DESC=""; MOD_SUDO="no"; MOD_DEPS=""; MOD_REQUIRES=""
    MODULE_DIR="$MODDIR/$id"
    source "$MODDIR/$id/module.sh"
    PAYLOAD="$MODDIR/$id/payload"
    echo -e "\n\033[1m$id\033[0m — $MOD_DESC"
    [[ -n $MOD_REQUIRES ]] && require_cmds "$MOD_REQUIRES"
    [[ $MOD_SUDO == yes ]] && echo "  info   needs sudo (you'll be prompted)"
    for d in $MOD_DEPS; do
      [[ -d $MODDIR/$d ]] && echo "  info   depends on module: $d"
    done
    # module-specific compatibility test, if defined
    if declare -F check >/dev/null; then check; fi
    exit $WARN_COUNT )
}
