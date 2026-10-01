"""
Migration script: Create a default household with all existing users and data.

This script:
1. Creates a "Cuentas Claras" household
2. Adds all existing users as members (Ivan → Owner, Tamara → Admin, others → Admin)
3. Assigns all existing records (transactions, categories, budgets, savings)
   to the new household

Run: python scripts/migrate_to_households.py
"""

import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app import create_app, db
from app.models import (
    Category,
    Household,
    HouseholdMember,
    MonthlyBudget,
    Saving,
    SavingAccount,
    Transaction,
    User,
)

app = create_app()

with app.app_context():
    # ── Check if already migrated ─────────────────────────────────
    existing = Household.query.first()
    if existing:
        print(f"⚠️  Ya existe un household: '{existing.name}' (id={existing.id})")
        print("   Los households ya están migrados. Saliendo.")
        sys.exit(0)

    users = User.query.all()
    if not users:
        print("❌ No hay usuarios en la DB. Ejecutá seed.py primero.")
        sys.exit(1)

    print(f"👥 Usuarios encontrados: {len(users)}")
    for u in users:
        print(f"   • {u.name} ({u.email})")

    # ── 1. Create the default household ───────────────────────────
    household = Household(
        name="Cuentas Claras",
        created_by=users[0].id,
    )
    db.session.add(household)
    db.session.flush()  # get the household id
    print(f"\n🏠 Household creado: '{household.name}' (id={household.id})")

    # ── 2. Add users as members ──────────────────────────────────
    for i, user in enumerate(users):
        # First user(s) with "ivan" or "telmo" → Owner
        # Users with "tamara" → Admin
        # Everyone else → Admin
        email_lower = user.email.lower()
        name_lower = user.name.lower()

        if (
            "ivan" in email_lower
            or "ivan" in name_lower
            or "telmo" in email_lower
            or "telmo" in name_lower
        ):
            role = "owner"
        elif "tamara" in email_lower or "tamara" in name_lower:
            role = "admin"
        else:
            role = "admin"

        member = HouseholdMember(
            household_id=household.id,
            user_id=user.id,
            role=role,
            invited_by=user.id,
            invited_at=datetime.now(timezone.utc),
            accepted_at=datetime.now(timezone.utc),
        )
        db.session.add(member)
        print(f"   • {user.name} → {role.upper()}")

    # ── 3. Assign existing data to the household ─────────────────
    tx_count = Transaction.query.update({Transaction.household_id: household.id})
    print(f"\n📊 Transacciones asignadas: {tx_count}")

    cat_count = Category.query.update({Category.household_id: household.id})
    print(f"📁 Categorías asignadas: {cat_count}")

    budget_count = MonthlyBudget.query.update(
        {MonthlyBudget.household_id: household.id}
    )
    print(f"📋 Presupuestos asignados: {budget_count}")

    acc_count = SavingAccount.query.update(
        {SavingAccount.household_id: household.id, SavingAccount.owner_id: users[0].id}
    )
    print(f"🏦 Cuentas de ahorro asignadas: {acc_count}")

    sav_count = Saving.query.update({Saving.household_id: household.id})
    print(f"💰 Ahorros asignados: {sav_count}")

    # ── 4. Commit everything ─────────────────────────────────────
    db.session.commit()
    print("\n✅ Migración completada con éxito!")
    print(f"   • Household: '{household.name}' (id={household.id})")
    print(f"   • Miembros: {len(users)}")
    print(f"   • Transacciones: {tx_count}")
    print(f"   • Categorías: {cat_count}")
    print(f"   • Presupuestos: {budget_count}")
    print(f"   • Cuentas de ahorro: {acc_count}")
    print(f"   • Ahorros: {sav_count}")
