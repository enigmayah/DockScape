from flask import Flask, request, jsonify
import docker
import logging
import os

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

client = docker.DockerClient(base_url=os.getenv("DOCKER_HOST", "unix:///var/run/docker.sock"))
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
