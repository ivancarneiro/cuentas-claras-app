import logging
from datetime import datetime

from flask import Blueprint, jsonify, request

from app import db
from app.auth.permissions import (
    get_user_households,
)
from app.models.category import Category
from app.models.transaction import Transaction
from app.routes.auth import login_required
from app.services.notification_service import notify_household_members

transactions_bp = Blueprint("transactions", __name__)
logger = logging.getLogger("cuentasclaras.transactions")


@transactions_bp.route("", methods=["GET"])
@login_required
def get_transactions():
    user = request.current_user
    households = get_user_households(user.id)

    household_id = request.args.get("household_id")
    if household_id:
        try:
            h_id = int(household_id)
            if h_id not in households:
                return jsonify({"error": "No tenés acceso a este grupo"}), 403
            query = Transaction.query.filter(Transaction.household_id == h_id)
        except (ValueError, TypeError):
            return jsonify({"error": "household_id inválido"}), 400
    else:
        query = Transaction.query.filter(Transaction.household_id.in_(households))

    # Filter by user
    user_id = request.args.get("user_id")
    if user_id:
        query = query.filter_by(user_id=int(user_id))

    # Filter by month/year
    month = request.args.get("month")
    year = request.args.get("year")
    if month and year:
        query = query.filter(
            db.extract("month", Transaction.date) == int(month),
            db.extract("year", Transaction.date) == int(year),
        )

    # Filter by type (income/expense)
    ttype = request.args.get("type")
    if ttype:
        query = query.filter_by(type=ttype)

    # Filter by category
    category_id = request.args.get("category_id")
    if category_id:
        query = query.filter_by(category_id=int(category_id))

    # Filter by fixed
    is_fixed = request.args.get("is_fixed")
    if is_fixed is not None:
        query = query.filter_by(is_fixed=is_fixed.lower() == "true")

    query = query.order_by(Transaction.date.desc(), Transaction.id.desc())
    transactions = query.all()
    return jsonify([t.to_dict() for t in transactions])


@transactions_bp.route("/<int:transaction_id>", methods=["GET"])
@login_required
def get_transaction(transaction_id):
    transaction = db.session.get(Transaction, transaction_id)
    if not transaction:
        return jsonify({"error": "Transacción no encontrada"}), 404
    return jsonify(transaction.to_dict())


@transactions_bp.route("", methods=["POST"])
@login_required
def create_transaction():
    data = request.get_json()
    required = ["category_id", "date", "amount", "type"]
    for field in required:
        if field not in data:
            return jsonify({"error": f"Campo requerido: {field}"}), 400

    if data["type"] not in ("income", "expense"):
        return jsonify({"error": "Tipo debe ser 'income' o 'expense'"}), 400

    try:
        amount = float(data["amount"])
        if amount <= 0:
            return jsonify({"error": "El monto debe ser mayor a 0"}), 400
    except (ValueError, TypeError):
        return jsonify({"error": "Monto inválido"}), 400

    # Validate category exists
    cat = db.session.get(Category, data["category_id"])
    if not cat:
        return jsonify({"error": "Categoría no encontrada"}), 404

    try:
        date = datetime.strptime(data["date"], "%Y-%m-%d").date()
    except (ValueError, TypeError):
        return jsonify({"error": "Formato de fecha inválido. Use YYYY-MM-DD"}), 400

    # Auto-assign household from the user's context
    user = request.current_user
    households = get_user_households(user.id)
    household_id = data.get("household_id") or getattr(
        request, "current_household_id", None
    )
    if household_id:
        if household_id not in households:
            return (
                jsonify({"error": "No pertenecés al grupo familiar especificado"}),
                403,
            )
    else:
        household_id = households[0] if households else None

    transaction = Transaction(
        user_id=data.get("user_id") or user.id,
        household_id=household_id,

        category_id=data["category_id"],
        date=date,
        description=data.get("description"),
        amount=float(data["amount"]),
        currency=data.get("currency", "ARS"),
        type=data["type"],
        is_fixed=data.get("is_fixed", False),
    )
    db.session.add(transaction)
    db.session.commit()
    logger.info(
        "Transaction created — id=%d user_id=%d amount=%.2f type=%s household_id=%s",
        transaction.id,
        transaction.user_id,
        transaction.amount,
        transaction.type,
        transaction.household_id,
    )

    if transaction.household_id:
        actor_name = user.name or "Un integrante"
        tipo_str = "un gasto" if transaction.type == "expense" else "un ingreso"
        cat_name = cat.name if cat else "General"
        curr = transaction.currency or "ARS"
        title = f"Nuevo movimiento en {transaction.household.name if transaction.household else 'el grupo'}"
        message = f"{actor_name} cargó {tipo_str} de {curr} {transaction.amount:,.2f} en {cat_name}"
        notify_household_members(
            household_id=transaction.household_id,
            actor_id=user.id,
            title=title,
            message=message,
            notification_type="transaction_created",
            reference_id=transaction.id,
        )

    return jsonify(transaction.to_dict()), 201


