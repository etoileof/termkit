# termkit

CustomKIMI is official Kimi Code with your own features added on top. The features are kept as patches outside Kimi's code, so every new Kimi release can be rebuilt with them using one command.

## Install on Windows

1. Download `termkit-<version>-windows-x64.zip` from the [latest release](../../releases/latest).
2. Extract it and double-click **`Install.cmd`**.
3. Paste your CloseRouter key and your 7api key when asked. Press Enter on an empty line to skip either one.
4. Open a new terminal, go to your project and type `kimi`.

No admin rights or Node.js are needed: the zip contains a standalone `kimi.exe` (Kimi Code's native build with the patches below). The installer puts it in `%LOCALAPPDATA%\Programs\termkit`, adds that to your PATH, saves the keys as the user environment variables `CLOSEROUTER_API_KEY` and `SEVENAPI_API_KEY`, creates `%USERPROFILE%\.kimi-code\config.toml` from `config/config.toml.example` (an existing one is kept), and turns off Kimi's auto-update. With only a 7api key, the default model becomes `7api/gpt-6-astra` and the CloseRouter model refresh is switched off so it doesn't warn on every start; adding a CloseRouter key later switches it back on. Run the installer again to change keys (Enter keeps a saved key, `-` removes it). Uninstall with `Uninstall.cmd` or from Settings > Apps > Installed apps. The installer does not ask for an OpenRouter key yet; set `OPENROUTER_API_KEY` as a user environment variable to use the OpenRouter models.

The zip is built by GitHub Actions (`.github/workflows/windows-release.yml`) on a Windows runner: it clones the Kimi Code release in `custom/BASE_VERSION`, applies `custom/patches`, builds `kimi.exe`, runs its smoke test and an end-to-end installer test, and publishes the release. It runs on every push to `main` that changes the patches, the base version, the config template or `windows/`, and on demand from the Actions tab.

## Layout

| Path | What it is |
|---|---|
| `custom/` | **Your features.** One patch per feature in `custom/patches/`, explained in `custom/FEATURES.md`. Updates never overwrite this folder. |
| `config/config.toml.example` | ClosedRouter provider and model template. Your live copy is `~/.kimi-code/config.toml`. |
| `docs/` | Reference notes: the CloseRouter API (`closerouter-api.md`) and the 7api model list (`models.yml`, key removed in this repository). They are not part of exported bundles or the Windows zip. |
| `windows/` | The Windows installer that goes into the release zip. |
| `scripts/update.sh` | Updates to a new Kimi release and re-applies your features. |
| `scripts/install.sh`, `install.ps1` | Install from an exported bundle on another Mac or Windows PC. |
| `scripts/export.sh`, `export.ps1` | Create a shareable bundle. |
| `source/` | The active build: official release plus your patches. `kimi` runs from here. |
| `source.previous/` | The build before the last update, kept for rollback. |

## Features

- **ClosedRouter provider:** OpenAI-compatible (`https://api.closerouter.dev/v1`) and Anthropic-compatible (`https://api.closerouter.dev`) providers with these models:
  - `closerouter/openai-gpt-6-astra` (default)
  - `closerouter/openai-gpt-6.1-sol`
  - `closerouter/deepseek-v4-pro-0813`
  - `closerouter/glm-5.3`
  - `closerouter/glm-5.3-flash`
  - `closerouter/gemini-4-argon`
  - `closerouter/grok-4.7`
  - `closerouter-anthropic/claude-fable-5.1`
  - `closerouter-anthropic/claude-fable-5`
  - `closerouter-anthropic/claude-opus-4.8`
  - `closerouter-anthropic/claude-opus-4.6`

  The providers and aliases are plain Kimi configuration, not a patch.
- **CloseRouter limits and efforts:** every start (and every 6 hours while `kimi web` runs) asks CloseRouter for each configured CloseRouter model's context limit, output limit and the reasoning efforts of the endpoint it is called through (Chat, Responses or Messages), and updates those aliases. The model picker then offers only those efforts, and "off" only where the endpoint can actually turn reasoning off. To keep a value of your own, such as a lower output cap, put it under `[models."<alias>".overrides]`; overrides are never rewritten. If CloseRouter cannot be reached, the previous values stay and Kimi shows a warning. If `[secondary_model] default_effort` does not fit a model's new efforts (for example `"off"` for a model that always reasons), that model keeps its previous efforts and the warning names the setting to change.
- **7api provider:** `https://7api.st` with 35 models named `7api/<model>`:
  - GPT models use the Responses API.
  - Claude models use the Anthropic API with adaptive thinking.
  - Gemini, DeepSeek, MiMo, Kimi K3, Grok and GLM use Chat Completions.

  Effort levels and limits come from `docs/models.yml`. This is also plain configuration. Thinking is off by default. For models with effort levels, "off" is sent as `off_effort = "none"`, which 7api accepts. Kimi K3 and the GLM 5.3 models cannot stop thinking, so they use their lowest level instead.
- **OpenRouter provider:** `https://openrouter.ai/api/v1` (Chat Completions, key from `OPENROUTER_API_KEY`) with `openrouter/muse-wonder` (Meta Muse Wonder), `openrouter/kimi-k3.1-pro` (Moonshot Kimi K3.1 Pro: 1M context, efforts low/high/max, $2 / $10 per million tokens, image input) and `openrouter/qwen3.8-27b` (Qwen 3.8 27B, run only on Cerebras: 65,536 context, 32,768 output, $0.99 / $1.49 per million tokens). Add more OpenRouter models with one `[models."openrouter/<name>"]` entry each; this is plain configuration.
- **Per-model request fields (`extra_body`):** a model alias can add its own fields to every OpenAI-style request, for options Kimi has no setting for. `openrouter/qwen3.8-27b` uses it to run only on Cerebras (`provider.only = ["cerebras/fp16"]`, `allow_fallbacks = false`), so OpenRouter never sends it to another host. Kimi's own fields win on a conflict.
- **OpenRouter limits and efforts:** like CloseRouter's, refreshed at every start (and every 6 hours while `kimi web` runs), from OpenRouter's public model list. No key is sent. Overrides are never rewritten.
- **OpenRouter balance and session cost:** the footer shows `OpenRouter balance $X  session cost $Y` while an OpenRouter model is active. The balance is your account balance from `/credits`, which needs an OpenRouter **management key**. Kimi reads that key straight from the Keychain (`OPENROUTER_MANAGEMENT_KEY`) and never exports it into its environment. Without a management key, the footer falls back to the API key's remaining credit limit, else shows nothing. The cost comes from the `usage.cost` OpenRouter returns with every reply.
- **Live balance:** the footer shows your ClosedRouter balance from `GET /v1/credits`, refreshed every 60 seconds while `CLOSEROUTER_API_KEY` is set. A failed request shows nothing rather than `$0`. Set `CLOSEROUTER_BALANCE_URL` only for a compatible proxy.
- **Session cost:** the footer shows the current session's cost from the `usage.cost` that CloseRouter returns with each response, including every subagent (foreground, background and nested, also after resuming the session). If a cost is missing, an estimate is shown only when all four `CLOSEROUTER_INPUT/OUTPUT/CACHE_READ/CACHE_WRITE_USD_PER_MILLION` rates are set; otherwise no cost is shown rather than a partial one. Requests that fail or are cancelled before CloseRouter reports their cost are not included. Do not enter guessed rates.
- **Web UI balance:** `kimi web` and `/web` show the balance of the active model's provider next to the model picker under the message box. Session cost is shown in the CLI only.
- **Context window in `/model`:** each model in the picker shows its context window (`1M`, `200k`, `64k`) next to its name, overrides included. The footer's context readout uses the same round numbers, so a 1M model reads `1M` in both places.
- **`/wipe-all-sessions confirm`:** deletes saved sessions in all workspaces, keeping config, credentials, plugins and logs. Without `confirm`, it only warns.
- **HTTP 524 retries:** when a provider's gateway times out (HTTP 524), Kimi retries the failed step up to 10 times, waiting longer each time, instead of failing the turn and pausing a running `/goal`. Each retry shows a line such as `System notice: Model request failed (HTTP 524). Retrying attempt 2/10 in 1s.` in the terminal and the web chat. If every attempt fails, the turn fails as before.
- **Agent dock:** every subagent of the session is listed as a row under the conversation with a status dot (pulsing while it runs, green when done, red when failed), its model, effort, tool count, elapsed time and the tool it is on. `↓` on an empty editor moves into the dock, `↑`/`↓` select a row, `Enter` shows that agent's live conversation in place of the main chat, `Esc` comes back. Finished agents linger 8 seconds. The upstream inline agent card and `/tasks` are unchanged.

The details for each patch are in `custom/FEATURES.md`.

## Daily use

Type `kimi`. On this Mac `kimi` is `scripts/kimi-launcher.sh` installed over the npm link at `/opt/homebrew/bin/kimi`; it reads the three keys from the Keychain for every launch context (also `/web` and scripts) and `update.sh` puts it back after each update. On other machines, the shortcut in `~/.zshrc` reads `CLOSEROUTER_API_KEY`, `SEVENAPI_API_KEY` and `OPENROUTER_API_KEY` from the macOS Keychain at launch. It also turns off Kimi's own auto-updater, which would replace this build with the plain official release.

To store or replace a key, run the matching line in a normal Terminal window. It prompts for the key without showing it:

```sh
security add-generic-password -U -a "$USER" -s CLOSEROUTER_API_KEY -w
security add-generic-password -U -a "$USER" -s SEVENAPI_API_KEY -w
security add-generic-password -U -a "$USER" -s OPENROUTER_API_KEY -w
security add-generic-password -U -a "$USER" -s OPENROUTER_MANAGEMENT_KEY -w   # optional, for the footer balance
```

## When a new Kimi version comes out

Close your `kimi` windows, then:

```sh
cd ~/Desktop/CustomKIMI
sh scripts/update.sh --check     # what you have vs. what's out
sh scripts/update.sh             # update to the latest release
```

That's usually all. The script downloads the official release into `source.next` and puts your features (`custom/patches`) back on top. Only what changed since your current build is downloaded; the rest is copied from `source/`. It then installs, typechecks, runs your features' tests, and builds. The tests run against a throwaway Kimi home, so they never touch your `~/.kimi-code`. Only when all of that passes does `kimi` switch to the new build, and the old one stays in `source.previous`. Open `kimi` again and you're on the new version.

If something goes wrong along the way, your current `kimi` keeps working exactly as before. Here's what you might run into:

- **"a custom patch no longer applies cleanly"**: Kimi changed code that one of your features also changes. The script names the patch and the files.
  - Easiest: open an AI agent in this folder and say *"Resolve the git am conflict in source.next using custom/FEATURES.md, then finish the update."*
  - By hand: fix the listed files in `source.next`, `git add` them, run `git am --continue`, then run `sh scripts/update.sh --continue`.
- **A typecheck or test fails after all patches applied**: Kimi renamed or changed something a feature relies on. Have the agent fix it in `source.next` and fold the fix into that feature's commit, so each feature stays one patch. The commands are in `custom/FEATURES.md`. Then run `sh scripts/update.sh --continue`.
- **"… has changes that are not saved in custom/patches"**: you changed something in `source/` and haven't saved it as a patch yet. Commit it there, run `sh scripts/update.sh --save`, then update again. This check is what keeps your own changes from being lost.
- **It sits at "Cloning into …" for minutes**: GitHub can be very slow from some networks. On October 24, 2026, the GitHub server this Mac's DNS picked sent about 10 KB/s, while GitHub's own `140.82.x.x` servers were fast. Stop it with Ctrl-C and run the update through one of those (TLS still checks that it is github.com):

  ```sh
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.curloptResolve GIT_CONFIG_VALUE_0=github.com:443:140.82.121.4 sh scripts/update.sh
  ```

Other handy commands:

- `sh scripts/update.sh --rollback` goes back to the previous build. Run it again to go forward.
- `sh scripts/update.sh 2.2.0` builds a specific release, for example to rebuild the current one from scratch.

**New Windows build:** after an update (or `--save`) changed `custom/`, commit and push it to this repository and the Windows release is rebuilt. A clone of this repository also works as the CustomKIMI folder itself: `source/` and the other build folders are git-ignored, and `sh scripts/update.sh <version>` creates them.

**Last update (2.2.0 → 2.3.1, October 24, 2026):** it stopped at `0006`, as predicted (Kimi moved its startup model refresh into the engine), and at `0011` (Kimi added a model setting on the same line as `extra_body`). After that, `0003` needed a renamed Kimi function, and `0007`'s tests needed Kimi's new session lock. Each fix is folded into its feature's patch, and `custom/FEATURES.md` describes the current state. On the same day the agent dock (`0013`, written on 2.2.0 in the separate `kiminew` build) was merged onto this 2.3.1 build with `git am --3way` without conflicts, so one `kimi` now carries all thirteen features.

Never run `npm install -g @moonshot-ai/kimi-code` or accept Kimi's built-in upgrade: both swap your build for the plain official one. If that happens anyway, run `cd source/apps/kimi-code && npm link --ignore-scripts` from this folder to bring yours back.

## Adding or changing features

**A provider or model** is only configuration. Edit `~/.kimi-code/config.toml`, then copy it to `config/config.toml.example` so the bundle has it too. Keep keys in the Keychain and reference them with `api_key_env`, never in the file.

**A code feature** lives in `source/`, which every update replaces. Only `custom/patches` survives an update, so save each change:

1. Change the code in `source/`, or ask an AI agent opened in this folder to do it.
2. Try it out: `cd source && corepack pnpm run build:packages && corepack pnpm --filter @moonshot-ai/kimi-code run build`, then run `kimi`.
3. Commit it in `source/`: `git add -A && git commit -m "<what changed>"`.
4. From this folder, run `sh scripts/update.sh --save`. It writes `custom/patches` and backs up the previous set in `custom/history/`.
5. Describe the feature in `custom/FEATURES.md`.

If you skip step 4, the next update stops and tells you, so the change can't be lost.

## If you move this folder

`kimi` points into `source/`, so moving the folder breaks the command (`command not found: kimi`). Re-link it from the new location:

```sh
cd /new/path/CustomKIMI/source/apps/kimi-code && npm link --ignore-scripts
```

## Install on another PC

Requirements: Node.js 24.15 or newer (with Corepack), Git, and a CloseRouter API key.

1. Run `sh scripts/export.sh` (macOS) or `.\scripts\export.ps1` (Windows). It creates `dist/CustomKIMI-<version>.tar.gz` (or `.zip`). The bundle leaves out dependencies, build output, `.git`, logs, `.env` files and config files. It refuses to export if it finds an API key in any file.
2. On the other PC, extract it and run `sh ./scripts/install.sh` (macOS) or `.\scripts\install.ps1` (Windows). The installer creates `~/.kimi-code/config.toml` from the template only if none exists, turns off Kimi's auto-update, builds, and links `kimi`.
3. Open a new terminal and run `kimi --version`.

Do not copy Kimi session history, logs or credentials between computers.

## Security

Keep API keys (`CLOSEROUTER_API_KEY`, `SEVENAPI_API_KEY`, `OPENROUTER_API_KEY`, `OPENROUTER_MANAGEMENT_KEY`) in the Keychain or the operating system environment only. Never put them in `config.toml`, the template, this folder, or a bundle. `api_key_env` must be the variable's **name**, never the key itself.
