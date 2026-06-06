#!/bin/bash
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

if [ -z "$FILE" ]; then
  exit 0
fi

# Normalize path
FILE=$(basename "$FILE")

BLOCKED=(".env" ".env.local" ".env.production" ".env.development")

for blocked in "${BLOCKED[@]}"; do
  if [ "$FILE" = "$blocked" ]; then
    echo "Blocked: $FILE contains sensitive credentials and cannot be read by Claude." >&2
    exit 2
  fi
done

exit 0