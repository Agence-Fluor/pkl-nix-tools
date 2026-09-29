#!/bin/sh
set -eu

readme_url=https://github.com/Agence-Fluor/pkl-nix-tools#nixos
os_release=${PKL_NIX_TOOLS_OS_RELEASE_FILE:-/etc/os-release}
os_marker=${PKL_NIX_TOOLS_NIXOS_MARKER:-/etc/NIXOS}
if [ -e "$os_marker" ] || { [ -f "$os_release" ] && grep -Eq '^ID="?nixos"?$' "$os_release"; }; then
  printf 'NixOS détecté. Installez pkl-nix-tools via configuration.nix :\n%s\n' "$readme_url"
  exit 0
fi

fail() { printf 'pkl-nix-tools install: %s\n' "$*" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || fail 'curl est requis'
: "${HOME:?HOME est requis}"

tools_url=${PKL_NIX_TOOLS_BASE_URL:-https://raw.githubusercontent.com/Agence-Fluor/pkl-nix-tools/main}
install_dir=${PKL_NIX_TOOLS_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/pkl-nix-tools}
bin_dir=${PKL_NIX_TOOLS_BIN_DIR:-$HOME/.local/bin}
parent_dir=${install_dir%/*}
case "$install_dir:$bin_dir" in
  /*:/*) ;;
  *) fail 'les chemins d’installation doivent être absolus' ;;
esac

mkdir -p "$parent_dir" "$bin_dir"
if [ -e "$bin_dir/pkl-nix-tools" ] || [ -L "$bin_dir/pkl-nix-tools" ]; then
  [ -L "$bin_dir/pkl-nix-tools" ] &&
    [ "$(readlink "$bin_dir/pkl-nix-tools")" = "$install_dir/bin/pkl-nix-tools" ] ||
    fail "$bin_dir/pkl-nix-tools existe déjà et ne pointe pas vers cette installation"
fi
if [ -e "$install_dir" ] || [ -L "$install_dir" ]; then
  [ -d "$install_dir" ] && [ ! -L "$install_dir" ] &&
    [ -f "$install_dir/bin/pkl-nix-tools" ] && [ -f "$install_dir/bin/imports.pkl" ] ||
    fail "$install_dir existe déjà et ne ressemble pas à une installation pkl-nix-tools"
fi

stage=$(mktemp -d "$parent_dir/.pkl-nix-tools-install.XXXXXXXX")
backup=
cleanup() {
  [ -z "$stage" ] || rm -rf "$stage"
  if [ -n "$backup" ]; then
    if [ -e "$install_dir" ]; then rm -rf "$backup"; else mv "$backup" "$install_dir"; fi
  fi
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$stage/bin"

curl -fsSL "$tools_url/pkl-nix-tools" -o "$stage/bin/pkl-nix-tools"
curl -fsSL "$tools_url/imports.pkl" -o "$stage/bin/imports.pkl"
chmod +x "$stage/bin/pkl-nix-tools"

if ! command -v pkl >/dev/null 2>&1; then
  if [ -n "${PKL_NIX_TOOLS_PKL_URL:-}" ]; then
    pkl_url=$PKL_NIX_TOOLS_PKL_URL
  else
    case "$(uname -s):$(uname -m)" in
      Linux:x86_64) platform=linux-amd64 ;;
      Linux:aarch64|Linux:arm64) platform=linux-aarch64 ;;
      Darwin:x86_64) platform=macos-amd64 ;;
      Darwin:arm64|Darwin:aarch64) platform=macos-aarch64 ;;
      *) fail 'plateforme Pkl non prise en charge ; installez Pkl manuellement' ;;
    esac
    pkl_url="https://github.com/apple/pkl/releases/download/0.31.1/pkl-$platform"
  fi
  curl -fsSL "$pkl_url" -o "$stage/bin/pkl"
  chmod +x "$stage/bin/pkl"
fi

if [ -d "$install_dir" ]; then
  backup=$(mktemp -d "$parent_dir/.pkl-nix-tools-previous.XXXXXXXX")
  rmdir "$backup"
  mv "$install_dir" "$backup"
fi
mv "$stage" "$install_dir"
stage=
if [ ! -L "$bin_dir/pkl-nix-tools" ]; then
  ln -s "$install_dir/bin/pkl-nix-tools" "$bin_dir/pkl-nix-tools"
fi
printf 'pkl-nix-tools installé dans %s\n' "$install_dir"
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) printf 'Ajoutez %s à votre PATH.\n' "$bin_dir" ;;
esac
if ! command -v nix >/dev/null 2>&1; then
  printf 'Nix reste à installer séparément pour utiliser flake.pkl.\n'
fi
