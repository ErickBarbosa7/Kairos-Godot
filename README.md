# Kairos-Godot

Terminal Arcade de **Kairos**, desarrollada con Godot 4.7.2 y GDScript. Consume la API del repositorio principal de Kairos y forma parte de la tercera etapa de la plataforma de fidelización B2B2C.

La experiencia permite que una persona juegue en una terminal, obtenga un QR temporal al finalizar y lo canjee después en la Wallet PWA por puntos y premios. El proyecto de Godot vive en [`kairos-arcade/`](kairos-arcade/).

## Estado

El menú Arcade presenta un catálogo desplazable de juegos:

| Juego | Estado | Descripción |
| --- | --- | --- |
| Defensa Estelar | Disponible | Shooter espacial vertical con oleadas, puntaje y pantalla de resultado. |
| Serpiente Golosa | Disponible | Snake de 60 s: come productos, crece y encadena para subir el multiplicador. Controles: flechas o WASD. |
| Ruta Nebular | EN PROCESO | Próximo juego del catálogo. |
| Lane Racer | EN PROCESO | Cambia de carril y evita el tráfico. |
| Memory Rush | EN PROCESO | Memoriza secuencias cada vez más largas. |
| Stack Tower | EN PROCESO | Apila bloques y construye la torre más alta. |

La aplicación incluye una marca de sucursal simulada para desarrollo local. Al configurarse, puede consultar la marca pública de una sucursal desde el API de Kairos.

## Documentación

- [Contexto](contexto.md): producto, flujo y restricciones de seguridad.
- [Planeación](planeacion.md): fases de trabajo.
- [Patrones de diseño](patrones-diseno.md): espacio para decisiones de diseño, experiencia y patrones de Godot.
- En el repositorio principal `Kairos`: `docs/ARQUITECTURA.md`, `docs/ESQUEMA.md` y `docs/DISENO.md`.

## Requisitos

