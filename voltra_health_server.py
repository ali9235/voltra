"""VOLTRA health server — the one canonical server for this project.

Apple Watch -> Apple Health -> Health Auto Export -> POST /health
            -> _data/health_payload.json -> GET /health/summary and /health/series

Binds to the LAN so the iPhone can reach it. It is never meant to be exposed
to the internet: no port forwarding, no tunnels.
"""

from flask import Flask, request, jsonify
import ipaddress
import json
import logging
import os
import shutil
import socket
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path
from datetime import datetime, timedelta
from statistics import mean
from urllib.parse import urlparse

app = Flask(__name__)

SERVER_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SERVER_DIR.parent if SERVER_DIR.name.lower() == "lib" else SERVER_DIR
# Ali's health data lives in _data/, which is gitignored. It used to sit loose
# in the project root, where it was also tracked by git — 3 MB of personal
# heart-rate and sleep history in the repository history. Moving it keeps the
# root tidy AND keeps the data out of any commit.
#
# The move happens once, automatically, on the first start after this change:
# the old root file is copied in rather than required, so nothing is lost if
# this code is ever rolled back.
DATA_DIR = PROJECT_ROOT / "_data"
DATA_FILE = DATA_DIR / "health_payload.json"
LEGACY_DATA_FILE = PROJECT_ROOT / "health_payload.json"
LOG_DIR = PROJECT_ROOT / "_logs"
PORT = 8766


def migrate_legacy_payload():
    """Bring a root-level health_payload.json into _data/ if that is all we have.

    Copies, never moves: if the server is downgraded the old file is still
    there. Returns True when a migration happened.
    """
    try:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        if DATA_FILE.exists() or not LEGACY_DATA_FILE.exists():
            return False
        shutil.copy2(LEGACY_DATA_FILE, DATA_FILE)
        return True
    except OSError as exc:
        log.warning("could not move the health payload into _data: %s", exc)
        return False


DATE_FORMAT = "%Y-%m-%d %H:%M:%S %z"

log = logging.getLogger("voltra")


def setup_logging():
    """Rotating file log that never takes the server down.

    A log file left locked by an earlier run used to make the server die on
    startup with nothing written anywhere. So: every step is optional. If the
    rotating file cannot be opened we try a pid-suffixed name, and if that
    fails too we simply keep logging to the console.
    """
    log.setLevel(logging.INFO)
    log.handlers.clear()

    console = logging.StreamHandler(sys.stdout)
    console.setFormatter(logging.Formatter("%(asctime)s  %(message)s", "%H:%M:%S"))
    log.addHandler(console)

    fmt = logging.Formatter("%(asctime)s  %(levelname)-7s %(message)s")

    for candidate in (
        LOG_DIR / "health_server.log",
        LOG_DIR / f"health_server.{os.getpid()}.log",
    ):
        try:
            LOG_DIR.mkdir(parents=True, exist_ok=True)
            handler = RotatingFileHandler(
                candidate,
                maxBytes=512 * 1024,
                backupCount=3,
                encoding="utf-8",
                delay=True,
            )
            handler.setFormatter(fmt)
            handler.emit(
                logging.LogRecord(
                    "voltra", logging.INFO, __file__, 0,
                    "log opened: %s", (candidate.name,), None,
                )
            )
            log.addHandler(handler)
            # Request lines land in the same rotating file instead of only
            # in whatever console window happened to launch the server.
            logging.getLogger("werkzeug").addHandler(handler)
            return candidate
        except OSError as e:
            console.handle(
                logging.LogRecord(
                    "voltra", logging.WARNING, __file__, 0,
                    "could not open %s (%s) - trying next",
                    (candidate.name, e), None,
                )
            )

    log.warning("file logging is off; console only")
    return None


def lan_ip():
    """Best-effort LAN address, so the banner is never a stale hardcoded IP."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.connect(("8.8.8.8", 80))  # no packet is sent; this only picks a route
            return s.getsockname()[0]
        finally:
            s.close()
    except OSError:
        return None


def is_local_origin(hostname):
    """Allow the Flutter web app from loopback or this machine's own LAN."""
    if not hostname:
        return False

    if hostname == "localhost":
        return True

    try:
        ip = ipaddress.ip_address(hostname)
    except ValueError:
        return False

    return ip.is_loopback or ip.is_private


