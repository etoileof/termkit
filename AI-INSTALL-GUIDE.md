# AI Installation Guide: CustomKIMI

## Objective

Install this CustomKIMI bundle on a new Windows or macOS/Linux computer, or update an existing install to a new Kimi Code release. CustomKIMI is official Kimi Code plus the patches in `custom/patches/`, described in `custom/FEATURES.md`:

- CloseRouter usage cost carried from `usage.cost` through session totals
- Live CloseRouter balance and session cost in the footer
- `/wipe-all-sessions confirm`
- node-pty permission fix for the install script
- Provider balance in the web UI
- CloseRouter context limits, output limits and reasoning efforts refreshed from CloseRouter at startup
- Session cost that includes every subagent
- OpenRouter balance and session cost in the footer and web UI
- OpenRouter context limits, output limits and reasoning efforts refreshed from OpenRouter's public model list at startup
- Bounded retries for provider HTTP 524 gateway timeouts, with a visible retry notice in the terminal and web chat
- Per-model `extra_body` request fields for OpenAI-style models (used to pin `openrouter/qwen3.8-27b` to Cerebras)
- Each model's context window shown in the `/model` picker, in the same round numbers as the footer
- Agent dock: every subagent of the session as a row under the conversation (status dot, model, effort, tool count, elapsed time, current tool); `↓` on an empty editor focuses it, `Enter` shows that agent's conversation live, `Esc` returns

The CloseRouter provider (GPT-6 Astra, GPT-6.1 Sol, DeepSeek, GLM 5.3, GLM 5.3 Flash, Gemini 4 Argon, Grok 4.7, Claude Fable 5.1 and 5, Claude Opus) and the 7api provider (35 models at `https://7api.st`, aliases `7api/<model>`) are configuration in `config/config.toml.example`, not patches. So is the OpenRouter provider (`https://openrouter.ai/api/v1`, aliases `openrouter/muse-wonder`, `openrouter/kimi-k3.1-pro` and `openrouter/qwen3.8-27b`).

## Security rules

Never search for, print, copy, or commit the API key. It is intentionally absent from this bundle. Obtain it from the operator securely and place it only in the current process environment, the operating system user environment, or the macOS Keychain.

In `config.toml`, `api_key_env` must be an environment variable name (`CLOSEROUTER_API_KEY` or `SEVENAPI_API_KEY`), never the key value.

Do not copy the operator's existing `~/.kimi-code` directory to the new computer. Existing destination config is preserved by the installers.

## Windows installation

1. Extract the zip file.
2. Open PowerShell in the extracted `CustomKIMI-<version>` directory.
3. Run:

```powershell
.\scripts\install.ps1
```

The installer checks Node.js, prompts silently for `CLOSEROUTER_API_KEY` when it is missing, creates `%USERPROFILE%\.kimi-code\config.toml` only when absent, disables Kimi's auto-update, installs dependencies, builds the workspace, and links the local package globally.

4. Open a new terminal and verify:

```powershell
kimi --version
where.exe kimi
```

## macOS/Linux installation

1. Extract the archive.
2. Open Terminal in the extracted `CustomKIMI-<version>` directory.
3. Run:

```sh
sh ./scripts/install.sh
```

The installer does the same steps as on Windows, prompting for the key without echoing it.

4. Open a new terminal and verify:

```sh
kimi --version
command -v kimi
```

## API key setup

Two keys are needed: `CLOSEROUTER_API_KEY` for ClosedRouter and `SEVENAPI_API_KEY` for 7api. Optional: `OPENROUTER_API_KEY` for OpenRouter, plus `OPENROUTER_MANAGEMENT_KEY` for the OpenRouter footer balance. On macOS, keep the management key in the Keychain only: Kimi reads it from there and it must not be exported. For a one-terminal test:

```sh
export CLOSEROUTER_API_KEY="YOUR_CLOSEROUTER_KEY"
export SEVENAPI_API_KEY="YOUR_7API_KEY"
kimi
```

For persistent setup on macOS, store the keys in the Keychain and read them at launch. The operator's `~/.zshrc` uses this `kimi` function:

```sh
security add-generic-password -U -a "$USER" -s CLOSEROUTER_API_KEY -w   # prompts for the key
security add-generic-password -U -a "$USER" -s SEVENAPI_API_KEY -w      # prompts for the key
security add-generic-password -U -a "$USER" -s OPENROUTER_API_KEY -w    # optional
security add-generic-password -U -a "$USER" -s OPENROUTER_MANAGEMENT_KEY -w   # optional, footer balance
kimi() { KIMI_CODE_NO_AUTO_UPDATE=1 CLOSEROUTER_API_KEY="${CLOSEROUTER_API_KEY:-$(security find-generic-password -a "$USER" -s CLOSEROUTER_API_KEY -w 2>/dev/null)}" SEVENAPI_API_KEY="${SEVENAPI_API_KEY:-$(security find-generic-password -a "$USER" -s SEVENAPI_API_KEY -w 2>/dev/null)}" OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-$(security find-generic-password -a "$USER" -s OPENROUTER_API_KEY -w 2>/dev/null)}" command kimi "$@"; }
```

On Windows, use the user environment.

## Updating to a new Kimi Code release (macOS/Linux)

```sh
sh scripts/update.sh --check   # installed vs. latest
sh scripts/update.sh           # or: sh scripts/update.sh <version>
```

