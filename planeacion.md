# Planeación — Kairos Arcade con Godot

## Objetivo inicial

Crear una terminal Arcade 2D para Windows con un menú de tres juegos. El
primer juego será un shooter espacial original inspirado en Galaga. Los otros
dos estarán visibles como `EN PROCESO` para que el sistema pueda crecer sin
cambiar el menú.

## Alcance de la primera entrega

- Resolución de referencia: 1920×1080 en horizontal.
- Controles: flechas o A/D para moverse y espacio para disparar.
- Partidas de 60 segundos.
- Carga dinámica de marca por sucursal.
- Menú con tres juegos:
  1. Defensa Estelar — jugable.
  2. Serpiente Golosa — jugable.
  3. Ruta Nebular — EN PROCESO.
- Pantalla final con puntaje y espacio reservado para QR.

No se usarán nombres, sprites, sonidos ni otros recursos de Galaga. Defensa
Estelar tendrá personajes, arte y sonido propios.

## Fase 1 — Base de la terminal

1. Actualizar `README.md` para identificar el proyecto como Kairos-Godot.
2. Crear carpetas `scenes/`, `scripts/`, `assets/`, `themes/` y `tests/`.
3. Configurar el proyecto para 2D, ventana horizontal y exportación Windows.
4. Definir acciones de entrada: movimiento, disparo, confirmar, volver y
   modo de prueba.
5. Crear autoloads:
   - `AppConfig`: URL de API, sucursal, máquina y configuración de desarrollo.
   - `ArcadeState`: estado global de menú, partida, puntaje y resultado.
   - `ApiClient`: solicitudes HTTP y carga de imágenes.
   - `TenantTheme`: colores, logo y fallback local.

**Criterio de aceptación:** la aplicación abre en una escena inicial sin
errores y puede ejecutarse con configuración simulada.

## Fase 2 — Marca y menú

1. Solicitar `GET /public/stores/:id/brand` al arrancar.
2. Aplicar nombre, logo y colores del tenant al menú.
3. Guardar la última respuesta válida para que la terminal funcione sin red.
4. Usar el tema Kairos oscuro como fallback si no hay marca almacenada.
5. Construir el menú como tres tarjetas grandes:
   - Defensa Estelar y Serpiente Golosa inician la partida.
   - Ruta Nebular muestra `EN PROCESO`, candado y no acepta selección.

**Criterio de aceptación:** cambiar de sucursal cambia la marca del menú y
una terminal sin conexión sigue mostrando la última marca disponible.

## Fase 3 — Defensa Estelar

1. Crear nave del jugador, movimiento horizontal y disparo con cadencia.
2. Crear enemigos propios que entren en formación, bajen hacia el jugador y
   disparen proyectiles.
3. Añadir colisiones, tres impactos disponibles y efectos visuales breves.
4. Añadir núcleos de energía o monedas como puntuación adicional.
5. Mostrar HUD con puntaje, vidas, multiplicador de racha y temporizador.
6. Terminar al agotarse el tiempo o las vidas.
7. Crear pantalla de resultado con puntaje, mejor resultado local y retorno
   al menú.

**Criterio de aceptación:** una persona puede empezar una partida, jugarla
durante 60 segundos y volver al menú sin reiniciar la aplicación.

## Fase 4 — QR seguro

1. Realizar una prueba técnica antes de integrar el QR definitivo:
   - cargar una llave privada ES256 o EdDSA;
   - firmar el payload en Godot;
   - verificar la firma con `jose` en la API de Kairos.
2. Elegir ES256 o EdDSA según la compatibilidad demostrada por la prueba.
3. Generar el JWT al terminar una partida con `store_id`, `machine_id`,
   `score`, `iat`, `exp` y `jti`.
4. Convertir el JWT a QR con cuatro módulos blancos de margen.
5. Mostrar el QR durante su vigencia, un contador y una indicación de abrir
   la Wallet para escanearlo.
6. Añadir al monorepo Kairos la ruta que validará el QR cuando se construya la
   Wallet; esa ruta verificará firma, expiración, máquina, tenant y uso único.

**Criterio de aceptación:** el QR firmado por Godot es verificable desde la
API y no puede reutilizarse al acreditarse.

## Fase 5 — Pruebas y entrega

1. Probar arranque con red, sin red y con una sucursal inexistente o inactiva.
2. Probar controles, reinicio, temporizador, vidas, puntaje y retorno al menú.
3. Probar a 1280×720, 1920×1080 y en pantalla completa.
4. Probar teclado y, cuando se agregue, controles táctiles.
5. Exportar para Windows y probar en la computadora destinada a la cabina.
6. Documentar el archivo externo de configuración de cada máquina y el
   procedimiento para registrar su llave pública en el panel.

## Decisiones pendientes antes de producción

- Hardware final de la cabina y si tendrá pantalla táctil.
- Arte, música y efectos de sonido definitivos.
- Librería o implementación para codificar QR.
- Algoritmo definitivo para firmar JWT desde Godot, confirmado por la prueba
  de interoperabilidad.