@transactions_bp.route("/<int:transaction_id>", methods=["PUT"])
@login_required
def update_transaction(transaction_id):
    transaction = db.session.get(Transaction, transaction_id)
    if not transaction:
        return jsonify({"error": "Transacción no encontrada"}), 404
    # Check access to the resource's household
    user = request.current_user
    households = get_user_households(user.id)
    if transaction.household_id not in households:
        return jsonify({"error": "No tenés acceso a esta transacción"}), 403
    data = request.get_json()

    if data.get("household_id"):
        if data["household_id"] not in households:
            return jsonify({"error": "No pertenecés al grupo especificado"}), 403
        transaction.household_id = data["household_id"]
    if data.get("user_id"):
        transaction.user_id = data["user_id"]
    if data.get("category_id"):
        cat = db.session.get(Category, data["category_id"])
        if not cat:
            return jsonify({"error": "Categoría no encontrada"}), 404
        transaction.category_id = data["category_id"]
    if data.get("date"):
        try:
            transaction.date = datetime.strptime(data["date"], "%Y-%m-%d").date()
        except (ValueError, TypeError):
            return jsonify({"error": "Formato de fecha inválido. Use YYYY-MM-DD"}), 400
    if data.get("description") is not None:
        transaction.description = data["description"]
    if data.get("amount") is not None:
        try:
            amount = float(data["amount"])
            if amount <= 0:
                return jsonify({"error": "El monto debe ser mayor a 0"}), 400
            transaction.amount = amount
        except (ValueError, TypeError):
            return jsonify({"error": "Monto inválido"}), 400
    if data.get("currency"):
        transaction.currency = data["currency"]
    if data.get("type"):
        if data["type"] not in ("income", "expense"):
            return jsonify({"error": "Tipo debe ser 'income' o 'expense'"}), 400
        transaction.type = data["type"]
    if data.get("is_fixed") is not None:
        transaction.is_fixed = bool(data["is_fixed"])

    db.session.commit()
    logger.info(
        "Transaction updated — id=%d user_id=%d amount=%.2f type=%s household_id=%s",
        transaction.id,
        transaction.user_id,
        transaction.amount,
        transaction.type,
        transaction.household_id,
    )

    if transaction.household_id:
        actor_name = user.name or "Un integrante"
        tipo_str = "el gasto" if transaction.type == "expense" else "el ingreso"
        title = f"Movimiento modificado en {transaction.household.name if transaction.household else 'el grupo'}"
        message = f"{actor_name} actualizó {tipo_str} ({transaction.currency} {transaction.amount:,.2f})"
        notify_household_members(
            household_id=transaction.household_id,
            actor_id=user.id,
            title=title,
            message=message,
            notification_type="transaction_updated",
            reference_id=transaction.id,
        )

    return jsonify(transaction.to_dict())


@transactions_bp.route("/<int:transaction_id>", methods=["DELETE"])
@login_required
def delete_transaction(transaction_id):
    transaction = db.session.get(Transaction, transaction_id)
    if not transaction:
        return jsonify({"error": "Transacción no encontrada"}), 404
    user = request.current_user
    households = get_user_households(user.id)
    if transaction.household_id not in households:
        return jsonify({"error": "No tenés acceso a esta transacción"}), 403
    # Guardar datos para el log y la notificación antes de borrar
    t_id = transaction.id
    t_amount = transaction.amount
    t_user_id = transaction.user_id
    t_type = transaction.type
    t_household_id = transaction.household_id
    t_household_name = transaction.household.name if transaction.household else "el grupo"
    t_currency = transaction.currency or "ARS"
    t_desc = transaction.description or (transaction.category.name if transaction.category else "Movimiento")

    db.session.delete(transaction)
    db.session.commit()
    logger.info(
        "Transaction deleted — id=%d user_id=%d amount=%.2f type=%s",
        t_id,
        t_user_id,
        t_amount,
        t_type,
    )

    if t_household_id:
        actor_name = user.name or "Un integrante"
        tipo_str = "un gasto" if t_type == "expense" else "un ingreso"
        title = f"Movimiento eliminado en {t_household_name}"
        message = f"{actor_name} eliminó {tipo_str} de {t_currency} {t_amount:,.2f} ({t_desc})"
        notify_household_members(
            household_id=t_household_id,
            actor_id=user.id,
            title=title,
            message=message,
            notification_type="transaction_deleted",
            reference_id=t_id,
        )

    return jsonify({"message": "Transacción eliminada"})
