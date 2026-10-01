from datetime import datetime, timezone

from app import db


class MonthlyBudget(db.Model):
    __tablename__ = "monthly_budgets"

    id = db.Column(db.Integer, primary_key=True)
    category_id = db.Column(db.Integer, db.ForeignKey("categories.id"), nullable=False)
    household_id = db.Column(
        db.Integer,
        db.ForeignKey("households.id"),
        nullable=True,
        comment="Household this budget belongs to",
    )
    month = db.Column(db.Integer, nullable=False, comment="1-12")
    year = db.Column(db.Integer, nullable=False)
    limit_amount = db.Column(
        db.Float, nullable=False, comment="Budget limit for the category"
    )
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(db.DateTime, onupdate=lambda: datetime.now(timezone.utc))

    category = db.relationship("Category", backref="budgets")

    def to_dict(self):
        return {
            "id": self.id,
            "category_id": self.category_id,
            "category_name": self.category.name if self.category else None,
            "household_id": self.household_id,
            "month": self.month,
            "year": self.year,
            "limit_amount": self.limit_amount,
        }
