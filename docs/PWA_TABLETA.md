# Kairos Arcade en tableta

La terminal web está diseñada para una tableta fija del negocio, en horizontal, conectada a Wi-Fi y corriente. Funciona con Chrome en Android y Safari en iPad; se instala desde el navegador en la pantalla de inicio.

## Publicación

1. Instala las plantillas de exportación de Godot 4.7.
2. En Godot, exporta el preset **Web PWA** a una carpeta estática bajo el mismo dominio que la API, por ejemplo `https://arcade.kairos.mx/`.
3. Configura HTTPS y conserva las cabeceras que genera la PWA. El juego debe poder solicitar `/terminal/*` con el mismo origen.
4. Define `VITE_ARCADE_WEB_URL` en el panel Admin con esa URL para mostrar el acceso de tableta en la landing.

Cada publicación sustituye los archivos web. Al cerrar y volver a abrir la PWA, la tableta descarga la versión vigente.

## Vinculación

1. La tableta abre la PWA y solicita un código temporal.
2. Un administrador entra a **Sucursales y máquinas** en Kairos.
3. Pulsa **Vincular tableta**, escribe el código, nombra la terminal y elige la sucursal.
4. La PWA recibe una cookie de terminal revocable. No guarda contraseñas, tokens de administrador ni llaves privadas.

Al revocar la máquina desde el panel se invalidan sus sesiones web y ya no puede emitir QR.

## Uso físico

- Montar la tableta en horizontal; el juego conserva su lienzo 16:9 y usa márgenes en iPad 4:3.
- Mantenerla conectada a Wi-Fi: los QR se firman desde la API al finalizar cada partida.
- Activar el modo de pantalla completa desde el primer toque y usar el modo kiosco/Acceso guiado que ofrezca el dispositivo.
- Los juegos se controlan con botones táctiles grandes: zonas izquierda/derecha, cuatro direcciones, toque para apilar y gestos para Snake. El teclado continúa disponible para escritorio.
