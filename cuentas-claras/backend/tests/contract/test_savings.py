import pytest

from app.models.household import Household, HouseholdMember
from app.models.saving import Saving, SavingAccount
from app.models.user import User


@pytest.fixture
def setup_savings_data(db_session, auth_headers):
    """Fixture para configurar cuenta de ahorro, usuario y hogar."""
    user = User.query.filter_by(email="test@example.com").first()

    household = Household(name="Familia Ahorro", created_by=user.id)
    db_session.session.add(household)
    db_session.session.commit()

    member = HouseholdMember(household_id=household.id, user_id=user.id, role="owner")
    db_session.session.add(member)
    db_session.session.commit()

    account = SavingAccount(
        name="U$D Naranja X",
        currency="USD",
        owner_id=user.id,
        household_id=household.id
    )
    db_session.session.add(account)
    db_session.session.commit()

    return {
        "user": user,
        "household": household,
        "account": account
    }

def test_create_account_success(client, auth_headers, setup_savings_data):
    """Crear una cuenta de ahorro exitosamente."""
    response = client.post("/api/savings/accounts", headers=auth_headers, json={
        "name": "BullMarket USD",
        "currency": "USD"
    })
    assert response.status_code == 201
    assert response.get_json()["name"] == "BullMarket USD"

def test_create_saving_success(client, auth_headers, setup_savings_data):
    """Registrar un balance mensual exitosamente."""
    data = setup_savings_data
    response = client.post("/api/savings", headers=auth_headers, json={
        "account_id": data["account"].id,
        "month": 6,
        "year": 2026,
        "balance": 1500.00,
        "balance_ars": 1425000.00,
        "note": "Ahorro de junio"
    })
    assert response.status_code == 201
    assert response.get_json()["balance"] == 1500.00

def test_create_saving_negative_balance(client, auth_headers, setup_savings_data):
    """Intentar registrar un balance negativo."""
    data = setup_savings_data
    response = client.post("/api/savings", headers=auth_headers, json={
        "account_id": data["account"].id,
        "month": 6,
        "year": 2026,
        "balance": -100.00
    })
    assert response.status_code == 400
    assert "balance" in response.get_json()["error"]

    response_ars = client.post("/api/savings", headers=auth_headers, json={
        "account_id": data["account"].id,
        "month": 6,
        "year": 2026,
        "balance": 100.00,
        "balance_ars": -950000
    })
    assert response_ars.status_code == 400
    assert "balance" in response_ars.get_json()["error"]

def test_update_saving_negative_balance(client, auth_headers, setup_savings_data, db_session):
    """Intentar actualizar un balance con valor negativo."""
    data = setup_savings_data
    s = Saving(
        account_id=data["account"].id,
        household_id=data["household"].id,
        month=6,
        year=2026,
        balance=1500.00
    )
    db_session.session.add(s)
    db_session.session.commit()

    response = client.put(
        f"/api/savings/{s.id}",
        headers=auth_headers,
        json={"balance": -50.00},
    )
    assert response.status_code == 400
    assert "balance" in response.get_json()["error"]


def test_delete_account_success(client, auth_headers, setup_savings_data):
    """Eliminar una cuenta de ahorro sin registros asociados debe ser exitoso."""
    # 1. Crear cuenta nueva vacía
    res = client.post(
        "/api/savings/accounts",
        headers=auth_headers,
        json={"name": "Cuenta Temporal", "currency": "ARS"},
    )
    assert res.status_code == 201
    acc_id = res.get_json()["id"]

    # 2. Eliminar cuenta
    res_del = client.delete(
        f"/api/savings/accounts/{acc_id}", headers=auth_headers
    )
    assert res_del.status_code == 200
    assert "eliminada correctamente" in res_del.get_json()["message"]


def test_delete_account_with_savings_fails(
    client, auth_headers, setup_savings_data, db_session
):
    """Intentar eliminar una cuenta con balances registrados debe retornar 400."""
    data = setup_savings_data
    # Agregar un balance a la cuenta
    s = Saving(
        account_id=data["account"].id,
        household_id=data["household"].id,
        month=6,
        year=2026,
        balance=1500.00,
    )
    db_session.session.add(s)
    db_session.session.commit()

    # Intentar eliminar la cuenta
    response = client.delete(
        f"/api/savings/accounts/{data['account'].id}", headers=auth_headers
    )
    assert response.status_code == 400
    assert "registro(s) de ahorro asociado(s)" in response.get_json()["error"]

