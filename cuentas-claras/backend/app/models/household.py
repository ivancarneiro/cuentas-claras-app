from datetime import datetime, timezone

from app import db


class Household(db.Model):
    """A shared household / group where users pool their financial data."""

    __tablename__ = "households"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    created_by = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    members = db.relationship("HouseholdMember", backref="household", lazy=True)
    invitations = db.relationship("Invitation", backref="household", lazy=True)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "created_by": self.created_by,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "member_count": len(self.members),
            "members": [m.to_dict() for m in self.members],
        }


class HouseholdMember(db.Model):
    """Membership and role of a user within a household."""

    __tablename__ = "household_members"

    __table_args__ = (
        db.UniqueConstraint("household_id", "user_id", name="uq_household_member"),
    )

    id = db.Column(db.Integer, primary_key=True)
    household_id = db.Column(db.Integer, db.ForeignKey("households.id"), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    role = db.Column(
        db.String(20),
        nullable=False,
        default="read",
        comment="owner | admin | edit | read",
    )
    invited_by = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=True)
    invited_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    accepted_at = db.Column(db.DateTime, nullable=True)

    def to_dict(self):
        return {
            "id": self.id,
            "household_id": self.household_id,
            "user_id": self.user_id,
            "user_name": self.user.name if self.user else None,
            "user_email": self.user.email if self.user else None,
            "name": self.user.name if self.user else None,
            "email": self.user.email if self.user else None,
            "role": self.role,
            "invited_by": self.invited_by,
            "accepted_at": self.accepted_at.isoformat() if self.accepted_at else None,
        }


class Invitation(db.Model):
    """Pending invitation to join a household by email."""

    __tablename__ = "invitations"

    id = db.Column(db.Integer, primary_key=True)
    household_id = db.Column(db.Integer, db.ForeignKey("households.id"), nullable=False)
    invited_email = db.Column(db.String(120), nullable=False)
    token = db.Column(
        db.String(128),
        unique=True,
        nullable=False,
        comment="Unique token for verification",
    )
    role = db.Column(
        db.String(20),
        nullable=False,
        default="read",
        comment="admin | edit | read",
    )
    invited_by = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)
    accepted = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    def to_dict(self):
        from app.models.user import User
        inviter = db.session.get(User, self.invited_by)
        created_iso = None
        if self.created_at:
            cat = self.created_at
            if cat.tzinfo is None:
                cat = cat.replace(tzinfo=timezone.utc)
            created_iso = cat.isoformat()
        exp_iso = None
        if self.expires_at:
            exp = self.expires_at
            if exp.tzinfo is None:
                exp = exp.replace(tzinfo=timezone.utc)
            exp_iso = exp.isoformat()

        return {
            "id": self.id,
            "household_id": self.household_id,
            "household_name": self.household.name if self.household else None,
            "invited_email": self.invited_email,
            "role": self.role,
            "token": self.token,
            "invited_by": self.invited_by,
            "invited_by_name": inviter.name if inviter else "Alguien",
            "accepted": self.accepted,
            "created_at": created_iso,
            "expires_at": exp_iso,
        }


