import io
import os
import re

import requests
from flask import Flask, request, jsonify

app = Flask(__name__)

OLLAMA_URL = os.getenv("OLLAMA_URL", "https://ollama.horus.maix.ovh")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "phi4-mini")
PUSHOVER_USER_KEY = os.getenv("PUSHOVER_USER_KEY", "")
PUSHOVER_API_TOKEN = os.getenv("PUSHOVER_API_TOKEN", "")
PUSHOVER_API_URL = "https://api.pushover.net/1/messages.json"

SEVERITY_PRIORITY_MAP = {
    "critical": 1,
    "warning": 0,
    "info": -1,
}

THINK_TAG_RE = re.compile(r"<think>.*?</think>", re.DOTALL)


def strip_think_tags(text):
    return THINK_TAG_RE.sub("", text).strip()


def send_pushover(title, message, priority=0, url=None, image_url=None):
    data = {
        "token": PUSHOVER_API_TOKEN,
        "user": PUSHOVER_USER_KEY,
        "title": title,
        "message": message,
        "priority": priority,
    }

    if url:
        data["url"] = url

    files = None
    if image_url:
        try:
            img_resp = requests.get(image_url, timeout=10)
            img_resp.raise_for_status()
            files = {"attachment": ("image.jpg", io.BytesIO(img_resp.content), img_resp.headers.get("Content-Type", "image/jpeg"))}
        except Exception:
            pass

    if files:
        resp = requests.post(PUSHOVER_API_URL, data=data, files=files, timeout=10)
    else:
        resp = requests.post(PUSHOVER_API_URL, data=data, timeout=10)

    return resp


@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.get_json(force=True, silent=True) or {}
    status = data.get("status", "unknown")

    for alert in data.get("alerts", []):
        alertname = alert.get("labels", {}).get("alertname", "Unknown")
        severity = alert.get("labels", {}).get("severity", "info")
        description = alert.get("annotations", {}).get("description", "")
        summary = alert.get("annotations", {}).get("summary", "")
        instance = alert.get("labels", {}).get("instance", "")

        prompt = (
            f"You are a concise server monitoring assistant. "
            f"This alert is {'ACTIVE — something is wrong' if status == 'firing' else 'RESOLVED — the issue has been fixed'}.\n"
            f"Alert: {alertname}\nSeverity: {severity}\nSummary: {summary}\nDescription: {description}\nInstance: {instance}\n\n"
            f"Write a 1-2 sentence notification for a phone push alert. "
            f"{'Convey urgency.' if status == 'firing' else 'Convey that the issue is cleared.'} "
            f"No JSON. No preamble."
        )

        try:
            resp = requests.post(f"{OLLAMA_URL}/api/generate", json={
                "model": OLLAMA_MODEL,
                "prompt": prompt,
                "stream": False
            }, timeout=30)
            message = strip_think_tags(resp.json().get("response", f"{alertname}: {description}"))
        except Exception:
            message = f"[{severity.upper()}] {alertname}: {description}"

        priority = SEVERITY_PRIORITY_MAP.get(severity, -1)
        emoji = "\U0001f534" if status == "firing" else "\u2705"
        title = f"{emoji} {alertname} ({status})"

        send_pushover(title=title, message=message, priority=priority)

    return "ok", 200


@app.route("/notify", methods=["POST"])
def notify():
    data = request.get_json(force=True, silent=True)
    if not data:
        return jsonify({"error": "JSON body required"}), 400

    title = data.get("title")
    message = data.get("message")

    if not title or not message:
        return jsonify({"error": "title and message are required"}), 400

    priority = data.get("priority", 0)
    url = data.get("url")
    image = data.get("image")

    resp = send_pushover(title=title, message=message, priority=priority, url=url, image_url=image)

    if resp.status_code == 200:
        return jsonify({"status": "sent"}), 200

    return jsonify({"error": "pushover request failed", "details": resp.text}), resp.status_code


@app.route("/health", methods=["GET"])
def health():
    return "ok", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
