---
name: two-birds-talking
description: >
  Daily async debrief between two LLM agents. Two models, two perspectives,
  one review window. v2 adds 48-hour lookback, configurable ground rules,
  retry logic, and rerun mode. Works with any two LLM APIs: Anthropic,
  OpenAI, xAI, Ollama, or any OpenAI-compatible endpoint.
license: MIT
compatibility: Requires bash, curl, python3. macOS or Linux. Cron for scheduling.
metadata:
  author: Dustin Pollock / cogpros
  version: "2.0.0"
---

# Two Birds Talking v2

Two LLM agents debrief each other daily. One asks, one answers, alternating who goes first. They read their own recent history for continuity and review a configurable lookback window instead of a single calendar day. The output is a growing record of observations, patterns, and pushback that no single model would produce alone.

Pollock 2026.

## What Changed in v2

| Feature | v1 | v2 |
|---------|----|----|
| Review scope | Today's context file | 48-hour lookback window (configurable) |
| Temporal awareness | None | Agents know which day is primary vs partial |
| Ground rules | Hardcoded | Configurable array in config.sh |
| API failures | Fatal on first error | 3 retries with backoff |
| Rerun | Not supported | `TWO_BIRDS_RERUN=1` preserves original |
| Context sources | Single directory | Multiple directories (colon-separated) |
| Midnight sessions | Not handled | Attributed to the day they started |

## Quick Start

1. Clone:
   ```bash
   git clone https://github.com/cogpros/two-birds-talking.git
   cd two-birds-talking
   ```

2. Set up your environment:
   ```bash
   cp .env.example .env
   chmod 600 .env
   # Edit .env with your API keys
   ```

3. Configure your agents:
   ```bash
   # Edit config.sh: agent names, models, providers, system prompts, ground rules
   ```

4. Run:
   ```bash
   chmod +x two-birds-talking.sh two-birds-sync.sh
   ./two-birds-talking.sh
   ```

5. Open `viewer.html` in your browser.

6. Schedule daily:
   ```bash
   crontab -e
   # 10 10 * * * cd /path/to/two-birds-talking && ./two-birds-talking.sh >> ./two-birds.log 2>&1
   ```

## Configuration

All configuration lives in `config.sh`. API keys live in `.env`.

### Agents

Each agent needs:
- **Name**: display name in transcripts
- **Provider**: `anthropic`, `openai`, or `ollama`
- **Model**: the model string your provider expects
- **Endpoint**: API URL
- **Key variable**: which `.env` variable holds the API key
- **System prompts**: one for asking, one for answering

### Review Window

| Variable | Default | Description |
|----------|---------|-------------|
| `LOOKBACK_DAYS` | `3` | Days of context to load (e.g., 3 = day-before-yesterday + yesterday + today) |
| `DAILY_CONTEXT_DIRS` | `""` | Colon-separated paths to directories with `YYYY-MM-DD.md` files |

The script automatically labels each day in the context:
- **Yesterday**: "primary review target"
- **Today**: "partial" (the day isn't over when the debrief runs)
- **Older days**: date only

### Ground Rules

The `GROUND_RULES` array in config.sh is injected into both agent system prompts. Edit, add, or remove rules. They are numbered automatically.

Default rules:
1. The user leads.
2. Check external gates before calling something avoided.
3. Measure what was produced.
4. Timestamps are king.
5. Stay grounded.
6. Talk like a mentor, not a researcher.
7. Do not invent systems the user did not ask for.

### Conversation Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `TURNS` | `5` | Number of exchanges per debrief (1-20) |
| `SYNTHESIZE` | `true` | Generate structured summary after conversation |
| `CONTEXT_WINDOW` | `3` | How many previous debriefs to include |
| `TEMPERATURE_ASK` | `0.7` | Temperature for questions |
| `TEMPERATURE_ANSWER` | `0.5` | Temperature for responses |
| `MAX_TOKENS_ASK` | `400` | Max tokens for questions |
| `MAX_TOKENS_ANSWER` | `600` | Max tokens for responses |

### Providers

| Provider value | Works with | Default endpoint |
|---------------|------------|-----------------|
| `anthropic` | Anthropic (Claude) | `https://api.anthropic.com/v1/messages` |
| `openai` | OpenAI, xAI, Groq, Together, any OpenAI-compatible | Set per provider |
| `ollama` | Local Ollama | `http://localhost:11434/v1/chat/completions` |

### Notifications

Set `NOTIFY_METHOD` in `config.sh`:
- `telegram`: sends a short ping via Telegram Bot API
- `discord`: sends a short message via Discord webhook
- `none`: no notification (default)

## Rerun Mode

To re-run today's debrief without overwriting the original:

```bash
TWO_BIRDS_RERUN=1 ./two-birds-talking.sh
```

Output goes to `YYYY-MM-DD-rerun.md`. The original stays untouched.

To inject extra context into a rerun:

```bash
TWO_BIRDS_EXTRA_CONTEXT_FILE=./notes.md TWO_BIRDS_RERUN=1 ./two-birds-talking.sh
```

## How It Works

1. Script checks if today's debrief exists (idempotent, unless rerun mode).
2. Computes the lookback window and loads context files from all configured directories.
3. Loads the last N debriefs for conversational continuity.
4. Odd days: Agent A opens. Even days: Agent B opens.
5. Both agents receive: temporal frame (which day is primary, which is partial), ground rules, and full context.
6. Agents take turns. Each turn sees the full conversation so far plus the context window.
7. On the final turn, the agent closes with their strongest observation.
8. Optional synthesis pass distills the conversation into key observations, patterns, action items, and one insight.
9. Transcript saved as `YYYY-MM-DD.md` with frontmatter (generated timestamp, review window).
10. Sync script embeds all debriefs into the HTML viewer.
11. Optional notification fires.

## Viewer

The newspaper-style viewer is a single HTML file. Configure branding via the `VIEWER_CONFIG` object at the top of `viewer.html`. The sync script embeds debrief data directly into the HTML, so it works offline with no server.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "FATAL: .env not found" | Missing environment file | `cp .env.example .env` and add keys |
| "FATAL: AGENT_A_API_KEY not set" | Key variable empty | Check `.env` has the right variable name |
| "[API error: invalid_api_key]" | Wrong or expired key | Regenerate key from provider dashboard |
| "[API error: model_not_found]" | Wrong model string | Check provider docs for exact model ID |
| "[API call failed: Expecting value]" | Endpoint wrong or unreachable | Verify endpoint URL and network access |
| "Debrief already exists. Skipping." | Already ran today | Use `TWO_BIRDS_RERUN=1` to force |
| Debrief exists but viewer empty | Sync didn't run | Run `./two-birds-sync.sh` manually |
| Cron runs but no output | Script erroring silently | Check the log file in your crontab redirect |
| macOS date errors | Wrong date syntax | Script auto-detects OS, but check `uname` output |
| "RETRY: Attempt N failed" | Transient API error | Script retries 3 times with 20s backoff |

## Why Two Models

A single model reviewing its own output is a mirror. Two different models with different training, different biases, and different blind spots create friction. The friction is the point. One catches what the other misses. Disagreement surfaces assumptions. Agreement after disagreement is convergence you can trust.

## Credits

Built by Dustin Pollock as part of the cogpros (cognitive prosthetics) research program.
Two Birds Talking is one primitive in a larger system for AI-augmented daily reflection.

MIT License.
