import json
import logging
import os
from typing import List, Optional

from app import db
from app.models.household import Household, HouseholdMember
from app.models.notification import DeviceToken, Notification
from app.models.user import User

logger = logging.getLogger("cuentasclaras.notifications")

_firebase_initialized = False


def _init_firebase():
    """Initializes Firebase Admin SDK if credentials are provided."""
    global _firebase_initialized
    if _firebase_initialized:
        return True

    try:
        import firebase_admin
        from firebase_admin import credentials

        # 1. Chequeo de credenciales en variable de entorno (JSON string)
        cred_json = os.environ.get("FIREBASE_CREDENTIALS")
        if cred_json:
            cred_dict = json.loads(cred_json)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK inicializado exitosamente desde FIREBASE_CREDENTIALS")
            return True

        # 2. Chequeo de archivo de credenciales
        cred_path = os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH")
        if cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK inicializado exitosamente desde %s", cred_path)
            return True

    except Exception as e:
        logger.warning("No se pudo inicializar Firebase Admin SDK: %s", e)

    return False


def send_push_notification(tokens: List[str], title: str, message: str, data: Optional[dict] = None):
    """Sends a push notification to a list of device tokens via Firebase Cloud Messaging."""
    if not tokens:
        return

    if not _init_firebase():
        logger.debug("Push notification omitida: Firebase no está configurado.")
        return

    try:
        from firebase_admin import messaging

        clean_data = {}
        if data:
            for k, v in data.items():
                clean_data[str(k)] = str(v) if v is not None else ""

        # Usar multicast para enviar en lote a múltiples dispositivos
        multicast = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=message,
            ),
            data=clean_data,
            tokens=tokens,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    icon="@mipmap/ic_launcher",
                    color="#4361EE",
                    sound="default",
                ),
            ),
        )

        response = messaging.send_each_for_multicast(multicast)
        logger.info("FCM: %d mensajes enviados exitosamente, %d fallidos", response.success_count, response.failure_count)

        # Si hay tokens inválidos o desinstalados, eliminarlos de la base de datos
        if response.failure_count > 0:
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    failed_token = tokens[idx]
                    logger.debug("Removiendo token FCM inválido: %s...", failed_token[:20])
                    DeviceToken.query.filter_by(token=failed_token).delete()
            db.session.commit()

    except Exception as e:
        logger.error("Error al enviar notificación push con FCM: %s", e)


def notify_household_members(
    household_id: Optional[int],
    actor_id: Optional[int],
    title: str,
    message: str,
    notification_type: str = "transaction_created",
    reference_id: Optional[int] = None,
):
    """
    Creates in-app notifications and sends push notifications to all members
    of the specified household except the actor.
    """
    if not household_id:
        return

    household = db.session.get(Household, household_id)
    if not household:
        return

    # Buscar miembros del hogar excepto el actor
    members = HouseholdMember.query.filter(
        HouseholdMember.household_id == household_id
    ).all()

    recipient_ids = [m.user_id for m in members if m.user_id != actor_id]
    if not recipient_ids:
        return

    # 1. Crear notificaciones en la base de datos (Fase 1: In-App)
    for user_id in recipient_ids:
        notif = Notification(
            user_id=user_id,
            actor_id=actor_id,
            household_id=household_id,
            title=title,
            message=message,
            type=notification_type,
            reference_id=reference_id,
            is_read=False,
        )
        db.session.add(notif)

    try:
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        logger.error("Error guardando notificaciones in-app: %s", e)
        return

    # 2. Despachar notificaciones push si hay tokens registrados (Fase 2: FCM)
    try:
        device_tokens = (
            DeviceToken.query.filter(DeviceToken.user_id.in_(recipient_ids))
            .with_entities(DeviceToken.token)
            .all()
        )
        tokens = [t[0] for t in device_tokens if t[0]]
        if tokens:
            send_push_notification(
                tokens=tokens,
                title=title,
                message=message,
                data={
                    "type": notification_type,
                    "household_id": household_id,
                    "reference_id": reference_id,
                },
            )
    except Exception as e:
        logger.error("Error al buscar tokens de dispositivo para push: %s", e)