`update.sh` clones the official release tag `@moonshot-ai/kimi-code@<version>` into `source.next` and applies `custom/patches/*.patch` with `git am --3way`. The clone borrows the objects `source/` already has (`--reference-if-able source --dissociate`), so only what changed since the current build is downloaded, and the new clone keeps its own copy of everything. First it replays the patches, index only, on the release in `custom/BASE_VERSION`, which recreates the file versions they were saved against. With those, a patch whose surrounding lines changed upstream is merged, or stops with ordinary conflict markers. It then installs dependencies, typechecks the patched packages, runs the tests the patches touch, and builds. The tests run with `KIMI_CODE_HOME` set to a throwaway directory and no network beyond localhost: `NODE_USE_ENV_PROXY=1` plus `HTTP(S)_PROXY=http://127.0.0.1:9` and `NO_PROXY=localhost,127.0.0.1,::1`. Some upstream tests otherwise use the operator's real `~/.kimi-code` and live client configs from Kimi's servers, and then fail outside upstream's CI: the survey popup's model list breaks 9 rating-survey tests even on unpatched 2.3.1. Run tests by hand the same way (the command is in `custom/FEATURES.md`). Do not use `KIMI_CODE_BASE_URL` for this: it also changes the managed provider's OAuth token lookup, which breaks two node-sdk tests. Only if everything passes does it replace `source/` (keeping the old build as `source.previous`), re-link `kimi`, and refresh `custom/patches/` against the new release. The previous patch set is archived in `custom/history/`.

If the clone stalls at "Cloning into …", GitHub's server for this network is slow (on 2026-10-24 the DNS-selected one sent ~10 KB/s). Rerun through one of GitHub's own servers: `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.curloptResolve GIT_CONFIG_VALUE_0=github.com:443:140.82.121.4 sh scripts/update.sh`.

If a patch conflicts, the script stops without touching the active build. Then:

1. Resolve the conflicts in `source.next` so each feature still behaves as described in `custom/FEATURES.md`. Keep upstream's changes and re-add the feature on top of them.
2. Run `git add <files>`, then `git am --continue`. Use `git am --skip` only when upstream already provides the same behavior.
3. Run `sh scripts/update.sh --continue`.

If every patch applies but the typecheck or a test fails, fix it in `source.next` and fold the fix into that feature's commit, so that each feature stays one patch. Run `git commit --fixup=<commit>`, then `git rebase --autosquash "@moonshot-ai/kimi-code@<version>"`, then `sh scripts/update.sh --continue`.

The update refuses to start while `source/` or `source.previous/` has uncommitted edits or commits that `--save` has not stored. Commit them in that build, run `sh scripts/update.sh --save`, and start again. Never discard them.

What the 2.2.0 → 2.3.1 update needed (October 24, 2026), as a guide to the kind of work the next one may need:

- `0006` conflicted in `apps/kimi-code/src/tui/kimi-tui.ts`, `controllers/auth-flow.ts` and `test/tui/kimi-tui-startup.test.ts`. Upstream moved the lazy startup selection into `utils/model-switch.ts` `lazyModelSelection()`, which now uses `configuredModelDefaults()`. It also moved the TUI's model refresh into the engine, so `detail` is carried through the engine and klient schemas (`custom/FEATURES.md` §6). The startup tests now mock `harness.refreshProviderModels()`.
- `0011` conflicted in `configSection.ts`, `model.ts` and the generated `config-manifest.toml`: upstream added `upgrade` on the same lines as `extraBody`. Both are kept, and `gen:config-manifest` reproduces the merged manifest.
- `0003` failed the typecheck in `commands/session.ts`: `waitForLazyCreation()` was renamed `waitForSessionAssembly()`.
- `0007`'s `sessionBilling.test.ts` needed two new `IAppendLogStore` members in its stub, and an in-memory `ISessionLockService` plus `ISessionContext` for `WireService`.

To undo the last update, run `sh scripts/update.sh --rollback`.

## Changing features

Code changes go in `source/`, which every update replaces. After committing a change there, run `sh scripts/update.sh --save` to store it in `custom/patches`. Then describe it in `custom/FEATURES.md`. Updates refuse to start while `source/` holds unsaved changes. Provider and model changes are only `config.toml` edits and need no patch.

## Verification checklist

- `kimi --version` matches `custom/BASE_VERSION`.
- The model picker includes `closerouter/openai-gpt-6.1-sol` and `closerouter/glm-5.3`, each row showing a context window (for example `1M`).
- The footer shows `ClosedRouter balance` after startup when the API key is available.
- After a model request, the footer shows `session cost` when CloseRouter supplies usage cost.
- After the first start with the key available, the CloseRouter aliases in `~/.kimi-code/config.toml` carry `support_efforts` and CloseRouter's context limits, and no `Skipped refreshing closerouter` warning appears.
- With `OPENROUTER_API_KEY` stored, `kimi -m openrouter/muse-wonder` answers. With an OpenRouter model active, the footer shows `OpenRouter balance` (needs the management key) and, after a request, `session cost`.
- `/wipe-all-sessions` shows a warning without deleting anything.
- `/wipe-all-sessions confirm` deletes saved sessions through Kimi's session API and starts a fresh session.
- While a subagent runs (for example after asking Kimi to delegate a task), a row with a pulsing dot appears under the conversation; `↓` on the empty editor selects it, `Enter` shows the agent's conversation, `Esc` returns to the main chat.

## Important limitations

This is a source distribution, not a precompiled universal binary. Installers rebuild dependencies and native components on the destination OS. Do not run the Windows installer on macOS/Linux or the shell installer on Windows. `update.sh` is a POSIX shell script; on Windows, update by re-exporting from an updated Mac install or by following its steps manually.

The bundle excludes API keys, personal session history, local config files, logs, dependencies, build output, and Git metadata by design.
