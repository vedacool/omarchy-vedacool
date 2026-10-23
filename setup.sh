#!/bin/bash
# omarchy-vedacool — modular restore of vedacool's Omarchy customisations.
#
# Usage:
#   ./setup.sh --list                 list modules and what they do
#   ./setup.sh --check [MODULE ...]   preflight only: deps + compatibility, no changes
#   ./setup.sh                        interactive menu (pick with numbers)
#   ./setup.sh --all                  restore everything (preflight runs first)
#   ./setup.sh MODULE [MODULE ...]    restore specific modules by id
#   DRY_RUN=1 ./setup.sh --all        preview every change, touch nothing
#   ./setup.sh --all --yes            apply without the confirm prompt (for pipes/scripts)
#   ./setup.sh --all --force          proceed even if preflight finds blockers (overrides the gate)
#
# Each module lives in modules/<id>/module.sh and defines MOD_DESC, MOD_SUDO,
# MOD_DEPS and an apply() function; its files (if any) live in modules/<id>/payload/.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/common.sh"
source "$ROOT/lib/preflight.sh"
MODDIR="$ROOT/modules"
WARN_COUNT=0
FORCE=0
ASSUME_YES=0

# Read from the controlling terminal even when stdin is a pipe (curl | bash).
TTY=/dev/tty; [[ -r $TTY ]] || TTY=""
have_tty() { [[ -n $TTY ]]; }

mapfile -t ALL < <(cd "$MODDIR" && ls -d */ 2>/dev/null | sed 's#/##' | sort)

meta_of() { # id -> prints "desc|sudo|deps" by sourcing in a subshell
  ( MOD_DESC=""; MOD_SUDO="no"; MOD_DEPS=""
    source "$MODDIR/$1/module.sh" >/dev/null 2>&1
    echo "$MOD_DESC|$MOD_SUDO|$MOD_DEPS" )
}

list() {
  echo "Available modules:"; echo
  for id in "${ALL[@]}"; do
    IFS='|' read -r desc sudo deps <<<"$(meta_of "$id")"
    printf "  \033[1m%-22s\033[0m %s\n" "$id" "$desc"
    [[ $sudo == yes ]] && printf "  %-22s   (needs sudo)\n" ""
    [[ -n $deps ]]     && printf "  %-22s   needs: %s\n" "" "$deps"
  done
  echo; echo "Restore with:  ./setup.sh <module> [<module> ...]   |   ./setup.sh --all"
}

# missing_requires "cmd1 cmd2" -> echoes the ones not installed
missing_requires() { local m="" c; for c in $1; do command -v "$c" >/dev/null || m+="$c "; done; echo "${m% }"; }

run_one() {
  local id=$1
  [[ -d $MODDIR/$id ]] || { warn "unknown module: $id"; return 1; }
  ( # subshell: isolate apply()/MOD_* per module, keep shared helpers via re-source
    source "$ROOT/lib/common.sh"
    WARN_COUNT=0
    MOD_DESC=""; MOD_SUDO="no"; MOD_DEPS=""; MOD_REQUIRES=""
    MODULE_DIR="$MODDIR/$id"
    source "$MODDIR/$id/module.sh"
    PAYLOAD="$MODDIR/$id/payload"
    echo -e "\n\033[1m== $id\033[0m — $MOD_DESC"
    # per-module preflight gate: skip if required commands are missing
    local miss; miss=$(missing_requires "$MOD_REQUIRES")
    if [[ -n $miss ]] && ! ((FORCE)); then
      warn "SKIPPED — preflight failed: missing $miss (install them, or re-run with --force)"
      exit $WARN_COUNT
    fi
    apply
    exit $WARN_COUNT )
}

# preflight SEL... — run base + per-module checks for a selection.
# Returns number of base blockers.
preflight() {
  echo -e "\033[1m== Preflight: dependency & compatibility check ==\033[0m\n"
  preflight_base; local blockers=$?
  for id in "$@"; do preflight_module "$id"; done
  echo
  if ((blockers)); then
    echo -e "\033[33mPreflight found $blockers base blocker(s) above.\033[0m"
  else
    echo -e "\033[32mPreflight: base environment OK.\033[0m Per-module WARNs above are advisory (missing deps / different hardware)."
  fi
  return $blockers
}

