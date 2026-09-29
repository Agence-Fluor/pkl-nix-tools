#!/bin/sh
set -eu

repo=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
cd "$repo"
output_path=${1:-dist/package}
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT HUP INT TERM

mkdir -p "$output_path"
cp PklProject PklProject.deps.json imports.pkl pkl-nix-tools "$stage/"
pkl project package --skip-publish-check --output-path "$output_path" "$stage"
