# Instalar Kairos Arcade en una máquina

Guía para dejar una terminal lista para el público: instalador, arranque automático y modo kiosco.

## Qué se probó y qué no

| Pieza | Estado |
| --- | --- |
| Modo kiosco, botones de ayuda y vinculación dentro de la app | Probado ejecutando la app desde el editor de Godot |
| `installer/linux/install.sh` y `run-kairos.sh` | Probado con un ejecutable de mentira: valida datos, instala, deja el arranque automático y reinicia tras un fallo |
| Lectura de `override.cfg` (URL de la API) | Probado en la carpeta del proyecto. Con una build exportada, Godot la lee junto al ejecutable según su documentación, pero **no se probó** |
| `tools/build.sh` (exportar) | Falla con un mensaje claro si faltan las plantillas; la exportación en sí **no se probó** |
| Fullscreen real, ventana que no se cierra y cursor oculto | **No se probó a pantalla completa** (se probó la lógica de decisión, no la ventana) |
| `installer/windows/KairosArcade.iss` | **Sin compilar ni probar**: se escribió sin Windows ni Inno Setup. Pruébalo primero en una máquina de prueba |

## 1. Generar la build

1. Instala Godot 4.7.2 y sus plantillas de exportación (Editor → Proyecto → Exportar → Administrar plantillas de exportación).
2. Desde la raíz del repositorio:

   ```sh
   tools/build.sh windows   # builds/KairosArcade.exe
   tools/build.sh linux     # builds/KairosArcade.x86_64
   ```

## 2. Instalar

### Windows

1. En Windows, con [Inno Setup 6](https://jrsoftware.org/isinfo.php): `iscc installer\windows\KairosArcade.iss`. Genera `builds\installer\KairosArcade-Setup.exe`.
2. En la máquina, ejecuta el instalador. Pide la **dirección del servidor de Kairos** (la API) y ofrece evitar la suspensión del equipo.
3. Instalación sin ventanas: `KairosArcade-Setup.exe /VERYSILENT /API=https://api.tu-dominio.com`.

Instala en `Program Files\Kairos Arcade`, crea el arranque automático para todos los usuarios y abre la app con `run-kairos.cmd`, que la vuelve a abrir si se cierra por un fallo.

### Linux

```sh
installer/linux/install.sh --api https://api.tu-dominio.com
```

Instala en `~/kairos-arcade` y crea `~/.config/autostart/kairos-arcade.desktop`. Opciones: `--prefix`, `--binary`, `--autostart-dir`, `--no-autostart`.

## 3. Vincular con el negocio

Al abrir la app por primera vez aparece **Vincula esta máquina**: el administrador del negocio inicia sesión, elige la sucursal y listo. Detalles en el `README.md` principal.

La carpeta de datos del usuario conserva la llave y la configuración; reinstalar la app **no** pide vincular de nuevo, y desinstalarla **no** las borra.

## Modo kiosco

Se activa solo en la app instalada (en el editor está apagado) y se controla así:

- `"kiosk": false` en `machine.config.json` lo apaga; `--windowed` y `--kiosk` (después de `--`) mandan sobre la configuración.
- Pone la ventana en **pantalla completa**, siempre encima, y oculta el cursor (excepto en la pantalla de vinculación).
- **Ignora cerrar la ventana** (Alt+F4) cuando la máquina ya está vinculada. Antes de vincular, el técnico sí puede cerrarla.
- La única salida es el **menú de administrador**: `Esc` cinco veces en el menú → inicio de sesión del negocio → "Salir de la aplicación". Esa salida termina con código 0 y el reinicio automático no la repite.

### Lo que el modo kiosco no puede bloquear

Una aplicación no puede impedir Alt+Tab, la tecla Windows ni Ctrl+Alt+Supr. Para una cabina pública, bloquea el equipo desde el sistema operativo:

- **Windows:** crea un usuario dedicado con inicio de sesión automático y usa *Acceso asignado* (Assigned Access) o *Shell Launcher* para que solo se ejecute Kairos Arcade.
- **Linux:** usa una sesión de kiosco dedicada (un usuario sin escritorio completo) o un gestor de ventanas de una sola aplicación.
- En ambos: desactiva la suspensión y los avisos del sistema, y no dejes el teclado conectado si no hace falta.

## Botones de ayuda

Todas las pantallas (menú, iniciales, marcador, resultado y vinculación) tienen un botón **?** en la esquina inferior derecha que explica la pantalla y qué es Kairos. También se abre con la tecla **H** y, en el menú, con **↓**. Para una cabina solo con botones, asigna uno de ellos a la tecla H. El texto vive en `scripts/core/help_texts.gd`; las instrucciones de cada juego, en su archivo de `resources/games/`.

Dentro de la partida no hay botón de ayuda, para no distraer ni pausar el juego.
