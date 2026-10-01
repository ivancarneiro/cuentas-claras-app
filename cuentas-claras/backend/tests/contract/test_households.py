# -*- coding: utf-8 -*-
"""
Tests de contrato para hogares (households).
Verificamos que al crear un nuevo hogar se generen las categorías por defecto correspondientes.
"""

from app.models.category import Category
from app.models.household import HouseholdMember
from app.models.user import User


def test_create_household_seeds_default_categories(client, auth_headers):
    """
    Verificamos que al crear un nuevo Household, se precarguen automáticamente
    las categorías más habituales.
    """
    # 1. Crear el Household
    response = client.post(
        "/api/households",
        headers=auth_headers,
        json={"name": "Hogar Test Autoseed"},
    )
    assert response.status_code == 201
    data = response.get_json()
    household_id = data["id"]

    # 2. Consultar las categorías en la DB para este household
    categories = Category.query.filter_by(household_id=household_id).all()

    # Comprobamos que no esté vacío y que tenga las categorías que definimos por defecto
    assert len(categories) > 0

    category_names = [c.name for c in categories]
    assert "Salario" in category_names
    assert "Hs Extra" in category_names
    assert "Luz" in category_names
    assert "Agua" in category_names
    assert "Gas" in category_names
    assert "Comida / Supermercado" in category_names
    assert "Ahorro Mensual" in category_names

    # 3. Validar a través del endpoint GET /api/categories
    response_categories = client.get("/api/categories", headers=auth_headers)
    assert response_categories.status_code == 200

    categories_json = response_categories.get_json()
    json_names = [c["name"] for c in categories_json]
    assert "Salario" in json_names
    assert "Luz" in json_names
    assert "Comida / Supermercado" in json_names


def test_accept_invitation_success(client, auth_headers, db_session):
    """
    Verificamos que un usuario invitado pueda listar y aceptar una invitación
    de forma exitosa, uniéndose al grupo familiar sin errores de zona horaria.
    """
    # 1. Registrar y loguear al usuario invitado
    client.post("/api/auth/register", json={
        "name": "Invitado Test",
        "email": "invitado@example.com",
        "password": "invitadopassword123",
        "short_name": "I"
    })
    res_login = client.post("/api/auth/login", json={
        "email": "invitado@example.com",
        "password": "invitadopassword123"
    })
    invitado_token = res_login.get_json()["token"]
    invitado_headers = {"Authorization": f"Bearer {invitado_token}"}

    # 2. Creador crea un Household
    res_hh = client.post(
        "/api/households",
        headers=auth_headers,
        json={"name": "Hogar Compartido"},
    )
    household_id = res_hh.get_json()["id"]

    # 3. Creador invita al usuario invitado
    res_invite = client.post(
        f"/api/households/{household_id}/invite",
        headers=auth_headers,
        json={"email": "invitado@example.com", "role": "edit"},
    )
    assert res_invite.status_code == 201
    token = res_invite.get_json()["token"]
    assert token is not None

    # 4. Invitado consulta sus invitaciones pendientes
    res_pending = client.get(
        "/api/households/invitations/pending",
        headers=invitado_headers
    )
    assert res_pending.status_code == 200
    pending_list = res_pending.get_json()
    assert len(pending_list) == 1
    assert pending_list[0]["token"] == token

    # 5. Invitado acepta la invitación
    res_accept = client.post(
        f"/api/households/invitations/{token}/accept",
        headers=invitado_headers
    )
    assert res_accept.status_code == 200
    assert res_accept.get_json()["message"] == "Invitación aceptada"

    # 6. Validar que el invitado sea miembro del grupo en la base de datos
    memberships = HouseholdMember.query.filter_by(
        household_id=household_id,
        user_id=User.query.filter_by(email="invitado@example.com").first().id,
    ).all()
    assert len(memberships) == 1
    assert memberships[0].role == "edit"


def test_delete_household_success(client, auth_headers):
    """Verificamos que un grupo sin transacciones pueda ser eliminado por su Owner."""
    # 1. Crear el Household
    res = client.post(
        "/api/households",
        headers=auth_headers,
        json={"name": "Grupo Para Borrar"},
    )
    assert res.status_code == 201
    household_id = res.get_json()["id"]

    # 2. Eliminar el Household
    res_del = client.delete(
        f"/api/households/{household_id}", headers=auth_headers
    )
    assert res_del.status_code == 200
    assert "eliminado correctamente" in res_del.get_json()["message"]

    # 3. Verificar que ya no exista ni se pueda acceder
    res_get = client.get(
        f"/api/households/{household_id}", headers=auth_headers
    )
    assert res_get.status_code in (403, 404)



