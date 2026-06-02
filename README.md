# claude-statusline

Multi-line status bar for [Claude Code](https://claude.ai/code). Shows model, context usage, subscription limits (5h/7d), and token breakdown — updated live.

## Preview

![claude-statusline preview](preview.png)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mvinnicius22/claude-statusline/main/install.sh | bash
```

Or clone:

```bash
git clone https://github.com/mvinnicius22/claude-statusline.git
cd claude-statusline && ./install.sh
```

Open a new Claude Code tab or run `/statusline` to see it.

## Requirements

- bash 3.2+, jq, git (optional — hides the git segment if absent)
- macOS or Linux/WSL — Windows native not supported

## Configuration

Set env vars in the `command` field of `~/.claude/settings.json`:

```json
"command": "SL_7D=0 SL_ICONS=nerd ~/.claude/statusline.sh"
```

**Toggles**

| Variable | Default | Effect when `0` |
|---|---|---|
| `SL_CAVEMAN` | 1 | Hide caveman mode badge |
| `SL_GIT` | 1 | Hide git segment |
| `SL_CTX` | 1 | Hide context/cost line |
| `SL_LIMITS` | 1 | Hide 5h and 7d lines |
| `SL_7D` | 1 | Hide 7d line only |
| `SL_TOKENS` | 1 | Hide token breakdown line |
| `SL_DRIFT` | 1 | Hide session drift indicator |

**Icons** — set via `SL_ICONS`

| Value | Description |
|---|---|
| `emoji` | Default. Works with any font. |
| `nerd` | Nerd Font glyphs (`󰚩`, ``, ``). Requires a [Nerd Font](https://www.nerdfonts.com/). |
| `none` | No icons. |

## What each line shows

**Line 1 — identity**
- Model, reasoning effort, output style
- Directory, git branch, changed files count, ahead/behind upstream
- `🪨 CAVEMAN` badge when caveman mode is active
- `← origin` (dimmed) when the working directory drifted from where the session started — signals that context, CLAUDE.md, and memory were loaded from a different project

**Line 2 — context & cost**
- Context window usage bar + tokens remaining
- `$X.XX` — client-side estimate of what the session would cost at API list prices. On Pro/Max you are not billed this amount.

**Lines 3–4 — subscription limits** (Pro/Max only)
- 5-hour and 7-day usage windows with reset time and countdown
- Pace arrow: `↑` will exhaust the window early · `→` on pace · `↓` consuming below average

**Line 5 — token breakdown**
- `fresh` / `write` / `read` / `out` — cumulative session tokens by type
- `hit %` — cache hit rate (`read / total input`). Higher means more context served at 0.1× instead of full price. Green ≥70%, yellow ≥40%, red below.

## Uninstall

```bash
./uninstall.sh
```

Removes `statusLine` from `settings.json` (backup created) and cleans up installed files.

## License

MIT

## Author

Marcos Vinícius Rego Freire
