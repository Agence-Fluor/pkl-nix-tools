#!/bin/sh
set -eu
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-XX:-UsePerfData"

repo=$(CDPATH='' cd "$(dirname "$0")/.." && pwd)
temp=$(mktemp -d)
server_pid=
cleanup() {
  if [ -n "$server_pid" ]; then kill "$server_pid" 2>/dev/null || true; fi
  rm -rf "$temp"
}
trap cleanup EXIT HUP INT TERM

bash "$repo/test.sh"
sh "$repo/scripts/package-pkl.sh" "$temp/dist"
version=$(pkl eval --no-project -x 'package.version' "$repo/PklProject")
archive="$temp/dist/pkl-nix-tools@$version.zip"
files=$(unzip -Z1 "$archive" | sort)
test "$files" = "$(printf 'imports.pkl\ninstall.pkl\npkl-nix-tools')"
mkdir -p "$temp/package" "$temp/consumer"
unzip -q "$archive" -d "$temp/package"

# Exercise an actual package:// dependency with a fresh cache, including resource reads.
python3 - "$temp/dist" "$temp/address" >"$temp/server.log" 2>&1 <<'PY' &
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import sys
server = ThreadingHTTPServer(('127.0.0.1', 0), partial(SimpleHTTPRequestHandler, directory=sys.argv[1]))
Path(sys.argv[2]).write_text(f'127.0.0.1:{server.server_port}')
server.serve_forever()
PY
server_pid=$!
attempt=0
until [ -s "$temp/address" ]; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 50 ] || ! kill -0 "$server_pid" 2>/dev/null; then
    cat "$temp/server.log" >&2
    exit 1
  fi
  sleep 0.1
done
address=$(cat "$temp/address")
cat > "$temp/consumer/PklProject.template" <<'PKL'
amends "pkl:Project"
dependencies {
  ["tools"] { uri = "package://pkg.pkl-lang.org/github.com/Agence-Fluor/pkl-nix-tools/pkl-nix-tools@@VERSION@" }
  ["nix"] { uri = "package://pkg.pkl-lang.org/github.com/Agence-Fluor/pkl-nix/pkl-nix@0.1.0" }
}
evaluatorSettings {
  moduleCacheDir = ".pkl-cache"
  http {
    rewrites {
      ["https://pkg.pkl-lang.org/github.com/Agence-Fluor/pkl-nix-tools/"] = "http://@ADDRESS@/"
      ["https://github.com/Agence-Fluor/pkl-nix-tools/releases/download/pkl-nix-tools@@VERSION@/"] = "http://@ADDRESS@/"
    }
  }
}
PKL
sed -e "s/@VERSION@/$version/g" -e "s/@ADDRESS@/$address/g" "$temp/consumer/PklProject.template" > "$temp/consumer/PklProject"
cat > "$temp/consumer/flake.pkl" <<'PKL'
#!/usr/bin/env -S pkl eval
amends "@nix/Flake.pkl"
description = "packaged consumer"
PKL
chmod +x "$temp/consumer/flake.pkl"
cd "$temp/consumer"
pkl project resolve >/dev/null
pkl run @tools/install.pkl --directory "$temp/installed"
cmp "$temp/installed/pkl-nix-tools" "$temp/package/pkl-nix-tools"
cmp "$temp/installed/imports.pkl" "$temp/package/imports.pkl"
chmod +x "$temp/installed/pkl-nix-tools"
PATH="$temp/installed:$PATH" pkl-nix-tools generate
nix-instantiate --parse .pkl-nix-tools/flake.nix >/dev/null
grep -Fq 'description = "packaged consumer"' .pkl-nix-tools/flake.nix
printf 'pkl-nix-tools package tests passed\n'