def parse_date(value):
    if not value:
        return None
    try:
        return datetime.strptime(value, DATE_FORMAT)
    except (TypeError, ValueError):
        return None


def round_number(value, digits=2):
    if value is None:
        return None
    return round(float(value), digits)


def load_health_payload():
    if not DATA_FILE.exists():
        raise FileNotFoundError(f"Health payload not found: {DATA_FILE}")

    with DATA_FILE.open("r", encoding="utf-8") as f:
        return json.load(f)


def metric_map(payload):
    metrics = payload.get("data", {}).get("metrics", [])
    return {
        metric.get("name"): metric
        for metric in metrics
        if isinstance(metric, dict) and metric.get("name")
    }


def latest_payload_datetime(metrics):
    latest = None

    for metric in metrics.values():
        for item in metric.get("data", []):
            if not isinstance(item, dict):
                continue

            dt = parse_date(item.get("date"))
            if dt and (latest is None or dt > latest):
                latest = dt

    return latest


def point_value(item, metric_name):
    if metric_name == "heart_rate":
        value = item.get("Avg")
    else:
        value = item.get("qty")

    return value if isinstance(value, (int, float)) else None


def summarize_point_metric(metric, metric_name, reference_date):
    if not metric:
        return None

    records = []

    for item in metric.get("data", []):
        if not isinstance(item, dict):
            continue

        dt = parse_date(item.get("date"))
        value = point_value(item, metric_name)

        if dt is not None and value is not None:
            records.append((dt, float(value), item))

    if not records:
        return None

    records.sort(key=lambda row: row[0])
    latest_dt, latest_value, latest_item = records[-1]
    start_date = reference_date - timedelta(days=6)

    today_values = [
        value
        for dt, value, _ in records
        if dt.date() == reference_date
    ]

    week_values = [
        value
        for dt, value, _ in records
        if start_date <= dt.date() <= reference_date
    ]

    result = {
        "unit": metric.get("units"),
        "latest": round_number(latest_value),
        "latest_at": latest_dt.isoformat(),
        "today_average": round_number(mean(today_values)) if today_values else None,
        "seven_day_average": round_number(mean(week_values)) if week_values else None,
        "today_samples": len(today_values),
        "seven_day_samples": len(week_values),
    }

    if today_values:
        result["today_min"] = round_number(min(today_values))
        result["today_max"] = round_number(max(today_values))
    else:
        result["today_min"] = None
        result["today_max"] = None

    if metric_name == "heart_rate":
        min_value = latest_item.get("Min")
        max_value = latest_item.get("Max")
        result["latest_min"] = round_number(min_value) if isinstance(min_value, (int, float)) else None
        result["latest_max"] = round_number(max_value) if isinstance(max_value, (int, float)) else None

    return result


def summarize_total_metric(metric, reference_date):
    if not metric:
        return None

    records = []

    for item in metric.get("data", []):
        if not isinstance(item, dict):
            continue

        dt = parse_date(item.get("date"))
        value = item.get("qty")

        if dt is not None and isinstance(value, (int, float)):
            records.append((dt, float(value)))

    if not records:
        return None

    records.sort(key=lambda row: row[0])
    latest_dt, latest_value = records[-1]
    start_date = reference_date - timedelta(days=6)

    daily_totals = {}

    for dt, value in records:
        day = dt.date()

        if start_date <= day <= reference_date:
            daily_totals[day] = daily_totals.get(day, 0.0) + value

    today_total = daily_totals.get(reference_date)

    observed_daily_totals = list(daily_totals.values())

    return {
        "unit": metric.get("units"),
        "latest_sample": round_number(latest_value),
        "latest_at": latest_dt.isoformat(),
        "today_total": round_number(today_total) if today_total is not None else None,
        "seven_day_total": round_number(sum(observed_daily_totals)) if observed_daily_totals else None,
        "seven_day_daily_average": (
            round_number(mean(observed_daily_totals))
            if observed_daily_totals
            else None
        ),
        "days_with_data": len(daily_totals),
    }


