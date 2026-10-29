#!/usr/bin/env bash
# SessionStart hook: keep ~/.claude/statusline.sh current and wired into settings.json.
# Runs every session and is idempotent. Mirrors the sbx kit's startup command in spec.yaml.
set -eu

src="${CLAUDE_PLUGIN_ROOT}/files/home/.claude/statusline.sh"
dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
dst="$dir/statusline.sh"
f="$dir/settings.json"

command -v jq >/dev/null 2>&1 || { echo "sbx-statusline: jq not found, skipping" >&2; exit 0; }

mkdir -p "$dir"
cmp -s "$src" "$dst" 2>/dev/null || { cp "$src" "$dst.tmp" && chmod +x "$dst.tmp" && mv "$dst.tmp" "$dst"; }

[ -s "$f" ] || echo '{}' > "$f"
want=$(jq -n --arg cmd "$dst" '{
  statusLine: {type: "command", command: $cmd, refreshInterval: 30},
  preferredNotifChannel: "terminal_bell"
}')
# rewrite only when something differs, so settings.json is not touched every session
if ! jq -e --argjson want "$want" '. + $want == .' "$f" >/dev/null 2>&1; then
  jq --argjson want "$want" '. + $want' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
fi
