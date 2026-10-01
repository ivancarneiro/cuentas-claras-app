import logging

from flask import Blueprint, jsonify, request

from app import db
from app.auth.permissions import get_user_households
from app.models.category import Category
from app.routes.auth import login_required

categories_bp = Blueprint("categories", __name__)
logger = logging.getLogger("cuentasclaras.categories")


@categories_bp.route("", methods=["GET"])
@login_required
def get_categories():
    user = request.current_user
    households = get_user_households(user.id)
    cat_type = request.args.get("type")
    household_id = request.args.get("household_id")

    if household_id:
        try:
            h_id = int(household_id)
            if h_id in households:
                query = Category.query.filter(
                    db.or_(
                        Category.household_id == h_id,
                        Category.household_id.is_(None),
                        Category.user_id.is_(None),
                        db.and_(Category.user_id == user.id, Category.household_id.is_(None)),
                    )
                )
            else:
                return (
                    jsonify({"error": "No pertenecés al grupo especificado"}),
                    403,
                )
        except (ValueError, TypeError):
            return jsonify({"error": "household_id inválido"}), 400
    else:
        query = Category.query.filter(
            db.or_(
                Category.household_id.in_(households),
                Category.user_id == user.id,
                Category.household_id.is_(None),
                Category.user_id.is_(None),
            )
        )
    if cat_type:
        query = query.filter_by(type=cat_type)
    categories = query.order_by(Category.sort_order, Category.name).all()
    return jsonify([c.to_dict() for c in categories])


@categories_bp.route("/<int:category_id>", methods=["GET"])
@login_required
def get_category(category_id):
    category = db.session.get(Category, category_id)
    if not category:
        return jsonify({"error": "Categoría no encontrada"}), 404
    return jsonify(category.to_dict())


@categories_bp.route("", methods=["POST"])
@login_required
def create_category():
    data = request.get_json()
    if not data or not data.get("name") or not data.get("type"):
        return jsonify({"error": "Nombre y tipo requeridos"}), 400

    if data["type"] not in ("income", "fixed_expense", "variable_expense", "savings"):
        return jsonify(
            {
                "error": "Tipo inválido. Use: income, fixed_expense, variable_expense, savings"
            }
        ), 400

    user = request.current_user
    households = get_user_households(user.id)

    # Auto-assign household
    household_id = data.get("household_id")
    if household_id:
        if household_id not in households:
            return (
                jsonify({"error": "No pertenecés al grupo familiar especificado"}),
                403,
            )
    else:
        household_id = households[0] if households else None


    category = Category(
        name=data["name"],
        type=data["type"],
        icon=data.get("icon"),
        user_id=data.get("user_id") or request.current_user.id,
        household_id=household_id,
        sort_order=data.get("sort_order", 0),
    )
    db.session.add(category)
    db.session.commit()
    logger.info(
        "Category created — id=%d name=%s type=%s household_id=%s user_id=%d",
        category.id,
        category.name,
        category.type,
        category.household_id,
        request.current_user.id,
    )
    return jsonify(category.to_dict()), 201


@categories_bp.route("/<int:category_id>", methods=["PUT"])
@login_required
def update_category(category_id):
    category = db.session.get(Category, category_id)
    if not category:
        return jsonify({"error": "Categoría no encontrada"}), 404

    households = get_user_households(request.current_user.id)
    if category.household_id and category.household_id not in households:
        return jsonify({"error": "No tiene permiso para editar esta categoría"}), 403

    data = request.get_json() or {}
    if data.get("name"):
        category.name = data["name"]
    if data.get("type"):
        if data["type"] not in (
            "income",
            "fixed_expense",
            "variable_expense",
            "savings",
        ):
            return jsonify({"error": "Tipo inválido"}), 400
        category.type = data["type"]
    if data.get("icon") is not None:
        category.icon = data["icon"]
    if data.get("sort_order") is not None:
        category.sort_order = data["sort_order"]
    db.session.commit()
    logger.info(
        "Category updated — id=%d name=%s type=%s household_id=%s",
        category.id,
        category.name,
        category.type,
        category.household_id,
    )
    return jsonify(category.to_dict())


@categories_bp.route("/<int:category_id>", methods=["DELETE"])
@login_required
def delete_category(category_id):
    category = db.session.get(Category, category_id)
    if not category:
        return jsonify({"error": "Categoría no encontrada"}), 404

    households = get_user_households(request.current_user.id)
    if category.household_id and category.household_id not in households:
        return jsonify({"error": "No tiene permiso para eliminar esta categoría"}), 403

    from app.models.transaction import Transaction

    tx_count = Transaction.query.filter_by(category_id=category_id).count()
    if tx_count > 0:
        logger.warning(
            "Attempted to delete category id=%d name=%s with %d transactions",
            category_id,
            category.name,
            tx_count,
        )
        return (
            jsonify(
                {
                    "error": f"No se puede eliminar la categoría '{category.name}' porque tiene {tx_count} transacción(es) asociada(s). Reasigne o elimine las transacciones primero."
                }
            ),
            400,
        )

    from app.models.monthly_budget import MonthlyBudget

    budget_count = MonthlyBudget.query.filter_by(category_id=category_id).count()
    if budget_count > 0:
        logger.warning(
            "Attempted to delete category id=%d name=%s with %d budgets",
            category_id,
            category.name,
            budget_count,
        )
        return (
            jsonify(
                {
                    "error": f"No se puede eliminar la categoría '{category.name}' porque tiene {budget_count} presupuesto(s) mensual(es) asociado(s)."
                }
            ),
            400,
        )

    category_name = category.name
    db.session.delete(category)
    db.session.commit()
    logger.info("Category deleted — id=%d name=%s", category_id, category_name)
    return jsonify({"message": "Categoría eliminada"})

