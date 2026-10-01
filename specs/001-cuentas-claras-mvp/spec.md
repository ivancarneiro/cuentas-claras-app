**Feature Branch**: `001-cuentas-claras-mvp`

**Created**: 2026-06-04

**Status**: Implemented

**Input**: User description: "Aplicación de gestión de finanzas personales y familiares. Permite a usuarios registrarse, autenticarse (local y Google), gestionar transacciones de ingresos y gastos con categorías, visualizar resúmenes mensuales con gráficos, gestionar cuentas de ahorro multi-moneda, y compartir la gestión financiera con otros miembros del hogar mediante un sistema de roles."

### User Story 1 - Autenticación de Usuario (Priority: P1)
Como usuario quiero poder registrarme e iniciar sesión en la aplicación para acceder a mis datos financieros de forma segura. El sistema soporta registro local (email/contraseña) y login con Google. Una vez autenticado, puedo ver y editar mi perfil (nombre, foto, iniciales).

**Why this priority**: Sin autenticación no hay acceso al sistema. Es el prerequisito absoluto para todas las demás funcionalidades.

**Independent Test**: Registrar un usuario, hacer login, verificar que el token JWT permite acceder a `/api/auth/me`, y que sin token se recibe 401.

**Acceptance Scenarios**:

1. **Given** un usuario no registrado, **When** envía POST `/api/auth/register` con name, email y password, **Then** recibe un JWT token y datos del usuario con status 201.
2. **Given** un usuario registrado, **When** envía POST `/api/auth/login` con email y password correctos, **Then** recibe un JWT token y datos del usuario.
3. **Given** un usuario con cuenta Google, **When** envía POST `/api/auth/google-login` con un idToken válido de Google, **Then** se crea o actualiza el usuario y recibe un JWT token.
4. **Given** un token JWT válido, **When** envía GET `/api/auth/me`, **Then** recibe los datos del usuario autenticado.
5. **Given** un token JWT expirado o inválido, **When** intenta acceder a un endpoint protegido, **Then** recibe error 401.

---

### User Story 2 - Gestión de Categorías (Priority: P1)
Como usuario quiero crear, editar y eliminar categorías para organizar mis transacciones. Las categorías tienen un tipo (income, fixed_expense, variable_expense, savings), un ícono opcional y un orden de visualización. Las categorías pertenecen a un household.

**Why this priority**: Las categorías son requeridas para crear transacciones. Sin ellas, la funcionalidad core no funciona.

**Independent Test**: Crear una categoría de tipo "variable_expense", listar categorías filtrando por tipo, editarla, y eliminarla.

**Acceptance Scenarios**:

1. **Given** un usuario autenticado con household, **When** envía POST `/api/categories` con name="Supermercado" y type="variable_expense", **Then** la categoría se crea con status 201 y se auto-asigna al household del usuario.
2. **Given** categorías existentes, **When** envía GET `/api/categories?type=income`, **Then** recibe sólo las categorías de tipo income del household.
3. **Given** un tipo inválido, **When** intenta crear una categoría con type="invalid", **Then** recibe error 400.

---

### User Story 3 - Registro y Gestión de Transacciones (Priority: P1)
Como usuario quiero registrar mis ingresos y gastos diarios con fecha, monto, categoría, descripción, moneda y tipo (ingreso/gasto). Quiero poder marcar gastos como fijos. Quiero filtrar transacciones por mes, año, tipo, categoría y si es fijo.

**Why this priority**: Es la funcionalidad core de la aplicación. Registrar transacciones es la acción principal del usuario.

**Independent Test**: Crear una transacción de gasto de $5000 ARS en categoría "Supermercado", listarla filtrando por mes actual, editarla cambiando el monto, y eliminarla.

**Acceptance Scenarios**:

1. **Given** un usuario autenticado, **When** envía POST `/api/transactions` con user_id, category_id, date, amount=5000, type="expense", currency="ARS", **Then** la transacción se crea con status 201.
2. **Given** transacciones existentes, **When** envía GET `/api/transactions?month=6&year=2026&type=expense`, **Then** recibe sólo gastos de junio 2026.
3. **Given** una transacción de otro household, **When** intenta editarla, **Then** recibe error 403.
4. **Given** falta el campo amount, **When** intenta crear una transacción, **Then** recibe error 400.

---

