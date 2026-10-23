#!/usr/bin/env bash
# omarchy-vedacool bootstrap installer.
#
# One-liners:
#   bash <(curl -fsSL https://raw.githubusercontent.com/vedacool/omarchy-vedacool/main/install.sh)
#       -> clone/update, show modules, then the interactive picker
#   curl -fsSL https://raw.githubusercontent.com/vedacool/omarchy-vedacool/main/install.sh | bash -s -- --check
#       -> dependency + compatibility check only, no changes
#   curl -fsSL .../install.sh | bash -s -- 20-hypr-desktop 30-chrome-flags --yes
#       -> clone/update, then restore just those modules (preflight must pass)
#   curl -fsSL .../install.sh | bash -s -- --all --yes
#       -> restore everything (preflight gates it; skips modules whose deps are missing)
#
# It only pulls the repo and hands off to ./setup.sh — setup.sh does the
# preflight gate, backups, and idempotent apply. Nothing is changed unless the
# preflight passes and you confirm (or pass --yes).

set -euo pipefail

REPO="${OMARCHY_VEDACOOL_REPO:-vedacool/omarchy-vedacool}"
BRANCH="${OMARCHY_VEDACOOL_BRANCH:-main}"
DEST="${OMARCHY_VEDACOOL_DIR:-$HOME/omarchy-vedacool}"

say() { printf '\033[1m[omarchy-vedacool]\033[0m %s\n' "$*"; }

command -v git >/dev/null || { echo "git is required (install it first: sudo pacman -S git)"; exit 1; }

if [[ -d $DEST/.git ]]; then
  say "Updating existing checkout at $DEST"
  git -C "$DEST" pull --ff-only || say "could not fast-forward; using the checkout as-is"
else
  say "Cloning $REPO -> $DEST"
  git clone --depth 1 -b "$BRANCH" "https://github.com/$REPO.git" "$DEST"
fi

cd "$DEST"
chmod +x setup.sh lib/*.sh 2>/dev/null || true

if (($#)); then
  exec ./setup.sh "$@"
else
  ./setup.sh --list
  echo
  say "Run the picker now (or later: cd $DEST && ./setup.sh)"
  ./setup.sh || true
fi
