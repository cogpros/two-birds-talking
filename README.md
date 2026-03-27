# Two Birds Talking v2

Daily async debrief between two LLM agents. Two models, two perspectives, one review window. They alternate who goes first, read their own history for continuity, and build a growing record of observations and pushback across days.

Pollock 2026.

## What it does

- **Two agents, daily conversation.** One opens, one answers. They alternate days. Configurable 1-20 turns per session.
- **48-hour lookback.** The debrief reviews a rolling window, not a calendar day. Yesterday is primary. Today is partial. No more calling a day "zero-session" when it hasn't happened yet.
- **Configurable ground rules.** An array of rules injected into both agent prompts. Edit them to match your setup.
- **Multi-turn dialogue.** Agents push back on each other, refine positions, and surface things neither would alone.
- **Persistent memory.** Each debrief reads the last N sessions for continuity. Patterns compound over days and weeks.
- **Retry logic.** Transient API failures get 3 retries with backoff instead of killing the session.
- **Rerun mode.** Re-run today's debrief without overwriting the original.
- **Newspaper-style viewer.** A self-contained HTML page that renders all debriefs in a readable, browsable format.
- **Any two LLMs.** Anthropic + xAI. Two Claudes. Claude + local Ollama. Any combination that has an API.

## Install

**Claude Code:**
```bash
cd ~/.claude/skills
git clone https://github.com/cogpros/two-birds-talking.git
```

**Standalone:**
```bash
git clone https://github.com/cogpros/two-birds-talking.git
cd two-birds-talking
```

## Setup

1. **Create your environment file:**
   ```bash
   cp .env.example .env
   chmod 600 .env
   ```

2. **Add your API keys to `.env`:**
   ```
   AGENT_A_API_KEY=sk-ant-your-key
   AGENT_B_API_KEY=sk-your-openai-key
   ```

3. **Edit `config.sh`:**
   - Name your agents
   - Set providers, models, and endpoints
   - Write system prompts that define each agent's voice
   - Edit ground rules to match your workflow
   - Set turn count (default: 5)
   - Point `DAILY_CONTEXT_DIRS` at your daily memory/context files
   - Configure notifications if desired

4. **Make scripts executable:**
   ```bash
   chmod +x two-birds-talking.sh two-birds-sync.sh
   ```

5. **Verify:**
   ```bash
   ./two-birds-talking.sh
   # Check debriefs/ for today's file
   # Open viewer.html in your browser
   ```

## Supported Providers

| Provider | `config.sh` value | Endpoint example |
|----------|-------------------|-----------------|
| Anthropic (Claude) | `anthropic` | `https://api.anthropic.com/v1/messages` |
| OpenAI | `openai` | `https://api.openai.com/v1/chat/completions` |
| xAI (Grok) | `openai` | `https://api.x.ai/v1/chat/completions` |
| Groq | `openai` | `https://api.groq.com/openai/v1/chat/completions` |
| Ollama (local) | `ollama` | `http://localhost:11434/v1/chat/completions` |

Any OpenAI-compatible API works with the `openai` provider type.

## The 48-Hour Lookback

v1 loaded "today's" context file. At 10am, that file was nearly empty because the day hadn't happened yet. The debrief was reviewing a blank page and drawing conclusions from it.

v2 loads a configurable window (default: 3 days). The script labels each day:
- **Yesterday**: primary review target (full day of data)
- **Today**: partial (only morning assembly data, day still in progress)
- **Day before**: catches late-night sessions that spill across midnight

Both agents and the synthesis pass receive this temporal frame. They know which data is complete and which is partial.

Set `LOOKBACK_DAYS` in `config.sh` to change the window. Point `DAILY_CONTEXT_DIRS` at one or more directories containing `YYYY-MM-DD.md` files (colon-separated for multiple sources).

## Ground Rules

The `GROUND_RULES` array in `config.sh` is injected into both agent system prompts. Edit, add, or remove rules to shape how the agents behave.

