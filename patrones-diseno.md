# Patrones de diseño — Kairos Arcade

Guía de diseño visual, de experiencia de usuario y de implementación en Godot
para la terminal Arcade. Complementa `contexto.md` y `planeacion.md`.

La fuente de verdad de la marca está en el repositorio `Kairos`:
`design.md` (paleta, tipografía y forma vigentes), `docs/DISENO.md` (theming del
tenant) y `packages/design/tokens.json`. Este documento no redefine esos valores;
explica cómo se traducen a una pantalla de arcade y a Godot. Si un token cambia
allá, cambia aquí.

## 1. Principios

1. **Se entiende en tres segundos.** Una persona de pie, que nunca vio la
   máquina, debe saber qué hacer sin leer instrucciones largas.
2. **La marca del negocio manda.** El color y el logo del tenant son el
   protagonista del menú y del HUD. Kairos queda como firma secundaria.
3. **Oscuro siempre.** El fondo es de noche de arcade para que el color del
   tenant destaque y el juego se lea con luz variable del local.
4. **Contraste y forma antes que decoración.** Bordes definidos, sombras duras,
   títulos pesados. Ningún estado se comunica solo con color.
5. **Se siente bien al tocarlo.** Cada acción tiene respuesta visual y sonora en
   menos de 100 ms.
6. **Jugable antes que bonito.** Si un efecto estorba la lectura del campo de
   juego, se reduce o se quita.

## 2. Pantalla y zonas seguras

- Resolución de referencia: **1920×1080**, horizontal. Proyecto con
  `stretch/mode = canvas_items` y `aspect = expand`, ya configurados.
- Márgenes seguros: **64 px** en cada lado. Ningún texto ni botón entra en esa
  franja, porque algunos monitores y cabinas recortan el borde.
- Rejilla de **8 px**. Espaciados válidos: 8, 16, 24, 32, 48, 64.
- Se prueba también a 1280×720 y en pantalla completa. Todo se ancla con
  contenedores y anclas, no con posiciones absolutas.

```
┌──────────────────────────────────────────────────────────────┐
│ 64px de margen seguro                                        │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ [logo] Negocio                        kairos · 00:60   │  │ cabecera
│  │                                                        │  │
│  │              zona principal de contenido               │  │
│  │                                                        │  │
│  │  controles / ayuda contextual                          │  │ pie
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## 3. Color

### 3.1 Capas

| Capa | Fuente | Uso |
|---|---|---|
| Base Kairos | `tokens.json` → `brand.night`, `night-raised`, `night-line` | Fondo, tarjetas, bordes. Nunca cambian por tenant |
| Tenant | `GET /public/stores/:id/brand` | Botones principales, selección, acento del HUD, logo |
| Puntos | `brand.reward` (`#FBBF24`) | Monedas, puntaje, premios. Igual en Arcade y Wallet |
| Estado | `theme.dark.success/warning/danger` | Vidas bajas, tiempo por acabar, errores |
| QR | Negro y blanco fijos | Nunca se tematiza |

### 3.2 Derivación del color del tenant

`TenantTheme` calcula en Godot los mismos valores que `theme-tenant.ts`, con la
misma fórmula de luminancia relativa, para que web y Arcade coincidan:

- `primary`: el color del tenant, ajustado si no llega a contraste 3:1 contra el
  fondo oscuro.
- `on_primary`: blanco o casi negro, el que dé mayor contraste (mínimo 4.5:1).
- `primary_hover`: 8 % más claro (en tema oscuro).
- `primary_subtle`: primario al 12 % de opacidad sobre la superficie.
- `focus`: primario o acento, el que contraste ≥ 3:1.

Si falta marca o el color es inválido, se usa el tema Kairos guardado en el
paquete. Los valores finales se escriben en un recurso `Theme` de Godot y no en
cada escena.

### 3.3 Reglas

- Nunca un color escrito dentro de una escena o script de UI. Todo sale de
  `TenantTheme` o de constantes de tokens.
- Un solo botón primario por pantalla.
- Los colores de los elementos del juego (balas, enemigos, nave) son **fijos y
  propios del juego**, no del tenant, para que siempre se distingan entre sí.
  El tenant solo tiñe la nave del jugador y los efectos de su disparo.

## 4. Tipografía

Las mismas familias que la web, empaquetadas como `FontFile` en `assets/fonts/`:

