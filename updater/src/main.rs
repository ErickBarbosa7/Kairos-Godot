use anyhow::{bail, Context, Result};
use base64::{engine::general_purpose::STANDARD, Engine};
use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use reqwest::blocking::Client;
use semver::Version;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{env, fs, io::{Cursor, Read}, path::{Path, PathBuf}, process::{Command, ExitCode}, thread, time::Duration};
use zip::ZipArchive;

const CONFIG_NAME: &str = "launcher.json";

#[derive(Debug, Deserialize)]
struct Manifest {
    version: Version,
    artifacts: std::collections::HashMap<String, Artifact>,
}

#[derive(Debug, Deserialize)]
struct Artifact {
    url: String,
    sha256: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct Config {
    current_version: String,
    previous_version: Option<String>,
    manifest_url: String,
    /// Clave pública Ed25519 de 32 bytes codificada en Base64.
    public_key_b64: String,
    game_args: Vec<String>,
}

fn platform() -> &'static str {
    #[cfg(target_os = "windows")]
    { "windows-x86_64" }
    #[cfg(target_os = "linux")]
    { "linux-x86_64" }
    #[cfg(not(any(target_os = "windows", target_os = "linux")))]
    { "unsupported" }
}

fn executable_name() -> &'static str {
    #[cfg(target_os = "windows")]
    { "KairosArcade.exe" }
    #[cfg(target_os = "linux")]
    { "KairosArcade.x86_64" }
    #[cfg(not(any(target_os = "windows", target_os = "linux")))]
    { "KairosArcade" }
}

fn config_path(root: &Path) -> PathBuf { root.join(CONFIG_NAME) }

fn read_config(root: &Path) -> Result<Config> {
    let path = config_path(root);
    let text = fs::read_to_string(&path).with_context(|| format!("No se pudo leer {}", path.display()))?;
    serde_json::from_str(&text).context("launcher.json no es válido")
}

fn write_config(root: &Path, config: &Config) -> Result<()> {
    let target = config_path(root);
    let temporary = target.with_extension("json.new");
    let data = serde_json::to_vec_pretty(config)?;
    fs::write(&temporary, data)?;
    fs::rename(temporary, target)?;
    Ok(())
}

fn http() -> Result<Client> {
    Ok(Client::builder().https_only(true).timeout(Duration::from_secs(60)).build()?)
}

fn download(client: &Client, url: &str) -> Result<Vec<u8>> {
    let response = client.get(url).send()?.error_for_status()?;
    Ok(response.bytes()?.to_vec())
}

fn verify_manifest(bytes: &[u8], signature: &[u8], public_key_b64: &str) -> Result<()> {
    let key_bytes = STANDARD.decode(public_key_b64).context("La clave pública no está en Base64")?;
    let key_array: [u8; 32] = key_bytes.try_into().map_err(|_| anyhow::anyhow!("La clave pública debe medir 32 bytes"))?;
    let signature_bytes = STANDARD.decode(signature).context("La firma del manifiesto no está en Base64")?;
    let signature = Signature::from_slice(&signature_bytes).context("La firma debe medir 64 bytes")?;
    VerifyingKey::from_bytes(&key_array)?.verify(bytes, &signature).context("La firma del manifiesto no es válida")
}

fn verify_hash(bytes: &[u8], expected: &str) -> Result<()> {
    let actual = hex::encode(Sha256::digest(bytes));
    if actual.eq_ignore_ascii_case(expected) { Ok(()) } else { bail!("El SHA-256 del paquete no coincide") }
}

fn unpack(bytes: &[u8], destination: &Path) -> Result<()> {
    let mut archive = ZipArchive::new(Cursor::new(bytes)).context("El paquete no es un ZIP válido")?;
    for index in 0..archive.len() {
        let mut entry = archive.by_index(index)?;
        let Some(relative) = entry.enclosed_name().map(PathBuf::from) else { bail!("El ZIP contiene una ruta insegura") };
        let target = destination.join(relative);
        if entry.is_dir() {
            fs::create_dir_all(&target)?;
            continue;
        }
        if let Some(parent) = target.parent() { fs::create_dir_all(parent)?; }
        let mut output = fs::File::create(&target)?;
        std::io::copy(&mut entry, &mut output)?;
    }
    Ok(())
}

