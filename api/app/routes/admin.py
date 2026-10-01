import logging
from flask import Blueprint, jsonify, request
from app import db
from app.models.user import User, AuthorizedEmail, is_app_owner
from app.models.household import Household
from app.routes.auth import login_required

admin_bp = Blueprint("admin", __name__)
logger = logging.getLogger("cuentasclaras.admin")


def app_owner_required(f):
    """Decorator to require that the current user is the application owner."""
    @login_required
    def decorated(*args, **kwargs):
        user = getattr(request, "current_user", None)
        if not user or not is_app_owner(user.email):
            logger.warning(
                "Unauthorized admin access attempt by user_id=%s email=%s",
                getattr(user, "id", None),
                getattr(user, "email", None),
            )
            return jsonify({"error": "Solo el dueño de la aplicación puede acceder a esta sección"}), 403
        return f(*args, **kwargs)
    decorated.__name__ = f.__name__
    return decorated


@admin_bp.route("/users", methods=["GET"])
@app_owner_required
def list_users():
    """List all registered users and pending pre-authorized emails."""
    users = User.query.order_by(User.id.asc()).all()
    authorized = AuthorizedEmail.query.order_by(AuthorizedEmail.created_at.desc()).all()

    users_data = []
    for u in users:
        d = u.to_dict()
        # Count owned households (without revealing financial data)
        d["owned_households_count"] = Household.query.filter_by(created_by=u.id).count()
        users_data.append(d)

    return jsonify({
        "users": users_data,
        "authorized_emails": [a.to_dict() for a in authorized],
    })


@admin_bp.route("/authorized-emails", methods=["POST"])
@app_owner_required
def authorize_email():
    """Pre-authorize an email address so that the user can register independently."""
    data = request.get_json() or {}
    email = data.get("email", "").strip().lower()
    notes = data.get("notes", "").strip()

    if not email or "@" not in email:
        return jsonify({"error": "Email válido requerido"}), 400

    # Check if already a registered user
    existing_user = User.query.filter(db.func.lower(User.email) == email).first()
    if existing_user:
        # If user exists and is disabled, re-enable
        if not existing_user.is_active:
            existing_user.is_active = True
            db.session.commit()
            return jsonify({
                "message": f"El usuario {email} ya existía y fue reactivado",
                "user": existing_user.to_dict(),
            }), 200
        return jsonify({"error": "Este correo ya está registrado y activo en la plataforma"}), 409

    # Check if already in authorized list
    existing_auth = AuthorizedEmail.query.filter(db.func.lower(AuthorizedEmail.email) == email).first()
    if existing_auth:
        return jsonify({"error": "Este correo ya se encuentra en la lista de autorizados"}), 409

    new_auth = AuthorizedEmail(
        email=email,
        notes=notes or None,
        created_by=request.current_user.id,
    )
    db.session.add(new_auth)
    db.session.commit()

    logger.info("Email authorized by owner — email=%s owner_id=%d", email, request.current_user.id)
    return jsonify({
        "message": f"Correo {email} autorizado exitosamente",
        "authorized_email": new_auth.to_dict(),
    }), 201


@admin_bp.route("/authorized-emails/<int:id>", methods=["DELETE"])
@app_owner_required
def revoke_authorized_email(id):
    """Revoke an authorized email before registration."""
    auth_entry = db.session.get(AuthorizedEmail, id)
    if not auth_entry:
        return jsonify({"error": "Autorización no encontrada"}), 404

    email = auth_entry.email
    db.session.delete(auth_entry)
    db.session.commit()

    logger.info("Email authorization revoked — email=%s", email)
    return jsonify({"message": f"Autorización revocada para {email}"})


@admin_bp.route("/users/<int:user_id>/toggle-status", methods=["PUT"])
@app_owner_required
def toggle_user_status(user_id):
    """Enable or disable a user account."""
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "Usuario no encontrado"}), 404

    # Prevent disabling the app owner
    if is_app_owner(user.email):
        return jsonify({"error": "No se puede deshabilitar la cuenta del dueño de la aplicación"}), 400

    user.is_active = not user.is_active
    db.session.commit()

    action = "habilitado" if user.is_active else "deshabilitado"
    logger.info("User account %s — user_id=%d email=%s", action, user.id, user.email)
    return jsonify({
        "message": f"Usuario {user.email} {action} correctamente",
        "user": user.to_dict(),
    })