Default rules prevent common failure modes:
- Scoring the user's day against external priorities
- Calling gated items "avoided"
- Ignoring what was actually produced
- Making claims without timestamp evidence
- Inventing systems nobody asked for

## Rerun Mode

```bash
# Re-run without overwriting today's debrief
TWO_BIRDS_RERUN=1 ./two-birds-talking.sh

# Inject extra context into a rerun
TWO_BIRDS_EXTRA_CONTEXT_FILE=./notes.md TWO_BIRDS_RERUN=1 ./two-birds-talking.sh
```

Output goes to `YYYY-MM-DD-rerun.md`. The original stays untouched.

## Multi-Turn Dialogue

Set `TURNS` in `config.sh` (1-20, default 5). With `TURNS=1`, you get a single question and answer. With `TURNS=6`, the agents go back and forth three rounds each, building on each exchange.

The depth is where value appears. Single-turn produces summaries. Multi-turn produces friction, refinement, and discovery.

## Synthesis

Set `SYNTHESIZE="true"` in `config.sh` (default: on). After the conversation finishes, one agent distills the full transcript into structured sections:

- **Key Observations**: the most important things said
- **Patterns Flagged**: recurring themes, risks, trends across the review window
- **Action Items**: concrete next steps (only items not gated by external dependencies)
- **Insight**: one sentence, the sharpest takeaway

Set to `"false"` if you just want the raw conversation.

## Notifications

| Method | Setup |
|--------|-------|
| **Telegram** | Set `NOTIFY_METHOD="telegram"` in `config.sh`. Add `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` to `.env`. |
| **Discord** | Set `NOTIFY_METHOD="discord"` in `config.sh`. Add `DISCORD_WEBHOOK_URL` to `.env`. |
| **None** | Set `NOTIFY_METHOD="none"` (default). Debriefs save silently. |

## The Viewer

`viewer.html` is a self-contained newspaper-style page. No server needed. Open it in a browser.

- **Index page** lists all debriefs with a preview
- **Debrief pages** render the full conversation with navigation
- **Auto-syncs** after each run, or run `./two-birds-sync.sh` manually
- **Customize branding** via the `VIEWER_CONFIG` object in the `<script>` section

## Cron Scheduling

```bash
crontab -e

# Daily at 10:10 AM (after your morning context assembles)
10 10 * * * cd /path/to/two-birds-talking && ./two-birds-talking.sh >> ./two-birds.log 2>&1
```

The script is idempotent. If today's debrief already exists, it exits cleanly.

## Why Two Models

A single model reviewing its own output is a mirror. Two different models with different training, different biases, and different blind spots create friction. The friction is the point. One catches what the other misses. Disagreement surfaces assumptions. Agreement after disagreement is convergence you can trust.

## Security

- API keys live in `.env`, which is in `.gitignore`. Never committed.
- `umask 077` ensures debrief files are only readable by the owner.
- No telemetry. No analytics. No network calls except to the APIs you configure.
- Keys are passed via environment variables, never logged or written to debrief files.

## File Structure

```
two-birds-talking/
├── SKILL.md              # Agent Skills spec
├── README.md             # This file
├── LICENSE.txt            # MIT
├── .gitignore             # Ignores .env, debriefs/, .DS_Store
├── .env.example           # API key template
├── config.sh              # Agent config, ground rules, settings
├── two-birds-talking.sh   # Main script
├── two-birds-sync.sh      # Syncs debriefs into the HTML viewer
├── viewer.html            # Newspaper-style debrief reader
└── debriefs/              # Generated (gitignored)
    ├── 2026-03-26.md
    └── ...
```

## Origin

Built by Dustin Pollock as part of the [cogpros](https://github.com/cogpros) research program. Two agents debrief each other daily while the operator sleeps. The pattern turned out to be useful beyond its original context.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
