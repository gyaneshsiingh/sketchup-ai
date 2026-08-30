#!/usr/bin/env bash
# Packages the plugin into dist/opencode_studio.rbz (a zip SketchUp installs).
set -euo pipefail
cd "$(dirname "$0")"

command -v zip >/dev/null || { echo "zip not found"; exit 1; }

# Syntax-check all Ruby files first.
find opencode_studio.rb opencode_studio mcp -name '*.rb' -print0 | while IFS= read -r -d '' f; do
  ruby -c "$f" >/dev/null || { echo "Syntax error in $f"; exit 1; }
done

mkdir -p dist
rm -f dist/opencode_studio.rbz
zip -r dist/opencode_studio.rbz opencode_studio.rb opencode_studio \
  -x '*.DS_Store' -x '*~' >/dev/null
echo "Built dist/opencode_studio.rbz (mcp/ stdio proxy ships with the repo; copy it next to the plugin if needed)"