| Rol | Fuente | Uso en Arcade |
|---|---|---|
| Display | Big Shoulders Display (700–900) | Títulos de juego, puntaje, temporizador, cuenta atrás |
| Acento | Instrument Serif cursiva | Una palabra por título, mensajes de celebración, firma "kairos" |
| Texto | Figtree (500–600) | Descripciones, ayudas, etiquetas |
| Mono | JetBrains Mono (500) | Contador del QR, códigos |

Escala para 1080p (se mira desde un metro o más, así que es mayor que en web):

| Elemento | Tamaño |
|---|---|
| Puntaje y cuenta atrás | 96–160 px, números tabulares |
| Título de pantalla | 72 px |
| Título de tarjeta de juego | 48 px |
| Texto de apoyo | 28 px mínimo |
| Etiquetas del HUD | 24 px mínimo |

- Regla de la cursiva: una sola palabra por título. Ejemplo: "Elige tu *juego*".
- Nada de texto por debajo de 24 px en 1080p.
- El puntaje usa dígitos de ancho fijo para que no "baile" al subir.

## 5. Forma y elevación

Sigue `design.md`: esquinas casi rectas (radios 0, 2 y 4 px), bordes de 2–4 px y
**sombras duras** sin desenfoque desplazadas hacia abajo y a la derecha.

- Tarjeta: fondo `night-raised`, borde `night-line` de 4 px, sombra dura de 8 px.
- Seleccionada: borde del color del tenant, sombra del color del tenant y
  escala 1.04. La selección nunca se indica solo con color: también con el borde
  grueso, la escala y una flecha o marcador.
- Botón: relleno del tenant, texto `on_primary`, mínimo 96 px de alto.
- Se usa `StyleBoxFlat` con borde y sombra dura. No se usan degradados suaves ni
  desenfoques.

## 6. Layout de pantallas

### 6.1 Arranque

- Logo Kairos y barra de carga corta mientras se pide la marca.
- Tiempo máximo de espera de red: 3 segundos. Si falla, pasa al menú con la
  última marca guardada, o con el tema Kairos si no hay ninguna. Nunca se queda
  bloqueada en una pantalla de carga.
- Sin mensajes técnicos para el cliente. Los errores van al registro.

### 6.2 Menú de juegos

Tres tarjetas grandes en fila, cada una de unos 560×640 px.

```
        [logo] NEGOCIO                          kairos
   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
   │  ilustración│ │  ilustración│ │  ilustración│
   │             │ │             │ │   (apagada) │
   │ DEFENSA     │ │ SERPIENTE   │ │ RUTA        │
   │ ESTELAR     │ │ GOLOSA      │ │ NEBULAR     │
   │ 60 s        │ │ 60 s        │ │ 🔒 EN PROCESO│
   └─────────────┘ └─────────────┘ └─────────────┘
        ← →  elegir        ESPACIO  jugar
```

- Foco inicial en el primer juego jugable. Si solo uno es jugable, la pantalla
  debe invitar a pulsar sin tener que navegar.
- Los juegos en proceso muestran candado, texto `EN PROCESO` y tono atenuado.
  El foco puede pasar por ellos, pero al confirmar se reproduce un sonido de
  "no disponible" y una sacudida corta; nunca un silencio que parezca fallo.
- Ayuda de controles fija abajo, con teclas dibujadas como iconos.
- Modo atracción: tras 30 segundos sin actividad, el menú reproduce una demo
  corta del juego con el texto "Pulsa ESPACIO para jugar". Cualquier tecla vuelve
  al menú.

### 6.3 Cuenta atrás

Antes de cada partida: **3, 2, 1, ¡YA!** en Display gigante (160 px), un número
por segundo, con sonido y escala de entrada. El jugador ve el campo y puede
mover la nave, pero no hay enemigos ni temporizador hasta "¡YA!". Se puede
saltar con confirmar.

### 6.4 HUD durante la partida

- Arriba izquierda: **puntaje** (Display 96 px, color `reward`).
- Arriba centro: **temporizador** de 60 s. En los últimos 10 s cambia a
  `warning`, late y suena un tic. Siempre acompañado del número.
- Arriba derecha: **vidas** como tres iconos de nave. Una vida perdida se ve
  como icono vacío con contorno, no solo como color apagado.
- Abajo izquierda: **multiplicador de racha** (`x2`, `x3`…) con barra que se
  vacía si no se acierta.
- El HUD es translúcido y no cubre el tercio inferior, donde está la nave.
- Los números que suben se animan con un pequeño impulso de escala de 120 ms.

### 6.5 Pausa y salida

