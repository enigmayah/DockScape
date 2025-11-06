#!/bin/sh
echo "Victim container started. Will try to read /host/etc/passwd periodically to simulate 'escape' behaviour."
while true; do
  echo "---- attempt to read /host/etc/passwd ----"
  if [ -f /host/etc/passwd ]; then
    echo "Found /host/etc/passwd, printing first 3 lines:"
    head -n 3 /host/etc/passwd || true
  else
    echo "/host/etc/passwd not present"
  fi
  sleep 15
done
