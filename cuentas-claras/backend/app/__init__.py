import logging
import sqlite3

from flask import Flask
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import event
from sqlalchemy.engine import Engine

from config import Config

db = SQLAlchemy()
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[],
    storage_uri="memory://",
)



@limiter.request_filter
def exempt_options():
    from flask import request

    return request.method == "OPTIONS"



@event.listens_for(Engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    if isinstance(dbapi_connection, sqlite3.Connection):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()


def create_app(config_class=Config, logger=None):
    app = Flask(__name__)
    app.config.from_object(config_class)

    if logger is None:
        logger = logging.getLogger(__name__)

    CORS(app)
    db.init_app(app)

    # Configurar Limiter con fallback para testing
    if not app.config.get("TESTING", False):
        limiter.init_app(app)


    from app.models import (  # noqa: F401
        AuthorizedEmail,
        Category,
        Household,
        HouseholdMember,
        Invitation,
        MonthlyBudget,
        Saving,
        SavingAccount,
        Transaction,
        User,
    )

    with app.app_context():
        try:
            db.create_all()
            logger.info("Base de datos inicializada (tablas creadas/verificadas)")
        except Exception as e:
            logger.error("Error al ejecutar db.create_all(): %s", e)

        # Migración segura y automática para esquemas existentes (ej. PostgreSQL en producción)
        try:
            with db.engine.begin() as conn:
                dialect = conn.dialect.name
                if dialect == "postgresql":
                    conn.execute(db.text("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;"))
                elif dialect == "sqlite":
                    cursor = conn.connection.cursor()
                    cursor.execute("PRAGMA table_info(users);")
                    cols = [row[1] for row in cursor.fetchall()]
                    if "is_active" not in cols:
                        conn.execute(db.text("ALTER TABLE users ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT 1;"))
            logger.info("Auto-migración completada exitosamente.")
        except Exception as e:
            logger.warning("Aviso en auto-migración de esquema: %s", e)

    from app.routes.admin import admin_bp
    from app.routes.auth import auth_bp
    from app.routes.categories import categories_bp
    from app.routes.households import households_bp
    from app.routes.monthly import monthly_bp
    from app.routes.savings import savings_bp
    from app.routes.transactions import transactions_bp
    from app.routes.version import version_bp

    app.register_blueprint(admin_bp, url_prefix="/api/admin")
    app.register_blueprint(auth_bp, url_prefix="/api/auth")
    app.register_blueprint(categories_bp, url_prefix="/api/categories")
    app.register_blueprint(transactions_bp, url_prefix="/api/transactions")
    app.register_blueprint(monthly_bp, url_prefix="/api/monthly")
    app.register_blueprint(savings_bp, url_prefix="/api/savings")
    app.register_blueprint(households_bp, url_prefix="/api/households")
    app.register_blueprint(version_bp, url_prefix="/api/version")

    logger.info(
        "Blueprints registrados: admin, auth, categories, transactions, monthly, savings, households, version"
    )


    @app.route("/api/health")
    def health():
        return {"status": "ok", "app": "Cuentas Claras"}

    return app
