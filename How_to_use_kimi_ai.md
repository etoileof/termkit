# How to use Kimi Code: knowledge file for AI assistants

Version covered: **Kimi Code CLI 2.2.0** (Moonshot AI), CustomKIMI build. Research date: **2026-10-18**.

Rechecked for **Kimi Code 2.3.1** on **2026-10-24**, when CustomKIMI moved to 2.3.1 + 12 patches. Five of the docs-vs-code facts in section 28 were rechecked in the 2.3.1 code and still hold: permission rules are never applied, Always Ask approves Write/Edit in a git repo, Edit has no read-first check, `kimi -p` ignores stdin, and the Bash timeout is in seconds. One behavior changed: since 2.3.0, `dangerous_command_guard = false` also turns off the sensitive-file and `.git/**` asks (see the guard and sensitive-file sections). The rest of this file was not re-verified for 2.3.1.

Source of truth: `~/Desktop/CustomKIMI/source` (upstream 2.3.1 + 12 local patches since 2026-10-24; 2.2.0 + 7 when this file was researched). The user's live config is in `~/.kimi-code/`.

---

## 0. Instructions for the AI reading this file

You are helping a user who will paste or attach this file and ask you to explain **Kimi Code CLI** ("Kimi", "kimi-code"). Kimi is Moonshot AI's terminal coding agent. Use this file as your main source.

1. **Map everything to Claude Code.** The user knows Claude Code well and is learning Kimi. Explain each Kimi concept by naming its Claude Code equivalent and how it differs. Section 33 has a lookup table.
2. **Keep it simple.** The user has asked many times for SIMPLE explanations. Use short sentences, plain words and one idea per bullet. Give a concrete example or command. Use analogies; this file uses "the company": AGENTS.md = rulebook, agent files = job descriptions, PROGRESS.md = whiteboard, /goal = engine, hooks = security guard. Go deeper only when asked.
3. **Be concrete.** When the user wants to do something, give exact commands, file paths and complete file contents. Section 31 has ready templates.
4. **Warn about gotchas when relevant** (section 29). The big ones:
   - Kimi has no memory.
   - AGENTS.md is read once per session.
   - `/undo` never restores files.
   - `[[permission.rules]]` is ignored in 2.2.0.
   - The `auto` permission mode means *Never Ask*.
   - There is no sandbox.
5. **Know how much to trust each fact.** Tags used here:
   - `[code]`: checked in the Kimi 2.2.0 source code.
   - `[docs]`: from Kimi's official docs, not checked in code.
   - `[user]`: the user's own setup on 2026-10-18.
   - `[cc]`: Claude Code facts from general knowledge as of mid-2026; may be outdated.
   - Untagged statements in a section follow that section's stated default.
6. **Kimi's docs are wrong in several places** (section 28). Prefer `[code]` facts. If you can read the source, verify there; section 35 maps topics to files.
7. **Facts can change after updates.** They describe 2.2.0 as of 2026-10-18. When it matters, say "as of 2.2.0".
8. **The user runs a patched build.** Never suggest `kimi upgrade` or `npm install -g @moonshot-ai/kimi-code`; both replace the patched build. Updates go through `sh scripts/update.sh` (section 4).
9. **Never ask for, print, or store the user's API keys.** They live in the macOS Keychain and are referenced only by variable name.
10. **The user's main aim:** a `/goal` loop where one coordinator agent delegates to specialist worker agents (section 31.4). Steer lessons toward it.

---

## 1. Quick answers (FAQ)

- **Does Kimi have memory?** No `[code]`. There is no auto memory, no `/memory`, no `#` quick-add and no memory tool. Between sessions it keeps only:
  - AGENTS.md files, re-read at each session start.
  - The session itself, if resumed with `kimi -c` or `/sessions`.
  - Files it is told to read, such as `PROGRESS.md`.
- **What replaces CLAUDE.md?** `AGENTS.md` `[code]`. Kimi never reads `CLAUDE.md`. To share one file between both tools: `git mv CLAUDE.md AGENTS.md && ln -s AGENTS.md CLAUDE.md`.
- **Is AGENTS.md per project?** It has three levels `[code]`:
  - `~/.kimi-code/AGENTS.md`: all projects.
  - `<repo>/AGENTS.md`: that project.
  - `<repo>/sub/folder/AGENTS.md`: that folder. The agent is told the file exists when it touches the folder, then must read it itself.
- **I edited AGENTS.md; why doesn't Kimi follow it?** It's read once per session. Run `/new` or restart; `/reload` is not enough `[code]`.
- **Are there built-in helper agents?** Yes `[code]`:
  - `coder`: the default; reads, edits, runs commands.
  - `explore`: reads and searches.
  - `plan`: reads only, no shell.
- **How do I make my own agents?** Create `.kimi-code/agents/` (project) or `~/.kimi-code/agents/` (all projects). Add one Markdown file per agent with frontmatter (`name`, `description`, `tools`…). The body is the agent's whole system prompt. Put `${base_prompt}` in it so the agent also gets Kimi's normal instructions and AGENTS.md. Restart Kimi afterwards. See section 13.
- **Does a custom agent get its prompt automatically?** Yes. When called, Kimi renders the file body as its system prompt (`${base_prompt}` etc. filled in) and sends the caller's task as its first message `[code]`.
- **Can the coordinator reuse a worker's previous context?** Yes `[code]`:
  - `Agent(resume="<agent_id>", prompt=…)` continues the same worker with all its prior context, even after a restart.
  - A new `Agent(subagent_type="builder", prompt=…)` starts fresh.
  - `fork: true` (experimental) clones the caller itself, not a worker.
- **How do I make Kimi loop until something is done?** `/goal <finish line + stop rule>` `[code]`. See section 15.
- **How do I save context?**
  - Delegate to subagents; only their final report comes back.
  - Start a new session per task with `/new`.
  - Use `/compact <what to keep>`.
  - Keep state in `PROGRESS.md`.
- **Which permission mode should I use?** Daily: **Ask When Needed** (`yolo`) with the guard on and the guard hook. **Never Ask** (`auto`) only on purpose, on a branch or worktree. See section 11.
- **How do I undo code changes?** With git. `/undo` and `Esc Esc` only rewind the conversation `[code]`.
- **How do I make rules that can't be broken?** With a `PreToolUse` hook (exit code 2 blocks) and `[tools] disabled`. Both work in every mode `[code]`. AGENTS.md is only soft guidance.
- **Can I reuse my Claude Code setup?** See section 33.3. In short:
  - Skills: point `extra_skill_dirs` at them or copy them.
  - Agents: `extra_agent_dirs`.
  - Project `.mcp.json`: read natively.
  - Hooks, commands and Claude plugins: need conversion.
  - `/import-from-cc-codex` imports instructions, skills and MCP settings.
- **Does web search work?** Not for this user `[user]`. `WebSearch` only exists after `/login` to a Kimi account, or with `[services.moonshot_search]` configured `[code]`. `FetchURL` works without login.
- **How do I run Kimi from a script?** `kimi -p "task" --output-format stream-json`. It always runs in Never Ask mode and ignores stdin `[code]`. See section 24.
- **Claude Code or Kimi, which is better?** It depends on the task; see section 33.2.

---

## 2. Glossary (Kimi term → meaning → Claude Code term)

| Kimi | Meaning | Claude Code |
|---|---|---|
| `AGENTS.md` | Instruction file injected into the system prompt | `CLAUDE.md` |
| Always Ask (`manual`) | Default permission mode | default / acceptEdits (in a git repo) |
| Ask When Needed (`yolo`) | Auto-approves almost everything, asks for a few risky things | auto mode (but rule-based, no classifier) |
| Never Ask (`auto`) | Approves everything and never asks the user | bypassPermissions |
| Plan mode | Read-mostly planning state, toggled with Shift-Tab | plan mode |
| Subagent | Helper agent with its own context | subagent (Task/Agent tool) |
| `coder` / `explore` / `plan` | Built-in subagent types | general-purpose / Explore / Plan |
| Agent file | Markdown file defining a custom agent | `.claude/agents/*.md` |
| Skill | `SKILL.md` recipe, invoked by `/skill:name` or by the model | skill |
| Goal mode (`/goal`) | Loop that continues turns until a finish line | loops via `/loop`, plugins such as ralph-loop |
| Swarm / `AgentSwarm` | One prompt template run as many subagents | parallel subagents |
| Tower | Experimental coordinator + workers in git worktrees | (scripted workflows are the nearest idea) |
| Steering (`Ctrl-S`) | Inject a message into the running turn | typing while Claude works |
| `[secondary_model]` | Model pool for subagents | `model:` in agent files |
| `SYSTEM.md` | Replaces or wraps the main system prompt | output styles / `--system-prompt` |
| Wire (`wire.jsonl`) | Per-agent session event log | session JSONL transcripts |
| Workspace trust | Per-folder trust that gates project MCP servers | folder trust dialog |
| ACP | Agent Client Protocol for editors (`kimi acp`) | IDE integrations |

---

## 3. Mental model

- **Same as Claude Code:**
  - An agent loop with near-identical tools: `Read`, `Write`, `Edit`, `Grep`, `Glob`, `Bash`, `Agent`, `Skill`, `AskUserQuestion`, `EnterPlanMode`, `ExitPlanMode`, `TaskOutput`, `TaskStop`, `CronCreate`.
  - The same ideas: skills, subagents, hooks, MCP, plugins, plan mode, sessions, compaction, background tasks.
- **Different:**
  - Instructions live in AGENTS.md (an open cross-tool convention), with lower authority. Kimi's system prompt calls them "project-supplied reference data" that cannot override the system prompt or the user.
  - No memory.
  - One user-level TOML config.
  - Any LLM provider.
  - Permission-mode names differ, and the safety tooling is weaker: config rules are ignored in 2.2.0, there is no sandbox, and undo doesn't restore files.
  - More autonomy built in: `/goal`, `/swarm`, `Ctrl-S` steering, cron, web UI, remote control.
- **The company analogy:**
  - AGENTS.md = rulebook everyone reads.
  - Agent file = one worker's job description.
  - `PROGRESS.md` = shared whiteboard (memory).
  - Skills = recipes.
  - `/goal` = engine.
  - Hooks = security guard (hard rules).
  - Permission mode = how often the boss (the user) is asked.
- **Soft vs hard rules:** AGENTS.md and skills are soft; the model can drift from them. Hooks and `[tools] disabled` are hard; they are enforced by code.

---

## 4. The CustomKIMI build `[user]`

### Layout

The build lives in `~/Desktop/CustomKIMI`.

- `source/`: the active build (official release plus patches). The global `kimi` command is npm-linked to `source/apps/kimi-code` (`@moonshot-ai/kimi-code@2.3.1` since 2026-10-24).
- `source.previous/`: the previous build, kept for rollback.
- `custom/patches/`: 7 patches.
- `custom/FEATURES.md`: describes each patch.
- `custom/BASE_VERSION`: `2.3.1` (since 2026-10-24).
- `custom/history/`: older patch sets.
- `config/config.toml.example`: the provider and model template.
- `docs/closerouter-api.md`, `docs/models.yml`: local reference notes.
- `scripts/`: `update.sh`, `install.sh`/`install.ps1`, `export.sh`/`export.ps1`.

### Patches

There are 12 patches since 2026-10-23: the 7 below plus 8. OpenRouter balance and session cost (the management key is read from the Keychain, never exported), 9. OpenRouter limits and efforts refreshed at startup from the public model list, and 10. HTTP 524 gateway timeouts retried like 429/5xx (up to `max_attempts_per_step`, 10 by default, with backoff) instead of failing the turn and pausing a goal; each retry shows `System notice: Model request failed (HTTP 524). Retrying attempt n/10 …` `[code]`, 11. a per-model `extra_body` table whose fields are added at the top level of OpenAI Chat/Responses requests, with Kimi's own fields winning on conflict `[code]`, and 12. the `/model` picker shows each model's effective context window (`1M`, `200k`, `64k`), and the footer's context readout uses the same round numbers (decimal when exact, else binary: 1,000,000 → `1M`, 262,144 → `256k`) `[code]`. The OpenRouter provider (`openrouter`, aliases `openrouter/muse-wonder` and `openrouter/qwen3.8-27b`, the latter pinned to Cerebras through `extra_body.provider`) is configuration.


1. Keep the provider-reported `usage.cost`.
2. Provider balance and session cost in the footer.
3. `/wipe-all-sessions confirm`.
4. node-pty permission fix.
5. Provider balance in the web UI.
6. Refresh CloseRouter context/output limits and reasoning efforts at startup. Pin your own values under `[models."<alias>".overrides]`.
7. Session cost includes every subagent.

### Launch

A zsh function `kimi` in `~/.zshrc` sets `KIMI_CODE_NO_AUTO_UPDATE=1`. It also exports `CLOSEROUTER_API_KEY`, `SEVENAPI_API_KEY` and `OPENROUTER_API_KEY`, read from the Keychain with `security find-generic-password`. `OPENROUTER_MANAGEMENT_KEY` is deliberately not exported; the billing code reads it from the Keychain itself. Consequence: every Bash command the agent runs inherits these keys `[code]`.

### Providers

| Provider | Type | Base URL |
|---|---|---|
| `closerouter` | openai | `https://api.closerouter.dev/v1` |
| `closerouter-anthropic` | anthropic | `https://api.closerouter.dev` |
| `7api` | openai | `https://7api.st/v1` |
| `7api-responses` | openai_responses | `https://7api.st/v1` |
| `7api-anthropic` | anthropic | `https://7api.st` |

There are 48 model aliases in total. `openrouter/muse-wonder` was added on 2026-10-22 and `openrouter/qwen3.8-27b` on 2026-10-23; Qwen is pinned to Cerebras through `extra_body.provider` and limited to 65,536 context and 32,768 output by `overrides`. `closerouter-anthropic/claude-fable-5.1` and `closerouter-anthropic/claude-fable-5` were added on 2026-10-22 (7api offers only Fable 5, as `7api/claude-fable-5`). Fable always thinks; Kimi's built-in Anthropic profile knows this, so "off" is never sent. `closerouter/gemini-4-argon` and `closerouter/grok-4.7` were added on 2026-10-22. CloseRouter publishes no context length for Argon, so its 128k is a placeholder taken from 7api. Each startup refresh warns about this but leaves the value alone.

