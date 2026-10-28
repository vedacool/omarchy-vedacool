#!/usr/bin/env bash
# export.sh — re-capture module payloads from THIS live machine into the repo.
#
# The repo is a generated snapshot of my real setup. After I change something
# worth keeping (a plugin, a theme, the bar layout, the hook), run this to pull
# the current files back into modules/*/payload, then commit. One source of
# truth: the live machine. No hand-syncing files.
#
#   ./export.sh            refresh all modules' payloads from $HOME, show a diff
#   ./export.sh --commit   also git-commit the refresh
#
# Each module declares EXPORT_PATHS (space-separated $HOME-relative paths, files
# or dirs) and/or an export_extra() function for dynamic bits (e.g. the bar
# layout read from shell.json).

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODDIR="$ROOT/modules"
DO_COMMIT=0; [[ ${1:-} == --commit ]] && DO_COMMIT=1

missing=0

sync_one() { # rel  payload_dir
  local rel="$1"
  local pdir="$2"
  local live="$HOME/$rel"
  local dest="$pdir/$rel"
  if [[ -z $rel || $dest == "$pdir/" ]]; then echo "  SKIP     empty path"; return; fi
  if [[ ! -e $live ]]; then echo "  MISSING  $rel (not on this machine — left as-is)"; missing=$((missing+1)); return; fi
  mkdir -p "$(dirname "$dest")"
  if [[ -d $live ]]; then rm -rf "$dest"; cp -a "$live" "$dest"; else cp -a "$live" "$dest"; fi
  echo "  ok       $rel"
}

for d in "$MODDIR"/*/; do
  id=$(basename "$d")
  out=$(
    EXPORT_PATHS=""; MODULE_DIR="${d%/}"
    source "$d/module.sh" >/dev/null 2>&1
    has_extra=0; declare -F export_extra >/dev/null && has_extra=1
    [[ -z $EXPORT_PATHS && $has_extra -eq 0 ]] && exit 0
    echo "== $id"
    for rel in $EXPORT_PATHS; do sync_one "$rel" "$d/payload"; done
    ((has_extra)) && export_extra
  )
  [[ -n $out ]] && echo "$out"
done

# drop any stray backups + audit memory swept in from the live tree
find "$MODDIR" -name '*.bak.*' -delete 2>/dev/null
find "$MODDIR" -type d \( -name '.audit' -o -name '__pycache__' \) -exec rm -rf {} + 2>/dev/null

echo
echo "Changes vs committed:"
git -C "$ROOT" status --short modules | sed 's/^/  /' | head -40
((missing)) && echo -e "\n  ($missing path(s) not present on this machine — see MISSING above)"

if ((DO_COMMIT)); then
  git -C "$ROOT" add -A modules
  if git -C "$ROOT" diff --cached --quiet; then
    echo -e "\nNothing changed — repo already matches the live machine."
  else
    git -C "$ROOT" -c commit.gpgsign=false commit -q -m "Refresh payloads from live machine ($(date +%F))"
    echo -e "\nCommitted. Push with: git -C $ROOT push"
  fi
else
  echo -e "\nReview: git -C $ROOT diff"
  echo "Keep it: ./export.sh --commit   (or git add -A && git commit)"
fi
