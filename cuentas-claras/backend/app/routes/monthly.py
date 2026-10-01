from flask import Blueprint, jsonify, request
from sqlalchemy import func

from app import db
from app.auth.permissions import get_user_households
from app.models.category import Category
from app.models.transaction import Transaction
from app.models.user import User
from app.routes.auth import login_required

monthly_bp = Blueprint("monthly", __name__)


@monthly_bp.route("/summary", methods=["GET"])
@login_required
def monthly_summary():
    month = request.args.get("month")
    year = request.args.get("year")

    if not month or not year:
        return jsonify({"error": "Parámetros 'month' y 'year' requeridos"}), 400

    month, year = int(month), int(year)
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

    # ── Helper: base filter for target households ──
    def _base_filter():
        return [
            db.extract("month", Transaction.date) == month,
            db.extract("year", Transaction.date) == year,
            Transaction.household_id.in_(target_households),
        ]

    # Total income
    total_income = (
        db.session.query(func.coalesce(func.sum(Transaction.amount), 0))
        .filter(
            *_base_filter(),
            Transaction.type == "income",
        )
        .scalar()
    )

    # Total expenses
    total_expenses = (
        db.session.query(func.coalesce(func.sum(Transaction.amount), 0))
        .filter(
            *_base_filter(),
            Transaction.type == "expense",
        )
        .scalar()
    )

    # Fixed expenses total
    fixed_expenses = (
        db.session.query(func.coalesce(func.sum(Transaction.amount), 0))
        .filter(
            *_base_filter(),
            Transaction.type == "expense",
            Transaction.is_fixed.is_(True),
        )
        .scalar()
    )

    # Variable expenses total
    variable_expenses = (
        db.session.query(func.coalesce(func.sum(Transaction.amount), 0))
        .filter(
            *_base_filter(),
            Transaction.type == "expense",
            Transaction.is_fixed.is_(False),
        )
        .scalar()
    )

    # Savings (income - expenses)
    savings = total_income - total_expenses

    # Per category breakdown for expenses
    expenses_by_category = (
        db.session.query(
            Category.id,
            Category.name,
            Category.icon,
            func.coalesce(func.sum(Transaction.amount), 0).label("total"),
            func.count(Transaction.id).label("count"),
        )
        .join(Transaction, Transaction.category_id == Category.id)
        .filter(
            *_base_filter(),
            Transaction.type == "expense",
        )
        .group_by(Category.id, Category.name, Category.icon)
        .all()
    )

    # Per category breakdown for income
    income_by_category = (
        db.session.query(
            Category.id,
            Category.name,
            Category.icon,
            func.coalesce(func.sum(Transaction.amount), 0).label("total"),
            func.count(Transaction.id).label("count"),
        )
        .join(Transaction, Transaction.category_id == Category.id)
        .filter(
            *_base_filter(),
            Transaction.type == "income",
        )
        .group_by(Category.id, Category.name, Category.icon)
        .all()
    )

    # Per user breakdown
    expenses_by_user = (
        db.session.query(
            User.id,
            User.name,
            func.coalesce(func.sum(Transaction.amount), 0).label("total"),
        )
        .join(Transaction, Transaction.user_id == User.id)
        .filter(
            *_base_filter(),
            Transaction.type == "expense",
        )
        .group_by(User.id, User.name)
        .all()
    )

    income_by_user = (
        db.session.query(
            User.id,
            User.name,
            func.coalesce(func.sum(Transaction.amount), 0).label("total"),
        )
        .join(Transaction, Transaction.user_id == User.id)
        .filter(
            *_base_filter(),
            Transaction.type == "income",
        )
        .group_by(User.id, User.name)
        .all()
    )

    return jsonify(
        {
            "month": month,
            "year": year,
            "total_income": float(total_income),
            "total_expenses": float(total_expenses),
            "fixed_expenses": float(fixed_expenses),
            "variable_expenses": float(variable_expenses),
            "savings": float(savings),
            "expenses_by_category": [
                {
                    "id": c.id,
                    "name": c.name,
                    "icon": c.icon,
                    "total": float(c.total),
                    "count": c.count,
                }
                for c in expenses_by_category
            ],
            "income_by_category": [
                {
                    "id": c.id,
                    "name": c.name,
                    "icon": c.icon,
                    "total": float(c.total),
                    "count": c.count,
                }
                for c in income_by_category
            ],
            "expenses_by_user": [
                {"id": u.id, "name": u.name, "total": float(u.total)}
                for u in expenses_by_user
            ],
            "income_by_user": [
                {"id": u.id, "name": u.name, "total": float(u.total)}
                for u in income_by_user
            ],
        }
    )
