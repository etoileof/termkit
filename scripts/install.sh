#!/bin/sh
set -eu

bundle_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_root="$bundle_root/source"
config_template="$bundle_root/config/config.toml.example"
config_dir="$HOME/.kimi-code"
config_path="$config_dir/config.toml"
tui_config_path="$config_dir/tui.toml"

node_version=$(node --version 2>/dev/null | tr -d 'v') || {
  printf '%s\n' 'Node.js 24.15 or newer is required.' >&2
  exit 1
}
node -e 'const [major, minor] = process.argv[1].split(".").map(Number); if (major < 24 || (major === 24 && minor < 15)) process.exit(1)' "$node_version" || {
  printf 'Node.js 24.15 or newer is required; found %s.\n' "$node_version" >&2
  exit 1
}

command -v corepack >/dev/null 2>&1 || {
  printf '%s\n' 'Corepack is required to activate pnpm 10.33.0.' >&2
  exit 1
}

if [ -z "${CLOSEROUTER_API_KEY:-}" ] && [ -t 0 ]; then
  printf 'CloseRouter API key (leave blank to set it later): '
  stty -echo
  IFS= read -r CLOSEROUTER_API_KEY || true
  stty echo
  printf '\n'
  export CLOSEROUTER_API_KEY
fi

if [ ! -f "$config_path" ]; then
  mkdir -p "$config_dir"
  cp "$config_template" "$config_path"
  chmod 600 "$config_path"
  printf 'Created Kimi configuration at %s\n' "$config_path"
else
  printf 'Keeping existing Kimi configuration at %s\n' "$config_path"
fi

# Kimi's auto-updater would replace this custom build with the official npm release.
if [ ! -f "$tui_config_path" ]; then
  printf '%s\n' '[upgrade]' 'auto_install = false' > "$tui_config_path"
  printf 'Disabled Kimi auto-update in %s\n' "$tui_config_path"
elif grep -q '^auto_install = true' "$tui_config_path"; then
  tui_config_tmp=$(mktemp)
  sed 's/^auto_install = true/auto_install = false/' "$tui_config_path" > "$tui_config_tmp"
  cat "$tui_config_tmp" > "$tui_config_path"
  rm -f "$tui_config_tmp"
  printf 'Disabled Kimi auto-update in %s\n' "$tui_config_path"
fi

cd "$source_root"
corepack pnpm install
corepack pnpm run build:packages
corepack pnpm --filter @moonshot-ai/kimi-code run build
(cd apps/kimi-code && npm link)

if [ -n "${CLOSEROUTER_API_KEY:-}" ]; then
  printf '%s\n' 'CloseRouter key is available for this Terminal session.'
else
  printf '%s\n' 'No key entered. Set CLOSEROUTER_API_KEY before launching kimi.'
fi
printf '%s\n' 'CustomKIMI is installed. Run: kimi --version'
