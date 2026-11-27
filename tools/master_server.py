#!/usr/bin/env python3
"""Servidor mestre MÍNIMO (opcional) para a lista de salas públicas pela internet.

    python3 tools/master_server.py 8080

Endpoints: GET /rooms | POST /rooms (JSON) | DELETE /rooms/<codigo>. Salas expiram em 90 s sem
re-registro. Sem autenticação: use atrás de um proxy/limite de taxa se for público.
Depois configure o Secret MASTER_SERVER_URL (ex.: https://meu-servidor.exemplo) no GitHub.
"""
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

ROOMS: dict[str, dict] = {}
TTL = 90


class H(BaseHTTPRequestHandler):
    def _send(self, code: int, body: object) -> None:
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        now = time.time()
        for k in [k for k, v in ROOMS.items() if now - v["_t"] > TTL]:
            del ROOMS[k]
        self._send(200, [{k: v for k, v in r.items() if k != "_t"} for r in ROOMS.values()])

    def do_POST(self) -> None:
        try:
            r = json.loads(self.rfile.read(min(int(self.headers.get("Content-Length", 0)), 4096)))
            code = str(r["code"])[:11]
            ROOMS[code] = {"name": str(r.get("name", "?"))[:24], "code": code, "size": int(r.get("size", 2)),
                           "players": int(r.get("players", 1)), "host": str(r.get("host", "?"))[:16],
                           "friends": [str(f)[:9] for f in r.get("friends", [])][:8], "_t": time.time()}
            self._send(200, {"ok": True})
        except Exception:
            self._send(400, {"ok": False})

    def do_DELETE(self) -> None:
        ROOMS.pop(self.path.rsplit("/", 1)[-1], None)
        self._send(200, {"ok": True})


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", int(sys.argv[1]) if len(sys.argv) > 1 else 8080), H).serve_forever()
