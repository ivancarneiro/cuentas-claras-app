import datetime
import logging
import secrets

import jwt
from flask import Blueprint, current_app, jsonify, request
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

from app import db, limiter
from app.models.user import User
from config import Config

auth_bp = Blueprint("auth", __name__)
logger = logging.getLogger("cuentasclaras.auth")



def generate_token(user_id):
    payload = {
        "user_id": user_id,
        "exp": datetime.datetime.now(datetime.timezone.utc)
        + Config.JWT_ACCESS_TOKEN_EXPIRES,
        "iat": datetime.datetime.now(datetime.timezone.utc),
    }
    return jwt.encode(payload, Config.SECRET_KEY, algorithm="HS256")


def decode_token(token):
    try:
        payload = jwt.decode(token, Config.SECRET_KEY, algorithms=["HS256"])
        return payload["user_id"]
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


def login_required(f):
    from functools import wraps

    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get("Authorization", "").replace("Bearer ", "")
        if not token:
            return jsonify({"error": "Token requerido"}), 401
        user_id = decode_token(token)
        if user_id is None:
            return jsonify({"error": "Token inválido o expirado"}), 401
        user = db.session.get(User, user_id)
        if not user:
            return jsonify({"error": "Usuario no encontrado"}), 401
        if hasattr(user, "is_active") and user.is_active is False:
            return jsonify({"error": "Tu cuenta ha sido deshabilitada por el administrador"}), 403
        request.current_user = user
        return f(*args, **kwargs)

    return decorated


@auth_bp.route("/login", methods=["POST"])
@limiter.limit("60 per minute; 1000 per hour")
def login():
    if Config.ENV == "production":
        return jsonify({"error": "El inicio de sesión local está deshabilitado en producción"}), 403

    data = request.get_json()
    email = (data or {}).get("email", "")
    logger.info("Login attempt — email=%s ip=%s", email, request.remote_addr)

    if not data or not email or not data.get("password"):
        logger.warning("Login failed — missing credentials email=%s", email)
        return jsonify({"error": "Email y contraseña requeridos"}), 400

    user = User.query.filter_by(email=email).first()
    if not user:
        logger.warning("Login failed — user not found email=%s", email)
        return jsonify({"error": "Email o contraseña incorrectos"}), 401

    if hasattr(user, "is_active") and user.is_active is False:
        logger.warning("Login blocked — inactive user email=%s", email)
        return jsonify({"error": "Tu cuenta ha sido deshabilitada por el administrador"}), 403

    if not user.check_password(data["password"]):
        logger.warning("Login failed — wrong password email=%s", email)
        return jsonify({"error": "Email o contraseña incorrectos"}), 401

    token = generate_token(user.id)
    logger.info(
        "Login success — email=%s user_id=%d name=%s", email, user.id, user.name
    )
    return jsonify(
        {
            "token": token,
            "user": user.to_dict(),
        }
    )


@auth_bp.route("/google-login", methods=["POST"])
@limiter.limit("60 per minute; 1000 per hour")
def google_login():
    """Login or register with Google ID token, validating user whitelist/authorization."""
    from app.models.user import AuthorizedEmail, is_app_owner
    from app.models.household import Household, HouseholdMember, Invitation
    from datetime import datetime, timezone

    data = request.get_json()
    logger.info("Google login attempt — ip=%s", request.remote_addr)

    if not data or not data.get("idToken"):
        logger.warning("Google login failed — missing idToken")
        return jsonify({"error": "Token de Google requerido"}), 400

    try:
        logger.debug(
            "Verifying Google ID token with client_id=%s...",
            Config.GOOGLE_CLIENT_ID[:30] + "...",
        )
        # Verify the Google ID token
        idinfo = id_token.verify_oauth2_token(
            data["idToken"],
            google_requests.Request(),
            Config.GOOGLE_CLIENT_ID,
        )
        logger.debug(
            "Google token verified successfully — audience=%s", idinfo.get("aud", "?")
        )

        # Extract user info from Google
        google_email = idinfo["email"].strip().lower()
        google_name = idinfo.get("name", "")
        logger.info("Google user — email=%s name=%s", google_email, google_name)

        # Find or create the user
        user = User.query.filter(db.func.lower(User.email) == google_email).first()
        if not user:
            # Check authorization for new user:
            is_owner = is_app_owner(google_email)
            authorized = AuthorizedEmail.query.filter(
                db.func.lower(AuthorizedEmail.email) == google_email
            ).first()
            pending_invitation = Invitation.query.filter(
                db.func.lower(Invitation.invited_email) == google_email,
                Invitation.accepted == False,
                Invitation.expires_at > datetime.now(timezone.utc),
            ).first()

            if not is_owner and not authorized and not pending_invitation:
                logger.warning(
                    "Unauthorized Google login rejected — email=%s", google_email
                )
                return (
                    jsonify(
                        {
                            "error": "Acceso denegado: tu cuenta no está habilitada. Solicitá acceso al administrador."
                        }
                    ),
                    403,
                )

            logger.info(
                "Authorized new user registering via Google — email=%s name=%s",
                google_email,
                google_name,
            )

            # Determine short_name from email or name
            short_name = None
            email_lower = google_email.lower()
            name_lower = google_name.lower()
            if "ivan" in email_lower or "ivan" in name_lower:
                short_name = "I"
            elif "tamara" in email_lower or "tamara" in name_lower:
                short_name = "T"

            user = User(
                name=google_name or google_email.split("@")[0],
                email=google_email,
                short_name=short_name,
                photo_url=idinfo.get("picture"),
                is_active=True,
            )
            user.set_password(secrets.token_urlsafe(32))
            db.session.add(user)
            db.session.flush()

            # Assign to household
            if pending_invitation:
                # User was invited to an existing group
                member = HouseholdMember(
                    household_id=pending_invitation.household_id,
                    user_id=user.id,
                    role=pending_invitation.role,
                    invited_by=pending_invitation.invited_by,
                    accepted_at=datetime.now(timezone.utc),
                )
                db.session.add(member)
                pending_invitation.accepted = True
                logger.info(
                    "User %s joined household %d via invitation as %s",
                    user.email,
                    pending_invitation.household_id,
                    pending_invitation.role,
                )
            else:
                # Individual user authorized by owner: create their personal household!
                personal_household = Household(
                    name="Mi Economía",
                    created_by=user.id,
                )
                db.session.add(personal_household)
                db.session.flush()

                member = HouseholdMember(
                    household_id=personal_household.id,
                    user_id=user.id,
                    role="owner",
                    invited_by=user.id,
                    accepted_at=datetime.now(timezone.utc),
                )
                db.session.add(member)

                from app.utils.category_defaults import seed_default_categories
                seed_default_categories(personal_household.id, user.id)
                logger.info(
                    "Personal household created for individual user %s (id=%d)",
                    user.email,
                    personal_household.id,
                )

            db.session.commit()
            logger.info(
                "User created — id=%d email=%s short_name=%s",
                user.id,
                user.email,
                short_name,
            )
        else:
            # Check if active
            if hasattr(user, "is_active") and user.is_active is False:
                logger.warning(
                    "Disabled user Google login rejected — id=%d email=%s",
                    user.id,
                    user.email,
                )
                return (
                    jsonify(
                        {
                            "error": "Tu cuenta ha sido deshabilitada por el administrador"
                        }
                    ),
                    403,
                )

            logger.info("Existing user found — id=%d email=%s", user.id, user.email)
            # Update Google profile data on each login
            user.name = google_name or user.name
            user.photo_url = idinfo.get("picture") or user.photo_url
            db.session.commit()

        token = generate_token(user.id)
        logger.info("Google login success — user_id=%d email=%s", user.id, google_email)
        return jsonify(
            {
                "token": token,
                "user": user.to_dict(),
            }
        )

    except ValueError as e:
        logger.error("Google token verification failed: %s", str(e), exc_info=True)
        return jsonify({"error": f"Token de Google inválido: {str(e)}"}), 401
    except Exception as e:
        logger.error("Error en Google login: %s", str(e), exc_info=True)
        db.session.rollback()
        return jsonify({"error": f"Error al procesar inicio de sesión con Google: {str(e)}"}), 500


