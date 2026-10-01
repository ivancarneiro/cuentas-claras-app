import logging
import secrets
from datetime import datetime, timedelta, timezone

from flask import Blueprint, jsonify, request

from app import db
from app.auth.permissions import household_access
from app.models.household import Household, HouseholdMember, Invitation
from app.models.user import User
from app.routes.auth import login_required

households_bp = Blueprint("households", __name__)
logger = logging.getLogger("cuentasclaras.households")


# ─── Own Households ─────────────────────────────────────────────────


@households_bp.route("/mine", methods=["GET"])
@login_required
def get_my_households():
    """Get all households the current user belongs to."""
    from app.models.user import is_app_owner

    user = request.current_user
    memberships = HouseholdMember.query.filter_by(user_id=user.id).all()

    result = []
    dirty = False
    for m in memberships:
        h = m.household
        if not h:
            continue

        actual_role = m.role
        # Auto-heal: Creator of a household MUST ALWAYS be Owner
        if h.created_by == user.id and m.role != "owner":
            m.role = "owner"
            actual_role = "owner"
            dirty = True
        elif is_app_owner(user.email) and h.name.lower() in ("casa", "cuentas claras") and m.role != "owner":
            m.role = "owner"
            actual_role = "owner"
            dirty = True

        now_utc = datetime.now(timezone.utc)
        active_invitations = (
            Invitation.query.filter_by(household_id=h.id, accepted=False)
            .filter(Invitation.expires_at > now_utc)
            .order_by(Invitation.created_at.desc())
            .all()
        )
        invitation_list = []
        for inv in active_invitations:
            inv_dict = inv.to_dict()
            inv_dict["invitation_link"] = f"{request.host_url}invitar/{inv.token}"
            invitation_list.append(inv_dict)

        result.append(
            {
                "id": h.id,
                "name": h.name,
                "role": actual_role,
                "member_count": len(h.members),
                "created_by": h.created_by,
                "members": [member.to_dict() for member in h.members],
                "pending_invitations": invitation_list,
            }
        )

    if dirty:
        db.session.commit()

    return jsonify(result)


@households_bp.route("", methods=["POST"])
@login_required
def create_household():
    """Create a new household. The creator becomes Owner."""
    data = request.get_json() or {}
    if not data.get("name"):
        return jsonify({"error": "Nombre del grupo requerido"}), 400

    user = request.current_user

    household = Household(
        name=data["name"],
        created_by=user.id,
    )
    db.session.add(household)
    db.session.flush()  # Get ID

    # Creator becomes Owner
    member = HouseholdMember(
        household_id=household.id,
        user_id=user.id,
        role="owner",
        invited_by=user.id,
        accepted_at=datetime.now(timezone.utc),
    )
    db.session.add(member)

    # Cargamos las categorías básicas por defecto para este nuevo grupo familiar
    from app.utils.category_defaults import seed_default_categories
    seed_default_categories(household.id, user.id)

    db.session.commit()

    logger.info(
        "Household created — id=%d name=%s by user=%d",
        household.id,
        household.name,
        user.id,
    )
    return jsonify(household.to_dict()), 201


@households_bp.route("/<int:household_id>", methods=["GET"])
@login_required
@household_access("read")
def get_household(household_id):
    """Get household details."""
    household = db.session.get(Household, household_id)
    if not household:
        return jsonify({"error": "Grupo familiar no encontrado"}), 404
    return jsonify(household.to_dict())


@households_bp.route("/<int:household_id>", methods=["PUT"])
@login_required
@household_access("admin")
def update_household(household_id):
    """Update household name (admin+)."""
    household = db.session.get(Household, household_id)
    if not household:
        return jsonify({"error": "Grupo familiar no encontrado"}), 404
    data = request.get_json() or {}
    if data.get("name"):
        household.name = data["name"]
    db.session.commit()
    return jsonify(household.to_dict())