### User Story 4 - Resumen Mensual y Dashboard (Priority: P2)
Como usuario quiero ver un resumen mensual de mis finanzas: total de ingresos, total de gastos (fijos y variables), ahorro del mes, desglose por categoría con gráficos, y desglose por miembro del household.

**Why this priority**: Visualizar datos es el segundo paso natural después de registrarlos. Sin embargo, la app funciona sin esta vista.

**Independent Test**: Con transacciones cargadas para un mes, consultar el resumen y verificar que los totales son correctos y el desglose por categoría coincide.

**Acceptance Scenarios**:

1. **Given** transacciones de junio 2026, **When** envía GET `/api/monthly/summary?month=6&year=2026`, **Then** recibe total_income, total_expenses, fixed_expenses, variable_expenses, savings, expenses_by_category, income_by_category, expenses_by_user, income_by_user.
2. **Given** no hay transacciones para un mes, **When** consulta el resumen, **Then** todos los totales son 0 y los arrays de desglose están vacíos.
3. **Given** faltan parámetros month o year, **When** consulta el resumen, **Then** recibe error 400.

---

### User Story 5 - Gestión de Ahorros Multi-Moneda (Priority: P2)
Como usuario quiero gestionar mis cuentas de ahorro (ej: "U$D Naranja X", "BullMarket", "Sobró 2025"). Cada cuenta tiene una moneda base. Quiero registrar balances mensuales con valor en moneda original y opcionalmente en ARS. Quiero ver un resumen con el último balance de cada cuenta y el total en ARS.

**Why this priority**: Funcionalidad complementaria importante pero no bloqueante para el uso diario.

**Independent Test**: Crear una cuenta de ahorro en USD, registrar un balance de $1000 USD para junio 2026 con balance_ars=950000, consultar el resumen y verificar totales.

**Acceptance Scenarios**:

1. **Given** un usuario autenticado, **When** crea una cuenta de ahorro con name="U$D NX" y currency="USD", **Then** se crea con status 201.
2. **Given** una cuenta de ahorro existente, **When** registra un balance de month=6, year=2026, balance=1000, balance_ars=950000, **Then** el balance se crea con status 201.
3. **Given** múltiples cuentas con balances, **When** consulta GET `/api/savings/summary`, **Then** recibe el último balance por cuenta y total_ars sumado.
4. **Given** se elimina una cuenta, **When** se confirma la eliminación, **Then** también se eliminan todos los balances asociados.

---

### User Story 6 - Households y Gestión Familiar (Priority: P2)
Como usuario quiero crear un grupo familiar (household), invitar a otros usuarios por email, y gestionar sus roles (owner/admin/edit/read). Los miembros comparten transacciones, categorías y ahorros dentro del household.

**Why this priority**: Habilita la gestión compartida pero la app funciona para un usuario individual sin esta feature.

**Independent Test**: Crear un household, invitar a un usuario por email, aceptar la invitación con el usuario invitado, verificar que ambos ven las mismas transacciones.

**Acceptance Scenarios**:

1. **Given** un usuario autenticado, **When** crea un household con name="Casa", **Then** se crea con status 201 y el usuario es "owner".
2. **Given** un admin del household, **When** invita a user@email.com con role="edit", **Then** se crea una invitación con token único y expiración de 7 días.
3. **Given** una invitación pendiente, **When** el invitado acepta con POST `/api/households/invitations/{token}/accept`, **Then** se agrega como miembro con el rol asignado.
4. **Given** un miembro con role="read", **When** intenta crear una transacción, **Then** tiene acceso de lectura pero no puede modificar (dependiendo de la implementación actual del endpoint).
5. **Given** un admin, **When** intenta remover al owner, **Then** recibe error 403.

---

### Edge Cases

- ¿Qué pasa si un usuario Google no tiene cuenta y se registra? → Se crea automáticamente con password aleatorio.
- ¿Qué pasa si se elimina una categoría que tiene transacciones asociadas? → SQLAlchemy lanza error de FK (no hay cascade delete).
- ¿Qué pasa si un usuario no pertenece a ningún household? → Recibe 403 en endpoints que requieren contexto de household.
- ¿Qué pasa si una invitación expiró? → Se retorna error 410 Gone.
- ¿Qué pasa si se invita a un email que ya es miembro? → Se retorna error 409 Conflict.
- ¿Qué pasa con montos negativos? → No hay validación actualmente. Debería rechazarse.
- ¿Qué pasa si el Google Client ID está mal configurado? → La verificación del token falla con 401.

