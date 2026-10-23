#!/bin/bash
# Shared helpers for omarchy-vedacool restore modules.
# Adapted from the battle-tested verify-customisations post-update hook.
# Rules: no `set -e` in modules; every edit is idempotent, guarded, and backed
# up first; DRY_RUN=1 changes nothing.

DRY_RUN=${DRY_RUN:-0}
HYPR="$HOME/.config/hypr"
TS=$(date +%s)

# --- payload root: set per-module by setup.sh before apply() -----------------
PAYLOAD=""   # points at the current module's payload/ dir

# --- output -------------------------------------------------------------------
_c_ok="\033[32m"; _c_fix="\033[36m"; _c_warn="\033[33m"; _c_off="\033[0m"
[[ -t 1 ]] || { _c_ok=""; _c_fix=""; _c_warn=""; _c_off=""; }
ok()   { echo -e "  ${_c_ok}ok${_c_off}     $1"; }
fix()  { echo -e "  ${_c_fix}done${_c_off}   $1"; }
warn() { echo -e "  ${_c_warn}WARN${_c_off}   $1"; WARN_COUNT=$((WARN_COUNT+1)); }
act()  { if ((DRY_RUN)); then echo "  [dry-run] $*"; return 0; fi; "$@"; }

backup() { [[ -f $1 ]] && act cp -p "$1" "$1.bak.setup.$TS"; }

# --- file payload -------------------------------------------------------------
# copy_payload REL [DEST]  — copy payload/REL to ~/REL (or to DEST), recursively,
# preserving perms. Creates parent dirs. Existing files are overwritten (backed
# up first if they are plain files).
copy_payload() {
  local rel="$1"
  local dest="${2:-$HOME/$rel}"
  local src="$PAYLOAD/$rel"
  # safety: never operate on an empty path, $HOME itself, or /
  if [[ -z $rel || $dest == "$HOME" || $dest == "$HOME/" || $dest == "/" ]]; then
    warn "refusing unsafe copy target for '$rel'"; return 1
  fi
  if [[ ! -e $src ]]; then warn "payload missing in repo: $rel"; return 1; fi
  if ((DRY_RUN)); then echo "  [dry-run] copy $rel -> $dest"; return 0; fi
  mkdir -p "$(dirname "$dest")"
  if [[ -d $src ]]; then
    mkdir -p "$dest"; cp -a "$src/." "$dest/"
  else
    [[ -f $dest ]] && cp -p "$dest" "$dest.bak.setup.$TS"
    cp -a "$src" "$dest"
  fi
}

# --- Hyprland edits (batched reload + validation + rollback) -------------------
hypr_files=(); hypr_pending=()
hypr_live() { command -v hyprctl >/dev/null && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; }
hypr_touch() { [[ " ${hypr_files[*]} " == *" $1 "* ]] && return; backup "$1"; hypr_files+=("$1"); }
uncommented() { grep -vE '^[[:space:]]*--' "$1"; }

# ensure_block FILE REGEX DESC CONTENT — append CONTENT unless REGEX matches an
# uncommented line. For Omarchy-seeded Lua files that must already exist.
ensure_block() {
  local file=$1 regex=$2 desc=$3 content=$4
  if [[ ! -f $file ]]; then warn "$desc: $file missing (install Omarchy defaults first)"; return; fi
  if uncommented "$file" | grep -qE -- "$regex"; then ok "$desc"; return; fi
  if ((DRY_RUN)); then echo "  [dry-run] append '$desc' to ${file/#$HOME/\~}"; return; fi
  hypr_touch "$file"; printf '\n%s\n' "$content" >>"$file"
  echo "  applying $desc"; hypr_pending+=("$desc")
}

hypr_finish() {
  ((${#hypr_files[@]})) || return 0
  if ! hypr_live; then
    for d in "${hypr_pending[@]}"; do fix "$d (Hyprland not running, unvalidated)"; done
    hypr_files=(); hypr_pending=(); return 0
  fi
  timeout 10 hyprctl reload >/dev/null 2>&1; sleep 1
  if [[ -z $(timeout 10 hyprctl configerrors 2>/dev/null | tr -d '[:space:]') ]]; then
    for d in "${hypr_pending[@]}"; do fix "$d"; done
  else
    for f in "${hypr_files[@]}"; do cp -p "$f.bak.setup.$TS" "$f"; done
    timeout 10 hyprctl reload >/dev/null 2>&1
    warn "edits caused Hyprland config errors; rolled back: ${hypr_pending[*]}"
  fi
  hypr_files=(); hypr_pending=()
}

# ensure_line FILE LINE DESC — append LINE if no identical line exists.
ensure_line() {
  local file=$1 line=$2 desc=$3
  if [[ -f $file ]] && grep -qxF -- "$line" "$file"; then ok "$desc"; return; fi
  if [[ ! -f $file ]]; then
    if ((DRY_RUN)); then echo "  [dry-run] create $file with: $line"; return; fi
    mkdir -p "$(dirname "$file")"
  fi
  backup "$file"
  if ((DRY_RUN)); then echo "  [dry-run] append to ${file/#$HOME/\~}: $line"; else printf '%s\n' "$line" >>"$file"; fi
  fix "$desc"
}

# ensure_sysfile PATH MODE DESC CONTENT — install a root-owned file if missing or
# different, using sudo. Prompts for a password if needed (restore is interactive).
ensure_sysfile() {
  local path=$1 mode=$2 desc=$3 content=$4 tmp
  if [[ -f $path && "$(<"$path")" == "$content" ]]; then ok "$desc"; return; fi
  if ((DRY_RUN)); then echo "  [dry-run] sudo install $path (mode $mode)"; fix "$desc (dry-run)"; return; fi
  tmp=$(mktemp); printf '%s\n' "$content" >"$tmp"
  if sudo install -D -m "$mode" "$tmp" "$path"; then fix "$desc"; else warn "$desc: sudo install failed for $path"; fi
  rm -f "$tmp"
}

# jq_set FILE FILTER DESC — apply a jq filter to a JSON file, validate, swap in.
jq_set() {
  local file=$1 filter=$2 desc=$3 tmp
  if [[ ! -f $file ]] || ! jq empty "$file" >/dev/null 2>&1; then warn "$desc: $file missing or invalid JSON"; return; fi
  if ((DRY_RUN)); then echo "  [dry-run] jq '$filter' on ${file/#$HOME/\~}"; fix "$desc (dry-run)"; return; fi
  backup "$file"; tmp=$(mktemp)
  if jq "$filter" "$file" >"$tmp" && jq empty "$tmp" >/dev/null 2>&1; then cat "$tmp" >"$file"; fix "$desc"; else warn "$desc: jq edit failed, left alone"; fi
  rm -f "$tmp"
}

# register_plugin ID — add {"id": ID} to shell.json .plugins (converting a bare
# string form), idempotently.
register_plugin() {
  local id=$1 sj="$HOME/.config/omarchy/shell.json"
  if [[ -f $sj ]] && jq -e --arg id "$id" '(.plugins // []) | any(type=="object" and .id==$id)' "$sj" >/dev/null 2>&1; then
    ok "plugin enabled: $id"; return
  fi
  jq_set "$sj" '.plugins = ([(.plugins // [])[] | select(. != "'"$id"'")] + [{"id": "'"$id"'"}])' "plugin enabled: $id"
}
