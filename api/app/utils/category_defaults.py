# -*- coding: utf-8 -*-
"""
Valores por defecto para las categorías iniciales de un grupo familiar.
Acá definimos las categorías básicas que todo hogar tiene que tener al crearse.
"""

DEFAULT_CATEGORIES = [
    # INGRESOS
    {"name": "Salario", "type": "income", "icon": "💰", "sort_order": 1},
    {"name": "Hs Extra", "type": "income", "icon": "⏰", "sort_order": 2},
    {"name": "Adicionales", "type": "income", "icon": "🎁", "sort_order": 3},
    {"name": "Otros Ingresos", "type": "income", "icon": "📥", "sort_order": 4},
    # GASTOS FIJOS
    {"name": "Alquiler / Cuota Dpto", "type": "fixed_expense", "icon": "🏠", "sort_order": 10},
    {"name": "Luz", "type": "fixed_expense", "icon": "💡", "sort_order": 11},
    {"name": "Agua", "type": "fixed_expense", "icon": "🚰", "sort_order": 12},
    {"name": "Gas", "type": "fixed_expense", "icon": "🔥", "sort_order": 13},
    {"name": "Internet", "type": "fixed_expense", "icon": "🌐", "sort_order": 14},
    {"name": "Seguros", "type": "fixed_expense", "icon": "🛡️", "sort_order": 15},
    {"name": "Expensas", "type": "fixed_expense", "icon": "🏢", "sort_order": 16},
    # GASTOS VARIABLES
    {"name": "Comida / Supermercado", "type": "variable_expense", "icon": "🛒", "sort_order": 20},
    {"name": "Delivery / Salidas", "type": "variable_expense", "icon": "🍕", "sort_order": 21},
    {"name": "Transporte", "type": "variable_expense", "icon": "🚗", "sort_order": 22},
    {"name": "Salud / Farmacia", "type": "variable_expense", "icon": "💊", "sort_order": 23},
    {"name": "Indumentaria", "type": "variable_expense", "icon": "👕", "sort_order": 24},
    {"name": "Educación", "type": "variable_expense", "icon": "📚", "sort_order": 25},
    {"name": "Entretenimiento", "type": "variable_expense", "icon": "🎬", "sort_order": 26},
    {"name": "Mascotas", "type": "variable_expense", "icon": "🐾", "sort_order": 27},
    {"name": "Varios", "type": "variable_expense", "icon": "📦", "sort_order": 28},
    # AHORROS
    {"name": "Ahorro Mensual", "type": "savings", "icon": "🏦", "sort_order": 40},
]


def seed_default_categories(household_id, user_id):
    """
    Carga las categorías por defecto para un Household recién creado.
    Asocia cada categoría a este Household y al usuario que lo creó.
    """
    from app import db
    from app.models.category import Category

    for cat in DEFAULT_CATEGORIES:
        category = Category(
            name=cat["name"],
            type=cat["type"],
            icon=cat["icon"],
            sort_order=cat["sort_order"],
            household_id=household_id,
            user_id=user_id,
        )
        db.session.add(category)
