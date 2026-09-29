#!/bin/sh
set -eu

repo=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT HUP INT TERM

bash "$repo/test.sh"
sh "$repo/scripts/package-pkl.sh" "$temp/dist"
version=$(pkl eval --no-project -x 'package.version' "$repo/PklProject")
archive="$temp/dist/pkl-nix-tools@$version.zip"
files=$(unzip -Z1 "$archive" | sort)
test "$files" = "$(printf 'imports.pkl\npkl-nix-tools')"
mkdir -p "$temp/package" "$temp/consumer"
unzip -q "$archive" -d "$temp/package"
chmod +x "$temp/package/pkl-nix-tools"
cp "$repo/PklProject" "$temp/package/PklProject"
cat > "$temp/consumer/PklProject" <<'EOF'
amends "pkl:Project"
dependencies {
  ["tools"] = import("../package/PklProject")
}
EOF
cat > "$temp/consumer/entry.pkl" <<'EOF'
value = "packaged"
EOF
cat > "$temp/consumer/check.pkl" <<'EOF'
import "@tools/imports.pkl" as Imports
output { text = Imports.output.text }
EOF
cd "$temp/consumer"
pkl project resolve >/dev/null
pkl eval --property "entry=file://$temp/consumer/entry.pkl" check.pkl > "$temp/imports.txt"
grep -Fq "file://$temp/consumer/entry.pkl" "$temp/imports.txt"
cat > "$temp/consumer/flake.pkl" <<'EOF'
#!/usr/bin/env -S pkl-nix-tools
output { text = "{ outputs = { self, ... }: { }; }" }
EOF
chmod +x "$temp/consumer/flake.pkl"
PATH="$temp/package:$PATH" ./flake.pkl generate
nix-instantiate --parse .pkl-nix-tools/flake.nix >/dev/null
printf 'pkl-nix-tools package tests passed\n'
