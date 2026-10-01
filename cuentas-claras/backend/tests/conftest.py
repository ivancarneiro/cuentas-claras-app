import os
import sys
from datetime import timedelta

import pytest

# Asegurar que el directorio raíz del backend esté en el PYTHONPATH
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app, db


class TestConfig:
    TESTING = True
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SECRET_KEY = "test_secret_key"
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=15)
    ALLOW_PUBLIC_REGISTRATION = True
    GOOGLE_CLIENT_ID = "test_google_client_id"

@pytest.fixture
def app():
    """Fixture que crea e inicializa la aplicación Flask para testing."""
    app = create_app(TestConfig)
    return app

@pytest.fixture
def client(app):
    """Fixture para obtener el cliente HTTP de testing de Flask."""
    return app.test_client()

@pytest.fixture
def db_session(app):
    """Fixture que inicializa las tablas de la DB en memoria y las limpia después de cada test."""
    with app.app_context():
        db.create_all()
        yield db
        db.session.remove()
        db.drop_all()

@pytest.fixture
def auth_headers(client, db_session):
    """Fixture helper para registrar un usuario, iniciar sesión y obtener los headers de autorización."""
    # 1. Registrar usuario
    client.post("/api/auth/register", json={
        "name": "Usuario Test",
        "email": "test@example.com",
        "password": "testpassword123",
        "short_name": "T"
    })
    # 2. Login
    res = client.post("/api/auth/login", json={
        "email": "test@example.com",
        "password": "testpassword123"
    })
    token = res.get_json()["token"]
    return {"Authorization": f"Bearer {token}"}