restore() {
  local -a sel=() deps_missing=()
  # validate requested ids against the known set (catch typos early)
  for id in "$@"; do
    if [[ " ${ALL[*]} " == *" $id "* ]]; then sel+=("$id")
    else echo -e "\033[31mUnknown module:\033[0m $id  (see ./setup.sh --list)"; fi
  done
  ((${#sel[@]})) || { echo "No valid modules selected."; return 1; }
  # dependency warning (informational; order is caller's choice + numeric prefix)
  for id in "${sel[@]}"; do
    IFS='|' read -r _ _ deps <<<"$(meta_of "$id")"
    for d in $deps; do
      [[ " ${sel[*]} " == *" $d "* ]] || deps_missing+=("$id needs $d")
    done
  done
  # --- preflight gate: set up ONLY if preflight passes ---
  preflight "${sel[@]}"; local blockers=$?
  if ((blockers)) && ! ((FORCE)); then
    echo -e "\n\033[31mStopping — preflight did not pass:\033[0m base environment has $blockers blocker(s) above."
    echo "Fix them, or re-run with --force to override."
    return 1
  fi
  if ((${#deps_missing[@]})); then
    echo "Note — unmet dependencies in this selection (restore them too, or they may already be present):"
    printf '  - %s\n' "${deps_missing[@]}"; echo
  fi
  # Confirm (reads the terminal even under curl | bash). No tty + no --yes = stop.
  if ! ((DRY_RUN)) && ! ((ASSUME_YES)); then
    if have_tty; then
      read -rp "Proceed with restore of ${#sel[@]} module(s)? [y/N] " go <"$TTY"
      [[ $go == [yY]* ]] || { echo "Aborted."; return 1; }
    else
      echo -e "\n\033[33mNo terminal to confirm on.\033[0m Re-run with --yes to apply non-interactively, or clone and run ./setup.sh directly."
      return 1
    fi
  fi
  ((DRY_RUN)) && echo "*** DRY RUN — nothing will be changed ***"
  local total_warn=0
  # run in the repo's sorted order so numeric prefixes sequence correctly
  for id in "${ALL[@]}"; do
    [[ " ${sel[*]} " == *" $id "* ]] || continue
    run_one "$id"; total_warn=$((total_warn + $?))
  done
  echo -e "\n\033[1mDone.\033[0m $total_warn item(s) need attention."
  ((DRY_RUN)) && echo "(dry run — re-run without DRY_RUN=1 to apply)"
}

menu() {
  echo "Pick modules to restore (space/comma separated numbers, 'a' for all, 'q' to quit):"; echo
  local i=1; local -a idx=()
  for id in "${ALL[@]}"; do
    IFS='|' read -r desc sudo _ <<<"$(meta_of "$id")"
    printf "  %2d) %-22s %s%s\n" "$i" "$id" "$desc" "$([[ $sudo == yes ]] && echo '  [sudo]')"
    idx[i]=$id; ((i++))
  done
  echo
  if have_tty; then read -rp "> " ans <"$TTY"; else echo "(no terminal for interactive menu — use: setup.sh <module> --yes, or --all)"; exit 1; fi
  [[ $ans == q ]] && exit 0
  if [[ $ans == a ]]; then restore "${ALL[@]}"; return; fi
  local -a pick=()
  for n in ${ans//,/ }; do [[ ${idx[n]:-} ]] && pick+=("${idx[n]}"); done
  ((${#pick[@]})) && restore "${pick[@]}" || echo "Nothing selected."
}

# strip global flags anywhere in args
args=()
for a in "$@"; do
  case $a in
    --force) FORCE=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    *) args+=("$a") ;;
  esac
done
set -- "${args[@]:-}"

case "${1:-}" in
  --list|-l)  list ;;
  --check|-c) shift; if (($#)); then preflight "$@"; else preflight "${ALL[@]}"; fi ;;
  --all|-a)   restore "${ALL[@]}" ;;
  "")         menu ;;
  -h|--help)  sed -n '2,16p' "$0" ;;
  *)          restore "$@" ;;
esac
