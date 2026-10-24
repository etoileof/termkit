# CustomKIMI features

Everything CustomKIMI changes in official Kimi Code lives in this folder. Each feature is one patch in `patches/`, and `scripts/update.sh` applies them in order on top of every new release. `BASE_VERSION` is the release the patches currently apply to; older patch sets are kept in `history/`.

The ClosedRouter and 7api providers and their models are not patches. They are plain Kimi configuration in `~/.kimi-code/config.toml` (template: `config/config.toml.example`), which official updates never touch.

If a patch stops applying after a new release, re-create the behavior described below on the new code. The patch file shows the previous implementation, and the listed tests show what must keep passing.

## 1. Provider-reported request cost (`0001-…`)

CloseRouter returns the exact USD cost of every request in `usage.cost`. Official Kimi drops that field. This patch keeps it and adds it up per session.

- `packages/agent-core-v2/src/human/llm/usage.ts`: `TokenUsage` has `cost?: number`. `addUsage` sums it; the sum is unknown (undefined) as soon as either side lacks a reported cost (patch 0007 — a request without a cost must not count as $0). `mergeUsagePatch` keeps it.
- `packages/agent-core-v2/src/human/llm/requester/bases/{anthropic,openai,openai-responses}/`: `contract.ts` declares `cost` on the raw usage type, and `format.ts` copies `usage.cost` into `TokenUsage.cost` when it is a finite number (anything else counts as unreported).
- `packages/agent-core-v2/src/human/usage/usage.ts`: the human-layer usage summary (not used by the v2 runtime) adds up `cost` where it is reported.
- `packages/node-sdk/src/types.ts`: the SDK `TokenUsage` has `readonly cost?: number`.
- `packages/agent-core-v2/docs/state-manifest.d.ts`: generated file, regenerated for the new field. If it conflicts, take upstream's version and run `corepack pnpm -C packages/agent-core-v2 run gen:state-manifest`.

Tests: agent-core-v2 `src/human/test/llm/usage.test.ts`, `src/human/test/usage/machine.test.ts`, `test/llm-adapter/contract/usage-tokens.test.ts`; node-sdk `test/session-event-wiring.test.ts`.

## 2. Provider balance and session cost in the footer (`0002-…`)

The footer's second line shows, before the context usage, the balance of the provider serving the active model and the cost of the current session, for example `7api balance $9.18  session cost $0.0123`. Since patch 0007 the session cost covers every agent of the session (see feature 7). The balance follows the active model (ClosedRouter, 7api or OpenRouter, see feature 8). When the terminal is too narrow, the cost is dropped first, then the balance. A `usage` slot with the same values is available to `status_line` templates. Requires feature 1.

Code in `apps/kimi-code/src/utils/billing/`:

- `billing-provider.ts`:
  - The abstract `BillingProvider` handles the API key (read from an environment variable) and authenticated GET requests with a 5 second timeout. It also matches model base URLs to the provider's host.
  - Failures resolve to `undefined`, so they are never shown as `$0`.
  - `costOfUsage()` is the one cost formula: tokens × USD per million, for input, output, cache reads and cache writes.
- `closedrouter.ts`: `ClosedRouterBilling`.
  - Balance comes from `GET https://api.closerouter.dev/v1/credits` (`total_credits`). Override the URL with `CLOSEROUTER_BALANCE_URL`.
  - Replies carry `usage.cost`, so no price list is needed.
  - If all four `CLOSEROUTER_*_USD_PER_MILLION` rates are set, they price a model whose cost is not fully reported: all of its tokens, as an estimate.
- `sevenapi.ts`: `SevenApiBilling`.
  - Balance comes from `GET https://7api.st/v1/balance` (`balance_usd`).
  - Prices come from `GET https://7api.st/v1/models`: `pricing.price_usd_per_mtok` covers input, output and cache writes, and `pricing.cache_read_usd_per_mtok` covers cache reads.
  - This matched 7api's billing exactly for the Chat, Responses and Messages APIs.