@households_bp.route("/<int:household_id>", methods=["DELETE"])
@login_required
@household_access("owner")
def delete_household(household_id):
    """Delete a household if it has no financial records. Only Owner can delete."""
    household = db.session.get(Household, household_id)
    if not household:
        return jsonify({"error": "Grupo familiar no encontrado"}), 404

    # Check for transactions
    from app.models.transaction import Transaction

    tx_count = Transaction.query.filter_by(household_id=household_id).count()
    if tx_count > 0:
        return (
            jsonify(
                {
                    "error": (
                        f"No se puede eliminar el grupo '{household.name}' porque tiene "
                        f"{tx_count} transacción(es) asociada(s). Elimine o transfiera las "
                        "transacciones primero."
                    )
                }
            ),
            400,
        )

    # Check for savings
    from app.models.saving import Saving, SavingAccount

    savings_count = (
        db.session.query(Saving)
        .join(SavingAccount)
        .filter(SavingAccount.household_id == household_id)
        .count()
    )
    if savings_count > 0:
        return (
            jsonify(
                {
                    "error": (
                        f"No se puede eliminar el grupo '{household.name}' porque tiene "
                        f"{savings_count} registro(s) de ahorro asociado(s)."
                    )
                }
            ),
            400,
        )

    # Cleanup associated empty accounts, categories, invitations, budgets and members
    from app.models.category import Category
    from app.models.monthly_budget import MonthlyBudget

    Category.query.filter_by(household_id=household_id).delete()
    SavingAccount.query.filter_by(household_id=household_id).delete()
    Invitation.query.filter_by(household_id=household_id).delete()
    MonthlyBudget.query.filter_by(household_id=household_id).delete()
    HouseholdMember.query.filter_by(household_id=household_id).delete()

    db.session.delete(household)
    db.session.commit()

    logger.info(
        "Household deleted — id=%d name=%s by user=%d",
        household_id,
        household.name,
        request.current_user.id,
    )
    return (
        jsonify(
            {"message": f"Grupo '{household.name}' eliminado correctamente"}
        ),
        200,
    )



# ─── Members ────────────────────────────────────────────────────────


@households_bp.route("/<int:household_id>/members", methods=["GET"])
@login_required
@household_access("read")
def get_members(household_id):
    """List all members of a household."""
    members = HouseholdMember.query.filter_by(household_id=household_id).all()
    return jsonify([m.to_dict() for m in members])


@households_bp.route("/<int:household_id>/members/<int:member_id>", methods=["DELETE"])
@login_required
@household_access("admin")
def remove_member(household_id, member_id):
    """Remove a member. Only owner can remove an admin."""
    member = db.session.get(HouseholdMember, member_id)
    if not member:
        return jsonify({"error": "Miembro no encontrado"}), 404

    # Owner cannot be removed
    if member.role == "owner":
        return jsonify(
            {"error": "El propietario del grupo no puede ser eliminado"}
        ), 403

    # Only owner can remove admins
    if member.role == "admin" and request.current_role != "owner":
        return jsonify(
            {"error": "Solo el propietario puede eliminar administradores"}
        ), 403

    # Cannot remove yourself if you're the last admin/owner
    remaining = HouseholdMember.query.filter_by(household_id=household_id).count()
    if remaining <= 1:
        return jsonify({"error": "No puede quedar el grupo sin miembros"}), 400

    db.session.delete(member)
    db.session.commit()
    return jsonify({"message": "Miembro eliminado del grupo"})


@households_bp.route(
    "/<int:household_id>/members/<int:member_id>/role", methods=["PUT"]
)
@login_required
@household_access("admin")
def update_member_role(household_id, member_id):
    """Change a member's role. Only owner can set admin."""
    data = request.get_json() or {}
    new_role = data.get("role")
    if new_role not in ("read", "edit", "admin"):
        return jsonify({"error": "Rol inválido. Use: read, edit, admin"}), 400

    member = db.session.get(HouseholdMember, member_id)
    if not member:
        return jsonify({"error": "Miembro no encontrado"}), 404

    # Owner's role cannot be changed
    if member.role == "owner":
        return jsonify({"error": "El rol del propietario no puede cambiarse"}), 403

    # Only owner can promote to admin
    household = db.session.get(Household, household_id)
    is_owner = (request.current_role == "owner") or (household and household.created_by == request.current_user.id)
    if new_role == "admin" and not is_owner:
        return jsonify({"error": "Solo el propietario puede asignar rol admin"}), 403

    member.role = new_role
    db.session.commit()
    return jsonify(member.to_dict())


# ─── Invitations ────────────────────────────────────────────────────


