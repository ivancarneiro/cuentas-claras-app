import os
from datetime import timedelta

from dotenv import load_dotenv

basedir = os.path.abspath(os.path.dirname(__file__))
load_dotenv(os.path.join(basedir, ".env"))


class Config:
    ENV = os.environ.get("ENV") or os.environ.get("FLASK_ENV", "production")
    SECRET_KEY = os.environ.get("SECRET_KEY")
    if not SECRET_KEY:
        raise ValueError("No se ha configurado la variable de entorno SECRET_KEY.")

    db_url = os.environ.get("DATABASE_URL")
    if db_url and db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql://", 1)

    SQLALCHEMY_DATABASE_URI = (
        db_url or f"sqlite:///{os.path.join(basedir, 'cuentas_claras.db')}"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Token expiration: configurable via JWT_EXPIRY_HOURS (default 24h)
    jwt_expiry_hours = int(os.environ.get("JWT_EXPIRY_HOURS", "24"))
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=jwt_expiry_hours)

    # Rate limiting
    RATELIMIT_STORAGE_URI = os.environ.get("RATELIMIT_STORAGE_URI", "memory://")

    # Control de registro público
    ALLOW_PUBLIC_REGISTRATION = (
        os.environ.get("ALLOW_PUBLIC_REGISTRATION", "false").lower()
        in ("true", "1", "yes")
    )

    GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID")

    # GitHub Releases / In-App Update
    GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    GITHUB_REPO = os.environ.get("GITHUB_REPO", "ivancarneiro/cuentas-claras-app")
    LATEST_APP_VERSION = os.environ.get("LATEST_APP_VERSION", "1.0.7")

    # Emails con permisos de propietario / admin
    APP_OWNER_EMAILS = [
        e.strip().lower()
        for e in os.environ.get(
            "APP_OWNER_EMAILS", "admin@cuentasclaras.app"
        ).split(",")
        if e.strip()
    ]


