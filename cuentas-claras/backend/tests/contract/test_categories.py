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


def test_create_category_success(client, auth_headers, setup_household, db_session):
    res = client.post(
        "/api/categories",
        headers=auth_headers,
        json={
            "name": "Supermercado",
            "type": "variable_expense",
            "icon": "shopping_cart",
            "sort_order": 1,
        },
    )
    assert res.status_code == 201
    data = res.get_json()
    assert data["name"] == "Supermercado"
    assert data["type"] == "variable_expense"
    assert data["icon"] == "shopping_cart"
    assert data["sort_order"] == 1
    assert "id" in data


def test_create_category_invalid_type(client, auth_headers, setup_household, db_session):
    res = client.post(
        "/api/categories",
        headers=auth_headers,
        json={"name": "Invalido", "type": "tipo_desconocido"},
    )
    assert res.status_code == 400
    assert "error" in res.get_json()


def test_create_category_missing_fields(client, auth_headers, setup_household, db_session):
    res = client.post(
        "/api/categories",
        headers=auth_headers,
        json={"name": "Solo Nombre"},
    )
    assert res.status_code == 400
    assert "error" in res.get_json()


def test_get_categories_list_and_filter(client, auth_headers, setup_household, db_session):
    client.post(
        "/api/categories",
        headers=auth_headers,
        json={"name": "Sueldo", "type": "income"},
    )
    client.post(
        "/api/categories",
        headers=auth_headers,
        json={"name": "Alquiler", "type": "fixed_expense"},
    )
    client.post(
        "/api/categories",
        headers=auth_headers,
        json={"name": "Salidas", "type": "variable_expense"},
    )

    # List all
    res_all = client.get("/api/categories", headers=auth_headers)
    assert res_all.status_code == 200
    all_cats = res_all.get_json()
    assert len(all_cats) >= 3

    # Filter by type
    res_income = client.get("/api/categories?type=income", headers=auth_headers)
    assert res_income.status_code == 200
    income_cats = res_income.get_json()
    assert len(income_cats) >= 1
    assert all(c["type"] == "income" for c in income_cats)


def test_get_category_by_id(client, auth_headers, setup_household, db_session):
    res = client.post(
        "/api/categories",
        headers=auth_headers,
        json={"name": "Internet", "type": "fixed_expense"},
    )
    cat_id = res.get_json()["id"]

    res_get = client.get(f"/api/categories/{cat_id}", headers=auth_headers)
    assert res_get.status_code == 200
    assert res_get.get_json()["name"] == "Internet"


def test_update_category_success(client, auth_headers, setup_household, db_session):
    res = client.post(
        "/api/categories",
        headers=auth_headers,
        json={"name": "Luz", "type": "fixed_expense"},
    )
    cat_id = res.get_json()["id"]

    res_up = client.put(
        f"/api/categories/{cat_id}",
        headers=auth_headers,
        json={"name": "Electricidad", "type": "variable_expense", "sort_order": 5},
    )
    assert res_up.status_code == 200
    updated = res_up.get_json()
    assert updated["name"] == "Electricidad"
    assert updated["type"] == "variable_expense"
    assert updated["sort_order"] == 5


def test_delete_category_success(client, auth_headers, setup_household, db_session):
    res = client.post(
        "/api/categories",
        headers=auth_headers,
        json={"name": "Para Borrar", "type": "variable_expense"},
    )
    cat_id = res.get_json()["id"]

    res_del = client.delete(f"/api/categories/{cat_id}", headers=auth_headers)
    assert res_del.status_code == 200

    # Verify 404 after delete
    res_get = client.get(f"/api/categories/{cat_id}", headers=auth_headers)
    assert res_get.status_code == 404


def test_delete_category_with_transactions_fails(client, auth_headers, setup_household, db_session):
    # 1. Crear categoría
    res_cat = client.post(
        "/api/categories",
        headers=auth_headers,
        json={"name": "Comida", "type": "variable_expense"},
    )
    cat_id = res_cat.get_json()["id"]

    # 2. Crear transacción asociada
    res_tx = client.post(
        "/api/transactions",
        headers=auth_headers,
        json={
            "category_id": cat_id,
            "date": "2026-06-15",
            "amount": 12500,
            "type": "expense",
            "currency": "ARS",
            "description": "Cena",
        },
    )
    assert res_tx.status_code == 201

    # 3. Intentar eliminar categoría — debe fallar con 400
    res_del = client.delete(f"/api/categories/{cat_id}", headers=auth_headers)
    assert res_del.status_code == 400
    assert "transacción" in res_del.get_json()["error"]
