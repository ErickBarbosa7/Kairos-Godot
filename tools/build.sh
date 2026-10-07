#!/usr/bin/env bash
# Exporta Kairos Arcade a builds/ (ejecutable único con el paquete incrustado).
#
#   tools/build.sh [windows|linux|all]     (por defecto: all)
#
# Requiere Godot 4.7.2 y sus plantillas de exportación instaladas
# (Editor > Proyecto > Exportar > Administrar plantillas de exportación).
# Cambia GODOT si el ejecutable no está en el PATH:  GODOT=/ruta/godot tools/build.sh linux
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
TARGET="${1:-all}"
VERSION="$("$GODOT" --version | cut -d. -f1-3)"

case "$(uname -s)" in
  Linux)  TEMPLATES="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates" ;;
  Darwin) TEMPLATES="$HOME/Library/Application Support/Godot/export_templates" ;;
  *)      TEMPLATES="${APPDATA:-$HOME/AppData/Roaming}/Godot/export_templates" ;;
esac
if ! ls -d "$TEMPLATES"/${VERSION}* >/dev/null 2>&1; then
  echo "No están instaladas las plantillas de exportación de Godot $VERSION en: $TEMPLATES" >&2
  echo "Instálalas desde el editor: Proyecto > Exportar > Administrar plantillas de exportación." >&2
  exit 1
fi

mkdir -p builds
"$GODOT" --headless --path kairos-arcade --import

export_preset() {
  echo "Exportando: $1"
  "$GODOT" --headless --path kairos-arcade --export-release "$1"
}

case "$TARGET" in
  windows) export_preset "Windows Desktop" ;;
  linux)   export_preset "Linux" ;;
  all)     export_preset "Windows Desktop"; export_preset "Linux" ;;
  *) echo "Uso: tools/build.sh [windows|linux|all]" >&2; exit 1 ;;
esac
echo "Listo. Archivos en builds/"
