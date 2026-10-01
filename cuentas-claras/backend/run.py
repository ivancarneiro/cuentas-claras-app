import logging
import logging.handlers
import sys
import time
import traceback

from werkzeug.exceptions import HTTPException

from app import create_app

# ── Logging configuration ──────────────────────────────────────────────
LOG_FILE = "/tmp/cuentasclaras.log"

# Root logger
root_logger = logging.getLogger()
root_logger.setLevel(logging.DEBUG)

# Formatter
formatter = logging.Formatter(
    "[%(asctime)s] %(levelname)s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

# File handler (rotating, keep up to 5 MB)
file_handler = logging.handlers.RotatingFileHandler(
    LOG_FILE, maxBytes=5_000_000, backupCount=2, encoding="utf-8"
)
file_handler.setLevel(logging.DEBUG)
file_handler.setFormatter(formatter)
root_logger.addHandler(file_handler)

# Stdout handler (so we still see logs in terminal)
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.INFO)
console_handler.setFormatter(formatter)
root_logger.addHandler(console_handler)

logger = logging.getLogger("cuentasclaras")

app = create_app(logger=logger)


# ── Request logging middleware ─────────────────────────────────────────
@app.before_request
def log_request_start():
    from flask import request

    request._start_time = time.time()


@app.after_request
def log_request_end(response):
    from flask import request

    duration = time.time() - getattr(request, "_start_time", time.time())
    logger.info(
        "%s %s → %s  (%.0fms)  [%s]",
        request.method,
        request.path,
        response.status_code,
        duration * 1000,
        request.remote_addr or "?",
    )
    return response


@app.errorhandler(HTTPException)
def handle_http_exception(error):

    from flask import jsonify

    return jsonify({"error": error.description}), error.code


@app.errorhandler(Exception)
def log_unhandled_error(error):
    from flask import request

    if isinstance(error, HTTPException):
        return handle_http_exception(error)

    logger.error(
        "UNHANDLED ERROR on %s %s: %s\n%s",
        request.method,
        request.path,
        error,
        traceback.format_exc(),
    )
    raise error



if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("Cuentas Claras — Backend iniciando")
    logger.info("Log file: %s", LOG_FILE)
    logger.info("=" * 60)
    app.run(host="0.0.0.0", port=5000, debug=True)