### Updating

- `sh scripts/update.sh --check` shows what's new; `sh scripts/update.sh [version]` updates.
- `--continue` resumes after resolving a patch conflict. `--rollback` goes back to the previous build. `--save` saves commits made in `source/` as patches.
- **Never** run `kimi upgrade` or `npm install -g @moonshot-ai/kimi-code`. If it happens, restore with `cd ~/Desktop/CustomKIMI/source/apps/kimi-code && npm link --ignore-scripts`. Run the same command after moving the folder.
- Requires Node.js ≥ 24.15.

---

## 5. Where files live `[code]`

```
~/.kimi-code/            (KIMI_CODE_HOME; default ~/.kimi-code)
  config.toml            runtime config (providers, models, permission, hooks, thinking, pools…)
  tui.toml               UI prefs (theme, editor, notifications, status line, auto-update, mermaid)
  AGENTS.md              global instructions (Kimi-specific)
  SYSTEM.md              replaces/wraps the main agent's system prompt
  mcp.json               user MCP servers
  skills/                user skills
  agents/                user agents
  themes/<name>.json     custom themes
  plugins/installed.json + plugins/managed/<id>/
  credentials/           OAuth tokens (Kimi login, MCP OAuth in credentials/mcp/)
  sessions/<workDirKey>/<sessionId>/  state.json, agents/<id>/wire.jsonl, agents/<id>/plans/, tasks/, cron/, upcoming-goals.json
  session_index.jsonl, workspaces.json, workspace-trust/
  file-history/          pre-edit copies for Write/Edit (only used by web/desktop diff views)
  logs/kimi-code.log, user-history/<md5(cwd)>.jsonl, bin/rg, bin/fd, server.token, updates/

~/.agents/               cross-tool convention, always in the real OS home
  AGENTS.md, skills/, agents/

<repo>/                  project root = nearest ancestor containing .git
  AGENTS.md (or agents.md)
  .mcp.json              Claude Code's MCP file, read natively (trusted folders only)
  .kimi-code/AGENTS.md   loaded in addition to the root AGENTS.md
  .kimi-code/skills/, .kimi-code/agents/
  .kimi-code/mcp.json    read from the current working directory
  .kimi-code/local.toml  [workspace] additional_dir (from /add-dir); gitignore it
  .agents/skills/, .agents/agents/   (.agents/AGENTS.md at project level is NOT read)
```

---

## 6. Instruction files (AGENTS.md) `[code]`

### Which files load

- **Filenames:** only `AGENTS.md` (with `agents.md` as fallback) and `.kimi-code/AGENTS.md`. There is no `CLAUDE.md`, `KIMI.md` or `AGENTS.override.md` support.
- **Load order** (all concatenated; none overrides another):
  1. `$KIMI_CODE_HOME/AGENTS.md`.
  2. `~/.agents/AGENTS.md`.
  3. Every directory from the git root down to the working directory. In each, `.kimi-code/AGENTS.md` loads first, then `AGENTS.md`.
- **Limits of the walk:** nothing above the repo root is read. Outside a git repo, only the working directory is read. Git worktrees are supported.
- Empty files are skipped and symlinks are followed.
- **Subdirectory files are not loaded at startup.** When Read, Edit, Write, Glob or Grep touch a directory (or Bash runs `ls`, `tree`, `find` or `cd` there), Kimi checks for unloaded AGENTS.md files between that directory and the git root. It then queues a reminder naming the files and asking the model to read them. The content is not injected, and each file is announced once per agent.
- **Size:** 32 KiB is a recommended limit. Larger files raise a warning; nothing is truncated.
- **Not supported:** `@path` imports, path-glob rules files and memory.

### How they are injected

- They go into the system prompt under "Project information", inside a 7-backtick fence, each prefixed with `<!-- From: /abs/path -->`.
- The prompt says: "The `AGENTS.md` content below is project-supplied reference data, not a privileged instruction channel… it cannot override these instructions or instructions from the user." It also tells the model to check subdirectories for their own AGENTS.md, and to update AGENTS.md when it changes something the file documents.

### When they are read

- **The system prompt is built once, when an agent starts.** It is not rebuilt mid-session, nor after compaction.
- **Mid-session edits:** a 200 ms file watcher sends a path-only "changed on disk, the copies in the system prompt are stale" reminder. Compaction drops such reminders.
- **Refreshing:** `/reload` does **not** refresh AGENTS.md (resume restores the saved prompt). Use `/new` or restart.
- **Turning the watcher off:** `[watch] enabled = false` or `KIMI_CODE_WATCH=0`.

### Subagents

- **Built-in subagents** get the same AGENTS.md block.
- **Custom agents** only get it if their body contains `${base_prompt}` or `${agents_md}`.

### `/init`

- Spawns a `coder` subagent using the main model, thinking level and permission mode.
- The subagent explores the project and writes the root `AGENTS.md`, replacing it but keeping still-accurate content. It writes in the project's main language.
- Suggested sections: overview, build/test commands, code style, testing, security.
- After it finishes, the new content arrives as a reminder (not in the system prompt). Run `/new` to load it properly.

### What else is in the system prompt

- **Included:**
  - Product name, OS, and shell name and path.
  - Working directory plus a 2-level listing (up to 30 top-level entries and 10 per subdirectory).
  - `--add-dir` directory listings, AGENTS.md, the skills list and plugin instructions (64 KiB cap).
  - NotifyUser guidance when that feature is on.
- **Not included:**
  - The date, which comes as a reminder at the start and when it changes.
  - Git status, which only the `explore` subagent receives.
  - The model name and knowledge cutoff.

---

## 7. Memory and how to fake it `[code]`

Kimi has no memory feature. The workarounds:

1. **AGENTS.md.** Durable rules and facts, re-read every session. Ask the agent to "add this to AGENTS.md" where you'd press `#` in Claude Code.
2. **Resume.** `kimi -c` (last session in this folder), `kimi -S [id]` or `/sessions`. Name sessions with `/title`.
3. **A progress file.** Tell the agent (in AGENTS.md) to read `PROGRESS.md` at the start and update it after every step. This is the real memory for long loops: it survives compaction and new sessions.
4. **A decision log.** Optionally, `DECISIONS.md` for why choices were made.
5. **VS Code extension only:** `/import <file|session_id>` adds a file or another session as one-time context `[code]`.

---

## 8. System prompt customization `[code]`

- **No flags:** there is no `--system-prompt`, `--append-system-prompt` or output styles.
- **`$KIMI_CODE_HOME/SYSTEM.md`** replaces the main agent's system prompt in all modes. Its tools, description and subagent list are inherited.
  - Use `${base_prompt}` inside it to wrap the built-in prompt instead of replacing it.
  - A SYSTEM.md (or agent file) containing neither `${base_prompt}` nor `${agents_md}` **silently drops all AGENTS.md content**.
- **Template variables** for agent files and SYSTEM.md:
  - `${base_prompt}`, `${agents_md}`, `${cwd}`, `${cwd_listing}`, `${os}`, `${shell}`.
  - `${skills}` (empty unless the agent has the `Skill` tool), `${skills_section}`, `${plugin_sections}`.
  - `${additional_dirs_info}`, `${additional_dirs_section}`, `${windows_notes}`, `${product_name}`.
  - Unknown variables stay verbatim. A bare `$` is not special.
  - `${now}` is documented but no longer exists; it renders literally.
- **`[identity] name` / `slug`** (or `KIMI_CODE_IDENTITY_NAME` / `KIMI_CODE_IDENTITY_SLUG`) change the name the agent uses for itself, the User-Agent token and the MCP client name. Takes effect for new sessions.

---

## 9. Configuration reference

### Validation and reloading `[code]`

- Each config section is validated as a whole. **One invalid value makes the entire section be ignored, with only a warning.** One bad `[[hooks]]` entry disables all hooks.
- Run `kimi doctor` (or `kimi doctor config` / `kimi doctor tui [path]`) after edits. It validates without modifying anything; exit code 0 means valid, 1 means invalid.
- `/reload` re-reads `config.toml` and `tui.toml`; `/reload-tui` re-reads only `tui.toml`.

### `config.toml` top level

- `default_model`.
- `default_permission_mode`: `manual` (default), `yolo` or `auto` `[code]`. Applies to new sessions only.
- `default_plan_mode`, `merge_all_available_skills`, `extra_skill_dirs`, `extra_agent_dirs`.
- `builtin_product_skills`: turns off the built-in skills that document Kimi itself.
- `telemetry`, `auto_session_title`.

### `[providers.<name>]`

- `type`: `kimi`, `anthropic`, `openai`, `openai_responses`, `google-genai` or `vertexai`.
- **Credentials: set exactly one** of `api_key`, `api_key_env` or `oauth`.
  - `api_key_env` names a shell variable that is re-read on every request. If it is unset or empty, requests fail loudly.
  - If none is set, Kimi falls back to the `[providers.<name>.env]` sub-table (conventional names such as `OPENAI_API_KEY` written inside config.toml).
  - Shell variables like `OPENAI_API_KEY` are **never** picked up automatically.
- Other fields: `base_url`, `custom_headers`.
- CustomKIMI note: `model_source = "static"` stops the CloseRouter refresh for that provider.

### `[models."<alias>"]`

- **Fields:**
  - `provider`, `model`, `max_context_size` (required), `max_input_size`, `max_output_size`.
  - `capabilities`: `thinking`, `always_thinking`, `image_in`, `video_in`, `audio_in`, `tool_use`, `dynamically_loaded_tools`.
  - `support_efforts`, `default_effort`, `off_effort` (the value sent to disable thinking).
  - `extra_body` (CustomKIMI patch 0011): a table of extra top-level request fields for OpenAI Chat/Responses models, sent verbatim, e.g. `[models."x".extra_body.provider] only = ["cerebras/fp16"]`. Kimi's own fields win on conflict `[code]`.
  - `base_url` (with `protocol`), `display_name`.
  - `reasoning_key` (openai type only), `adaptive_thinking` (anthropic only).
- **Overrides:** `[models."<alias>".overrides]` holds values that survive provider refreshes. It cannot override `provider`, `model`, `protocol` or `base_url`.
- Quote aliases containing dots: `[models."glm-5.3"]`.

### `[secondary_model]`: the subagent model pool `[code]`

- **Fields:**
  - `default_model`.
  - `models`: a table of alias → hint text. It requires `default_model`, which must be one of its keys.
  - `force = true`: pin every subagent to `default_model`. Can't be combined with `models`.
  - `default_effort`: applies to every spawn.
- **Effect:** when a pool is configured, `Agent` and `AgentSwarm` gain a `model` parameter. `"primary"` means the caller's own model and effort.
- **Without a pool**, subagents inherit the caller's model.
- **Errors:** broken pool aliases fail session start loudly.
- **Scope:** used only for subagents, not for compaction or titles.
- **Effort per entry:** register variant aliases with different `overrides.default_effort`.

### Other sections

- **`[thinking]`**: `enabled` (default true), `effort` (`low`, `medium`, `high`, `xhigh`, `max`), `keep`.
- **`[loop_control]`**: `max_steps_per_turn` (unset means unlimited), `max_attempts_per_step` (10), `reserved_context_size`, `compaction_max_attempts` (5), `compaction_trigger_ratio` (0.5–0.99, default 0.85) `[code]`.
- **`[token_counting]`**: `strategy` (`measured+estimated`, `measured` or `estimated`).
- **`[background]`**:
  - `max_running_tasks`, `keep_alive_on_exit` (false), `kill_grace_period_ms` (5000).
  - `bash_auto_background_on_timeout` (true).
  - `bash_task_timeout_s` (600). It only applies to foreground commands moved to the background `[code]`.
  - `print_background_mode` (`exit`, `drain` or `steer`; default `steer`), `print_wait_ceiling_s`, `print_max_turns`.
- **`[subagent] timeout_ms`** and **`[swarm] timeout_ms`**: 2 hours each; 0 means none. Print mode has no timeout by default.
- **`[mcp]`**: `startup_timeout_ms` (30000), `tool_timeout_ms` (60000).
- **`[tools]`**: `enabled` / `disabled`, global and **enforced** `[code]`. Built-in tool names are exact and case-sensitive; MCP tools match globs such as `mcp__github__*`.
- **`[read]`**: `default_max_chars` (100000), `max_chars` (500000).
- **`[image]`**: `max_edge_px` (2000), `read_byte_budget` (262144).
- **`[services.moonshot_search]` / `[services.moonshot_fetch]`**: `base_url`, `api_key`, `oauth`, `custom_headers`. These power WebSearch and FetchURL.
- **`[permission]`**:
  - `dangerous_command_guard` (default true).
  - `rules`, also shorthand `[[permission.allow]]`, `[[permission.deny]]` and `[[permission.ask]]` with `tool` + `match`. **Rules are parsed but never applied in 2.2.0** `[code]`.
- **`[[hooks]]`**: see section 20.
- **`[identity]`**: `name`, `slug`.
- **`[watch]`**: `enabled` (default true).
- **`[database]`**: `base`, `search`.
- **`[experimental]`**: flags, see section 26.

### `tui.toml`

- `theme`: `auto`, `dark`, `light` or a custom theme name.
- `tui_mode`: `regular` or `fullscreen` (experimental; needs a restart).
- `render_latex`, `disable_paste_burst`, `cache_expiry_hint`, `disable_feedback_survey`.
- `[editor] command`.
- `[notifications] enabled` and `notification_condition` (`unfocused` or `always`).
- `[upgrade] auto_install`.
- `[status_line] items`: any of `mode`, `goal`, `model`, `tasks`, `cwd`, `git`, `tips`.
- `[status_line] command`:
  - Runs with `sh -c` and `KIMI_CODE_STATUS_LINE=1`. Its first stdout line replaces footer line 1. It has 300 ms and runs at most once per second.
  - Stdin is JSON: `model`, `cwd`, `gitBranch`, `permissionMode`, `planMode`, `contextUsage`, `contextTokens`, `maxContextTokens`, `sessionId`, `version`.
  - A non-zero exit falls back to the built-in footer.
