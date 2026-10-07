#!/usr/bin/env bash
# Instala Kairos Arcade en Linux y lo deja arrancando solo al iniciar sesión.
#
#   ./install.sh --api https://api.tu-dominio.com [--binary RUTA] [--prefix DIR]
#                [--autostart-dir DIR] [--no-autostart]
#
# Por defecto instala en ~/kairos-arcade y crea ~/.config/autostart/kairos-arcade.desktop.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PREFIX="$HOME/kairos-arcade"
BINARY="$HERE/../../builds/KairosArcade.x86_64"
AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART=1
API=""

usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --api) API="${2:-}"; shift 2 ;;
    --binary) BINARY="${2:-}"; shift 2 ;;
    --prefix) PREFIX="${2:-}"; shift 2 ;;
    --autostart-dir) AUTOSTART_DIR="${2:-}"; shift 2 ;;
    --no-autostart) AUTOSTART=0; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Opción desconocida: $1" >&2; usage 1 ;;
  esac
done

case "$API" in
  http://*|https://*) ;;
  *) echo "Falta --api con la dirección del servidor (https://...)." >&2; exit 1 ;;
esac
[ -f "$BINARY" ] || { echo "No encuentro el ejecutable: $BINARY (genera la build con tools/build.sh)." >&2; exit 1; }

mkdir -p "$PREFIX"
install -m 755 "$BINARY" "$PREFIX/KairosArcade.x86_64"
install -m 755 "$HERE/run-kairos.sh" "$PREFIX/run-kairos.sh"

# Godot lee override.cfg junto al ejecutable y reemplaza el ajuste kairos/api_url.
printf '[kairos]\n\napi_url="%s"\n' "$API" > "$PREFIX/override.cfg"

if [ "$AUTOSTART" -eq 1 ]; then
  mkdir -p "$AUTOSTART_DIR"
  cat > "$AUTOSTART_DIR/kairos-arcade.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Kairos Arcade
Exec=$PREFIX/run-kairos.sh
Path=$PREFIX
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
fi

echo "Kairos Arcade instalado en $PREFIX"
[ "$AUTOSTART" -eq 1 ] && echo "Arrancará solo al iniciar sesión ($AUTOSTART_DIR/kairos-arcade.desktop)."
echo "Para abrirlo ahora: $PREFIX/run-kairos.sh"
