import os
import sys
import traceback

# Add backend directory to Python path
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "cuentas-claras", "backend"))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

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