- `[markdown] mermaid`: `final` or `off`.

### Project-local `.kimi-code/local.toml`

Only `[workspace] additional_dir` (absolute paths written by `/add-dir`). There is **no project-level config** for permissions, hooks or models `[code]`.

---

## 10. Providers and models

- **Types** `[docs]`:
  - `kimi`: Moonshot; OpenAI-compatible; supports video upload.
  - `anthropic`, `openai` (Chat Completions; handles `reasoning_content` automatically), `openai_responses`.
  - `google-genai` (give the host root only for `base_url`), `vertexai` (project and location go in the `[providers.vertexai.env]` sub-table).
- Capabilities such as thinking and vision are matched by model-name prefix. Set `capabilities` for custom models.
- **Interactive:** `/provider` opens the provider manager and can import from the models.dev catalog, with an offline snapshot. Kimi OAuth accounts are managed with `/login` and `/logout`.
- **Shell:**
  - `kimi provider add <registry-url> [--api-key]` imports from a custom registry.
  - `kimi provider remove <id>`, `kimi provider list [--json]`.
  - `kimi provider catalog list [id] [--filter]` and `catalog add <id> --api-key … [--default-model] [--base-url]`.
- **Temporary model:** `KIMI_MODEL_NAME` plus `KIMI_MODEL_API_KEY` (and optional `_PROVIDER_TYPE`, `_BASE_URL`, `_MAX_CONTEXT_SIZE`, `_CAPABILITIES`, `_THINKING_EFFORT`, …). Nothing is written to config. `-m` still wins.
- **Effort:**
  - `/effort` (alias `/thinking`) changes it mid-session. Arrow keys choose a level; Enter saves it as the default; Alt-S applies it to this session only. `/model` also uses ←/→ for effort.
  - Changing effort mid-session invalidates the prompt cache `[code]`.
  - There is no `--effort` flag and no "ultrathink" keywords `[code]`.
- **Kimi login** (`/login` or `kimi login [--region mainland-cn|global]`) adds the managed `kimi-code/*` models plus the WebSearch and FetchURL services. Remote Control and the Datasource plugin need a Kimi account; Remote Control needs a paid one.

---

## 11. Permissions and safety `[code]`

### Modes

| Config value | UI name | How to enter | Runs without asking | Still asks |
|---|---|---|---|---|
| `manual` (default) | **Always Ask** | `/permission` | Read, Grep, Glob, ReadMediaFile, TodoList, TaskList, TaskOutput, WaitFor, CronList, WebSearch, FetchURL, Agent, AgentSwarm, AskUserQuestion, NotifyUser, Skill, Enter/ExitPlanMode, the goal tools, select_tools. **Also Write/Edit inside the workspace when it is a git repo (macOS/Linux)** | Every Bash call (unless approved for the session), MCP tools, TaskStop, CronCreate/CronDelete, writes outside the repo, `.git/**`, dangerous commands |
| `yolo` | **Ask When Needed** | `/yolo` (`/yes`), `kimi -y`/`--yolo` (hidden: `--yes`, `--auto-approve`) | Everything else too, including writes outside the workspace | Dangerous commands (guard), `.git/**` paths, plan approval on ExitPlanMode. The agent can still ask questions |
| `auto` | **Never Ask** | `/auto`, `kimi --auto`, **always in `kimi -p`** | Everything, including plan exit | Nothing. `AskUserQuestion` is denied. A reminder tells the model not to ask (`KIMI_CODE_PERMISSION_MODE_REMINDER=0` disables it) |

**Switching modes:**
- `Shift-Tab` only toggles Plan mode; no key cycles permission modes.
- There is no `--manual` flag. `--yolo` and `--auto` are mutually exclusive.
- `default_permission_mode` applies to new sessions only. A resumed session keeps its saved mode unless you pass `--yolo` or `--auto`.

### Policy order

The first matching check wins:
1. Auto mode denies AskUserQuestion.
2. User deny rules (never loaded in 2.2.0).
3. Dangerous-command check (interactive sessions only).
4. Auto mode approves everything.
5. Session approval history.
6. User ask rules (never loaded).
7. User allow rules (never loaded).
8. Ask on sensitive files.
9. Ask on `.git` paths.
10. Yolo approves.
11. Default safe-tool list approves.
12. Writes inside a git working directory are approved.
13. Otherwise ask.

### Dangerous-command guard

- **How it works:** parses Bash with tree-sitter-bash (500 ms / 10k-node budget). It looks through `sudo`, `env`, `nohup`, `eval`, `busybox`, nested `sh -c` (up to 4 levels) and chains joined with `&&`, `;` or `$(…)`.
- **Catches:** `shutdown`, `halt`, `poweroff`, `reboot`, `mkfs*`, `wipefs`, `format`, `diskpart`, `init 0/6`, `systemctl poweroff/reboot`, `dd of=/dev/<disk>`, and `rm` with recursive + force unless every target is under `/tmp`.
- **Misses:** `git push --force`, `git reset --hard`, `curl … | sh`, `chmod 777`, `rm -r` without `-f`.
- **Behavior by mode:**
  - Always Ask and Ask When Needed: asks even if the exact command was approved for the session. A command it can't parse asks in manual but is allowed in yolo.
  - Never Ask: skipped. `kimi -p`: not loaded at all.
- **Settings:** on by default. `KIMI_CODE_DANGEROUS_COMMAND_GUARD=true|false` overrides the config. With `false`: yolo runs these commands without asking, manual falls back to the normal Bash prompt, and auto is unaffected (the guard never runs there anyway). Since 2.3.0, `false` also turns off two asks that used to stay on: sensitive files (`sensitive-file-access-ask`) and `.git/**` paths (`git-control-path-access-ask`) `[code]`.

### Permission rules (broken in 2.2.0)

- `[[permission.rules]]` is validated but never applied. `addRules()` is only called from tests, and kap-server hard-codes `permission_rules: []`. The docs claim they load.
- If they ever work, note:
  - Precedence would be deny > ask > allow, not file order.
  - The pattern is `Tool` or `Tool(glob)`. Bash globs match the whole command string; `*` doesn't cross `/`. There is no Claude-style `prefix:*`.
  - MCP tools and AgentSwarm match by name only.
- **What does work:** `[tools] disabled` and `PreToolUse` hooks.

### Approval UI

- **Options:** Approve once, Approve for this session, Reject, Reject with feedback. Keys: `1`–`9`, `Enter`; `Esc`/`Ctrl-C`/`Ctrl-D` reject; `Ctrl-E` expands the diff.
- There is no "always" option, and nothing is written to config.
- **Session approvals** match exactly: `Bash(<exact command>)`, `Write(<abs path>)`, or the whole tool for MCP. They are stored in the agent's `wire.jsonl` and replayed on resume.

### Sensitive files and sandbox

