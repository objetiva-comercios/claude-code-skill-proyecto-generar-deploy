#!/bin/bash
# =============================================================================
# generar-deploy — Instalador automatico de skill para Claude Code
# =============================================================================
# Uso:
#   curl -sL https://raw.githubusercontent.com/objetiva-comercios/claude-code-skill-proyecto-generar-deploy/main/install.sh | bash
#
# O desde el repo clonado:
#   bash install.sh
#
# Que hace:
#   1. Verifica que git este instalado
#   2. Clona el repositorio (o actualiza si ya existe)
#   3. Copia SKILL.md a ~/.claude/skills/generar-deploy/
#   4. Verifica la instalacion
#
# Requisitos:
#   - git
#   - Claude Code instalado (~/.claude/ debe existir)
# =============================================================================

set -euo pipefail

# -- Config ------------------------------------------------------------------
SKILL_NAME="generar-deploy"
INSTALL_DIR="${HOME}/.claude/skills/${SKILL_NAME}"
REPO_URL="https://github.com/objetiva-comercios/claude-code-skill-proyecto-generar-deploy.git"
TEMP_DIR=$(mktemp -d)

# -- Colores -----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# -- Banner ------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  generar-deploy — Instalador de Skill"
echo "=========================================="
echo ""

# -- Verificar dependencias --------------------------------------------------
info "Verificando dependencias..."

command -v git >/dev/null 2>&1 || error "git no esta instalado. Instalar con: sudo apt install git"
ok "git encontrado"

if [ ! -d "${HOME}/.claude" ]; then
  error "No se encontro ~/.claude/ — Claude Code no parece estar instalado. Instalar desde https://claude.com/claude-code"
fi
ok "Claude Code detectado"

# -- Cleanup al salir --------------------------------------------------------
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

# -- Clonar repositorio temporalmente ----------------------------------------
info "Descargando skill desde GitHub..."
git clone --quiet --depth 1 "$REPO_URL" "$TEMP_DIR/repo" || error "No se pudo clonar el repositorio"
ok "Repositorio descargado"

# -- Verificar que SKILL.md existe en el repo --------------------------------
if [ ! -f "$TEMP_DIR/repo/SKILL.md" ]; then
  error "No se encontro SKILL.md en el repositorio"
fi

# -- Limpiar carpetas mal nombradas (de git clone directo) -------------------
WRONG_DIR="${HOME}/.claude/skills/claude-code-skill-proyecto-generar-deploy"
if [ -d "$WRONG_DIR" ]; then
  warn "Detectada carpeta mal nombrada: $(basename "$WRONG_DIR")"
  warn "Eliminando para usar el nombre correcto: ${SKILL_NAME}"
  rm -rf "$WRONG_DIR"
  ok "Carpeta incorrecta eliminada"
fi

# -- Instalar skill ----------------------------------------------------------
info "Instalando skill en ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
cp "$TEMP_DIR/repo/SKILL.md" "$INSTALL_DIR/SKILL.md"
ok "SKILL.md copiado a ${INSTALL_DIR}/"

# -- Verificar instalacion ---------------------------------------------------
if [ -f "${INSTALL_DIR}/SKILL.md" ]; then
  ok "Skill '${SKILL_NAME}' instalada correctamente"
else
  error "La verificacion fallo — SKILL.md no se encuentra en ${INSTALL_DIR}/"
fi

# -- Resultado ---------------------------------------------------------------
echo ""
echo "=========================================="
echo "  Instalacion completada"
echo "=========================================="
echo ""
info "Skill instalada en: ${INSTALL_DIR}/SKILL.md"
info "Para usarla, abri Claude Code en cualquier proyecto y escribi:"
echo ""
echo "    /generar-deploy"
echo ""
info "O con lenguaje natural: \"genera el deploy\", \"haceme el install.sh\", etc."
echo ""
