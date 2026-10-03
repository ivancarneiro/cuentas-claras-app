# Cuentas Claras 💵
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/ivancarneiro/cuentas-claras-app/)
Aplicación multiplataforma moderna para la gestión de finanzas personales y familiares, diseñada desde la base para soportar la administración colaborativa de gastos compartidos en el hogar, control de ahorros y soporte multi-moneda (ARS / USD).

* 📦 **Releases y APKs Android**: [GitHub Releases](https://github.com/ivancarneiro/cuentas-claras-app/releases)


---

## 🚀 Características Principales

* **Gestión Multi-Grupo Familiar**: Creá y administrá distintos grupos (ej. *Casa*, *Oficina*), con roles independientes (*Propietario*, *Admin*, *Editar*, *Solo lectura*).
* **Invitaciones Seguras con TTL de 48hs**: Sistema de invitación por correo y enlace tokenizado, con vencimiento estricto a las 48 horas y renovación automática.
* **Seguimiento de Gastos e Ingresos**: Clasificación por categorías fijas y variables, desglose mensual y visualización gráfica interactiva.
* **Ahorro Mensual Automático**: Cálculo automático del total de ahorros del período y balance financiero consolidado.
* **Autenticación Híbrida**: Inicio de sesión clásico con contraseña o mediante **Google Sign-In** (Web y Android nativo), protegido con lista blanca de acceso dinámico.
* **Multi-Plataforma**: PWA / Web optimizada y aplicación nativa compilada para Android (APK).

---

## 📂 Estructura del Proyecto

* **`cuentas-claras/backend/`**: API REST en Python (Flask 3.x, SQLAlchemy, JWT, Google Auth) con soporte para SQLite local y Neon PostgreSQL en producción.
* **`cuentas-claras/frontend/`**: Aplicación Flutter (Dart 3.8+) con Provider, diseño responsivo, soporte de modo oscuro/claro y compilación Web/Android.
* **`public/`**: Build optimizado de Flutter Web desplegado automáticamente en Vercel.
* **`.github/workflows/`**: Pipelines de integración continua y compilación automatizada de APKs para Android al publicar tags de versión (`v*`).

---

## 📋 Requisitos Previos

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22 o superior).
* [Python](https://www.python.org/downloads/) (3.11 a 3.14).
* [uv](https://docs.astral.sh/uv/) (recomendado para gestión ultrarrápida del entorno virtual de Python) o `pip`.
* Cuenta en [Google Cloud Console](https://console.cloud.google.com/) para configurar la autenticación OAuth.

---

## 🛠️ Configuración y Ejecución del Backend

1. **Navegá al directorio del backend**:
   ```bash
   cd cuentas-claras/backend
   ```

2. **Instalá las dependencias**:
   ```bash
   uv sync
   # o alternativamente: python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
   ```

3. **Variables de entorno (`.env`)**:
   Copiá `.env.example` para crear tu `.env`:
   ```bash
   cp .env.example .env
   ```
   Completá las variables clave:
   ```env
   SECRET_KEY=clave_secreta_super_segura_para_firmar_jwt
   GOOGLE_CLIENT_ID=tu_google_client_id_web.apps.googleusercontent.com
   DATABASE_URL=sqlite:///cuentas_claras.db # O tu connection string de Neon PostgreSQL
   APP_OWNER_EMAIL=tu_correo@gmail.com
   ```

4. **Iniciá el servidor en desarrollo**:
   ```bash
   uv run python run.py
   ```
   El backend correrá en `http://localhost:5000`.

5. **Correr los tests**:
   ```bash
   uv run pytest
   ```

---

## 📱 Configuración y Ejecución del Frontend

1. **Navegá al directorio del frontend**:
   ```bash
   cd cuentas-claras/frontend
   ```

2. **Instalá las dependencias**:
   ```bash
   flutter pub get
   ```

3. **Ejecución local**:
   * **Web**:
     ```bash
     flutter run -d chrome
     ```
   * **Android (Emulador o Dispositivo)**:
     ```bash
     flutter run
     ```

4. **Compilar para Producción**:
   * **Web**:
     ```bash
     flutter build web --release --output ../../public/
     ```
   * **Android APK**:
     ```bash
     flutter build apk --release
     ```

---

## 🔐 Configuración de Google Sign-In (Web y Android)

Para que el inicio de sesión con Google funcione correctamente tanto en la versión Web como en la aplicación móvil de Android, es necesario configurar las credenciales OAuth en el **mismo proyecto** de [Google Cloud Console](https://console.cloud.google.com/).

### 1. Crear el Proyecto y Configurar la Pantalla de Consentimiento
1. En Google Cloud Console, creá un nuevo proyecto (ej. `Cuentas Claras`).
2. Dirigite a **APIs & Services (APIs y servicios)** > **OAuth consent screen (Pantalla de consentimiento)**.
3. Seleccioná el tipo de usuario **External (Externo)** y completá el nombre de la app, correo de soporte y correos de contacto del desarrollador.
4. En **Scopes (Permisos)**, agregá `email`, `profile` y `openid`.
5. Si la app está en estado *Testing*, agregá los correos de prueba en la lista de usuarios de prueba.

---

### 2. Crear el Client ID para Web (Backend y Clientes Web)
El Client ID Web se utiliza para el frontend Web y, de forma crucial, actúa como el `serverClientId` necesario para que el backend valide los tokens de Google (tanto los provenientes de navegadores como los generados en Android).

1. Andá a **APIs & Services** > **Credentials (Credenciales)**.
2. Hacé clic en **+ Create Credentials (+ Crear credenciales)** > **OAuth client ID (ID de cliente de OAuth)**.
3. Seleccioná tipo de aplicación: **Web application (Aplicación web)**.
4. Configurá los **Authorized JavaScript origins (Orígenes autorizados de JavaScript)**:
   * Entorno local: `http://localhost:5000` y `http://localhost:<puerto>` (puerto local de Flutter Web).
   * Entorno de producción (si se publica en la web): `https://tu-dominio-o-servidor.com` (la URL pública o dominio donde esté desplegada tu app).
5. En **Authorized redirect URIs (URIs de redireccionamiento autorizados)**:
   * La URL pública de tu app web: `https://tu-dominio-o-servidor.com`.
6. Guardá y copiá el **Client ID** generado:
   * Colocalo en el `.env` del backend: `GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com`.
   * Colocalo en `cuentas-claras/frontend/lib/config/api_config.dart` en la constante `googleClientId`.

> [!TIP]
> **Recomendación para publicación en Android**:
> Si vas a distribuir y utilizar la aplicación principalmente en **Android** (mediante el archivo APK descargable o a través de Google Play), este Client ID Web sigue siendo necesario para configurar el `GOOGLE_CLIENT_ID` del backend y el `serverClientId` del cliente Flutter. Sin embargo, no hace falta configurar dominios de producción en los orígenes de JavaScript, ya que en Android la autenticación corre nativamente a través de Google Play Services con la credencial de Android detallada en el paso siguiente.


---

### 3. Crear el Client ID para Android
Para que los dispositivos Android puedan usar el selector nativo de cuentas de Google:

1. En la misma sección de **Credentials**, hacé clic en **+ Create Credentials** > **OAuth client ID**.
2. Seleccioná tipo de aplicación: **Android**.
3. **Package name (Nombre del paquete)**:
   Debe coincidir exactamente con el `applicationId` configurado en `android/app/build.gradle.kts`:
   ```
   com.cuentasclaras.cuentas_claras_app
   ```
4. **SHA-1 certificate fingerprint (Huella digital del certificado SHA-1)**:
   Google necesita la huella digital del certificado con el que se firma la APK:

   * **Para Debug / Desarrollo Local**:
     Podés extraer el SHA-1 ejecutando en tu terminal:
     ```bash
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```
     O utilizando el keystore debug del proyecto:
     ```bash
     keytool -list -v -keystore cuentas-claras/frontend/android/app/debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```
   * **Para Release / Producción**:
     Extraé el SHA-1 de tu keystore de producción (o el de GitHub Actions si compilás en CI/CD):
     ```bash
     keytool -list -v -keystore /ruta/a/tu/upload-keystore.jks -alias tu-alias
     ```
5. Pegá el valor SHA-1 (con formato `AA:BB:CC:...`) en Google Cloud Console y guardá.

> [!NOTE]
> **¿Cómo se conectan Android y el Backend?**
> En Android, la app se autentica con Google de forma nativa utilizando la huella SHA-1 registrada y le solicita a Google un `idToken` para el **Web Client ID** (`serverClientId`). Luego envía ese `idToken` a `/api/auth/google-login`, donde el backend lo valida de forma segura contra Google. Por eso es indispensable que ambos Client IDs estén en el **mismo proyecto de Google Cloud**.

---

## 📦 Despliegue y CI/CD

### 1. Despliegue Web y Backend (Agnóstico con recomendación de Vercel)
La arquitectura desacoplada de la aplicación permite desplegarla en prácticamente cualquier infraestructura:

* **Frontend Web (Estático)**: Al compilar Flutter Web (`flutter build web --release --output public/`), se genera un conjunto de archivos estáticos (HTML, JS, WASM y assets) que pueden alojarse en cualquier servidor web o CDN (como Nginx, Cloudflare Pages, AWS S3/CloudFront, GitHub Pages o Vercel).
* **Backend API (Python/Flask)**: Puede ejecutarse mediante cualquier servidor WSGI de producción (Gunicorn, uWSGI), contenedor Docker o plataformas PaaS/Serverless (Railway, Render, Fly.io, AWS Lambda o Vercel).

> [!TIP]
> **Plataforma recomendada: Vercel**
> Este repositorio incluye una configuración lista para desplegar frontend y backend juntos sin necesidad de administrar servidores:
> * La carpeta `public/` sirve el cliente Flutter Web de forma estática con caché global.
> * El archivo `api/index.py` ejecuta el backend Flask como Serverless Functions.
> * Cada `push` a las ramas `main` o `staging` dispara un despliegue automático con URLs de vista previa y producción instantáneas.

---

### 2. Compilación y Publicación Móvil (Android con GitHub Actions)
Para generar y distribuir una nueva versión oficial de la aplicación móvil para Android:
1. Asegurate de que la versión esté actualizada en `cuentas-claras/frontend/pubspec.yaml` (ej. `1.0.5+6`).
2. Creá y subí un tag de versión:
   ```bash
   git tag v1.0.5
   git push origin v1.0.5
   ```
3. El workflow automatizado `.github/workflows/build-apk.yml` compilará la versión release en un entorno limpio de Ubuntu y publicará el archivo `.apk` directamente en los Releases de GitHub, disponible para descarga directa o mediante la función de auto-actualización de la app.


---

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Consultá el archivo `LICENSE` para más información.
