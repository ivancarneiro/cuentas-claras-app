---
description: "Task list for Cuentas Claras MVP implementation"
---

**Input**: Design documents from `specs/001-cuentas-claras-mvp/`

**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Tests**: Test tasks incluidos. La implementación actual no tiene tests automatizados — son tareas pendientes.

**Organization**: Tasks grouped by user story. Tasks already implemented are marked `[x]`.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Exact file paths included in descriptions

---

## Phase 1: Setup (Project Infrastructure)
**Purpose**: Project initialization and SDD framework setup

- [x] T001 Create project directory structure (`cuentas-claras/backend/`, `cuentas-claras/frontend/`)
- [x] T002 Initialize Flask backend with dependencies (`requirements.txt`)
- [x] T003 [P] Initialize Flutter frontend with dependencies (`pubspec.yaml`)
- [x] T004 [P] Configure Flask app factory pattern (`backend/app/__init__.py`)
- [x] T005 [P] Configure Flask CORS and SQLAlchemy (`backend/app/__init__.py`)
- [x] T006 Initialize git repository and `.gitignore`
- [x] T007 Initialize Spec-Driven Development with `specify init`
- [x] T008 [P] Create `.env` file for secrets management
- [x] T009 [P] Configure Python linting (flake8/ruff) and Dart linting (analysis_options.yaml)

---

## Phase 2: Foundational (Core Infrastructure)
**Purpose**: Core infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T010 Setup SQLAlchemy database with SQLite (`backend/config.py`)
- [x] T011 [P] Create User model with bcrypt password hashing (`backend/app/models/user.py`)
- [x] T012 [P] Implement JWT token generation and validation (`backend/app/routes/auth.py`)
- [x] T013 [P] Implement `login_required` decorator (`backend/app/routes/auth.py`)
- [x] T014 [P] Implement RBAC permission system (`backend/app/auth/permissions.py`)
- [x] T015 [P] Create health check endpoint (`backend/app/__init__.py`)
- [x] T016 [P] Configure request logging middleware (`backend/run.py`)
- [x] T017 [P] Setup Flutter MultiProvider with AuthProvider, DataProvider, ThemeProvider (`frontend/lib/main.dart`)
- [x] T018 [P] Create ApiService HTTP client (`frontend/lib/services/api_service.dart`)
- [x] T019 [P] Create LoggerService for debugging (`frontend/lib/services/logger_service.dart`)
- [x] T020 [P] Define theme system light/dark (`frontend/lib/config/theme.dart`)
- [x] T021 [P] Define currency configurations (`frontend/lib/config/currencies.dart`)

**Checkpoint**: Foundation ready — all models, auth, and frontend infrastructure operational

---

## Phase 3: User Story 1 — Autenticación de Usuario (Priority: P1) 🎯 MVP
**Goal**: Usuarios pueden registrarse, hacer login (local y Google), y gestionar su perfil.

**Independent Test**: Registro → Login → Token válido → Acceso a `/api/auth/me`

### Tests for User Story 1 ⚠️
- [x] T022 [P] [US1] Test de contrato para POST `/api/auth/register` en `backend/tests/contract/test_auth.py`
- [x] T023 [P] [US1] Test de contrato para POST `/api/auth/login` en `backend/tests/contract/test_auth.py`
- [x] T024 [P] [US1] Test de contrato para POST `/api/auth/google-login` en `backend/tests/contract/test_auth.py`
- [x] T025 [P] [US1] Test de contrato para GET `/api/auth/me` (con y sin token) en `backend/tests/contract/test_auth.py`
- [x] T026 [P] [US1] Test de widget para LoginScreen en `frontend/test/screens/login_screen_test.dart`

### Implementation for User Story 1
- [x] T027 [US1] Implement register endpoint POST `/api/auth/register` en `backend/app/routes/auth.py`
- [x] T028 [US1] Implement login endpoint POST `/api/auth/login` en `backend/app/routes/auth.py`
- [x] T029 [US1] Implement Google OAuth login POST `/api/auth/google-login` en `backend/app/routes/auth.py`
- [x] T030 [US1] Implement profile endpoints GET `/api/auth/me` y PUT `/api/auth/profile` en `backend/app/routes/auth.py`
- [x] T031 [US1] Create LoginScreen with Google Sign-In en `frontend/lib/screens/login_screen.dart`
- [x] T032 [US1] Create AuthProvider with token management en `frontend/lib/providers/auth_provider.dart`
- [x] T033 [US1] Create ProfileScreen en `frontend/lib/screens/profile_screen.dart`
- [x] T034 [US1] Implement AuthGate routing (login vs home) en `frontend/lib/main.dart`

**Checkpoint**: ✅ User Story 1 fully functional and independently testable

