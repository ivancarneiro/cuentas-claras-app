import os
import sys
import traceback

# Ensure api directory is in sys.path
api_dir = os.path.dirname(os.path.abspath(__file__))
if api_dir not in sys.path:
    sys.path.insert(0, api_dir)

try:
    from app import create_app
    app = create_app()
    handler = app
    application = app
except Exception as e:
    from flask import Flask, jsonify
    err_msg = str(e)
    tb = traceback.format_exc()
    print(f"Error initializing backend: {err_msg}\n{tb}", file=sys.stderr)
    app = Flask(__name__)

    @app.route("/", defaults={"path": ""})
    @app.route("/<path:path>")
    def catch_all(path):
        return jsonify({"error": f"Error al inicializar backend: {err_msg}", "traceback": tb}), 500

    handler = app
    application = app
