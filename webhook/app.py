from flask import Flask, request, jsonify
import docker
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

client = docker.from_env()
def safe_pause(container_id_or_name):
    try:
        c = client.containers.get(container_id_or_name)
        if c.status == 'paused':
            return True, "Already paused"
        c.pause()
        return True, f"Paused {c.name} ({c.id})"
    except Exception as e:
        return False, str(e)


@app.route("/alert", methods=["POST"])
def alert():
    data = request.get_json(silent=True)

    if not data:
        logging.warning("No JSON received")
        return jsonify({"ok": False, "error": "No JSON"}), 400

    output_fields = data.get("output_fields", {}) or {}

    cid = output_fields.get("container.id") or output_fields.get("container_id")
    cname = output_fields.get("container.name") or output_fields.get("container_name")

    target = cid or cname

    if not target:
        return jsonify({"ok": False, "error": "No container found"}), 400

    success, msg = safe_pause(target)

    logging.info(msg)
    return jsonify({"ok": success, "message": msg})
    

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

