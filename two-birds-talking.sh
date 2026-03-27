#!/usr/bin/env bash
# two-birds-talking.sh v2 -- Daily async debrief between two LLM agents
# Agents alternate who asks first (odd days = A, even days = B).
# v2: 48-hour lookback window, configurable ground rules, rerun mode, retry logic.
# Works with Anthropic, OpenAI-compatible, and Ollama APIs.
# Pollock 2026. cogpros.
umask 077

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

# Detect OS for date commands (macOS vs Linux)
if [[ "$(uname)" == "Darwin" ]]; then
  date_offset() { date -v-${1}d '+%Y-%m-%d'; }
else
  date_offset() { date -d "$1 days ago" '+%Y-%m-%d'; }
fi

TODAY=$(date '+%Y-%m-%d')
DAY_NUM=$(date '+%-d')
IS_EVEN=$(( DAY_NUM % 2 ))

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }

# --- Load config ---
if [[ ! -f "$CONFIG_FILE" ]]; then
  log "FATAL: config.sh not found at $CONFIG_FILE"
  log "Copy config.sh from the repo and edit it."
  exit 1
fi
source "$CONFIG_FILE"

# --- Load env ---
if [[ ! -f "$ENV_FILE" ]]; then
  log "FATAL: .env not found at $ENV_FILE"
  log "Copy .env.example to .env and add your API keys."
  exit 1
fi
set -a
source "$ENV_FILE"
set +a

# --- Validate ---
AGENT_A_KEY="${!AGENT_A_KEY_VAR}"
AGENT_B_KEY="${!AGENT_B_KEY_VAR}"

if [[ -z "$AGENT_A_KEY" ]]; then
  log "FATAL: $AGENT_A_KEY_VAR not set in .env"
  exit 1
fi
if [[ -z "$AGENT_B_KEY" ]]; then
  log "FATAL: $AGENT_B_KEY_VAR not set in .env"
  exit 1
fi

# Clamp turns to 1-20
if [[ "$TURNS" -lt 1 ]]; then TURNS=1; fi
if [[ "$TURNS" -gt 20 ]]; then TURNS=20; fi

# --- Compute lookback dates ---
LOOKBACK_DAYS="${LOOKBACK_DAYS:-3}"
LOOKBACK_DATES=()
for (( i=LOOKBACK_DAYS-1; i>=0; i-- )); do
  LOOKBACK_DATES+=("$(date_offset "$i")")
done

YESTERDAY="$(date_offset 1)"
REVIEW_WINDOW="$(date_offset $((LOOKBACK_DAYS-1))) through ${TODAY} $(date '+%H:%M')"

log "Review window: $REVIEW_WINDOW"

# --- Create debriefs dir ---
mkdir -p "$DEBRIEFS_DIR"

# --- Rerun mode ---
OUTPUT_FILE="$DEBRIEFS_DIR/$TODAY.md"
if [[ "${TWO_BIRDS_RERUN:-0}" == "1" ]]; then
  OUTPUT_FILE="$DEBRIEFS_DIR/$TODAY-rerun.md"
  log "RERUN MODE: output to $OUTPUT_FILE"
else
  if [[ -f "$OUTPUT_FILE" ]]; then
    log "Debrief for $TODAY already exists. Skipping. Set TWO_BIRDS_RERUN=1 to force."
    exit 0
  fi
fi

