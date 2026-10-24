# Kimi Code Guide

A guide for a Claude Code user. It covers Kimi Code 2.2.0 as built by CustomKIMI. Everything here was checked against the Kimi source in `source/` on 18 October 2026. Where Kimi's own docs disagree with the code, this guide follows the code. Rechecked for Kimi Code 2.3.1 on 24 October 2026: the facts below that contradict Kimi's docs still hold. One thing changed: since 2.3.0, turning off `dangerous_command_guard` also stops the prompts for sensitive files and `.git/**` paths.

- **Part 1** explains how to use Kimi, in plain words.
- **Part 2** is the full reference: everything we found.

A visual version with a searchable Claude Code → Kimi table: https://claude.ai/artifact/Eo6ZibKhg5sHn1m2sAvSh3

---

# Part 1: How to use Kimi

## 1. The 30-second version

- Kimi works like Claude Code: same kind of agent, almost the same tool names.
- Your rules file is **`AGENTS.md`**, not `CLAUDE.md`. Kimi never reads `CLAUDE.md`.
- Kimi has **no memory**. To make it "remember", use AGENTS.md, a `PROGRESS.md` file, or resume the old session.
- Permission mode names: `manual` = **Always Ask** (default), `yolo` = **Ask When Needed**, `auto` = **Never Ask**. `auto` means it never asks you anything.
- **`/undo` does not undo file changes.** Git is your only undo for code.
- `/goal` keeps Kimi working until a finish line is reached. Subagents do work in their own chat, so yours stays small.
- Allow/deny rules in `config.toml` do **nothing** in 2.2.0. Use hooks for hard rules.

## 2. The pieces (a company)

| Company | In Kimi | What it is |
|---|---|---|
| Rulebook everyone reads | `AGENTS.md` | Project rules: how to build and test, what never to touch |
| Job description per worker | agent file in `.kimi-code/agents/` | Who that agent is, what tools it may use, how it works |
| Whiteboard | `PROGRESS.md` | What's done and what's next. This is the memory |
| Recipes | skills in `.kimi-code/skills/` | Saved workflows you can replay with `/skill:name` |
| Engine | `/goal` | Keeps working, turn after turn, until done |
| Security guard | hooks in `config.toml` | Hard rules the agent can't break |

**Soft rules vs hard rules.** AGENTS.md and skills are *soft*: the model usually follows them, but can drift. Hooks are *hard*: they always run. Anything that must never happen goes in a hook.

## 3. Set up once (for all projects)

Do these once. Lesson 1 of the learning path covers them.

1. **Safer defaults.** Edit `~/.kimi-code/config.toml`:
   ```toml
   default_permission_mode = "yolo"     # Ask When Needed; use /auto on purpose only
   [permission]
   dangerous_command_guard = true
   ```
2. **Install the guard hook** (section 9). It blocks force-push, `git reset --hard`, `curl | sh`, deleting home, reading keys and printing your API keys. It works in every mode.
3. **Your personal rules** go in `~/.kimi-code/AGENTS.md`: language, how you like commits, your habits.
4. **A model pool for helpers**, so subagents can use cheaper models (section 10).
5. After every config edit, run `kimi doctor`. If one entry in a section is wrong, Kimi silently drops the **whole** section.

## 4. Set up each project (checklist)

Run these in the project root (the folder that has `.git`):

```sh
# 1. Rules file. If the project already has a CLAUDE.md:
git mv CLAUDE.md AGENTS.md && ln -s AGENTS.md CLAUDE.md
# ...otherwise just create AGENTS.md (or run /init inside Kimi for a first draft)

# 2. Memory file
printf '# Progress\n\n## Done\n\n## Next\n\n## Problems\n' > PROGRESS.md

# 3. Folders for your own agents and skills (only if you need them)
mkdir -p .kimi-code/agents .kimi-code/skills

# 4. Keep machine-specific settings out of git
echo ".kimi-code/local.toml" >> .gitignore
```

What to write in `AGENTS.md`, as short facts:
- How to build, test and lint (the exact commands).
- A map of the folders.
- Code style and conventions.
- What never to touch.
- One line: "Read PROGRESS.md before starting; update it after every step."

Optional per project:
- `.kimi-code/mcp.json` for project MCP servers. A Claude Code `.mcp.json` at the repo root is read too.
- An `AGENTS.md` inside a subfolder holds rules only for that folder.

**After editing any AGENTS.md, type `/new`.** Kimi reads it only when a session starts.

## 5. Daily use

| You want to… | Do this |
|---|---|
| Start | `kimi` (in the project folder) |
| Continue the last session | `kimi -c` |
| Pick an old session | `kimi -S` or `/sessions` |
| Point at a file | type `@` and pick it |
| Run a shell command yourself | type `!` in an empty prompt |
| Plan first, then act | `Shift-Tab` (Plan mode) |
| Change mode | `/permission`, `/yolo`, `/auto` |
| Change model or effort | `/model`, `/effort` |
| Add something while it works | type it and press `Ctrl-S` (Enter only queues it) |
| Stop it | `Esc` |
| Ask a side question | `/btw your question` |
| Shrink the chat | `/compact keep the API decisions` |
| See context use and cost | `/usage` and your footer |
| Copy the session to try another idea | `/fork` |
| Fresh start | `/new` |