- **The file tools always block:** `.env*` (except example/sample/template), `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `credentials*`, `.aws/credentials`. This is checked before permissions, in every mode.
- **Not covered:** `.netrc`, `*.pem`, `~/.kimi-code/config.toml`.
- **There is no sandbox.**
  - Bash runs `bash -c` directly, with the **full parent environment** (`process.env` merged).
  - There is no network restriction.
  - Bash can read anything the user can. The system prompt itself says Bash enforces none of the file guards.
- **`.git/**` paths** ask in manual and yolo, unless `dangerous_command_guard` is off (since 2.3.0) `[code]`.

### Workspace trust

- Stored in `~/.kimi-code/workspace-trust/`, per launch folder.
- **The TUI** asks "Trust and continue" or "Exit" in untrusted folders.
- **What it gates:** only the project MCP servers (`.mcp.json`, `.kimi-code/mcp.json`). Project skills, agents and AGENTS.md load regardless.
- **Headless:** `kimi -p` skips project MCP servers unless the folder is trusted or `KIMI_CODE_TRUST_WORKSPACE=1` is set.
- **Security note:** a cloned repo's `.kimi-code/agents/agent.md` with `override: true` replaces the main system prompt. Review `.kimi-code/agents/` and `.agents/agents/` in unfamiliar repos.

### Subagents and hooks vs. permissions

- A subagent copies the caller's permission mode when it starts. Mode changes are pushed to running agents.
- `PreToolUse` hooks can block in **every** mode, including Never Ask.

---

## 12. Built-in tools `[code]`

| Tool | Key facts | Approval in Always Ask |
|---|---|---|
| `Read` | Text only. `path`, `line_offset` (negative = from end), `n_lines`, `column_offset`, `max_chars` (100k default, 500k max). Refuses PDF, Office, archives and secret files; images/video go to ReadMediaFile | auto |
| `ReadMediaFile` | Images/video ≤100 MB, `region`, `full_resolution`. Downscaled to ≤2000 px / 256 KiB. **Only exists when the model accepts image or video input** | auto |
| `Write` | `path`, `content`, `mode` (`overwrite` or `append`). Creates parent directories | ask, but auto inside a git repo |
| `Edit` | Exact `old_string` → `new_string`; `replace_all`. Non-unique matches are an error. No MultiEdit. **Read-before-edit is a prompt rule only, not enforced** | ask, but auto inside a git repo |
| `Grep` | ripgrep (PATH, else downloads to `~/.kimi-code/bin/rg`). 20 s timeout. Modes: `files_with_matches` (default), `content`, `count_matches`. 250 per page. Filters secrets. **Its `glob` matches absolute paths**, so `src/**/*.ts` finds nothing; use `**/src/**/*.ts` | auto |
| `Glob` | Files only, newest first, 100 per page. Respects `.gitignore` | auto |
| `Bash` | Always `/bin/bash` (not the login zsh) with the login PATH merged in. Runs as `bash -c "cd <cwd> && …"` in a fresh shell each call, colors off, stdin closed. **`timeout` in seconds:** foreground 60 default, 300 max; background 600 default, 86400 max. `run_in_background` needs `description`; `disable_timeout` exists. A foreground timeout moves the command to the background. Output escape sequences are sanitized | ask |
| `WebSearch` | Moonshot search service. Exists only after `/login` or with `[services.moonshot_search]` (or the `KIMI_WEB_SEARCH_BASE_URL` + API key environment variables) | auto |
| `FetchURL` | `url`. Managed fetch when logged in, otherwise a local fetch with main-text extraction. Limits: 10 MiB, 10 redirects; refuses private and loopback addresses | auto |
| `TodoList` | `todos: [{title, status: pending\|in_progress\|done}]`. Omit to read; `[]` clears | auto |
| `AskUserQuestion` | 1–4 questions, 2–4 options each, `header` ≤12 chars, `multi_select`, `background` (answer arrives later). Denied in Never Ask | auto |
| `NotifyUser` | Mid-turn progress update shown in the Updates panel. Experimental flag `notify_user` | auto |
| `Skill` | Runs an inline/prompt skill, nesting up to 3 levels | auto |
| `Agent` | Subagent; section 13 | auto |
| `AgentSwarm` | Template × items; section 16 | auto (the docs wrongly say it asks outside swarm mode) |
| `TaskList` / `TaskOutput` / `TaskStop` | Background tasks. TaskOutput is non-blocking: the last 32 KB plus an `output_path`. TaskStop sends SIGTERM, then SIGKILL after 5 s. Tasks writing more than 16 MiB are killed | TaskStop asks |
| `WaitFor` | Wait ≤90 s for background tasks. A new user message ends the wait. Flag `wait_for` (on by default) | auto |
| `CronCreate` / `CronList` / `CronDelete` | Session-bound scheduled prompts (section 17) | Create/Delete ask |
| `EnterPlanMode` / `ExitPlanMode` | Section 14 | auto |
| `CreateGoal` / `GetGoal` / `SetGoalBudget` / `UpdateGoal` | Goal mode (section 15). They are in the main agent's toolset | auto |
| `select_tools` | Loads deferred MCP tools. Flag `tool-select` | auto |
| `Tower*` (13 tools) | Tower mode, flag `tower` | — |
| `mcp__<server>__<tool>` | MCP tools | ask |

**Behavior notes:**
- **Parallelism:** Read, Grep, Glob, WebSearch, FetchURL and Agent run in parallel. Bash, task tools, TodoList, Cron, plan, goal, Skill and AskUserQuestion run one at a time. Edit and Write lock per file.
- **Large output:** results over 50,000 characters are saved to a file; the model sees the first 4 KB, the last 1 KB and the path. Read is exempt.
- **Repeat breaker:** identical consecutive calls trigger reminders at 3, 5 and 8 repeats and a forced stop at 12. `KIMI_CODE_REPEAT_BREAKER=0` disables it.
- **Prompt rules from the tool descriptions:**
  - Prefer the dedicated tools over shell.
  - Only one Edit per file per response; re-read before a second edit.
  - Git commit, push and reset run only when the user asks.
  - Never read secrets via Bash.
- **Not available:** LSP, notebook editing, PDF reading, a memory tool, built-in computer use. Computer use comes from plugins (Kimi Computer Use, Kimi Browser Extension).

---

## 13. Subagents and custom agents `[code]`

### Built-in profiles

- **`agent`** (the main agent) has every tool and delegates to `coder`, `explore` and `plan`.
- **`coder`** (the default `subagent_type`) has all main-agent tools except Agent, AgentSwarm, AskUserQuestion, the goal tools and the Tower tools.
- **`explore`** has Bash, Read, ReadMediaFile, Glob, Grep, WebSearch, FetchURL and NotifyUser. It is read-only only because its prompt says so (it has Bash). It also gets a `<git-context>` block: remote, branch, up to 20 dirty files and the last 3 commits.
- **`plan`** has Read, ReadMediaFile, Glob, Grep, WebSearch, FetchURL and NotifyUser; no shell.
- **Built-in subagents** start with this framing: "You are now running as a subagent… The main agent can only see your last message…".

### Calling subagents (`Agent` tool parameters)

- `prompt` and `description` (3–5 words) are required.
- `subagent_type` defaults to `coder`.
- `resume`: an `agent_id`. Mutually exclusive with `subagent_type`. The resumed agent keeps its own type and model.
- `run_in_background`: the result arrives later as a synthetic user message. The caller needs the task tools.
- `fork: true`: experimental, flag `subagent_fork`. The subagent starts from a snapshot of the **caller's** history and inherits the **caller's** type, tools and model. This clones the caller; it is not a persona.
- `model`: only when a pool is configured.
- **Every result includes `agent_id: …` and a `resume_hint`.** Resume works for idle subagents owned by the caller, and survives session restarts because history is stored in `agents/<id>/wire.jsonl`. Up to 32 completed subagent scopes stay in memory (`KIMI_CODE_SUBAGENT_SCOPE_CACHE_SIZE`); older ones are rebuilt from disk.
- **Parallel and timeouts:** several Agent calls in one response run in parallel. Timeout is 2 h (`[subagent] timeout_ms`); print mode has none.
- **Nesting:** built-in subagents can't spawn subagents. Custom agents can only with an explicit `subagents:` list.

### Custom agent files

- **Locations:** `$KIMI_CODE_HOME/agents/`, `~/.agents/agents/`, `<root>/.kimi-code/agents/`, `<root>/.agents/agents/`, `extra_agent_dirs`, a plugin's `agents/`, and `--agent-file`. Folders are scanned recursively for `.md` files.
- **Priority on name clash:** explicit (`--agent-file`) > project > extra > user > plugin > built-in. Replacing a built-in needs `override: true`; `--agent-file` doesn't.
- **Frontmatter:**
  - `name`: kebab-case; defaults to the file name. Invalid files are skipped with a warning.
  - `description`: **required**; the caller uses it to choose.
  - `whenToUse`.
  - `override`.
  - `tools`: allowlist as a YAML list or comma string. Omitted or `*` means all tools; `[]` means none. MCP globs like `mcp__github__*` are allowed.
  - `disallowedTools`: applied after `tools`.
  - `subagents`: allowlist of types this agent may call. `*` means all.
  - Unknown fields (`model`, `color`, …) are ignored. Claude Code-style files load, but `WebFetch`, `TodoWrite` and `Task` in `tools` match nothing (Kimi names: `FetchURL`, `TodoList`, `Agent`).
  - Invalid entries such as a bare `*` in `disallowedTools`, `mcp__github` without the tool part, or `read` instead of `Read` are warned about and never match.
- **The body is the whole system prompt**, rendered as a template on each build. Include `${base_prompt}` (the effective default prompt: built-in or SYSTEM.md, with AGENTS.md, skills, environment and plugins) or at least `${agents_md}`.
- **Custom agents used as subagents do NOT get the built-in subagent framing.** Write it yourself: "your last message is your report to the caller; don't ask the user".
- **Choosing the main agent:**
  - `kimi --agent <name>` or `kimi --agent-file <path>`, for new sessions only. Not combinable with `--session` or `--continue`.
  - The binding is permanent for that session; resume restores it.
  - A session created later in the same process (for example with `/new`) uses the default agent.
  - An unknown name errors with "Available profiles: …", which is a handy way to list all agents.

### Delegation allowlist rules

- **The caller declares `subagents:`** → exactly that list is used.
- **The caller doesn't declare it** (the default main agent, or a custom agent without the field):
  - The allowed list is the built-in default (coder, explore, plan) plus every discovered custom agent.
  - Targets that can themselves delegate (have `Agent` or `AgentSwarm`, which includes any agent with `tools` omitted) are **silently removed**.
- **Practical rules for a team:**
  - The coordinator declares `subagents:` explicitly.
  - Workers have explicit `tools` lists **without** `Agent`/`AgentSwarm`.
  - **Never give the coordinator a `tools:` allowlist** unless it includes `CreateGoal`, `GetGoal`, `SetGoalBudget` and `UpdateGoal`. Without them the goal loop can never finish. Restrict with `disallowedTools` instead.

---

## 14. Plan mode `[code]`

- **Enter:** `Shift-Tab`, `/plan [on|off]`, `kimi --plan`, `default_plan_mode = true`, or the model calling `EnterPlanMode` (no approval needed).
- **Restrictions:** Write and Edit may only touch the plan file (auto-allowed). TaskStop, CronCreate and CronDelete are blocked.
- **Bash still runs** under the current permission mode, so Plan mode is not a sandbox. Each turn must end with AskUserQuestion or ExitPlanMode.
- **Plan file:** `~/.kimi-code/sessions/<wd>/<sid>/agents/<agentId>/plans/<slug>.md`, with revisions in `plan/<id>/vN.md`. `/plan clear` empties it (idle only).
- **`ExitPlanMode`** reads the file and shows an approval panel:
  - Approve, or pick one of 1–3 `options` alternatives (label ≤80 characters; `Approve`/`Reject`/`Revise` are reserved).
  - Reject (stay in Plan mode), or Revise with feedback.
- **Never Ask** auto-approves the exit. Approving does not change the permission mode.

---

## 15. Goal mode (`/goal`) `[code]`

- **Starting:** `/goal <objective>` (≤4000 characters) creates a goal and sends the objective as the first prompt. In manual or yolo mode it first offers to switch permission mode.
- **The loop:** after each turn the runtime sends a hidden "continue" prompt. This repeats until the model calls `UpdateGoal` with `complete` or `blocked`.
  - The model may mark the goal blocked only after hitting the same blocker 3 turns in a row.
  - Impossible goals are blocked immediately.
- **Budgets:** the model calls `SetGoalBudget` (turns, tokens or time) **only when the user states a limit**. When a budget runs out, tools are rejected and the goal becomes blocked. Time only counts while the goal is active and the session is open.
- **Subcommands:**
  - `status` (alias: bare `/goal`), `pause`, `cancel`, `next <objective>`, `next manage`: available any time.
  - `resume`, `replace <objective>`: idle only.
  - If an objective starts with a subcommand word, use `--`: `/goal -- cancel the old note`, `/goal next -- manage the checklist`.
- **The queue:** `/goal next` queues a follow-up, saved in `upcoming-goals.json`. The agent doesn't see it until the current goal completes. Queued goals never start while the current one is paused, cancelled or blocked.
- **End states:** complete; paused (by you, by an interrupt, or by an error); blocked.
- **Headless:** `kimi -p "/goal …"` exits 0 (complete), 3 (blocked) or 6 (paused). Only the create form works in `-p`.
- **Footer:** the `goal` slot shows e.g. `[goal ● active · 4m · 7 turns]`. The web UI has a goal bar.
- **Limits:** goals aren't copied to forks, and goal mode and Tower exclude each other.
- **`/write-goal`** is a built-in skill that helps word an objective.
- **Good goal:** a checkable finish line plus a stop rule. Bad: "find every bug". In Always Ask mode a goal may stall at approvals.

---

## 16. Swarm and Tower

### Swarm `[code]` `[docs]`

- **`/swarm on|off`** toggles swarm mode. **`/swarm <task>`** turns it on, sends the task, and turns it off when the turn completes. It is idle-only.
- In manual mode it asks to switch to Ask When Needed or Never Ask first `[docs]`.
- **`AgentSwarm`** takes `prompt_template` (must contain `{{item}}`), `items` (≥2 unless resuming), `subagent_type`, `model` and `resume_agent_ids`.
  - It runs up to 128 subagents: 5 start immediately, then one more every 700 ms. Cap concurrency with `KIMI_CODE_AGENT_SWARM_MAX_CONCURRENCY`.
  - It waits for all of them and returns an aggregated report. Timeout is `[swarm] timeout_ms` (2 h).
  - **It must be the only tool call in its response.**

### Tower (experimental flag `tower`, needs a restart) `[code]`

- The main agent becomes a control tower: it plans missions and spawns worker and reviewer agents, **each in its own git worktree** under `.tower/worktrees/`.
- Coordination state lives in `.tower/comms/`, managed through 13 `Tower*` tools.
- **Commands:** `/tower on|off|status|teardown|<base-branch>`. Without the flag, `/tower` is sent to the model as plain text. The agent can't turn Tower on by itself, and Tower can't run with a goal.
- In Tower mode, a message sent while the agent runs aborts the turn and runs as its own turn (2.2.0). Workers don't receive permission-mode pushes.

---

## 17. Background tasks and scheduled prompts

### Background tasks `[code]`

- **Start:** `Bash` or `Agent` with `run_in_background`, `AskUserQuestion` with `background`, a foreground timeout, or `Ctrl-B`. `Ctrl-B` moves a running foreground Bash call, subagent or `!` command to the background; a hint appears after 10 s.
- **Monitor:** `TaskList`, `TaskOutput`, `WaitFor` (≤90 s), and `/tasks` in the TUI (`j`/`k` move, `Tab` filters, `r` refreshes, `s` then `y` stops a task, `Enter`/`o` shows output).
- **Results:** completion queues a `<notification>` that wakes an idle agent into a new turn.
- **On exit:** tasks end with the session unless `keep_alive_on_exit` is set. In `-p` mode, Kimi waits for and steers on background completions by default.

### Scheduled prompts (cron) `[docs]` + `[code]`

- **How:** ask in natural language ("remind me at 14:30 to…", "every weekday at 9 summarize CI failures"). The agent calls `CronCreate` with a 5-field cron expression in local time, a prompt (≤8 KB) and `recurring` (default true).
- **Limits:** at most 50 jobs per session. Recurring jobs expire after 7 days, with a final `stale` fire. Deterministic jitter is applied, and missed fires coalesce into one.
- **Scope:** session-bound. They reload on `kimi -S <id>`, are not carried into new sessions, and since 2.2.0 don't fire in forks.
- **Off switch:** `KIMI_DISABLE_CRON=1`. `CronCreate` and `CronDelete` are blocked in Plan mode.

---

## 18. Context, compaction, undo, fork, sessions `[code]`

### Compaction

- **When it triggers automatically** (checked before each step):
  - At 85% of the model's input limit, or when usage plus a 50,000-token reserve reaches the limit.
  - A ratio below 0.85 compacts in the background and only blocks at 85%.
  - A provider context-overflow error also triggers it, up to 3 times in a row.
- **`/compact [instruction]`:** idle only. The instruction is added to the summary prompt. `Esc` cancels.
- **What survives:**
  - The user's own messages, up to 20k tokens (the first 2k plus the most recent).
  - A first-person summary written by the same model.
  - The live todo list.
  - A pointer to `wire.jsonl` for exact lookups.
  - A reminder of running background tasks.
- **What is lost:** reminders, including the AGENTS.md "changed on disk" notes.

### Undo and file history

- **`/undo [n]` or `Esc Esc`** (twice within 600 ms while idle) lists recent prompts. Picking one rewinds the conversation, todo list and plan state, and puts that prompt back in the input box.
- It can't cross the last compaction, and **files are never reverted**.
- **File history** keeps copies before Write/Edit (≤4 MiB per file, last 5 turns, last 30 sessions per workspace). It is not taken before Bash, it only feeds read-only diff views in the web and desktop apps, and there is no restore command.

### Fork and export

- **`/fork`** or **`kimi fork [id] [--cwd] [-y]`** copies the whole session. You stay in the original, and `kimi --resume <id>` for the copy goes to the clipboard. Forking from a specific turn exists only in the SDK and server API (`turnIndex`).
- **`/export-md [path]`** (alias `/export`) writes readable Markdown. **`/export-debug-zip`** and **`kimi export [id] [-o] [-y] [--no-include-global-log]`** produce a debug ZIP that includes logs.

### Sessions

- **Storage:** `sessions/<workDirKey>/<sessionId>/`. `workDirKey` = `wd_<slug>_<sha256 prefix>`.
- **Listing:** `kimi session list [--cwd] [--all] [--archived] [--limit] [--json]`.
- **Session picker:** type to filter; `Ctrl-A` shows all workspaces; `Ctrl-X` deletes.
- **`/wipe-all-sessions confirm`:** CustomKIMI patch; deletes all sessions in all workspaces.
- **Prompt cache:** on resume, or after a long idle, Kimi may warn that the prompt cache expired (`cache_expiry_hint`).
- **TUI rendering:** only the last 15 turns stay rendered (`KIMI_CODE_TUI_MAX_TURNS`), and `Ctrl-O` expands the last 3 (`KIMI_CODE_TUI_EXPAND_TURNS`).

---

## 19. Skills `[code]`

### Where skills are found

- **Directories:** `$KIMI_CODE_HOME/skills`, `~/.agents/skills`, `<root>/.kimi-code/skills`, `<root>/.agents/skills`, `extra_skill_dirs` (paths with `~`, absolute, or project-relative), enabled plugins, and built-ins.
- **`.claude/skills` is not scanned.** `extra_skill_dirs = ["~/.claude/skills"]` reuses those skills in place.
- `--skills-dir <dir>` (repeatable) **replaces** the user and project directories for one launch.
- **Precedence:** project > user > extra > plugin > built-in.

### Format

- `<dir>/SKILL.md` (needs `name` and `description`), or a flat `<name>.md` at the top level of a skills folder (name defaults to the file name, description to the first line).
- Scanning recurses up to 8 levels. If both forms exist, the directory form wins.

### Frontmatter

- **Read:**
  - `name`, `description`.
  - `type`: `prompt` (default), `inline` (same), `flow` (manual only) or `reference`.
  - `whenToUse` (also `when-to-use` / `when_to_use`).
  - `disableModelInvocation` (also kebab or snake case).
  - `arguments` (list or space-separated), `has-sub-skill`.
- **Ignored:** `allowed-tools`, `model`, `context`, `agent`, `argument-hint`, `` !`cmd` `` injection.

### Placeholders

- `$ARGUMENTS`, `$ARGUMENTS[n]`, `$n` (**0-based**), `$<name>`, `${KIMI_SKILL_DIR}`, `${KIMI_SESSION_ID}`.
- With no placeholders, the arguments are appended as `ARGUMENTS: …`.
- **Any `$<digit>` in the body is always substituted**, so `awk '{print $1}'` breaks.
- A plugin's `skillInstructions` are prepended to its skills.

### Invocation

- **By the user:**
  - `/skill:<name> [args]`.
  - `/<name>`, if no built-in command has that name.
  - `/<name>` written anywhere mid-prompt. Several can be activated at once.
  - `/<parent>.<sub>` for sub-skills.
- **By the model:** through the `Skill` tool (auto-approved, nesting ≤3).
  - The model's listing excludes `disableModelInvocation`, `flow` and sub-skills, with descriptions cut at 250 characters.
  - The skill list is frozen per agent when it is created, so new skills need a new session.
  - `kimi -p "/skill:x"` sends the text literally.
- **Busy agent:** skill commands typed while the agent works are queued. `Ctrl-S` steers them in.

### Built-in skills

- `/mcp-config`: MCP setup and OAuth login.
- `/import-from-cc-codex`: imports Claude Code and Codex instructions, skills and MCP (previews before writing). Scope:
  - **Reads** `~/.claude/{AGENTS,CLAUDE}.md`, `~/.claude/skills`, `~/.claude.json` mcpServers, `.claude/` project files, and the Codex equivalents.
  - **Appends** marked blocks to Kimi's AGENTS.md, copies skills without overwriting, and only *prints* MCP entries for `/mcp-config`.
  - **Skips** commands, hooks, plugins, output styles, agents, and project-root CLAUDE.md/AGENTS.md.
- `/update-config`: edits config.toml and tui.toml by conversation.
- `/custom-theme [text]`: creates a theme.
- `/write-goal`: words a goal.
- `/check-kimi-code-docs`: answers from the official docs, so it inherits their errors.
- `/sub-skill`, `/sub-skill.review`, `/sub-skill.consolidate`: reorganize skills into bundles.
- The skills that document Kimi itself can be hidden with `builtin_product_skills = false`.

---

## 20. Hooks `[code]`

### Configuration

- `[[hooks]]` in `$KIMI_CODE_HOME/config.toml`, plus the `hooks` arrays of enabled plugins. **There are no project-level hooks.**
- **Fields (strict):** `event`, `matcher` (optional), `command`, `timeout` (1–600 s, default 30). Extra fields invalidate the whole `hooks` section, which disables all hooks.

### Events (20)

- **Tools:** PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, PermissionResult.
- **Prompts and turns:** UserPromptSubmit, UserPromptQueued, TurnStarted, Stop, StopFailure, Interrupt.
- **Sessions:** SessionStart (`startup`|`resume`), SessionEnd (`exit`|`archive`), SessionHeartbeat (every 60 s, only when configured).
- **Subagents and tasks:** SubagentStart, SubagentStop, TaskStarted.
- **Compaction:** PreCompact, PostCompact.
- **Notification:** background-task status changes, e.g. matcher `task\.completed`.

### Matching and running

- **Matcher:** `new RegExp(matcher).test(value)`, unanchored and case-sensitive. Empty matches everything. An invalid regex such as `*` never fires. Use `^Bash$`.
- **Execution:** hooks run in parallel under `/bin/sh`, and identical commands run once.
  - Global hooks run in the project directory.
  - Plugin hooks run in the plugin root, with `KIMI_PLUGIN_ROOT` and `KIMI_CODE_HOME` set.

### Stdin payload (snake_case JSON)

- Always: `hook_event_name`, `session_id`, `cwd`, `client_type`, `session_title`.
- Tool events: `tool_name`, `tool_input`, `tool_call_id`, `tool_output` (≤2000 chars). **Write and Edit use `tool_input.path`, not `file_path`.**
- UserPromptSubmit: `prompt` as an **array** of content parts.
- Stop: `stop_hook_active` (always false).
- SessionStart: `source`, `model`, `profile`.
- TurnStarted: `turn_id`, `origin_kind`, `origin_name`, `prompt`.
- There is no `transcript_path` and no `tool_response`.

### Decisions

- **Exit 2 blocks,** using stderr as the reason. Any other exit, a timeout or a crash **allows**: hooks fail open.
- On exit 0, JSON `{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"…"}}` blocks. A `message` field supplies text.
- **Ignored:** `allow`/`ask` decisions, `additionalContext`, `decision`, `continue`, `systemMessage`, `updatedInput`.
- **Blockable events:** PreToolUse, UserPromptSubmit and Stop. A Stop block re-prompts the model at most once per turn. A blocked UserPromptSubmit skips the model call.
- **Output handling:**
  - UserPromptSubmit stdout is injected as `<hook_result>`; since 2.2.0, JSON output without `message` is not added.
  - SessionStart output is discarded, so it cannot add context.
  - PreCompact return values are ignored.
- **Timing:** PreToolUse runs before permission checks, and a block works in every mode.

---

## 21. Plugins `[code]`

### Manifest

- `kimi.plugin.json` (wins) or `.kimi-plugin/plugin.json`. **Claude, Codex and Gemini manifests are ignored.** A Claude-only plugin fails to install with "No manifest…".
- **Fields:**
  - `name` (the id; `[a-z0-9][a-z0-9_-]{0,63}`), `version`, `description`, `interface{displayName,…}`.
  - `skills` (`./` paths; otherwise only a root `SKILL.md`), `agents` (default `agents/`), `commands` (must be declared).
  - `sessionStart.skill`: loaded into the main agent at session start.
  - `skillInstructions`.
  - `systemPrompt` / `systemPromptPath`: ≤32 KB each, ≤64 KB total across plugins.
  - `mcpServers`, inline.
  - `hooks`, in Kimi format.
- **Unsupported** (shown as diagnostics): `tools`, `apps`, `inject`, `configFile`. `${CLAUDE_PLUGIN_ROOT}` is not supported; use `KIMI_PLUGIN_ROOT`.

### Plugin commands

- Invoked as `/<plugin>:<command>`. Only `name`, `description` and `$ARGUMENTS` are honored. Without `$ARGUMENTS`, text is appended as `ARGUMENTS: …`.

### Installing and managing

- **Sources:** GitHub (`/tree/<ref>`, `/releases/tag/<tag>`, `/commit/<sha>`; no subdirectories), zip URLs, local folders. Each is copied to `plugins/managed/<id>/`. Plugins are per-user only.
- **Trust labels:** `official` (Kimi CDN zips), `curated`, `third-party` (everything else, including all GitHub installs). Labels plus a "Trust and install" prompt; no sandbox.
- **Commands** (TUI only; there is no `kimi plugin` CLI):
  - `/plugins` opens the manager. Tabs: Installed, Official, Curated, Custom. Keys: Space toggles, D removes, M manages MCP, R reloads, I shows info.
  - `/plugins list|install <src>|marketplace [src]|info|enable|disable|remove <id>|reload|mcp enable|disable <id> <server>`.
- **Updates and removal:**
  - Changes apply after `/reload` or `/new`.
  - Updating means reinstalling; update checks cover GitHub installs only, and tag or SHA pins never update.
  - `remove` deletes only the record.
- **Custom marketplace JSON:** `{"version":"2","plugins":[{"id","source"}]}`. Claude `marketplace.json` files fail. Override with `KIMI_CODE_PLUGIN_MARKETPLACE_URL`.

### Official plugins `[docs]`

- **Kimi Datasource:** financial, macro, legal and academic data; needs a Kimi login and uses quota.
- **Kimi Browser Extension:** drives your real browser; needs the Chrome/Edge extension.
- **Kimi Computer Use:** macOS/Windows desktop control.

### The user's plugins `[user]` `[code]`

- **superpowers 7.0.0** works because it ships `.kimi-plugin/plugin.json`.
  - It provides 15 skills: brainstorming, diagnosing-superpowers, dispatching-parallel-agents, executing-plans, finishing-a-development-branch, receiving-code-review, requesting-code-review, subagent-driven-development, systematic-debugging, test-driven-development, using-git-worktrees, using-superpowers, verification-before-completion, writing-plans, writing-skills.
  - `sessionStart.skill = using-superpowers`, injected for the main agent only.
  - Its `skillInstructions` map TodoWrite→TodoList and Task→Agent.
  - Its Claude `hooks/hooks.json` is unused.
  - Skills are invoked as `/skill:brainstorming`. `Skill("superpowers:brainstorming")` fails; names are flat.
- **kimi-cu** is the official computer-use plugin: skills plus a stdio MCP server `mac`, with tools `mcp__plugin-kimi-cu_mac__*`. On macOS it needs Accessibility and Screen Recording permissions.

---

## 22. MCP `[code]`

### Config files

- **Load order (same name: later wins):**
  1. `$KIMI_CODE_HOME/mcp.json`.
  2. `<git root>/.mcp.json` (Claude Code's project file, read natively).
  3. `<cwd>/.kimi-code/mcp.json`.
  4. Plugin servers.
- **Never read:** `~/.claude.json`, Claude Desktop, Cursor and Codex configs.

### Schema

- `{"mcpServers": {name: {…}}}`.
- **stdio:** `command`, `args`, `env`, `cwd`.
- **http/sse:** `url`, `headers`, `bearerTokenEnvVar`, `auth: "oauth"`. A `url` without `transport` means HTTP. **SSE needs `"transport": "sse"`**; Claude's `type` key is ignored.
- **All servers:** `enabled`, `deferred` (experimental), `startupTimeoutMs`, `toolTimeoutMs`, `enabledTools`, `disabledTools`.
- **There is no `${VAR}` expansion.**
- **One invalid server voids its whole file.**

### Behavior

- **Transports:** stdio, Streamable HTTP, SSE. Only **tools** are used (no prompts, no resources).
  - Embedded media are preserved as `kimi-file://` references.
  - `structuredContent` is passed along.
