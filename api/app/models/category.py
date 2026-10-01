from datetime import datetime, timezone

from app import db


class Category(db.Model):
    __tablename__ = "categories"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    type = db.Column(
        db.String(20),
        nullable=False,
        comment="income | fixed_expense | variable_expense | savings",
    )
    icon = db.Column(db.String(50), nullable=True)
    user_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id"),
        nullable=True,
        comment="Creator/owner (nullable for system categories)",
    )
    household_id = db.Column(
        db.Integer,
        db.ForeignKey("households.id"),
        nullable=True,
        comment="Household this category belongs to",
    )
    sort_order = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    transactions = db.relationship("Transaction", backref="category", lazy=True)
    household = db.relationship("Household", backref="categories", lazy=True)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "type": self.type,
            "icon": self.icon,
            "user_id": self.user_id,
            "household_id": self.household_id,
            "household_name": self.household.name if self.household else None,
            "sort_order": self.sort_order,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