fn game_path(root: &Path, version: &str) -> PathBuf {
    root.join("versions").join(version).join(executable_name())
}

fn apply_update(root: &Path, config: &mut Config) -> Result<bool> {
    if platform() == "unsupported" { bail!("Este launcher solo se distribuye para Linux y Windows") }
    let client = http()?;
    let manifest_bytes = download(&client, &config.manifest_url)?;
    let signature_url = format!("{}.sig", config.manifest_url);
    let signature = download(&client, &signature_url)?;
    verify_manifest(&manifest_bytes, &signature, &config.public_key_b64)?;
    let manifest: Manifest = serde_json::from_slice(&manifest_bytes).context("El manifiesto firmado no es JSON válido")?;
    let installed = Version::parse(&config.current_version).context("current_version no es semver")?;
    if manifest.version <= installed { return Ok(false); }
    let artifact = manifest.artifacts.get(platform()).with_context(|| format!("No existe paquete para {}", platform()))?;
    let package = download(&client, &artifact.url)?;
    verify_hash(&package, &artifact.sha256)?;

    let versions = root.join("versions");
    fs::create_dir_all(&versions)?;
    let staging = tempfile::Builder::new().prefix(".staging-").tempdir_in(&versions)?;
    unpack(&package, staging.path())?;
    let executable = staging.path().join(executable_name());
    if !executable.is_file() { bail!("El paquete no contiene {} en su raíz", executable_name()) }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut permissions = fs::metadata(&executable)?.permissions();
        permissions.set_mode(0o755);
        fs::set_permissions(&executable, permissions)?;
    }
    let version = manifest.version.to_string();
    let final_dir = versions.join(&version);
    if final_dir.exists() { bail!("La versión {} ya existe", version) }
    fs::rename(staging.keep(), &final_dir)?;
    config.previous_version = Some(config.current_version.clone());
    config.current_version = version;
    write_config(root, config)?;
    println!("Actualizado a {}", config.current_version);
    Ok(true)
}

fn rollback(root: &Path, config: &mut Config) -> Result<()> {
    let previous = config.previous_version.clone().context("No hay una versión anterior disponible")?;
    if !game_path(root, &previous).is_file() { bail!("La versión anterior ya no está instalada") }
    let current = std::mem::replace(&mut config.current_version, previous);
    config.previous_version = Some(current);
    write_config(root, config)?;
    println!("Se restauró {}", config.current_version);
    Ok(())
}

fn launch(root: &Path, config: &Config) -> Result<ExitCode> {
    let executable = game_path(root, &config.current_version);
    if !executable.is_file() { bail!("No existe la versión activa: {}", executable.display()) }
    let status = Command::new(executable).args(&config.game_args).current_dir(root).status()?;
    Ok(ExitCode::from(status.code().unwrap_or(1) as u8))
}

fn usage() {
    eprintln!("Uso: kairos-arcade-launcher [--root RUTA] [run|check|rollback]");
}

fn main() -> Result<ExitCode> {
    let mut arguments = env::args().skip(1);
    let mut root = env::current_exe()?.parent().context("El launcher no tiene carpeta")?.to_path_buf();
    let mut command = "run".to_string();
    while let Some(argument) = arguments.next() {
        if argument == "--root" { root = PathBuf::from(arguments.next().context("Falta ruta después de --root")?); }
        else if ["run", "check", "rollback"].contains(&argument.as_str()) { command = argument; }
        else { usage(); bail!("Argumento desconocido: {}", argument); }
    }
    let mut config = read_config(&root)?;
    match command.as_str() {
        "rollback" => { rollback(&root, &mut config)?; Ok(ExitCode::SUCCESS) }
        "check" => { let changed = apply_update(&root, &mut config)?; println!("{}", if changed { "Hay una versión nueva instalada" } else { "Ya está actualizado" }); Ok(ExitCode::SUCCESS) }
        "run" => {
            if let Err(error) = apply_update(&root, &mut config) { eprintln!("No se pudo actualizar: {error:#}. Se iniciará la versión actual."); }
            loop {
                let code = launch(&root, &config)?;
                if code == ExitCode::SUCCESS { return Ok(code); }
                thread::sleep(Duration::from_secs(3));
            }
        }
        _ => unreachable!(),
    }
}
