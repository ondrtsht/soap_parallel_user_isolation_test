#!/bin/bash
set -u

EXPECTED_USER="${1:-}"
EXPECTED_KEY="${2:-}"
RESPONSE_FILE="${3:-}"

if [ -z "$EXPECTED_USER" ] || [ -z "$EXPECTED_KEY" ] || [ -z "$RESPONSE_FILE" ]; then
  echo "Usage: $0 EXPECTED_USER EXPECTED_KEY RESPONSE_XML" >&2
  exit 2
fi

if [ ! -f "$RESPONSE_FILE" ]; then
  echo "NG: response file not found: $RESPONSE_FILE" >&2
  exit 2
fi

if command -v xmllint >/dev/null 2>&1; then
  ACTUAL_USER=$(xmllint --xpath 'string((//*[local-name()="userId"])[last()])' "$RESPONSE_FILE" 2>/dev/null)
  ACTUAL_KEY=$(xmllint --xpath 'string((//*[local-name()="requestKey"])[last()])' "$RESPONSE_FILE" 2>/dev/null)
else
  # Fallback for minimal environments. Prefer xmllint for production testing.
  ACTUAL_USER=$(sed -n 's:.*<[^>]*userId[^>]*>\([^<]*\)</[^>]*userId>.*:\1:p' "$RESPONSE_FILE" | tail -1)
  ACTUAL_KEY=$(sed -n 's:.*<[^>]*requestKey[^>]*>\([^<]*\)</[^>]*requestKey>.*:\1:p' "$RESPONSE_FILE" | tail -1)
fi

if [ "$EXPECTED_USER" = "$ACTUAL_USER" ] && [ "$EXPECTED_KEY" = "$ACTUAL_KEY" ]; then
  echo "OK expectedUser=$EXPECTED_USER actualUser=$ACTUAL_USER expectedKey=$EXPECTED_KEY actualKey=$ACTUAL_KEY"
  exit 0
fi

echo "NG expectedUser=$EXPECTED_USER actualUser=$ACTUAL_USER expectedKey=$EXPECTED_KEY actualKey=$ACTUAL_KEY"
exit 1