### Functional Requirements

- **FR-001**: El sistema DEBE permitir registro local con email, nombre y contraseña.
- **FR-002**: El sistema DEBE permitir login con Google OAuth2 via ID token.
- **FR-003**: El sistema DEBE generar tokens JWT con expiración configurable (default 90 días).
- **FR-004**: El sistema DEBE proteger todos los endpoints con autenticación JWT excepto health, login, register, google-login.
- **FR-005**: El sistema DEBE soportar CRUD completo de categorías con tipos: income, fixed_expense, variable_expense, savings.
- **FR-006**: El sistema DEBE soportar CRUD completo de transacciones con filtros por mes, año, tipo, categoría, usuario, is_fixed.
- **FR-007**: El sistema DEBE soportar monedas múltiples (ARS, USD, BRL, BTC, etc.) en transacciones y ahorros.
- **FR-008**: El sistema DEBE calcular resúmenes mensuales con total de ingresos, gastos fijos, gastos variables, ahorro, y desglose por categoría y usuario.
- **FR-009**: El sistema DEBE soportar cuentas de ahorro con balances mensuales y resumen con totalización en ARS.
- **FR-010**: El sistema DEBE soportar households con roles jerárquicos (owner > admin > edit > read).
- **FR-011**: El sistema DEBE soportar invitaciones por email con token único y expiración de 7 días.
- **FR-012**: El sistema DEBE auto-asignar household a recursos cuando no se especifica explícitamente.
- **FR-013**: El sistema DEBE registrar logs estructurados de todas las operaciones de autenticación.
- **FR-014**: El sistema DEBE servir un endpoint de health check en `/api/health`.
- **FR-015**: El frontend DEBE soportar temas claro y oscuro.
- **FR-016**: El frontend DEBE soportar localización en español (AR) e inglés (US).
- **FR-017**: El frontend DEBE mostrar gráficos de distribución de gastos por categoría.
- **FR-018**: El sistema DEBE validar que el tipo de transacción sea "income" o "expense".
- **FR-019**: El sistema DEBE validar formato de fecha YYYY-MM-DD en transacciones.
- **FR-020**: El sistema DEBE prevenir que un owner sea removido de su household.

### Key Entities

- **User**: Representa un usuario registrado. Atributos: name, email, password_hash, short_name, photo_url, email_verified. Relaciones: tiene muchas Transactions, pertenece a muchos Households via HouseholdMember.
- **Category**: Tipo de ingreso/gasto. Atributos: name, type, icon, sort_order. Pertenece a un User (creador) y a un Household.
- **Transaction**: Movimiento financiero. Atributos: date, amount, currency, type, description, is_fixed. Pertenece a un User, un Category y un Household.
- **MonthlyBudget**: Límite de presupuesto mensual por categoría. Atributos: month, year, limit_amount. Pertenece a un Category y un Household.
- **SavingAccount**: Cuenta/entidad de ahorro. Atributos: name, currency, description. Tiene muchos Savings.
- **Saving**: Balance mensual de una cuenta de ahorro. Atributos: month, year, balance, currency, balance_ars, note.
- **Household**: Grupo familiar/compartido. Atributos: name, created_by. Tiene muchos HouseholdMembers e Invitations.
- **HouseholdMember**: Membresía de usuario en household. Atributos: role, invited_by, accepted_at.
- **Invitation**: Invitación pendiente para unirse a un household. Atributos: invited_email, token, role, expires_at, accepted.

### Success Criteria

- **SC-001**: Un usuario puede completar el registro y login en menos de 30 segundos.
- **SC-002**: Un usuario puede agregar una transacción en menos de 15 segundos (3-4 campos).
- **SC-003**: El resumen mensual se carga en menos de 2 segundos.
- **SC-004**: La app funciona offline para consultar datos previamente cargados (futuro).
- **SC-005**: Dos o más usuarios de un household ven los mismos datos financieros en tiempo real.

### Assumptions

- Los usuarios tienen conectividad a internet para sincronizar con el backend.
- El soporte mobile offline es out of scope para el MVP.
- La autenticación existente con JWT + Google OAuth es suficiente para v1.
- SQLite es adecuado como base de datos para el volumen esperado (< 100 usuarios).
- Las conversiones de moneda a ARS se ingresan manualmente por el usuario.
