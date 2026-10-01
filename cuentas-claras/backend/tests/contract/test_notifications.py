# -*- coding: utf-8 -*-
"""
Tests de contrato para el sistema de notificaciones (in-app y device tokens).
"""

from app import db
from app.models.category import Category
from app.models.household import Household, HouseholdMember
from app.models.notification import DeviceToken, Notification
from app.models.user import User


def test_get_notifications_empty(client, auth_headers):
    """Un usuario sin notificaciones debe recibir una lista vacía y 0 unread."""
    res = client.get("/api/notifications", headers=auth_headers)
    assert res.status_code == 200
    data = res.get_json()
    assert "notifications" in data
    assert len(data["notifications"]) == 0

    res_count = client.get("/api/notifications/unread-count", headers=auth_headers)
    assert res_count.status_code == 200
    assert res_count.get_json()["unread_count"] == 0


def test_transaction_creation_notifies_other_household_members(client, auth_headers):
    """
    Cuando un usuario A crea una transacción en un household compartido con usuario B,
    el usuario B debe recibir una notificación in-app (y el usuario A no).
    """
    # 1. Crear usuario B
    user_b = User(name="Usuario B", email="user_b@test.com", password_hash="hash")
    db.session.add(user_b)
    db.session.commit()

    # 2. Crear un hogar compartido
    res_hh = client.post("/api/households", headers=auth_headers, json={"name": "Hogar Compartido"})
    assert res_hh.status_code == 201
    hh_id = res_hh.get_json()["id"]

    # Agregar a usuario B al hogar
    member_b = HouseholdMember(household_id=hh_id, user_id=user_b.id, role="edit")
    db.session.add(member_b)
    db.session.commit()

    # 3. Usuario A crea una transacción en el hogar compartido
    cat = Category.query.filter_by(household_id=hh_id).first()
    res_tx = client.post(
        "/api/transactions",
        headers=auth_headers,
        json={
            "household_id": hh_id,
            "category_id": cat.id,
            "date": "2026-10-01",
            "amount": 25000.0,
            "currency": "ARS",
            "type": "expense",
            "description": "Supermercado del mes",
        },
    )
    assert res_tx.status_code == 201

    # 4. Verificar que el usuario B tiene 1 notificación
    notifs_b = Notification.query.filter_by(user_id=user_b.id).all()
    assert len(notifs_b) == 1
    assert "Nuevo movimiento" in notifs_b[0].title
    assert "25,000.00" in notifs_b[0].message
    assert notifs_b[0].is_read is False

    # 5. Verificar que el usuario A (el actor) NO tiene notificación de su propia acción
    user_a = User.query.filter_by(email="test@example.com").first()
    notifs_a = Notification.query.filter_by(user_id=user_a.id).all()
    assert len(notifs_a) == 0


def test_mark_notification_as_read(client, auth_headers):
    """Marcar notificación individual y masiva como leída."""
    user = User.query.filter_by(email="test@example.com").first()
    notif1 = Notification(user_id=user.id, title="Aviso 1", message="Mensaje 1", is_read=False)
    notif2 = Notification(user_id=user.id, title="Aviso 2", message="Mensaje 2", is_read=False)
    db.session.add_all([notif1, notif2])
    db.session.commit()

    # Verificar conteo = 2
    res_count = client.get("/api/notifications/unread-count", headers=auth_headers)
    assert res_count.get_json()["unread_count"] == 2

    # Marcar la primera como leída
    res_read = client.post(f"/api/notifications/{notif1.id}/read", headers=auth_headers)
    assert res_read.status_code == 200

    res_count = client.get("/api/notifications/unread-count", headers=auth_headers)
    assert res_count.get_json()["unread_count"] == 1

    # Marcar todas como leídas
    res_read_all = client.post("/api/notifications/read-all", headers=auth_headers)
    assert res_read_all.status_code == 200

    res_count = client.get("/api/notifications/unread-count", headers=auth_headers)
    assert res_count.get_json()["unread_count"] == 0


def test_register_and_unregister_device_token(client, auth_headers):
    """Registrar y desvincular token FCM de dispositivo."""
    # Registrar token
    res = client.post(
        "/api/notifications/device-token",
        headers=auth_headers,
        json={"token": "fcm_token_test_12345", "platform": "android"},
    )
    assert res.status_code == 200

    token_db = DeviceToken.query.filter_by(token="fcm_token_test_12345").first()
    assert token_db is not None
    assert token_db.platform == "android"

    # Desvincular token
    res_del = client.delete(
        "/api/notifications/device-token",
        headers=auth_headers,
        json={"token": "fcm_token_test_12345"},
    )
    assert res_del.status_code == 200
    assert DeviceToken.query.filter_by(token="fcm_token_test_12345").first() is None
