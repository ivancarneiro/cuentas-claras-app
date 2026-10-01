# Referencia de API — Cuentas Claras

Esta documentación detalla los endpoints REST disponibles en la API de Cuentas Claras.

## 🔐 Autenticación

Todos los endpoints (excepto los de registro, login y health check) requieren un encabezado de autorización HTTP con el token JWT:

```http
Authorization: Bearer <tu_jwt_token>
```

---

## 1. Auth (`/api/auth`)

### Registro de Usuario
- **Endpoint**: `POST /api/auth/register`
- **Rate Limit**: 10 peticiones/minuto, 50/hora
- **Body**:
  ```json
  {
    "name": "Juan Pérez",
    "email": "juan@example.com",
    "password": "miPasswordSegura123",
    "short_name": "J"
  }
  ```
- **Respuesta (201 Created)**:
  ```json
  {
    "token": "eyJhbGci...",
    "user": {
      "id": 1,
      "name": "Juan Pérez",
      "email": "juan@example.com",
      "short_name": "J",
      "photo_url": null,
      "email_verified": false
    }
  }
  ```

### Inicio de Sesión Local
- **Endpoint**: `POST /api/auth/login`
- **Rate Limit**: 10 peticiones/minuto, 50/hora
- **Body**:
  ```json
  {
    "email": "juan@example.com",
    "password": "miPasswordSegura123"
  }
  ```
- **Respuesta (200 OK)**:
  ```json
  {
    "token": "eyJhbGci...",
    "user": { ... }
  }
  ```

### Inicio de Sesión con Google
- **Endpoint**: `POST /api/auth/google-login`
- **Rate Limit**: 10 peticiones/minuto, 50/hora
- **Body**:
  ```json
  {
    "idToken": "<Google_ID_Token_JWT>"
  }
  ```
- **Respuesta (200 OK)**:
  ```json
  {
    "token": "eyJhbGci...",
    "user": { ... }
  }
  ```

### Obtener Perfil Actual
- **Endpoint**: `GET /api/auth/me`
- **Requiere Auth**: Sí
- **Respuesta (200 OK)**: Datos del usuario autenticado.

### Actualizar Perfil
- **Endpoint**: `PUT /api/auth/profile`
- **Requiere Auth**: Sí
- **Body** (campos opcionales):
  ```json
  {
    "name": "Juan Carlos Pérez",
    "short_name": "JC",
    "photo_url": "https://example.com/avatar.jpg"
  }
  ```

---

## 2. Categorías (`/api/categories`)

### Listar Categorías
- **Endpoint**: `GET /api/categories`
- **Query Params**:
  - `type` *(opcional)*: `income` | `fixed_expense` | `variable_expense` | `savings`
- **Respuesta (200 OK)**: Lista de categorías del hogar del usuario y categorías del sistema.

### Crear Categoría
- **Endpoint**: `POST /api/categories`
- **Body**:
  ```json
  {
    "name": "Supermercado",
    "type": "variable_expense",
    "icon": "shopping_cart",
    "sort_order": 1,
    "household_id": 1
  }
  ```
- **Respuesta (201 Created)**: Objeto de categoría creada.

### Actualizar Categoría
- **Endpoint**: `PUT /api/categories/<id>`
- **Body**: Campos a actualizar (`name`, `type`, `icon`, `sort_order`).

### Eliminar Categoría
- **Endpoint**: `DELETE /api/categories/<id>`
- **Nota**: Si la categoría posee transacciones asociadas, retornará `400 Bad Request` con mensaje de advertencia para proteger la integridad histórica.

---

## 3. Transacciones (`/api/transactions`)

### Listar Transacciones
- **Endpoint**: `GET /api/transactions`
- **Query Params**:
  - `month` *(opcional)*: `1` a `12`
  - `year` *(opcional)*: e.g. `2026`
  - `type` *(opcional)*: `income` | `expense`
  - `category_id` *(opcional)*: ID de categoría
  - `is_fixed` *(opcional)*: `true` | `false`
  - `household_id` *(opcional)*: ID de household
- **Respuesta (200 OK)**: Lista de transacciones ordenadas por fecha descendente.

