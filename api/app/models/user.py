from datetime import datetime, timezone

import bcrypt

from app import db


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    short_name = db.Column(
        db.String(10), nullable=True, comment="Iniciales para identificar al usuario"
    )
    photo_url = db.Column(
        db.String(500), nullable=True, comment="URL de foto de perfil (Google o manual)"
    )
    email_verified = db.Column(
        db.Boolean, default=False, comment="Si el email fue verificado"
    )
    verification_token = db.Column(
        db.String(128), nullable=True, unique=True, comment="Token para verificar email"
    )
    verification_token_expires = db.Column(
        db.DateTime, nullable=True, comment="Expiración del token de verificación"
    )
    is_active = db.Column(
        db.Boolean, default=True, nullable=False, comment="Si el usuario está habilitado en la plataforma"
    )
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    transactions = db.relationship("Transaction", backref="user", lazy=True)
    memberships = db.relationship(
        "HouseholdMember",
        foreign_keys="HouseholdMember.user_id",
        backref="user",
        lazy=True,
    )

    def set_password(self, password: str):
        self.password_hash = bcrypt.hashpw(
            password.encode("utf-8"), bcrypt.gensalt()
        ).decode("utf-8")

    def check_password(self, password: str) -> bool:
        return bcrypt.checkpw(
            password.encode("utf-8"), self.password_hash.encode("utf-8")
        )

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "short_name": self.short_name,
            "photo_url": self.photo_url,
            "email_verified": self.email_verified,
            "is_active": self.is_active if hasattr(self, "is_active") and self.is_active is not None else True,
            "is_app_owner": is_app_owner(self.email),
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


def is_app_owner(email: str | None) -> bool:
    """Verifies if the given email belongs to an application owner."""
    if not email:
        return False
    clean = email.strip().lower()
    try:
        from config import Config
        owner_emails = getattr(Config, "APP_OWNER_EMAILS", ["admin@cuentasclaras.app"])
    except Exception:
        owner_emails = ["admin@cuentasclaras.app"]
    return clean in owner_emails


class AuthorizedEmail(db.Model):
    """Emails pre-approved by the app owner to register as individual users."""

    __tablename__ = "authorized_emails"

    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    notes = db.Column(db.String(255), nullable=True)
    created_by = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    def to_dict(self):
        return {
            "id": self.id,
            "email": self.email,
            "notes": self.notes,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