## 6. Memory: how Kimi "remembers"

Kimi has no memory feature: no auto memory, no `/memory`, no `#`. It only knows:

1. **AGENTS.md files**, read at the start of each session.
2. **The current session.** Resume it with `kimi -c` or `/sessions`.
3. **Files you tell it to read.** Use `PROGRESS.md` for state and progress, and maybe `DECISIONS.md` for why you chose things.

Habit: where you'd press `#` in Claude Code, say **"add this to AGENTS.md"**.

## 7. Helpers and your team (subagents)

**Built in, no files needed:**
- `coder` (default): reads, edits, runs commands.
- `explore`: reads and searches.
- `plan`: reads only, designs.

Use them by asking: "use explore to find where login is handled".

**Why use them:** a helper works in its **own empty chat**. Only its final report comes back, so your main chat stays small.

**Your own agents:** one Markdown file per agent.
- `my-project/.kimi-code/agents/` is for that project only.
- `~/.kimi-code/agents/` is for all your projects.

You create these folders yourself. Kimi finds the files when a session starts, so **restart Kimi** after adding one.

When an agent is called, Kimi turns the text under the `---` into its instructions. The task message becomes its first message. `${base_prompt}` is filled in with Kimi's normal instructions **plus your AGENTS.md**.

### Your coordinator team

