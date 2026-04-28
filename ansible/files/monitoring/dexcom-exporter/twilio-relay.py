#!/usr/bin/env python3
# Twilio SMS relay for Alertmanager webhooks
#
# Receives Alertmanager webhook POSTs and sends SMS via Twilio.
# Runs as a sidecar container alongside the Dexcom exporter.

import os
import json
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from twilio.rest import Client

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("twilio-relay")

TWILIO_SID = os.environ.get("TWILIO_ACCOUNT_SID", "")
TWILIO_TOKEN = os.environ.get("TWILIO_AUTH_TOKEN", "")
TWILIO_FROM = os.environ.get("TWILIO_FROM_NUMBER", "")
SMS_TO = os.environ.get("SMS_TO_NUMBER", "")
PORT = int(os.environ.get("RELAY_PORT", "9667"))


class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length else {}

        alerts = body.get("alerts", [])
        client = Client(TWILIO_SID, TWILIO_TOKEN)

        for alert in alerts:
            status = alert.get("status", "unknown")
            annotations = alert.get("annotations", {})
            summary = annotations.get("summary", "Glucose alert")

            if status == "resolved":
                msg = f"[RESOLVED] {summary}"
            else:
                msg = f"[ALERT] {summary}"

            try:
                client.messages.create(
                    body=msg,
                    from_=TWILIO_FROM,
                    to=SMS_TO,
                )
                log.info("SMS sent: %s", msg)
            except Exception as e:
                log.error("Failed to send SMS: %s", e)

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, format, *args):
        pass


def main():
    if not all([TWILIO_SID, TWILIO_TOKEN, TWILIO_FROM, SMS_TO]):
        log.error(
            "Missing required env vars: TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, "
            "TWILIO_FROM_NUMBER, SMS_TO_NUMBER"
        )
        log.warning("Starting anyway -- SMS will fail until credentials are configured")

    server = HTTPServer(("0.0.0.0", PORT), WebhookHandler)
    log.info("Twilio SMS relay listening on :%d", PORT)
    server.serve_forever()


if __name__ == "__main__":
    main()