---

## Phase 4: User Story 2 — Gestión de Categorías (Priority: P1)
**Goal**: CRUD completo de categorías con tipos y filtros.

**Independent Test**: Crear categoría → Listar por tipo → Editar → Eliminar

### Tests for User Story 2 ⚠️
- [x] T035 [P] [US2] Test de contrato para CRUD `/api/categories` en `backend/tests/contract/test_categories.py`
- [x] T036 [P] [US2] Test de filtro por type en `backend/tests/contract/test_categories.py`

### Implementation for User Story 2
- [x] T037 [US2] Create Category model en `backend/app/models/category.py`
- [x] T038 [US2] Implement CRUD endpoints en `backend/app/routes/categories.py`
- [x] T039 [US2] Create Category Dart model en `frontend/lib/models/category.dart`
- [x] T040 [US2] Create CategoriesScreen en `frontend/lib/screens/categories_screen.dart`

**Checkpoint**: ✅ User Story 2 fully functional and independently testable

---

## Phase 5: User Story 3 — Registro y Gestión de Transacciones (Priority: P1) 🎯 MVP
**Goal**: CRUD de transacciones con filtros avanzados y soporte multi-moneda.

**Independent Test**: Crear transacción → Listar con filtros → Editar → Eliminar

### Tests for User Story 3 ⚠️
- [x] T041 [P] [US3] Test de contrato para CRUD `/api/transactions` en `backend/tests/contract/test_transactions.py`
- [x] T042 [P] [US3] Test de filtros (month, year, type, category_id, is_fixed) en `backend/tests/contract/test_transactions.py`
- [x] T043 [P] [US3] Test de validación (tipo inválido, fecha inválida, campos faltantes) en `backend/tests/contract/test_transactions.py`
- [x] T044 [P] [US3] Test de acceso cross-household (debe retornar 403) en `backend/tests/contract/test_transactions.py`

### Implementation for User Story 3
- [x] T045 [US3] Create Transaction model en `backend/app/models/transaction.py`
- [x] T046 [US3] Implement CRUD + filter endpoints en `backend/app/routes/transactions.py`
- [x] T047 [US3] Create Transaction Dart model en `frontend/lib/models/transaction.dart`
- [x] T048 [US3] Create TransactionsScreen with filters en `frontend/lib/screens/transactions_screen.dart`
- [x] T049 [US3] Create AddTransactionScreen form en `frontend/lib/screens/add_transaction_screen.dart`
- [x] T050 [US3] Implement DataProvider for transaction CRUD en `frontend/lib/providers/data_provider.dart`

**Checkpoint**: ✅ User Story 3 fully functional and independently testable

---

## Phase 6: User Story 4 — Resumen Mensual y Dashboard (Priority: P2)
**Goal**: Vista de resumen mensual con totales, desgloses y gráficos.

**Independent Test**: Con datos cargados, verificar que totales son correctos y gráficos se renderizan.

### Tests for User Story 4 ⚠️
- [x] T051 [P] [US4] Test de contrato para GET `/api/monthly/summary` en `backend/tests/contract/test_monthly.py`
- [x] T052 [P] [US4] Test con mes sin datos (todos 0) en `backend/tests/contract/test_monthly.py`
- [x] T053 [P] [US4] Test de parámetros faltantes (400) en `backend/tests/contract/test_monthly.py`

### Implementation for User Story 4
- [x] T054 [US4] Create MonthlyBudget model en `backend/app/models/monthly_budget.py`
- [x] T055 [US4] Implement monthly summary endpoint en `backend/app/routes/monthly.py`
- [x] T056 [US4] Create MonthlySummary Dart model en `frontend/lib/models/monthly_summary.dart`
- [x] T057 [US4] Create DashboardScreen with charts en `frontend/lib/screens/dashboard_screen.dart`

**Checkpoint**: ✅ User Story 4 fully functional and independently testable

---

## Phase 7: User Story 5 — Gestión de Ahorros Multi-Moneda (Priority: P2)
**Goal**: CRUD de cuentas de ahorro, balances mensuales, y resumen con totalización ARS.

**Independent Test**: Crear cuenta USD → Registrar balance → Consultar summary → Verificar total_ars

### Tests for User Story 5 ⚠️
- [x] T058 [P] [US5] Test de contrato para CRUD `/api/savings/accounts` en `backend/tests/contract/test_savings.py`
- [x] T059 [P] [US5] Test de contrato para CRUD `/api/savings` en `backend/tests/contract/test_savings.py`
- [x] T060 [P] [US5] Test de contrato para GET `/api/savings/summary` en `backend/tests/contract/test_savings.py`