- `providers.ts`: `createBillingProviders()`, the list of providers.
- `billing-monitor.ts`: `BillingMonitor`.
  - Polls every provider whose key is set: balances every 60 seconds, prices every 10 minutes.
  - Computes the session cost from per-model session usage (`SessionUsage.byModel`; the footer passes the session-wide `billingUsage` of feature 7 and falls back to the main agent's `sessionUsage`). A model's reported `cost` is used only when every one of its requests reported one (feature 1 keeps the sum unknown otherwise); then all of that model's tokens are priced from the price list or the rates instead.
  - The engine keys `byModel` by **model alias**, for example `7api/gpt-6-astra`. `modelResolver()` maps an alias, or a `<baseUrl>#<model>` key, to its provider endpoint and upstream model id using the configured models and providers.
  - Hides the cost if any model cannot be priced.

Wiring:

- `apps/kimi-code/src/tui/components/chrome/footer.ts`:
  - The footer owns a `BillingMonitor`, started in the constructor and stopped in `dispose()`.
  - It uses `modelResolver()` both for the active model's endpoint (the model's own `baseUrl`, else its provider's) and for the session usage keys.
  - It renders the balance and the cost.
- `apps/kimi-code/src/tui/types.ts`: adds `AppState.sessionUsage`.
- `apps/kimi-code/src/tui/controllers/session-event-handler.ts` and `kimi-tui.ts`: store `sessionUsage` from status events and syncs, and reset it when switching sessions.

**Adding a provider:**

1. Subclass `BillingProvider` with its `label`, `host`, `apiKeyEnv` and `fetchBalanceUsd()`.
2. If the provider's replies carry no cost, also implement `fetchPrices()`.
3. Add the class to `createBillingProviders()` in `providers.ts`.

Tests (apps/kimi-code): `test/utils/billing/billing-providers.test.ts`, `test/utils/billing/billing-monitor.test.ts`, `test/tui/components/chrome/footer.test.ts`, `test/tui/controllers/session-event-handler-compaction.test.ts`.

## 3. `/wipe-all-sessions` (`0003-…`)

`/wipe-all-sessions confirm` deletes every saved session in every workspace. Config, credentials, plugins and logs are kept. Without `confirm`, it only shows a warning. If the current session was deleted, a fresh one starts. The command is only available while Kimi is idle.

- `apps/kimi-code/src/tui/commands/registry.ts`: entry in `BUILTIN_SLASH_COMMANDS` (`availability: 'idle-only'`).
- `apps/kimi-code/src/tui/commands/session.ts`: `handleWipeAllSessionsCommand`. It lists sessions with `harness.listSessions({ includeArchived: true })`. If the current session is among them, it calls `host.closeSessionForWipe()` first. It then calls `harness.deleteSession(id)` for each session, and finally `host.createNewSession()`.
- `apps/kimi-code/src/tui/commands/dispatch.ts` and `index.ts`: export the handler, add `case 'wipe-all-sessions'`, and add `closeSessionForWipe(): Promise<void>` to `SlashCommandHost`.
- `apps/kimi-code/src/tui/kimi-tui.ts`: `closeSessionForWipe()` closes the session, clears `sessionId` and redraws an empty transcript.

Tests: none; the typecheck catches API changes. For example, Kimi Code 2.3.0 renamed `waitForLazyCreation()`, which the handler awaits first, to `waitForSessionAssembly()`; it now also waits for a `/new` session that is still being created.

## 4. node-pty permission fix (`0004-…`)

`pnpm install` runs `scripts/fix-node-pty-perms.mjs` to make node-pty's `spawn-helper` binaries executable. node-pty needs them to start terminal processes on macOS. Upstream resolves node-pty from `packages/services`, which does not exist, so the helpers stay non-executable. This patch resolves node-pty from `packages/agent-core-v2` and `apps/kimi-code`, relative to the script. Drop this patch once upstream fixes the path.

Check: `pnpm install` must not print `[fix-node-pty-perms] skipped: …`, which means node-pty was not found. It prints `made N spawn-helper binary(ies) executable` when it fixes something, and nothing when the helpers are already executable.

## 5. Provider balance in the web UI (`0005-…`)

`kimi web` and `/web` show the balance of the provider serving the open session's model, for example `7api $6.72`, just before the model picker under the message box. If a web UI update moves the picker, the badge falls back to a small pill in the bottom-right corner. It refreshes every minute and whenever the session or model changes. Requires feature 2.

Session cost is CLI-only: the web server's public API has no per-model session usage.

The web UI ships pre-built (`apps/kimi-code/dist-web`, synced from upstream), so the badge is an add-on served by the local server:

- `packages/kap-server/src/start.ts`: two generic `startServer` options.
  - `extraRoutes(app)` is called after all API routes are registered.
  - `webHtmlInjection` is passed on to the web asset routes.
  - This package forbids comments (`scripts/check-no-comments.mjs`).
- `packages/kap-server/src/routes/webAssets.ts`: `registerWebAssetRoutes(app, dir, { htmlInjection })` inserts the snippet before `</head>` whenever `index.html` is served.
- `apps/kimi-code/src/cli/sub/web/run.ts`: creates a `BillingMonitor`, passes `BALANCE_BADGE_HTML` and `registerBalanceBadge` to `startServer`, and stops the monitor on close. It is used by both `kimi web` and `/web`.
- `apps/kimi-code/src/cli/sub/web/balance-badge.ts`:
  - Serves the script at `GET /customkimi/balance-badge.js`.
  - Serves `GET /api/customkimi/balance?model=<alias>`, which needs bearer auth like every `/api` route.
  - The route reads the config with `loadRuntimeConfigSafe(resolveConfigPath({}))` and resolves the alias with `modelResolver()`.
- `apps/kimi-code/src/cli/sub/web/balance-badge-script.ts`: the browser script.
  - Reads the web UI's credential from `localStorage['kimi-web.server-credential']` (`{ credential, expiresAt }`).
  - Gets the open session's model from `GET /api/v1/sessions/<id>/status`.
  - Places itself before the button that contains `.mp-name`.

Notes for future updates:

- The server replaces `Authorization` with `[redacted]` before route handlers run, so a handler cannot call other API routes on the caller's behalf. Failed authentications also count toward the server's rate limit. That is why the browser does the session lookup itself and never retries a rejected credential.
- If the web UI renames `.mp-name`, the badge falls back to the corner pill. If it changes how the credential is stored, the badge hides. Either way, update the selector or the storage key in `balance-badge-script.ts`.

Tests: kap-server `test/webAssetsInjection.test.ts`; apps/kimi-code `test/cli/web/balance-badge.test.ts`.

## 6. CloseRouter model limits and efforts (`0006-…`)

When Kimi starts (and every 6 hours while `kimi web` runs), the configured CloseRouter aliases are refreshed from CloseRouter itself, so context limits, output limits and reasoning efforts follow what the endpoint each alias is called through supports. Only aliases that already exist are updated; the catalog is never imported and no alias, provider or setting is added or removed.

- `packages/oauth/src/closerouter.ts`: `refreshCloseRouterModels()`.
  - An alias is refreshed when its endpoint is CloseRouter: the model's own `base_url` if set, else its provider's, must be `https://api.closerouter.dev` or `…/v1` (HTTPS, no port, credentials, query or other path). Its protocol (`protocol` on the model, else the provider `type`) picks the endpoint: `openai` → Chat (`chat`), `openai_responses` → Responses (`responses`), `anthropic` → Messages (`messages`). Skipped: providers with `model_source = "static"`, a registry `source` or `oauth`; models with `oauth`; the `KIMI_MODEL_*` environment model.
  - `GET /v1/models` gives `context_length` → `max_context_size` and `max_output_tokens` → `max_output_size`. `GET /v1/models/{author}/{model}/endpoints` gives the endpoint's `supported_reasoning_efforts` → `support_efforts` (without `none`, ordered weakest to strongest; a missing list means no efforts) and `default_effort = "high"` when listed (else the middle level; a client default, not a claim about CloseRouter's).
  - Chat and Responses can only stop reasoning through an explicit `none` effort: with `none` the alias gets `off_effort = "none"` and `thinking`; without it `thinking` + `always_thinking`, so "off" is never offered or sent. Messages gets `thinking` only and keeps native Anthropic semantics ("off" is sent as `thinking: {type: "disabled"}`; models that cannot turn reasoning off get `always_thinking` from their model profile at runtime). The refresh owns both thinking tags; pin your own with `overrides.capabilities`.
  - `[secondary_model].default_effort` is validated against every pool model when a session starts. If the new efforts would make it invalid (for example `"off"` with a model that always reasons), that alias keeps its previous efforts and the refresh says which effort to change; limits are still updated.
  - The key is the one the alias would use for chat (model `api_key`, else the provider `api_key` / `api_key_env`, else the provider `env` table entry of its type). A provider's key is sent only when the provider itself points at CloseRouter (its `base_url`, or the base URL in its `env` table). A provider without one talks to its vendor's default API, and one pointing elsewhere owns its key for that endpoint, so an alias that only re-routes such a provider to CloseRouter is skipped and reported; a key set on the alias itself is still used. Requests go only to `api.closerouter.dev`, with redirects refused, and failure messages never contain the key (it is redacted, and a key with control characters is refused before any request). One catalog request per key, one endpoint request per model, at most 4 at once, 10 s per request and 30 s in total. `:flex`/`:default`/`:priority` model suffixes are looked up by their base id.
  - Failures keep the previous metadata and are reported (the TUI shows `Skipped refreshing <provider>: …` at startup): network/HTTP/JSON errors (with the underlying cause, e.g. a refused redirect), a model missing from the catalog, an invalid `context_length`, an endpoint type that is not listed, an endpoint that does not stream, conflicting or malformed effort lists, and a `[secondary_model]` conflict.
  - After the requests the config is read again and the patch is merged into it, so edits made meanwhile are kept; only the `models` section is written, and nothing at all when nothing changed. A changed provider is reported with a `detail` that the TUI shows, naming what changed (`closerouter · limits and efforts of 3 models updated from CloseRouter.`, or only limits or efforts); the TUI prints all refresh messages before it re-reads the session status.
  - A refresh write cannot delete a key (missing keys survive the config write), so the module only writes definite values; a stale `off_effort` stays when `none` disappears, unused once the alias is `always_thinking`.
