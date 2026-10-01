"""
Importador de datos históricos desde el archivo ODS de CUENTAS CLARAS.
Fase 1: Importa datos de 2026 (control mensual + ahorros).
"""

import os
import sys
from datetime import date, datetime
from numbers import Number

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app import create_app, db
from app.models.category import Category
from app.models.saving import Saving, SavingAccount
from app.models.transaction import Transaction
from app.models.user import User

# Mapeo de nombres de categorías en el ODS a categorías en la DB
CATEGORY_MAP = {
    "sueldo t": "Sueldo Tamara",
    "sueldo i": "Sueldo Ivan",
    "hs extra t": "Hs Extra Tamara",
    "hs extra i": "Hs Extra Ivan",
    "alquiler": "Alquiler / Cuota Dpto",
    "cuota dpto": "Alquiler / Cuota Dpto",
    "tarjeta t": "Tarjeta Tamara",
    "tarj tam": "Tarjeta Tamara",
    "tarjeta i": "Tarjeta Ivan",
    "tarj ivan": "Tarjeta Ivan",
    "expensas": "Expensas",
    "metrogas": "Metrogas",
    "luz": "Luz",
    "agua": "Agua",
    "internet": "Internet",
    "seguro": "Seguros",
    "abl": "ABL",
    "comida": "Comida / Supermercado",
    "super": "Comida / Supermercado",
    "verdulería": "Verdulería",
    "verduleria": "Verdulería",
    "delivery": "Delivery / Salidas",
    "salidas": "Delivery / Salidas",
    "transporte": "Transporte",
    "uber": "Transporte",
    "farmacia": "Salud / Farmacia",
    "salud": "Salud / Farmacia",
    "ropa": "Indumentaria",
    "indumentaria": "Indumentaria",
    "mascota": "Mascotas",
    "regalo": "Regalos",
    "varios": "Varios",
}


def normalize(text: str) -> str:
    """Normalize text for comparison."""
    if not text:
        return ""
    return (
        text.lower()
        .strip()
        .replace("í", "i")
        .replace("é", "e")
        .replace("ó", "o")
        .replace("á", "a")
        .replace("ú", "u")
    )


def get_cell_value(cell) -> tuple:
    """Return (raw_value, type, string_value) from an ODS cell.
    - If value is a number (float/int): return it directly.
    - If value is a string: try to parse as amount.
    """
    val = cell.value
    if val is None:
        return None, "empty", ""

    if isinstance(val, Number) and not isinstance(val, bool):
        # Float or int — use directly
        return float(val), "number", str(val)

    s = str(val).strip()
    return s, "string", s


def parse_amount_string(text: str) -> float | None:
    """Parse a formatted ARS amount string like '$1.234,56' or 'AR$500,00' to float."""
    if not text:
        return None
    text = text.strip()
    # Remove currency symbols and spaces
    text = text.replace("AR$", "").replace("$", "").replace(" ", "")
    # Handle negative numbers in parentheses
    text = text.replace("(", "-").replace(")", "")
    if not text:
        return None
    # ARS format: 1.234,56 (dot = thousands, comma = decimal)
    # If there's a comma: remove all dots (thousand separators), then convert comma to dot
    if "," in text:
        text = text.replace(".", "")  # remove thousand separators
        text = text.replace(",", ".")  # convert decimal comma to dot
    elif "." in text:
        # No comma — dots are thousand separators (e.g. "1.500" = 1500)
        # But only if there's more than one dot, or the part after the dot is 3 digits
        parts = text.split(".")
        # If last part has 3 digits and there are multiple parts, it's thousand separators
        if len(parts) >= 2 and len(parts[-1]) == 3:
            text = text.replace(".", "")  # remove thousand separators
        # Otherwise the dot IS the decimal (e.g., US format "1.50")
        # Keep as-is
    try:
        return float(text)
    except ValueError, TypeError:
        return None


def extract_amount(cell_value, val_type: str, string_val: str) -> float | None:
    """Extract numeric amount from a cell, handling both number and string types."""
    if val_type == "number":
        return float(cell_value)
    return parse_amount_string(string_val)


def find_category(name: str, cat_type: str = None) -> Category:
    """Find a category by name matching."""
    normalized = normalize(name)
    mapped = CATEGORY_MAP.get(normalized)
    if mapped:
        cat = Category.query.filter_by(name=mapped).first()
        if cat:
            return cat

    # Try direct match
    cat = Category.query.filter(db.func.lower(Category.name) == normalized).first()
    if cat:
        return cat

    # Try partial match
    cats = Category.query.all()
    for c in cats:
        cn = normalize(c.name)
        if cn in normalized or normalized in cn:
            return c

    # Create new category on the fly
    cat = Category(
        name=name.strip().title(),
        type=cat_type or "variable_expense",
        icon="📦",
        sort_order=99,
    )
    db.session.add(cat)
    db.session.flush()
    print(f"  📦 Nueva categoría creada: {cat.name} ({cat.type})")
    return cat


