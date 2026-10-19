#!/usr/bin/env python3
"""E029 host-only prebuilt Firefox/r3dfox SharedWorker and CSP smoke."""
import argparse
import csv
import hashlib
import http.server
import json
import os
from pathlib import Path
import subprocess
import threading
import time
import traceback
import urllib.request
from urllib.parse import urlsplit

SOURCE_SHA = "67dc557067835bb8175f38830887e96afb75cf07"
ARTIFACT_ID = 12135779653
EXPECTED_SHA1 = {
    "r3dfox.exe": "f78b3444960d5efbffd7fa897addc7315758b7a7",
    "xul.dll": "bd70d93d68e10bae8c1307f10e22dac1378e0dc6",
}

WORKER_JS = """let clients = 0;
const token = String(Date.now()) + ':' + String(Math.random());
self.onconnect = event => {
  clients += 1;
  const port = event.ports[0];
  port.onmessage = event => port.postMessage({
    token, connections: clients, echo: event.data
  });
  port.start();
};
"""
SERVICE_JS = """self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
"""
WORKER_CALL = """
const done = arguments[arguments.length - 1];
let finished = false;
const timer = setTimeout(() => finish({error: "worker response timeout"}), 10000);
function finish(value) {
  if (finished) return;
  finished = true;
  clearTimeout(timer);
  done(value);
}
try {
  const worker = new SharedWorker(arguments[0], arguments[1]);
  (window.e029Workers ||= []).push(worker);
  worker.onerror = event => { event.preventDefault(); finish({error: "worker error"}); };
  worker.port.onmessage = event => finish({ok: true, ...event.data});
  worker.port.start();
  worker.port.postMessage("E029");
} catch (error) {
  finish({error: String(error)});
}
"""
CSP_BLOCK_CALL = """
const done = arguments[arguments.length - 1];
let violation = false, workerError = false, securityException = false;
let exceptionName = "", finished = false;
function finish() {
  if (finished) return;
  finished = true;
  done({blocked: violation || securityException,
        violation, workerError, securityException, exceptionName});
}
window.addEventListener("securitypolicyviolation", event => {
  if (event.effectiveDirective === "worker-src" ||
      event.effectiveDirective === "child-src") {
    violation = true;
    finish();
  }
}, {once: true});
try {
  const worker = new SharedWorker("/shared-worker.js", "e029-blocked");
  worker.onerror = event => { workerError = true; event.preventDefault(); };
  worker.port.start();
} catch (error) {
  exceptionName = error.name;
  securityException = error.name === "SecurityError";
}
setTimeout(finish, 2000);
"""
CSP_REPORT_CALL = """
const done = arguments[arguments.length - 1];
let report = false, connected = false, finished = false, timer;
function finish() {
  if (finished) return;
  finished = true;
  clearTimeout(timer);
  done({report, connected});
}
window.addEventListener("securitypolicyviolation", event => {
  if (event.disposition === "report") {
    report = true;
    if (connected) finish();
  }
});
try {
  const worker = new SharedWorker("/shared-worker.js", "e029-reportonly");
  window.e029ReportWorker = worker;
  worker.port.onmessage = () => { connected = true; if (report) finish(); };
  worker.port.start();
  worker.port.postMessage("E029");
} catch (error) { done({report: false, connected: false, error: String(error)}); }
timer = setTimeout(finish, 6000);
"""
SERVICE_CALL = """
const done = arguments[arguments.length - 1];
if (!navigator.serviceWorker) {
  done({error: "ServiceWorker API unavailable"});
} else {
  navigator.serviceWorker.register("/service-worker.js")
    .then(reg => navigator.serviceWorker.ready.then(() => {
      const active = !!reg.active;
      return reg.unregister().then(() => done({active}));
    }))
    .catch(err => done({error: String(err)}));
}
"""


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_args):
        return

    def respond(self, status, content, mime, headers=None):
        data = content.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = urlsplit(self.path).path
        if path in ("/page", "/blocked", "/report-only"):
            headers = {}
            if path == "/blocked":
                headers["Content-Security-Policy"] = "default-src 'self'; worker-src 'none'"
            elif path == "/report-only":
                headers["Content-Security-Policy-Report-Only"] = (
                    "default-src 'self'; worker-src 'none'; report-uri /csp-report"
                )
            return self.respond(200, "<!doctype html><title>E029 fixture</title>",
                                "text/html; charset=utf-8", headers)
        if path == "/shared-worker.js":
            return self.respond(200, WORKER_JS, "application/javascript")
        if path == "/service-worker.js":
            return self.respond(200, SERVICE_JS, "application/javascript")
        if path == "/redirect-shared-worker.js":
            self.send_response(302)
            self.send_header("Location", "/shared-worker.js")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        self.respond(404, "not found", "text/plain")

    def do_POST(self):
        if urlsplit(self.path).path != "/csp-report":
            return self.respond(404, "not found", "text/plain")
        length = min(int(self.headers.get("Content-Length", "0")), 65536)
        self.rfile.read(length)
        self.send_response(204)
        self.send_header("Content-Length", "0")
        self.end_headers()


