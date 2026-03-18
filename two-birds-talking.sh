#!/usr/bin/env bash
# two-birds-talking.sh -- Daily async debrief between two LLM agents
# Agents alternate who asks first (odd days = A, even days = B).
# Supports multi-turn dialogue (configurable 1-20 turns).
# Works with Anthropic, OpenAI-compatible, and Ollama APIs.
set -e
umask 077

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

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

# --- Create debriefs dir ---
mkdir -p "$DEBRIEFS_DIR"

# --- Check if today's debrief exists ---
if [[ -f "$DEBRIEFS_DIR/$TODAY.md" ]]; then
  log "Debrief for $TODAY already exists. Skipping."
  exit 0
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

# --- Load daily context if configured ---
DAILY_CONTEXT=""
if [[ -n "$DAILY_CONTEXT_DIR" ]]; then
  DAILY_FILE="$DAILY_CONTEXT_DIR/${TODAY}.md"
  if [[ -f "$DAILY_FILE" ]]; then
    DAILY_CONTEXT=$(cat "$DAILY_FILE")
  fi
fi

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

Today's context (if available):
${DAILY_CONTEXT:-No daily context provided.}"

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
      response=$(curl -s -X POST "$endpoint" \
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
      # OpenAI-compatible format (works with OpenAI, xAI, Groq, Together, Ollama)
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

      response=$(curl -s -X POST "$endpoint" \
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

# --- Build the conversation ---
TRANSCRIPT=""
LAST_MESSAGE=""

for (( turn=1; turn<=TURNS; turn++ )); do
  if (( turn % 2 == 1 )); then
    # First agent speaks
    SPEAKER_NAME="$FIRST_NAME"
    SPEAKER_PROVIDER="$FIRST_PROVIDER"
    SPEAKER_MODEL="$FIRST_MODEL"
    SPEAKER_ENDPOINT="$FIRST_ENDPOINT"
    SPEAKER_KEY="$FIRST_KEY"
    OTHER_NAME="$SECOND_NAME"

    if [[ $turn -eq 1 ]]; then
      SPEAKER_SYSTEM="$FIRST_SYSTEM_ASK"
      PROMPT="You are generating today's debrief. You speak first. $OTHER_NAME will respond.

$CONTEXT_BLOCK

Based on the recent context and any patterns you see, open the conversation. Ask a question or make an observation that matters. No preamble."
    else
      SPEAKER_SYSTEM="$FIRST_SYSTEM_ANSWER"
      PROMPT="Continuing today's debrief. Here is the conversation so far:

$TRANSCRIPT

$CONTEXT_BLOCK

Respond to what $OTHER_NAME just said. Push back if you disagree. Build on what's working. Ask a follow-up or shift to what matters next. Keep it focused."
    fi
  else
    # Second agent speaks
    SPEAKER_NAME="$SECOND_NAME"
    SPEAKER_PROVIDER="$SECOND_PROVIDER"
    SPEAKER_MODEL="$SECOND_MODEL"
    SPEAKER_ENDPOINT="$SECOND_ENDPOINT"
    SPEAKER_KEY="$SECOND_KEY"
    OTHER_NAME="$FIRST_NAME"

    SPEAKER_SYSTEM="$SECOND_SYSTEM_ANSWER"
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

  RESPONSE=$(call_api "$SPEAKER_PROVIDER" "$SPEAKER_ENDPOINT" "$SPEAKER_KEY" \
    "$SPEAKER_MODEL" "$SPEAKER_SYSTEM" "$PROMPT" \
    "$([ $turn -eq 1 ] && echo $TEMPERATURE_ASK || echo $TEMPERATURE_ANSWER)" \
    "$([ $turn -eq 1 ] && echo $MAX_TOKENS_ASK || echo $MAX_TOKENS_ANSWER)")

  if [[ -z "$RESPONSE" ]] || [[ "$RESPONSE" == *"[API call failed:"* ]] || [[ "$RESPONSE" == *"[API error:"* ]] || [[ "$RESPONSE" == *"[Unknown provider:"* ]]; then
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

  SYNTH_PROMPT="Here is today's full debrief between $FIRST_NAME and $SECOND_NAME:

$TRANSCRIPT

Distill this conversation into four sections. Be specific, not generic. Pull exact phrases and observations from the transcript.

## Key Observations
- (3-5 bullets: the most important things said)

## Patterns Flagged
- (recurring themes, risks, or trends noticed)

## Action Items
- (concrete next steps that emerged)

## Insight
(One sentence. The single sharpest takeaway from this conversation.)"

  SYNTHESIS=$(call_api "$FIRST_PROVIDER" "$FIRST_ENDPOINT" "$FIRST_KEY" \
    "$FIRST_MODEL" "You are a precise analyst. Extract structure from conversation. No filler." \
    "$SYNTH_PROMPT" 0.3 800)

  if [[ -z "$SYNTHESIS" ]] || [[ "$SYNTHESIS" == *"[API call failed:"* ]] || [[ "$SYNTHESIS" == *"[API error:"* ]]; then
    log "ERROR: Synthesis failed. Response: $SYNTHESIS"
    SYNTHESIS="[Synthesis failed. Check logs.]"
  else
    log "Synthesis complete."
  fi
fi

# --- Save to file ---
cat > "$DEBRIEFS_DIR/$TODAY.md" << DEBRIEF_EOF
# Two Birds Talking -- $(date '+%B %d, %Y')
**$FIRST_NAME** opens, **$SECOND_NAME** responds. $TURNS turn(s).

---

$TRANSCRIPT
${SYNTHESIS:+---

$SYNTHESIS}
DEBRIEF_EOF

log "Debrief saved to $DEBRIEFS_DIR/$TODAY.md"

# --- Sync to viewer ---
SYNC_SCRIPT="$SCRIPT_DIR/two-birds-sync.sh"
if [[ -x "$SYNC_SCRIPT" ]]; then
  bash "$SYNC_SCRIPT" 2>/dev/null && log "Viewer synced." || log "Viewer sync failed (non-fatal)."
fi

# --- Notify ---
case "$NOTIFY_METHOD" in
  telegram)
    if [[ -n "$TELEGRAM_BOT_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]]; then
      curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=Two Birds Talking -- ${TODAY}. ${FIRST_NAME} opened, ${SECOND_NAME} responded. ${TURNS} turns." \
        >/dev/null 2>&1 || true
      log "Telegram notification sent."
    else
      log "Telegram configured but tokens missing. Skipping notification."
    fi
    ;;
  discord)
    if [[ -n "$DISCORD_WEBHOOK_URL" ]]; then
      local discord_msg
      discord_msg=$(printf '%s' "Two Birds Talking -- ${TODAY}. ${FIRST_NAME} opened, ${SECOND_NAME} responded. ${TURNS} turns." | python3 -c 'import sys,json; print(json.dumps({"content": sys.stdin.read()}))')
      curl -s -X POST "$DISCORD_WEBHOOK_URL" \
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
