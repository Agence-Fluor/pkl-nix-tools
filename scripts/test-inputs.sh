#!/usr/bin/env bash
set -euo pipefail
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-XX:-UsePerfData"
repo=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
server_pid=
cleanup() {
  [[ -z $server_pid ]] || kill "$server_pid" 2>/dev/null || true
  rm -rf -- "$work"
}
trap cleanup EXIT
mkdir -p "$work/producer" "$work/consumer" "$work/dist/source/.pkl-nix-tools"
for project in producer consumer; do
  cp "$repo/PklProject" "$repo/PklProject.deps.json" "$work/$project/"
done
head -n 1 "$repo/flake.pkl" > "$work/producer/flake.pkl"
cat >> "$work/producer/flake.pkl" <<PKL
amends "@nix/Flake.pkl"
import "@nix/Nix.pkl" as Nix
local launcher = import("$repo/Bootstrap.pkl").output.text
custom {
  ["message"] = new Nix.Apply {
    callee = new Nix.Ref { path = "builtins.readFile" }
    arguments { new Nix.Path { value = "../message.txt" } }
  }
}
PKL
printf 'from the complete source tree' > "$work/producer/message.txt"
chmod +x "$work/producer/flake.pkl"
(cd "$work/producer" && ./flake.pkl generate)

consumer() {
  head -n 1 "$repo/flake.pkl" > "$work/consumer/flake.pkl"
  cat >> "$work/consumer/flake.pkl" <<PKL
amends "@nix/Flake.pkl"
import "@nix/Nix.pkl" as Nix
local launcher = import("$repo/Bootstrap.pkl").output.text
inputs {
  ["producer"] = new Nix.Input { url = "$1?dir=.pkl-nix-tools" }
}
custom { ["message"] = new Nix.Ref { path = "inputs.producer.message" } }
PKL
  chmod +x "$work/consumer/flake.pkl"
  (
    cd "$work/consumer"
    ./flake.pkl flake update producer
    nix --extra-experimental-features 'nix-command flakes' eval \
      "path:$PWD?dir=.pkl-nix-tools#message" --raw --no-write-lock-file > "$work/actual"
    cmp "$work/actual" "$work/expected"
    [[ -f flake.lock && ! -e flake.nix && flake.lock -ef .pkl-nix-tools/flake.lock ]]
  )
}
cp "$work/producer/message.txt" "$work/expected"
consumer "path:$work/producer"
printf 'updated local source' > "$work/producer/message.txt"
cp "$work/producer/message.txt" "$work/expected"
(cd "$work/producer" && ./flake.pkl generate)
consumer "path:$work/producer"

# Serve the same source tree as a release asset; Pkl is absent from the archive.
cp "$work/producer/message.txt" "$work/dist/source/"
cp "$work/producer/.pkl-nix-tools/flake.nix" "$work/dist/source/.pkl-nix-tools/"
tar -czf "$work/dist/producer.tar.gz" -C "$work/dist" source
python3 - "$work/dist" "$work/address" <<'PY' >"$work/server.log" 2>&1 &
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import sys
server = ThreadingHTTPServer(('127.0.0.1', 0), partial(SimpleHTTPRequestHandler, directory=sys.argv[1]))
Path(sys.argv[2]).write_text(f'127.0.0.1:{server.server_port}')
server.serve_forever()
PY
server_pid=$!
for ((attempt=0; attempt<50; attempt++)); do
  [[ ! -s $work/address ]] || break
  sleep 0.1
done
[[ -s $work/address ]] || { cat "$work/server.log" >&2; exit 1; }
consumer "http://$(cat "$work/address")/producer.tar.gz"
printf 'Local and HTTP archive inputs preserve the complete project sources\n'