- [Godot Engine 4.7.2](https://godotengine.org/download/) o una versión compatible de Godot 4.
- Git.
- El repositorio principal de Kairos y su API, solo para probar la integración real con una sucursal.

## Abrir y ejecutar

```sh
godot --path kairos-arcade
```

También se puede importar `kairos-arcade/project.godot` desde el Project Manager de Godot. El proyecto abre el menú principal y puede jugarse con teclado: flechas o `A` / `D` para moverse y `Espacio` para disparar en Defensa Estelar.

Sin archivo de configuración la terminal arranca con una sucursal simulada y no hace peticiones de red.

## Flujo de la terminal

1. La aplicación carga la configuración de la máquina y la marca de la sucursal.
2. La persona elige un juego del catálogo.
3. Juega una partida de 60 segundos. Durante la partida ve la **meta de QR** del juego.
4. Si su puntaje entra al top 10 del juego, pone sus **iniciales** (3 caracteres).
5. Si llegó a la meta, **gira la ruleta una sola vez**: cada casilla es una recompensa del negocio y la que queda bajo la flecha es la que gana.
6. En el resultado ve la recompensa ganada y un QR firmado, válido por 60 segundos, que la Wallet PWA canjea por un cupón para recoger en caja. Si no llegó a la meta, ve cuánto le faltó.

### La ruleta

- Aparece solo en las partidas que llegan a la meta, y da **un único giro**. Después de poner las iniciales (si entró al marcador) y antes del resultado.
- Las casillas son las recompensas **activas y con existencias** del negocio (`GET /public/stores/:id/rewards`). Si hay más de 8 se sortean 8; con menos, salen todas. Cada casilla tiene la misma probabilidad.
- El resultado se decide al empezar a girar. Si el negocio no tiene recompensas, el resultado lo explica y no hay QR. Sin red usa la última lista guardada; una máquina sin vincular usa recompensas de muestra.
- El QR lleva firmado el `reward_id`. La API comprueba que la recompensa sea de ese negocio, descuenta el stock y crea un cupón que el personal canjea en caja con su código (`docs/ACREDITACION.md` en `Kairos`).
- La recompensa ganada se muestra con **la imagen que el administrador subió** al crearla en el panel: en la tarjeta "¡GANASTE!" y junto al QR del resultado. Las casillas de la rueda llevan solo el nombre. Las imágenes se descargan al arrancar y se **guardan en disco** (`user://reward_images/`), así que la ruleta las muestra aunque la máquina arranque sin internet. Si el administrador cambia la imagen se descarga la nueva y la anterior se borra; solo una recompensa que nunca se descargó sale únicamente con su nombre.
- Con `"reduce_motion": true` la rueda no gira ni hay confeti.

### El QR no se da en cada partida

Una recompensa por partida le costaría demasiado a los negocios. Cada juego tiene una **meta de puntaje** (`qr_goal` en `kairos-arcade/resources/games/*.tres`) y solo las partidas que la alcanzan giran la ruleta y generan QR. Las metas se calibraron con la simulación de balance (`tests/balance_sim.gd`):

| Juego | Meta | Estimación con los bots de prueba |
| --- | --- | --- |
| Defensa Estelar | 22 000 | casual 0 %, medio ~30 %, bueno ~27 % |
| Serpiente Golosa | 10 000 | medio ~6 %, jugada casi perfecta ~99 % |

Los bots conocen la posición de todo, así que una persona real debería acertar menos. El negocio puede ajustar la meta de cada juego en `machine.config.json` con `qr_goals` según cuántos QR vea que se generan. Los puntos de Wallet que vale cada QR los decide la API (`score_per_point` y `max_points_per_game` del tenant), no la terminal.

### Probar el canje del QR

La API acredita el QR con `POST /wallet/claims` (detalle y errores en `docs/ACREDITACION.md` del repositorio `Kairos`). Mientras la Wallet no exista, se puede probar a mano: en `Kairos`, `pnpm --filter @kairos/api seed:consumer` imprime un token de cliente de prueba; el contenido del QR se lee con cualquier lector (por ejemplo `zbarimg --raw captura.png`) y se envía antes de que pasen 60 s.

### Estadísticas para calibrar la meta

La máquina cuenta, por juego, las partidas terminadas, cuántas llegaron a la meta y cuántos QR emitió (`user://play_stats.json`; no guarda iniciales ni datos de personas). Para verlas:

```sh
godot --headless --path kairos-arcade --script res://tools/stats.gd
```

Con 30 partidas o más avisa si la meta parece muy fácil (más de 15 % de partidas en la meta) o muy difícil (menos de 5 %). Los límites son orientativos; cada negocio decide cuánto quiere regalar.

### Marcador

Cada juego guarda en la máquina los 10 mejores puntajes con iniciales de 3 caracteres (`A-Z` y `0-9`). Se ve con `↑` desde el menú o con el botón "Marcador" del resultado. Las iniciales se eligen con `↑ ↓` (letra), `← →` (casilla) y `Espacio`; se guardan solas a los 30 s. Hay una lista mínima de iniciales bloqueadas en `ScoreStore.BLOCKED`.

La terminal usa una base visual oscura y adapta los acentos de interfaz a la identidad de la empresa anfitriona. Se emplean recursos propios y no se incorporan sprites ni contenido protegido de otros juegos.

## Configuración de la máquina

`AppConfig` busca un archivo `machine.config.json` en este orden:

1. Ruta indicada con `--config=<ruta>` después de `--`
   (`godot --path kairos-arcade -- --config=/ruta/machine.config.json`).
2. Variable de entorno `KAIROS_CONFIG`.
3. Junto al ejecutable exportado.
4. `user://machine.config.json` (carpeta de datos de Godot).

Campos:

```json
{
  "api_url": "http://localhost:3000",
  "store_id": "uuid-de-la-sucursal",
  "machine_id": "uuid-de-la-maquina",
  "private_key_path": "/ruta/fuera/del/repo/maquina.private.pem",
  "qr_goals": { "defensa_estelar": 22000 },
  "dev_mode": false,
  "reduce_motion": false
}
```

- `private_key_path`: llave privada ES256 (PEM PKCS#8) de **esta** máquina. Sin ella la terminal juega normal pero no genera QR.
- `qr_goals`: opcional; sobrescribe la meta de QR de cada juego.

### Vincular una terminal con un negocio

La app se vincula sola desde su propia pantalla; no hace falta consola ni editar archivos. Se hace una vez por máquina y necesita teclado y ratón solo en ese momento.

**Antes**, en el panel de Kairos: el Super Admin crea el negocio (con su administrador) y el administrador crea la sucursal.

**En la máquina**, al abrir la app instalada por primera vez aparece "Vincula esta máquina":

1. El administrador escribe el identificador del negocio, su correo y su contraseña (los mismos del panel). Solo el rol administrador puede vincular.
2. Elige la sucursal y le pone un nombre a la máquina ("Mostrador").
3. La app **genera aquí el par de llaves**, registra en el panel solo la **pública** y guarda la configuración. Al terminar muestra "¡Máquina vinculada!" y arranca con la marca del negocio.

La contraseña y el token de sesión no se guardan: viven solo en esa pantalla. La llave privada nunca sale del equipo; se guarda en la carpeta de datos del usuario (`machine.private.pem`, con permisos restringidos en Linux y macOS) junto con `machine.config.json`. El panel muestra el ID de cada máquina por si hace falta.

- **Vincular de nuevo o cambiar de sucursal:** en el menú, pulsa `Esc` cinco veces seguidas. Pide otra vez el inicio de sesión del negocio y registra una máquina **nueva**; revoca la anterior en el panel.
- **URL de la API:** viene incluida en la app (ajuste `kairos/api_url` en `project.godot`, sección `[kairos]`). **Cámbiala a la URL de producción antes de exportar.** La variable de entorno `KAIROS_API_URL` la sobrescribe.
- **Al desarrollar:** desde el editor la vinculación se omite y se usa la sucursal simulada. Para probar la pantalla: `godot --path kairos-arcade -- --link`.
- **Si se compromete una máquina:** "Revocar" en el panel. Es definitivo.

Cada máquina tiene su **propio par de llaves**, así que revocar una no apaga a las demás. El **reloj de la máquina debe estar en hora**: el QR vence a los 60 s y la API lo rechaza si la hora no coincide (margen de 5 s).

#### Alta manual (alternativa avanzada)

Sigue funcionando si prefieres hacerlo a mano: genera la llave con `pnpm --filter @kairos/api gen:machine-key mostrador-1` en el repositorio `Kairos`, registra la pública en el panel ("Agregar máquina", ES256) y escribe `machine.config.json` con `api_url`, `store_id`, `machine_id` y `private_key_path`.

## Instalación y modo kiosco

La app se instala con un instalador (Windows) o un script (Linux), arranca sola, se abre a pantalla completa y se vuelve a abrir si falla. La guía completa, qué se probó y qué no, está en [`installer/README.md`](installer/README.md).

Todas las pantallas tienen un botón **?** (o la tecla **H**) que explica la pantalla y qué es Kairos.

## Pruebas

```sh
godot --headless --path kairos-arcade --script res://tests/run_tests.gd
```

Sale con código distinto de cero si alguna prueba falla.

## Estructura

```text
kairos-arcade/
├── assets/       # Fuentes y recursos propios
├── resources/    # Datos del catálogo de juegos
├── scenes/       # Inicio, menú, juego y resultado
├── scripts/      # Interfaz, lógica de juego, API y estado global
├── tests/        # Pruebas ejecutables en modo headless
└── project.godot
```
