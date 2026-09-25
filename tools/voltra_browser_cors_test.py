"""Browser-level CORS proof for the VOLTRA Desktop pairing endpoint.

The Python self-test sends the same headers a browser would, but it does not
*enforce* CORS. This script runs the real check inside real Chrome:

  1. serves a tiny page from http://localhost:8099  (a loopback origin, the
     same class of origin `flutter run -d chrome` uses)
  2. launches Chrome headless on that page
  3. the page does fetch() POST /pair with Content-Type: application/json,
     which forces a CORS preflight
  4. Chrome blocks the response unless the server's CORS headers are correct
  5. the outcome is printed into the DOM and dumped back here

Standard library only.
"""

import http.server
import json
import os
import socket
import subprocess
import sys
import threading

DESKTOP_PORT = 8765
PAGE_PORT = 8099
PAIR_CODE = "123456"

CHROME_CANDIDATES = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    os.path.expandvars(
        r"%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
    ),
]

PAGE = """<!doctype html>
<html><body><pre id="out">PENDING</pre>
<script>
const base = "http://__HOST__:__PORT__";
async function run() {
  const lines = [];
  try {
    const s = await fetch(base + "/status");
    lines.push("STATUS_HTTP=" + s.status);
    lines.push("STATUS_BODY=" + (await s.text()).trim());
  } catch (e) { lines.push("STATUS_ERROR=" + e); }

  try {
    const r = await fetch(base + "/pair", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({code: "__CODE__", device: "VOLTRA Companion"})
    });
    lines.push("PAIR_HTTP=" + r.status);
    lines.push("PAIR_BODY=" + (await r.text()).trim());
    lines.push(r.status === 200 ? "RESULT=OK" : "RESULT=BAD_STATUS");
  } catch (e) {
    lines.push("PAIR_ERROR=" + e);
    lines.push("RESULT=BLOCKED_BY_CORS_OR_NETWORK");
  }
  document.getElementById("out").textContent = lines.join("\\n");
}
run();
</script></body></html>"""


def lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def find_chrome():
    for p in CHROME_CANDIDATES:
        if os.path.isfile(p):
            return p
    return None


def main():
    host = lan_ip()
    print("Desktop host under test:", host, flush=True)

    html = (
        PAGE.replace("__HOST__", host)
        .replace("__PORT__", str(DESKTOP_PORT))
        .replace("__CODE__", PAIR_CODE)
    ).encode()

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(html)))
            self.end_headers()
            self.wfile.write(html)

        def log_message(self, *a):
            pass

    server = http.server.HTTPServer(("127.0.0.1", PAGE_PORT), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    print("Test page: http://localhost:%d/ (origin used for CORS)" % PAGE_PORT,
          flush=True)

    chrome = find_chrome()
    if not chrome:
        print("FAIL: chrome.exe not found in the usual locations.", flush=True)
        return 2
    print("Chrome:", chrome, flush=True)

    out = subprocess.run(
        [
            chrome,
            "--headless=new",
            "--disable-gpu",
            "--no-first-run",
            "--virtual-time-budget=8000",
            "--dump-dom",
            "http://localhost:%d/" % PAGE_PORT,
        ],
        capture_output=True,
        text=True,
        timeout=90,
    ).stdout

    print("---- DOM ----", flush=True)
    start = out.find('<pre id="out">')
    end = out.find("</pre>", start)
    dom = out[start + len('<pre id="out">'):end] if start >= 0 else out
    print(dom.strip(), flush=True)
    print("-------------", flush=True)

    ok = "RESULT=OK" in dom
    print("\nBROWSER CORS TEST: %s" % ("PASS" if ok else "FAIL"), flush=True)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
