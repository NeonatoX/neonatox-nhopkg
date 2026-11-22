#!/usr/bin/env python3
"""Tiny static HTTP server with a request log, for the nhopkg -U test.

Configuration (environment):
  FAKE_REPO_ROOT   directory served over HTTP (required)
  FAKE_REPO_PORT   port to listen on (required)
  FAKE_REPO_LOG    file to append "GET <path>" lines to
"""

import os
from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler

ROOT = os.environ["FAKE_REPO_ROOT"]
LOG = os.environ.get("FAKE_REPO_LOG", "")


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        if LOG:
            with open(LOG, "a", encoding="utf-8") as log:
                log.write("GET %s\n" % self.path)
        return super().do_GET()


if __name__ == "__main__":
    port = int(os.environ["FAKE_REPO_PORT"])
    HTTPServer(("127.0.0.1", port), partial(Handler, directory=ROOT)).serve_forever()
