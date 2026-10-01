from functools import wraps

from flask import jsonify, request

from app.models.household import HouseholdMember

# Role hierarchy: higher = more permissions
ROLE_LEVELS = {
    "read": 0,
    "edit": 1,
    "admin": 2,
    "owner": 3,
}


def get_user_households(user_id):
    """Get all households the user belongs to."""
    memberships = HouseholdMember.query.filter_by(user_id=user_id).all()
    return [m.household_id for m in memberships]


def get_user_role(household_id, user_id):
    """Get the user's role in a specific household, or None if not a member."""
    membership = HouseholdMember.query.filter_by(
        household_id=household_id, user_id=user_id
    ).first()
    return membership.role if membership else None


def check_role(role, min_role):
    """Check if role meets the minimum required level."""
    return ROLE_LEVELS.get(role, -1) >= ROLE_LEVELS.get(min_role, 0)


def household_access(min_role="read"):
    """Decorator that verifies the user has at least `min_role` in the household.

    The household_id is resolved in this order:
    1. request.json['household_id'] (for POST/PUT)
    2. request.args['household_id'] (for GET)
    3. From the resource itself (for GET/DELETE on specific resources)
    """

    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            user = getattr(request, "current_user", None)
            if not user:
                return jsonify({"error": "Usuario no autenticado"}), 401

            household_id = _resolve_household_id(kwargs)
            if not household_id:
                # If no household context, use user's first/default household
                memberships = HouseholdMember.query.filter_by(user_id=user.id).all()
                if not memberships:
                    return jsonify(
                        {"error": "No pertenecés a ningún grupo familiar"}
                    ), 403
                household_id = memberships[0].household_id

            role = get_user_role(household_id, user.id)
            if not role:
                return jsonify({"error": "No pertenecés a este grupo familiar"}), 403

            if not check_role(role, min_role):
                return jsonify(
                    {
                        "error": f"Se requiere rol '{min_role}' o superior. Tu rol: '{role}'"
                    }
                ), 403

            request.current_household_id = household_id
            request.current_role = role
            return f(*args, **kwargs)

        return decorated

    return decorator


def _resolve_household_id(kwargs):
    """Try to resolve household_id from request data or resource."""
    # From JSON body
    if request.is_json:
        data = request.get_json(silent=True) or {}
        if data.get("household_id"):
            return data["household_id"]

    # From query params
    if request.args.get("household_id"):
        return int(request.args["household_id"])

    return None