- **OAuth:** a 401 exposes `mcp__<srv>__authenticate`. `/mcp-config login <srv>` runs PKCE with a 127.0.0.1 callback. Tokens go in `credentials/mcp/`; `/logout` doesn't clear them.
- **Tool names:** `mcp__<server>__<tool>`, sanitized and ≤64 characters.
- **Approval:** every MCP call asks in Always Ask. "Approve for this session" covers that one tool. Yolo and auto approve automatically.
- **Commands:** `/mcp` shows status. `/mcp-config` adds, edits or logs in conversationally. There is no `kimi mcp` CLI.
- **Lifecycle:**
  - New servers join new sessions only.
  - Removed servers keep showing as `removed` in open sessions.
  - Plugin servers can be toggled live.
  - Project files load only in trusted folders.
- **Deferred tools** (like Claude Code's tool search): `"deferred": true` + the `tool-select` flag + a model with the `dynamically_loaded_tools` capability.
- **Proxies:** `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NO_PROXY` are honored. Loopback always bypasses the proxy.

---

## 23. TUI: commands, keys, input `[code]`

### Slash commands

A = available any time; I = idle only.

| Command (aliases) | Does | Avail |
|---|---|---|
| `/help` (`/h`, `/?`) | Help panel | A |
| `/new` (`/clear`) | New session (re-reads AGENTS.md) | I |
| `/sessions` (`/resume`) | Session picker | I |
| `/fork` | Copy the session, stay in the original | I |
| `/undo [n]` | Rewind the conversation (not files) | I |
| `/compact [instr]` | Compact the context | I |
| `/title [t]` (`/rename`) | Show or set the title | A |
| `/usage` | Tokens, context, quota | A |
| `/status` | Version, model, cwd, mode | A |
| `/model [alias]` | Switch model (←/→ effort); CustomKIMI shows each model's context window | A |
| `/effort [lvl]` (`/thinking`) | Thinking effort (undocumented) | A |
| `/secondary-model` (`/subagent-model`) | Subagent default model | A |
| `/provider` (`/providers`) | Provider manager | A |
| `/permission` | Permission picker | A |
| `/yolo` (`/yes`) | Picker with Ask When Needed preselected | A |
| `/auto` | Picker with Never Ask preselected | A |
| `/plan [on\|off\|clear]` | Plan mode (`clear` is idle only) | A |
| `/goal …` | Goal mode (create/replace/resume idle-only) | mixed |
| `/swarm on\|off\|<task>` | Swarm mode | I |
| `/tower …` | Tower (experimental flag) | A |
| `/btw [q]` | Side question to a forked read-only agent | A |
| `/tasks` (`/task`) | Background tasks browser | A |
| `/mcp` | MCP status | A |
| `/plugins …` | Plugin manager | A |
| `/add-dir [path\|list]` | Add a workspace directory | I |
| `/init` | Generate AGENTS.md | I |
| `/settings` (`/config`) | Settings panel | A |
| `/experiments` (`/experimental`) | Experimental flags (the docs wrongly say always available) | I |
| `/reload` | Reload session + config.toml + tui.toml | I |
| `/reload-tui` | Reload tui.toml | A |
| `/editor [cmd]` | Ctrl-G editor | A |
| `/theme [name]` | Theme | A |
| `/login`, `/logout` (`/disconnect`) | Kimi account / provider logout | I |
| `/export-md [path]` (`/export`) | Markdown export | I |
| `/export-debug-zip` | Debug ZIP | I |
| `/copy` | Copy the last reply | I |
| `/web` | Hand the session to the web UI (always starts a new server) | A |
| `/remote-control` (`/rc`) | Remote Control | A |
| `/desktop` (`/install-desktop`) | Desktop app page | A |
| `/feedback` (`/bug`) | Send feedback | A |
| `/version` | Version | A |
| `/exit` (`/quit`, `/q`) | Exit | I |
| `/wipe-all-sessions confirm` | CustomKIMI: delete all sessions | I |
| `/skill:<name>`, `/<plugin>:<cmd>`, built-in skill commands | Skills and plugin commands | queued if busy |

### Input syntax

- **`/`** at the start runs a command. Unmatched input goes to the model as text.
- **`@`** opens a fuzzy file/folder picker (cwd + added dirs). It inserts `@path` or `@"path with spaces"`; the model reads the file itself.
- **`!`** in an empty prompt enters shell mode.
  - Backspace or Esc on an empty line exits; `↑` recalls earlier `!` commands.
  - Output goes into the context.
  - Commands queue if the agent is busy.
- **There is no `#` or `&` prefix.**
- **Paste:**
  - `Ctrl-V` (Windows: `Alt-V`) pastes an image **or video**. On macOS, a media file copied in Finder becomes an attachment.
  - Drag-and-drop inserts only the path.
  - Pastes over 10 lines or 1000 characters collapse to `[paste #N +X lines]`.
  - Media over 20 MB per conversation: the oldest are dropped `[docs]`.
- **New lines:** `Shift-Enter`, `Ctrl-J`, `Alt-Enter`, or `\` then Enter.
- **History:** `↑`/`↓` on an empty prompt walks per-folder history. **There is no `Ctrl-R` search.**
- **While the agent works:**
  - `Enter` **queues** your message.
  - `Ctrl-S` **steers** it into the running turn.
  - `↑` on an empty prompt edits the last queued message.
  - While `WaitFor` runs or in Tower mode, Enter steers automatically.

### Keys

| Key | Does |
|---|---|
| `Shift-Tab` | Toggle Plan mode (only) |
| `Esc` | Close a popup/autocomplete/btw panel, cancel compaction, or interrupt |
| `Esc Esc` (idle, within 600 ms) | Undo selector |
| `Ctrl-C` | Busy: clears typed text, then interrupts. Idle: clears the line; twice within 1.5 s exits. During shutdown: force exit |
| `Ctrl-D` | Twice on an empty line exits; otherwise deletes forward |
| `Ctrl-S` | Steer |
| `Ctrl-B` | Background the running command, subagent or `!` command |
| `Ctrl-O` | Expand/collapse tool output and compaction summaries |
| `Ctrl-T` | Expand the todo list |
| `Ctrl-N` | Focus the Updates panel (←/→ channels, ↑/↓ pages, Esc leaves) |
| `Ctrl-G` | External editor (`/editor` → `$VISUAL` → `$EDITOR`) |
| `Ctrl--` | Undo the last edit in the input box |
| `Ctrl-A`/`E`/`W`/`U`/`K`/`Y`, `Alt-Y`/`B`/`F`, `Ctrl-]` | Emacs-style editing |
| Approval panel | `1`–`9`, `Enter`, `Esc`/`Ctrl-C`/`Ctrl-D` reject, `Ctrl-E` expand diff, `Ctrl-O` |
| Fullscreen only | `PgUp`/`PgDn`, `Ctrl-↑`/`Ctrl-↓` between prompts, `Ctrl-Shift-F` search, `Home`/`End` |

Key bindings cannot be customized. At startup Kimi runs `stty -ixon` so `Ctrl-S` reaches the app.

### Notifications and themes

- **Notifications:** sent on approval needed, question asked and turn complete. They use OSC 9 desktop notifications where the terminal supports it, otherwise a bell; tmux passthrough works. Use a `Notification` hook for custom actions.
- **Themes:** `/theme`. Custom themes are JSON at `~/.kimi-code/themes/<name>.json`: `{name, base: dark|light, colors}` with tokens such as `primary`, `accent`, `text`, `border`, `success`, `warning`, `error`, `diffAdded`, `roleUser` and `shellMode`. `/custom-theme` writes them for you.
- **Rendering:** Mermaid diagrams render in the terminal, and LaTeX renders as Unicode.

---

## 24. CLI and headless `[code]`

### Main flags

- **Sessions:** `-S/--session [id]` (hidden alias `-r/--resume`), `-c/--continue` (hidden `-C`).
- **Model and prompt:** `-m/--model <alias>`, `-p/--prompt <text>`, `--output-format text|stream-json`.
- **Modes:** `-y/--yolo`, `--auto`, `--plan`.
- **Extras:** `--skills-dir` (repeatable; replaces discovery), `--agent <name>` / `--agent-file <path>`, `--add-dir <dir>` (repeatable), `-V/--version`, `-h/--help`.

**Flag conflicts:**
- `-p` can't be combined with `--yolo`, `--auto` or `--plan`.
- `--continue` and `--session` exclude each other, as do `--yolo` and `--auto`.
- `--agent`/`--agent-file` can't be combined with `--session` or `--continue`, nor with each other.
- `--output-format` requires `-p`.

**Missing** compared with Claude Code: `--effort`, `--max-turns`, `--system-prompt`, `--allowedTools`, `--mcp-config`, `--manual`.

A bare positional prompt (`kimi "fix it"`) is an error ("unknown command").

### Subcommands

- **Basics:** `login [--region]`, `acp [--login --region]`, `doctor [config|tui [path]]`, `export`, `fork [id] [--cwd] [-y]`, `session list […]`.
- **Web:** `web` (flags in section 25), `web rotate-token`, `rc`/`remote` (web with Remote Control forced on).
- **Providers:** `provider add|remove|list|catalog list|catalog add`.
- **Other:** `vis [id] [--port --host --no-open]`, `app [path]`, `install-desktop`, `migrate [--run [--config-only]]` (from the legacy Python kimi-cli in `~/.kimi/`), `upgrade|update [-y]` (**never in CustomKIMI**).
- **Deprecated:** `server` (exits 1; `server kill` still works).
- **There are no `mcp`, `plugin` or `logout` subcommands.**

### Headless (`-p`)

- **Input:**
  - **Stdin is not read**: pass the prompt as the argument, e.g. `kimi -p "$(cat task.md)"`.
  - `kimi -p "/goal …"` runs goal mode. `kimi -p "/skill:x"` is sent literally.
- **Permissions:** forces Never Ask for the run (restoring the old mode on resumed sessions). The dangerous-command guard is not loaded; static deny rules would apply if rules worked.
- **Session selection:**
  - `-c` picks the newest session in the same cwd; if there is none, it starts fresh with a stderr note.
  - `-S <id>` from another directory fails with a `cd … && kimi -r <id>` hint.
- **Limits:** step, bash and subagent limits are removed. Background tasks are steered back in until none remain (`print_background_mode = "steer"`).
- **MCP:** project servers are skipped in untrusted folders unless `KIMI_CODE_TRUST_WORKSPACE=1`.
- **Output:**
  - **text:** the reply goes to stdout with `•` bullets. Thinking, the version and the resume hint go to stderr, and tool calls aren't printed.
  - **stream-json:** one JSON object per line on stdout, per message (not per token):
    - It opens with `{"role":"meta","type":"system.version"}`.
    - Each step emits `{"role":"assistant","content","tool_calls":[…]}` and `{"role":"tool","tool_call_id","content"}`.
    - Retries emit `{"role":"meta","type":"turn.step.retrying"}`.
    - Goal runs add `{"type":"goal.summary"}`.
    - It ends with `{"role":"meta","type":"session.resume_hint","session_id","command"}`.
    - Thinking is never emitted.
  - `KIMI_MODEL_OUTPUT_FORMAT` sets the default format.
- **Exit codes:** 0 success; 1 failure (including flag conflicts and hook-blocked prompts); 3 goal blocked; 6 goal paused; 130/129/143 for SIGINT/SIGHUP/SIGTERM; 2 for `migrate --config-only` without `--run`.

### SDK

`@moonshot-ai/kimi-code-sdk` (`packages/node-sdk`) is marked `private` in this checkout, and its README is a stub. It runs the engine in-process:

```ts
const h = createKimiHarness({});
const s = await h.createSession({ workDir: process.cwd(), model: (await h.getConfig()).defaultModel, permission: 'auto' });
const done = new Promise<void>(r => s.onEvent(e => {
  if (e.type === 'assistant.delta') process.stdout.write(e.delta);
  if (e.type === 'turn.ended') r();
}));
await Promise.all([s.prompt('Summarize this repo'), done]); await h.close();
```

- **Session methods:** `steer`, `cancel`, `setModel`, `setThinking`, `setPermission`, `setPlanMode`, `compact`, `createGoal`, `setApprovalHandler`.
- **Harness methods:** `resumeSession`, `forkSession`, `listSessions`.

---

## 25. Other surfaces

- **`kimi web`** (and `/web`) runs a foreground server on `127.0.0.1:58627`; busy ports go +1. It serves REST `/api/v1` (+`/api/v2/sessions`), a WebSocket at `/api/v1/ws`, and the web UI. Specs are at `/openapi.json` and `/asyncapi.json`.
  - **Auth:** a bearer token in `~/.kimi-code/server.token`; the banner URL includes `#token=`. `kimi web rotate-token` issues a new one.
  - **Flags:** `--port`, `--host [h]` (bare = 0.0.0.0, LAN/phone; also set `KIMI_CODE_PASSWORD`), `--allowed-host`, `--log-level`, `--debug-endpoints`, `--dangerous-bypass-auth` (never on untrusted networks), `--web-title`, `--no-open`, `--rc/--remote-control`.
  - **Features:** shared sessions and config, click-to-approve, diffs, task panel, global search, archive, settings and Lab.
  - **Web commands:** `/new`, `/goal`, `/compact`, `/tower`, `/export` (a ZIP), `/remote-control`.
  - The basic API flow: POST `/sessions`, subscribe over WebSocket, POST `/sessions/{id}/prompts` `[docs]`.
