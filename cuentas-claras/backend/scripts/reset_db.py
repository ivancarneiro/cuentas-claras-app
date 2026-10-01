"""
Reset database and re-import all data from seed + ODS.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app import create_app, db

app = create_app()

with app.app_context():
    # Drop all tables and recreate
    db.drop_all()
    db.create_all()
    print("🗑️  Base de datos reseteada")

# Run seed
print("\n🌱 Ejecutando seed...")
exec(open(os.path.join(os.path.dirname(__file__), "seed.py")).read())

# Run import
print("\n📥 Ejecutando importación ODS...")
exec(open(os.path.join(os.path.dirname(__file__), "import_ods.py")).read())

print("\n✅ Reset completo!")
