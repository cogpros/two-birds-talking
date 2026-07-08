# Two Birds Talking v2

**Archived 2026-07-08.** This repo is no longer maintained. See below.

## Why archived

Two Birds Talking's evaluation mechanism, two owls reading independently and a rift step comparing their reads, has been folded into [cogpros/finnskogarna](https://github.com/cogpros/finnskogarna) as its **Phase 3.5, Evaluation** stage, as of finnskogarna v0.7.0 (2026-07-08).

This repo's original design was a **sequential hand-off**: one agent opens, reads, and hands off to the next, who reads and responds in turn. The fold re-cut that to **blind-parallel-plus-rift**: both owls read independently with no hand-off, then a rift step compares the two independent reads. The re-cut happened because running the evaluation as a standalone daily ritual competed for its own operator slot, rather than living inside the fold it was meant to evaluate. Folding it into finnskogarna put the evaluation where the thing it evaluates actually happens.

See `HISTORY.md` in [cogpros/finnskogarna](https://github.com/cogpros/finnskogarna). The Two Birds section under the v0.7.0 entry has the full evolution narrative.

---

## What this tool did (historical reference)

Daily async debrief between two LLM agents. Two models, two perspectives, one review window. They alternated who went first, read their own history for continuity, and built a growing record of observations and pushback across days.

Pollock 2026.

### Features

- **Two agents, daily conversation.** One opens, one answers. They alternate days. Configurable 1-20 turns per session.
- **48-hour lookback.** The debrief reviewed a rolling window, not a calendar day, so a run at 10am wasn't drawing conclusions from an empty "today" file. Default window 3 days: yesterday (primary, full day), today (partial), day before (catches late-night sessions spilling across midnight). Configurable via `LOOKBACK_DAYS`.
- **Configurable ground rules.** An array of rules injected into both agent prompts, editable per setup. Defaults guarded against scoring the day against external priorities, calling gated items "avoided," ignoring what was actually produced, claims without timestamp evidence, and inventing systems nobody asked for.
- **Multi-turn dialogue.** Agents pushed back on each other, refined positions, and surfaced things neither would alone. `TURNS` in `config.sh` (1-20, default 5).
- **Persistent memory.** Each debrief read the last N sessions for continuity.
- **Retry logic.** Transient API failures got 3 retries with backoff.
- **Rerun mode.** `TWO_BIRDS_RERUN=1 ./two-birds-talking.sh` re-ran today's debrief to `YYYY-MM-DD-rerun.md` without overwriting the original.
- **Synthesis.** One agent distilled the transcript into Key Observations, Patterns Flagged, Action Items, and a one-sentence Insight.
- **Newspaper-style viewer.** `viewer.html`, a self-contained HTML page rendering all debriefs, browsable, no server needed.
- **Any two LLMs.** Anthropic, xAI, OpenAI, Groq, or any OpenAI-compatible endpoint including local Ollama, in any combination.

### Why two models

A single model reviewing its own output is a mirror. Two different models with different training, different biases, and different blind spots create friction. The friction was the point. One catches what the other misses. Disagreement surfaces assumptions. Agreement after disagreement is convergence you can trust.

### File structure

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

### Security

- API keys lived in `.env`, which was in `.gitignore`. Never committed.
- `umask 077` ensured debrief files were only readable by the owner.
- No telemetry. No analytics. No network calls except to the configured APIs.

## Origin

Built by Dustin Pollock as part of the [cogpros](https://github.com/cogpros) research program. Two agents debriefed each other daily while the operator slept. The pattern turned out to be useful beyond its original context, which is why it now lives inside finnskogarna instead of running standalone.

See also: [hugr-solve](https://github.com/cogpros/hugr-solve), the heavier sibling. Same two-agent conversation engine, pointed at a single hard problem until convergence or deadlock.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