### Implementation for User Story 5
- [x] T061 [US5] Create SavingAccount + Saving models en `backend/app/models/saving.py`
- [x] T062 [US5] Implement savings CRUD + summary endpoints en `backend/app/routes/savings.py`
- [x] T063 [US5] Create Saving Dart model en `frontend/lib/models/saving.dart`
- [x] T064 [US5] Create SavingsScreen en `frontend/lib/screens/savings_screen.dart`

**Checkpoint**: ✅ User Story 5 fully functional and independently testable

---

## Phase 8: User Story 6 — Households y Gestión Familiar (Priority: P2)
**Goal**: Households con roles, invitaciones por email, y datos compartidos.

**Independent Test**: Crear household → Invitar user → Aceptar invitación → Verificar datos compartidos

### Tests for User Story 6 ⚠️
- [x] T065 [P] [US6] Test de contrato para CRUD `/api/households` en `backend/tests/contract/test_households.py`
- [x] T066 [P] [US6] Test de invitaciones (crear, aceptar, declinar, expirar) en `backend/tests/contract/test_households.py`
- [x] T067 [P] [US6] Test de permisos RBAC (owner/admin/edit/read) en `backend/tests/contract/test_households.py`
- [x] T068 [P] [US6] Test de edge cases (remover owner, invitar existente) en `backend/tests/contract/test_households.py`

### Implementation for User Story 6
- [x] T069 [US6] Create Household + HouseholdMember + Invitation models en `backend/app/models/household.py`
- [x] T070 [US6] Implement household CRUD + members endpoints en `backend/app/routes/households.py`
- [x] T071 [US6] Implement invitation endpoints (create, accept, decline) en `backend/app/routes/households.py`
- [x] T072 [US6] Create HouseholdScreen en `frontend/lib/screens/household_screen.dart`

**Checkpoint**: ✅ User Story 6 fully functional and independently testable

---

## Phase 9: Polish & Hardening
**Purpose**: Mejoras que afectan múltiples user stories

- [x] T073 [P] Crear `.env.example` con todas las variables de entorno necesarias
- [x] T074 [P] Migrar secrets hardcodeados a `.env` en `backend/config.py`
- [x] T075 [P] Agregar validación de montos negativos en transacciones y ahorros
- [x] T076 [P] Agregar logging consistente en routes/categories.py, routes/transactions.py, routes/savings.py
- [x] T077 [P] Crear README.md del proyecto raíz con setup instructions
- [x] T078 [P] Agregar manejo de cascade delete para categorías con transacciones
- [x] T079 Configurar pytest y crear `backend/tests/conftest.py` con fixtures base
- [x] T080 [P] Configurar flutter_test y crear tests de widget básicos
- [x] T081 Security hardening: rate limiting en endpoints de auth
- [x] T082 [P] Documentar API endpoints (OpenAPI/Swagger o markdown)
- [ ] T083 Run quickstart.md validation

---

## Dependencies

### Phase Dependencies
- **Setup (Phase 1)**: No dependencies — parcialmente completado
- **Foundational (Phase 2)**: Depends on Setup — ✅ completado
- **User Stories (Phases 3-8)**: All depend on Foundational — ✅ implementación completada
- **Polish (Phase 9)**: Depends on all user stories — **PENDIENTE**

### User Story Dependencies
- **US1 Auth (P1)**: Ninguna dependencia — ✅ completado
- **US2 Categories (P1)**: Depende de US1 (auth) — ✅ completado
- **US3 Transactions (P1)**: Depende de US1 + US2 — ✅ completado
- **US4 Dashboard (P2)**: Depende de US3 (transactions exist) — ✅ completado
- **US5 Savings (P2)**: Depende de US1 (auth) — ✅ completado
- **US6 Households (P2)**: Depende de US1 (auth) — ✅ completado

### Within Each User Story
- Tests MUST be written and FAIL before new implementation
- Models before services
- Services before endpoints
- Core implementation before integration

### Parallel Opportunities
- All test tasks marked [P] can run in parallel
- All Phase 9 tasks marked [P] can run in parallel
- Tests for different user stories are fully independent

---

## Execution Strategy

### Current Status: MVP Implemented
The core implementation (Phases 1-8) is complete. Focus is now on:
1. Phase 9: Polish & Hardening
2. Writing automated tests (all test tasks T022-T068)
3. Security improvements (T073, T074, T081)

### Recommended Next Steps (Priority Order)
1. **T006, T007**: Initialize git + SDD framework
2. **T008, T073, T074**: Environment/secrets management
3. **T079**: Setup pytest infrastructure
4. **T022-T025**: Auth contract tests (highest value)
5. **T041-T044**: Transaction contract tests
6. **T075, T076**: Input validation + logging consistency
