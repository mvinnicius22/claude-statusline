<div align="center">

# 🛰️ Vitals — a Statusline for Claude Code

**Your whole session at a glance: context, subscription limits, token economics, and git state — live, in the terminal.**

[![CI](https://github.com/mvinnicius22/claude-statusline/actions/workflows/ci.yml/badge.svg)](https://github.com/mvinnicius22/claude-statusline/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/platform-macOS%20%C2%B7%20Linux%20%C2%B7%20WSL-informational)
![License](https://img.shields.io/badge/license-MIT-green)
![Dependencies](https://img.shields.io/badge/deps-bash%20%2B%20jq-lightgrey)

</div>

---

## Preview

```text
🪨 CAVEMAN │ 🤖 Opus 4.8 ⚡high · default │ 📁 myproject on 🌿 main  A2 M3 D1 ?4
ctx █░░░░░░░░░  14% · 853k left · $4.92
5h  █████████░  95% ·  5% left · ↺ 15:50 (1h52m) ↑
7d  ██░░░░░░░░  28% · 72% left · ↺ Fri 11:00
tok fresh 6.5k · write 130k · read 834k · out 13.9k · hit 92%
```

Lines `5h` / `7d` appear only on **Pro/Max** plans, where Claude Code ships subscription usage in its data feed. On API/enterprise billing they're omitted and you keep the context + cost line.

When Claude Code's working directory drifts from where the session started, a dim `← origin` marker is appended to line 1, so you know the loaded context (CLAUDE.md, git state, memory) came from another project:

```text
🤖 Opus 4.8 ⚡high · default │ 📁 claude-statusline on 🌿 main ← cpp-platform
```

---

## What's on screen

Five lines, each independently toggleable. Here's what every token means.

### Line 1 — Identity

```text
🪨 CAVEMAN │ 🤖 Opus 4.8 ⚡high · default │ 📁 myproject on 🌿 main  A2 M3 D1 ?4
```

| Element | Meaning |
|---|---|
| `🪨 CAVEMAN` | The [caveman](https://github.com/juliusbrussee/caveman) plugin's active mode, read from `~/.claude/.caveman-active`. Shows the level (`CAVEMAN:ULTRA`) when not `full`. Hidden when the plugin is off. |
| `🤖 Opus 4.8` | Active model display name. |
| `⚡high` | Reasoning effort, color-coded: `low` green · `medium` yellow · `high` magenta · `xhigh`/`max` red. |
| `default` | Current output style. |
| `📁 myproject` | Current working directory (basename). |
| `🌿 main` | Git branch (or short SHA when detached). |
| `↑2 ↓1` | Commits ahead / behind the upstream branch. |
| `← origin` | Session-drift marker (see Preview). |

**Git change counts** — one letter per change type, only non-zero shown, colored by intent:

| Token | Type | Color |
|---|---|---|
| `A` | added / staged-new | green |
| `M` | modified | yellow |
| `D` | deleted | red |
| `R` | renamed | blue |
| `?` | untracked | gray |

So `A2 M3 D1 ?4` = 2 added, 3 modified, 1 deleted, 4 untracked. A brand-new file counts as `A`/`?`, not a vague "changed", and removals stand out in red.

### Line 2 — Context & cost

```text
ctx █░░░░░░░░░  14% · 853k left · $4.92
```

- **bar + `14%`** — share of the model's context window currently in use. The bar greens→yellows→reds as it fills (≥60% yellow, ≥80% red).
- **`853k left`** — exact tokens still free in the window, computed from `total_input_tokens` against `context_window_size` (not a rounded percentage, so it matches `/context`).
- **`$4.92` — session cost.** This is `cost.total_cost_usd`, a **client-side estimate** Claude Code computes by multiplying every token the session has processed by that model's list prices. Input, output, and the three cache rates are each priced differently (see below), then summed and accumulated from the first message of the session.
  - On a **Pro/Max subscription you are *not* billed this amount** — your plan is a flat fee. The number is a reference: *"what this session would have cost on the pay-as-you-go API."* Useful for spotting an expensive session, comparing workflows, or estimating an API port.
  - It resets per session and can differ from any real API invoice (client-side estimate, list prices).

### Lines 3–4 — Subscription usage limits

```text
5h  █████████░  95% ·  5% left · ↺ 15:50 (1h52m) ↑
7d  ██░░░░░░░░  28% · 72% left · ↺ Fri 11:00
```

Your real Pro/Max usage windows, read straight from `rate_limits` in Claude Code's data feed. **No API call, no token cost** — it's already in the feed.

- **bar + `% · % left`** — used and remaining share of the rolling 5-hour and 7-day windows. Same numbers you'd see on the usage page.
- **`↺ 15:50 (1h52m)`** — wall-clock reset time and a live countdown.
- **Pace arrow** — projects whether you'll run out *before* the window resets, by comparing how fast you're burning to a flat schedule:
  - the projection is `used% × (window ÷ elapsed)` — i.e. "at this rate, what % will I hit by reset time?"
  - `→` **on pace** (projected 85–115%): you'll finish the window roughly as it resets.
  - `↑` **too fast** (projected >115%, shown red): at the current rate you'll exhaust the window early — ease off if you need to last.
  - `↓` **slack** (projected <85%, green): you're consuming slower than the window refills, plenty of headroom.

> There is no absolute token quota exposed for subscription windows — Anthropic only reports a percentage, so the statusline shows `% left`, never a token count, for these lines.

### Line 5 — Session token breakdown

```text
tok fresh 6.5k · write 130k · read 834k · out 13.9k · hit 92%
```

Cumulative token counts for the session, parsed from the transcript and cached by file mtime (so a huge session isn't re-read every refresh). Each type is **billed at a different multiple of the base input price** — this line shows where your tokens actually go:

| Token | What it is | Billed at |
|---|---|---|
| `fresh` | New input tokens, never seen before | **1×** |
| `write` | Tokens written into the prompt cache | **1.25×** (5-min TTL) or **2×** (1-hour) |
| `read` | Tokens served from the prompt cache (cache hits) | **0.1×** |
| `out` | Tokens the model generated | output rate |

**Why `read` is usually the biggest number:** every turn re-sends the entire conversation, and Claude Code caches the stable prefix. After the first turn, most of that prefix is *re-read* from cache at 0.1× instead of paid fresh. That's the whole point of caching — it makes long sessions cheap.

- **`hit 92%` — cache hit rate** = `read ÷ (fresh + write + read)`. The share of your input that came from the cheap cache instead of full-price processing.
  - **Higher is better/cheaper.** A healthy Claude Code session sits high (80–95%+).
  - It **drops when the context churns** — editing files, tools changing, switching projects — which invalidates the cache and forces expensive re-writes (`write` at 1.25×). A sudden dip in `hit` is a signal you just paid to rebuild the cache.
  - Color: green ≥70%, yellow ≥40%, red below.

---

## Requirements

- **bash** 3.2+ (ships with macOS; standard on Linux/WSL)
- **jq** — required
- **git** — optional (the git segment simply hides if absent)
- **OS** — macOS, Linux, or Windows via WSL. Native Windows / PowerShell is not supported.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mvinnicius22/claude-statusline/main/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/mvinnicius22/claude-statusline.git
cd claude-statusline
./install.sh
```

The installer copies `statusline.sh` to `~/.claude/`, backs up `settings.json`, and injects the `statusLine` block. Open a new Claude Code tab or run `/statusline` to see it.

---

## Additional configuration

Everything is opt-out via environment variables set inside the `command` field of `settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "SL_7D=0 SL_ICONS=nerd ~/.claude/statusline.sh"
}
```

### Toggles

| Variable | Default | Set to `0` to… |
|---|:---:|---|
| `SL_CAVEMAN` | 1 | hide the caveman mode badge |
| `SL_GIT` | 1 | hide the git segment |
| `SL_CTX` | 1 | hide the context/cost line |
| `SL_LIMITS` | 1 | hide both 5h and 7d lines |
| `SL_7D` | 1 | hide only the 7d line |
| `SL_TOKENS` | 1 | hide the token breakdown line |
| `SL_DRIFT` | 1 | hide the `← origin` drift marker |

### Icons

| `SL_ICONS=` | Result |
|---|---|
| `emoji` *(default)* | 🤖 📁 🌿 — works with any font |
| `nerd` | Nerd Font glyphs (`󰚩`, ``, ``) — needs a [Nerd Font](https://www.nerdfonts.com/) in your terminal |
| `none` | no leading icons |

---

## How it works

- **Subscription limits and cost come from the data Claude Code already pipes to the statusline** — no network calls, no API key, no extra tokens spent.
- Limit percentages reflect your real usage window. The reset time can be off by a minute or two if you also use Claude on another machine (that usage isn't in the local data).
- The token breakdown is parsed from the session transcript and cached by mtime for speed.

## Uninstall

```bash
./uninstall.sh
```

Removes the `statusLine` block from `settings.json` (backup first), deletes `statusline.sh`, and clears the token caches.

## License

MIT

## Author

Marcos Vinicius
