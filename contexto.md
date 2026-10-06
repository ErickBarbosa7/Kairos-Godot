# Contexto — Kairos Arcade

## Producto

Kairos es una plataforma de fidelización gamificada B2B2C. Un cliente juega
en una terminal física, obtiene puntos y después los acredita desde la Wallet
de Kairos para canjear premios del negocio.

La terminal Arcade es el tercer proyecto de Kairos. Su papel es atraer al
cliente en el local, ofrecer partidas cortas y generar un QR efímero con el
puntaje al terminar.

## Repositorios

- `Kairos`: monorepo web con API, panel Super Admin, panel del negocio y la
  futura Wallet PWA.
- `Kairos-Godot`: terminal Arcade creada con Godot 4.7.2 y GDScript.

El proyecto de Godot vive en `kairos-arcade/`.

## Actores y flujo

1. El negocio registra una sucursal y una máquina en el panel Kairos.
2. La terminal inicia con el identificador de la sucursal y carga su marca.
3. El cliente elige un juego y juega una partida corta.
4. La terminal genera un QR firmado con el resultado.
5. La Wallet valida el QR y acredita los puntos al cliente.
6. El cliente solicita un premio y el personal lo entrega desde caja.

## Estado actual

- Godot 4.7.2 está instalado.
- El repositorio contiene un proyecto Godot vacío.
- La API ya expone `GET /public/stores/:id/brand`, que devuelve nombre,
  logo, colores y modo de tema de una sucursal activa.
- El panel permite registrar máquinas con llave pública ES256 o EdDSA.
- Aún faltan la firma del QR desde Godot y la validación/acreditación del QR
  desde la futura Wallet.

## Diseño de la terminal

La terminal usa un fondo oscuro de arcade y la marca del tenant como color
principal. Kairos queda como firma secundaria. La interfaz debe conservar el
lenguaje actual: contraste alto, bordes definidos, sombras duras, títulos
pesados y estados explicados con icono y texto.

El QR siempre se muestra negro sobre blanco, con una zona silenciosa de cuatro
módulos, sin colores de marca.

## Restricciones de seguridad

- Cada máquina tiene su propio par de llaves; la API guarda solo la pública.
- La privada vive fuera del repositorio y fuera del paquete versionado.
- El QR llevará `store_id`, `machine_id`, `score`, `iat`, `exp` y `jti`.
- El QR expira en 60 segundos o menos y solo puede acreditarse una vez.
- La terminal nunca decide cuántos puntos Wallet obtiene el cliente; solo
  informa el puntaje crudo. La API calcula y limita los puntos.