def import_sheet(sheet_name: str, month: int, year: int, users: dict):
    """Import data from a monthly sheet."""
    import ezodf

    ods_path = os.path.join(
        os.path.dirname(__file__), "..", "..", "..", "CUENTAS CLARAS.ods"
    )
    if not os.path.exists(ods_path):
        print(f"❌ No se encuentra el archivo ODS en: {ods_path}")
        return

    doc = ezodf.opendoc(ods_path)
    sheet = None
    for s in doc.sheets:
        if s.name.strip().lower() == sheet_name.strip().lower():
            sheet = s
            break

    if sheet is None:
        print(f"❌ Hoja '{sheet_name}' no encontrada")
        return

    print(f"\n📄 Importando: {sheet_name} (mes {month}/{year})")

    section = None
    transactions_created = 0

    for row_idx in range(sheet.nrows()):
        # Read row as raw cell values (keep original types!)
        cells = [sheet[row_idx, col] for col in range(sheet.ncols())]
        values = []
        for c in cells:
            raw, vtype, sval = get_cell_value(c)
            values.append((raw, vtype, sval))

        # Detect section headers (use string values for detection)
        first_raw, first_type, first_str = values[0] if values else ("", "empty", "")
        first_norm = normalize(first_str)

        if "entradas" in first_norm or "ingresos" in first_norm:
            section = "income"
            continue
        elif "gastos fijos" in first_norm:
            section = "fixed_expense"
            continue
        elif "gastos extra" in first_norm or "gastos variables" in first_norm:
            section = "variable_expense"
            continue
        elif "total" in first_norm or "sobr" in first_norm or "ahorro" in first_norm:
            section = None
            continue

        if section is None:
            continue

        # Skip empty rows
        if not any(s for _, _, s in values if s):
            continue

        # Concept is the first column's string value
        concept = first_str
        if not concept or concept in ("📆", "CONCEPTOS", "CONCEPTO", ""):
            continue

        # Try to parse a date from any column
        row_date = None
        for col_idx in range(1, len(values)):
            _, _, sval = values[col_idx]
            if sval:
                for fmt in ["%d/%m/%Y", "%d/%m/%y", "%d/%m", "%Y-%m-%d", "%d-%m-%Y"]:
                    try:
                        parsed = datetime.strptime(sval, fmt)
                        if fmt == "%d/%m":
                            row_date = date(year, month, parsed.day)
                        else:
                            row_date = date(parsed.year, parsed.month, parsed.day)
                        break
                    except ValueError:
                        continue
                if row_date:
                    break

        if row_date is None:
            row_date = date(year, month, 15)

        # Find the first amount in the row (skip concept column)
        amount = None
        for col_idx in range(1, min(5, len(values))):  # Check first few data columns
            raw, vtype, sval = values[col_idx]
            parsed = extract_amount(raw, vtype, sval)
            if parsed is not None and parsed != 0:
                amount = parsed
                break

        if amount is None or amount == 0:
            continue

        # Determine user based on concept
        cn = normalize(concept)
        user = None
        # T = Tamara, I = Ivan
        if "tamara" in cn:
            user = users.get("tamara")
        elif "ivan" in cn:
            user = users.get("ivan")
        elif cn.endswith(" t") or cn == "t":
            user = users.get("tamara")
        elif cn.endswith(" i") or cn == "i":
            user = users.get("ivan")
        elif "t " in cn or cn == "t":
            user = users.get("tamara")
        elif "i " in cn or cn == "i":
            user = users.get("ivan")
        elif cn == "sueldot":
            user = users.get("tamara")
        elif cn == "sueldoi":
            user = users.get("ivan")

        if user is None:
            # Check the original ODS concept for T/I suffix
            for word in concept.lower().split():
                word = word.strip()
                if word in ("t", "t."):
                    user = users.get("tamara")
                    break
                elif word in ("i", "i."):
                    user = users.get("ivan")
                    break

        if user is None:
            # Default: shared fixed expenses go to Ivan
            user = users.get("ivan")

        category = find_category(concept, section)
        ttype = "income" if section == "income" else "expense"
        is_fixed = section == "fixed_expense"

        tx = Transaction(
            user_id=user.id,
            category_id=category.id,
            date=row_date,
            description=f"{concept}".strip(),
            amount=abs(amount),
            type=ttype,
            is_fixed=is_fixed,
        )
        db.session.add(tx)
        transactions_created += 1

    db.session.commit()
    print(f"   ✅ {transactions_created} transacciones importadas")


