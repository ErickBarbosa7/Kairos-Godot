# Sección de descarga: Kairos Arcade

## Objetivo

Presentar la Terminal Arcade como una herramienta para negocios de Kairos. La sección se dirige a administradores de empresas que quieren instalar una terminal, no a las personas que canjean premios en la Wallet.

Debe aparecer después de la explicación del producto y antes del formulario de contacto o cierre de la landing.

## Contenido

**Etiqueta:** `TERMINAL PARA NEGOCIOS`

**Título:** `Convierte cada visita en una partida.`

**Texto:**

> Instala Kairos Arcade en tu negocio. Tus clientes juegan, alcanzan una meta y reciben un código para girar la ruleta y reclamar su recompensa desde Kairos.

**Beneficios:**

- Juegos cortos para jugar en el punto de venta.
- Recompensas vinculadas a cada sucursal.
- QR temporal y seguro para continuar en el teléfono.
- Marca, colores y catálogo adaptados a cada negocio.
- Actualizaciones para mantener la terminal al día.

## Acciones de descarga

| Plataforma | Botón | Estado inicial | Destino |
| --- | --- | --- | --- |
| Windows | `Descargar para Windows` | Disponible al publicar el instalador | `KairosArcade-Setup.exe` |
| Linux | `Descargar para Linux` | Disponible al publicar el paquete | Guía o paquete Linux x86_64 |
| macOS | `Próximamente para macOS` | Deshabilitado | Sin descarga |

Debajo de los botones debe leerse:

> Para negocios Kairos. Después de instalar, vincula la terminal con tu cuenta y sucursal.

No se deben publicar archivos de configuración de máquinas, llaves privadas ni URLs internas de API. Cada instalación se vincula desde la propia aplicación.

## Video demo

Mostrar un video corto, sin audio obligatorio y con subtítulos, a la derecha del texto en escritorio. En móvil va antes de los botones de descarga.

**Duración:** 25 a 30 segundos.

| Tiempo | Toma | Texto en pantalla |
| --- | --- | --- |
| 0–3 s | Logotipo y pantalla de bienvenida | `KAIROS ARCADE` |
| 3–7 s | Menú con los seis juegos | `Elige un juego` |
| 7–15 s | Cortes rápidos de Defensa Estelar, Memory Rush, Lane Racer, Stack Tower y Ruta Nebular | `Juega. Supera la meta.` |
| 15–21 s | Resultado de una partida y ruleta de recompensa | `Gana una recompensa` |
| 21–25 s | QR en pantalla y teléfono simulando el escaneo | `Continúa en tu teléfono` |
| 25–30 s | Vuelta a la terminal y llamada a la acción | `Instala Kairos Arcade en tu negocio` |

El video no debe mostrar credenciales, IDs de sucursal, llaves de máquina, una URL local ni información real de clientes.

### Archivos para la landing

```text
public/
└── arcade/
    ├── kairos-arcade-demo.webm
    ├── kairos-arcade-demo.mp4
    ├── kairos-arcade-demo-poster.webp
    └── kairos-arcade-demo.vtt
```

- `webm` es el video principal.
- `mp4` es el respaldo para navegadores que no reproduzcan WebM.
- `poster.webp` se muestra antes de reproducir.
- `vtt` contiene subtítulos en español.
- El video debe iniciar silenciado, reproducirse automáticamente solo si está visible y respetar `prefers-reduced-motion`; con movimiento reducido se muestra el póster y un botón de reproducir.

## Estado de lanzamiento

Antes de habilitar el botón de Windows, publicar el instalador `.exe` firmado. Antes de habilitar Linux, publicar un paquete versionado y una guía de instalación. La sección puede salir primero con ambas descargas como `Próximamente` y el video demo activo.

## Criterios de aceptación

- La sección es clara para una empresa que nunca ha usado Kairos.
- Cada descarga identifica sistema operativo y versión.
- Las descargas no exponen secretos ni configuraciones de otras máquinas.
- El video tiene póster, subtítulos y alternativa sin reproducción automática.
- Los botones se ven y funcionan correctamente en móvil y escritorio.
