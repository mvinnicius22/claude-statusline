# claude-statusline

A multi-line status bar for [Claude Code](https://claude.ai/code) that shows model, context usage, subscription limits, and token breakdown — live, in the terminal.

## Preview

```
🪨 CAVEMAN │ 🤖 Opus 4.8 ⚡high · default │ 📁 myproject on 🌿 main (2 changed)
ctx █░░░░░░░░░  11% · 890k left · $4.92
5h  ██████░░░░  66% · 34% left · ↺ 15:50 (3h04m) →
7d  ██░░░░░░░░  26% · 74% left · ↺ Fri 11:00
tok fresh 24.9k · write 252k · read 9.3M · out 175k · hit 92%
```

When Claude Code's working directory drifts from where the session started, a discrete `← origin` indicator appears on line 1:

```
🤖 Opus 4.8 ⚡high · default │ 📁 claude-statusline on 🌿 main ← cpp-platform
```

Lines 3–4 (`5h`/`7d`) only appear on Pro/Max plans where Claude Code provides rate limit data.

## What each field means

**Line 1 — identity**
- `🪨 CAVEMAN` — caveman plugin mode badge (only if active). Hidden otherwise.
- `🤖 Opus 4.8` — model · `⚡high` reasoning effort · current output style.
- `📁 proj on 🌿 branch (N changed)` — directory, git branch, count of changed files, plus `↑/↓` commits ahead/behind upstream.
- `← origin` — session drift indicator. Appears (dimmed) when Claude Code's working directory has changed since the session started. Signals that the session context (CLAUDE.md, gitStatus, memory) was loaded from a different project, which affects cost relevance. Start a fresh session in the current directory to reset.

**Line 2 — context & cost**
- bar + `%` — share of the model's context window in use right now.
- `890k left` — tokens still free in the context window (exact count, not a rounded %).
- `$4.92` — `cost.total_cost_usd`: a **client-side estimate** Claude Code computes by multiplying the session's tokens by the model's list prices (input, output, and cache rates differ). It accumulates from the start of the session. On a **Pro/Max subscription you do not pay this** — it is a reference number ("what this would cost on the API"), not a charge.

**Lines 3–4 — subscription limits** (Pro/Max only, from `rate_limits` in stdin; no API call)
- bar + `%` used · `% left` of the 5-hour and 7-day usage windows.
- `↺ 15:50 (3h04m)` — when the window resets and the countdown.
- pace arrow: `→` on pace · `↑` you'll exhaust the window before it resets at the current rate · `↓` consuming slower than the window refills.

**Line 5 — session token breakdown** (cumulative, parsed from the transcript)
- `fresh` — new input tokens, billed at **1×**.
- `write` — tokens written to the prompt cache, billed at **1.25×** (5-min TTL) or **2×** (1-hour).
- `read` — tokens read back from cache (cache hits), billed at **0.1×**. This is normally the largest number: every turn re-reads the whole conversation from cache.
- `out` — tokens the model generated.
- `hit 92%` — **cache hit rate** = `read / (fresh + write + read)`. Higher is cheaper, more of your context is served from cache at 0.1× instead of paying full price. It drops when the context churns (files edited, tools change) and the cache is invalidated, forcing expensive re-writes. Green ≥70%, yellow ≥40%, red below.

## Requirements

- bash 3.2+
- jq
- git (optional — hides the git segment if absent)
- macOS or Linux (including WSL on Windows)

Windows native / PowerShell is not supported.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/<user>/claude-statusline/main/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/<user>/claude-statusline.git
cd claude-statusline
./install.sh
```

The installer:
1. Copies `statusline.sh` to `~/.claude/statusline.sh`
2. Backs up `~/.claude/settings.json`
3. Injects the `statusLine` block into `settings.json`

Open a new Claude Code tab or run `/statusline` to see it.

## Toggles

Set env vars in the `command` field of `settings.json`:

```json
"command": "SL_7D=0 SL_TOKENS=0 ~/.claude/statusline.sh"
```

| Variable | Default | Effect when set to `0` |
|---|---|---|
| `SL_CAVEMAN` | 1 | Hide caveman mode badge |
| `SL_GIT` | 1 | Hide git segment |
| `SL_CTX` | 1 | Hide context/cost line |
| `SL_LIMITS` | 1 | Hide 5h and 7d lines |
| `SL_7D` | 1 | Hide 7d line only |
| `SL_TOKENS` | 1 | Hide token breakdown line |
| `SL_DRIFT` | 1 | Hide session drift indicator (`← origin`) |

## Icons

| Value | Description |
|---|---|
| `SL_ICONS=emoji` | Default. Works with any font. |
| `SL_ICONS=nerd` | Nerd Font glyphs (`󰚩`, ``, ``). Requires a [Nerd Font](https://www.nerdfonts.com/) in your terminal. |
| `SL_ICONS=none` | No icons. |

Apply in `settings.json`:

```json
"command": "SL_ICONS=nerd ~/.claude/statusline.sh"
```

## Uninstall

```bash
./uninstall.sh
```

Removes `statusLine` from `settings.json` (backup created), deletes `statusline.sh`, and cleans up token cache files.

## Notes

- The 5h/7d values come from `rate_limits` in Claude Code's stdin — no API calls, no extra cost.
- Percentages reflect your actual subscription window usage. The reset time can differ by a minute or two across machines if you use multiple devices.
- There is no "absolute tokens available" number exposed — the context bar uses `context_window_size` from the session, not a subscription cap.

## License

MIT
