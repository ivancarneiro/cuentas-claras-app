#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/cuentas-claras/backend"
FRONTEND_DIR="$SCRIPT_DIR/cuentas-claras/frontend"

echo "======================================================"
echo "🚀 Iniciando Cuentas Claras en entorno local"
echo "======================================================"

# 1. Iniciar Backend (Flask)
echo "📦 Iniciando Backend Flask en http://localhost:5000..."
cd "$BACKEND_DIR"
uv run python run.py &
BACKEND_PID=$!

# Trap para matar los procesos al presionar Ctrl+C
trap 'echo ""; echo "🛑 Deteniendo servidores..."; kill $BACKEND_PID 2>/dev/null || true; exit 0' INT TERM EXIT

sleep 2

# 2. Iniciar Frontend Web (Build estático)
echo "🌐 Iniciando Frontend Web en http://localhost:8080..."
cd "$FRONTEND_DIR/build/web"
python3 -m http.server 8080