def test_delete_household_with_transactions_fails(
    client, auth_headers, db_session
):
    """Verificamos que no se permita eliminar un grupo con transacciones asociadas."""
    # 1. Crear Household
    res = client.post(
        "/api/households",
        headers=auth_headers,
        json={"name": "Grupo Con Movimientos"},
    )
    assert res.status_code == 201
    household_id = res.get_json()["id"]

    # 2. Crear una categoría en ese household
    res_cat = client.post(
        "/api/categories",
        headers=auth_headers,
        json={
            "name": "Comida Especial",
            "type": "variable_expense",
            "household_id": household_id,
        },
    )
    cat_id = res_cat.get_json()["id"]

    # 3. Crear una transacción
    res_tx = client.post(
        "/api/transactions",
        headers=auth_headers,
        json={
            "amount": 2500.0,
            "currency": "ARS",
            "type": "expense",
            "category_id": cat_id,
            "household_id": household_id,
            "date": "2026-08-15",
            "description": "Cena",
        },
    )
    assert res_tx.status_code == 201

    # 4. Intentar eliminar el household debe fallar con 400
    res_del = client.delete(
        f"/api/households/{household_id}", headers=auth_headers
    )
    assert res_del.status_code == 400
    assert "transacción(es) asociada(s)" in res_del.get_json()["error"]


def test_household_pending_invitations_and_48h_ttl(client, auth_headers):
    """
    Verificamos que las invitaciones tengan un TTL de 48 horas máx,
    que aparezcan en GET /api/households/mine dentro del household,
    y que re-invitar renueve la invitación sin error.
    """
    from datetime import datetime, timezone, timedelta

    # 1. Crear un household
    res_hh = client.post(
        "/api/households",
        headers=auth_headers,
        json={"name": "Hogar TTL Test"},
    )
    assert res_hh.status_code == 201
    hh_id = res_hh.get_json()["id"]

    # 2. Invitar a un email
    res_inv = client.post(
        f"/api/households/{hh_id}/invite",
        headers=auth_headers,
        json={"email": "futuro_miembro@example.com", "role": "edit"},
    )
    assert res_inv.status_code == 201
    inv_data = res_inv.get_json()
    token_1 = inv_data["token"]
    assert token_1 is not None

    # Verificar que el TTL es de aprox 48hs (máximo 48 horas)
    expires_at = datetime.fromisoformat(inv_data["expires_at"].replace("Z", "+00:00"))
    now = datetime.now(timezone.utc)
    delta = expires_at - now
    # Debe ser menor o igual a 48hs y mayor a 47hs
    assert timedelta(hours=47) <= delta <= timedelta(hours=48, minutes=1)

    # 3. Consultar /api/households/mine y validar que aparece en pending_invitations
    res_mine = client.get("/api/households/mine", headers=auth_headers)
    assert res_mine.status_code == 200
    households = res_mine.get_json()
    current_hh = next((h for h in households if h["id"] == hh_id), None)
    assert current_hh is not None
    assert "pending_invitations" in current_hh
    assert len(current_hh["pending_invitations"]) == 1
    pending_item = current_hh["pending_invitations"][0]
    assert pending_item["invited_email"] == "futuro_miembro@example.com"
    assert pending_item["role"] == "edit"
    assert pending_item["token"] == token_1
    assert "invitar/" in pending_item["invitation_link"]

    # 4. Re-invitar al mismo usuario renueva la invitación con nuevo token y 48hs
    res_reinv = client.post(
        f"/api/households/{hh_id}/invite",
        headers=auth_headers,
        json={"email": "futuro_miembro@example.com", "role": "admin"},
    )
    assert res_reinv.status_code == 201
    reinv_data = res_reinv.get_json()
    assert reinv_data["role"] == "admin"
    assert reinv_data["token"] != token_1

    # 5. Volver a consultar /api/households/mine: sigue habiendo 1 sola invitación con el nuevo rol
    res_mine_2 = client.get("/api/households/mine", headers=auth_headers)
    current_hh_2 = next((h for h in res_mine_2.get_json() if h["id"] == hh_id), None)
    assert len(current_hh_2["pending_invitations"]) == 1
    assert current_hh_2["pending_invitations"][0]["role"] == "admin"


