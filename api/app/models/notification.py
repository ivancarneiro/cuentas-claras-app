from datetime import datetime, timezone
from app import db

class Notification(db.Model):
    __tablename__ = "notifications"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    actor_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=True)
    household_id = db.Column(db.Integer, db.ForeignKey("households.id"), nullable=True)
    title = db.Column(db.String(120), nullable=False)
    message = db.Column(db.String(255), nullable=False)
    type = db.Column(db.String(40), default="transaction_created") # transaction_created, transaction_updated, transaction_deleted, member_joined, invite_sent
    reference_id = db.Column(db.Integer, nullable=True)
    is_read = db.Column(db.Boolean, default=False, nullable=False, index=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), index=True)

    recipient = db.relationship("User", foreign_keys=[user_id], backref="notifications")
    actor = db.relationship("User", foreign_keys=[actor_id])
    household = db.relationship("Household", foreign_keys=[household_id])

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "actor_id": self.actor_id,
            "actor_name": self.actor.name if self.actor else None,
            "actor_short_name": self.actor.short_name if self.actor else None,
            "actor_photo_url": self.actor.photo_url if self.actor else None,
            "household_id": self.household_id,
            "household_name": self.household.name if self.household else None,
            "title": self.title,
            "message": self.message,
            "type": self.type,
            "reference_id": self.reference_id,
            "is_read": self.is_read,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class DeviceToken(db.Model):
    __tablename__ = "device_tokens"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    token = db.Column(db.String(500), unique=True, nullable=False)
    platform = db.Column(db.String(20), default="android") # android, ios, web
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    user = db.relationship("User", backref="device_tokens")

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "token": self.token,
            "platform": self.platform,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
