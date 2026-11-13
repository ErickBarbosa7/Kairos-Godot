# Actualizaciones de Kairos Arcade

Kairos Arcade se distribuye en Linux y Windows con un launcher externo. macOS está pendiente y no se publica desde este flujo.

## Diseño

El launcher inicia el juego activo desde `versions/<versión>/`, consulta un manifiesto HTTPS y descarga una nueva versión solo cuando el juego ya no se está ejecutando. La actualización se descomprime en una carpeta temporal, se verifica y se mueve a su versión final antes de marcarla como activa. Si falla, `launcher.json` sigue apuntando a la versión anterior.

El launcher no actualiza su propio binario. Una actualización de launcher se entrega mediante el instalador, lo que evita intentar reemplazar un ejecutable en uso.

```text
instalación/
├── KairosArcadeLauncher[.exe]
├── launcher.json
└── versions/
    ├── 0.1.0/KairosArcade[.x86_64|.exe]
    └── 0.2.0/KairosArcade[.x86_64|.exe]
```

Los datos de máquina, llave privada, marcador y caché permanecen fuera de estas carpetas, en `user://`. Nunca se incluyen en un ZIP de actualización.

## Manifiesto firmado

El servidor publica `manifest.json` y `manifest.json.sig`. La firma Ed25519 se calcula sobre los bytes exactos de `manifest.json`; por eso no debe reformatearse después de firmarlo.

```json
{
  "version": "0.2.0",
  "artifacts": {
    "linux-x86_64": { "url": "https://updates.example/arcade/0.2.0/kairos-linux.zip", "sha256": "…", "size": 123 },
    "windows-x86_64": { "url": "https://updates.example/arcade/0.2.0/kairos-windows.zip", "sha256": "…", "size": 456 }
  }
}
```

Cada ZIP contiene el ejecutable y los archivos exportados de Godot en su raíz. La clave privada solo vive en el equipo de publicación o en secretos de CI. La clave pública Base64 de 32 bytes vive en `launcher.json`.

## Publicar una versión

1. Genera una vez las llaves fuera del repositorio:

   ```sh
   node tools/update/create-key.mjs ~/.config/kairos-arcade-updates/key
   ```

2. Compila el launcher para Linux y Windows desde `updater/` con Rust. Puedes ejecutar `cargo build --release --manifest-path updater/Cargo.toml` o lanzar el flujo de GitHub Actions **Compilar launcher**; sus artefactos son los binarios a distribuir mediante el instalador, no como actualización de juego.
3. Exporta Godot para Linux y Windows, empaqueta cada export en un ZIP y conserva el ejecutable en la raíz del ZIP.
4. Crea y firma el manifiesto:

   ```sh
   node tools/update/publish.mjs \
     --version=0.2.0 \
     --base-url=https://updates.tu-dominio.com/arcade \
     --private-key=$HOME/.config/kairos-arcade-updates/key.private.pem \
     --linux=builds/kairos-linux-x86_64.zip \
     --windows=builds/kairos-windows-x86_64.zip \
     --out=builds/release
   ```

5. Sube los dos ZIP, `manifest.json` y `manifest.json.sig` a la ruta indicada por el manifiesto.

## launcher.json inicial

```json
{
  "current_version": "0.1.0",
  "previous_version": null,
  "manifest_url": "https://updates.tu-dominio.com/arcade/stable/manifest.json",
  "public_key_b64": "PEGA_AQUÍ_LA_CLAVE_PÚBLICA",
  "game_args": []
}
```

Ejecuta `KairosArcadeLauncher --root <carpeta-instalación> run` para actualizar al abrir y reiniciar el juego tras un fallo. Usa `check` para instalar una actualización sin iniciar una partida y `rollback` para volver a la versión anterior.