def import_savings():
    """Import savings data from AHORROS_Telmo and AHORROS_26 sheets."""
    import ezodf

    ods_path = os.path.join(
        os.path.dirname(__file__), "..", "..", "..", "CUENTAS CLARAS.ods"
    )
    if not os.path.exists(ods_path):
        print(f"❌ No se encuentra AHORROS ODS en: {ods_path}")
        return

    doc = ezodf.opendoc(ods_path)

    for s in doc.sheets:
        name = s.name.strip()

        # --- AHORROS_Telmo: crypto holdings ---
        if name == "AHORROS_Telmo":
            print("\n📄 Importando: AHORROS_Telmo")
            in_holdings = False
            for row_idx in range(s.nrows()):
                cells = [s[row_idx, col] for col in range(s.ncols())]
                vals = []
                for c in cells:
                    raw, vtype, sval = get_cell_value(c)
                    vals.append((raw, vtype, sval))

                if not any(v[2] for v in vals):
                    continue

                first_norm = normalize(vals[0][2]) if vals else ""

                if "btc" in first_norm and "pepe" in first_norm:
                    in_holdings = True
                    continue

                if in_holdings and len(vals) >= 3:
                    token = vals[0][2]
                    qty = extract_amount(vals[1][0], vals[1][1], vals[1][2])
                    ars = extract_amount(vals[2][0], vals[2][1], vals[2][2])

                    if token and qty is not None:
                        account = SavingAccount.query.filter(
                            db.func.lower(SavingAccount.name) == normalize(token)
                        ).first()
                        if not account:
                            account = SavingAccount(
                                name=token.upper(),
                                currency=token.upper() if len(token) <= 5 else "ARS",
                            )
                            db.session.add(account)
                            db.session.flush()

                        saving = Saving(
                            account_id=account.id,
                            month=6,
                            year=2026,
                            balance=qty,
                            balance_ars=ars,
                        )
                        db.session.add(saving)
                        print(f"   💰 {token}: {qty} (ARS {ars})")

            db.session.commit()
            print("   ✅ Ahorros Telmo importados")

        # --- AHORROS_26: savings accounts ---
        elif name == "AHORROS_26":
            print("\n📄 Importando: AHORROS_26")
            for row_idx in range(s.nrows()):
                cells = [s[row_idx, col] for col in range(s.ncols())]
                vals = []
                for c in cells:
                    raw, vtype, sval = get_cell_value(c)
                    vals.append((raw, vtype, sval))

                if not any(v[2] for v in vals):
                    continue

                account_name = vals[0][2] if vals else ""
                if not account_name:
                    continue

                for col_idx in range(1, min(7, len(vals))):
                    raw, vtype, sval = vals[col_idx]
                    amount = extract_amount(raw, vtype, sval)
                    if amount is not None and amount > 0:
                        account = SavingAccount.query.filter(
                            db.func.lower(SavingAccount.name) == normalize(account_name)
                        ).first()
                        if not account:
                            account = SavingAccount(
                                name=account_name,
                                currency="ARS",
                                description="Desde AHORROS_26",
                            )
                            db.session.add(account)
                            db.session.flush()

                        saving = Saving(
                            account_id=account.id,
                            month=col_idx,
                            year=2026,
                            balance=amount,
                            balance_ars=amount,
                        )
                        db.session.add(saving)
                        print(
                            f"   💰 {account_name} (mes {col_idx}/2026): ARS {amount}"
                        )

            db.session.commit()
            print("   ✅ AHORROS_26 importados")


if __name__ == "__main__":
    app = create_app()

    with app.app_context():
        ivan = User.query.filter_by(short_name="I").first()
        tamara = User.query.filter_by(short_name="T").first()
        if not ivan or not tamara:
            print("❌ Ejecutá primero: python scripts/seed.py")
            sys.exit(1)

        users = {"ivan": ivan, "tamara": tamara}
        print(
            f"👤 Usuarios: {ivan.name} ({ivan.short_name}) y {tamara.name} ({tamara.short_name})"
        )

        months_2026 = [
            ("ene26", 1, 2026),
            ("feb26", 2, 2026),
            ("mar26", 3, 2026),
            ("abr26", 4, 2026),
            ("may26", 5, 2026),
            ("jun26", 6, 2026),
        ]

        print("\n" + "=" * 60)
        print("🔄 IMPORTANDO CONTROL MENSUAL 2026")
        print("=" * 60)

        for sheet_name, month, year in months_2026:
            import_sheet(sheet_name, month, year, users)

        print("\n" + "=" * 60)
        print("🔄 IMPORTANDO AHORROS")
        print("=" * 60)
        import_savings()

        total = Transaction.query.count()
        savings_count = Saving.query.count()
        print(f"\n{'=' * 60}")
        print("📊 RESUMEN FINAL:")
        print(f"   Transacciones: {total}")
        print(f"   Registros de ahorro: {savings_count}")
        print(f"{'=' * 60}")
