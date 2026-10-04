#!/bin/bash
set -u

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
RESULT_DIR="$BASE_DIR/results"
mkdir -p "$RESULT_DIR"

if [ -f "$BASE_DIR/config.env" ]; then
  . "$BASE_DIR/config.env"
else
  echo "ERROR: config.env not found. Run: cp config.env.example config.env" >&2
  exit 2
fi

: "${SOAP_URL:?SOAP_URL is not set}"
: "${CURL_TIMEOUT:=30}"

START_NS=$(date +%s 2>/dev/null)

rm -f "$RESULT_DIR/response_A.xml" "$RESULT_DIR/response_B.xml"
rm -f "$RESULT_DIR/result_A.txt" "$RESULT_DIR/result_B.txt"

curl_args=(
  -sS
  --connect-timeout "$CURL_TIMEOUT"
  --max-time "$CURL_TIMEOUT"
  -H "Content-Type: text/xml; charset=utf-8"
)

if [ -n "${SOAP_ACTION:-}" ]; then
  curl_args+=( -H "SOAPAction: $SOAP_ACTION" )
fi

echo "Starting two requests in parallel..."
echo "SOAP_URL=$SOAP_URL"

{
  date '+%Y-%m-%dT%H:%M:%S.%3N START USER-A' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S START USER-A'
  curl "${curl_args[@]}" --data-binary @"$BASE_DIR/requests/request_A.xml" \
    "$SOAP_URL" > "$RESULT_DIR/response_A.xml" 2> "$RESULT_DIR/curl_A.err"
  rc=$?
  date '+%Y-%m-%dT%H:%M:%S.%3N END USER-A' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S END USER-A'
  echo "$rc" > "$RESULT_DIR/curl_A.rc"
} > "$RESULT_DIR/timing_A.log" 2>&1 &
PID_A=$!

{
  date '+%Y-%m-%dT%H:%M:%S.%3N START USER-B' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S START USER-B'
  curl "${curl_args[@]}" --data-binary @"$BASE_DIR/requests/request_B.xml" \
    "$SOAP_URL" > "$RESULT_DIR/response_B.xml" 2> "$RESULT_DIR/curl_B.err"
  rc=$?
  date '+%Y-%m-%dT%H:%M:%S.%3N END USER-B' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S END USER-B'
  echo "$rc" > "$RESULT_DIR/curl_B.rc"
} > "$RESULT_DIR/timing_B.log" 2>&1 &
PID_B=$!

wait "$PID_A"
RC_A=$(cat "$RESULT_DIR/curl_A.rc")
wait "$PID_B"
RC_B=$(cat "$RESULT_DIR/curl_B.rc")

echo "curl exit codes: A=$RC_A B=$RC_B"

if [ "$RC_A" -ne 0 ] || [ "$RC_B" -ne 0 ]; then
  echo "NG: curl request failed"
  exit 1
fi

set +e
"$BASE_DIR/bin/verify_response.sh" USER-A TEST-A-000001 "$RESULT_DIR/response_A.xml" | tee "$RESULT_DIR/result_A.txt"
V_A=${PIPESTATUS[0]}
"$BASE_DIR/bin/verify_response.sh" USER-B TEST-B-000002 "$RESULT_DIR/response_B.xml" | tee "$RESULT_DIR/result_B.txt"
V_B=${PIPESTATUS[0]}
set -e

if [ "$V_A" -eq 0 ] && [ "$V_B" -eq 0 ]; then
  echo "OVERALL: PASS"
  exit 0
fi

echo "OVERALL: FAIL"
exit 1
