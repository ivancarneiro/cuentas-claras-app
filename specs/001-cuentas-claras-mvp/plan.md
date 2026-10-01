# Implementation Plan: Cuentas Claras MVP

**Branch**: `001-cuentas-claras-mvp` | **Date**: 2026-06-04 | **Spec**: `specs/001-cuentas-claras-mvp/spec.md`

**Input**: Feature specification from `specs/001-cuentas-claras-mvp/spec.md`

## Summary

Cuentas Claras es una aplicación de gestión de finanzas personales y familiares compuesta por un backend REST API en Flask/Python y un frontend multiplataforma en Flutter/Dart. El sistema permite a usuarios autenticados (local y Google OAuth) registrar transacciones de ingresos/gastos multi-moneda, organizarlas por categorías, visualizar resúmenes mensuales con gráficos, gestionar cuentas de ahorro, y compartir la gestión financiera con miembros del hogar mediante un sistema de roles jerárquico.

## Technical Context

**Language/Version**: Python 3.14 (backend), Dart 3.8+ / Flutter (frontend)

**Primary Dependencies**:
- Backend: Flask 3.1.1, Flask-SQLAlchemy 3.1.1, Flask-CORS 5.0.1, PyJWT 2.10.1, bcrypt 4.2.0, google-auth 2.38.0, python-dotenv 1.1.0, ezodf, lxml
- Frontend: Flutter SDK, provider 6.1.0, http 1.2.0, fl_chart 0.70.0, intl 0.20.0, google_identity_services_web 0.3.3

**Storage**: SQLite (archivo local `cuentas_claras.db`) via SQLAlchemy ORM

**Testing**: pytest (backend), flutter_test (frontend)

**Target Platform**: Web (Flutter Web), Android, iOS, Linux desktop; Backend en cualquier servidor Linux/macOS

**Project Type**: Web application (backend API + frontend SPA/mobile)

**Performance Goals**: < 2s respuesta para resúmenes mensuales, < 500ms para CRUD básico

**Constraints**: Offline capability fuera de scope MVP. < 100 usuarios concurrentes. SQLite como DB.

**Scale/Scope**: < 100 usuarios, ~10k transacciones/año por household, 2 plataformas (web + mobile)

## Constitution Check

| Principio | Estado | Notas |
|---|---|---|
| I. Arquitectura Cliente-Servidor | ✅ PASS | Backend y frontend separados, comunicación via REST JSON |
| II. Seguridad por Diseño | ⚠️ PARCIAL | JWT implementado. Secrets hardcodeados como defaults (aceptable dev). Falta `.env` file. |
| III. Calidad de Código | ⚠️ PARCIAL | Logging implementado en auth/households. Falta en savings/categories/transactions. Sin linter configurado. |
| IV. Multi-Moneda | ✅ PASS | Transacciones y ahorros soportan campo `currency`. Conversión a ARS en savings. |
| V. Household-First | ✅ PASS | Todos los recursos filtran por household_id. Permisos RBAC implementados. |
| VI. Simplicidad | ✅ PASS | SQLite, sin abstracciones innecesarias, Flask directo. |

## Project Structure

### Documentation (this feature)

```text
specs/001-cuentas-claras-mvp/
├── spec.md              # Especificación funcional
├── plan.md              # Este archivo
└── tasks.md             # Lista de tareas
```

### Source Code (repository root)

```text
cuentas-claras/
├── backend/
│   ├── app/
│   │   ├── __init__.py          # Flask app factory, blueprints registration
│   │   ├── auth/
│   │   │   └── permissions.py   # RBAC: role hierarchy, household_access decorator
│   │   ├── models/
│   │   │   ├── __init__.py      # Model exports
│   │   │   ├── user.py          # User model (bcrypt, to_dict)
│   │   │   ├── category.py      # Category model (type enum)
│   │   │   ├── transaction.py   # Transaction model (multi-currency)
│   │   │   ├── monthly_budget.py # MonthlyBudget model
│   │   │   ├── saving.py        # SavingAccount + Saving models
│   │   │   └── household.py     # Household + HouseholdMember + Invitation
│   │   └── routes/
│   │       ├── auth.py          # Auth endpoints + JWT + Google OAuth
│   │       ├── categories.py    # Category CRUD
│   │       ├── transactions.py  # Transaction CRUD + filters
│   │       ├── monthly.py       # Monthly summary aggregations
│   │       ├── savings.py       # Savings accounts + balances + summary
│   │       └── households.py    # Household CRUD + members + invitations
│   ├── scripts/
│   │   ├── import_ods.py        # Import from ODS spreadsheet
│   │   ├── migrate_to_households.py  # Migration script
│   │   ├── reset_db.py          # DB reset utility
│   │   └── seed.py              # Data seeding
│   ├── config.py                # Flask config (secrets, DB URI, JWT expiry)
│   ├── run.py                   # Entry point with logging middleware
│   ├── requirements.txt         # Python dependencies
│   └── cuentas_claras.db        # SQLite database file
│
└── frontend/
    ├── lib/
    │   ├── main.dart            # App entry, MultiProvider, AuthGate
    │   ├── config/
    │   │   ├── api_config.dart   # Backend URL + Google Client ID
    │   │   ├── currencies.dart   # Currency definitions
    │   │   └── theme.dart        # Light/dark theme definitions
    │   ├── models/
    │   │   ├── user.dart         # User model
    │   │   ├── category.dart     # Category model
    │   │   ├── transaction.dart  # Transaction model
    │   │   ├── monthly_summary.dart  # Monthly summary model
    │   │   └── saving.dart       # Saving model
    │   ├── providers/
    │   │   ├── auth_provider.dart     # Auth state management
    │   │   ├── data_provider.dart     # Data fetching/caching
    │   │   └── theme_provider.dart    # Theme switching
    │   ├── services/
    │   │   ├── api_service.dart       # HTTP client for backend API
    │   │   └── logger_service.dart    # Debug logging service
    │   ├── screens/
    │   │   ├── login_screen.dart      # Login/register screen
    │   │   ├── home_screen.dart       # Main navigation
    │   │   ├── dashboard_screen.dart  # Monthly overview + charts
    │   │   ├── transactions_screen.dart   # Transaction list + filters
    │   │   ├── add_transaction_screen.dart # Transaction form
    │   │   ├── categories_screen.dart     # Category management
    │   │   ├── savings_screen.dart        # Savings management
    │   │   ├── household_screen.dart      # Household + members
    │   │   └── profile_screen.dart        # User profile editing
    │   └── widgets/
    │       └── debug_overlay.dart    # Debug info overlay
    ├── pubspec.yaml             # Dart/Flutter dependencies
    └── analysis_options.yaml    # Dart linting rules
```

**Structure Decision**: Estructura web app (backend + frontend) ya establecida y funcional. No requiere cambios estructurales.

## Complexity Tracking

> No hay violaciones de la constitución que requieran justificación.

| Aspecto | Decisión | Justificación |
|---------|----------|---------------|
| SQLite en producción | Aceptado | Volumen < 100 usuarios, simplicidad operativa |
| JWT 90 días expiración | Aceptado para MVP | UX-first: evita re-login frecuente. Revisar en v2. |
| Sin email verification flow | Pendiente | Campo existe en modelo, lógica no implementada |
| Sin rate limiting | Pendiente | Bajo riesgo con < 100 usuarios |
