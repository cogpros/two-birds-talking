#!/usr/bin/env bash
# config.sh -- Two Birds Talking configuration
# Edit this file to set up your agents, models, and preferences.

# ============================================================
# AGENT A
# ============================================================
AGENT_A_NAME="Corvus"
AGENT_A_PROVIDER="anthropic"          # anthropic | openai | ollama
AGENT_A_MODEL="claude-sonnet-4-6"
AGENT_A_ENDPOINT="https://api.anthropic.com/v1/messages"
AGENT_A_KEY_VAR="AGENT_A_API_KEY"     # Name of the env var in .env holding the key

# System prompt when Agent A asks a question
AGENT_A_SYSTEM_ASK="You are ${AGENT_A_NAME}, one half of a daily async debrief. You are direct, analytical, and pattern-focused. You ask one question per turn -- the question that matters most right now based on recent work. No filler."

# System prompt when Agent A answers a question
AGENT_A_SYSTEM_ANSWER="You are ${AGENT_A_NAME}, one half of a daily async debrief. You are direct, analytical, and pattern-focused. Answer in one focused paragraph, maybe two if the question demands it. No filler."

# ============================================================
# AGENT B
# ============================================================
AGENT_B_NAME="Strix"
AGENT_B_PROVIDER="openai"             # anthropic | openai | ollama
AGENT_B_MODEL="gpt-4o"
AGENT_B_ENDPOINT="https://api.openai.com/v1/chat/completions"
AGENT_B_KEY_VAR="AGENT_B_API_KEY"

# System prompt when Agent B asks a question
AGENT_B_SYSTEM_ASK="You are ${AGENT_B_NAME}, one half of a daily async debrief. You are compressed, strategic, and direct. You ask one question per turn -- pointed, specific, and designed to draw out something the other agent can uniquely answer. No preamble."

# System prompt when Agent B answers a question
AGENT_B_SYSTEM_ANSWER="You are ${AGENT_B_NAME}, one half of a daily async debrief. You are compressed, strategic, and direct. Answer in one focused paragraph, maybe two. Be specific."

# ============================================================
# CONVERSATION
# ============================================================
TURNS=5                               # Number of exchanges (1-20). Default: 5.
SYNTHESIZE="true"                     # Generate a structured summary after the conversation (true/false).
CONTEXT_WINDOW=3                      # How many previous debriefs to read for continuity.
TEMPERATURE_ASK=0.7                   # Temperature for generating questions.
TEMPERATURE_ANSWER=0.5                # Temperature for generating answers.
MAX_TOKENS_ASK=300                    # Max tokens for questions.
MAX_TOKENS_ANSWER=500                 # Max tokens for answers.

# ============================================================
# PATHS
# ============================================================
DEBRIEFS_DIR="./debriefs"             # Where markdown debrief files are stored.
VIEWER_FILE="./viewer.html"           # Path to the newspaper-style HTML viewer.

# Optional: path to a directory with daily context files (YYYY-MM-DD.md).
# If set and a file exists for today, its content is included in the prompt.
# Leave empty to skip.
DAILY_CONTEXT_DIR=""

# ============================================================
# NOTIFICATIONS
# ============================================================
NOTIFY_METHOD="none"                  # telegram | discord | none

# ============================================================
# VIEWER BRANDING
# ============================================================
# Customize the viewer by editing the VIEWER_CONFIG object
# at the top of the <script> section in viewer.html.
