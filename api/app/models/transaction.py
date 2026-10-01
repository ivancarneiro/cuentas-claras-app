from datetime import datetime, timezone

from app import db


class Transaction(db.Model):
    __tablename__ = "transactions"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    household_id = db.Column(
        db.Integer,
        db.ForeignKey("households.id"),
        nullable=True,
        comment="Household this transaction belongs to",
    )
    category_id = db.Column(db.Integer, db.ForeignKey("categories.id"), nullable=False)
    date = db.Column(db.Date, nullable=False)
    description = db.Column(db.String(255), nullable=True)
    amount = db.Column(db.Float, nullable=False)
    currency = db.Column(
        db.String(10), default="ARS", nullable=False, comment="ARS, USD, BRL, BTC, etc."
    )
    type = db.Column(
        db.String(10),
        nullable=False,
        comment="income | expense",
    )
    is_fixed = db.Column(
        db.Boolean, default=False, comment="Whether it's a fixed monthly expense"
    )
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(db.DateTime, onupdate=lambda: datetime.now(timezone.utc))

    household = db.relationship("Household", backref="transactions", lazy=True)

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "user_name": self.user.name if self.user else None,
            "household_id": self.household_id,
            "household_name": self.household.name if self.household else None,
            "category_id": self.category_id,
            "category_name": self.category.name if self.category else None,
            "category_type": self.category.type if self.category else None,
            "date": self.date.isoformat() if self.date else None,
            "description": self.description,
            "amount": self.amount,
            "currency": self.currency,
            "type": self.type,
            "is_fixed": self.is_fixed,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

