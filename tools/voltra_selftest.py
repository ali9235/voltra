"""End-to-end check of the VOLTRA Desktop server.

Verifies, without a browser:
  1. the LAN IPv4 of this machine (auto-detected; the address has changed
     between Ethernet .11 and Wi-Fi .10 before)
  2. GET  /status              -> 200 and online=true
  3. OPTIONS /pair preflight   -> CORS headers present for a localhost origin
  4. POST /pair (right code)   -> 200
  5. POST /pair (wrong code)   -> 401
  6. OPTIONS /pair from a foreign origin -> NOT allowed

Standard library only. Run:  python voltra_selftest.py
"""

import json
import socket
import sys
import urllib.error
import urllib.request

PORT = 8765
PAIR_CODE = "123456"
WEB_ORIGIN = "http://localhost:5123"  # flutter run -d chrome --web-port 5123
FOREIGN_ORIGIN = "http://evil.example.com"

results = []


def log(ok, label, detail=""):
    tag = "PASS" if ok else "FAIL"
    line = "[%s] %s%s" % (tag, label, (" :: " + detail) if detail else "")
    print(line, flush=True)
    results.append(ok)


def lan_ipv4_candidates():
    found = []
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        found.append(s.getsockname()[0])
    except OSError:
        pass
    finally:
        s.close()
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            a = info[4][0]
            if a not in found and not a.startswith("127."):
                found.append(a)
    except OSError:
        pass
    for extra in ("192.168.18.11", "192.168.18.10"):
        if extra not in found:
            found.append(extra)
    return found


def request(method, url, origin=None, payload=None, timeout=4):
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"
    if origin:
        headers["Origin"] = origin
        if method == "OPTIONS":
            headers["Access-Control-Request-Method"] = "POST"
            headers["Access-Control-Request-Headers"] = "content-type"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, dict(r.headers), r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read().decode("utf-8", "replace")


def find_server():
    for ip in lan_ipv4_candidates() + ["127.0.0.1"]:
        try:
            status, _, body = request("GET", "http://%s:%d/status" % (ip, PORT))
            if status == 200 and json.loads(body).get("online") is True:
                return ip, body
        except Exception:
            continue
    return None, None


def main():
    print("Detected LAN IPv4 candidates:", lan_ipv4_candidates(), flush=True)

    ip, body = find_server()
    if not ip:
        log(False, "GET /status", "no VOLTRA Desktop server answered on port %d" % PORT)
        print("\nRESULT: FAIL", flush=True)
        return 1

    log(True, "GET /status", "%s -> %s" % (ip, body.strip()))
    print("ACTIVE_DESKTOP_IP=%s" % ip, flush=True)

    base = "http://%s:%d" % (ip, PORT)

    # --- CORS preflight from the Flutter Web origin
    status, headers, _ = request("OPTIONS", base + "/pair", origin=WEB_ORIGIN)
    allow = headers.get("Access-Control-Allow-Origin")
    ok = status in (200, 204) and allow in (WEB_ORIGIN, "*")
    log(ok, "OPTIONS /pair preflight (CORS)",
        "HTTP %s, Allow-Origin=%s" % (status, allow))

    # --- real pairing
    status, headers, body = request(
        "POST", base + "/pair", origin=WEB_ORIGIN,
        payload={"code": PAIR_CODE, "device": "VOLTRA Companion"},
    )
    ok = status == 200 and json.loads(body).get("ok") is True
    log(ok, "POST /pair correct code", "HTTP %s %s" % (status, body.strip()))
    log(headers.get("Access-Control-Allow-Origin") == WEB_ORIGIN,
        "POST /pair response carries CORS header",
        str(headers.get("Access-Control-Allow-Origin")))

    # --- wrong code must be rejected
    status, _, body = request(
        "POST", base + "/pair", origin=WEB_ORIGIN,
        payload={"code": "000000", "device": "VOLTRA Companion"},
    )
    log(status == 401, "POST /pair wrong code rejected", "HTTP %s" % status)

    # --- foreign origin must NOT be allowed
    status, headers, _ = request("OPTIONS", base + "/pair", origin=FOREIGN_ORIGIN)
    allow = headers.get("Access-Control-Allow-Origin")
    log(allow != FOREIGN_ORIGIN and allow != "*",
        "Foreign origin not allowed by CORS", "Allow-Origin=%s" % allow)

    passed = all(results)
    print("\nRESULT: %s (%d/%d checks passed)"
          % ("PASS" if passed else "FAIL", sum(results), len(results)), flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
