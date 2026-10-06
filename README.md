# Kairos-Godot

Terminal Arcade de **Kairos**, desarrollada con Godot 4.7.2 y GDScript. Consume la API del repositorio principal de Kairos y forma parte de la tercera etapa de la plataforma de fidelización B2B2C.

La experiencia permite que una persona juegue en una terminal, obtenga un QR temporal al finalizar y lo canjee después en la Wallet PWA por puntos y premios. El proyecto de Godot vive en [`kairos-arcade/`](kairos-arcade/).

## Estado

El menú Arcade presenta tres juegos:

| Juego | Estado | Descripción |
| --- | --- | --- |
| Defensa Estelar | Disponible | Shooter espacial vertical con oleadas, puntaje y pantalla de resultado. |
| Fiebre de Monedas | EN PROCESO | Próximo juego del catálogo. |
| Ruta Nebular | EN PROCESO | Próximo juego del catálogo. |

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
3. Juega una partida de Defensa Estelar y obtiene un resultado.
4. La siguiente integración generará un QR temporal firmado para que la Wallet PWA canjee los puntos.

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
  "dev_mode": false,
  "reduce_motion": false
}
```

`reduce_motion` quita la sacudida de cámara, reduce las partículas y detiene el fondo animado.

Este archivo y cualquier llave privada (`*.pem`) viven fuera del repositorio y
están en `.gitignore`. Nunca se guardan dentro de `kairos-arcade/`.

La marca de una sucursal se obtiene mediante:

```text
GET /public/stores/:store_id/brand
```

La integración del QR deberá firmar comprobantes de corta duración con los identificadores de tienda y máquina, el puntaje, emisión, expiración e identificador único. La Wallet validará la firma y rechazará comprobantes vencidos o ya usados. Ninguna clave privada debe entrar al repositorio.

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
