from datetime import date

import pytest

from app.models.category import Category
from app.models.household import Household, HouseholdMember
from app.models.transaction import Transaction
from app.models.user import User


@pytest.fixture
def setup_data(db_session, auth_headers):
    """Fixture para configurar los datos básicos (User, Household, Category) para el usuario autenticado."""
    user = User.query.filter_by(email="test@example.com").first()

    household = Household(name="Familia Test", created_by=user.id)
    db_session.session.add(household)
    db_session.session.commit()

    member = HouseholdMember(household_id=household.id, user_id=user.id, role="owner")
    db_session.session.add(member)
    db_session.session.commit()

    category = Category(name="Supermercado", type="expense", household_id=household.id)
    db_session.session.add(category)
    db_session.session.commit()

    return {
        "user": user,
        "household": household,
        "category": category
    }

@pytest.fixture
def setup_other_household(db_session):
    """Fixture para crear otro usuario y un household separado, para probar controles de acceso."""
    other_user = User(name="Otro Usuario", email="otro@example.com")
    other_user.set_password("otrapassword123")
    db_session.session.add(other_user)
    db_session.session.commit()

    other_household = Household(name="Familia Ajena", created_by=other_user.id)
    db_session.session.add(other_household)
    db_session.session.commit()

    member = HouseholdMember(household_id=other_household.id, user_id=other_user.id, role="owner")
    db_session.session.add(member)
    db_session.session.commit()

    other_category = Category(name="Salidas", type="expense", household_id=other_household.id)
    db_session.session.add(other_category)
    db_session.session.commit()

    return {
        "user": other_user,
        "household": other_household,
        "category": other_category
    }

def test_create_transaction_success(client, auth_headers, setup_data, db_session):
    """Crear una transacción de forma exitosa."""
    data = setup_data
    response = client.post("/api/transactions", headers=auth_headers, json={
        "user_id": data["user"].id,
        "category_id": data["category"].id,
        "date": "2026-06-15",
        "amount": 5400.50,
        "type": "expense",
        "currency": "ARS",
        "description": "Compra de verdulería"
    })
    assert response.status_code == 201
    res_data = response.get_json()
    assert res_data["amount"] == 5400.50
    assert res_data["type"] == "expense"
    assert res_data["currency"] == "ARS"

    # Validar que el household_id se guardó correctamente en la DB
    created_t = db_session.session.get(Transaction, res_data["id"])
    assert created_t.household_id == data["household"].id

def test_create_transaction_missing_fields(client, auth_headers, setup_data):
    """Intentar crear una transacción omitiendo campos obligatorios."""
    data = setup_data
    # Falta el campo 'amount'
    response = client.post("/api/transactions", headers=auth_headers, json={
        "user_id": data["user"].id,
        "category_id": data["category"].id,
        "date": "2026-06-15",
        "type": "expense"
    })
    assert response.status_code == 400
    assert "error" in response.get_json()

def test_create_transaction_invalid_date(client, auth_headers, setup_data):
    """Intentar crear una transacción con formato de fecha inválido."""
    data = setup_data
    response = client.post("/api/transactions", headers=auth_headers, json={
        "user_id": data["user"].id,
        "category_id": data["category"].id,
        "date": "15/06/2026",
        "amount": 1200,
        "type": "expense"
    })
    assert response.status_code == 400
    assert "Format" in response.get_json()["error"] or "fecha" in response.get_json()["error"]

def test_create_transaction_invalid_type(client, auth_headers, setup_data):
    """Intentar crear una transacción con tipo incorrecto."""
    data = setup_data
    response = client.post("/api/transactions", headers=auth_headers, json={
        "user_id": data["user"].id,
        "category_id": data["category"].id,
        "date": "2026-06-15",
        "amount": 1200,
        "type": "invalid_type"
    })
    assert response.status_code == 400

def test_get_transactions_filtered(client, auth_headers, setup_data, db_session):
    """Listar y filtrar transacciones por mes, año, categoría y tipo."""
    data = setup_data

    # Crear transacciones de prueba
    t1 = Transaction(
        user_id=data["user"].id,
        household_id=data["household"].id,
        category_id=data["category"].id,
        date=date(2026, 6, 10),
        amount=1500,
        type="expense"
    )
    t2 = Transaction(
        user_id=data["user"].id,
        household_id=data["household"].id,
        category_id=data["category"].id,
        date=date(2026, 5, 20),
        amount=2500,
        type="expense"
    )
    db_session.session.add_all([t1, t2])
    db_session.session.commit()

    # Filtrar por junio 2026
    res = client.get("/api/transactions?month=6&year=2026", headers=auth_headers)
    assert res.status_code == 200
    res_data = res.get_json()
    assert len(res_data) == 1
    assert res_data[0]["amount"] == 1500

