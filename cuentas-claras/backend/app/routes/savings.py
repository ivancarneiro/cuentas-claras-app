import logging

from flask import Blueprint, jsonify, request

from app import db
from app.auth.permissions import get_user_households
from app.models.saving import MonthlySavingAdjustment, Saving, SavingAccount
from app.routes.auth import login_required

savings_bp = Blueprint("savings", __name__)
logger = logging.getLogger("cuentasclaras.savings")


# --- Saving Accounts ---


@savings_bp.route("/accounts", methods=["GET"])
@login_required
def get_accounts():
    user = request.current_user
    households = get_user_households(user.id)
    household_id = request.args.get("household_id")
    if household_id:
        try:
            h_id = int(household_id)
            if h_id not in households:
                return jsonify({"error": "No tenés acceso a este grupo"}), 403
            target_households = [h_id]
        except (ValueError, TypeError):
            return jsonify({"error": "household_id inválido"}), 400
    else:
        target_households = households

    accounts = (
        SavingAccount.query.filter(SavingAccount.household_id.in_(target_households))
        .order_by(SavingAccount.name)
        .all()
    )
    return jsonify([a.to_dict() for a in accounts])


@savings_bp.route("/accounts", methods=["POST"])
@login_required
def create_account():
    data = request.get_json()
    if not data or not data.get("name"):
        return jsonify({"error": "Nombre requerido"}), 400

    # Auto-assign household
    household_id = data.get("household_id")
    if not household_id:
        households = get_user_households(request.current_user.id)
        household_id = households[0] if households else None

    account = SavingAccount(
        name=data["name"],
        currency=data.get("currency", "ARS"),
        description=data.get("description"),
        owner_id=data.get("owner_id") or request.current_user.id,
        household_id=household_id,
    )
    db.session.add(account)
    db.session.commit()

    # Si viene saldo inicial, guardarlo en la tabla Saving
    balance = data.get("balance") or data.get("initial_balance")
    balance_ars = data.get("balance_ars") or data.get("initial_balance_ars")
    if balance is not None or balance_ars is not None:
        try:
            b_val = float(balance) if balance is not None else 0.0
            if balance_ars is None and account.currency == "ARS":
                b_ars = b_val
            else:
                b_ars = float(balance_ars) if balance_ars is not None else b_val
            from datetime import date
            today = date.today()
            saving = Saving(
                account_id=account.id,
                household_id=household_id,
                month=today.month,
                year=today.year,
                balance=b_val,
                currency=account.currency,
                balance_ars=b_ars,
                note="Saldo inicial",
            )
            db.session.add(saving)
            db.session.commit()
        except (ValueError, TypeError):
            pass

    logger.info(
        "SavingAccount created — id=%d name=%s currency=%s household_id=%s",
        account.id,
        account.name,
        account.currency,
        account.household_id,
    )
    return jsonify(account.to_dict()), 201


@savings_bp.route("/accounts/<int:account_id>", methods=["PUT"])
@login_required
def update_account(account_id):
    account = db.session.get(SavingAccount, account_id)
    if not account:
        return jsonify({"error": "Cuenta de ahorro no encontrada"}), 404
    data = request.get_json()
    if data.get("name"):
        account.name = data["name"]
    if data.get("currency"):
        account.currency = data["currency"]
    if data.get("description") is not None:
        account.description = data["description"]

    # Si se envían saldos al editar la cuenta, actualizar o crear el último registro
    balance = data.get("balance")
    balance_ars = data.get("balance_ars")
    if balance is not None or balance_ars is not None:
        try:
            b_val = float(balance) if balance is not None else 0.0
            if balance_ars is None and account.currency == "ARS":
                b_ars = b_val
            else:
                b_ars = float(balance_ars) if balance_ars is not None else b_val
            from datetime import date
            today = date.today()
            # Buscar último saving de esta cuenta
            last_saving = (
                Saving.query.filter_by(account_id=account.id)
                .order_by(Saving.year.desc(), Saving.month.desc())
                .first()
            )
            if last_saving and last_saving.month == today.month and last_saving.year == today.year:
                last_saving.balance = b_val
                last_saving.balance_ars = b_ars
                last_saving.currency = account.currency
            else:
                new_saving = Saving(
                    account_id=account.id,
                    household_id=account.household_id,
                    month=today.month,
                    year=today.year,
                    balance=b_val,
                    currency=account.currency,
                    balance_ars=b_ars,
                    note="Actualización de saldo",
                )
                db.session.add(new_saving)
        except (ValueError, TypeError):
            pass

    db.session.commit()
    logger.info(
        "SavingAccount updated — id=%d name=%s currency=%s household_id=%s",
        account.id,
        account.name,
        account.currency,
        account.household_id,
    )
    return jsonify(account.to_dict())
    logger.info(
        "SavingAccount updated — id=%d name=%s currency=%s household_id=%s",
        account.id,
        account.name,
        account.currency,
        account.household_id,
    )
    return jsonify(account.to_dict())


