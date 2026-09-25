# auxiliary-model-launcher

Route Claude Code and Codex CLI to third-party model providers (Kimi Code,
DeepSeek, Z.AI GLM, StepFun) while leaving your existing Claude and ChatGPT
subscriptions untouched.

Windows only. Requires PowerShell 5.1 or later.

It leaves your existing `claude` and `codex` commands untouched.
Environment variables are set only inside the launcher process, and your
current directory never changes.

## Layout

```
auxiliary-model-launcher/
├── bin/                     Add this folder to PATH.
│   ├── claude-deepseek.cmd
│   ├── claude-glm.cmd
│   ├── claude-kimi.cmd
│   ├── claude-stepfun.cmd
│   ├── codex-glm.cmd
│   ├── codex-kimi.cmd
├── tools/
│   ├── claude/
│   │   └── launch.ps1       Bridge implementation for Claude Code.
│   └── codex/
│       └── launch.ps1       Bridge implementation for Codex.
├── routes/                  One folder per route: a reachable endpoint plus
│   │                        the API key and model IDs that go with it. The
│   │                        folder name IS the route name, and it is what
│   │                        the shim passes to launch.ps1. Copy or delete a
│   │                        folder to add or remove a route.
│   ├── kimi/
│   │   ├── apikey.txt       The API key, one line (you create this; it is
│   │   │                    gitignored). Or set <NAME>_API_KEY instead.
│   │   ├── claude.json      Claude Code settings fragment for this route.
│   │   └── codex.toml       Codex config.toml fragment for this route.
│   ├── deepseek/
│   │   ├── apikey.txt
│   │   └── claude.json      No codex.toml: Claude Code only.
│   ├── glm/
│   │   ├── apikey.txt
│   │   ├── claude.json
│   │   └── codex.toml
│   └── stepfun/
│       ├── apikey.txt
│       └── claude.json      No codex.toml: StepFun has no Responses API.
└── README.md
```

## How it works

Each route folder holds three files:

| File | Format | Holds |
|---|---|---|
| apikey.txt | plain text | The API key, single line (or the `<NAME>_API_KEY` env var) |
| claude.json | Claude Code settings.json | env vars: base URL, model names, effort |
| codex.toml | Codex config.toml | model, endpoint, extra keys |

`tools/<tool>/launch.ps1` reads the folder named by the shim, injects the API
key from apikey.txt, applies the tool-side fragment, and starts the tool.
Nothing else. The bridge scripts contain no route names and no endpoints.

## claude.json format

