#!/usr/bin/env bash
# Abre Kairos Arcade y lo vuelve a abrir si se cierra por un fallo.
# Si el administrador sale a propósito (código 0), no se reabre.
cd "$(dirname "$0")" || exit 1

# Evita que la pantalla se apague (solo aplica en X11; en Wayland usa la configuración del escritorio).
if command -v xset >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
  xset s off -dpms s noblank 2>/dev/null || true
fi

BIN="${KAIROS_BIN:-./KairosArcade.x86_64}"
while true; do
  "$BIN" "$@"
  code=$?
  [ "$code" -eq 0 ] && exit 0
  sleep "${KAIROS_RESTART_DELAY:-3}"
done