def summarize_sleep(metric, reference_date):
    if not metric:
        return None

    records = []

    for item in metric.get("data", []):
        if not isinstance(item, dict):
            continue

        sleep_end = parse_date(item.get("sleepEnd"))
        sleep_start = parse_date(item.get("sleepStart"))
        date_value = parse_date(item.get("date"))
        sort_dt = sleep_end or sleep_start or date_value

        if sort_dt is not None:
            records.append((sort_dt, item))

    if not records:
        return None

    records.sort(key=lambda row: row[0])
    latest_dt, latest = records[-1]
    start_date = reference_date - timedelta(days=6)

    week_records = [
        item
        for dt, item in records
        if start_date <= dt.date() <= reference_date
    ]

    sleep_values = [
        float(item.get("totalSleep"))
        for item in week_records
        if isinstance(item.get("totalSleep"), (int, float))
    ]

    stage_names = ("awake", "core", "deep", "rem")
    stages = {
        stage: round_number(latest.get(stage), 3)
        if isinstance(latest.get(stage), (int, float))
        else None
        for stage in stage_names
    }

    stages_available = any(
        isinstance(latest.get(stage), (int, float)) and latest.get(stage) > 0
        for stage in stage_names
    )

    return {
        "unit": metric.get("units", "hr"),
        "latest_date": latest_dt.date().isoformat(),
        "sleep_start": latest.get("sleepStart"),
        "sleep_end": latest.get("sleepEnd"),
        "total_sleep_hours": round_number(latest.get("totalSleep"), 3)
        if isinstance(latest.get("totalSleep"), (int, float))
        else None,
        "asleep_hours": round_number(latest.get("asleep"), 3)
        if isinstance(latest.get("asleep"), (int, float))
        else None,
        "stages": stages,
        "stages_available": stages_available,
        "seven_day_average_sleep_hours": (
            round_number(mean(sleep_values), 3)
            if sleep_values
            else None
        ),
        "sleep_records_in_window": len(week_records),
        "source": latest.get("source"),
    }


def build_summary(payload):
    metrics = metric_map(payload)
    latest_dt = latest_payload_datetime(metrics)

    if latest_dt is None:
        raise ValueError("No dated health metric samples were found.")

    reference_date = latest_dt.date()

    heart_rate = summarize_point_metric(
        metrics.get("heart_rate"),
        "heart_rate",
        reference_date,
    )

    hrv = summarize_point_metric(
        metrics.get("heart_rate_variability"),
        "heart_rate_variability",
        reference_date,
    )

    resting_heart_rate = summarize_point_metric(
        metrics.get("resting_heart_rate"),
        "resting_heart_rate",
        reference_date,
    )

    steps = summarize_total_metric(
        metrics.get("step_count"),
        reference_date,
    )

    active_energy = summarize_total_metric(
        metrics.get("active_energy"),
        reference_date,
    )

    exercise_time = summarize_total_metric(
        metrics.get("apple_exercise_time"),
        reference_date,
    )

    distance = summarize_total_metric(
        metrics.get("walking_running_distance"),
        reference_date,
    )

    sleep = summarize_sleep(
        metrics.get("sleep_analysis"),
        reference_date,
    )

    if active_energy:
        today_kj = active_energy.get("today_total")
        week_avg_kj = active_energy.get("seven_day_daily_average")

        active_energy["today_kcal"] = (
            round_number(today_kj / 4.184)
            if today_kj is not None
            else None
        )

        active_energy["seven_day_daily_average_kcal"] = (
            round_number(week_avg_kj / 4.184)
            if week_avg_kj is not None
            else None
        )

    return {
        "ok": True,
        "reference_date": reference_date.isoformat(),
        "latest_sample_at": latest_dt.isoformat(),
        "available_metrics": sorted(metrics.keys()),
        "overview": {
            "heart_rate": heart_rate,
            "resting_heart_rate": resting_heart_rate,
            "hrv": hrv,
            "steps": steps,
            "active_energy": active_energy,
            "exercise_time": exercise_time,
            "walking_running_distance": distance,
            "sleep": sleep,
        },
    }


