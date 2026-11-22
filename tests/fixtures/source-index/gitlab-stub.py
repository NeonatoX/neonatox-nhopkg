#!/usr/bin/env python3
"""Minimal GitLab REST stub for the source-index Etapa 2 test.

It serves exactly the four endpoints the generator uses, from the golden
nhoid fixtures next to this file. It logs every request so the test can prove
that a cache hit performs no raw-file downloads, and it can inject one HTTP
429 with a short Retry-After to exercise the retry path.

Configuration (environment):
  FAKE_GITLAB_PORT   port to listen on (required)
  FAKE_GITLAB_LOG    file to append "METHOD path?query" lines to
  FAKE_GITLAB_429    path substring that gets one 429 before succeeding
"""

import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

FIXTURES = Path(__file__).resolve().parent
LOG = os.environ.get("FAKE_GITLAB_LOG", "")
RATE_LIMIT_PATH = os.environ.get("FAKE_GITLAB_429", "")

PROJECTS = [
    {
        "id": 1,
        "path": "kinfocenter",
        "archived": False,
        "empty_repo": False,
        "branches": {
            "main": "013963ff9f07c2b5bb392ae536a1abd9de2f73a2",
            "musl": "8861717582cca888832dba0473e68986a1a60ae5",
        },
        "tree": [
            {"type": "blob", "path": "patches/fix.patch"},
            {"type": "blob", "path": "others/extra.txt"},
            {"type": "blob", "path": "nhoid"},
        ],
    },
    {
        "id": 2,
        "path": "qt6-graphs",
        "archived": False,
        "empty_repo": False,
        "branches": {
            "main": "8ee225a6528e587e6ba91b862922cb6f51f3e063",
            "musl": "998d09278c7ce731c128615be6680e406e7fe0df",
        },
        "tree": None,  # 404: no extras
    },
    {
        "id": 3,
        "path": "broken",
        "archived": False,
        "empty_repo": False,
        "branches": {"main": "deadbeef"},
        "tree": None,
    },
]

seen_429 = set()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send_json(self, code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_raw(self, code, body, retry_after=None):
        self.send_response(code)
        if retry_after is not None:
            self.send_header("Retry-After", str(retry_after))
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        split = urlsplit(self.path)
        path, query = split.path, parse_qs(split.query)
        if LOG:
            with open(LOG, "a", encoding="utf-8") as log:
                log.write("GET %s?%s\n" % (path, split.query))

        if RATE_LIMIT_PATH and RATE_LIMIT_PATH in self.path and self.path not in seen_429:
            seen_429.add(self.path)
            self.send_raw(429, b'{"message":"rate limited"}', retry_after=1)
            return

        parts = [p for p in path.split("/") if p]
        # /api/v4/groups/<group>/projects
        if len(parts) == 5 and parts[0:2] == ["api", "v4"] and parts[2] == "groups" and parts[4] == "projects":
            page = int(query.get("page", ["1"])[0])
            rows = PROJECTS[(page - 1) * 2: page * 2]
            self.send_json(200, [
                {k: p[k] for k in ("id", "path", "archived", "empty_repo")}
                for p in rows
            ])
            return

        # /api/v4/projects/<id>/repository/...
        if len(parts) >= 5 and parts[0:2] == ["api", "v4"] and parts[2] == "projects":
            project = next((p for p in PROJECTS if str(p["id"]) == parts[3]), None)
            if project is None:
                self.send_json(404, {"message": "no such project"})
                return
            tail = parts[4:]
            if tail == ["repository", "branches"]:
                self.send_json(200, [
                    {"name": name, "commit": {"id": sha}}
                    for name, sha in project["branches"].items()
                ])
                return
            if tail == ["repository", "tree"]:
                if project["tree"] is None:
                    self.send_json(404, {"message": "no tree"})
                else:
                    self.send_json(200, project["tree"])
                return
            if tail == ["repository", "files", "nhoid", "raw"]:
                ref = query.get("ref", [""])[0]
                if ref not in project["branches"]:
                    self.send_raw(404, b"no such ref")
                    return
                nhoid = FIXTURES / project["path"] / ref / "nhoid"
                if not nhoid.is_file():
                    self.send_raw(404, b"no such nhoid")
                    return
                self.send_raw(200, nhoid.read_bytes())
                return

        self.send_json(404, {"message": "no such endpoint"})


if __name__ == "__main__":
    port = int(os.environ["FAKE_GITLAB_PORT"])
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
