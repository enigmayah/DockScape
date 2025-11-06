#!/bin/sh
set -e
LOGFILE="/var/log/falco.json"
WEBHOOK_URL="http://webhook:5000/alert"

[ -f "$LOGFILE" ] || touch "$LOGFILE"

tail -F "$LOGFILE" | while read -r line; do
  [ -z "$line" ] && continue
  echo "$line" | curl -s -X POST -H "Content-Type: application/json" --data-binary @- "$WEBHOOK_URL"
done
