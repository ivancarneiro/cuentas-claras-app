from flask import Blueprint, jsonify, request
from app import db
from app.models.notification import DeviceToken, Notification
from app.routes.auth import login_required

notifications_bp = Blueprint("notifications", __name__)


@notifications_bp.route("", methods=["GET"])
@login_required
def get_notifications():
    """Retorna las notificaciones del usuario autenticado ordenadas por fecha reciente."""
    user = request.current_user
    limit = min(request.args.get("limit", default=50, type=int), 100)
    page = max(request.args.get("page", default=1, type=int), 1)

    query = Notification.query.filter_by(user_id=user.id).order_by(
        Notification.created_at.desc()
    )
    pagination = query.paginate(page=page, per_page=limit, error_out=False)

    return jsonify(
        {
            "notifications": [n.to_dict() for n in pagination.items],
            "total": pagination.total,
            "page": pagination.page,
            "pages": pagination.pages,
            "has_next": pagination.has_next,
        }
    )


@notifications_bp.route("/unread-count", methods=["GET"])
@login_required
def get_unread_count():
    """Retorna la cantidad de notificaciones no leídas."""
    user = request.current_user
    count = Notification.query.filter_by(
        user_id=user.id, is_read=False
    ).count()
    return jsonify({"unread_count": count})


@notifications_bp.route("/<int:notification_id>/read", methods=["POST"])
@login_required
def mark_notification_read(notification_id):
    """Marca una notificación específica como leída."""
    user = request.current_user
    notif = Notification.query.filter_by(
        id=notification_id, user_id=user.id
    ).first()
    if not notif:
        return jsonify({"error": "Notificación no encontrada"}), 404

    notif.is_read = True
    db.session.commit()
    return jsonify({"message": "Notificación marcada como leída", "notification": notif.to_dict()})


@notifications_bp.route("/read-all", methods=["POST"])
@login_required
def mark_all_read():
    """Marca todas las notificaciones del usuario como leídas."""
    user = request.current_user
    Notification.query.filter_by(user_id=user.id, is_read=False).update(
        {"is_read": True}
    )
    db.session.commit()
    return jsonify({"message": "Todas las notificaciones fueron marcadas como leídas"})


@notifications_bp.route("/<int:notification_id>", methods=["DELETE"])
@login_required
def delete_notification(notification_id):
    """Elimina una notificación."""
    user = request.current_user
    notif = Notification.query.filter_by(
        id=notification_id, user_id=user.id
    ).first()
    if not notif:
        return jsonify({"error": "Notificación no encontrada"}), 404

    db.session.delete(notif)
    db.session.commit()
    return jsonify({"message": "Notificación eliminada"})


# ==========================================================
# GESTIÓN DE TOKENS DE DISPOSITIVO PARA PUSH (FCM)
# ==========================================================

@notifications_bp.route("/device-token", methods=["POST"])
@login_required
def register_device_token():
    """Registra o actualiza el FCM token del dispositivo del usuario."""
    user = request.current_user
    data = request.get_json() or {}
    token = data.get("token", "").strip()
    platform = data.get("platform", "android").strip().lower()

    if not token:
        return jsonify({"error": "El token de dispositivo es obligatorio"}), 400

    existing = DeviceToken.query.filter_by(token=token).first()
    if existing:
        existing.user_id = user.id
        existing.platform = platform
    else:
        new_token = DeviceToken(
            user_id=user.id,
            token=token,
            platform=platform,
        )
        db.session.add(new_token)

    db.session.commit()
    return jsonify({"message": "Token de dispositivo registrado exitosamente"})


@notifications_bp.route("/device-token", methods=["DELETE"])
@login_required
def unregister_device_token():
    """Elimina el FCM token al cerrar sesión."""
    user = request.current_user
    data = request.get_json() or {}
    token = data.get("token", "").strip()

    if token:
        DeviceToken.query.filter_by(token=token, user_id=user.id).delete()
    else:
        DeviceToken.query.filter_by(user_id=user.id).delete()

    db.session.commit()
    return jsonify({"message": "Token de dispositivo desvinculado exitosamente"})