def daily_totals(metric, reference_date, days):
    """[{date, value}] per day for a metric that is summed (steps, energy...)."""
    if not metric:
        return None

    start_date = reference_date - timedelta(days=days - 1)
    totals = {}

    for item in metric.get("data", []):
        if not isinstance(item, dict):
            continue

        dt = parse_date(item.get("date"))
        value = item.get("qty")

        if dt is None or not isinstance(value, (int, float)):
            continue

        day = dt.date()
        if start_date <= day <= reference_date:
            totals[day] = totals.get(day, 0.0) + float(value)

    if not totals:
        return None

    return {
        "unit": metric.get("units"),
        "kind": "total",
        "points": [
            {"date": day.isoformat(), "value": round_number(totals[day])}
            for day in sorted(totals)
        ],
    }


def daily_averages(metric, metric_name, reference_date, days):
    """[{date, value, min, max}] per day for a metric that is averaged."""
    if not metric:
        return None

    start_date = reference_date - timedelta(days=days - 1)
    buckets = {}

    for item in metric.get("data", []):
        if not isinstance(item, dict):
            continue

        dt = parse_date(item.get("date"))
        value = point_value(item, metric_name)

        if dt is None or value is None:
            continue

        day = dt.date()
        if start_date <= day <= reference_date:
            buckets.setdefault(day, []).append(float(value))

    if not buckets:
        return None

    return {
        "unit": metric.get("units"),
        "kind": "average",
        "points": [
            {
                "date": day.isoformat(),
                "value": round_number(mean(buckets[day])),
                "min": round_number(min(buckets[day])),
                "max": round_number(max(buckets[day])),
                "samples": len(buckets[day]),
            }
            for day in sorted(buckets)
        ],
    }


def daily_sleep(metric, reference_date, days):
    """One entry per night. Stage values are passed through untouched and the
    stages_available flag is computed per night, so the client can refuse to
    draw stage charts for nights that have none."""
    if not metric:
        return None

    start_date = reference_date - timedelta(days=days - 1)
    stage_names = ("awake", "core", "deep", "rem")
    points = []

    for item in metric.get("data", []):
        if not isinstance(item, dict):
            continue

        sleep_end = parse_date(item.get("sleepEnd"))
        sleep_start = parse_date(item.get("sleepStart"))
        sort_dt = sleep_end or sleep_start or parse_date(item.get("date"))

        if sort_dt is None:
            continue

        day = sort_dt.date()
        if not (start_date <= day <= reference_date):
            continue

        total = item.get("totalSleep")

        points.append({
            "date": day.isoformat(),
            "value": round_number(total, 3)
            if isinstance(total, (int, float))
            else None,
            "sleep_start": item.get("sleepStart"),
            "sleep_end": item.get("sleepEnd"),
            "stages_available": any(
                isinstance(item.get(s), (int, float)) and item.get(s) > 0
                for s in stage_names
            ),
        })

    if not points:
        return None

    points.sort(key=lambda p: p["date"])

    return {
        "unit": metric.get("units", "hr"),
        "kind": "sleep",
        "points": points,
    }


def build_series(payload, days):
    metrics = metric_map(payload)
    latest_dt = latest_payload_datetime(metrics)

    if latest_dt is None:
        raise ValueError("No dated health metric samples were found.")

    reference_date = latest_dt.date()

    series = {
        "steps": daily_totals(metrics.get("step_count"), reference_date, days),
        "active_energy": daily_totals(
            metrics.get("active_energy"), reference_date, days
        ),
        "exercise_time": daily_totals(
            metrics.get("apple_exercise_time"), reference_date, days
        ),
        "walking_running_distance": daily_totals(
            metrics.get("walking_running_distance"), reference_date, days
        ),
        "heart_rate": daily_averages(
            metrics.get("heart_rate"), "heart_rate", reference_date, days
        ),
        "resting_heart_rate": daily_averages(
            metrics.get("resting_heart_rate"),
            "resting_heart_rate",
            reference_date,
            days,
        ),
        "hrv": daily_averages(
            metrics.get("heart_rate_variability"),
            "heart_rate_variability",
            reference_date,
            days,
        ),
        "sleep": daily_sleep(metrics.get("sleep_analysis"), reference_date, days),
    }

    # active_energy arrives in kJ. Convert once, here, so the client never has
    # to know about the unit mismatch.
    energy = series.get("active_energy")
    if energy:
        energy["unit"] = "kcal"
        for point in energy["points"]:
            if point["value"] is not None:
                point["value"] = round_number(point["value"] / 4.184)

    observed_days = set()
    for block in series.values():
        if block:
            for point in block["points"]:
                observed_days.add(point["date"])

    return {
        "ok": True,
        "reference_date": reference_date.isoformat(),
        "days_requested": days,
        "days_with_data": len(observed_days),
        "first_day": min(observed_days) if observed_days else None,
        "last_day": max(observed_days) if observed_days else None,
        "series": series,
    }