- **`kimi rc`** (or `kimi web --rc`, or `/rc`) controls the machine from a phone through Kimi's relay (`code-rc.kimi.com` / `.ai`). It shows a QR code.
  - **Requires a paid Kimi membership.**
  - Loopback only; one instance per machine (lock file `~/.kimi-code/server/rc.json`); about 3 devices per account. Not usable for this user's third-party-only setup.
- **`kimi acp`** speaks Agent Client Protocol (JSON-RPC over stdio) for Zed, JetBrains and Paseo. Use the absolute `kimi` path in GUI apps. IDE-forwarded MCP servers work for http, stdio and sse.
  - Zed config: `"agent_servers": {"Kimi Code CLI": {"type": "custom", "command": "kimi", "args": ["acp"], "env": {}}}`.
- **`kimi vis [id]`** opens a session visualizer in the browser.
- **`kimi app [path]`** and **`/desktop`** relate to the Kimi Code desktop app. A VS Code extension also exists ("Kimi Code for VS Code").
- **Video input:** paste a recording or use `ReadMediaFile`. Needs a model with `video_in` (Kimi models); most of the user's aliases lack it.

---

## 26. Experimental flags `[code]`

- **Precedence:** per-flag environment variable `KIMI_CODE_EXPERIMENTAL_<NAME>` > `[experimental] <id>` in config.toml > master `KIMI_CODE_EXPERIMENTAL_FLAG=1` > the flag's default.
- **`/experiments`** writes `[experimental]` and reloads.

| id (config key) | Default | Enables |
|---|---|---|
| `wait_for` | **on** | `WaitFor` tool |
| `notify_user` | off (**on for this user**) | `NotifyUser` + Updates panel. New sessions only |
| `subagent_fork` | off | `fork` param on Agent/AgentSwarm |
| `tool-select` (hyphen) | off | Deferred MCP tools via `select_tools` |
| `tower` | off | Tower mode (restart needed) |

Hidden experimental config, commented out in the docs: `micro_compaction` trims older large tool results `[docs]`.

---

## 27. Environment variables (selection)

