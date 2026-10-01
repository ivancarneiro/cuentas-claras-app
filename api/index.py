import os
import sys

# Ensure api directory and backend directory are in sys.path
api_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.abspath(os.path.join(api_dir, "..", "cuentas-claras", "backend"))

for path in [api_dir, backend_dir]:
    if path not in sys.path:
        sys.path.insert(0, path)

from app import create_app

app = create_app()
handler = app
application = app
