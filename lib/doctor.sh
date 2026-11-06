#!/bin/bash
# doctor.sh — read-only drift report for omarchy-vedacool.
#
# Answers "are my mods still applied, or has something drifted?" WITHOUT changing
# anything. For every module it compares what is installed under $HOME against the
# committed copy in modules/<id>/payload/ (the repo is the source of truth), checks
# the state of any systemd user services the module owns, and runs the module's own
# check() for semantic signals. Nothing here writes, installs, or needs sudo, so it
# is safe to run anytime — e.g. after a kernel bump or `omarchy update`.
#
# Sourced by setup.sh; invoked with `./setup.sh --status` (alias --doctor).

# Files that legitimately differ or are noise, excluded from directory diffs:
# our own timestamped backups, python caches, and the stripped audit dir.
_doc_excl=( --exclude='*.bak.setup.*' --exclude='*.bak.*' --exclude='__pycache__' --exclude='.audit' )

# symbols (plain when not a tty)
if [[ -t 1 ]]; then
  _S_OK="\033[32m✓\033[0m"; _S_DR="\033[33m⚠\033[0m"; _S_MI="\033[31m✗\033[0m"; _S_IN="\033[36mℹ\033[0m"
  _B="\033[1m"; _O="\033[0m"; _DIM="\033[2m"
else
  _S_OK="[ok]"; _S_DR="[drift]"; _S_MI="[missing]"; _S_IN="[info]"; _B=""; _O=""; _DIM=""
fi

# doctor_one ID — prints one module's line(s); echoes a trailing status token
# (ok|drift|missing|attn|info) on the LAST line so the caller can tally.
doctor_one() {
  local id=$1
  (
    MOD_DESC=""; EXPORT_PATHS=""; MOD_REQUIRES=""
    MODULE_DIR="$MODDIR/$id"
    source "$MODDIR/$id/module.sh" >/dev/null 2>&1
    PAYLOAD="$MODDIR/$id/payload"

    local synced=0 drift=0 missing=0 total=0
    local -a notes=()

    # --- payload file integrity (installed $HOME copy vs committed payload) ----
    local rel src dst
    for rel in $EXPORT_PATHS; do
      src="$PAYLOAD/$rel"; dst="$HOME/$rel"
      [[ -e $src ]] || continue            # owned but not stored in payload — skip
      total=$((total+1))
      if [[ ! -e $dst ]]; then
        missing=$((missing+1)); notes+=("   $_S_MI  missing: $rel"); continue
      fi
      if [[ -d $src ]]; then
        if diff -rq "${_doc_excl[@]}" "$src" "$dst" >/dev/null 2>&1; then
          synced=$((synced+1))
        else
          drift=$((drift+1))
          # show which files differ, briefly
          local diffs; diffs=$(diff -rq "${_doc_excl[@]}" "$src" "$dst" 2>/dev/null \
            | sed "s#$src/\?##g; s#$dst/\?##g" | head -4)
          notes+=("   $_S_DR  drift: $rel")
          while IFS= read -r l; do [[ -n $l ]] && notes+=("        $_DIM$l$_O"); done <<<"$diffs"
        fi
      else
        if cmp -s "$src" "$dst"; then synced=$((synced+1)); else drift=$((drift+1)); notes+=("   $_S_DR  drift: $rel"); fi
      fi
    done

    # --- systemd user services this module owns -------------------------------
    local svc unit en ac
    for rel in $EXPORT_PATHS; do
      [[ $rel == *.service ]] || continue
      unit=$(basename "$rel")
      en=$(systemctl --user is-enabled "$unit" 2>/dev/null || echo "unknown")
      ac=$(systemctl --user is-active  "$unit" 2>/dev/null || echo "inactive")
      if [[ $en == enabled && $ac == active ]]; then
        notes+=("   $_S_OK  service $unit: enabled, active")
      else
        notes+=("   $_S_DR  service $unit: $en, $ac")
        [[ $drift == 0 && $missing == 0 ]] && drift=1   # degrade verdict
      fi
    done

    # --- module's own check() (semantic, read-only) ---------------------------
    local chk="" chk_warn=0
    if declare -F check >/dev/null 2>&1; then
      WARN_COUNT=0
      chk=$(check 2>/dev/null)
      chk_warn=$WARN_COUNT
    fi

    # --- verdict line ---------------------------------------------------------
    local sym status summary
    if ((missing)); then
      sym=$_S_MI; status=missing; summary="${missing} missing, ${drift} drift, ${synced}/${total} ok"
    elif ((drift)); then
      sym=$_S_DR; status=drift;   summary="${drift} drifted, ${synced}/${total} ok"
    elif ((total)); then
      sym=$_S_OK; status=ok;      summary="in sync (${synced}/${total})"
    elif ((chk_warn)); then
      sym=$_S_DR; status=attn;    summary="check reported ${chk_warn} warning(s)"
    elif [[ -n $chk ]]; then
      sym=$_S_OK; status=ok;      summary="checks passed"
    else
      sym=$_S_IN; status=info;    summary="no files/service to verify (config-edit module)"
    fi

    printf "  %b  ${_B}%-20s${_O} %s\n" "$sym" "$id" "$summary"
    local n; for n in "${notes[@]}"; do printf "%b\n" "$n"; done
    # surface check() warnings (lines that start with WARN)
    if ((chk_warn)); then
      while IFS= read -r l; do [[ $l == *WARN* ]] && printf "   %b  %s\n" "$_S_DR" "$(echo "$l" | sed 's/^[[:space:]]*WARN[[:space:]]*//')"; done <<<"$chk"
    fi

    echo "__STATUS__:$status"
  )
}

doctor() {
  echo -e "${_B}== VEDA mods — drift report ==${_O}"
  echo -e "${_DIM}comparing installed \$HOME copy against the committed repo payload; read-only${_O}\n"
  local -a sel=("$@"); ((${#sel[@]})) || sel=("${ALL[@]}")
  local n_ok=0 n_drift=0 n_missing=0 n_attn=0 n_info=0
  local -a need_repair=()
  for id in "${sel[@]}"; do
    [[ -d $MODDIR/$id ]] || { echo "  unknown module: $id"; continue; }
    local out; out=$(doctor_one "$id")
    local st=${out##*__STATUS__:}
    printf '%s\n' "${out%$'\n'__STATUS__:*}"
    case $st in
      ok) ((n_ok++)) ;;
      drift)   ((n_drift++));   need_repair+=("$id") ;;
      missing) ((n_missing++)); need_repair+=("$id") ;;
      attn)    ((n_attn++));    need_repair+=("$id") ;;
      info) ((n_info++)) ;;
    esac
  done
  echo
  echo -e "${_B}Summary:${_O} ${#sel[@]} modules — ${n_ok} in sync, ${n_drift} drift, ${n_missing} missing, ${n_attn} attn, ${n_info} info"
  if ((${#need_repair[@]})); then
    echo -e "Repair:  ${_B}./setup.sh ${need_repair[*]}${_O}   ${_DIM}(re-applies the committed version)${_O}"
    return 1
  fi
  echo -e "${_S_OK} Everything matches the repo."
  return 0
}
