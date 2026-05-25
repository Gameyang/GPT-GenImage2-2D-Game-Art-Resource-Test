#!/bin/sh

set -u

REPO_ROOT="/Users/yang.jin/workspace/GPT-GenImage2-2D-Game-Art-Resource-Test"
ORIGINAL_NOTIFY="/Users/yang.jin/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient"
PUBLISH_SCRIPT="$REPO_ROOT/scripts/publish-work-result.js"

input_file="$(mktemp "${TMPDIR:-/tmp}/codex-turn-ended.XXXXXX")"
trap 'rm -f "$input_file"' EXIT

cat > "$input_file" || true

if [ -x "$ORIGINAL_NOTIFY" ]; then
  "$ORIGINAL_NOTIFY" turn-ended < "$input_file" >/dev/null 2>&1 || true
fi

current_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"

if [ "$current_root" = "$REPO_ROOT" ] && [ -f "$PUBLISH_SCRIPT" ]; then
  node "$PUBLISH_SCRIPT" \
    --hook-input "$input_file" \
    --require-cwd-match \
    --quiet >/dev/null 2>&1 || true
fi