`routes/<name>/claude.json` follows the Claude Code settings.json format.
The env block is applied verbatim:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.kimi.ai/coding/",
    "ANTHROPIC_MODEL": "kimi-k3[1m]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "kimi-k3[1m]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "kimi-k3[1m]",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "kimi-k3[1m]",
    "ANTHROPIC_DEFAULT_FABLE_MODEL": "kimi-k3[1m]",
    "CLAUDE_CODE_SUBAGENT_MODEL": "k3-256k",
    "CLAUDE_CODE_EFFORT_LEVEL": "high"
  }
}
```

The API key is injected as `ANTHROPIC_AUTH_TOKEN` (Bearer) from apikey.txt
(or the `<NAME>_API_KEY` environment variable), so it is not part of this
file. It takes precedence over a saved claude.ai login immediately, while
`ANTHROPIC_API_KEY` would need a one-time approval and trigger a both-set
warning. Any other Claude Code env var can be added to the env block.

## codex.toml format

`routes/<name>/codex.toml` follows the Codex config.toml format, plus one
launcher-managed top-level key:

```toml
model = "k3"
base_url = "https://api.kimi.ai/coding/v1"
```

- `base_url` (required) is read by launch.ps1 and moved into the generated
  `[model_providers.<name>]` table.
- Everything else in the file is passed through verbatim into the profile.
- launch.ps1 writes `model_provider = "<name>"` itself. Do not add one.
- The API key is passed through the `AUX_PROVIDER_API_KEY` env var, so it
  never appears in this file.
- Put top-level keys first and any table sections after them.

launch.ps1 rewrites `%USERPROFILE%\.codex\<name>.config.toml` on every
launch. The plain `codex` command is never affected. An optional
`codex-models.json` in the route folder declares model metadata (context
window, reasoning levels) to Codex and silences the fallback-metadata
warning; launch.ps1 copies it to `%USERPROFILE%\.codex\<name>.models.json`
and points `model_catalog_json` at it.

## Bundled routes

A route is one reachable endpoint plus the API key and model IDs that go with
it. Bundle a second route when you want the same model family from a
different endpoint (pay-as-you-go instead of a coding plan, say), because
the endpoint, the key and the model IDs all change together.

| Route | Anthropic endpoint | OpenAI endpoint | Notes |
|---|---|---|---|
| kimi | https://api.kimi.ai/coding/ | https://api.kimi.ai/coding/v1 (responses) | Kimi Code subscription key from kimi.com. Aliases such as kimi-for-coding roll over to newer versions automatically. Note the model IDs differ per protocol: Claude Code uses `kimi-k3[1m]`, Codex uses `k3` / `k3-256k` / `kimi-for-coding`. |
| deepseek | https://api.deepseek.com/anthropic | none | All roles use deepseek-flash (1M context with the [1m] suffix). claude.json pins adaptive thinking off to avoid a known 400 error. |
| glm | https://api.z.ai/api/anthropic | https://api.z.ai/api/v1 (responses) | Requires a GLM Coding Plan subscription key, issued separately from pay-as-you-go keys. Pay-as-you-go platform keys use a different endpoint set and cannot use the Anthropic endpoint. Model catalog based on the official Z.AI Codex guide. |
| stepfun | https://api.stepfun.ai/step_plan | none | Claude Code only. All roles use step-5-preview (1M context) via the Step Plan endpoint. For the standard pay-as-you-go API instead, point `ANTHROPIC_BASE_URL` at `https://api.stepfun.ai/` (the pay-as-you-go base, not the `/step_plan` path) with a platform API key and a topped-up balance. No Responses API endpoint exists. |

## Setup

1. Extract the folder anywhere. Keep it out of OneDrive or other sync
   targets, because it will hold API keys.
2. For each route you use, create `routes/<name>/apikey.txt` with
   your API key on a single line, or set an environment variable named
   `<NAME>_API_KEY` (for example `KIMI_API_KEY`). The file wins when both
   exist. apikey.txt is gitignored; if a key ever leaks into a commit,
   revoke it at the provider first. Delete the route folders and shims you do not use.
3. Add `bin` to PATH. Run once in PowerShell, adjusting the path to match
   your extract location:

   ```powershell
   $p = [Environment]::GetEnvironmentVariable('Path','User')
   [Environment]::SetEnvironmentVariable('Path', "$p;C:\auxiliary-model-launcher\bin", 'User')
   ```

   Do not use `setx PATH "%PATH%;..."`. It bakes the merged system PATH into
   your user PATH and can truncate long values.

4. Open a new terminal and verify:

   ```
   claude-kimi       Claude Code on Kimi Code
   codex-kimi        Codex on Kimi Code
   claude-glm        Claude Code on GLM
   codex-glm         Codex on GLM
   claude            Your existing subscription, unchanged
   codex             Your existing subscription, unchanged
   ```

## Adding a route

1. Copy an existing folder under `routes/` and rename it. The folder name
   becomes the route name, and the shim passes that name to launch.ps1.
2. Paste the API key into apikey.txt.
3. Edit claude.json and codex.toml: endpoints and model names.
   Remove codex.toml for Claude-only routes.
4. Copy shims in `bin` (two lines each, replace `<name>`):

   ```bat
   @echo off
   powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\tools\claude\launch.ps1" <name> %*
   ```

## Cleanup

Removing one route:

1. Delete its folder under `routes/`.
2. Delete its shims in `bin/`.
3. Delete the generated files `%USERPROFILE%\.codex\<name>.config.toml` and,
   when it exists, `%USERPROFILE%\.codex\<name>.models.json`.

Uninstalling everything:

1. Delete the launcher folder and remove `bin` from PATH.
2. Under `%USERPROFILE%\.codex`, delete the `<name>.config.toml` and
   `<name>.models.json` files for the routes you used.

This launcher never writes to `%USERPROFILE%\.codex\config.toml` or
`auth.json`, so your existing Codex settings and login are unaffected.

## Support

If this project is useful, you can support its development.

- GitHub Sponsors https://github.com/sponsors/livingghost

