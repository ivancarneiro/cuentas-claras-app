from datetime import datetime, timezone

from app import db


class SavingAccount(db.Model):
    """Savings accounts/entities (e.g., U$D NX, U$D FT, BullMarket, Sobró 2025, etc.)"""

    __tablename__ = "saving_accounts"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    currency = db.Column(db.String(10), default="ARS", comment="ARS, USD, BTC, etc.")
    description = db.Column(db.String(255), nullable=True)
    owner_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id"),
        nullable=True,
        comment="Who created/manages this account",
    )
    household_id = db.Column(
        db.Integer,
        db.ForeignKey("households.id"),
        nullable=True,
        comment="Household this account belongs to",
    )
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    balances = db.relationship("Saving", backref="account", lazy=True)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "currency": self.currency,
            "description": self.description,
            "owner_id": self.owner_id,
            "household_id": self.household_id,
        }


class Saving(db.Model):
    """Monthly savings balance per account"""

    __tablename__ = "savings"

    id = db.Column(db.Integer, primary_key=True)
    account_id = db.Column(
        db.Integer, db.ForeignKey("saving_accounts.id"), nullable=False
    )
    household_id = db.Column(
        db.Integer,
        db.ForeignKey("households.id"),
        nullable=True,
        comment="Household this saving belongs to",
    )
    month = db.Column(db.Integer, nullable=False, comment="1-12")
    year = db.Column(db.Integer, nullable=False)
    balance = db.Column(
        db.Float, nullable=False, comment="Balance in the entry's currency"
    )
    currency = db.Column(
        db.String(10),
        nullable=True,
        comment="Per-entry currency override (ARS, USD, BRL, BTC, etc.). Falls back to account currency.",
    )
    balance_ars = db.Column(db.Float, nullable=True, comment="Balance converted to ARS")
    note = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(db.DateTime, onupdate=lambda: datetime.now(timezone.utc))

    def to_dict(self):
        return {
            "id": self.id,
            "account_id": self.account_id,
            "account_name": self.account.name if self.account else None,
            "currency": self.currency
            or (self.account.currency if self.account else "ARS"),
            "household_id": self.household_id,
            "month": self.month,
            "year": self.year,
            "balance": self.balance,
            "balance_ars": self.balance_ars,
            "note": self.note,
        }


class MonthlySavingAdjustment(db.Model):
    """Manual adjustment for monthly savings when real cash differs from tracked transactions"""

    __tablename__ = "monthly_saving_adjustments"

    id = db.Column(db.Integer, primary_key=True)
    household_id = db.Column(
        db.Integer,
        db.ForeignKey("households.id"),
        nullable=False,
        comment="Household this adjustment belongs to",
    )
    month = db.Column(db.Integer, nullable=False, comment="1-12")
    year = db.Column(db.Integer, nullable=False)
    amount_ars = db.Column(db.Float, nullable=False, comment="Real net saving amount in ARS")
    note = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(db.DateTime, onupdate=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        db.UniqueConstraint("household_id", "year", "month", name="uq_household_year_month_adj"),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "household_id": self.household_id,
            "month": self.month,
            "year": self.year,
            "amount_ars": self.amount_ars,
            "note": self.note,
        }