- No hay pausa que permita "congelar" la partida para alargar el tiempo de la
  cabina: la tecla de pausa muestra una confirmación de abandonar y el tiempo no
  se detiene más de 10 segundos antes de cerrar la partida.
- Salir a mitad de partida pide confirmación con botón de peligro y texto claro.

### 6.6 Resultado y QR

Orden de aparición, con 400 ms entre cada paso:

1. **Fin de partida** con título y motivo ("Se acabó el tiempo" o "Sin vidas").
2. **Puntaje final** contando hacia arriba. Si supera el mejor local, aparece
   "¡Nuevo récord!" con icono y texto.
3. **QR** negro sobre blanco, con margen de 4 módulos, mínimo **480×480 px**, en
   un panel blanco con borde. Es lo más grande de la pantalla.
4. **Contador de vigencia** en mono grande, con barra que se vacía. Se pone en
   `warning` con icono cuando quedan 15 s.
5. Texto claro en español: "Abre Kairos en tu teléfono y escanea este código".
6. Botón "Jugar otra vez" y "Volver al menú". El foco inicial está en "Jugar
   otra vez".

Reglas del QR:

- Nunca se tematiza, no lleva logo en el centro y no tiene animaciones sobre él.
- Al expirar se reemplaza por un estado "Código vencido" con icono y texto, y
  ofrece volver a jugar. No se regenera solo con el mismo puntaje.
- La pantalla vuelve sola al menú tras 90 segundos para la siguiente persona.
- El brillo y el fondo alrededor del QR son lisos, sin partículas, para que
  la cámara del teléfono lo lea.

## 7. Experiencia de juego y manejo

### 7.1 Controles

| Acción | Teclado | Mando (futuro) |
|---|---|---|
| Mover | ← → o A D | Stick izquierdo o cruceta |
| Disparar | Espacio | Botón A |
| Confirmar | Espacio o Intro | Botón A |
| Volver | Esc | Botón B |
| Modo de prueba | F1 (solo desarrollo) | — |

- Toda acción se define en el `InputMap` con nombres (`move_left`, `fire`,
  `confirm`, `back`). Ningún script lee teclas directamente.
- El menú se navega con las mismas teclas que el juego, sin cambiar de mano.
- Disparo automático opcional: si se deja pulsado, dispara a la cadencia
  máxima. Reduce el cansancio en partidas de un minuto.
- Se prevén objetivos táctiles de al menos 96 px por si la cabina lleva pantalla
  táctil.

### 7.2 Dificultad y ritmo

Una partida de 60 segundos tiene que sentirse como una historia corta:

| Tramo | Qué pasa |
|---|---|
| 0–10 s | Pocos enemigos y lentos. El jugador aprende los controles |
| 10–40 s | Más enemigos, formaciones y disparos enemigos |
| 40–55 s | Pico de intensidad y aparece un enemigo especial |
| 55–60 s | Ráfaga final con puntos extra por núcleos |

- Los primeros 10 segundos no deben poder acabar la partida.
- Perder una vida da 1.5 s de invulnerabilidad con parpadeo.
- El juego se premia más por aprender que por insistir: la racha sube con
  aciertos seguidos y baja al recibir impacto.
- La dificultad está en un recurso de configuración, no dentro del código, para
  ajustarla sin tocar la lógica.

### 7.3 Legibilidad del campo

- Las balas del jugador son azules o del color del tenant con forma de **barra**.
  Las de los enemigos son rosa magenta (`#FF3D9A`) con forma de **diamante** y borde blanco; no se usa naranja-rojo porque muchos tenants eligen tonos cálidos y se confundirían con las balas del jugador. La forma
  las distingue aunque el color falle (daltonismo).
- Los enemigos tienen silueta clara contra el fondo. Los núcleos de energía son
  ámbar con brillo y giro constante.
- El fondo del campo (estrellas, nebulosa) tiene bajo contraste y se mueve
  despacio, para que no compita con lo importante.
- La zona de hitbox del jugador es **más pequeña que el sprite**. Es la práctica
  habitual del género y evita que los impactos parezcan injustos.

## 8. Sensación de juego (game feel)

Pequeños detalles que cuestan poco y cambian mucho la experiencia:

| Evento | Respuesta |
|---|---|
| Disparar | Destello en la boca de la nave, retroceso de 2 px, sonido corto |
| Impactar enemigo | Parpadeo blanco de 60 ms y partículas pequeñas |
| Destruir enemigo | Explosión breve, número de puntos flotante en `reward`, sonido |
| Recoger núcleo | Brillo, sonido ascendente, el icono vuela hacia el puntaje |
| Recibir impacto | Sacudida de cámara de 150 ms, parpadeo rojo del borde, pérdida de vida visible |
| Subir racha | El multiplicador crece y suena un acorde |
| Últimos 10 s | Latido del temporizador y ligero aumento de música |

