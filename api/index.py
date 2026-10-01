import os
import sys
import traceback

# Add current directory (api/) and backend directory to Python path
current_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.abspath(os.path.join(current_dir, "..", "cuentas-claras", "backend"))

for path in [current_dir, backend_dir]:
    if path not in sys.path:
        sys.path.insert(0, path)

try:
    from app import create_app
    app = create_app()
except Exception as e:
    from flask import Flask, jsonify
    err_msg = str(e)
    tb = traceback.format_exc()
    print(f"Error initializing app: {err_msg}\n{tb}", file=sys.stderr)
    app = Flask(__name__)

    @app.route("/", defaults={"path": ""})
    @app.route("/<path:path>")
    def catch_all(path):
        return jsonify({"error": f"Error al inicializar backend: {err_msg}", "traceback": tb}), 500
