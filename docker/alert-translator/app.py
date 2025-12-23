import os
import requests
from flask import Flask, request

app = Flask(__name__)

OLLAMA_URL = os.getenv("OLLAMA_URL", "https://ollama.horus.maix.ovh")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "mistral-small:24b")
NTFY_URL = os.getenv("NTFY_URL", "https://ntfy.maix.ovh/alerts")

@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.json
    status = data.get("status", "unknown")

    for alert in data.get("alerts", []):
        alertname = alert.get("labels", {}).get("alertname", "Unknown")
        severity = alert.get("labels", {}).get("severity", "info")
        description = alert.get("annotations", {}).get("description", "")
        summary = alert.get("annotations", {}).get("summary", "")
        instance = alert.get("labels", {}).get("instance", "")

        alert_text = f"status:{status} alert:{alertname} severity:{severity} summary:{summary} description:{description} instance:{instance}"

        # Ask Ollama to translate
        prompt = f"Translate this alert into a short, clear notification (1-2 sentences max, no JSON):\n\n{alert_text}"

        try:
            resp = requests.post(f"{OLLAMA_URL}/api/generate", json={
                "model": OLLAMA_MODEL,
                "prompt": prompt,
                "stream": False
            }, timeout=30)
            message = resp.json().get("response", alert_text)
        except Exception as e:
            message = f"[{severity.upper()}] {alertname}: {description}"

        # Send to ntfy
        priority = "urgent" if severity == "critical" else "high" if severity == "warning" else "default"
        emoji = "🔴" if status == "firing" else "✅"

        requests.post(NTFY_URL,
            data=f"{emoji} {message}".encode("utf-8"),
            headers={
                "Title": f"{alertname} ({status})",
                "Priority": priority,
                "Tags": severity
            })

    return "ok", 200

@app.route("/health", methods=["GET"])
def health():
    return "ok", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