Principios:

- **Detención de impacto (hit stop):** 30–50 ms de pausa al destruir un enemigo
  grande. Más de eso se siente como lag.
- **Sacudida de cámara** breve y con intensidad limitada. Debe poder reducirse.
- **Partículas** con tope por pantalla (por ejemplo 200) para sostener 60 FPS en
  equipo modesto.
- **Números flotantes** pequeños que suben y se desvanecen en 600 ms.
- **Un efecto no tapa a otro:** el juego se lee primero, la decoración después.

## 9. Movimiento

Mismas duraciones que la web, con una más para el juego:

| Uso | Duración |
|---|---|
| Microinteracción (foco, pulsación) | 120 ms |
| Transición de pantalla | 200–300 ms |
| Celebración (récord, resultado) | 400 ms |
| Cuenta atrás | 1 s por paso |

- Curvas con salida suave (`ease_out`) para entradas y `ease_in` para salidas.
- Las transiciones entre pantallas son un barrido o corte en color del tenant,
  nunca fundidos largos.
- Opción **"Reducir movimiento"** en la configuración de la máquina: sin
  sacudida de cámara, sin hit stop, partículas reducidas y fondo estático. El
  juego sigue siendo completo.
- Nada parpadea más de tres veces por segundo en una zona grande.

## 10. Sonido

- Cada acción relevante tiene sonido corto: mover foco, confirmar, disparo,
  impacto, explosión, núcleo, vida perdida, fin de partida, nuevo récord, tic del
  temporizador y "no disponible".
- La música del menú es tranquila y en bucle. La del juego sube de intensidad con
  el tramo de la partida.
- Buses de audio separados: `Musica`, `Efectos`, `Interfaz`. El volumen general
  se limita para no molestar en el local.
- Todo sonido importante tiene también respuesta visual, y al revés. La
  información no depende solo del audio.
- Si un recurso de audio falta, el juego continúa en silencio y lo registra.

## 11. Accesibilidad

- Contraste de texto ≥ 4.5:1 y de elementos grandes ≥ 3:1 sobre el fondo.
- Foco siempre visible: borde grueso, escala y marcador, no solo color.
- Ningún estado depende solo del color: vidas, tiempo, bloqueado y errores
  llevan icono y texto.
- Textos en español, centralizados en un único archivo de cadenas
  (`scripts/strings.gd` o un recurso de traducción), no dentro de las escenas.
- Controles simples: dos acciones de juego. Opción de disparo automático.
- Opción de reducir movimiento (sección 9).
- Texto mínimo de 24 px y lenguaje corto, sin tecnicismos.
- Lectura del QR: se evita cualquier efecto encima y se mantiene el contraste
  máximo.

## 12. Patrones de implementación en Godot

### 12.1 Estructura de carpetas

```
kairos-arcade/
  scenes/
    boot/        # arranque y carga de marca
    menu/        # menú y tarjetas de juego
    games/
      defensa_estelar/
    ui/          # HUD, resultado, QR, diálogos reutilizables
  scripts/
    autoload/    # AppConfig, ArcadeState, ApiClient, TenantTheme
    core/        # utilidades, estados, señales
    games/
  assets/
    fonts/  audio/  sprites/  vfx/
  themes/        # Theme de Godot (base Kairos y plantilla del tenant)
  resources/     # configuración de juegos y dificultad (.tres)
  tests/
```

### 12.2 Autoloads (ya definidos en la planeación)

| Autoload | Responsabilidad | No debe hacer |
|---|---|---|
| `AppConfig` | Leer URL de API, sucursal, máquina y opciones del archivo externo | Guardar la llave privada en el proyecto |
| `ArcadeState` | Estado de pantalla, partida, puntaje y resultado | Pintar interfaz |
| `ApiClient` | Peticiones HTTP, tiempo de espera, descarga de imágenes | Decidir lógica de juego |
| `TenantTheme` | Calcular colores derivados, aplicar `Theme`, respaldo | Hacer peticiones de red |

### 12.3 Patrones recomendados

- **Señales hacia arriba, llamadas hacia abajo.** Los nodos hijos emiten señales
  (`score_changed`, `life_lost`, `game_finished`); el padre decide. Se evitan
  rutas largas `get_node("../../..")`.
