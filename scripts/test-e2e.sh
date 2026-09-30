#!/usr/bin/env bash
set -euo pipefail
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-XX:-UsePerfData"
repo=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/package"
cp "$repo"/{PklProject,PklProject.deps.json,Bootstrap.pkl,install.pkl,pkl-nix-tools} "$work/package/"
cp -R "$repo/example" "$work/package/example"
cd "$work/package/example"
pkl project resolve
# A bogus global command proves the shebang uses the project dependency.
mkdir "$work/bin"
printf '#!/bin/sh\necho "global launcher used" >&2\nexit 99\n' > "$work/bin/pkl-nix-tools"
chmod +x "$work/bin/pkl-nix-tools"
export PATH="$work/bin:$PATH"
pkl eval flake.pkl > "$work/rendered.nix"
nix-instantiate --parse "$work/rendered.nix" >/dev/null
cp flake.lock "$work/original.lock"
./flake.pkl flake lock
./flake.pkl build --no-link
expected=$(cat message.txt)
[[ $(./flake.pkl run .#hello) == "$expected" ]]
[[ $(./flake.pkl develop --command hello-pkl 2> "$work/develop.stderr") == "$expected" ]]
if grep -q 'Removed input' "$work/develop.stderr"; then cat "$work/develop.stderr" >&2; exit 1; fi
./flake.pkl develop --command true
cmp flake.lock "$work/original.lock"
./flake.pkl flake check
rm -rf .pkl-nix-tools
./flake.pkl flake metadata --json > "$work/metadata.json"
cmp flake.lock "$work/original.lock"
[[ ! -e flake.nix && ! -L flake.nix && flake.lock -ef .pkl-nix-tools/flake.lock ]]
# Atomic replacement of the root lock must rebind the generated hard link.
cp flake.lock "$work/replacement.lock"
mv "$work/replacement.lock" flake.lock
./flake.pkl develop --command true 2> "$work/develop.stderr"
if grep -q 'Removed input' "$work/develop.stderr"; then cat "$work/develop.stderr" >&2; exit 1; fi
[[ flake.lock -ef .pkl-nix-tools/flake.lock ]]
cmp flake.lock "$work/original.lock"
# First use without any lock also writes only the root file before linking it.
rev=$(nix --extra-experimental-features 'nix-command flakes' eval --impure --raw \
  --expr '(builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked.rev')
rm flake.lock .pkl-nix-tools/flake.lock
./flake.pkl develop --override-input nixpkgs "github:NixOS/nixpkgs/$rev" --command true 2> "$work/develop.stderr"
if grep -q 'Removed input' "$work/develop.stderr"; then cat "$work/develop.stderr" >&2; exit 1; fi
[[ flake.lock -ef .pkl-nix-tools/flake.lock ]]
cmp flake.lock "$work/original.lock"
printf 'Real Nix build, run, develop, check and cache recovery passed\n'
