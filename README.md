# Two Birds Talking

Daily async debrief between two LLM agents. They alternate who goes first, read their own history for continuity, and build a growing record of observations and pushback across days.

## What it does

- **Two agents, daily conversation.** One opens, one responds. They alternate days. Configurable 1-20 turns per session.
- **Multi-turn dialogue.** Not just Q&A. Agents push back on each other, refine positions, and surface things neither would alone.
- **Persistent memory.** Each debrief reads the last N sessions for continuity. Patterns compound over days and weeks.
- **Newspaper-style viewer.** A self-contained HTML page that renders all debriefs in a readable, browsable format.
- **Any two LLMs.** Anthropic + OpenAI. Two Claudes. Claude + local Ollama. Any combination that has an API.

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
   - Set turn count (default: 5)
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
| Ollama (local) | `ollama` | `http://localhost:11434/v1/chat/completions` |

Any OpenAI-compatible API works with the `openai` provider type.

## Multi-Turn Dialogue

Set `TURNS` in `config.sh` (1-20, default 5). With `TURNS=1`, you get a single question and answer. With `TURNS=6`, the agents go back and forth three rounds each, building on each exchange.

The depth is where value appears. Single-turn produces summaries. Multi-turn produces friction, refinement, and discovery.

## Synthesis

Set `SYNTHESIZE="true"` in `config.sh` (default: on). After the conversation finishes, one agent distills the full transcript into structured sections:

- **Key Observations** -- the most important things said
- **Patterns Flagged** -- recurring themes, risks, trends
- **Action Items** -- concrete next steps that emerged
- **Insight** -- one sentence, the sharpest takeaway

Set to `"false"` if you just want the raw conversation.

## Notifications

| Method | Setup |
|--------|-------|
| **Telegram** | Set `NOTIFY_METHOD="telegram"` in `config.sh`. Add `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` to `.env`. Create a bot via [@BotFather](https://t.me/BotFather). |
| **Discord** | Set `NOTIFY_METHOD="discord"` in `config.sh`. Add `DISCORD_WEBHOOK_URL` to `.env`. Create a webhook in your Discord channel settings. |
| **None** | Set `NOTIFY_METHOD="none"` (default). Debriefs save silently. |

Notifications are short pings ("Two Birds Talking -- 2026-03-19. Corvus opened, Strix responded. 5 turns."). Full content lives in the viewer.

## The Viewer

`viewer.html` is a self-contained newspaper-style page. No server needed. Just open it in a browser.

- **Index page** lists all debriefs with a preview of the opening line.
- **Debrief pages** render the full conversation with navigation between days.
- **Auto-syncs** after each cron run. Or run `./two-birds-sync.sh` manually.
- **Customize branding** by editing the `VIEWER_CONFIG` object at the top of the `<script>` section.

## Cron Scheduling

```bash
crontab -e

# Daily at 6:15 AM
15 6 * * * cd /path/to/two-birds-talking && ./two-birds-talking.sh >> /tmp/two-birds.log 2>&1
```

The script is idempotent. If today's debrief already exists, it exits cleanly. Safe to re-run.

## Security

- API keys live in `.env`, which is in `.gitignore`. Never committed.
- `umask 077` ensures debrief files are only readable by the owner.
- No telemetry. No analytics. No network calls except to the APIs you configure.
- Keys are passed via environment variables, never logged or written to debrief files.

## Limitations

- The viewer is static HTML. Large numbers of debriefs (hundreds) may slow initial load.

## File Structure

```
two-birds-talking/
├── SKILL.md              # Agent Skills spec
├── README.md             # This file
├── LICENSE.txt            # MIT
├── .gitignore             # Ignores .env, debriefs/, .DS_Store
├── .env.example           # API key template
├── config.sh              # Agent names, models, prompts, settings
├── two-birds-talking.sh   # Main script
├── two-birds-sync.sh      # Syncs debriefs into the HTML viewer
├── viewer.html            # Newspaper-style debrief reader
└── debriefs/              # Generated (gitignored)
    ├── 2026-03-18.md
    ├── 2026-03-19.md
    └── ...
```

## Origin

Built by [Raven Systems](https://github.com/cogpros) as part of a cognitive prosthetic infrastructure. Two agents debrief each other daily while the operator sleeps. The pattern turned out to be useful beyond its original context.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