def sha1(path):
    digest = hashlib.sha1()
    with path.open("rb") as handle:
        for data in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(data)
    return digest.hexdigest()


def browser_processes():
    output = subprocess.run(
        ["tasklist", "/FI", "IMAGENAME eq r3dfox.exe", "/FO", "CSV", "/NH"],
        capture_output=True, text=True, check=True,
    ).stdout
    return [row for row in csv.reader(output.splitlines())
            if row and row[0].lower() == "r3dfox.exe"]


def wait_for_exit(seconds=30):
    start = time.monotonic()
    while time.monotonic() - start < seconds:
        if not browser_processes():
            return True, round(time.monotonic() - start, 3)
        time.sleep(0.5)
    return False, round(time.monotonic() - start, 3)


def require_worker(result, context):
    if not isinstance(result, dict) or result.get("ok") is not True:
        raise AssertionError(f"{context}: {result}")
    if result.get("echo") != "E029" or not result.get("token"):
        raise AssertionError(f"{context}: invalid worker reply: {result}")
    return result


def check(condition, label, data=None):
    if not condition:
        raise AssertionError(f"{label}: {data}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--browser", type=Path)
    parser.add_argument("--geckodriver", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f"http://127.0.0.1:{server.server_port}"

    if args.self_test:
        try:
            for path, expected in (
                ("/page", b"E029 fixture"),
                ("/shared-worker.js", b"onconnect"),
                ("/service-worker.js", b"install"),
                ("/redirect-shared-worker.js", b"onconnect"),
            ):
                with urllib.request.urlopen(base + path, timeout=5) as response:
                    check(expected in response.read(), "fixture", path)
            with urllib.request.urlopen(base + "/blocked", timeout=5) as response:
                check("worker-src 'none'" in
                      response.headers.get("Content-Security-Policy", ""),
                      "CSP response header")
            print("E029 FIXTURE SELF-TEST PASS")
            return 0
        finally:
            server.shutdown()
            server.server_close()

    if not args.browser or not args.geckodriver or not args.output:
        parser.error("--browser, --geckodriver and --output are required")
    args.output.mkdir(parents=True, exist_ok=True)
    report = {
        "test": "E029 prebuilt-host SharedWorker/CSP external regression",
        "source_under_test": SOURCE_SHA,
        "artifact_id": ARTIFACT_ID,
        "ci_controller_sha": os.environ.get("GITHUB_SHA", "LOCAL"),
        "platform": "host Windows, not physical XP",
        "native_actor_lifetime": "NOT_TESTED",
        "cases": [],
    }
    driver = None
    started = time.monotonic()

    def case(name, callback):
        item = {"name": name, "status": "FAIL"}
        try:
            value = callback()
            item["status"] = "PASS"
            if value is not None:
                item["result"] = value
        except Exception as exc:
            item["error"] = f"{type(exc).__name__}: {exc}"
            print(f"FAIL {name}: {item['error']}", flush=True)
        else:
            print(f"PASS {name}", flush=True)
        report["cases"].append(item)

    try:
        def identity():
            check(args.browser.is_file(), "missing browser", args.browser)
            check(args.geckodriver.is_file(), "missing geckodriver", args.geckodriver)
            for name, expected in EXPECTED_SHA1.items():
                path = args.browser.parent / name
                check(path.is_file(), "missing binary", name)
                actual = sha1(path)
                check(actual == expected, f"artifact member SHA-1 mismatch: {name}",
                      actual)
            check(not browser_processes(), "stale r3dfox process before test")
            return {"matched": list(EXPECTED_SHA1), "preexisting_browser_pids": 0}
        case("artifact_identity_and_clean_host", identity)
        check(report["cases"][-1]["status"] == "PASS", "identity preflight failed")

        from selenium import webdriver
        from selenium.webdriver.firefox.options import Options
        from selenium.webdriver.firefox.service import Service

        opts = Options()
        opts.binary_location = str(args.browser.resolve())
        opts.add_argument("-headless")
        opts.add_argument("-no-remote")
        opts.set_preference("browser.shell.checkDefaultBrowser", False)
        opts.set_preference("browser.startup.page", 0)
        service = Service(
            executable_path=str(args.geckodriver.resolve()),
            log_output=str(args.output / "geckodriver.log"),
        )
        driver = webdriver.Firefox(service=service, options=opts)
        driver.set_script_timeout(20)
        driver.set_page_load_timeout(30)
        driver.get(base + "/page")
        primary = driver.current_window_handle

        state = {}

        def shared_clients():
            first = require_worker(
                driver.execute_async_script(WORKER_CALL, "/shared-worker.js",
                                            "e029-common"), "first client"
            )
            driver.switch_to.new_window("tab")
            driver.get(base + "/page")
            second = require_worker(
                driver.execute_async_script(WORKER_CALL, "/shared-worker.js",
                                            "e029-common"), "second client"
            )
            check(first["token"] == second["token"],
                  "two tabs did not share the same worker")
            check(first["connections"] == 1 and second["connections"] == 2,
                  "unexpected SharedWorker client counts", (first, second))
            state["clients"] = True
            return {"shared_token_same": True, "connection_counts": [1, 2]}

        def redirect_worker():
            driver.get(base + "/page")
            result = require_worker(
                driver.execute_async_script(WORKER_CALL,
                                            "/redirect-shared-worker.js",
                                            "e029-redirect"), "redirected worker"
            )
            return {"redirected_worker_connected": result["connections"] >= 1}

        def blocked_worker():
            driver.get(base + "/blocked")
            result = driver.execute_async_script(CSP_BLOCK_CALL)
            check(result.get("blocked") is True,
                  "worker-src policy did not block SharedWorker", result)
            return result

        def report_only_worker():
            driver.get(base + "/report-only")
            result = driver.execute_async_script(CSP_REPORT_CALL)
            check(result.get("connected") is True, "report-only blocked worker", result)
            check(result.get("report") is True,
                  "no report-only CSP violation observed", result)
            return result

        def service_worker():
            driver.get(base + "/page")
            result = driver.execute_async_script(SERVICE_CALL)
            check(result.get("active") is True,
                  "ServiceWorker activation/unregistration failed", result)
            return {"registered_active_and_unregistered": True}

        case("shared_worker_two_clients", shared_clients)
        case("shared_worker_same_origin_redirect", redirect_worker)
        case("csp_worker_src_blocked", blocked_worker)
        case("csp_report_only_worker_allowed", report_only_worker)
        case("service_worker_control", service_worker)

    except Exception as exc:
        report["setup_failure"] = f"{type(exc).__name__}: {exc}"
        print("E029 SETUP FAILURE:", report["setup_failure"], flush=True)
    finally:
        if driver is not None:
            result = {"name": "webdriver_graceful_quit_and_process_retirement",
                      "status": "FAIL"}
            quit_error = []
            def quit_browser():
                try:
                    driver.quit()
                except Exception as exc:
                    quit_error.append(f"{type(exc).__name__}: {exc}")
            closer = threading.Thread(target=quit_browser, daemon=True)
            closer.start()
            closer.join(timeout=50)
            if closer.is_alive():
                result["error"] = "WebDriver quit did not return within 50 s"
            elif quit_error:
                result["error"] = quit_error[0]
            else:
                try:
                    stopped, elapsed = wait_for_exit(30)
                    result["process_retired"] = stopped
                    result["retirement_observation_seconds"] = elapsed
                    if stopped:
                        result["status"] = "PASS"
                    else:
                        result["error"] = "r3dfox.exe still running after WebDriver quit"
                except Exception as exc:
                    result["error"] = f"{type(exc).__name__}: {exc}"
            report["cases"].append(result)
            print(f"{result['status']} {result['name']}", flush=True)
        server.shutdown()
        server.server_close()
        report["duration_seconds"] = round(time.monotonic() - started, 2)
        report["status"] = (
            "PASS" if report["cases"] and
            all(item["status"] == "PASS" for item in report["cases"]) and
            "setup_failure" not in report else "FAIL"
        )
        result_path = args.output / "e029-prebuilt-report.json"
        result_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(f"E029 HOST PREBUILT OVERALL {report['status']}", flush=True)
        print(f"Detailed status: {result_path}", flush=True)
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
