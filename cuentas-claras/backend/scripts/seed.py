"""
Seed script: Crea usuarios y categorías iniciales basadas en el ODS de CUENTAS CLARAS.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app import create_app, db
from app.models.category import Category
from app.models.saving import SavingAccount
from app.models.user import User

app = create_app()

with app.app_context():
    db.create_all()

    # --- USERS ---
    if User.query.count() == 0:
        ivan = User(
            name="Ivan",
            email="ivan@cuentasclaras.app",
            short_name="I",
        )
        ivan.set_password("123456")

        tamara = User(
            name="Tamara",
            email="tamara@cuentasclaras.app",
            short_name="T",
        )
        tamara.set_password("123456")

        db.session.add(ivan)
        db.session.add(tamara)
        db.session.commit()
        print("✅ Usuarios creados: Ivan (I) y Tamara (T)")
    else:
        print("ℹ️  Usuarios ya existen, se omite seed")

    # --- CATEGORIES ---
    if Category.query.count() == 0:
        categories = [
            # INGRESOS
            {"name": "Sueldo Ivan", "type": "income", "icon": "💰", "sort_order": 1},
            {"name": "Sueldo Tamara", "type": "income", "icon": "💰", "sort_order": 2},
            {"name": "Hs Extra Ivan", "type": "income", "icon": "⏰", "sort_order": 3},
            {
                "name": "Hs Extra Tamara",
                "type": "income",
                "icon": "⏰",
                "sort_order": 4,
            },
            {"name": "Otros Ingresos", "type": "income", "icon": "📥", "sort_order": 5},
            # GASTOS FIJOS
            {
                "name": "Alquiler / Cuota Dpto",
                "type": "fixed_expense",
                "icon": "🏠",
                "sort_order": 10,
            },
            {
                "name": "Tarjeta Ivan",
                "type": "fixed_expense",
                "icon": "💳",
                "sort_order": 11,
            },
            {
                "name": "Tarjeta Tamara",
                "type": "fixed_expense",
                "icon": "💳",
                "sort_order": 12,
            },
            {
                "name": "Expensas",
                "type": "fixed_expense",
                "icon": "🏢",
                "sort_order": 13,
            },
            {
                "name": "Metrogas",
                "type": "fixed_expense",
                "icon": "🔥",
                "sort_order": 14,
            },
            {"name": "Luz", "type": "fixed_expense", "icon": "💡", "sort_order": 15},
            {"name": "Agua", "type": "fixed_expense", "icon": "🚰", "sort_order": 16},
            {
                "name": "Internet",
                "type": "fixed_expense",
                "icon": "🌐",
                "sort_order": 17,
            },
            {"name": "Seguros", "type": "fixed_expense", "icon": "🛡️", "sort_order": 18},
            {"name": "ABL", "type": "fixed_expense", "icon": "🏛️", "sort_order": 19},
            # GASTOS VARIABLES
            {
                "name": "Comida / Supermercado",
                "type": "variable_expense",
                "icon": "🛒",
                "sort_order": 20,
            },
            {
                "name": "Verdulería",
                "type": "variable_expense",
                "icon": "🥬",
                "sort_order": 21,
            },
            {
                "name": "Delivery / Salidas",
                "type": "variable_expense",
                "icon": "🍕",
                "sort_order": 22,
            },
            {
                "name": "Transporte",
                "type": "variable_expense",
                "icon": "🚗",
                "sort_order": 23,
            },
            {
                "name": "Salud / Farmacia",
                "type": "variable_expense",
                "icon": "💊",
                "sort_order": 24,
            },
            {
                "name": "Indumentaria",
                "type": "variable_expense",
                "icon": "👕",
                "sort_order": 25,
            },
            {
                "name": "Educación",
                "type": "variable_expense",
                "icon": "📚",
                "sort_order": 26,
            },
            {
                "name": "Entretenimiento",
                "type": "variable_expense",
                "icon": "🎬",
                "sort_order": 27,
            },
            {
                "name": "Servicios",
                "type": "variable_expense",
                "icon": "🔧",
                "sort_order": 28,
            },
            {
                "name": "Mascotas",
                "type": "variable_expense",
                "icon": "🐾",
                "sort_order": 29,
            },
            {
                "name": "Regalos",
                "type": "variable_expense",
                "icon": "🎁",
                "sort_order": 30,
            },
            {
                "name": "Varios",
                "type": "variable_expense",
                "icon": "📦",
                "sort_order": 31,
            },
            # AHORROS
            {
                "name": "Ahorro Mensual",
                "type": "savings",
                "icon": "🏦",
                "sort_order": 40,
            },
        ]

        for cat in categories:
            c = Category(**cat)
            db.session.add(c)

        db.session.commit()
        print(f"✅ {len(categories)} categorías creadas")
    else:
        print("ℹ️  Categorías ya existen, se omite seed")

    # --- SAVING ACCOUNTS (from AHORROS_Telmo & AHORROS_26) ---
    if SavingAccount.query.count() == 0:
        accounts = [
            {"name": "BTC", "currency": "BTC", "description": "Bitcoin"},
            {"name": "PEPE", "currency": "PEPE", "description": "Pepe coin"},
            {"name": "USDT", "currency": "USDT", "description": "Tether"},
            {"name": "R$ FT", "currency": "BRL", "description": "Reales en FT"},
            {"name": "U$D NX", "currency": "USD", "description": "Dólar en Nexo"},
            {"name": "U$D FT", "currency": "USD", "description": "Dólar en FT"},
            {"name": "BullMarket", "currency": "ARS", "description": "BullMarket"},
            {"name": "Sobró 2025", "currency": "ARS", "description": "Excedente 2025"},
        ]
        for acc in accounts:
            a = SavingAccount(**acc)
            db.session.add(a)

        db.session.commit()
        print(f"✅ {len(accounts)} cuentas de ahorro creadas")
    else:
        print("ℹ️  Cuentas de ahorro ya existen, se omite seed")

    print("\n🎯 Seed completado!")
