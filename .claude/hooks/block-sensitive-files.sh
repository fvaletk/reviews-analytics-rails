#!/bin/bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

SENSITIVE_PATTERN='\.env[^a-zA-Z]|\.env$|GOOGLE_CLIENT|GOOGLE_OAUTH|GEMINI_API_KEY|RAILS_MASTER_KEY'

# Block Read/Write/Edit tool calls on .env files
if [ "$TOOL" != "Bash" ] && [ -n "$FILE" ]; then
  BASENAME=$(basename "$FILE")
  if echo "$BASENAME" | grep -qE '^\.env(\.|$)'; then
    echo "Blocked: $FILE is a sensitive credentials file and cannot be accessed by Claude." >&2
    exit 2
  fi
fi

# Block Bash commands that write credentials to .env files
if [ "$TOOL" = "Bash" ] && [ -n "$COMMAND" ]; then
  if echo "$COMMAND" | grep -qE '\.env' && echo "$COMMAND" | grep -qE '(>|cp |tee |write)'; then
    echo "Blocked: Bash command appears to write to a .env file. Claude must not write credentials to disk." >&2
    exit 2
  fi
  if echo "$COMMAND" | grep -qE "$SENSITIVE_PATTERN"; then
    echo "Blocked: Bash command contains sensitive credential patterns." >&2
    exit 2
  fi
fi

exit 0