@app.get("/health/series")
def health_series():
    try:
        days = int(request.args.get("days", 30))
    except (TypeError, ValueError):
        days = 30

    days = max(1, min(days, 365))

    try:
        payload = load_health_payload()
        return jsonify(build_series(payload, days)), 200

    except FileNotFoundError as e:
        return jsonify({"ok": False, "error": str(e)}), 404

    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.after_request
def add_local_cors_headers(response):
    origin = request.headers.get("Origin")

    if origin:
        try:
            hostname = urlparse(origin).hostname
        except ValueError:
            hostname = None

        if is_local_origin(hostname):
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Vary"] = "Origin"

    return response


@app.get("/")
def home():
    return """
    <h1>VOLTRA Health Server</h1>
    <p>Server is running ✅</p>
    <p>POST health data to: /health</p>
    <p>GET parsed summary from: /health/summary</p>
    <p>GET daily series from: /health/series?days=30</p>
    """


@app.get("/ping")
def ping():
    return jsonify({
        "ok": True,
        "message": "VOLTRA Health Server is running"
    })


@app.get("/health/summary")
def health_summary():
    try:
        payload = load_health_payload()
        return jsonify(build_summary(payload)), 200

    except FileNotFoundError as e:
        return jsonify({
            "ok": False,
            "error": str(e)
        }), 404

    except Exception as e:
        return jsonify({
            "ok": False,
            "error": str(e)
        }), 500


@app.route("/health", methods=["GET", "POST"])
def health():
    if request.method == "GET":
        if not DATA_FILE.exists():
            return jsonify({
                "ok": True,
                "message": "No health data received yet"
            })

        try:
            with DATA_FILE.open("r", encoding="utf-8") as f:
                data = json.load(f)

            return jsonify({
                "ok": True,
                "data": data
            })

        except Exception as e:
            return jsonify({
                "ok": False,
                "error": str(e)
            }), 500

    try:
        data = request.get_json(silent=True)

        if data is None:
            raw = request.get_data(as_text=True)

            try:
                data = json.loads(raw)
            except Exception:
                data = {
                    "raw": raw
                }

        DATA_DIR.mkdir(parents=True, exist_ok=True)

        with DATA_FILE.open("w", encoding="utf-8") as f:
            json.dump(
                data,
                f,
                indent=2,
                ensure_ascii=False
            )

        received_metrics = sorted(metric_map(data).keys())

        log.info(
            "health data received - %d metrics: %s",
            len(received_metrics),
            ", ".join(received_metrics) or "(none)",
        )

        return jsonify({
            "ok": True,
            "message": "Health data received successfully",
            "metrics_received": received_metrics
        }), 200

    except Exception as e:
        log.exception("health receive error: %s", e)

        return jsonify({
            "ok": False,
            "error": str(e)
        }), 500


if __name__ == "__main__":
    log_file = setup_logging()
    moved_payload = migrate_legacy_payload()
    ip = lan_ip()
    phone = f"http://{ip}:{PORT}" if ip else None

    log.info("=" * 46)
    log.info("VOLTRA HEALTH SERVER")
    log.info("=" * 46)
    log.info("This computer   http://127.0.0.1:%d", PORT)
    log.info("iPhone / LAN    %s", phone or "(no LAN address found)")
    log.info("Send health to  %s", f"{phone}/health" if phone else f"http://127.0.0.1:{PORT}/health")
    log.info("Summary         http://127.0.0.1:%d/health/summary", PORT)
    log.info("Series          http://127.0.0.1:%d/health/series?days=30", PORT)
    log.info("Payload file    %s", DATA_FILE)
    if moved_payload:
        log.info("Payload moved   from %s (the old copy was left in place)", LEGACY_DATA_FILE)
    log.info("Log file        %s", log_file or "(console only)")
    log.info("Local network only. Do not forward this port.")
    log.info("=" * 46)

    app.run(
        host="0.0.0.0",
        port=PORT,
        debug=False
    )