```
my-project/
├── AGENTS.md                ← rulebook (everyone)
├── PROGRESS.md              ← whiteboard
└── .kimi-code/agents/
    ├── coordinator.md       ← boss: decides and delegates, never codes
    ├── planner.md
    ├── builder.md
    ├── tester.md
    └── reviewer.md
```

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
3. Same topic as before? Resume that worker with its agent_id. New topic? Start a fresh one.
4. Write the result, each worker's agent_id and the next step into PROGRESS.md. That is the only file you edit.
```

**`builder.md`** (the other workers follow this pattern)
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

### Rules for agent files

- `description` is required. It is how the coordinator decides whom to call.
- `name` is lowercase with dashes (`test-runner`). It defaults to the file name.
- Tool names are case-sensitive: `Read`, not `read`.
- **Put `${base_prompt}` in every file.** Without it, the agent doesn't see AGENTS.md.
- **Keep `Agent` out of workers' `tools`**, so workers can't hire their own helpers.
- **Never give the coordinator a `tools:` list.** It would lose the goal tools and the loop could never finish. Use `disallowedTools`.
- **Workers don't get Kimi's built-in "you are a subagent" text.** Say in each file that its last message is the report.
- **A `model:` line in an agent file is ignored.** The coordinator picks models from the model pool.

### Fresh worker or the same one again?

| You want | The coordinator calls | The worker remembers |
|---|---|---|
| A clean worker | `Agent(subagent_type="tester", prompt=…)` | Nothing but this task |
| The same worker again | `Agent(resume="agent-3", prompt=…)` | Everything it did before, even after a Kimi restart |
| A copy of the coordinator itself | `Agent(fork=true, …)` (experimental flag `subagent_fork`) | The coordinator's whole chat. This copies the boss, not a worker |

- Every call returns `agent_id: agent-…`. Have the coordinator write the IDs into `PROGRESS.md`, because its own chat gets compressed.
- **Use fresh for new, unrelated work.** It's cleaner and cheaper.
- **Use resume for follow-ups** that need what the worker learned, like "fix the bug you found".

## 8. Goal loops

```sh
git switch -c my-feature              # always loop on a branch
kimi --agent coordinator --yolo       # coordinator as boss, Ask When Needed mode
```
Inside Kimi:
```
/goal Build feature X. Done when the tests in tests/x pass and the reviewer says APPROVED. If the same problem blocks you 3 times, stop and explain.
```

| Command | What it does |
|---|---|
| `/goal` or `/goal status` | Show progress: time, turns, tokens |
| `/goal pause` / `/goal resume` | Pause or continue |
| `/goal cancel` | Stop for good |
| `/goal replace <new goal>` | Change the goal |
| `/goal next <goal>` | Queue the next goal; it starts when this one completes |
| `/goal next manage` | Reorder, edit or delete queued goals |
| `/write-goal` | Built-in helper that words a good goal for you |

How it works:
- After each turn, Kimi sends a hidden "continue" until the agent marks the goal **complete** or **blocked**.
- It may only call itself blocked after hitting the same blocker 3 turns in a row.
- **Limits:** write them into the goal ("stop after 30 turns" or "spend at most 1 hour"). The agent then sets a budget, and running out blocks the goal.
- **Good goals:** a checkable finish line plus a stop rule. Bad: "find all bugs".
- **For scripts:** `kimi -p "/goal …"` exits with 0 when complete, 3 when blocked, 6 when paused.
- `/new` drops back to the normal agent. Restart with `kimi --agent coordinator`.

## 9. Staying safe

- There is **no sandbox**. Shell commands run as you, with your full environment, including the API keys your `kimi` shell function exports.
- The file tools refuse `.env` files and SSH keys. `Bash` does not.
- **Always Ask** still auto-approves edits inside a git repo. **Never Ask** (`auto`, `--auto`, every `kimi -p`) approves everything, and the built-in guard doesn't even run.
- Commit or stash before long runs. Run loops on a branch or `git worktree`.

**The guard hook.** Save this as `~/.kimi-code/hooks/bash-guard.mjs`. It was tested on 16 commands that must be blocked and 10 that must not:
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

## 10. Saving context and money

- **Use subagents.** Their reading and trial and error stay out of your chat.
- **One session per task.** `/new` between unrelated work.
- **`/compact <what to keep>`** at natural breaks. Kimi also compacts by itself at 85% full.
- **`PROGRESS.md`** survives compaction and new sessions. Chat history doesn't.
- **Ask workers for short reports.** Every report lands in the coordinator's chat.
- **Set effort at the start.** `/effort` mid-session throws away the prompt cache. `Alt-S` in the picker applies it to this session only.
- **Cheap models for helpers** (main agent keeps its own model):
  ```toml
  [secondary_model]
  default_model = "7api/glm-5.3-flash"
  default_effort = "high"
  [secondary_model.models]
  "7api/glm-5.3-flash" = "Fast and cheap: searching, reading, summarizing, small edits."
  "closerouter/openai-gpt-6-astra" = "Hard problems: tricky debugging, refactors, design."
  ```
  The main agent then picks a model per helper. You can also say in the coordinator's file which worker gets which model.

---

# Part 2: Everything we found (reference)

## A. Where files live

```
~/.kimi-code/                  (moves with KIMI_CODE_HOME)
├── config.toml     providers, models, permissions, hooks, thinking, subagent pool
├── tui.toml        theme, editor, notifications, status line, auto-update, mermaid
├── AGENTS.md       your global rules
├── SYSTEM.md       replaces the main system prompt (use ${base_prompt} to wrap it)
├── mcp.json        user MCP servers
├── skills/         user skills
├── agents/         user agents
├── themes/         custom TUI themes
├── hooks/          (your own scripts, e.g. bash-guard.mjs)
├── plugins/        installed.json + managed/<id>/
├── sessions/       <workDirKey>/<sessionId>/  (state.json, agents/*/wire.jsonl, plans/, tasks/, cron/)
├── credentials/    Kimi OAuth + MCP OAuth tokens
├── workspace-trust/
├── file-history/   copies before Write/Edit (only used for web/desktop diff views)
└── logs/  user-history/  bin/rg  bin/fd

~/.agents/                     (shared with other agent tools; stays in the real home)
├── AGENTS.md
├── skills/
└── agents/

<repo>/   (project root = nearest folder with .git)
├── AGENTS.md           (agents.md also works)
├── .mcp.json           Claude Code's MCP file; read too (trusted folders only)
├── .kimi-code/
│   ├── AGENTS.md       loads together with the root one
│   ├── skills/  agents/  mcp.json
│   └── local.toml      extra workspace dirs from /add-dir (gitignore it)
└── .agents/skills/  .agents/agents/     (but .agents/AGENTS.md is NOT read)
```

## B. AGENTS.md: exact behavior

- **Load order:** `~/.kimi-code/AGENTS.md`, then `~/.agents/AGENTS.md`, then each folder from the git root down to the working directory. In each folder it reads `.kimi-code/AGENTS.md` and then `AGENTS.md`.
  - All files are combined; none overrides another.
  - Nothing above the repo root is read. Outside git, only the working directory is read.
- **`CLAUDE.md` is never read.** Symlink it to AGENTS.md (the Kimi repo itself does this).
- **Subfolder AGENTS.md files are not loaded at start.** When the agent touches a folder, Kimi sends a note naming the file, and the agent must read it itself.
- **Size:** over 32 KiB only gives a warning; nothing is cut.
- **Not supported:** `@file` imports, path-glob rules files, and memory of any kind.
- **Authority:** it sits in the system prompt as "project-supplied reference data". It can't override the system prompt or what you say in chat. Write it as facts.
- **When it is read:** once per session.
  - Edits mid-session only trigger a "changed on disk" note.
  - `/reload` does **not** refresh it; `/new` does.
  - Compaction drops those notes.
- **`/init`:** a coder subagent explores the repo and rewrites the root AGENTS.md, keeping what's still accurate. It uses your model and permission mode.
- **Also in the system prompt:** OS, shell, working directory, a 2-level folder listing, skills, and plugin instructions.
- **Not in the system prompt:**
  - The date, which arrives as a reminder.
  - Git status. Only `explore` gets it.
  - The model's name.
- **No `--system-prompt` or output styles.** Use `~/.kimi-code/SYSTEM.md` or an agent file.
  - Template variables: `${base_prompt}`, `${agents_md}`, `${cwd}`, `${cwd_listing}`, `${os}`, `${shell}`, `${skills}`, `${skills_section}`, `${plugin_sections}`, `${additional_dirs_info}`.
  - The documented `${now}` no longer exists.

## C. Permission modes: exact behavior

| Mode | Runs without asking | Still asks |
|---|---|---|
| **Always Ask** (`manual`, default) | Read/Grep/Glob, web tools, Agent, AgentSwarm, Skill, todos, plan and goal tools, **Write/Edit inside a git repo** | Every Bash command, MCP tools, writes outside the repo, `.git/**` (only while the guard is on, since 2.3.0), dangerous commands |
| **Ask When Needed** (`yolo`, `/yolo`, `-y`) | Everything else too | Dangerous commands and `.git/**` (both only if the guard is on, since 2.3.0), plan approval |
| **Never Ask** (`auto`, `/auto`, `--auto`, every `kimi -p`) | Everything, including its own plan approval | Nothing. `AskUserQuestion` is disabled |

- **Switching modes:**
  - `Shift-Tab` only toggles Plan mode. Use `/permission`, `/yolo` or `/auto` for permission modes.
  - There is no `--manual` flag.
  - A resumed session keeps its saved mode unless you pass `--yolo` or `--auto`.
- **Dangerous-command guard:**
  - **What it catches** (by parsing the command): `rm -rf` outside `/tmp`, `shutdown`, `reboot`, `halt`, `poweroff`, `mkfs`, `wipefs`, `dd` to a disk, `init 0/6`, `systemctl poweroff/reboot`. It also looks inside `sudo`, `env`, `nohup`, `eval` and nested `sh -c`.
  - **What it misses:** `git push --force`, `git reset --hard`, `curl | sh`, `chmod 777`.
  - **Where it runs:** Always Ask and Ask When Needed only, not Never Ask or `-p`. It is on by default.
- **`[[permission.rules]]` are parsed but never applied in 2.2.0.** Use `[tools] disabled` (a global tool blocklist that does work) and hooks.
- **Approval options:** approve once, approve for this session, reject, or reject with feedback.
  - There is no "always". Session approvals match the exact command or path.
- **File tools always refuse:** `.env*` (except example/sample/template), `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `credentials*`, `.aws/credentials`.
  - They don't cover `.netrc` or `*.pem`, and Bash can read anything.
- **Folder trust only gates the project's MCP servers.** The TUI asks you to trust the folder or exit. `KIMI_CODE_TRUST_WORKSPACE=1` trusts it for headless runs.
- **Plan mode:** Write/Edit can only touch the plan file, and Cron and TaskStop are blocked. **Bash still runs under the current mode.**

## D. Tools

| Tool | Notes |
|---|---|
| `Read` | Text only, up to 100k characters by default and 500k max (`[read]`). No PDF or Office files |
| `ReadMediaFile` | Images and video up to 100 MB. Only exists if the model accepts images/video |
| `Write` | Overwrite or append |
| `Edit` | Exact string replace, `replace_all`. No multi-edit. "Read first" is a prompt rule, not enforced |
| `Grep` / `Glob` | ripgrep. Grep's `glob` matches absolute paths, so `src/**/*.ts` finds nothing; use `**/src/**/*.ts` |
| `Bash` | Always `/bin/bash -c`, fresh shell each call, no zsh aliases. Timeout in **seconds**: 60 default, 300 max in the foreground. A foreground timeout moves the command to the background |
| `WebSearch` | Only after `/login` to Kimi, or with `[services.moonshot_search]` configured. **You have neither** |
| `FetchURL` | Works without login (local fetch). Max 10 MiB; refuses private and loopback addresses |
| `TodoList` | Like Claude Code's TodoWrite. `Ctrl-T` expands it |
| `AskUserQuestion` | 1–4 questions. Can run in the background |
| `Agent` / `AgentSwarm` | Subagents. AgentSwarm runs one template over 2–128 items: 5 at once, then one more every 0.7 s |
| `TaskList`, `TaskOutput`, `TaskStop`, `WaitFor` | Background tasks. WaitFor waits at most 90 s |
| `CronCreate`, `CronList`, `CronDelete` | Scheduled prompts inside one session. Up to 50; recurring ones expire after 7 days |
| `EnterPlanMode`, `ExitPlanMode`, goal tools, `Skill`, `NotifyUser` | Plan mode, `/goal`, skills, and the Updates panel |

- **Output size:** tool output over 50k characters is saved to a file, and the model sees the first 4 KB and the last 1 KB.
- **Parallel or not:** Read, Grep, Glob, web tools and Agent run in parallel. Several Bash calls in one reply run one after another.
- **Repeat breaker:** the same call repeated 12 times stops the turn. `KIMI_CODE_REPEAT_BREAKER=0` turns this off.
- **Not available:** PDF reading, notebook editing, LSP.

## E. Subagents

- **Built-in agents:**
  - `coder` has all main tools except Agent, AgentSwarm, AskUserQuestion, goal and Tower tools.
  - `explore` is read-only because its prompt says so; it does have Bash.
  - `plan` has no shell.
- Built-in subagents can't start more subagents. A custom agent can, but only with a `subagents:` list.
- **Which model a subagent uses:** the caller's, unless `[secondary_model]` is set.
  - With a pool, the `Agent` tool gets a `model` option. `"primary"` means the caller's model.
  - `force = true` pins every subagent to `default_model`.
- **Background subagents:** `run_in_background: true`. The result arrives later as a message. Timeout is 2 hours (`[subagent] timeout_ms`), with no limit in `-p`.
- **Custom agent files:**
  - **Locations:** `.kimi-code/agents/`, `.agents/agents/`, `~/.kimi-code/agents/`, `~/.agents/agents/`, `extra_agent_dirs`, plugins.
  - **Priority when names clash:** `--agent-file`, then project, then extra dirs, then user, then plugin, then built-in.
  - **Fields:** `name`, `description` (required), `whenToUse`, `tools`, `disallowedTools`, `subagents`, `override`.
  - **The body is the whole system prompt.**
- **Coordinator team list:**
  - With an explicit `subagents:` list, the coordinator can call exactly those agents.
  - Without one, any worker that has the `Agent` tool is silently hidden from it.
- **Main agent for a session:** `--agent <name>` or `--agent-file <file>`, for new sessions only. `/new` returns to the default agent.

## F. Goal mode

- `/goal <objective>` takes up to 4000 characters.
- The loop continues automatically until the agent marks the goal complete or blocked.
- If an objective starts with a subcommand word, put `--` first: `/goal -- cancel the old note…`.
- **Permission mode:** in Always Ask and Ask When Needed, `/goal` first offers to switch mode. In Always Ask, a goal can stall waiting for approvals.
- **Time:** it only counts while the goal is active and the session is open.
- **Forks:** a fork doesn't copy the goal.
- **Tower:** goal and Tower can't run together.
- **Footer:** the `goal` slot shows something like `[goal ● active · 4m · 7 turns]`.

## G. Context and compaction

- **When it compacts automatically:** at 85% of the model's input limit, or when usage plus a 50k-token reserve reaches the limit.
  - Tune it with `[loop_control] compaction_trigger_ratio` (0.5–0.99) and `reserved_context_size`.
- **`/compact [what to keep]`** only works when idle. `Esc` cancels it.
- **What survives:** your own messages (up to 20k tokens: the first 2k plus the most recent), a summary, the todo list, a pointer to the session log, and the list of running background tasks.
- Compaction uses the agent's own model. `[secondary_model]` is only for subagents.

## H. Undo and fork

- **`/undo [n]`, or `Esc Esc` while idle**, rewinds the conversation, todos and plan state.
  - It can't go back past the last compaction.
  - **Files are never restored.**
- **`/fork` or `kimi fork [id]`** copies the session. You stay in the original, and a `kimi --resume <id>` command for the copy goes to your clipboard.

## I. Skills

- **Folders:** `~/.kimi-code/skills/`, `~/.agents/skills/`, `.kimi-code/skills/`, `.agents/skills/`, `extra_skill_dirs`, plugins.
  - `.claude/skills` is **not** read, but `extra_skill_dirs = ["~/.claude/skills"]` reuses those skills where they are.
  - **Priority when names clash:** project, then user, then extra, then plugin, then built-in.
- **Format:** `<name>/SKILL.md` (needs `name` and `description`), or a single `<name>.md`.
- **Frontmatter Kimi reads:** `name`, `description`, `type` (prompt, inline, flow), `whenToUse`, `disableModelInvocation`, `arguments`.
- **Frontmatter Kimi ignores:** `allowed-tools`, `model`, `context: fork`, `agent`, and `` !`cmd` `` injection.
- **Placeholders:** `$ARGUMENTS`, `$0`, `$1`… (they start at **0**), `$name`, `${KIMI_SKILL_DIR}`, `${KIMI_SESSION_ID}`.
  - If there are no placeholders, your text is appended as `ARGUMENTS: …`.
  - `$1`-style text is **always** replaced, so `awk '{print $1}'` breaks inside a skill.
- **How to run one:**
  - `/skill:name args`, or `/name` if no built-in command has that name.
  - `/name` mid-sentence; several at once work.
  - The model calls them on its own via the `Skill` tool, up to 3 levels deep.
- **Things to watch:**
  - The skill list is fixed when a session starts.
  - `kimi -p "/skill:x"` sends the text literally instead of running the skill.
- **Built-in skills:** `/mcp-config`, `/import-from-cc-codex`, `/update-config`, `/custom-theme`, `/write-goal`, `/check-kimi-code-docs`, `/sub-skill`.

## J. Hooks

- **Where:** `[[hooks]]` in `~/.kimi-code/config.toml`, or in a plugin's manifest. There are no project-level hooks.
- **Fields:** exactly `event`, `matcher`, `command`, `timeout` (1–600 s, default 30). **One invalid entry disables every hook.**
- **The 20 events:**
  - Tools: PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, PermissionResult.
  - Prompts and turns: UserPromptSubmit, UserPromptQueued, TurnStarted, Stop, StopFailure, Interrupt.
  - Sessions: SessionStart, SessionEnd, SessionHeartbeat.
  - Subagents and tasks: SubagentStart, SubagentStop, TaskStarted.
  - Compaction: PreCompact, PostCompact.
  - Notification (background-task status changes).
- **Which events can block:** PreToolUse, UserPromptSubmit and Stop. A Stop block makes the model continue, at most once per turn.
- **Blocking:** exit code 2, with stderr as the reason, or JSON `{"hookSpecificOutput":{"permissionDecision":"deny"}}`.
  - "allow" and "ask" decisions are ignored.
  - **Hooks fail open:** a crash or timeout lets the call through.
- **Matcher:** an unanchored, case-sensitive regex. Write `^Bash$`; a bare `*` never fires.
- **Input on stdin (JSON):**
  - Every event: `hook_event_name`, `session_id`, `cwd`, `session_title`.
  - Tool events: `tool_name`, `tool_input` (Write and Edit use **`path`**, not `file_path`) and `tool_output`.
- **Output:**
  - `UserPromptSubmit` stdout goes into the context.
  - `SessionStart` output is thrown away.
- **Not supported:** `additionalContext`, `updatedInput`, `$CLAUDE_PROJECT_DIR`.

## K. Plugins

- **Manifest:** `kimi.plugin.json` or `.kimi-plugin/plugin.json`. Claude `.claude-plugin/` manifests are ignored.
- **A plugin can add:** skills, agents, commands (`/plugin:cmd`), MCP servers, hooks, a session-start skill, and system-prompt text.
- **Install** with `/plugins install <GitHub URL | zip URL | folder>`. There's no `kimi plugin` shell command.
  - Changes apply after `/reload` or `/new`.
  - To update, reinstall.
  - Remove only deletes the install record; the files stay.
- **Trust labels** (official, curated, third-party) are labels plus a confirmation prompt. They are not a sandbox.
- **Your plugins:**
  - **superpowers 7.0.0** works through its own Kimi manifest: 15 skills such as `/skill:brainstorming`, with `using-superpowers` loaded at session start.
  - **kimi-cu** is Kimi's official macOS computer-use plugin. Its tools are `mcp__plugin-kimi-cu_mac__*`, and it needs Accessibility and Screen Recording permission.

## L. MCP

- **Files, read in this order (later wins):** `~/.kimi-code/mcp.json`, then `<git root>/.mcp.json`, then `<cwd>/.kimi-code/mcp.json`, then plugin servers.
  - Project files load only in trusted folders.
  - `~/.claude.json` and Claude Desktop configs are not read.
- **Server format:**
  - Local servers use `command`, `args`, `env`, `cwd`.
  - Remote servers use `url`, `headers`, `bearerTokenEnvVar`.
  - SSE servers need `"transport": "sse"`. Claude's `"type"` key is ignored.
  - Options: `enabled`, `enabledTools`, `disabledTools`, `startupTimeoutMs`, `toolTimeoutMs`, and `deferred` (experimental).
- **Commands:** `/mcp-config` adds, edits, or logs in to a server (`/mcp-config login <name>`). `/mcp` shows status.
- **Gotchas:**
  - New servers join new sessions only.
  - One invalid server empties its whole file.
  - No `${VAR}` expansion.
  - Kimi uses MCP tools only, not prompts or resources.
  - Every MCP call asks in Always Ask mode.
- **Your Playwright server from Claude Code**, for `~/.kimi-code/mcp.json`:
  ```json
  { "mcpServers": { "playwright": { "command": "npx", "args": ["@playwright/mcp@latest"] } } }
  ```

## M. Commands

**Sessions:** `/new` (`/clear`), `/sessions` (`/resume`), `/fork`, `/undo [n]`, `/compact [hint]`, `/title` (`/rename`), `/usage`, `/status`, `/export-md`, `/export-debug-zip`, `/add-dir`, `/copy`, `/wipe-all-sessions confirm` (your patch).

**Modes and models:** `/model`, `/effort` (`/thinking`), `/secondary-model`, `/plan [on|off|clear]`, `/permission`, `/yolo`, `/auto`, `/goal …`, `/swarm …`, `/btw …`, `/tower …` (experimental).

**Setup:** `/init`, `/settings` (`/config`), `/update-config`, `/reload`, `/reload-tui`, `/mcp`, `/mcp-config`, `/plugins`, `/provider`, `/experiments`, `/theme`, `/custom-theme`, `/editor`, `/import-from-cc-codex`, `/check-kimi-code-docs`, `/login`, `/logout`, `/web`, `/remote-control` (`/rc`), `/tasks`, `/help`, `/exit`.

**From the shell:**
- **Sessions:** `kimi`, `kimi -c`, `kimi -S [id]`, `kimi -m <alias>`, `kimi --plan`, `kimi -y`, `kimi --auto`, `kimi --agent <name>`, `kimi --agent-file <f>`, `kimi --add-dir <d>`.
- **Headless:** `kimi -p "…" [--output-format stream-json]`.
- **Session tools:** `kimi session list --json`, `kimi fork [id]`, `kimi export [id]`.
- **Other:** `kimi web`, `kimi rc`, `kimi vis`, `kimi acp`, `kimi doctor`, `kimi provider …`, `kimi app`, `kimi login`.
- **Never run `kimi upgrade`** (see U).

**Keys:**

| Key | Does |
|---|---|
| `Shift-Tab` | Plan mode on/off |
| `Ctrl-S` | Push your text into the running turn now. `Enter` while busy only queues it, and `↑` edits the queued message |
| `Esc` | Stop the turn |
| `Esc Esc` (idle) | Open the undo picker |
| `Ctrl-C` | Interrupt. Twice while idle exits |
| `Ctrl-D` | Twice on an empty prompt exits |
| `Ctrl-B` | Send the running command to the background |
| `Ctrl-O` | Expand or collapse tool output |
| `Ctrl-T` | Expand the todo list |
| `Ctrl-G` | Write the prompt in your editor |
| `Ctrl-V` | Paste an image or video, or a file copied in Finder |
| `Ctrl-N` | Focus the Updates panel |
| `Shift-Enter` / `Ctrl-J` | New line |
| `@` / `!` | File picker / shell mode |
| `1`–`9`, `Ctrl-E` | Pick an approval option / expand the diff |

There is no `Ctrl-R` history search, and keys can't be remapped.

## N. Headless (`kimi -p`)

- **Always runs in Never Ask mode.**
- **Stdin is ignored.** Use `kimi -p "$(cat task.md)"`. A bare `kimi "prompt"` is an error.
- **Output:**
  - `--output-format stream-json` prints one JSON message per line: assistant messages, tool results, and meta lines such as the version and a resume hint.
  - Thinking is never printed.
- **Exit codes:** 0 ok, 1 error, 3 goal blocked, 6 goal paused, 130/143 interrupted.
- **Background tasks:** it keeps running until they finish (`print_background_mode = "steer"` by default).
- **Missing options:** no `--max-turns`, `--allowedTools`, `--system-prompt` or `--mcp-config`.
  - Use config, `KIMI_LOOP_MAX_STEPS_PER_TURN`, `--agent-file`, or a separate `KIMI_CODE_HOME`.
- **Project MCP servers are skipped** unless the folder is trusted or `KIMI_CODE_TRUST_WORKSPACE=1` is set.

## O. Other surfaces

- **`kimi web` / `/web`:** browser UI on `127.0.0.1:58627`, using the same sessions.
  - `--host` opens it to your LAN.
  - It has diffs, click-to-approve, a task panel and search across sessions.
- **`kimi rc`:** remote control from your phone through Kimi's relay. Needs a paid Kimi account.
- **`kimi vis`:** session visualizer in the browser.
- **`kimi acp`:** Zed, JetBrains and Paseo integration.
- **Video input:** `Ctrl-V` a screen recording. Needs a model with `video_in`.
- **Scheduled prompts:** "remind me at 14:30 to…" or "every hour check…". They run inside the session only; `KIMI_DISABLE_CRON=1` turns them off.
- **Tower (experimental):** the main agent becomes a control tower with workers and reviewers, each in its own git worktree under `.tower/worktrees/`.

## P. Experimental flags

Turn them on with `/experiments`, `[experimental] <id> = true`, or `KIMI_CODE_EXPERIMENTAL_<NAME>=1`. `KIMI_CODE_EXPERIMENTAL_FLAG=1` turns them all on.

| Flag | Default | What it does |
|---|---|---|
| `wait_for` | on | `WaitFor` tool |
| `notify_user` | off (**on for you**) | Updates panel and `NotifyUser` |
| `subagent_fork` | off | `fork` option on `Agent` |
| `tool-select` | off | Load MCP tools on demand (`"deferred": true`) |
| `tower` | off | Tower mode (needs a restart) |

## Q. Useful environment variables

| Variable | What it does |
|---|---|
| `KIMI_CODE_HOME` | Moves all data, e.g. for a separate test setup |
| `KIMI_MODEL_NAME` + `KIMI_MODEL_API_KEY` … | A temporary model |
| `KIMI_CODE_NO_AUTO_UPDATE=1` | Turns off updates. Your wrapper sets it |
| `KIMI_DISABLE_TELEMETRY=1` | Turns off telemetry |
| `KIMI_LOG_LEVEL` | Log level |
| `KIMI_CODE_DEBUG=1` | Shows step timings |
| `KIMI_CODE_TRUST_WORKSPACE=1` | Trusts the folder for this run |
| `KIMI_CODE_INFINITE_RETRY=1` | Keeps retrying failed model requests |
| `KIMI_LOOP_MAX_STEPS_PER_TURN` | Caps the steps in one turn |
| `KIMI_CODE_AGENT_SWARM_MAX_CONCURRENCY` | Caps how many swarm agents run at once |
| `KIMI_SUBAGENT_TIMEOUT_MS` | Subagent timeout |
| `KIMI_CODE_DANGEROUS_COMMAND_GUARD` | Overrides the guard setting in config |
| `KIMI_DISABLE_CRON=1` | Turns off scheduled prompts |

## R. Docs vs code (Kimi's docs are wrong here)

1. **`[[permission.rules]]`:** the docs say they are loaded. In the code they are never applied.
2. **Always Ask:** the docs say it confirms every edit. It auto-approves edits inside a git repo.
3. **Write/Edit:** the docs say a prior Read is required. Nothing enforces it.
4. **Bash timeout:** the docs say milliseconds. It is seconds.
5. **`bash_task_timeout_s`:** it only applies to commands moved to the background, not to explicit background calls (those default to 600 s).
6. **FetchURL:** the docs say it needs a host implementation. It always works through the local fallback.
7. **AgentSwarm:** the docs say it needs approval outside swarm mode. It's auto-approved.
8. **Prompt rebuilds:** the docs say plugin prompt text is rebuilt after compaction. It isn't; the prompt is built once per session.
9. **`${now}`:** documented, but it no longer exists.
10. **The docs changelog stops at 2.1.1.** For 2.2.0 see `source/apps/kimi-code/CHANGELOG.md`.
11. **Undocumented features:**
    - `/effort`, `/tower`, `/write-goal`
    - `kimi fork`, `kimi session list`
    - Inline `/skill` mentions in a prompt
    - `KIMI_MODEL_OUTPUT_FORMAT`, `KIMI_CODE_TUI_MAX_TURNS`
    - `.mcp.json` support

`/check-kimi-code-docs` answers from these same docs, so it inherits the mistakes.

## S. Your setup (as of 18 October 2026)

**Found:**
- `default_permission_mode = "auto"` (Never Ask), `dangerous_command_guard = false`, `default_model = "7api/glm-5.3-abliterated"`.
  - Nothing ever asks. The guard wouldn't run in Never Ask anyway. The model has had its refusal behavior removed.
- No Kimi login and no `[services.moonshot_search]`, so there is no web search.
- No AGENTS.md anywhere, no Kimi `mcp.json`, and no Kimi skills or agents of your own.
- Subagents: `closerouter/openai-gpt-6-astra` at high effort, with only `default_model` set, so there is no choice.
- Thinking on (high), `notify_user` on.
- Auto-update off twice (shell function and `tui.toml`), which is correct for CustomKIMI.
- The `kimi` wrapper exports both API keys, so the agent's Bash can see them.

**Suggested** (change these keys, keep the rest):
```toml
default_model = "closerouter/openai-gpt-6-astra"   # or any alias you trust unsupervised
default_permission_mode = "yolo"

[permission]
dangerous_command_guard = true

[secondary_model]
default_model = "7api/glm-5.3-flash"
default_effort = "high"
[secondary_model.models]
"7api/glm-5.3-flash" = "Fast and cheap: searching, reading, summarizing, small edits."
"closerouter/openai-gpt-6-astra" = "Hard problems: tricky debugging, refactors, design."

[[hooks]]
event = "PreToolUse"
matcher = "^Bash$"
command = "node ~/.kimi-code/hooks/bash-guard.mjs"
timeout = 10
```
- Keep the abliterated alias and switch to it with `/model` when you want it.
- For web search: `/login` with a Kimi account, or add a search MCP server.

**Moving from Claude Code:**

| Claude Code piece | Kimi equivalent |
|---|---|
| superpowers | Already working in Kimi |
| ralph-loop | `/goal` |
| playwright MCP | Add to `~/.kimi-code/mcp.json` (section L) |
| frontend-design | Copy its SKILL.md into `~/.kimi-code/skills/` if the license allows |
| swift-lsp, clangd-lsp | No equivalent |
| your `/sessions` command | `/wipe-all-sessions` or `kimi session list --json` |

## T. Updating CustomKIMI

- `sh scripts/update.sh --check` to see what's new.
- `sh scripts/update.sh` to update.
- `--rollback` to undo an update.
- `--save` after you commit your own changes in `source/`.
- **Never run `kimi upgrade` or `npm install -g @moonshot-ai/kimi-code`.** Both replace your patched build.
- After each update, re-check the docs-vs-code facts in R. Kimi may have fixed some of them.

## U. Learning path

1. **Safe and yours.** Ask When Needed, the guard hook, `kimi doctor`, `~/.kimi-code/AGENTS.md`.
2. **Project instructions.** AGENTS.md plus the CLAUDE.md symlink, `/init`, a nested AGENTS.md, `/new`.
3. **The daily loop.** `@`, `!`, queue vs `Ctrl-S`, `/undo` vs git, `/compact`, `/fork`, `kimi -c`.
4. **Models, effort, cost.** `/model`, `/effort`, the subagent pool, your footer cost.
5. **Delegation.** explore, plan and coder; `/btw`; `/tasks`; `/swarm`.
6. **Autonomy.** `/goal` with a finish line and budget, cron, `kimi -p` in a script.
7. **Extending.** Your own skill, agent and hook; MCP via `/mcp-config`.
8. **Your team.** Coordinator plus workers in a goal loop (sections 7 and 8).
9. **Other surfaces.** `kimi web`, `kimi vis`, ACP, Tower.