@savings_bp.route("/accounts/<int:account_id>", methods=["DELETE"])
@login_required
def delete_account(account_id):
    account = db.session.get(SavingAccount, account_id)
    if not account:
        return jsonify({"error": "Cuenta de ahorro no encontrada"}), 404
    acc_name = account.name
    acc_h_id = account.household_id

    # Comprobar si tiene registros de ahorro asociados
    savings_count = Saving.query.filter_by(account_id=account_id).count()
    if savings_count > 0:
        return (
            jsonify(
                {
                    "error": (
                        f"No se puede eliminar la cuenta '{acc_name}' porque tiene "
                        f"{savings_count} registro(s) de ahorro asociado(s). "
                        "Elimine o reasigne los registros de ahorro primero."
                    )
                }
            ),
            400,
        )

    db.session.delete(account)
    db.session.commit()
    logger.info(
        "SavingAccount deleted — id=%d name=%s household_id=%s",
        account_id,
        acc_name,
        acc_h_id,
    )
    return jsonify(
        {"message": f"Cuenta de ahorro '{acc_name}' eliminada correctamente"}
    )




# --- Saving Balances ---


@savings_bp.route("", methods=["GET"])
@login_required
def get_savings():
    user = request.current_user
    households = get_user_households(user.id)
    query = Saving.query.filter(Saving.household_id.in_(households))

    account_id = request.args.get("account_id")
    if account_id:
        query = query.filter_by(account_id=int(account_id))

    month = request.args.get("month")
    year = request.args.get("year")
    if month and year:
        query = query.filter_by(month=int(month), year=int(year))

    savings = query.order_by(Saving.year.desc(), Saving.month.desc()).all()
    return jsonify([s.to_dict() for s in savings])


@savings_bp.route("", methods=["POST"])
@login_required
def create_saving():
    data = request.get_json()
    required = ["account_id", "month", "year", "balance"]
    for field in required:
        if field not in data:
            return jsonify({"error": f"Campo requerido: {field}"}), 400

    try:
        balance = float(data["balance"])
        if balance < 0:
            return jsonify({"error": "El balance no puede ser negativo"}), 400
    except (ValueError, TypeError):
        return jsonify({"error": "Balance inválido"}), 400

    if data.get("balance_ars") is not None:
        try:
            balance_ars = float(data["balance_ars"])
            if balance_ars < 0:
                return jsonify({"error": "El balance en ARS no puede ser negativo"}), 400
        except (ValueError, TypeError):
            return jsonify({"error": "Balance en ARS inválido"}), 400

    # Auto-assign household from account's household
    account = db.session.get(SavingAccount, data["account_id"])
    household_id = account.household_id if account else None
    if not household_id:
        households = get_user_households(request.current_user.id)
        household_id = households[0] if households else None

    saving = Saving(
        account_id=data["account_id"],
        household_id=household_id,
        month=data["month"],
        year=data["year"],
        balance=float(data["balance"]),
        currency=data.get("currency"),
        balance_ars=float(data["balance_ars"]) if data.get("balance_ars") else None,
        note=data.get("note"),
    )
    db.session.add(saving)
    db.session.commit()
    logger.info(
        "Saving created — id=%d account_id=%d period=%02d/%d balance=%.2f household_id=%s",
        saving.id,
        saving.account_id,
        saving.month,
        saving.year,
        saving.balance,
        saving.household_id,
    )
    return jsonify(saving.to_dict()), 201


@savings_bp.route("/<int:saving_id>", methods=["PUT"])
@login_required
def update_saving(saving_id):
    saving = db.session.get(Saving, saving_id)
    if not saving:
        return jsonify({"error": "Balance de ahorro no encontrado"}), 404
    data = request.get_json()
    if data.get("balance") is not None:
        try:
            balance = float(data["balance"])
            if balance < 0:
                return jsonify({"error": "El balance no puede ser negativo"}), 400
            saving.balance = balance
        except (ValueError, TypeError):
            return jsonify({"error": "Balance inválido"}), 400
    if data.get("currency") is not None:
        saving.currency = data["currency"]
    if data.get("balance_ars") is not None:
        try:
            balance_ars = float(data["balance_ars"])
            if balance_ars < 0:
                return jsonify({"error": "El balance en ARS no puede ser negativo"}), 400
            saving.balance_ars = balance_ars
        except (ValueError, TypeError):
            return jsonify({"error": "Balance en ARS inválido"}), 400
    if data.get("note") is not None:
        saving.note = data["note"]
    db.session.commit()
    logger.info(
        "Saving updated — id=%d account_id=%d period=%02d/%d balance=%.2f household_id=%s",
        saving.id,
        saving.account_id,
        saving.month,
        saving.year,
        saving.balance,
        saving.household_id,
    )
    return jsonify(saving.to_dict())