- **Máquina de estados** para el flujo de la aplicación:
  `Boot → Menu → Countdown → Playing → Result → Menu`. Una sola escena activa a
  la vez, cambiada por un `SceneManager` que aplica la transición.
- **Interfaz común de juego.** Cada juego implementa el mismo contrato:
  `start()`, señal `finished(score: int, reason: String)`, propiedad
  `duration_seconds`. El menú solo conoce ese contrato, así que añadir un juego
  no cambia el menú.
- **Recursos de datos** (`Resource`) para describir cada juego (nombre, ilustración,
  estado `jugable` o `en_proceso`, escena) y la dificultad (oleadas, velocidades,
  cadencias). Los datos se ajustan en el editor sin tocar código.
- **Reserva de objetos (object pooling)** para balas, enemigos y partículas. En
  juegos de disparos evita picos de memoria y mantiene 60 FPS.
- **Un `Theme` por tema**, no estilos por nodo. Los controles heredan de él y el
  cambio de marca se aplica en un solo punto.
- **Entrada por acciones** del `InputMap`, nunca por teclas fijas.
- **Tipado estático** en GDScript (`var score: int`, `func fire() -> void`) para
  detectar errores antes de ejecutar y ganar rendimiento.
- **Sin lógica de puntos de Wallet.** La terminal informa el puntaje crudo. La
  API calcula y limita los puntos.
- **Separar lógica de presentación.** El cálculo de puntaje, racha y oleadas va
  en clases sin nodos, para poder probarlo con pruebas unitarias.

### 12.4 Rendimiento

- Objetivo: **60 FPS** estables a 1920×1080 en el equipo de la cabina.
- Renderizador `Compatibility` o `Mobile` si el equipo es modesto. Se confirma
  con una prueba en el hardware real antes de elegir.
- Atlas de sprites, sin imágenes sueltas grandes. Texturas de tamaño potencia de
  2 donde aplique.
- Límite de partículas y de enemigos en pantalla definido en recursos.
- Logo del tenant limitado en tamaño al descargarse y guardado en caché local.

### 12.5 Resiliencia

- La terminal nunca debe quedarse en pantalla de error para el cliente. Todo
  fallo de red o de recurso tiene un camino de respaldo.
- Marca: última respuesta válida guardada → tema Kairos embebido.
- Los errores se registran en un archivo local, no se muestran al cliente.
- Un reinicio automático de la aplicación debe volver al menú sin intervención.

## 13. Seguridad visible en el diseño

- La llave privada y el archivo de configuración de la máquina viven fuera del
  proyecto y de cualquier carpeta versionada. Nunca se muestran en pantalla ni
  en registros.
- El menú de desarrollo y el modo de prueba (`F1`) solo existen en compilaciones
  de desarrollo, no en la exportación final.
- La pantalla de resultado no muestra datos del QR ni del JWT en texto.

## 14. Lista de comprobación antes de dar por bueno un diseño

- [ ] Se entiende qué hacer en tres segundos sin leer.
- [ ] Nada entra en el margen seguro de 64 px.
- [ ] Texto de 24 px o más y contraste ≥ 4.5:1.
- [ ] Ningún estado depende solo del color.
- [ ] El foco es visible con borde, escala y marcador.
- [ ] Cada acción tiene respuesta visual y sonora en menos de 100 ms.
- [ ] Un solo botón primario por pantalla.
- [ ] El tenant cambia logo y color; el resto no cambia.
- [ ] Sin red, la marca guardada o la de Kairos aparece sin errores visibles.
- [ ] El QR es negro sobre blanco, de 480 px o más, con margen de 4 módulos.
- [ ] Se sostienen 60 FPS en el equipo de la cabina.
- [ ] Funciona con "Reducir movimiento" activado.
- [ ] Se probó a 1280×720, 1920×1080 y pantalla completa.

## 15. Decisiones abiertas

1. Arte definitivo de la nave, enemigos y fondo, y si se encarga a un ilustrador
   o se genera con un estilo propio y consistente.
2. Música y efectos de sonido definitivos. Mientras tanto, se usan marcadores
   de posición con licencia libre claramente identificada.
3. Si la cabina tendrá pantalla táctil o mando. Cambia los tamaños de objetivo y
   la ayuda de controles.
4. Si "Reducir movimiento" y el volumen se configuran desde el archivo de la
   máquina o desde un menú oculto en la terminal.
5. Renderizador final, según la prueba en el hardware de la cabina.