| Variable | Effect |
|---|---|
| `KIMI_CODE_HOME` | Data root (default `~/.kimi-code`) |
| `KIMI_MODEL_*` | Temporary model (section 10) |
| `KIMI_CODE_NO_AUTO_UPDATE` | Disable update checks (the user's wrapper sets it) |
| `KIMI_DISABLE_TELEMETRY` | Telemetry off |
| `KIMI_LOG_LEVEL` | off/error/warn/info/debug; logs go to `~/.kimi-code/logs/kimi-code.log` |
| `KIMI_CODE_DEBUG=1` | Per-step timing in the transcript |
| `KIMI_SHELL_PATH` | Windows Git Bash path only |
| `KIMI_CODE_TRUST_WORKSPACE` | Trust the folder for this process |
| `KIMI_CODE_DANGEROUS_COMMAND_GUARD` | true/false override |
| `KIMI_CODE_PERMISSION_MODE_REMINDER=0` | No Never Ask reminder |
| `KIMI_CODE_REPEAT_BREAKER=0` | Disable the repeat breaker |
| `KIMI_CODE_INFINITE_RETRY` | Retry LLM requests forever (backoff ≤32 s) |
| `KIMI_LOOP_MAX_STEPS_PER_TURN`, `KIMI_LOOP_MAX_ATTEMPTS_PER_STEP` | Loop limits |
| `KIMI_SUBAGENT_TIMEOUT_MS`, `KIMI_CODE_SWARM_TIMEOUT_MS` | Timeouts |
| `KIMI_CODE_AGENT_SWARM_MAX_CONCURRENCY` | Swarm concurrency cap |
| `KIMI_CODE_SUBAGENT_SCOPE_CACHE_SIZE` | Resident subagent scopes (32) |
| `KIMI_CODE_BACKGROUND_*` | Overrides for the `[background]` keys |
| `KIMI_DISABLE_CRON=1` | Disable cron |
| `KIMI_WEB_SEARCH_BASE_URL` / `_API_KEY`, `KIMI_WEB_FETCH_BASE_URL` / `_API_KEY` | Web services |
| `KIMI_MCP_STARTUP_TIMEOUT_MS`, `KIMI_MCP_TOOL_TIMEOUT_MS` | MCP timeouts |
| `KIMI_CODE_IDENTITY_NAME` / `_SLUG` | Identity |
| `KIMI_CODE_BUILTIN_PRODUCT_SKILLS` | Kimi-docs skills on/off |
| `KIMI_CODE_WATCH` | File watchers on/off |
| `KIMI_CODE_PLUGIN_MARKETPLACE_URL` | Marketplace JSON |
| `KIMI_CODE_CUSTOM_HEADERS` | Extra HTTP headers on model requests |
| `KIMI_CODE_LLM_HEADERS_TIMEOUT_MS` | First-byte timeout |
| `KIMI_TOKEN_COUNTING_STRATEGY` | Context counting |
| `KIMI_IMAGE_MAX_EDGE_PX`, `KIMI_IMAGE_READ_BYTE_BUDGET` | Image limits |
| `KIMI_CODE_TUI_MAX_TURNS` (15), `KIMI_CODE_TUI_EXPAND_TURNS` (3) | TUI rendering window |
| `KIMI_CODE_PASSWORD` | Extra credential for `kimi web` on a LAN |
| `KIMI_CODE_EXPERIMENTAL_*` | Flags (section 26) |
| `HTTP(S)_PROXY`, `ALL_PROXY` (SOCKS ok), `NO_PROXY` | Proxies |

---

## 28. Where Kimi's docs are wrong (verified in code)

1. **`[[permission.rules]]` "load at session start":** never applied in 2.2.0.
2. **"Always Ask" "asks for every edit":** auto-approves Write/Edit inside a git repo.
3. **Write/Edit "require a prior Read and reject changed files":** not enforced in code.
4. **Bash `timeout` "in milliseconds":** it is seconds.
5. **`bash_task_timeout_s` "default for background tasks":** only for commands moved to the background. Explicit background calls default to 600 s.
6. **FetchURL "needs a host implementation":** always available via the local fallback.
7. **AgentSwarm "needs approval outside swarm mode":** auto-approved.
8. **The plugins docs say prompts are rebuilt after compaction or tool-policy changes:** no runtime rebuild path exists.
9. **`${now}` template variable:** removed; renders literally.
10. **"Never Ask handles sensitive files automatically" / yolo "asks":** the file tools always **block** sensitive files, and Bash is never checked.
11. **The 0.40.0 changelog says auto mode blocks dangerous commands:** reversed in 0.41.0; auto skips the guard.
12. **`/experiments` and `/swarm on|off` "always available":** idle-only.
13. **`/web` "pick a running server":** always starts a new one.
14. **The docs changelog stops at 2.1.1.** 2.2.0 notes are in `source/apps/kimi-code/CHANGELOG.md`.
15. **The MCP docs omit `.mcp.json`;** the code reads it.
16. **The keyboard docs list "Ctrl-P previous page":** it no longer exists.
17. **Undocumented:** `/effort` (`/thinking`), `/tower`, `/write-goal`, `/dance` (easter egg), `kimi fork`, `kimi session list`, inline `/skill` tokens, `KIMI_MODEL_OUTPUT_FORMAT`, `KIMI_CODE_TUI_MAX_TURNS`, `${KIMI_SESSION_ID}`, `type: reference` skills, `[markdown] mermaid` in tui.toml.
18. **Consequence:** `/check-kimi-code-docs` answers from these docs and inherits their errors.

---

## 29. Gotchas, ranked

1. **Config permission rules do nothing in 2.2.0.** This fails silently.
2. **One invalid entry disables a whole config section,** with only a warning. A bad hook disables all hooks; a bad MCP server voids its file. Run `kimi doctor`.
3. **`/undo` never restores files.** Use git; commit before long runs.
4. **AGENTS.md is read once per session.** Use `/new`, not `/reload`. CLAUDE.md is never read.
5. **Mode names mislead:** `--yolo` = Ask When Needed, `--auto` = Never Ask, and `kimi -p` is always Never Ask. Resumed sessions keep their mode.
6. **No sandbox.** Bash inherits the full environment, including the API keys the user's wrapper exports.
7. **Hooks fail open and can only deny.** SessionStart output is discarded. The matcher is a regex: use `^Bash$`, never `*`.
8. **The agent's shell is bash, fresh on each call.** No zsh aliases, `cd` doesn't persist, and parallel Bash calls run serially.
9. **No web search without a Kimi login.**
10. **`$<digit>` in skill bodies is always substituted.** Skills are frozen per session; `-p "/skill:x"` is literal.
11. **Cloned repos can override the system prompt** via project agent files. Project skills, agents and AGENTS.md load before trust.
12. **`kimi -p` ignores stdin and has no `--max-turns`.**
13. **The main agent sees no git status and doesn't know its model name.**
14. **Custom agent files without `${base_prompt}` or `${agents_md}` don't see AGENTS.md.** A coordinator with a `tools:` list breaks goal mode.
15. **`/new` drops the `--agent` selection.**
16. **Grep's `glob` matches absolute paths.**
17. **`kimi upgrade` / `npm i -g` replace the CustomKIMI build.**

---

## 30. Best practices

### Instructions
- One file for both tools: AGENTS.md is the real file, and CLAUDE.md is a symlink to it.
- Write AGENTS.md as concrete project facts: commands, folder map, conventions, never-touch list.
- Keep it under 32 KiB.
- Use nested AGENTS.md files per folder.
- Run `/new` after edits.

### Memory
- Keep a `PROGRESS.md` (and optionally `DECISIONS.md`), referenced from AGENTS.md.
- Name sessions with `/title`.
- Resume with `kimi -c`.

### Safety
- Default to Ask When Needed with the guard on.
- Install the guard hook (section 31.6).
- Restrict tools with `[tools] disabled`.
- Run Never Ask, `-p` and long goals only on a branch or `git worktree`, after committing.
- Run `kimi doctor` after config edits.
- Review `.kimi-code/agents/` in cloned repos.

### Context
- Delegate exploration to `explore`.
- One session per task.
- `/compact <keep X>` at natural breaks.
- Ask workers for short reports.
- Check `/usage`.

### Cost
- Strong model for the main agent, cheap pool models for helpers (`[secondary_model]` with hints).
- Choose effort at session start; changing it mid-session breaks the prompt cache.
- Watch the footer cost (CustomKIMI patch).

### Autonomy
- `/goal` with a checkable finish line and an explicit stop rule or budget.
- `/goal next` to queue follow-ups.
- `/btw` for side questions.
- `Ctrl-S` to steer instead of interrupting.
- `Ctrl-B` to background slow commands.

### Parallelism
- Several independent Agent calls in one response.
- `/swarm` for many similar items.

### Updates
- Re-verify section 28 after each `scripts/update.sh`.

---

## 31. Templates and recipes

### 31.1 Set up a project (run in the repo root)

```sh
# rules file (if a CLAUDE.md exists)
git mv CLAUDE.md AGENTS.md && ln -s AGENTS.md CLAUDE.md
# memory file
printf '# Progress\n\n## Goal\n\n## Team (agent ids)\n\n## Done\n\n## Next\n\n## Problems\n' > PROGRESS.md
# custom agents and skills (only if needed)
mkdir -p .kimi-code/agents .kimi-code/skills
# keep machine-specific settings out of git
echo ".kimi-code/local.toml" >> .gitignore
```

### 31.2 AGENTS.md template

```markdown
# <project name>

## Commands
- Install: <cmd>
- Build: <cmd>
- Test: <cmd>
- Lint: <cmd>

## Layout
- src/…: <what lives here>

## Conventions
- <style rules, naming, patterns to follow>

## Never
- Never edit <generated/vendor paths>.
- Never commit or push unless asked.

## Memory
- Read PROGRESS.md before starting; update it after every step.
```

### 31.3 PROGRESS.md template

```markdown
# Progress
## Goal
<the current objective and its finish line>
## Team (agent ids)
- builder: agent-…
## Done
- …
## Next
- …
## Problems
- …
```

### 31.4 Coordinator team for goal loops (the user's target design)

**Files:** `.kimi-code/agents/{coordinator,planner,builder,tester,reviewer}.md`.

**How it runs:**
- The coordinator is the main agent (`kimi --agent coordinator`).
- Workers are its subagents. Each worker gets Kimi's normal prompt plus AGENTS.md through `${base_prompt}`, then its role.
- The coordinator routes work using the workers' descriptions plus its own instructions.
- It decides fresh vs resume per call, and records agent ids in PROGRESS.md.

**`coordinator.md`**
```markdown
---
name: coordinator
description: Runs the project; decides what happens next and hands every task to a worker
subagents: planner, builder, tester, reviewer
disallowedTools: Bash
---
${base_prompt}

## Your job: coordinator
You never write code or run commands. You decide what's next and call the right worker:
- planner: splits a feature into small steps (reads only)
- builder: writes or changes code for one step
- tester: runs the tests and reports exactly what fails
- reviewer: checks the changes; must approve before the goal is done

Every turn:
1. Read PROGRESS.md.
2. Call one worker with a complete, self-contained task description.
3. Same topic as before? Resume that worker: Agent(resume="<its agent_id>"). New topic? Start a fresh one.
4. Write the result, each worker's agent_id and the next step into PROGRESS.md. That is the only file you edit.
```

**`builder.md`**
```markdown
---
name: builder
description: Writes or changes code for one small, clearly described step
tools: Read, Write, Edit, Grep, Glob, Bash, TodoList, Skill
---
${base_prompt}

## Your job: builder
The coordinator calls you, not the user.
- Do only the step you're given.
- Don't ask questions; if something is unclear, say so at the end.
- Your last message is your report: files changed, how you checked them, what's still open.
```

**`planner.md`**
```markdown
---
name: planner
description: Breaks a feature into small, ordered steps without changing anything
tools: Read, Grep, Glob, Skill
---
${base_prompt}

## Your job: planner
The coordinator calls you, not the user. Read the code and return a numbered list of small steps,
each with the files it touches and how to check it worked. Don't edit anything. Keep the report short.
```

**`tester.md`**
```markdown
---
name: tester
description: Runs the tests and reports exactly what fails, without fixing anything
tools: Read, Grep, Glob, Bash
---
${base_prompt}

## Your job: tester
The coordinator calls you, not the user. Run the tests named in AGENTS.md. Report which tests fail,
the error lines, and your best guess at the cause. Never edit files. Keep the report short.
```

**`reviewer.md`**
```markdown
---
name: reviewer
description: Reviews the current changes and either approves them or lists problems
tools: Read, Grep, Glob, Bash
---
${base_prompt}

## Your job: reviewer
The coordinator calls you, not the user. Look at the changes (git diff) and list problems,
most serious first. Don't edit files. End with exactly "APPROVED" or "CHANGES NEEDED".
```

**Run it:**
```sh
git switch -c my-feature
kimi --agent coordinator --yolo
```
Then, inside Kimi:
```
/goal Build feature X. Done when the tests in tests/x pass and the reviewer says APPROVED. If the same problem blocks you 3 times, stop and explain.
```

**Rules that matter:**
- Every file contains `${base_prompt}`.
- The coordinator has `subagents:` and **no** `tools:` list.
- Workers have no `Agent` tool.
- Restart Kimi after adding or changing agent files.
- After `/new`, restart with `--agent`.
- For different models per worker, configure `[secondary_model.models]` and say in coordinator.md which worker uses which alias (the `model` parameter of the Agent call).

### 31.5 Skill template (recipe)

`.kimi-code/skills/fix-tests/SKILL.md`:
```markdown
---
name: fix-tests
description: Fix failing tests one file at a time, tracking progress in PROGRESS.md
---
1. Read PROGRESS.md (create it if missing).
2. Run the test command from AGENTS.md and list the failing test files.
3. For each failing file, start a coder subagent: "Make <file> pass. Change nothing else."
4. After each one, write what changed and what's left in PROGRESS.md.
5. Run the tests again. Stop when everything passes.
```

Use it with `/skill:fix-tests`, or in a goal: `/goal Use the fix-tests skill until all tests pass; stop if blocked 3 times.`

### 31.6 Guard hook

Tested on 16 should-block and 10 should-allow commands. Malformed input fails open.

Save as `~/.kimi-code/hooks/bash-guard.mjs`:
```js
// PreToolUse guard for Kimi's Bash tool. Exit 2 blocks the call; stderr is the reason.
let raw = '';
process.stdin.on('data', (chunk) => (raw += chunk));
process.stdin.on('end', () => {
  let cmd = '';
  try { cmd = JSON.parse(raw).tool_input?.command ?? ''; } catch { process.exit(0); }
  const rules = [
    [/\bgit\s+push\b.*\s(--force|-f)(\s|$)/, 'force push'],
    [/\bgit\s+reset\s+--hard\b/, 'git reset --hard'],
    [/\bgit\s+clean\s+-\w*f/, 'git clean -f'],
    [/\b(curl|wget)\b[^|]*\|\s*(sudo\s+)?(ba|z)?sh\b/, 'piping a download into a shell'],
    [/\brm\s+-\w*[rR]\w*\s+(.*\s)?(\/|~|\$HOME|\.\.)(\/|\s|$)/, 'rm -r on /, ~, $HOME or ..'],
    [/(\.ssh\/|\.aws\/credentials|\.netrc|security\s+find-\w+-password)/, 'reading credentials'],
    [/(^|[\s;&|])(env|printenv)(\s*$|\s*[;&|>])|_API_KEY/, 'printing the environment or API keys'],
  ];
  for (const [re, why] of rules) {
    if (re.test(cmd)) {
      console.error(`Blocked by bash-guard (${why}). Ask the user to run this command.`);
      process.exit(2);
    }
  }
  process.exit(0);
});
```

Register it in `~/.kimi-code/config.toml`:
```toml
[[hooks]]
event = "PreToolUse"
matcher = "^Bash$"
command = "node ~/.kimi-code/hooks/bash-guard.mjs"
timeout = 10
```

Test it, then validate the config:
```sh
echo '{"tool_input":{"command":"git push --force"}}' | node ~/.kimi-code/hooks/bash-guard.mjs; echo "exit $?"   # expect exit 2
kimi doctor
```

### 31.7 Recommended config for this user

Change these keys and keep the rest:
```toml
default_model = "closerouter/openai-gpt-6-astra"   # or any alias the user trusts unsupervised
default_permission_mode = "yolo"

[permission]
dangerous_command_guard = true

[secondary_model]
default_model = "7api/glm-5.3-flash"
default_effort = "high"
[secondary_model.models]
"7api/glm-5.3-flash" = "Fast and cheap: searching, reading, summarizing, small edits."
"closerouter/openai-gpt-6-astra" = "Hard problems: tricky debugging, refactors, design."
```
Plus the hook from 31.6. CustomKIMI checks that `[secondary_model].default_effort` is supported by every pool model; `high` fits both.

### 31.8 MCP: Playwright, as used in the user's Claude Code

Add to `~/.kimi-code/mcp.json`, then `/new`:
```json
{ "mcpServers": { "playwright": { "command": "npx", "args": ["@playwright/mcp@latest"] } } }
```

---

## 32. The user's setup (snapshot 2026-10-18) `[user]`

### Kimi

- **Mode and model:** `default_model = "7api/glm-5.3-abliterated"` (refusal behavior removed), `default_permission_mode = "auto"` (Never Ask), `[permission] dangerous_command_guard = false`. **Risk:** nothing ever asks, and the guard wouldn't run in Never Ask anyway. Recommended changes are in 31.7. None were applied yet.
- **Thinking and subagents:**
  - `[thinking] enabled = true`, `effort = "high"`.
  - `[secondary_model] default_model = "closerouter/openai-gpt-6-astra"`, `default_effort = "high"`: no pool, so the agent can't choose.
  - `[experimental] notify_user = true`.
- **Missing pieces:** no web search (no Kimi login, no `[services.moonshot_search]`). No `~/.kimi-code/AGENTS.md`, `~/.agents/AGENTS.md`, Kimi `mcp.json`, or user skills/agents.
- **Plugins:** superpowers 7.0.0 (GitHub) and kimi-cu (official zip).
- **tui.toml:** `theme = "auto"`, notifications on (when unfocused), `[upgrade] auto_install = false`.
- **Keys:** the `kimi` wrapper exports both API keys into Kimi's environment, so the agent's Bash can read them.

### Claude Code

- No global CLAUDE.md, no custom agents, no hooks.
- One custom command `/sessions` (session cleanup).
- Plugins: frontend-design, superpowers, swift-lsp, clangd-lsp, ralph-loop.
- MCP: playwright.

### Migration notes

| Claude Code piece | Kimi equivalent |
|---|---|
| superpowers | Already works in Kimi |
| ralph-loop | `/goal` |
| playwright | 31.8 |
| frontend-design | Copy its SKILL.md into `~/.kimi-code/skills/` if the license allows |
| LSP plugins | No equivalent |
| `/sessions` | `/wipe-all-sessions` or `kimi session list --json` |

---

## 33. Claude Code vs Kimi

### 33.1 Lookup table (Claude Code → Kimi)

| Claude Code `[cc]` | Kimi | Status |
|---|---|---|
| `CLAUDE.md` | `AGENTS.md`, `.kimi-code/AGENTS.md` | partial (no CLAUDE.md, lower authority, once per session) |
| `~/.claude/CLAUDE.md` | `~/.kimi-code/AGENTS.md` + `~/.agents/AGENTS.md` | close |
| Nested CLAUDE.md auto-load | Path-only reminder, model must Read | partial |
| `CLAUDE.local.md` | none (git-ignored `.kimi-code/AGENTS.md`) | none |
| `@imports`, `.claude/rules`, auto memory, `/memory`, `#` | none | none |
| `/init` | `/init` (rewrites root AGENTS.md via a subagent) | close |
| Output styles, `--append-system-prompt` | `SYSTEM.md` with `${base_prompt}`, agent files | partial |
| settings.json (user/project/local/managed) | `config.toml` + `tui.toml` (user only) | partial |
| `/config` | `/settings`, `/update-config` | same |
| default / acceptEdits / plan / auto / bypassPermissions | manual (+in-repo edits) / — / Plan mode / yolo (rule-based) / auto + `-p` | partial |
| Shift-Tab cycles modes | `/permission`, `/yolo`, `/auto`; Shift-Tab = Plan only | partial |
| `permissions.allow/deny/ask` | `[[permission.rules]]` (ignored in 2.2.0) → `[tools] disabled` + hooks | broken |
| "Don't ask again" | Approve for this session | partial |
| `/sandbox` | none | none |
| Skills (`.claude/skills`) | `.kimi-code/skills`, `.agents/skills`, `extra_skill_dirs` | close |
| `.claude/commands` | flat skills or plugin `commands` | partial |
| Subagents (`.claude/agents`) | `.kimi-code/agents`, `.agents/agents`, `extra_agent_dirs` | close |
| `model:` in agent file | `[secondary_model]` pool | partial |
| Hooks (settings.json JSON) | `[[hooks]]` TOML; same event names; exit 2 | close (deny-only, fail-open) |
| Plugins (`.claude-plugin`) | `kimi.plugin.json` | partial |
| `.mcp.json`, `claude mcp add` | `.mcp.json` read + `.kimi-code/mcp.json`, `/mcp-config` | close |
| MCP tool search | `deferred` + `tool-select` flag | partial |
| `claude -c` / `-r` | `kimi -c` / `kimi -S` (`-r`) | same |
| `/clear` | `/new` (`/clear`) | same |
| `/rewind` (code + chat) | `/undo` (chat only) | partial |
| `--fork-session` | `/fork`, `kimi fork` | close |
| `/compact` | `/compact` | same |
| `/context`, `/cost` | `/usage`, `/status`, footer cost | close |
| TodoWrite | TodoList | same |
| WebFetch / WebSearch | FetchURL / WebSearch (needs Kimi login) | partial |
| Read PDF, NotebookEdit, LSP | none | none |
| Background tasks, Ctrl-B | same, plus `/tasks`, WaitFor | same |
| `/loop`, scheduled tasks | Cron tools (session-bound), `/goal` | partial |
| `claude -p`, json output | `kimi -p`, stream-json only, no stdin | partial |
| `--max-turns`, `--allowedTools`, `--system-prompt` | none | none |
| Agent SDK | private node SDK + `kimi web` REST/WS API | partial |
| IDE extensions | `kimi acp`, VS Code extension | close |
| Web / desktop / Remote Control | `kimi web`, `kimi app`, `kimi rc` (paid Kimi) | close |

### 33.2 What's better at what (balanced summary)

**Kimi is better at:**
- Model freedom and cost: any provider and mix, cheap models for helpers.
- Openness: MIT licensed and patchable (CustomKIMI).
- Built-in goal loops: queue, budgets, CI exit codes.
- Mass fan-out: AgentSwarm up to 128.
- Steering: explicit `Ctrl-S`.
- Video input.
- Per-spawn model choice from a pool.

**Claude Code is better at `[cc]`:**
- Instructions and memory: CLAUDE.md hierarchy, imports, rules, auto memory.
- Safety: classifier-based auto mode, rules that work, sandbox, persistent approvals.
- Undo: `/rewind` restores files.
- Hooks: allow, ask, deny, input changes, context injection.
- Scripted multi-agent workflows.
- Headless and SDK: json output, `--max-turns`, `--allowedTools`, stdin, public Agent SDK.
- MCP: tool search by default, prompts and resources.
- Tool breadth: PDF, notebooks, LSP.
- Web search out of the box, and a bigger plugin ecosystem.

**Tie:** the core loop and tools, skills, subagents, plan mode, sessions, background tasks, browser and phone access.

**Model quality** depends on the model, not the harness. Kimi can run Claude models too; the user has Claude Opus 5.5 on 7api. Kimi's prompts are tuned for Kimi's own models.

**Use Kimi for** cheap or mixed models, long goal loops and swarms, tinkering with the tool, and video. **Use Claude Code for** risky changes, big projects that need memory and rules, scripted workflows, and CI/SDK automation.

### 33.3 Reusing Claude Code assets in Kimi

| Asset | How |
|---|---|
| Skills | `extra_skill_dirs = ["~/.claude/skills", ".claude/skills"]`, symlink into `~/.agents/skills`, or `/import-from-cc-codex`. Claude-only frontmatter is ignored |
| CLAUDE.md | Symlink to AGENTS.md, or import into `.kimi-code/AGENTS.md` |
| Agents | `extra_agent_dirs = ["~/.claude/agents"]`. Fix tool names (WebFetch→FetchURL, TodoWrite→TodoList, Task→Agent) and add `${base_prompt}` |
| Commands | Rewrite as skills; positional args start at `$0` |
| Hooks | Rewrite as `[[hooks]]` TOML. Exit-2/deny scripts keep working; use `tool_input.path` instead of `file_path` |
| Status line | `[status_line] command`; the JSON fields differ |
| Project `.mcp.json` | Works in trusted folders. SSE needs `"transport": "sse"`; no `${VAR}` |
| `~/.claude.json` MCP | Copy entries into `~/.kimi-code/mcp.json` |
| Plugins | Need a `kimi.plugin.json` |
| Claude marketplace.json | Entries need `id` and a string `source` |
| Output styles | `SYSTEM.md` |

---

## 34. Learning path and status

1. **Safe and yours:** Ask When Needed, the guard hook, `kimi doctor`, `~/.kimi-code/AGENTS.md`.
2. **Project instructions:** AGENTS.md plus the CLAUDE.md symlink, `/init`, a nested AGENTS.md, `/new`.
3. **The daily loop:** `@`, `!`, queue vs `Ctrl-S`, `/undo` vs git, `/compact`, `/fork`, `kimi -c`.
4. **Models, effort, cost:** `/model`, `/effort`, the subagent pool, the footer cost.
5. **Delegation:** explore, plan and coder; `/btw`; `/tasks`; `/swarm`.
6. **Autonomy:** `/goal` with a finish line and budget, cron, `kimi -p` in a script.
7. **Extending:** your own skill, agent and hook; MCP via `/mcp-config`.
8. **The team:** coordinator plus workers in a goal loop (31.4).
9. **Other surfaces:** `kimi web`, `kimi vis`, ACP, Tower.

Status as of 2026-10-18: no lesson started. A visual field guide exists at https://claude.ai/artifact/Eo6ZibKhg5sHn1m2sAvSh3, and a simple human guide at `~/Desktop/CustomKIMI/KIMI_Guide.md`.

---

## 35. Where to verify in the source

Paths are relative to `~/Desktop/CustomKIMI/source/`. Prefer `rg` to search.

| Topic | Files |
|---|---|
| AGENTS.md loading | `packages/agent-core-v2/src/agent/profile/context.ts` |
| AGENTS.md reminders | `packages/agent-core-v2/src/agent/agentsMdReminder/agentsMdReminderService.ts` |
| System prompt & template vars | `packages/agent-core-v2/src/app/agentProfileCatalog/system.md`, `profile-shared.ts` |
| Prompt built once | `packages/agent-core-v2/src/agent/profile/profileService.ts` |
| `/init` | `packages/agent-core-v2/src/features/sessionInit/` |
| Permission policies | `packages/agent-core-v2/src/agent/permissionPolicy/permissionPolicyService.ts`, `policies/*.ts` |
| Permission rules config (unused) | `packages/agent-core-v2/src/agent/permissionRules/configSection.ts`, `permissionRulesService.ts` |
| Sensitive paths | `packages/agent-core-v2/src/tool/path-access.ts` |
| Bash tool | `packages/agent-core-v2/src/agent/tools/os/bash/` |
| Child env = full parent env | `packages/agent-core-v2/src/os/backends/node-local/hostProcessService.ts` (`buildEnv`) |
| Tool lists per profile | `packages/agent-core-v2/src/session/agentLifecycle/profile/profiles.ts` |
| Agent tool (resume/fork/model) | `packages/agent-core-v2/src/agent/tools/agent/agent.ts`, `agentTool.ts` |
| Subagent spawn & allowlist | `packages/agent-core-v2/src/session/subagent/subagentService.ts`, `configSection.ts` |
| Agent files | `packages/agent-core-v2/src/workspace/workspaceAgentProfileLoader/internal/` |
| Plan mode | `packages/agent-core-v2/src/features/plan/planService.ts` |
| Goal mode | `packages/agent-core-v2/src/features/goal/`, `apps/kimi-code/src/tui/commands/goal.ts` |
| Compaction | `packages/agent-core-v2/src/agent/fullCompaction/` |
| Undo / file history | `packages/agent-core-v2/src/agent/undo/`, `src/features/fileHistory/` |
| Skills | `packages/agent-core-v2/src/features/skill/catalog/` |
| Hooks | `packages/agent-core-v2/src/features/externalHooks/` |
| Plugins | `packages/agent-core-v2/src/app/plugin/` |
| MCP | `packages/agent-core-v2/src/app/mcpConfig/configLoader.ts`, `src/mcpCore/` |
| Trust | `packages/agent-core-v2/src/workspace/workspaceTrust/`, `workspaceMcpConfig/` |
| Config validation | `packages/agent-core-v2/src/app/config/configService.ts` |
| Config schema manifest | `packages/agent-core-v2/docs/config-manifest.toml` |
| Flags | `packages/agent-core-v2/src/app/flag/`, `src/**/flag.ts` |
| CLI flags & print mode | `apps/kimi-code/src/cli/commands.ts`, `options.ts`, `v2/run-v2-print.ts`, `prompt-render.ts` |
| Slash commands | `apps/kimi-code/src/tui/commands/registry.ts`, `dispatch.ts`, `resolve.ts` |
| Keys | `apps/kimi-code/src/tui/controllers/editor-keyboard.ts`, `components/editor/custom-editor.ts` |
| Status line / tui.toml | `apps/kimi-code/src/tui/utils/status-line-command.ts`, `src/tui/config.ts` |
| CustomKIMI patches | `~/Desktop/CustomKIMI/custom/FEATURES.md`, `custom/patches/` |
| Official docs | `docs/en/**` (they lag the code) |

---

## 36. Not verified or open questions

- **Session approvals and subagents:** do "Approve for this session" decisions propagate to subagents? The docs say yes; the code research suggested approvals are stored per agent. Untested.
- **New agent files without a restart:** whether file watchers pick them up is unverified. Restarting Kimi is the safe advice.
- **`/swarm` in manual mode:** it prompts to switch modes `[docs]`.
- **Not studied in depth:** the VS Code extension, the server API details, and the ACP capability matrix.
- **Unknown model capabilities:** pricing and capabilities of the user's third-party models (GPT-6 Astra, GLM-5.3, etc.) are unknown to this research; don't make claims about which is "better".