@savings_bp.route("/<int:saving_id>", methods=["DELETE"])
@login_required
def delete_saving(saving_id):
    saving = db.session.get(Saving, saving_id)
    if not saving:
        return jsonify({"error": "Balance de ahorro no encontrado"}), 404
    s_id = saving.id
    s_acc = saving.account_id
    s_m = saving.month
    s_y = saving.year
    s_b = saving.balance
    s_h = saving.household_id

    db.session.delete(saving)
    db.session.commit()
    logger.info(
        "Saving deleted — id=%d account_id=%d period=%02d/%d balance=%.2f household_id=%s",
        s_id,
        s_acc,
        s_m,
        s_y,
        s_b,
        s_h,
    )
    return jsonify({"message": "Registro de ahorro eliminado"})


@savings_bp.route("/summary", methods=["GET"])
@login_required
def savings_summary():
    """Get accounts summary with percentages and monthly flow for the year"""
    from datetime import date
    from sqlalchemy import func
    from app.models.transaction import Transaction

    user = request.current_user
    households = get_user_households(user.id)
    year = request.args.get("year", date.today().year, type=int)

    household_id = request.args.get("household_id")
    if household_id:
        try:
            h_id = int(household_id)
            if h_id not in households:
                return jsonify({"error": "No tenés acceso a este grupo"}), 403
            target_households = [h_id]
        except (ValueError, TypeError):
            return jsonify({"error": "household_id inválido"}), 400
    else:
        target_households = households

    # 1. Obtener todas las cuentas del target_households
    all_accounts = (
        SavingAccount.query.filter(SavingAccount.household_id.in_(target_households))
        .order_by(SavingAccount.name)
        .all()
    )

    # 2. Obtener el último Saving por cuenta
    subquery = (
        db.session.query(
            Saving.account_id,
            func.max(Saving.year * 100 + Saving.month).label("max_period"),
        )
        .filter(Saving.household_id.in_(target_households))
        .group_by(Saving.account_id)
        .subquery()
    )

    latest_savings = (
        db.session.query(Saving)
        .join(
            subquery,
            db.and_(
                Saving.account_id == subquery.c.account_id,
                (Saving.year * 100 + Saving.month) == subquery.c.max_period,
            ),
        )
        .filter(Saving.household_id.in_(target_households))
        .all()
    )
    latest_by_account = {s.account_id: s for s in latest_savings}

    # 3. Flujo mensual del año (ENE a DIC): cálculos automáticos + ajustes manuales
    adjustments = (
        MonthlySavingAdjustment.query.filter(
            MonthlySavingAdjustment.household_id.in_(target_households),
            MonthlySavingAdjustment.year == year,
        ).all()
    )
    adj_by_month = {a.month: a for a in adjustments}

    month_names = ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]
    monthly_flow = []
    months_total_ars = 0.0

    for m in range(1, 13):
        # Ingresos del mes
        inc = (
            db.session.query(func.coalesce(func.sum(Transaction.amount), 0))
            .filter(
                Transaction.household_id.in_(target_households),
                db.extract("year", Transaction.date) == year,
                db.extract("month", Transaction.date) == m,
                Transaction.type == "income",
            )
            .scalar()
        )
        # Gastos del mes
        exp = (
            db.session.query(func.coalesce(func.sum(Transaction.amount), 0))
            .filter(
                Transaction.household_id.in_(target_households),
                db.extract("year", Transaction.date) == year,
                db.extract("month", Transaction.date) == m,
                Transaction.type == "expense",
            )
            .scalar()
        )
        auto_saving = float(inc) - float(exp)
        adj = adj_by_month.get(m)
        if adj:
            amount_ars = float(adj.amount_ars)
            is_manual = True
            note = adj.note
        else:
            amount_ars = auto_saving
            is_manual = False
            note = None

        months_total_ars += amount_ars
        monthly_flow.append({
            "month": m,
            "name": month_names[m - 1],
            "income": float(inc),
            "expenses": float(exp),
            "auto_amount_ars": round(auto_saving, 2),
            "amount_ars": round(amount_ars, 2),
            "is_manual": is_manual,
            "note": note,
            "percentage": 0.0,
        })

    # 4. Procesar cuentas con sus saldos
    accounts_data = []
    accounts_total_ars = 0.0

    for acc in all_accounts:
        saving = latest_by_account.get(acc.id)
        if saving:
            bal = float(saving.balance)
            bal_ars = float(saving.balance_ars if saving.balance_ars is not None else saving.balance)
        else:
            bal = 0.0
            bal_ars = 0.0

        accounts_total_ars += bal_ars
        accounts_data.append({
            "id": acc.id,
            "account_id": acc.id,
            "account_name": acc.name,
            "currency": acc.currency,
            "description": acc.description,
            "balance": round(bal, 2),
            "balance_ars": round(bal_ars, 2),
            "month": saving.month if saving else None,
            "year": saving.year if saving else None,
            "saving_id": saving.id if saving else None,
            "percentage": 0.0,
        })

    # 5. Total Ahorros Consolidado (Activos en ARS + suma del flujo mensual del año)
    total_ars = accounts_total_ars + months_total_ars

    # 6. Calcular porcentajes sobre el total
    if total_ars > 0:
        for a in accounts_data:
            a["percentage"] = round((a["balance_ars"] / total_ars) * 100, 2)
        for mf in monthly_flow:
            mf["percentage"] = round((mf["amount_ars"] / total_ars) * 100, 2)

    # 7. Tipo de cambio de referencia para USD
    usd_rate = 1400.0
    for a in accounts_data:
        if a["currency"] == "USD" and a["balance"] > 0 and a["balance_ars"] > 0:
            usd_rate = a["balance_ars"] / a["balance"]
            break

    total_usd = round(total_ars / usd_rate, 2) if usd_rate > 0 else 0.0

    return jsonify({
        "accounts": accounts_data,
        "monthly_flow": monthly_flow,
        "total_ars": round(total_ars, 2),
        "accounts_total_ars": round(accounts_total_ars, 2),
        "months_total_ars": round(months_total_ars, 2),
        "usd_rate": round(usd_rate, 2),
        "total_usd": total_usd,
        "year": year,
    })


