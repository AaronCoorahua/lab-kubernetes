#!/usr/bin/env bash
# Uso: ./scripts/balanceo.sh [peticiones] [url]
# Lanza N peticiones al Service y cuenta cuántas atendió cada Pod.
set -euo pipefail

N="${1:-10}"
URL="${2:-http://localhost:30080/}"

echo "== $N peticiones a $URL =="
pods=""
for i in $(seq 1 "$N"); do
  body=$(curl -s --max-time 3 "$URL") || { echo "peticion $i: sin respuesta"; continue; }
  pod=$(echo "$body" | sed -n 's/.*"pod": *"\([^"]*\)".*/\1/p')
  echo "peticion $i -> ${pod:-respuesta inesperada: $body}"
  [ -n "$pod" ] && pods="$pods$pod"$'\n'
done

echo
echo "== Peticiones por Pod =="
printf '%s' "$pods" | sort | uniq -c | sort -rn