### Crear Transacción
- **Endpoint**: `POST /api/transactions`
- **Body**:
  ```json
  {
    "category_id": 2,
    "date": "2026-06-15",
    "amount": 15400.50,
    "type": "expense",
    "currency": "ARS",
    "is_fixed": false,
    "description": "Compra semanal de verdulería"
  }
  ```
- **Respuesta (201 Created)**: Transacción creada.

### Actualizar Transacción
- **Endpoint**: `PUT /api/transactions/<id>`
- **Body**: Campos a modificar (`amount`, `category_id`, `date`, `description`, etc.).

### Eliminar Transacción
- **Endpoint**: `DELETE /api/transactions/<id>`
- **Respuesta (200 OK)**: `{"message": "Transacción eliminada"}`

---

## 4. Resumen Mensual (`/api/monthly`)

### Consultar Resumen
- **Endpoint**: `GET /api/monthly/summary?month=6&year=2026`
- **Query Params obligatorios**: `month`, `year`
- **Respuesta (200 OK)**:
  ```json
  {
    "month": 6,
    "year": 2026,
    "total_income": 500000.0,
    "total_expenses": 200000.0,
    "fixed_expenses": 150000.0,
    "variable_expenses": 50000.0,
    "savings": 300000.0,
    "expenses_by_category": [
      { "id": 1, "name": "Alquiler", "icon": "home", "total": 150000.0, "count": 1 },
      { "id": 2, "name": "Supermercado", "icon": "cart", "total": 50000.0, "count": 3 }
    ],
    "income_by_category": [
      { "id": 3, "name": "Sueldo", "icon": "work", "total": 500000.0, "count": 1 }
    ],
    "expenses_by_user": [
      { "id": 1, "name": "Juan", "total": 200000.0 }
    ],
    "income_by_user": [
      { "id": 1, "name": "Juan", "total": 500000.0 }
    ]
  }
  ```

---

## 5. Ahorros (`/api/savings`)

### Cuentas de Ahorro
- `GET /api/savings/accounts`: Listar cuentas.
- `POST /api/savings/accounts`: Crear cuenta (`name`, `currency`, `description`).
- `PUT /api/savings/accounts/<id>`: Actualizar cuenta.
- `DELETE /api/savings/accounts/<id>`: Eliminar cuenta y sus balances asociados.

### Balances Mensuales
- `GET /api/savings?account_id=<id>&year=<year>`: Listar balances.
- `POST /api/savings`: Registrar balance (`account_id`, `month`, `year`, `balance`, `currency`, `balance_ars`, `note`).
- `PUT /api/savings/<id>`: Modificar balance.
- `DELETE /api/savings/<id>`: Eliminar balance.

### Resumen Consolidado de Ahorro
- `GET /api/savings/summary`: Devuelve el último balance de cada cuenta y el total consolidado en ARS.

---

## 6. Grupos Familiares / Households (`/api/households`)

### Gestión de Hogar
- `GET /api/households`: Listar hogares del usuario.
- `POST /api/households`: Crear hogar (`name`).
- `GET /api/households/<id>`: Obtener datos del hogar.
- `PUT /api/households/<id>`: Actualizar nombre del hogar (requiere rol `admin` u `owner`).

### Miembros y Roles
- `GET /api/households/<id>/members`: Listar miembros con sus roles (`owner`, `admin`, `edit`, `read`).
- `DELETE /api/households/<id>/members/<member_id>`: Eliminar miembro.
- `PUT /api/households/<id>/members/<member_id>/role`: Cambiar rol (solo `owner`).

### Invitaciones
- `POST /api/households/<id>/invite`: Crear invitación por email con rol sugerido (expira en 7 días).
- `GET /api/households/invitations/pending`: Listar invitaciones pendientes dirigidas al usuario actual.
- `POST /api/households/invitations/<token>/accept`: Aceptar invitación y unirse al hogar.
- `DELETE /api/households/invitations/<id>`: Rechazar / cancelar invitación.

---

## 7. Health Check (`/api/health`)

- **Endpoint**: `GET /api/health`
- **Auth**: Pública
- **Respuesta (200 OK)**:
  ```json
  {
    "status": "ok",
    "app": "Cuentas Claras"
  }
  ```