@savings_bp.route("/monthly-flow", methods=["POST", "PUT"])
@login_required
def set_monthly_flow():
    """Create or update manual monthly savings adjustment"""
    data = request.get_json()
    if not data or "month" not in data or "year" not in data or "amount_ars" not in data:
        return jsonify({"error": "Parámetros 'month', 'year' y 'amount_ars' requeridos"}), 400

    try:
        month = int(data["month"])
        year = int(data["year"])
        amount_ars = float(data["amount_ars"])
    except (ValueError, TypeError):
        return jsonify({"error": "Valores numéricos inválidos"}), 400

    note = data.get("note")
    user = request.current_user
    households = get_user_households(user.id)
    household_id = data.get("household_id")
    if not household_id:
        household_id = households[0] if households else None

    if not household_id or household_id not in households:
        return jsonify({"error": "No pertenecés a este grupo familiar"}), 403

    adj = MonthlySavingAdjustment.query.filter_by(
        household_id=household_id, year=year, month=month
    ).first()

    if not adj:
        adj = MonthlySavingAdjustment(
            household_id=household_id,
            year=year,
            month=month,
            amount_ars=amount_ars,
            note=note,
        )
        db.session.add(adj)
    else:
        adj.amount_ars = amount_ars
        adj.note = note

    db.session.commit()
    logger.info("Monthly saving adjustment set — household=%d period=%02d/%d amount_ars=%.2f", household_id, month, year, amount_ars)
    return jsonify(adj.to_dict()), 200


@savings_bp.route("/monthly-flow", methods=["DELETE"])
@login_required
def delete_monthly_flow():
    """Remove manual monthly savings adjustment (resets to automatic calculation)"""
    month = request.args.get("month", type=int)
    year = request.args.get("year", type=int)
    if not month or not year:
        return jsonify({"error": "Parámetros 'month' y 'year' requeridos"}), 400

    user = request.current_user
    households = get_user_households(user.id)
    adj = MonthlySavingAdjustment.query.filter(
        MonthlySavingAdjustment.household_id.in_(households),
        MonthlySavingAdjustment.year == year,
        MonthlySavingAdjustment.month == month,
    ).first()

    if adj:
        db.session.delete(adj)
        db.session.commit()
        logger.info("Monthly saving adjustment removed — period=%02d/%d", month, year)

    return jsonify({"message": "Ajuste manual eliminado, cálculo automático restablecido"})