@auth_bp.route("/register", methods=["POST"])
@limiter.limit("60 per minute; 1000 per hour")
def register():
    if Config.ENV == "production":
        return jsonify({"error": "El registro local está deshabilitado en producción"}), 403

    if not current_app.config.get("ALLOW_PUBLIC_REGISTRATION", False):
        logger.warning(
            "Public registration attempt blocked — ip=%s", request.remote_addr
        )
        return (
            jsonify(
                {
                    "error": "El registro público está deshabilitado en esta instancia"
                }
            ),
            403,
        )

    data = request.get_json()
    if (
        not data
        or not data.get("email")
        or not data.get("password")
        or not data.get("name")
    ):
        return jsonify({"error": "Nombre, email y contraseña requeridos"}), 400

    if User.query.filter_by(email=data["email"]).first():
        return jsonify({"error": "El email ya está registrado"}), 409

    user = User(
        name=data["name"],
        email=data["email"],
        short_name=data.get("short_name"),
    )
    user.set_password(data["password"])
    db.session.add(user)
    db.session.commit()

    token = generate_token(user.id)
    return jsonify({"token": token, "user": user.to_dict()}), 201


@auth_bp.route("/me", methods=["GET"])
@login_required
def me():
    return jsonify(request.current_user.to_dict())


@auth_bp.route("/avatar/<int:user_id>", methods=["GET"])
def get_user_avatar(user_id):
    user = db.session.get(User, user_id)
    if not user or not user.photo_url:
        return jsonify({"error": "No avatar"}), 404
    import urllib.request
    from flask import Response
    try:
        req = urllib.request.Request(
            user.photo_url, headers={"User-Agent": "Mozilla/5.0"}
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            content_type = resp.headers.get("Content-Type", "image/jpeg")
            data = resp.read()
            return Response(
                data,
                mimetype=content_type,
                headers={
                    "Cache-Control": "public, max-age=86400",
                    "Access-Control-Allow-Origin": "*",
                },
            )
    except Exception as e:
        logger.warning("Failed to proxy avatar: %s", str(e))
        return jsonify({"error": "Failed to fetch avatar"}), 502


@auth_bp.route("/profile", methods=["PUT"])
@login_required
def update_profile():
    """Update the current user's profile."""
    data = request.get_json()
    if not data:
        return jsonify({"error": "Datos requeridos"}), 400

    user = request.current_user

    if data.get("name"):
        user.name = data["name"]
    if data.get("short_name") is not None:
        user.short_name = data["short_name"]
    if data.get("photo_url") is not None:
        user.photo_url = data["photo_url"]
    if data.get("email") and data["email"] != user.email:
        # Check email is not taken
        existing = User.query.filter_by(email=data["email"]).first()
        if existing and existing.id != user.id:
            return jsonify({"error": "El email ya está registrado"}), 409
        user.email = data["email"]

    db.session.commit()
    logger.info("Profile updated — user_id=%d", user.id)
    return jsonify(user.to_dict())
