#!/bin/bash
set -u

echo "Checking prerequisites..."

command -v curl >/dev/null 2>&1 && echo "OK curl" || echo "NG curl"
command -v xmllint >/dev/null 2>&1 && echo "OK xmllint" || echo "WARN xmllint not found (fallback parser will be used)"
command -v date >/dev/null 2>&1 && echo "OK date" || echo "NG date"

if command -v java >/dev/null 2>&1; then
  java -version 2>&1 | head -3
else
  echo "WARN java not found (required for JMeter)"
fi

if command -v jmeter >/dev/null 2>&1; then
  jmeter --version 2>&1 | head -3
else
  echo "WARN jmeter not found"
fi
