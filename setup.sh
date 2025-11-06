#!/usr/bin/env bash
set -e

ROOT="$PWD"
mkdir -p "$ROOT"/victim "$ROOT"/webhook "$ROOT"/falco/rules "$ROOT"/docs "$ROOT"/host_share/etc

# victim/Dockerfile
cat > "$ROOT"/victim/Dockerfile <<'DOCKER_VICTIM'
FROM alpine:3.18
RUN apk add --no-cache bash curl
COPY app.sh /app/app.sh
RUN chmod +x /app/app.sh
CMD ["/bin/sh", "/app/app.sh"]
DOCKER_VICTIM

# victim/app.sh
cat > "$ROOT"/victim/app.sh <<'APP_VICTIM'
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
APP_VICTIM

# webhook/requirements.txt
cat > "$ROOT"/webhook/requirements.txt <<'REQ'
Flask==2.3.2
docker==6.0.0
REQ

# webhook/app.py
cat > "$ROOT"/webhook/app.py <<'APP_WEBHOOK'
from flask import Flask, request, jsonify
import docker
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

client = docker.DockerClient(base_url='unix://var/run/docker.sock')

def safe_pause(container_id_or_name):
    try:
        c = client.containers.get(container_id_or_name)
    except Exception as e:
        return False, f"Container {container_id_or_name} not found: {e}"
    if c.status == 'paused':
        return True, "Already paused"
    c.pause()
    return True, f"Paused {c.name} ({c.id})"

@app.route("/alert", methods=["POST"])
def alert():
    data = request.get_json(silent=True)
    if not data:
        logging.warning("No JSON received")
        return jsonify({"ok": False, "error": "no json"}), 400

    output_fields = data.get("output_fields", {}) or {}
    cid = output_fields.get("container.id") or output_fields.get("container_id") or output_fields.get("container")
    cname = output_fields.get("container.name") or output_fields.get("container_name")

    target = cid or cname
    if not target:
        msg = data.get("output") or ""
        import re
        m = re.search(r'id=([0-9a-f]{12,64})', msg)
        target = m.group(1) if m else None

    if not target:
        logging.error("No container identifier found in event")
        return jsonify({"ok": False, "error": "no container id/name found"}), 400

    ok, detail = safe_pause(target)
    status_code = 200 if ok else 500
    logging.info(f"Action on {target}: {detail}")
    return jsonify({"ok": ok, "detail": detail}), status_code

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
APP_WEBHOOK

# falco rule
cat > "$ROOT"/falco/rules/local_rules.yaml <<'FALCO_RULE'
- rule: HostMountAccessDetected
  desc: Detect access to host-mounted filesystem inside container (simulated container escape)
  condition: container and (fd.name startswith "/host" or fd.name contains "/host/")
  output: Container=%container.name (id=%container.id) accessed host path=%fd.name user=%user.name cmdline=%proc.cmdline
  priority: WARNING
  tags: [container,host,mount]
FALCO_RULE

# falco forwarder
cat > "$ROOT"/falco/forwarder.sh <<'FORWARD'
#!/bin/sh
set -e
LOGFILE="/var/log/falco.json"
WEBHOOK_URL="http://webhook:5000/alert"

[ -f "$LOGFILE" ] || touch "$LOGFILE"

tail -F "$LOGFILE" | while read -r line; do
  [ -z "$line" ] && continue
  echo "$line" | curl -s -X POST -H "Content-Type: application/json" --data-binary @- "$WEBHOOK_URL"
done
FORWARD

# docker-compose.yml
cat > "$ROOT"/docker-compose.yml <<'DCMP'
version: "3.8"

services:

  falco:
    image: falcosecurity/falco:latest
    container_name: falco
    privileged: true
    network_mode: "bridge"
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /dev:/host/dev:ro
      - /proc:/host/proc:ro
      - /boot:/host/boot:ro
      - /lib/modules:/lib/modules:ro
      - ./falco/rules:/etc/falco/rules.d:ro
      - ./falco/forwarder.sh:/opt/forwarder.sh:ro
      - ./falco/falco.json:/var/log/falco.json
    command: >
      sh -c "falco -F /etc/falco/falco_rules.yaml \
                -f /etc/falco/falco.yaml \
                -o json_output=true \
                -o json_include_output_property=true \
                -o enable_source=true \
                -o log_output=true \
                -o log_file=/var/log/falco.json \
                && tail -F /var/log/falco.json"

  webhook:
    build: ./webhook
    container_name: falco-webhook
    restart: unless-stopped
    network_mode: "bridge"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:rw
    environment:
      - FLASK_ENV=production
    ports:
      - "5000:5000"

  victim:
    build: ./victim
    container_name: victim-sim
    restart: unless-stopped
    network_mode: "bridge"
    volumes:
      - ./host_share:/host:ro
    command: ["/bin/sh", "/app/app.sh"]
DCMP

# docs
cat > "$ROOT"/docs/README.md <<'DOCS'
# Container Escape Lab README
See project root for setup.sh and docker-compose. Start with `docker compose up --build`.
DOCS

cat > "$ROOT"/docs/daywise_log.md <<'DOCS2'
# Day-wise Log (sample)
- Day 1: Setup files
- Day 2: Test detection
DOCS2

cat > "$ROOT"/docs/viva_prep.md <<'DOCS3'
# Viva prep
Key points: safe simulation, Falco rule, webhook pauses container via Docker socket.
DOCS3

cat > "$ROOT"/docs/final_report.md <<'DOCS4'
# Final report
Short report placeholder.
DOCS4

# ensure dummy host file exists
if [ ! -f "$ROOT"/host_share/etc/passwd ]; then
  echo "root:x:0:0:root:/root:/bin/bash" > "$ROOT"/host_share/etc/passwd
fi

chmod +x "$ROOT"/victim/app.sh "$ROOT"/falco/forwarder.sh

# webhook Dockerfile
cat > "$ROOT"/webhook/Dockerfile <<'DOCKER_WEBHOOK'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py /app/app.py
CMD ["python", "app.py"]
DOCKER_WEBHOOK

echo "All files created in: $ROOT"
echo "Run: docker compose up --build"
