from flask import Flask, request, jsonify
import json
from pathlib import Path
from datetime import datetime

app = Flask(__name__)

# مكان حفظ آخر بيانات وصلت من الآيفون
DATA_FILE = Path(__file__).resolve().parent / "health_payload.json"


@app.get("/")
def home():
    return """
    <h1>VOLTRA Health Server</h1>
    <p>Server is running ✅</p>
    <p>POST health data to: /health</p>
    """


@app.get("/ping")
def ping():
    return jsonify({
        "ok": True,
        "message": "VOLTRA Health Server is running"
    })


@app.route("/health", methods=["GET", "POST"])
def health():

    # عرض آخر بيانات وصلت
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

    # استقبال بيانات Health Auto Export
    try:

        data = request.get_json(silent=True)

        # في حال لم تصل البيانات بصيغة JSON
        if data is None:

            raw = request.get_data(as_text=True)

            print("\nRAW HEALTH DATA RECEIVED:")
            print(raw)

            try:
                data = json.loads(raw)

            except Exception:
                data = {
                    "raw": raw
                }

        print("\n================================")
        print("HEALTH DATA RECEIVED")
        print(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        print("================================")

        print(
            json.dumps(
                data,
                indent=2,
                ensure_ascii=False
            )
        )

        # حفظ آخر بيانات وصلت
        with DATA_FILE.open("w", encoding="utf-8") as f:
            json.dump(
                data,
                f,
                indent=2,
                ensure_ascii=False
            )

        return jsonify({
            "ok": True,
            "message": "Health data received successfully"
        }), 200

    except Exception as e:

        print("Health receive error:", e)

        return jsonify({
            "ok": False,
            "error": str(e)
        }), 500


if __name__ == "__main__":

    print("")
    print("================================")
    print("VOLTRA HEALTH SERVER")
    print("================================")
    print("")
    print("Computer:")
    print("http://127.0.0.1:8766")
    print("")
    print("iPhone:")
    print("http://192.168.18.11:8766")
    print("")
    print("Ping:")
    print("http://192.168.18.11:8766/ping")
    print("")
    print("Health endpoint:")
    print("http://192.168.18.11:8766/health")
    print("")
    print("================================")
    print("")

    app.run(
        host="0.0.0.0",
        port=8766,
        debug=False
    )