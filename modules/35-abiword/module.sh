MOD_DESC="AbiWord: lightweight WordPad-style editor, set as default for text files"
MOD_SUDO="yes"
MOD_DEPS=""
MOD_REQUIRES="xdg-mime"

# AbiWord is a small rich-text word processor (rtf/doc/odt/txt/html) — the
# WordPad equivalent. Set as the default handler for plain text files.
check() {
  command -v abiword >/dev/null && ok "abiword already installed" \
    || echo "  info   abiword not installed yet; apply will try to install it (needs sudo)"
}

apply() {
  if ! command -v abiword >/dev/null 2>&1; then
    if ((DRY_RUN)); then echo "  [dry-run] sudo pacman -S --needed --noconfirm abiword"
    elif command -v pacman >/dev/null && sudo pacman -S --needed --noconfirm abiword >/dev/null 2>&1; then
      fix "abiword installed"
    else
      warn "could not install abiword automatically; run: sudo pacman -S --needed abiword"
    fi
  else
    ok "abiword installed"
  fi

  # Default app for plain text files.
  if command -v abiword >/dev/null 2>&1; then
    if [[ "$(xdg-mime query default text/plain 2>/dev/null)" == abiword.desktop ]]; then
      ok "AbiWord is the default for text files"
    elif ((DRY_RUN)); then
      echo "  [dry-run] xdg-mime default abiword.desktop text/plain"
    else
      xdg-mime default abiword.desktop text/plain && fix "AbiWord set as default for text/plain"
    fi
  fi
}