- `packages/oauth/src/refreshProviderModels.ts`: branch 1.5 calls `refreshCloseRouterModels()` for scope `all` (startup, `kap-server`'s scheduled refresh); the model picker's OAuth-only refresh does not. `ProviderChange.detail` carries the summary above.
- `packages/agent-core-v2/src/app/kosongConfig/discoveryService.ts`: the engine's refresh host also passes `secondaryModel`, so the check above works for `kimi web` too.
- `apps/kimi-code/src/tui/kimi-tui.ts`: after a refresh that changed something, `applyRefreshedModelLimits()` re-reads the session status (context limit, thinking effort) so the footer follows at once; without a session it uses `configuredModelDefaults()`. The change `detail` is shown as a status line. All refresh messages are printed first; the re-read runs last, after upstream's own post-refresh step (moving a session-less selection off a retired default model).
- `apps/kimi-code/src/tui/utils/model-switch.ts`: `lazyModelSelection()`, the footer's model, context limit and effort before a session exists (startup, `/reload`, and a retired default model), uses `configuredModelDefaults()`. So does `controllers/auth-flow.ts` after a login.
- Since 2.3.0 the TUI refreshes through the engine (`harness.refreshProviderModels()`, with snake_case fields such as `provider_name`). `detail` is therefore carried by `providerRefreshChangeSchema` (`agent-core-v2/src/app/kosongConfig/discovery.ts`), `mapRefreshResult` (`discoveryService.ts`), and in klient by `refreshProviderModelsResponseSchema` (`src/contract/global/providerDiscovery.ts`) and the catalog event's `catalogChangedSchema` (`src/contract/global/events.ts`). klient strips unknown fields, so a missing entry still compiles but silently drops the status line; node-sdk `test/sdk-rpc-client-v2.test.ts` checks it end to end.
- `apps/kimi-code/src/tui/utils/thinking-config.ts`: `configuredModelDefaults()` mirrors the engine for the footer before a session exists: the effective context limit (overrides and `max_input_size`) and, for an `always_thinking` model, the configured (else default) effort instead of "off".

Pin a value with `[models."<alias>".overrides]`; overrides win at runtime and are never rewritten. The refreshed values reach the engine through the normal config reload: compaction and the completion budget read the current model on every request, and requests carry `reasoning_effort` (Chat), `reasoning.effort` (Responses) or `output_config.effort` (Messages). Unsupported efforts set explicitly (for example in `[thinking]`) are not rewritten for generic providers; CloseRouter rejects them, and the pickers only offer listed efforts.

Tests: oauth `test/closerouter.test.ts`; agent-core-v2 `test/llm-adapter/model/closerouterRequests.test.ts` (refresh → model → captured HTTP bodies, and `[secondary_model]` validation); node-sdk `test/sdk-rpc-client-v2.test.ts` (a stubbed CloseRouter refresh through the real harness keeps `detail`); apps/kimi-code `test/tui/utils/thinking-config.test.ts`, `test/tui/kimi-tui-startup.test.ts` (the lazy footer at startup and after a refresh, and the live-session re-read, with the engine's refresh mocked).

## 7. Session cost of every agent (`0007-…`)

The footer's session cost includes the main agent, foreground, background and nested subagents, including finished ones and those of earlier runs of a resumed session. Each agent is counted once; the context meter stays the main agent's own.

- `packages/agent-core-v2/src/session/usage/sessionBilling.ts`: `SessionBilling` keeps each agent's cumulative per-model usage keyed by agent id and replaces it on every update (never adds repeated cumulative totals); the snapshot sums all agents per model.
- `packages/agent-core-v2/src/session/usage/sessionBillingService.ts`: `ISessionBillingService` (session scope, registered in `features/usage/usageFeature.ts`, exported from `index.ts`).
  - Live: from its creation, every `ISessionUsageService.onDidRecord` replaces that agent's snapshot with its cumulative `status()`; a live agent always wins over its durable records.
  - Durable: on first use (`ready` / `snapshot()`, i.e. the first `getStatus()`) it reads every agent in the session metadata, and later every agent registered afterwards (`onDidChangeMetadata`), from `agents/<id>/wire.jsonl` (`usage.record` lines, summed like the agent's own usage model), holding a log lease while reading. Hosts that never ask (web server, print mode) do no reads.
  - If session metadata or a journal cannot be read, or a usage record is malformed, the snapshot becomes empty, which hides the cost rather than showing a partial one, and an update is sent.
  - A damaged journal (a line that is not valid JSON) is different: like the engine's own repair, it is read up to its first bad line. A last line cut off by a crash loses nothing, but usage recorded after a bad line in the middle is not counted, so the cost shown is lower. Only a warning is logged.
  - `ready` never rejects. `onDidChange` fires once after the restore and whenever the snapshot changes afterwards, including background subagents that spend after the main turn ended.
- `packages/agent-core-v2/src/human/llm/usage.ts`: `addUsage` keeps the cost unknown when either side lacks one (see feature 1).
- `packages/klient/src/contract/agent/schemas.ts`: `tokenUsageSchema` carries `cost`, so `getStatus().usage` keeps it on resume.
- `packages/node-sdk/src/types.ts`: `SessionStatus.billingUsage`. `src/sdk-rpc-client-v2.ts`: `getStatus()` waits for `ready` first, then reads every slice. `src/v2/session-wiring.ts`: forwards `onDidChange` as an `agent.status.updated` event of the main agent that carries the main agent's own snapshot (usage, context, model) like every status event, plus `billingUsage`. `agent-core-v2/src/agent/usage/usageEvents.ts`: the field on `AgentStatusUpdatedEvent`.
- `apps/kimi-code/src/tui/types.ts`: `AppState.billingUsage`. `controllers/session-event-handler.ts` stores it before child events are routed away; `kimi-tui.ts` sets it from `getStatus()` (unless a newer billing event arrived meanwhile) and clears it when switching sessions; `components/chrome/footer.ts` prices `billingUsage ?? sessionUsage`.

Not included: requests that fail or are cancelled before the provider reports usage (usage is recorded on success only), and costs a provider did not report. Session spend is never inferred from balance changes. Like the agent's own usage, a forked session includes the usage copied from its source.

Known limits:
- The first `getStatus()` of a session (TUI start or resume) waits for one sequential read of every agent's journal, the main agent's included although its live usage is already known.
- Agents are found through the session metadata, not by listing the `agents/` folder.
- `billingUsage` is `{}` both before anything is spent and while the cost cannot be fully accounted for; the footer shows no cost in either case.

Tests: agent-core-v2 `test/agent/usage/sessionBilling.test.ts` (its test agents register an in-memory session lock and a session context, because since 2.3.0 an agent's wire journal is written only while its process holds the session lock), `test/llm-adapter/contract/usage-tokens.test.ts`, `src/human/test/llm/usage.test.ts`; node-sdk `test/session-billing.test.ts` (real subagents through a stubbed endpoint, live and after a restart), `test/session-event-wiring.test.ts`; apps/kimi-code `test/tui/components/chrome/footer.test.ts`, `test/tui/controllers/session-event-handler-compaction.test.ts`, `test/tui/kimi-tui-startup.test.ts`.

## 8. OpenRouter balance and session cost (`0008-…`)

OpenRouter is the third billing provider, after ClosedRouter and 7api. When the active model's base URL is on `openrouter.ai` (for example `https://openrouter.ai/api/v1`), the footer shows `OpenRouter balance $X  session cost $Y` and the `kimi web` badge shows `OpenRouter $X`. It is active only when `OPENROUTER_API_KEY` is set. Requires features 1, 2 and 5.

- `apps/kimi-code/src/utils/billing/openrouter.ts`: `OpenRouterBilling` (label `OpenRouter`, host `openrouter.ai`, key `OPENROUTER_API_KEY`).
  - **Balance with a management key:** `GET https://openrouter.ai/api/v1/credits` with the management key, giving `data.total_credits - data.total_usage`. Both must be finite numbers.
  - **Fallback:** if there is no management key, or `/credits` fails or returns an invalid body, the balance is `GET /api/v1/key` with the normal API key, giving `data.limit_remaining`. A key without a credit limit reports `null`, which means no balance is shown. Failures show nothing, never `$0`; a real 0 balance is shown.
  - **Which key goes where:** the management key is sent only to `/credits`. The API key is sent only to `/key` and `/models`. Without an API key, nothing is requested and no stored key is read.
  - **Where the management key comes from:**
    - `OPENROUTER_MANAGEMENT_KEY` in the environment (trimmed, non-empty) wins.
    - Otherwise, on macOS only, `readKeychainManagementKey()` reads it from the login Keychain: `/usr/bin/security find-generic-password -a <current user> -s OPENROUTER_MANAGEMENT_KEY -w`, called by absolute path with a 3 s timeout. It returns the trimmed output, or nothing on any error. Store the key with `security add-generic-password -a "$USER" -s OPENROUTER_MANAGEMENT_KEY -w`.
    - The management key can create and delete API keys. It is therefore kept out of Kimi's environment, so the agent's shell does not inherit it. It is never written to `process.env` and never logged.
    - **Limit:** the Keychain only keeps the key out of inherited environments. Any process running as you, the agent's shell included, can read the item without a prompt using the same `security` command. If the agent may run untrusted prompts, do not store a management key. The balance then comes from the `/key` fallback.
    - A key found in the Keychain is cached for the provider's lifetime. A miss is cached for 10 minutes, so the 60-second balance poll does not start a process each time. Constructing the provider never reads the Keychain. The reader and the clock can be injected as constructor options, so tests never run `security`.
  - **Prices:** `GET /api/v1/models` (public, but the API key is sent). Per-token USD strings become per-million prices: `prompt` → input, `completion` → output. `input_cache_read` and `input_cache_write` become the cache-read and cache-write prices; if one is missing or invalid, the input price is used. Entries whose prompt or completion price is missing, not a number or negative (`"-1"` means variable pricing, as for `openrouter/auto`) are skipped. OpenRouter replies carry `usage.cost` (feature 1), so these prices only cover replies without a cost.
- `apps/kimi-code/src/utils/billing/billing-provider.ts`: `getJson(url, key = this.apiKey)`. A subclass can sign a request with another key; ClosedRouter and 7api are unchanged.
- `apps/kimi-code/src/utils/billing/providers.ts`: `createBillingProviders()` returns ClosedRouter, 7api, OpenRouter, in that order.
- The web badge (`cli/sub/web/balance-badge*.ts`) contains nothing provider-specific and needed no change.

Tests: apps/kimi-code `test/utils/billing/billing-providers.test.ts` covers:
- the provider order;
- the management key from the environment (reader not called) and from the Keychain (read once, and still cached 11 minutes later, with an injected clock);
- a Keychain miss cached for 10 minutes, with an injected clock;
- the `/credits` fallback for an HTTP error, a failed request, missing usage and a non-numeric balance;
- `limit_remaining: null` and a `/key` error;
- a zero balance, no API key, and which key each URL receives;
- price parsing, including `"-1"`, invalid prices and cache-price fallbacks;
- `bills()`;
- the Keychain reader's exact command and timeout, empty or missing results, and no process on other platforms (with a mocked `node:child_process`).

- `apps/kimi-code/vitest.config.ts`: `test.env` blanks `CLOSEROUTER_API_KEY`, `SEVENAPI_API_KEY`, `OPENROUTER_API_KEY` and `OPENROUTER_MANAGEMENT_KEY`. A test that builds a `FooterComponent` without a billing source uses the real environment. Run from a `kimi` shell (whose wrapper exports the keys), it would otherwise poll real balances and read the Keychain.

Keys: store them with `security add-generic-password -U -a "$USER" -s OPENROUTER_API_KEY -w` and `… -s OPENROUTER_MANAGEMENT_KEY -w`. The `kimi` function in `~/.zshrc` exports only `OPENROUTER_API_KEY`.

## 9. OpenRouter model limits and efforts (`0009-…`)

When Kimi starts (and every 6 hours while `kimi web` runs), Kimi refreshes the configured OpenRouter aliases from OpenRouter's public model catalog. Like feature 6 for CloseRouter, this keeps context limits, output limits and reasoning efforts in line with what OpenRouter reports. It only updates aliases that already exist. It never imports the catalog and never adds or removes an alias, provider or setting. It never uses an API key.

- `packages/oauth/src/openrouter.ts`: `refreshOpenRouterModels(host, config, options)`. It has the same contract as `refreshCloseRouterModels()` and returns `{ config, changed, unchanged, failed }`.
  - **Which aliases:** an alias is refreshed when its effective endpoint is OpenRouter.
    - The endpoint is the model's own `base_url` if set, else its provider's, else the base URL in the provider's `env` table for its type (`OPENAI_BASE_URL`, …).
    - The endpoint must be exactly `https://openrouter.ai/api/v1`, with or without a trailing slash: HTTPS only, and no port, credentials, query or other path (`openRouterApiBase()`).
    - The protocol (`protocol` on the model, else the provider `type`) must be `openai` (Chat) or `openai_responses` (Responses). Anthropic-protocol aliases are skipped.
    - Skipped as in feature 6: providers with `model_source = "static"`, a registry `source` or `oauth`; models with `oauth`; the `KIMI_MODEL_*` environment model. `providerId` limits the refresh to one provider.
  - **The request:** one `GET https://openrouter.ai/api/v1/models`.
    - It sends no `Authorization` header: the catalog is public, so no key can leave through this feature. It sends `User-Agent`.
    - Redirects are refused. Kimi waits at most 10 s for the response, and at most 30 s in total, including reading the catalog body. Tests replace the network call through `options.fetchImpl`.
  - **Finding a model:** by exact id (`model`, or the legacy `name`). If that id is missing and has a `:<variant>` suffix (`:nitro`, `:floor`, `:online`, …), the base id is tried. A catalog entry whose full id contains a colon (for example `…:free`) still matches exactly first.
  - **Limits:** `context_length` sets `max_context_size`. `top_provider.max_completion_tokens` sets `max_output_size`; when it is missing or invalid, the previous value stays and nothing is reported.
    - `max_output_size` is written as OpenRouter reports it, with no cap. Chat requests clamp it to the remaining context and to 131072 tokens. Responses requests, and their compaction requests, send it unchanged. For `meta/muse-wonder` that is 943718 tokens, which OpenRouter can refuse once the input plus the requested output is larger than the context, or when the remaining credit cannot pay for that many output tokens. On an `openai_responses` alias of such a model, pin a smaller `[models."<alias>".overrides].max_output_size`.
  - **Efforts:**
    - The effort list comes from `reasoning.supported_efforts`. It is checked, de-duplicated and ordered weakest to strongest with CloseRouter's `parseEfforts()`.
    - When `reasoning.mandatory` is true, `none` is dropped, because reasoning cannot be turned off.
    - When `reasoning` is null, or has no `supported_efforts` list, the alias is handled like a CloseRouter endpoint that lists no effort levels: its previous efforts stay, and this is reported only if the alias already had `support_efforts`.
    - CloseRouter's Chat and Responses rules then apply unchanged through `patchAlias()`:
      - With `none`, the alias gets `off_effort = "none"` and `thinking`.
      - Without `none`, it gets `thinking` and `always_thinking`.
      - `support_efforts` lists the levels other than `none`.
      - `default_effort` is `"high"` when that level is listed, else the middle level.
      - Other capabilities, such as `image_in`, are kept.
    - Example: `meta/muse-wonder` becomes `support_efforts = [minimal, low, medium, high, xhigh, max]`, `default_effort = "high"`, `thinking` plus `always_thinking`, `max_context_size = 1048576` and `max_output_size = 943718`.
  - **Rules kept from feature 6:**
    - The `[secondary_model].default_effort` conflict check (`subagentEffortProblem()`). The message names OpenRouter.
    - After the request, the config is read again and the patch is merged into it. Only the `models` section is written, and nothing at all when nothing changed.
    - `[models."<alias>".overrides]` are never rewritten.
    - A refresh write cannot delete a key, so a stale `off_effort` stays when `none` disappears. It is never used, because the alias becomes `always_thinking`.
  - **Failures:** every failure keeps the previous values and is reported per provider. The TUI shows each one at startup as `Skipped refreshing <provider>: …`.
    - The catalog request fails (network, HTTP, invalid JSON, no `data` list, refused redirect, timeout): `OpenRouter model catalog request failed (<cause>); keeping the previous limits and efforts.`
    - The model is not in the catalog: `<model> is not in the OpenRouter catalog; keeping its previous limits and efforts.`
    - `context_length` is invalid: `OpenRouter reports no valid context_length for <model>; keeping its previous context size.`
    - Also reported: a malformed `supported_efforts` list, an empty effort list while the alias had efforts, a `[secondary_model]` conflict, and a failed config re-read or write.
  - Aliases added while the request is running are refreshed too, because the public catalog lists every model. CloseRouter, whose catalog depends on the API key, leaves those for its next refresh.
- `packages/oauth/src/closerouter.ts`: the helpers above are only exported. CloseRouter's behavior is unchanged.
  - Because this file only gains exports, three parts of `refreshCloseRouterModels()` are mirrored in `openrouter.ts` instead of shared: the target skip rules, the `[secondary_model]` conflict message, and the re-read, merge and models-only write. A fix to one must be made in the other too.
- `packages/oauth/src/refreshProviderModels.ts`: branch 1.6 runs right after CloseRouter's branch 1.5, for scope `all` only: TUI startup through `authFlow.refreshProviderModels()`, and kap-server's `ModelCatalogRefreshScheduler` at startup and every 6 hours. The model picker's OAuth-only refresh (scope `oauth`) does not run it.
  - A throw is reported as a failure for the provider (or `openrouter`) and never aborts the refresh. Later branches, such as custom registries, still run.
  - `metadataChange()` builds the shared change detail, so the TUI shows, for example, `openrouter · limits and efforts of 2 models updated from OpenRouter.`, or only limits or efforts.
- Like feature 6, values reach the engine through the normal config reload. The TUI's `applyRefreshedModelLimits()` (feature 6) re-reads the session status after any refresh that changed something.

Pin a value with `[models."<alias>".overrides]`. To opt a provider out of every refresh, set `model_source = "static"` on it.

Requires feature 6, whose helpers it reuses. Tests: oauth `test/openrouter.test.ts`; `test/closerouter.test.ts` must keep passing unchanged.

## 10. Bounded retries for HTTP 524 (`0010-…`)

Provider HTTP 524 gateway timeouts use the existing transient-error retry path instead of immediately failing the turn and pausing an active goal. No automatic "Continue" prompt is injected, and no infinite-retry setting is enabled.

- `packages/agent-core-v2/src/human/llm/requester/retry.ts`: includes 524 in the turn retry policy. Retries keep the existing attempt limit (10 total attempts per step by default), exponential backoff with jitter, `Retry-After` handling, and cancellation. `[loop_control].max_attempts_per_step` can override the limit.
- `packages/agent-core-v2/src/llm-adapter/contract/errors.ts`: includes 524 in `isRetryableGenerateError`, keeping compaction retries and telemetry classification consistent.
- Only the failed model step is retried. If all attempts fail, the turn still fails and the goal pauses normally; authentication, request validation, quota and safety failures retain their existing handling.
- This is recovery from a provider timeout, not a change to the provider's own timeout. A timed-out request can still have consumed provider resources before a retry.
- `apps/kimi-code/src/tui/controllers/session-event-handler.ts`: each scheduled turn retry prints a plain status line, for example `System notice: Model request failed (HTTP 524). Retrying attempt 2/10 in 1s.` Pending stream output is flushed before the notice. `types.ts`, `components/messages/status-message.ts` and `kimi-tui.ts` carry `preserveWhenFolding` so these lines remain visible during long-turn and completed-turn folding. The existing live retry indicator remains.
- `packages/kap-server/src/services/transcript/coreEventMap.ts`: each turn retry adds a display-only, labelled text frame for the prebuilt web UI (its notice frames are ignored and notice markers are only toasts). The line stays in the live chat after recovery, without changing model context or exposing raw provider error bodies. Stable retry frame IDs avoid duplication in the web transcript; stream-frame adoption skips these lines. This does not reconstruct retry lines in cold history after a server/session restart.

Tests: agent-core-v2 `src/human/test/agent/turn.test.ts` (524 recovery, bounded exhaustion and cancellation during backoff), `test/app/llmProtocol/errors.test.ts` (524 classification and unchanged non-retryable errors); node-sdk `test/session-prompt-events.test.ts` (real goal session with a stubbed HTTP 524: completes without pausing, preserves retry messages and does not replay completed tools); apps/kimi-code `test/tui/controllers/session-event-handler-step-retry.test.ts` (chat status entry survives retry completion), `test/tui/kimi-tui-message-flow.test.ts` (retry notices survive folding and follow buffered thinking); kap-server `test/services/transcript.test.ts` (visible retry lines, duplicate events, non-HTTP failures and separate model text).

Restart existing Kimi processes after rebuilding to load the changed engine.

## 11. Per-model extra request fields (`0011-…`)

A model alias can carry an `extra_body` table. Its fields are added at the top level of every OpenAI Chat Completions or Responses request for that alias. Use it for provider options Kimi has no setting for, such as OpenRouter's provider routing:

```toml
[models."openrouter/qwen3.8-27b".extra_body.provider]
only = [ "cerebras/fp16" ]
allow_fallbacks = false
```

- Keys inside `extra_body` are sent exactly as written; only top-level config keys are converted between snake_case and camelCase. The table survives Kimi's own config writes and the CloseRouter and OpenRouter startup refreshes.
- Kimi's own fields win on a conflict. `model`, `messages`/`input`, `tools`, `stream`, and every field Kimi sets itself (effort, output cap, response format) replace the same key from `extra_body`.
- Anthropic and Google models ignore it. It is not an override, so it cannot be set under `overrides`.
- When you pin one OpenRouter provider, put that provider's limits under `overrides`. Feature 9 writes the model-wide limits; for `qwen/qwen3.8-27b` those are 1,000,000 context and 235,929 output, while Cerebras serves 65,536 and 32,768.
- `packages/agent-core-v2/src/app/kosongConfig/configSection.ts`: `extraBody` in the model schema (omitted from `overrides`). `docs/config-manifest.toml` is regenerated.
- `llm-adapter/model/model.ts`: `ModelRecord.extraBody`. `llm-adapter/protocol/protocol.ts` and `llm-adapter/model/catalog-service.ts`: carried in `providerOptions` for the `openai` and `openai_responses` protocols.
- `llm-adapter/model/model-requester-impl.ts`: passed as `LlmRequestConfig.extraBody` (`human/llm/requester/requester.ts`).
- `human/llm/requester/bases/openai/format.ts` and `bases/openai-responses/format.ts`: spread first when the request body is assembled.
- This is separate from upstream's internal `extraParams.openai.extra_body`, which a plain OpenAI request still sends literally as an `extra_body` field.

Tests: agent-core-v2 `test/app/model/model.test.ts` (TOML round trip keeps nested keys verbatim), `test/llm-adapter/model/catalog.test.ts` (`providerOptions` for the OpenAI wires only), `test/llm-adapter/model/modelRequester.test.ts` (sent with every request), `src/human/test/llm/response-format.test.ts` (top-level fields on Chat and Responses requests; Kimi's `model`, `stream` and `reasoning_effort` win).

Known unrelated failure: agent-core-v2 `test/tool/tool.test.ts` "returns the spawned agent id when a foreground subagent times out" fails (30 s test timeout) with and without patches 0010 and 0011. `update.sh` does not run it, because no patch touches that file.

## 12. Context window in the `/model` picker (`0012-…`)

Every row of the `/model` picker shows the model's context window in a right-aligned column between the model name and the provider, so models can be compared before picking:

```
  ❯ x-ai/grok-4.7                       256k  closerouter ← current
    anthropic/claude-opus-4.8           200k  closerouter-anthropic
    GPT-6 Astra (7api)                 1.05M  7api-responses
    qwen/qwen3.8-27b                     64k  openrouter
```

- The value is the effective `max_context_size`, so `[models."<alias>".overrides]` counts (Qwen shows Cerebras's 64k, not the model-wide 1M). The column also appears in the per-provider tabs.
- Sizes read the way providers advertise them, via `formatContextSize()`:
  - Decimal units when they come out exact: 1,000,000 is `1M`, 200,000 is `200k` and 1,050,000 is `1.05M`.
  - Otherwise binary units when those are exact: 262,144 is `256k` and 1,048,576 is `1M`.
  - Otherwise rounded decimal units, such as `944k`.
- The footer's context readout uses the same formatter, so the picker and the footer agree. A 1M model's footer shows `(120k/1M)`, where upstream showed `(117k/977k)`. Token totals elsewhere (`/usage`, the goal panel) keep upstream's 1024-based `formatTokenCount()`.
- `apps/kimi-code/src/utils/usage/usage-format.ts`: `formatContextSize()`.
- `apps/kimi-code/src/tui/components/dialogs/model-selector.ts`: `ModelChoice.context` and the aligned column.
- `apps/kimi-code/src/tui/components/chrome/footer.ts`: `formatContextStatus()` uses the new formatter.

Tests: apps/kimi-code `test/utils/usage/usage-format.test.ts` (decimal, binary and rounded cases), `test/tui/components/dialogs/model-selector.test.ts` (aligned column, overrides), `test/tui/components/panels/footer-context.test.ts` (`120k/1M`), and the updated picker expectations in `test/tui/kimi-tui-message-flow.test.ts`.

## 13. Agent dock under the conversation (`0013-…`)

Every subagent of the session is listed as a row right under the conversation (above the Todo / Updates panels and the editor), led by a status dot: it pulses while the agent runs, turns green (`· done`) when it completed and red (`· failed`) when it failed. A row shows the agent name, its description, model, effort, how many tools it has used, the elapsed time and, while running, the tool it is on right now (for example `Bash ls src`). Finished rows stay for 8 seconds (failed ones 20 seconds) and then leave the list; a foreground agent of an aborted turn is marked `· ended`.

Keys: `↓` on an empty editor moves into the dock (the dim `↓ agents` hint under the rows says so), `↑`/`↓` move the selection, `Esc` goes back to the editor, and `↓` past the last row does too. `Enter` shows the selected agent's conversation **in place of the main chat**, in the chat's own shape: the task prompt the parent gave the agent as a user message (`❯ …`), then its assistant text (Markdown) and tool calls through the main-flow renderers, a `⠸ coder is working…` line while it runs and `✓ coder finished` / `✗ coder failed` with the result at the end. The dock, editor and footer stay where they are; a muted `agent coder › lister · model · effort` line on top marks it. While an agent is shown, `↑`/`↓` switch to another agent and `Enter`/`Esc` bring the main chat back (the dock keeps the focus; `Esc` again returns to the editor). The upstream inline agent card and `/tasks` are unchanged; the dock is an addition.

- `apps/kimi-code/src/tui/components/chrome/agent-dock.ts`: `AgentDockComponent`, the rows, the selection, the `viewing` mode and the linger timers. It holds its own reference to each agent's activity record because the store drops foreground-only records once they end.
- `apps/kimi-code/src/tui/components/messages/agent-conversation.ts`: `AgentConversationComponent`, the agent's conversation rendered from its activity record (cached per record version).
- `apps/kimi-code/src/tui/components/messages/subagent-activity-lines.ts`: the tool-call header and body rendering shared with the `/tasks` activity viewer (moved out of `agent-activity-viewer.ts`).
- `apps/kimi-code/src/tui/controllers/agent-dock-controller.ts`: subscribes to the activity store, mounts the dock in `state.agentDockContainer`, and swaps the transcript slot — the UI's child in the regular layout, a `TranscriptView` under a replacement layout root in fullscreen — for the conversation and back.
- `apps/kimi-code/src/tui/controllers/subagent-activity-store.ts`: `subscribe()` with `update` / `drop` / `clear` notifications (every mutation `bump`s the record and notifies); records carry the spawn `prompt`, read by `subagent-event-handler.ts` from the parent Agent tool call's arguments (`streamingUI.getActiveToolCall(parentToolCallId)?.args.prompt`).
- `apps/kimi-code/src/tui/tui-state.ts`, `kimi-tui.ts`: the `agentDockContainer` placed after the activity container in the regular layout, the fullscreen dock and the exit replay; the controller is reset with the session runtime (`resetSessionRuntimeState`) and disposed in `stop()`.
- `apps/kimi-code/src/tui/controllers/editor-keyboard.ts`: `onDownArrowEmpty` tries the dock first (`focusFromEditor()`), then the `/btw` panel as before.

The feature was written on Kimi Code 2.2.0 and merged onto 2.3.1 with `git am --3way` without conflicts; upstream's 2.3.x changes to `kimi-tui.ts` and `subagent-event-handler.ts` did not touch these lines.

Tests: apps/kimi-code `test/tui/components/chrome/agent-dock.test.ts`, `test/tui/components/messages/agent-conversation.test.ts`, the `subscribe` case in `test/tui/controllers/subagent-activity-store.test.ts`.

## When a patch conflicts

`update.sh` stops, leaves the new release in `source.next` with the patch half-applied, and keeps your current `kimi` running.

1. In `source.next`, `git status` lists the conflicted files.
2. Edit them so the feature works as described above. To have an AI agent do it, ask: "Resolve the git am conflict in source.next using custom/FEATURES.md."
3. Run `git add <files>`, then `git am --continue`. Repeat this for each later patch that conflicts. If upstream now does the same thing itself, run `git am --skip` instead.
4. Run `sh scripts/update.sh --continue`.

The update then rewrites `patches/` from the resolved code, so the next release starts from the fixed version.

Every patch can apply and the typecheck or a test still fail, for example because upstream renamed something a patch uses. In that case, fix it in `source.next` and fold the fix into the commit of the feature it belongs to, so that each feature stays one patch. Run `git commit --fixup=<that feature's commit>`, then `git rebase --autosquash "@moonshot-ai/kimi-code@<version>"`, then `sh scripts/update.sh --continue`.

## Changing or adding a feature

1. Commit the change on top of the branch in `source/`.
2. From the CustomKIMI folder, run `sh scripts/update.sh --save`. It rewrites `patches/` from the commits in `source/` and keeps the previous set in `history/`.
3. Describe the feature in this file, with its files and tests, like the entries above.
4. Optionally, run `sh scripts/update.sh "$(cat custom/BASE_VERSION)"` to rebuild from scratch and run the tests.

To run a feature's tests by hand the way `update.sh` does, give them a throwaway Kimi home and no network beyond localhost:

```sh
env KIMI_CODE_HOME="$(mktemp -d)" NODE_USE_ENV_PROXY=1 HTTP_PROXY=http://127.0.0.1:9 HTTPS_PROXY=http://127.0.0.1:9 \
  NO_PROXY=localhost,127.0.0.1,::1 corepack pnpm -C <package> exec vitest run <test files>
```

Without that, some of upstream's tests read and write your real `~/.kimi-code`, and live settings from Kimi's servers make them fail. For example, the survey popup's model list makes 9 rating-survey tests in `kimi-tui-message-flow.test.ts` fail even on unpatched 2.3.1. Do not block Kimi's servers with `KIMI_CODE_BASE_URL` instead: it also changes which OAuth token the managed provider uses, and two title-generation tests in node-sdk's `sdk-rpc-client-v2.test.ts` then fail.

An update refuses to start while `source/` has uncommitted edits or commits that `--save` has not stored yet.
