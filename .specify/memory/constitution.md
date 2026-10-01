# Cuentas Claras — Constitution

## Core Principles

### I. Arquitectura Cliente-Servidor Clara
La aplicación mantiene una separación estricta entre backend (Flask/Python) y frontend (Flutter/Dart). Cada componente es independiente, se comunica exclusivamente via API REST JSON, y puede desarrollarse, testearse y desplegarse de forma autónoma. No se permiten dependencias directas entre capas — todo pasa por contratos HTTP documentados.

### II. Seguridad por Diseño
- Todos los secrets (JWT_SECRET, Google Client ID, DB credentials) se gestionan via variables de entorno o `.env`. **Nunca se hardcodean en código fuente** (los valores por defecto actuales son sólo para desarrollo local).
- Autenticación JWT obligatoria en todos los endpoints excepto `/api/health`, `/api/auth/login`, `/api/auth/register`, `/api/auth/google-login`.
- Control de acceso basado en roles (RBAC) para operaciones de household: `owner > admin > edit > read`.
- Validación de inputs en backend para todo dato del usuario. No confiar en validaciones del frontend.
- Google ID tokens se verifican contra el GOOGLE_CLIENT_ID configurado en cada request.

### III. Calidad de Código
- **Python**: Seguir PEP-8. Logging estructurado obligatorio con `logging` stdlib. Docstrings en funciones públicas.
- **Dart/Flutter**: Seguir las guías de `effective_dart`. Usar Provider para state management. Widgets `const` cuando sea posible.
- **Naming**: Modelos en singular (`User`, `Transaction`), tablas en plural (`users`, `transactions`). Endpoints en español para mensajes de error al usuario.
- Código auto-documentado preferido sobre comentarios redundantes. Los comentarios explican el *porqué*, no el *qué*.

### IV. Multi-Moneda como Ciudadano de Primera Clase
El sistema soporta múltiples monedas (ARS, USD, BRL, BTC, etc.) como requisito fundamental, no como feature secundario. Cada transacción y balance de ahorro lleva su moneda explícita. Las conversiones a ARS se almacenan opcionalmente para totalización.

### V. Household-First Data Model
Todos los datos financieros (transacciones, categorías, presupuestos, ahorros) pertenecen a un Household. Los usuarios acceden a datos a través de sus membresías de household. Esto habilita la gestión familiar compartida y el control de acceso granular.

### VI. Simplicidad y Pragmatismo (YAGNI)
- Empezar simple. SQLite para desarrollo y producción inicial. Migrar a PostgreSQL sólo cuando se demuestre necesidad.
- No agregar abstracciones (repository pattern, service layers complejos) hasta que la complejidad lo justifique.
- Priorizar features que el usuario final usa diariamente sobre infraestructura elegante.

## Estándares de Testing

- **Backend**: Tests con `pytest`. Mínimo: tests de contrato para cada endpoint de API.
- **Frontend**: Tests de widgets con `flutter_test`. Mínimo: tests de navegación y state management.
- **Regla**: Todo nuevo endpoint debe tener al menos un test de éxito y un test de error antes de merge.

## Estándares UX

- **Idioma**: Interfaz en español (Argentina). Mensajes de error en español.
- **Responsive**: La app Flutter soporta mobile y web.
- **Tema**: Soporte light/dark theme. Colores y tipografía definidos en `config/theme.dart`.
- **Feedback**: Toda operación debe dar feedback visual (loading states, success/error messages).

## Governance

- Esta constitución rige todas las decisiones técnicas y de diseño del proyecto.
- Cualquier cambio a estos principios requiere documentación explícita en el changelog y justificación escrita.
- Los PRs y reviews deben verificar cumplimiento con estos principios.

**Version**: 1.0.0 | **Ratified**: 2026-06-04 | **Last Amended**: 2026-06-04
