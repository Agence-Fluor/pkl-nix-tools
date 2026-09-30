#!/usr/bin/env bash
set -euo pipefail
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-XX:-UsePerfData"
repo=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/package"
cp "$repo"/{PklProject,PklProject.deps.json,imports.pkl,install.pkl,pkl-nix-tools} "$work/package/"
cp -R "$repo/example" "$work/package/example"
cd "$work/package/example"
pkl project resolve
pkl run install.pkl --directory "$work/bin"
chmod +x "$work/bin/pkl-nix-tools"
export PATH="$work/bin:$PATH"
pkl eval flake.pkl > "$work/rendered.nix"
nix-instantiate --parse "$work/rendered.nix" >/dev/null
cp flake.lock "$work/original.lock"
./flake.pkl flake lock
./flake.pkl build --no-link
expected=$(cat message.txt)
[[ $(./flake.pkl run .#hello) == "$expected" ]]
[[ $(./flake.pkl develop --command hello-pkl) == "$expected" ]]
./flake.pkl develop --command true
cmp flake.lock "$work/original.lock"
./flake.pkl flake check
rm -rf .pkl-nix-tools
./flake.pkl flake metadata --json > "$work/metadata.json"
cmp flake.lock "$work/original.lock"
[[ ! -e flake.nix && ! -L flake.nix && ! -e .pkl-nix-tools/flake.lock ]]
printf 'Real Nix build, run, develop, check and cache recovery passed\n'
