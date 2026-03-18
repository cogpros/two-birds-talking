---
name: two-birds-talking
description: >
  Daily async debrief between two LLM agents. One opens the conversation, the
  other responds, alternating days. Supports multi-turn dialogue (1-20 turns)
  where agents push back, refine, and build on each other's observations.
  Reads recent debriefs for continuity. Includes a newspaper-style HTML viewer
  and configurable notifications (Telegram, Discord, or none). Works with any
  two LLM APIs: Anthropic, OpenAI, xAI, Ollama, or any OpenAI-compatible endpoint.
license: MIT
compatibility: Requires bash, curl, python3. macOS or Linux. Cron for scheduling.
metadata:
  author: cogpros
  version: "1.0.0"
---

# Two Birds Talking

Two LLM agents debrief each other daily. One asks, one answers, alternating who goes first. They read their own recent history for continuity. The output is a growing record of observations, patterns, and pushback that no single model would produce alone.

## Quick Start

1. Clone into your skills directory or anywhere on your machine:
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
   # Edit config.sh -- set agent names, models, providers, system prompts
   ```

4. Make scripts executable and run:
   ```bash
   chmod +x two-birds-talking.sh two-birds-sync.sh
   ./two-birds-talking.sh
   ```

5. Open `viewer.html` in your browser to read the debrief.

6. Set up daily cron:
   ```bash
   crontab -e
   # Add:
   # 15 6 * * * cd /path/to/two-birds-talking && ./two-birds-talking.sh >> /tmp/two-birds.log 2>&1
   ```

## Configuration

All configuration lives in `config.sh`. API keys live in `.env`.

### Agents

Each agent needs:
- **Name** -- display name in transcripts
- **Provider** -- `anthropic`, `openai`, or `ollama`
- **Model** -- the model string your provider expects
- **Endpoint** -- API URL
- **Key variable** -- which `.env` variable holds the API key
- **System prompts** -- one for asking, one for answering

### Conversation Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `TURNS` | `5` | Number of exchanges per debrief (1-20) |
| `CONTEXT_WINDOW` | `3` | How many previous debriefs to include as context |
| `TEMPERATURE_ASK` | `0.7` | Temperature for questions/observations |
| `TEMPERATURE_ANSWER` | `0.5` | Temperature for responses |
| `MAX_TOKENS_ASK` | `300` | Max tokens for questions |
| `MAX_TOKENS_ANSWER` | `500` | Max tokens for responses |

### Providers

| Provider value | Works with | Default endpoint |
|---------------|------------|-----------------|
| `anthropic` | Anthropic (Claude) | `https://api.anthropic.com/v1/messages` |
| `openai` | OpenAI, xAI, any OpenAI-compatible | Set per provider |
| `ollama` | Local Ollama | `http://localhost:11434/v1/chat/completions` |

### Notifications

Set `NOTIFY_METHOD` in `config.sh`:
- `telegram` -- sends a short ping via Telegram Bot API
- `discord` -- sends a short message via Discord webhook
- `none` -- no notification (default)

### Viewer

The newspaper-style viewer is configured via the `VIEWER_CONFIG` object at the top of `viewer.html`. Change the title, subtitle, org name, and footer to match your setup.

## How It Works

1. Script checks if today's debrief already exists (idempotent).
2. Loads the last N debriefs for conversational continuity.
3. Odd days: Agent A opens. Even days: Agent B opens.
4. Agents take turns for the configured number of rounds. Each turn sees the full conversation so far plus the context window.
5. On the final turn, the agent is prompted to close with their strongest observation.
6. Transcript is saved as `YYYY-MM-DD.md` in the debriefs directory.
7. Sync script embeds all debriefs into the HTML viewer.
8. Optional notification fires.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "FATAL: .env not found" | Missing environment file | `cp .env.example .env` and add keys |
| "FATAL: AGENT_A_API_KEY not set" | Key variable empty | Check `.env` has the right variable name |
| "[API error: invalid_api_key]" | Wrong or expired key | Regenerate key from provider dashboard |
| "[API error: model_not_found]" | Wrong model string | Check provider docs for exact model ID |
| "API call failed: Expecting value" | Endpoint wrong or unreachable | Verify endpoint URL and network access |
| Debrief exists but viewer is empty | Sync didn't run | Run `./two-birds-sync.sh` manually |
| Cron runs but no output | Script erroring silently | Check the log file in your crontab redirect |