def test_update_transaction_success(client, auth_headers, setup_data, db_session):
    """Actualizar datos de una transacción propia."""
    data = setup_data
    t = Transaction(
        user_id=data["user"].id,
        household_id=data["household"].id,
        category_id=data["category"].id,
        date=date(2026, 6, 10),
        amount=1500,
        type="expense"
    )
    db_session.session.add(t)
    db_session.session.commit()

    response = client.put(f"/api/transactions/{t.id}", headers=auth_headers, json={
        "amount": 1750.00,
        "description": "Monto corregido"
    })
    assert response.status_code == 200
    res_data = response.get_json()
    assert res_data["amount"] == 1750.00
    assert res_data["description"] == "Monto corregido"

def test_delete_transaction_success(client, auth_headers, setup_data, db_session):
    """Eliminar una transacción propia."""
    data = setup_data
    t = Transaction(
        user_id=data["user"].id,
        household_id=data["household"].id,
        category_id=data["category"].id,
        date=date(2026, 6, 10),
        amount=1500,
        type="expense"
    )
    db_session.session.add(t)
    db_session.session.commit()

    response = client.delete(f"/api/transactions/{t.id}", headers=auth_headers)
    assert response.status_code == 200

    # Verificar que ya no exista
    assert db_session.session.get(Transaction, t.id) is None

def test_unauthorized_cross_household_access(
    client, auth_headers, setup_data, setup_other_household, db_session
):
    """Intentar ver, editar o eliminar una transacción de otro household debe retornar 403."""
    other = setup_other_household

    # Crear transacción en el household ajeno
    t_other = Transaction(
        user_id=other["user"].id,
        household_id=other["household"].id,
        category_id=other["category"].id,
        date=date(2026, 6, 10),
        amount=3000,
        type="expense"
    )
    db_session.session.add(t_other)
    db_session.session.commit()

    # Intentar editarla usando las credenciales del usuario de setup_data (que no tiene acceso a other_household)
    response_update = client.put(f"/api/transactions/{t_other.id}", headers=auth_headers, json={
        "amount": 4000
    })
    assert response_update.status_code == 403

    # Intentar eliminarla
    response_delete = client.delete(f"/api/transactions/{t_other.id}", headers=auth_headers)
    assert response_delete.status_code == 403

def test_create_transaction_negative_amount(client, auth_headers, setup_data):
    """Intentar crear una transacción con un monto negativo o cero."""
    data = setup_data
    # Monto negativo
    response = client.post("/api/transactions", headers=auth_headers, json={
        "user_id": data["user"].id,
        "category_id": data["category"].id,
        "date": "2026-06-15",
        "amount": -50.00,
        "type": "expense"
    })
    assert response.status_code == 400
    assert "monto" in response.get_json()["error"] or "amount" in response.get_json()["error"]

    # Monto cero
    response_zero = client.post("/api/transactions", headers=auth_headers, json={
        "user_id": data["user"].id,
        "category_id": data["category"].id,
        "date": "2026-06-15",
        "amount": 0,
        "type": "expense"
    })
    assert response_zero.status_code == 400
    assert "monto" in response_zero.get_json()["error"] or "amount" in response_zero.get_json()["error"]

def test_update_transaction_negative_amount(client, auth_headers, setup_data, db_session):
    """Intentar actualizar una transacción con un monto negativo o cero."""
    data = setup_data
    t = Transaction(
        user_id=data["user"].id,
        household_id=data["household"].id,
        category_id=data["category"].id,
        date=date(2026, 6, 10),
        amount=1500,
        type="expense"
    )
    db_session.session.add(t)
    db_session.session.commit()

    response = client.put(f"/api/transactions/{t.id}", headers=auth_headers, json={
        "amount": -100.00
    })
    assert response.status_code == 400
    assert "monto" in response.get_json()["error"] or "amount" in response.get_json()["error"]
