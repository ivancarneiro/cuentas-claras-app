import pytest

from app.models.household import Household, HouseholdMember
from app.models.user import User


@pytest.fixture
def setup_household(db_session, auth_headers):
    user = User.query.filter_by(email="test@example.com").first()
    household = Household(name="Casa Test", created_by=user.id)
    db_session.session.add(household)
    db_session.session.commit()

    member = HouseholdMember(household_id=household.id, user_id=user.id, role="owner")
    db_session.session.add(member)
    db_session.session.commit()

    return {"user": user, "household": household}


def test_monthly_summary_missing_params(client, auth_headers, setup_household, db_session):
    # Sin month ni year
    res = client.get("/api/monthly/summary", headers=auth_headers)
    assert res.status_code == 400
    assert "error" in res.get_json()

    # Solo month
    res_only_m = client.get("/api/monthly/summary?month=6", headers=auth_headers)
    assert res_only_m.status_code == 400

    # Solo year
    res_only_y = client.get("/api/monthly/summary?year=2026", headers=auth_headers)
    assert res_only_y.status_code == 400


def test_monthly_summary_empty_month(client, auth_headers, setup_household, db_session):
    res = client.get("/api/monthly/summary?month=1&year=2025", headers=auth_headers)
    assert res.status_code == 200
    data = res.get_json()
    assert data["month"] == 1
    assert data["year"] == 2025
    assert data["total_income"] == 0.0
    assert data["total_expenses"] == 0.0
    assert data["fixed_expenses"] == 0.0
    assert data["variable_expenses"] == 0.0
    assert data["savings"] == 0.0
    assert data["expenses_by_category"] == []
    assert data["income_by_category"] == []
    assert data["expenses_by_user"] == []
    assert data["income_by_user"] == []


def test_monthly_summary_calculations(client, auth_headers, setup_household, db_session):
    # 1. Crear categorías
    res_cat_sal = client.post(
        "/api/categories",
        headers=auth_headers,
        json={"name": "Sueldo", "type": "income"},
    )
    sal_cat_id = res_cat_sal.get_json()["id"]

    res_cat_rent = client.post(
        "/api/categories",
        headers=auth_headers,
        json={"name": "Alquiler", "type": "fixed_expense"},
    )
    rent_cat_id = res_cat_rent.get_json()["id"]

    res_cat_food = client.post(
        "/api/categories",
        headers=auth_headers,
        json={"name": "Supermercado", "type": "variable_expense"},
    )
    food_cat_id = res_cat_food.get_json()["id"]

    # 2. Crear transacciones para Junio 2026
    # Ingreso: 500.000
    res_tx1 = client.post(
        "/api/transactions",
        headers=auth_headers,
        json={
            "category_id": sal_cat_id,
            "date": "2026-06-05",
            "amount": 500000.0,
            "type": "income",
            "currency": "ARS",
            "description": "Sueldo Junio",
        },
    )
    assert res_tx1.status_code == 201

    # Gasto Fijo: 150.000
    res_tx2 = client.post(
        "/api/transactions",
        headers=auth_headers,
        json={
            "category_id": rent_cat_id,
            "date": "2026-06-10",
            "amount": 150000.0,
            "type": "expense",
            "is_fixed": True,
            "currency": "ARS",
            "description": "Alquiler depto",
        },
    )
    assert res_tx2.status_code == 201

    # Gasto Variable: 50.000
    res_tx3 = client.post(
        "/api/transactions",
        headers=auth_headers,
        json={
            "category_id": food_cat_id,
            "date": "2026-06-15",
            "amount": 50000.0,
            "type": "expense",
            "is_fixed": False,
            "currency": "ARS",
            "description": "Compras del mes",
        },
    )
    assert res_tx3.status_code == 201

    # 3. Consultar resumen mensual
    res = client.get("/api/monthly/summary?month=6&year=2026", headers=auth_headers)
    assert res.status_code == 200
    data = res.get_json()

    assert data["month"] == 6
    assert data["year"] == 2026
    assert data["total_income"] == 500000.0
    assert data["total_expenses"] == 200000.0
    assert data["fixed_expenses"] == 150000.0
    assert data["variable_expenses"] == 50000.0
    assert data["savings"] == 300000.0

    # Categorías
    assert len(data["expenses_by_category"]) == 2
    assert len(data["income_by_category"]) == 1
    assert data["income_by_category"][0]["name"] == "Sueldo"
    assert data["income_by_category"][0]["total"] == 500000.0

    # Usuarios
    assert len(data["expenses_by_user"]) >= 1
    assert len(data["income_by_user"]) >= 1
