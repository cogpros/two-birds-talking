#!/usr/bin/env bash
# config.sh -- Two Birds Talking v2 configuration
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
AGENT_A_SYSTEM_ASK="You are ${AGENT_A_NAME}, one half of a daily async debrief. You are direct, analytical, and pattern-focused. You ask one question per turn. The question that matters most right now based on recent work. No filler."

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
AGENT_B_SYSTEM_ASK="You are ${AGENT_B_NAME}, one half of a daily async debrief. You are compressed, strategic, and direct. You ask one question per turn. Pointed, specific, and designed to draw out something the other agent can uniquely answer. No preamble."

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
MAX_TOKENS_ASK=400                    # Max tokens for questions.
MAX_TOKENS_ANSWER=600                 # Max tokens for answers.

# ============================================================
# REVIEW WINDOW (v2)
# ============================================================
# The debrief runs in the morning and reviews what happened BEFORE it ran.
# LOOKBACK_DAYS controls how many days of context to load.
# Default: 3 (day-before-yesterday + yesterday + today's partial).
# The script labels yesterday as primary, today as partial (morning assembly only).
LOOKBACK_DAYS=3

# ============================================================
# GROUND RULES
# ============================================================
# These rules are injected into both agent system prompts.
# Edit, add, or remove rules to match your setup.
# Each rule should be one line. They are numbered automatically.
GROUND_RULES=(
  "THE USER LEADS. The user decides what to work on. Do not score their day against anyone else's priorities."
  "CHECK EXTERNAL GATES BEFORE CALLING SOMETHING AVOIDED. If an item cannot move because of external dependencies, it is gated, not avoided. Name the gate."
  "MEASURE WHAT WAS PRODUCED. Start with what got done. A day that produces real output is not a failure because one item did not move."
  "TIMESTAMPS ARE KING. Every claim must reference actual timestamps from the context."
  "STAY GROUNDED. No pathologizing productive days. If you are going to call something out, show the evidence. If the evidence is not there, do not say it."
  "TALK LIKE A MENTOR, NOT A RESEARCHER. You are two people reviewing recent work. Not two academics studying a subject."
  "DO NOT INVENT SYSTEMS OR FEATURES THE USER DID NOT ASK FOR. If it was not requested, do not propose it and do not track its absence."
)

# ============================================================
# PATHS
# ============================================================
DEBRIEFS_DIR="./debriefs"             # Where markdown debrief files are stored.
VIEWER_FILE="./viewer.html"           # Path to the newspaper-style HTML viewer.

# Directories containing daily context files (YYYY-MM-DD.md).
# The script loads files from the lookback window across all listed directories.
# Separate multiple directories with colons. Leave empty to skip.
# Example: DAILY_CONTEXT_DIRS="./daily-memory:./second-source"
DAILY_CONTEXT_DIRS=""

# ============================================================
# NOTIFICATIONS
# ============================================================
NOTIFY_METHOD="none"                  # telegram | discord | none

# ============================================================
# VIEWER BRANDING
# ============================================================
# Customize the viewer by editing the VIEWER_CONFIG object
# at the top of the <script> section in viewer.html.
