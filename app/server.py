#!/usr/bin/env python3
"""
CSYE 6225 - Assignment 6: Choosing the Right EC2 Instance Type

Service used on both hosts. Uses only the Python standard library - no
pip install required, since the worker host has no internet access to
reach PyPI (no NAT Gateway, same isolation model as Assignment 5).

Endpoints:
  GET /healthcheck            (both hosts)
  GET /check-private?target=  (api host only) - proxies target's /healthcheck
  GET /check-batch?target=    (api host only) - proxies target's /batch-job
  GET /batch-job              (worker host only) - trivial deterministic computation

Do NOT modify this file.
"""

import json
import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

HOST_ROLE = os.environ.get("HOST_ROLE", "unknown")
PORT = int(os.environ.get("PORT", 80))
PROXY_TIMEOUT_SECONDS = 5


class ServiceHandler(BaseHTTPRequestHandler):
    def _send_json(self, status_code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _proxy(self, target, path):
        url = f"http://{target}{path}"
        with urllib.request.urlopen(url, timeout=PROXY_TIMEOUT_SECONDS) as resp:
            return resp.read()

    def do_GET(self):
        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)

        if parsed.path == "/healthcheck":
            self._send_json(200, {"status": "ok", "host": HOST_ROLE})
            return

        if parsed.path == "/check-private":
            if HOST_ROLE != "api":
                self.send_response(404)
                self.end_headers()
                return
            target = qs.get("target", [None])[0]
            if not target:
                self._send_json(400, {"error": "missing required query parameter: target"})
                return
            try:
                body = self._proxy(target, "/healthcheck")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            except (urllib.error.URLError, TimeoutError, ConnectionError) as exc:
                self._send_json(502, {"error": f"could not reach {target}: {exc}"})
            return

        if parsed.path == "/check-batch":
            if HOST_ROLE != "api":
                self.send_response(404)
                self.end_headers()
                return
            target = qs.get("target", [None])[0]
            if not target:
                self._send_json(400, {"error": "missing required query parameter: target"})
                return
            try:
                body = self._proxy(target, "/batch-job")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            except (urllib.error.URLError, TimeoutError, ConnectionError) as exc:
                self._send_json(502, {"error": f"could not reach {target}: {exc}"})
            return

        if parsed.path == "/batch-job":
            if HOST_ROLE != "worker":
                self.send_response(404)
                self.end_headers()
                return
            try:
                a = int(qs.get("a", ["15"])[0])
                b = int(qs.get("b", ["27"])[0])
            except ValueError:
                self._send_json(400, {"error": "a and b must be integers"})
                return
            self._send_json(200, {"host": "worker", "a": a, "b": b, "result": a + b})
            return

        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        # Quiet down default stderr logging; systemd captures this either way.
        pass


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", PORT), ServiceHandler)
    server.serve_forever()
