#!/bin/sh
# f2w : installeur en une commande.
#   curl -fsSL https://kryve.fr/f2w | sh
# Télécharge l'installeur interactif de la dernière version publiée, vérifie sa somme SHA-256, puis le lance.
# Options transmises à l'installeur : curl -fsSL https://kryve.fr/f2w | sh -s -- --help
set -eu

REPO="${F2W_INSTALLER_REPO:-louislaurent1/f2w-installer}"
BASE="${F2W_INSTALLER_BASE:-https://github.com/$REPO/releases/latest/download}"

os=$(uname -s)
arch=$(uname -m)
case "$os/$arch" in
  Darwin/*) asset=f2w-install-macos-universal ;;
  Linux/x86_64 | Linux/amd64) asset=f2w-install-linux-x86_64 ;;
  Linux/aarch64 | Linux/arm64) asset=f2w-install-linux-aarch64 ;;
  *)
    echo "f2w : système non pris en charge ($os $arch). f2w tourne sur macOS ou Linux (sous Windows : WSL)." >&2
    exit 1
    ;;
esac

if command -v shasum >/dev/null 2>&1; then
  sha() { shasum -a 256 "$1" | cut -d ' ' -f 1; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha() { sha256sum "$1" | cut -d ' ' -f 1; }
else
  echo "f2w : ni shasum ni sha256sum, impossible de vérifier le téléchargement." >&2
  exit 1
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/f2w-install.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
trap 'exit 130' INT TERM

echo "f2w : téléchargement de l'installeur…"
if ! curl -fsSL --retry 2 -o "$tmp/$asset" "$BASE/$asset" || ! curl -fsSL --retry 2 -o "$tmp/$asset.sha256" "$BASE/$asset.sha256"; then
  echo "f2w : téléchargement impossible depuis $BASE. Vérifie ta connexion, puis relance la commande." >&2
  exit 1
fi
want=$(cut -d ' ' -f 1 <"$tmp/$asset.sha256")
got=$(sha "$tmp/$asset")
if [ "$want" != "$got" ]; then
  echo "f2w : la somme de contrôle ne correspond pas, installation annulée (fichier corrompu ou modifié)." >&2
  exit 1
fi
chmod +x "$tmp/$asset"

# Piped into sh, our stdin is the script itself: the installer reads the keyboard from the terminal.
status=0
if [ -t 1 ] && (: </dev/tty) 2>/dev/null; then
  "$tmp/$asset" "$@" </dev/tty || status=$?
else
  "$tmp/$asset" "$@" || status=$?
fi
exit "$status"
