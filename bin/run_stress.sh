#!/bin/bash
set -u

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
RESULT_DIR="$BASE_DIR/results/stress"
mkdir -p "$RESULT_DIR"

if [ -f "$BASE_DIR/config.env" ]; then
  . "$BASE_DIR/config.env"
else
  echo "ERROR: config.env not found" >&2
  exit 2
fi

: "${SOAP_URL:?SOAP_URL is not set}"
: "${CURL_TIMEOUT:=30}"

ITERATIONS="${1:-100}"
rm -f "$RESULT_DIR/summary.csv"
echo "iteration,user,expected_key,actual_user,actual_key,result" > "$RESULT_DIR/summary.csv"

extract() {
  file="$1"
  xpath="$2"
  if command -v xmllint >/dev/null 2>&1; then
    xmllint --xpath "string((//*[local-name()=\"$xpath\"])[last()])" "$file" 2>/dev/null
  else
    sed -n "s:.*<[^>]*$xpath[^>]*>\\([^<]*\\)</[^>]*$xpath>.*:\\1:p" "$file" | tail -1
  fi
}

for i in $(seq 1 "$ITERATIONS"); do
  KEY_A=$(printf 'A-%06d' "$i")
  KEY_B=$(printf 'B-%06d' "$i")
  REQ_A="$RESULT_DIR/request_A_$i.xml"
  REQ_B="$RESULT_DIR/request_B_$i.xml"
  RESP_A="$RESULT_DIR/response_A_$i.xml"
  RESP_B="$RESULT_DIR/response_B_$i.xml"

  sed "s/TEST-A-000001/TEST-$KEY_A/" "$BASE_DIR/requests/request_A.xml" > "$REQ_A"
  sed "s/TEST-B-000002/TEST-$KEY_B/" "$BASE_DIR/requests/request_B.xml" > "$REQ_B"

  (
    curl -sS --connect-timeout "$CURL_TIMEOUT" --max-time "$CURL_TIMEOUT" \
      -H "Content-Type: text/xml; charset=utf-8" \
      ${SOAP_ACTION:+-H "SOAPAction: $SOAP_ACTION"} \
      --data-binary @"$REQ_A" "$SOAP_URL" > "$RESP_A"
  ) &
  P1=$!

  (
    curl -sS --connect-timeout "$CURL_TIMEOUT" --max-time "$CURL_TIMEOUT" \
      -H "Content-Type: text/xml; charset=utf-8" \
      ${SOAP_ACTION:+-H "SOAPAction: $SOAP_ACTION"} \
      --data-binary @"$REQ_B" "$SOAP_URL" > "$RESP_B"
  ) &
  P2=$!

  wait "$P1"; R1=$?
  wait "$P2"; R2=$?

  AU=$(extract "$RESP_A" userId)
  AK=$(extract "$RESP_A" requestKey)
  BU=$(extract "$RESP_B" userId)
  BK=$(extract "$RESP_B" requestKey)

  if [ "$R1" -eq 0 ] && [ "$AU" = "USER-A" ] && [ "$AK" = "TEST-$KEY_A" ]; then RA=OK; else RA=NG; fi
  if [ "$R2" -eq 0 ] && [ "$BU" = "USER-B" ] && [ "$BK" = "TEST-$KEY_B" ]; then RB=OK; else RB=NG; fi

  echo "$i,USER-A,TEST-$KEY_A,$AU,$AK,$RA" >> "$RESULT_DIR/summary.csv"
  echo "$i,USER-B,TEST-$KEY_B,$BU,$BK,$RB" >> "$RESULT_DIR/summary.csv"

  if [ "$RA" = NG ] || [ "$RB" = NG ]; then
    echo "FAIL at iteration $i. See $RESULT_DIR/summary.csv"
    exit 1
  fi

  rm -f "$REQ_A" "$REQ_B" "$RESP_A" "$RESP_B"
done

echo "PASS: $ITERATIONS parallel A/B iterations completed."
echo "Summary: $RESULT_DIR/summary.csv"
exit 0
