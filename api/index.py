import json
import os
import sys
import traceback

# Ensure api directory and backend directory are in sys.path
api_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.abspath(os.path.join(api_dir, "..", "cuentas-claras", "backend"))

for path in [api_dir, backend_dir]:
    if path not in sys.path:
        sys.path.insert(0, path)

try:
    from app import create_app
    _flask_app = create_app()
    _init_error = None
except Exception as e:
    _flask_app = None
    _init_error = f"{e}\n{traceback.format_exc()}"
    print(f"CRITICAL BACKEND INIT ERROR: {_init_error}", file=sys.stderr)


def application(environ, start_response):
    if _init_error:
        status = "500 Internal Server Error"
        response_headers = [
            ("Content-Type", "application/json"),
            ("Access-Control-Allow-Origin", "*"),
            ("Access-Control-Allow-Headers", "*"),
            ("Access-Control-Allow-Methods", "*"),
        ]
        start_response(status, response_headers)
        return [json.dumps({"error": "Backend initialization failed", "details": _init_error}).encode("utf-8")]
    try:
        return _flask_app(environ, start_response)
    except Exception as exc:
        tb = traceback.format_exc()
        print(f"WSGI REQUEST EXCEPTION: {exc}\n{tb}", file=sys.stderr)
        status = "500 Internal Server Error"
        response_headers = [
            ("Content-Type", "application/json"),
            ("Access-Control-Allow-Origin", "*"),
            ("Access-Control-Allow-Headers", "*"),
            ("Access-Control-Allow-Methods", "*"),
        ]
        start_response(status, response_headers)
        return [json.dumps({"error": str(exc), "traceback": tb}).encode("utf-8")]


app = application
handler = application