@households_bp.route("/<int:household_id>/invite", methods=["POST"])
@login_required
@household_access("admin")
def invite_member(household_id):
    """Invite someone to join the household by email."""
    data = request.get_json() or {}
    email = data.get("email", "").strip().lower()
    if not email:
        return jsonify({"error": "Email requerido"}), 400

    role = data.get("role", "read")
    if role not in ("read", "edit", "admin"):
        return jsonify({"error": "Rol inválido. Use: read, edit, admin"}), 400

    # Only owner can invite with admin role
    household = db.session.get(Household, household_id)
    is_owner = (request.current_role == "owner") or (household and household.created_by == request.current_user.id)
    if role == "admin" and not is_owner:
        return jsonify(
            {"error": "Solo el propietario puede invitar con rol admin"}
        ), 403

    # Check if already a member
    existing_user = User.query.filter_by(email=email).first()
    if existing_user:
        existing_member = HouseholdMember.query.filter_by(
            household_id=household_id, user_id=existing_user.id
        ).first()
        if existing_member:
            return jsonify({"error": "Este usuario ya es miembro del grupo"}), 409

    user = request.current_user
    now_utc = datetime.now(timezone.utc)

    # Check for pending invitation
    pending = Invitation.query.filter_by(
        household_id=household_id, invited_email=email, accepted=False
    ).first()

    if pending:
        # Renovar invitación existente con nuevo token, rol y TTL de 48hs max
        pending.token = secrets.token_urlsafe(48)
        pending.role = role
        pending.invited_by = user.id
        pending.created_at = now_utc
        pending.expires_at = now_utc + timedelta(hours=48)
        invitation = pending
        db.session.commit()
    else:
        invitation = Invitation(
            household_id=household_id,
            invited_email=email,
            token=secrets.token_urlsafe(48),
            role=role,
            invited_by=user.id,
            expires_at=now_utc + timedelta(hours=48),
        )
        db.session.add(invitation)
        db.session.commit()

    logger.info(
        "Invitation created/renewed — household=%d email=%s role=%s invited_by=%d expires_in=48h",
        household_id,
        email,
        role,
        user.id,
    )

    return jsonify(
        {
            **invitation.to_dict(),
            "token": invitation.token,
            "invitation_link": f"{request.host_url}invitar/{invitation.token}",
        }
    ), 201


@households_bp.route("/invitations/pending", methods=["GET"])
@login_required
def get_pending_invitations():
    """Get all pending invitations for the current user."""
    user = request.current_user
    now_utc = datetime.now(timezone.utc)
    invitations = (
        Invitation.query.filter_by(invited_email=user.email, accepted=False)
        .filter(Invitation.expires_at > now_utc)
        .all()
    )
    result = []
    for i in invitations:
        inv_data = i.to_dict()
        inv_data["invitation_link"] = f"{request.host_url}invitar/{i.token}"
        result.append(inv_data)
    return jsonify(result)


@households_bp.route("/invitations/<token>/accept", methods=["POST"])
@login_required
def accept_invitation(token):
    """Accept an invitation and join the household."""
    invitation = Invitation.query.filter_by(token=token, accepted=False).first()
    if not invitation:
        return jsonify({"error": "Invitación no encontrada o ya aceptada"}), 404

    now_utc = datetime.now(timezone.utc)
    exp = invitation.expires_at
    if exp:
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        if exp < now_utc:
            return jsonify({"error": "Esta invitación ha expirado"}), 410


    user = request.current_user
    if user.email != invitation.invited_email:
        return jsonify({"error": "Esta invitación fue enviada a otro email"}), 403

    # Add as member
    member = HouseholdMember(
        household_id=invitation.household_id,
        user_id=user.id,
        role=invitation.role,
        invited_by=invitation.invited_by,
        accepted_at=datetime.now(timezone.utc),
    )
    db.session.add(member)

    invitation.accepted = True
    db.session.commit()

    logger.info(
        "Invitation accepted — household=%d user=%d role=%s",
        invitation.household_id,
        user.id,
        invitation.role,
    )

    return jsonify(
        {
            "message": "Invitación aceptada",
            "household": invitation.household.to_dict(),
            "role": invitation.role,
        }
    )


@households_bp.route("/invitations/<int:invitation_id>", methods=["DELETE"])
@login_required
def decline_invitation(invitation_id):
    """Decline/delete a pending invitation."""
    invitation = db.session.get(Invitation, invitation_id)
    if not invitation:
        return jsonify({"error": "Invitación no encontrada"}), 404
    user = request.current_user

    # Only the invitee or an admin of the household can delete
    if user.email != invitation.invited_email:
        membership = HouseholdMember.query.filter_by(
            household_id=invitation.household_id, user_id=user.id
        ).first()
        if not membership or membership.role not in ("admin", "owner"):
            return jsonify(
                {"error": "No tenés permiso para cancelar esta invitación"}
            ), 403

    db.session.delete(invitation)
    db.session.commit()
    return jsonify({"message": "Invitación cancelada"})