# --- Load recent debriefs for context ---
RECENT_CONTEXT=""
RECENT_FILES=$(ls -1 "$DEBRIEFS_DIR"/*.md 2>/dev/null | sort -r | head -"$CONTEXT_WINDOW")
for f in $RECENT_FILES; do
  FNAME=$(basename "$f" .md)
  CONTENT=$(cat "$f")
  RECENT_CONTEXT+="--- Debrief $FNAME ---
$CONTENT

"
done

if [[ -z "$RECENT_CONTEXT" ]]; then
  RECENT_CONTEXT="No previous debriefs on file."
fi

# --- Load daily context from lookback window ---
DAILY_CONTEXT=""
if [[ -n "$DAILY_CONTEXT_DIRS" ]]; then
  IFS=':' read -ra CONTEXT_DIR_LIST <<< "$DAILY_CONTEXT_DIRS"
  for LOOKBACK_DATE in "${LOOKBACK_DATES[@]}"; do
    for CONTEXT_DIR in "${CONTEXT_DIR_LIST[@]}"; do
      CONTEXT_FILE="${CONTEXT_DIR}/${LOOKBACK_DATE}.md"
      if [[ -f "$CONTEXT_FILE" ]]; then
        if [[ "$LOOKBACK_DATE" == "$TODAY" ]]; then
          LABEL="${LOOKBACK_DATE} (today, partial)"
        elif [[ "$LOOKBACK_DATE" == "$YESTERDAY" ]]; then
          LABEL="${LOOKBACK_DATE} (yesterday, primary review target)"
        else
          LABEL="${LOOKBACK_DATE}"
        fi
        DAILY_CONTEXT="${DAILY_CONTEXT}
--- ${LABEL} ---
$(cat "$CONTEXT_FILE")
"
      fi
    done
  done
fi

# --- Build ground rules string ---
GROUND_RULES_STR=""
if [[ ${#GROUND_RULES[@]} -gt 0 ]]; then
  GROUND_RULES_STR="

GROUND RULES (non-negotiable):"
  for i in "${!GROUND_RULES[@]}"; do
    GROUND_RULES_STR+="
$((i+1)). ${GROUND_RULES[$i]}"
  done
fi

# --- Build temporal frame ---
TEMPORAL_FRAME="
TEMPORAL FRAME: This is the morning debrief for ${TODAY}. You are reviewing the past ${LOOKBACK_DAYS} days (${REVIEW_WINDOW}). Yesterday (${YESTERDAY}) contains the primary session data and is your main review target. Today (${TODAY}) is still in progress. Its context file, if present, contains only partial data. Do not evaluate today as complete. Do not call any day a 'zero-session day' unless its context file is both complete and empty.

Do not conflate work from separate sessions. A session that runs past midnight belongs to the day it started, not the day it ended. Check timestamps."

# --- Determine who goes first ---
if [[ "$IS_EVEN" -eq 0 ]]; then
  FIRST_NAME="$AGENT_B_NAME"
  FIRST_PROVIDER="$AGENT_B_PROVIDER"
  FIRST_MODEL="$AGENT_B_MODEL"
  FIRST_ENDPOINT="$AGENT_B_ENDPOINT"
  FIRST_KEY="$AGENT_B_KEY"
  FIRST_SYSTEM_ASK="$AGENT_B_SYSTEM_ASK"
  FIRST_SYSTEM_ANSWER="$AGENT_B_SYSTEM_ANSWER"
  SECOND_NAME="$AGENT_A_NAME"
  SECOND_PROVIDER="$AGENT_A_PROVIDER"
  SECOND_MODEL="$AGENT_A_MODEL"
  SECOND_ENDPOINT="$AGENT_A_ENDPOINT"
  SECOND_KEY="$AGENT_A_KEY"
  SECOND_SYSTEM_ASK="$AGENT_A_SYSTEM_ASK"
  SECOND_SYSTEM_ANSWER="$AGENT_A_SYSTEM_ANSWER"
else
  FIRST_NAME="$AGENT_A_NAME"
  FIRST_PROVIDER="$AGENT_A_PROVIDER"
  FIRST_MODEL="$AGENT_A_MODEL"
  FIRST_ENDPOINT="$AGENT_A_ENDPOINT"
  FIRST_KEY="$AGENT_A_KEY"
  FIRST_SYSTEM_ASK="$AGENT_A_SYSTEM_ASK"
  FIRST_SYSTEM_ANSWER="$AGENT_A_SYSTEM_ANSWER"
  SECOND_NAME="$AGENT_B_NAME"
  SECOND_PROVIDER="$AGENT_B_PROVIDER"
  SECOND_MODEL="$AGENT_B_MODEL"
  SECOND_ENDPOINT="$AGENT_B_ENDPOINT"
  SECOND_KEY="$AGENT_B_KEY"
  SECOND_SYSTEM_ASK="$AGENT_B_SYSTEM_ASK"
  SECOND_SYSTEM_ANSWER="$AGENT_B_SYSTEM_ANSWER"
fi

log "Today is $TODAY (day $DAY_NUM). $FIRST_NAME opens, $SECOND_NAME responds. $TURNS turn(s)."

# --- Shared context block ---
CONTEXT_BLOCK="Recent debriefs for continuity:
$RECENT_CONTEXT

Daily context (${REVIEW_WINDOW}):
${DAILY_CONTEXT:-No daily context provided.}

$(if [[ -n "${TWO_BIRDS_EXTRA_CONTEXT_FILE:-}" ]] && [[ -f "$TWO_BIRDS_EXTRA_CONTEXT_FILE" ]]; then echo "Additional context:"; cat "$TWO_BIRDS_EXTRA_CONTEXT_FILE"; fi)"

# --- Unified API caller ---
# call_api <provider> <endpoint> <api_key> <model> <system_msg> <user_msg> <temperature> <max_tokens>
call_api() {
  local provider="$1"
  local endpoint="$2"
  local api_key="$3"
  local model="$4"
  local system_msg="$5"
  local user_msg="$6"
  local temp="${7:-0.5}"
  local max_tok="${8:-500}"

  local sys_json usr_json
  sys_json=$(printf '%s' "$system_msg" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
  usr_json=$(printf '%s' "$user_msg" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')

  local payload response

  case "$provider" in
    anthropic)
      payload=$(cat <<JSONEOF
{
  "model": "$model",
  "max_tokens": $max_tok,
  "temperature": $temp,
  "system": $sys_json,
  "messages": [{"role": "user", "content": $usr_json}]
}
JSONEOF
)
      response=$(curl -s --max-time 120 -X POST "$endpoint" \
        -H "x-api-key: $api_key" \
        -H "anthropic-version: 2023-06-01" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null) || true

      echo "$response" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    if "content" in data:
        print(data["content"][0]["text"])
    elif "error" in data:
        print(f"[API error: {data[\"error\"][\"message\"]}]")
    else:
        print("[API call failed: unexpected response]")
except Exception as e:
    print(f"[API call failed: {e}]")
' 2>/dev/null
      ;;

    openai|ollama)
      payload=$(cat <<JSONEOF
{
  "model": "$model",
  "messages": [
    {"role": "system", "content": $sys_json},
    {"role": "user", "content": $usr_json}
  ],
  "temperature": $temp,
  "max_tokens": $max_tok
}
JSONEOF
)
      local auth_args=()
      if [[ "$provider" != "ollama" ]]; then
        auth_args=(-H "Authorization: Bearer $api_key")
      fi

      response=$(curl -s --max-time 120 -X POST "$endpoint" \
        "${auth_args[@]}" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null) || true

      echo "$response" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    if "choices" in data:
        print(data["choices"][0]["message"]["content"])
    elif "error" in data:
        msg = data["error"]
        if isinstance(msg, dict):
            msg = msg.get("message", str(msg))
        print(f"[API error: {msg}]")
    else:
        print("[API call failed: unexpected response]")
except Exception as e:
    print(f"[API call failed: {e}]")
' 2>/dev/null
      ;;

    *)
      echo "[Unknown provider: $provider]"
      ;;
  esac
}

# --- Check if result is an API error ---
is_api_error() {
  local result="$1"
  [[ -z "$result" ]] || [[ "$result" == *"[API call failed:"* ]] || [[ "$result" == *"[API error:"* ]] || [[ "$result" == *"[Unknown provider:"* ]]
}

# --- Call with retry ---
call_api_retry() {
  local max_retries=3
  local retry_delay=20
  local attempt=1
  local result

  while [[ $attempt -le $max_retries ]]; do
    result=$(call_api "$@")

    if is_api_error "$result"; then
      if [[ $attempt -lt $max_retries ]]; then
        log "RETRY: Attempt $attempt failed. Waiting ${retry_delay}s..."
        sleep "$retry_delay"
        attempt=$((attempt + 1))
      else
        log "RETRY: Failed after $max_retries attempts."
        echo "$result"
        return 1
      fi
    else
      echo "$result"
      return 0
    fi
  done
}

# --- Build the conversation ---
TRANSCRIPT=""

for (( turn=1; turn<=TURNS; turn++ )); do
  if (( turn % 2 == 1 )); then
    SPEAKER_NAME="$FIRST_NAME"
    SPEAKER_PROVIDER="$FIRST_PROVIDER"
    SPEAKER_MODEL="$FIRST_MODEL"
    SPEAKER_ENDPOINT="$FIRST_ENDPOINT"
    SPEAKER_KEY="$FIRST_KEY"
    OTHER_NAME="$SECOND_NAME"

    if [[ $turn -eq 1 ]]; then
      SPEAKER_SYSTEM="${FIRST_SYSTEM_ASK}${TEMPORAL_FRAME}${GROUND_RULES_STR}"
      PROMPT="You are generating today's debrief. You speak first. $OTHER_NAME will respond.

$CONTEXT_BLOCK

Based on the recent context and any patterns you see, open the conversation. Ask a question or make an observation that matters. No preamble."
    else
      SPEAKER_SYSTEM="${FIRST_SYSTEM_ANSWER}${TEMPORAL_FRAME}${GROUND_RULES_STR}"
      PROMPT="Continuing today's debrief. Here is the conversation so far:

$TRANSCRIPT

$CONTEXT_BLOCK

Respond to what $OTHER_NAME just said. Push back if you disagree. Build on what's working. Ask a follow-up or shift to what matters next. Keep it focused."
    fi
  else
    SPEAKER_NAME="$SECOND_NAME"
    SPEAKER_PROVIDER="$SECOND_PROVIDER"
    SPEAKER_MODEL="$SECOND_MODEL"
    SPEAKER_ENDPOINT="$SECOND_ENDPOINT"
    SPEAKER_KEY="$SECOND_KEY"
    OTHER_NAME="$FIRST_NAME"

    SPEAKER_SYSTEM="${SECOND_SYSTEM_ANSWER}${TEMPORAL_FRAME}${GROUND_RULES_STR}"
    PROMPT="Continuing today's debrief. Here is the conversation so far:

$TRANSCRIPT

$CONTEXT_BLOCK

Respond to what $OTHER_NAME just said. Push back if you disagree. Build on what's working. Ask a follow-up or shift to what matters next. Keep it focused."
  fi

  if [[ $turn -eq $TURNS ]]; then
    PROMPT="$PROMPT

This is the final turn. Close with your strongest observation or carry-forward."
  fi

  log "Turn $turn/$TURNS: $SPEAKER_NAME..."

  RESPONSE=$(call_api_retry "$SPEAKER_PROVIDER" "$SPEAKER_ENDPOINT" "$SPEAKER_KEY" \
    "$SPEAKER_MODEL" "$SPEAKER_SYSTEM" "$PROMPT" \
    "$([ $turn -eq 1 ] && echo $TEMPERATURE_ASK || echo $TEMPERATURE_ANSWER)" \
    "$([ $turn -eq 1 ] && echo $MAX_TOKENS_ASK || echo $MAX_TOKENS_ANSWER)")

  if is_api_error "$RESPONSE"; then
    log "WARNING: $SPEAKER_NAME turn $turn returned: $RESPONSE"
    if [[ $turn -eq 1 ]]; then
      log "FATAL: Cannot start conversation. Exiting."
      exit 1
    fi
    log "Ending conversation early at turn $((turn - 1))."
    break
  fi

  TRANSCRIPT+="**${SPEAKER_NAME} (Turn ${turn}):**

${RESPONSE}

---

"

  log "Turn $turn complete."
done

if [[ -z "$TRANSCRIPT" ]]; then
  log "FATAL: No conversation generated."
  exit 1
fi

# --- Synthesis pass (optional) ---
SYNTHESIS=""
if [[ "$SYNTHESIZE" == "true" ]] && [[ -n "$TRANSCRIPT" ]]; then
  log "Running synthesis pass..."

  SYNTH_SYSTEM="${FIRST_SYSTEM_ANSWER} You are synthesizing a debrief into honest, grounded feedback. Be concrete, specific, and actionable.${TEMPORAL_FRAME}${GROUND_RULES_STR}"

  SYNTH_PROMPT="Here is today's full debrief between $FIRST_NAME and $SECOND_NAME:

$TRANSCRIPT

And here is the context that informed the conversation:
$CONTEXT_BLOCK

Distill this conversation into four sections. Be specific, not generic. Pull exact phrases and observations from the transcript. Summarize activity across the review window with yesterday (${YESTERDAY}) as the primary focus. Note any items from today's partial context separately.

## Key Observations
- (3-5 bullets: the most important things said)

## Patterns Flagged
- (recurring themes, risks, or trends noticed across the review window)

## Action Items
- (concrete next steps that emerged, only items not gated by external dependencies)

## Insight
(One sentence. The single sharpest takeaway from this conversation.)"

  SYNTHESIS=$(call_api_retry "$FIRST_PROVIDER" "$FIRST_ENDPOINT" "$FIRST_KEY" \
    "$FIRST_MODEL" "$SYNTH_SYSTEM" "$SYNTH_PROMPT" 0.3 1000)

  if is_api_error "$SYNTHESIS"; then
    log "ERROR: Synthesis failed. Response: $SYNTHESIS"
    SYNTHESIS="[Synthesis failed. Check logs.]"
  else
    log "Synthesis complete."
  fi
fi

# --- Save to file ---
TRANSCRIPT_FILE=$(mktemp /tmp/tbt-transcript.XXXXXX)
SYNTHESIS_FILE=$(mktemp /tmp/tbt-synthesis.XXXXXX)
printf '%s' "$TRANSCRIPT" > "$TRANSCRIPT_FILE"
printf '%s' "$SYNTHESIS" > "$SYNTHESIS_FILE"

python3 - "$OUTPUT_FILE" "$FIRST_NAME" "$SECOND_NAME" "$TURNS" "$REVIEW_WINDOW" "$TRANSCRIPT_FILE" "$SYNTHESIS_FILE" << 'PYEOF'
import sys
from datetime import datetime

path = sys.argv[1]
first = sys.argv[2]
second = sys.argv[3]
turns = sys.argv[4]
window = sys.argv[5]

with open(sys.argv[6]) as f:
    transcript = f.read()
with open(sys.argv[7]) as f:
    synthesis = f.read()

date_str = datetime.now().strftime("%B %d, %Y")
generated = datetime.now().isoformat()

content = f"""---
generated: {generated}
review_window: {window}
---

# Two Birds Talking -- {date_str}
**{first}** opens, **{second}** responds. {turns} turn(s). Review window: {window}.

---

## Transcript

{transcript}

## Synthesis

{synthesis}
"""

with open(path, "w") as f:
    f.write(content)
PYEOF

rm -f "$TRANSCRIPT_FILE" "$SYNTHESIS_FILE"

if [[ ! -f "$OUTPUT_FILE" ]]; then
  log "FATAL: Failed to save debrief file"
  exit 1
fi

log "Debrief saved to $OUTPUT_FILE"

# --- Sync to viewer ---
SYNC_SCRIPT="$SCRIPT_DIR/two-birds-sync.sh"
if [[ -x "$SYNC_SCRIPT" ]]; then
  SYNC_OUT=$(bash "$SYNC_SCRIPT" 2>&1)
  if [[ $? -eq 0 ]]; then
    log "Viewer synced. $SYNC_OUT"
  else
    log "Viewer sync failed (non-fatal): $SYNC_OUT"
  fi
fi

# --- Notify ---
case "$NOTIFY_METHOD" in
  telegram)
    if [[ -n "$TELEGRAM_BOT_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]]; then
      curl -s --max-time 10 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=Two Birds Talking -- ${TODAY}. ${FIRST_NAME} opened, ${SECOND_NAME} responded. ${TURNS} turns. Window: ${REVIEW_WINDOW}." \
        >/dev/null 2>&1 || true
      log "Telegram notification sent."
    else
      log "Telegram configured but tokens missing. Skipping notification."
    fi
    ;;
  discord)
    if [[ -n "$DISCORD_WEBHOOK_URL" ]]; then
      discord_msg=$(printf '%s' "Two Birds Talking -- ${TODAY}. ${FIRST_NAME} opened, ${SECOND_NAME} responded. ${TURNS} turns." | python3 -c 'import sys,json; print(json.dumps({"content": sys.stdin.read()}))')
      curl -s --max-time 10 -X POST "$DISCORD_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$discord_msg" \
        >/dev/null 2>&1 || true
      log "Discord notification sent."
    else
      log "Discord configured but webhook URL missing. Skipping notification."
    fi
    ;;
  none|*)
    ;;
esac

log "Two Birds Talking complete."
