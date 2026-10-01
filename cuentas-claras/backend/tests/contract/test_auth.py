from unittest.mock import patch


def test_register_success(client, db_session):
    """Test exitoso de registro de un nuevo usuario."""
    response = client.post("/api/auth/register", json={
        "name": "Ivan",
        "email": "ivan@example.com",
        "password": "supersecurepassword123",
        "short_name": "I"
    })
    assert response.status_code == 201
    data = response.get_json()
    assert "token" in data
    assert "user" in data
    assert data["user"]["email"] == "ivan@example.com"
    assert data["user"]["name"] == "Ivan"

def test_register_missing_fields(client, db_session):
    """Test de registro con campos requeridos faltantes."""
    response = client.post("/api/auth/register", json={
        "email": "ivan@example.com",
    })
    assert response.status_code == 400
    assert "error" in response.get_json()

def test_register_duplicate_email(client, db_session):
    """Test de registro con un email que ya está en uso."""
    # Primer registro
    client.post("/api/auth/register", json={
        "name": "Ivan",
        "email": "ivan@example.com",
        "password": "supersecurepassword123",
    })
    # Segundo registro con mismo email
    response = client.post("/api/auth/register", json={
        "name": "Ivan Duplicado",
        "email": "ivan@example.com",
        "password": "anotherpassword123",
    })
    assert response.status_code == 409
    assert "error" in response.get_json()

def test_login_success(client, db_session):
    """Test de login exitoso."""
    # Registrar primero
    client.post("/api/auth/register", json={
        "name": "Ivan",
        "email": "ivan@example.com",
        "password": "supersecurepassword123",
    })
    # Login
    response = client.post("/api/auth/login", json={
        "email": "ivan@example.com",
        "password": "supersecurepassword123"
    })
    assert response.status_code == 200
    data = response.get_json()
    assert "token" in data
    assert "user" in data
    assert data["user"]["email"] == "ivan@example.com"

def test_login_wrong_credentials(client, db_session):
    """Test de login con contraseña incorrecta."""
    client.post("/api/auth/register", json={
        "name": "Ivan",
        "email": "ivan@example.com",
        "password": "supersecurepassword123",
    })
    response = client.post("/api/auth/login", json={
        "email": "ivan@example.com",
        "password": "wrongpassword"
    })
    assert response.status_code == 401
    assert "error" in response.get_json()

def test_google_login_unauthorized_rejected(client, db_session):
    """Test de que usuarios de Google no pre-autorizados son rechazados con 403."""
    mock_id_info = {
        "email": "unauthorized@example.com",
        "name": "Unauthorized User",
        "picture": "https://example.com/photo.jpg",
        "aud": "test_google_client_id"
    }
    with patch("app.routes.auth.id_token.verify_oauth2_token", return_value=mock_id_info):
        response = client.post("/api/auth/google-login", json={
            "idToken": "fake_google_token"
        })
        assert response.status_code == 403
        data = response.get_json()
        assert "Acceso denegado" in data["error"]

def test_google_login_success(client, db_session):
    """Test de login/registro con Google exitoso para usuario pre-autorizado."""
    from app.models.user import AuthorizedEmail
    auth_email = AuthorizedEmail(email="googleuser@example.com", notes="Test user")
    db_session.session.add(auth_email)
    db_session.session.commit()

    mock_id_info = {
        "email": "googleuser@example.com",
        "name": "Google User",
        "picture": "https://example.com/photo.jpg",
        "aud": "test_google_client_id"
    }
    with patch("app.routes.auth.id_token.verify_oauth2_token", return_value=mock_id_info):
        response = client.post("/api/auth/google-login", json={
            "idToken": "fake_google_token"
        })
        assert response.status_code == 200
        data = response.get_json()
        assert "token" in data
        assert "user" in data
        assert data["user"]["email"] == "googleuser@example.com"
        assert data["user"]["name"] == "Google User"

def test_google_login_missing_token(client, db_session):
    """Test de login con Google sin token."""
    response = client.post("/api/auth/google-login", json={})
    assert response.status_code == 400

def test_me_endpoint_success(client, auth_headers):
    """Test de consulta al endpoint /me con token válido."""
    response = client.get("/api/auth/me", headers=auth_headers)
    assert response.status_code == 200
    data = response.get_json()
    assert data["email"] == "test@example.com"

def test_me_endpoint_unauthorized(client):
    """Test de consulta al endpoint /me sin token o con token inválido."""
    response = client.get("/api/auth/me")
    assert response.status_code == 401

    response_invalid = client.get(
        "/api/auth/me", headers={"Authorization": "Bearer invalidtoken"}
    )
    assert response_invalid.status_code == 401


def test_register_blocked_when_disabled(app, client, db_session):
    """Test de rechazo cuando ALLOW_PUBLIC_REGISTRATION=False."""
    app.config["ALLOW_PUBLIC_REGISTRATION"] = False
    response = client.post(
        "/api/auth/register",
        json={
            "name": "Intruso",
            "email": "intruso@example.com",
            "password": "password123",
        },
    )
    assert response.status_code == 403
    assert "deshabilitado" in response.get_json()["error"]
    # Restaurar para no afectar otros tests
    app.config["ALLOW_PUBLIC_REGISTRATION"] = True


