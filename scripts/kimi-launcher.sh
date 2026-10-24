#!/bin/sh
# CustomKIMI auth launcher for this Mac. Installed over the `kimi` link that
# `npm link` creates (update.sh reinstalls it after every update and rollback).
# It exports the API keys from the login Keychain for EVERY launch context
# (interactive, non-interactive, scripts, 'kimi web', '/web') and turns off
# Kimi's own auto-updater. It runs whatever build the npm link points at, so
# --rollback keeps working. OPENROUTER_MANAGEMENT_KEY is deliberately NOT
# exported: Kimi reads it from the Keychain itself.
for key in CLOSEROUTER_API_KEY SEVENAPI_API_KEY OPENROUTER_API_KEY; do
  eval "val=\${$key:-}"
  if [ -z "$val" ]; then
    val="$(security find-generic-password -a "$USER" -s "$key" -w 2>/dev/null || true)"
    [ -n "$val" ] && export "$key=$val"
  fi
done
export KIMI_CODE_NO_AUTO_UPDATE=1
exec node "/opt/homebrew/lib/node_modules/@moonshot-ai/kimi-code/dist/main.mjs" "$@"
