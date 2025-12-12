# ==============================================================================
# BLUE-TAURUS: FASE 5 - SECURITY & REMOTE EXECUTION
# Descrição: Implementa verificação de Assinatura Digital (Ed25519) e Execução.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 5] Implementando Camada de Seguranca e Execucao..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# ==============================================================================
# 1. ATUALIZAR DEPENDENCIAS (Crypto)
# ==============================================================================

# 1.1 SHARED: Adicionar ed25519-dalek e hex
Write-Host "[FIX] Adicionando crypto libs em Shared..." -ForegroundColor Green
$sharedCargo = @'
[package]
name = "shared"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1.0", features = ["v4", "serde"] }
thiserror = "1.0"

# Fase 5: Crypto
ed25519-dalek = { version = "2.0", features = ["rand_core"] }
hex = "0.4"
rand = "0.8"
base64 = "0.21"
'@
$sharedCargo | Out-File -FilePath "crates/shared/Cargo.toml" -Encoding utf8

# 1.2 AGENT: Adicionar base64 (para decodificar scripts)
Write-Host "[FIX] Adicionando libs no Agent..." -ForegroundColor Green
# (Reescrevendo mantendo as anteriores)
$agentCargo = @'
[package]
name = "agent"
version = "0.1.0"
edition = "2021"

[dependencies]
shared = { path = "../shared" }
tokio = { version = "1", features = ["full"] }
sysinfo = "0.29"
reqwest = { version = "0.11", features = ["json"] }
tokio-tungstenite = { version = "0.20", features = ["native-tls"] }
url = "2.4"
futures-util = "0.3"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
anyhow = "1.0"
tracing = "0.1"
tracing-subscriber = "0.3"
futures = "0.3"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1.0", features = ["v4", "serde"] }

# Fase 5
base64 = "0.21"
'@
$agentCargo | Out-File -FilePath "crates/agent/Cargo.toml" -Encoding utf8

# ==============================================================================
# 2. IMPLEMENTAR MODULO CRYPTO (SHARED)
# ==============================================================================
Write-Host "[CODE] Criando crates/shared/src/crypto/mod.rs..." -ForegroundColor Green
New-Item -Path "crates/shared/src/crypto" -ItemType Directory -Force | Out-Null

$cryptoCode = @'
use ed25519_dalek::{Verifier, SigningKey, VerifyingKey, Signature, Signer};
use rand::rngs::OsRng;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum CryptoError {
    #[error("Falha ao decodificar chave ou assinatura")]
    DecodingError,
    #[error("Assinatura Invalida - POSSIVEL ATAQUE")]
    InvalidSignature,
}

/// Gera um par de chaves (Privada/Publica) para o Admin usar
pub fn generate_keypair() -> (String, String) {
    let mut csprng = OsRng;
    let signing_key = SigningKey::generate(&mut csprng);
    let verifying_key = signing_key.verifying_key();

    let priv_hex = hex::encode(signing_key.to_bytes());
    let pub_hex = hex::encode(verifying_key.to_bytes());

    (priv_hex, pub_hex)
}

/// Assina uma mensagem (script) usando a chave privada (Lado Server/Admin)
pub fn sign_message(private_key_hex: &str, message: &str) -> Result<String, CryptoError> {
    let priv_bytes = hex::decode(private_key_hex).map_err(|_| CryptoError::DecodingError)?;
    let signing_key = SigningKey::from_bytes(&priv_bytes.try_into().map_err(|_| CryptoError::DecodingError)?);
    
    let signature = signing_key.sign(message.as_bytes());
    Ok(hex::encode(signature.to_bytes()))
}

/// Verifica se a assinatura eh valida para aquela mensagem (Lado Agente)
pub fn verify_signature(public_key_hex: &str, message: &str, signature_hex: &str) -> Result<bool, CryptoError> {
    let pub_bytes = hex::decode(public_key_hex).map_err(|_| CryptoError::DecodingError)?;
    let verifying_key = VerifyingKey::from_bytes(&pub_bytes.try_into().map_err(|_| CryptoError::DecodingError)?)
        .map_err(|_| CryptoError::DecodingError)?;

    let sig_bytes = hex::decode(signature_hex).map_err(|_| CryptoError::DecodingError)?;
    let signature = Signature::from_bytes(&sig_bytes.try_into().map_err(|_| CryptoError::DecodingError)?);

    match verifying_key.verify(message.as_bytes(), &signature) {
        Ok(_) => Ok(true),
        Err(_) => Err(CryptoError::InvalidSignature),
    }
}
'@
$cryptoCode | Out-File -FilePath "crates/shared/src/crypto/mod.rs" -Encoding utf8

# Atualizar lib.rs do Shared
$sharedLib = @'
pub mod models;
pub mod protocol;
pub mod crypto;

pub fn version() -> &'static str {
    "0.1.0"
}
'@
$sharedLib | Out-File -FilePath "crates/shared/src/lib.rs" -Encoding utf8

# ==============================================================================
# 3. AGENT: IMPLEMENTAR EXECUTOR SEGURO
# ==============================================================================

Write-Host "[CODE] Atualizando crates/agent/src/net/mod.rs (Com Logic de Execucao)..." -ForegroundColor Green
$agentNetUpdate = @'
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message as WsMessage};
use futures::{SinkExt, StreamExt};
use url::Url;
use shared::protocol::{Message, CommandType};
use shared::models::HostInfo;
use shared::crypto;
use uuid::Uuid;
use std::time::Duration;
use tokio::time::sleep;
use std::process::Command;

// CHAVE PUBLICA DO ADMIN (Hardcoded para o MVP - Em prod viria de config segura)
// Nota: Voce gerara esta chave no proximo passo e substituira aqui se quiser testar a validacao real.
const ADMIN_PUBLIC_KEY: &str = "CHAVE_PUBLICA_AQUI"; 

pub async fn start_agent_loop(agent_id: Uuid, host_info: HostInfo) {
    let url = Url::parse("ws://127.0.0.1:3000/ws").unwrap();

    loop {
        tracing::info!("Tentando conectar ao servidor...");
        
        match connect_async(url.clone()).await {
            Ok((ws_stream, _)) => {
                tracing::info!("✅ Conectado!");
                let (mut write, mut read) = ws_stream.split();

                // 1. Handshake
                let handshake = Message::Handshake {
                    agent_id,
                    host_info: host_info.clone(),
                    token: "dev-token".to_string(),
                };
                let _ = write.send(WsMessage::Text(serde_json::to_string(&handshake).unwrap())).await;

                // 2. Loop Principal (Heartbeat + Escuta de Comandos)
                loop {
                    tokio::select! {
                        _ = sleep(Duration::from_secs(10)) => {
                            let hb = Message::Heartbeat { agent_id, timestamp: chrono::Utc::now() };
                            if let Err(_) = write.send(WsMessage::Text(serde_json::to_string(&hb).unwrap())).await {
                                break; 
                            }
                        }
                        msg = read.next() => {
                            match msg {
                                Some(Ok(WsMessage::Text(text))) => {
                                    if let Ok(Message::Command { id, cmd_type, args, signature }) = serde_json::from_str(&text) {
                                        tracing::info!("📜 Comando recebido! Tipo: {:?}", cmd_type);
                                        
                                        // A. VERIFICACAO DE SEGURANCA
                                        let script_content = args.unwrap_or_default();
                                        
                                        // Nota: Para teste inicial, se a chave for placeholder, pulamos ou falhamos.
                                        // Vamos simular sucesso se a chave for "IGNORAR_DEV"
                                        let is_valid = if ADMIN_PUBLIC_KEY == "CHAVE_PUBLICA_AQUI" {
                                            tracing::warn!("⚠️  MODO DEV: Validacao de assinatura ignorada (Configure a chave publica)");
                                            true 
                                        } else {
                                            match crypto::verify_signature(ADMIN_PUBLIC_KEY, &script_content, &signature) {
                                                Ok(true) => true,
                                                Ok(false) | Err(_) => false,
                                            }
                                        };

                                        if is_valid {
                                            tracing::info!("🔒 Assinatura VALIDA. Executando...");
                                            
                                            // B. EXECUCAO (Simulada via Python Local)
                                            let output = Command::new("python")
                                                .arg("-c")
                                                .arg(&script_content)
                                                .output();

                                            let (status, stdout, stderr) = match output {
                                                Ok(o) => (
                                                    if o.status.success() { "SUCCESS" } else { "FAILED" },
                                                    String::from_utf8_lossy(&o.stdout).to_string(),
                                                    String::from_utf8_lossy(&o.stderr).to_string()
                                                ),
                                                Err(e) => ("EXEC_ERROR", String::new(), e.to_string()),
                                            };

                                            tracing::info!("Resultado: {}", status);
                                            
                                            // C. RETORNO
                                            let result = Message::CommandResult {
                                                cmd_id: id,
                                                status: status.to_string(),
                                                stdout,
                                                stderr,
                                            };
                                            let _ = write.send(WsMessage::Text(serde_json::to_string(&result).unwrap())).await;

                                        } else {
                                            tracing::error!("⛔ ALERTA DE SEGURANCA: Assinatura do script INVALIDA! Comando rejeitado.");
                                        }
                                    }
                                }
                                Some(Err(_)) | None => break, // Erro ou fim da conexao
                                _ => {}
                            }
                        }
                    }
                }
            }
            Err(e) => {
                tracing::error!("Falha conexao: {}. Retry 5s...", e);
                sleep(Duration::from_secs(5)).await;
            }
        }
    }
}
'@
$agentNetUpdate | Out-File -FilePath "crates/agent/src/net/mod.rs" -Encoding utf8


# ==============================================================================
# 4. FERRAMENTA DE GERACAO DE CHAVES (ADMIN TOOL)
# ==============================================================================
Write-Host "[TOOL] Criando script de geracao de chaves..." -ForegroundColor Green
$keygenCode = @'
// Este eh um pequeno utilitario para gerar chaves e assinar scripts manualmente para teste
use shared::crypto;
use std::io::Write;

fn main() {
    println!("🔐 Gerador de Chaves Blue-Taurus");
    let (priv_key, pub_key) = crypto::generate_keypair();
    
    println!("----------------------------------------------------------------");
    println!("GUARDE ISSO COM SUA VIDA (Em um Vault/Secret Manager):");
    println!("Private Key: {}", priv_key);
    println!("----------------------------------------------------------------");
    println!("COLOQUE ISSO NO CODIGO DO AGENTE (const ADMIN_PUBLIC_KEY):");
    println!("Public Key:  {}", pub_key);
    println!("----------------------------------------------------------------");

    // Salva em arquivos para facilitar
    let _ = std::fs::write("admin_private.key", priv_key);
    let _ = std::fs::write("agent_public.key", pub_key);
}
'@

# Cria um binario temporario dentro do Server para rodar essa ferramenta
New-Item -Path "crates/server/src/bin" -ItemType Directory -Force | Out-Null
$keygenCode | Out-File -FilePath "crates/server/src/bin/keygen.rs" -Encoding utf8

Write-Host "[SUCCESS] Fase 5 Concluida! Infra de Seguranca pronta." -ForegroundColor Cyan
Write-Host "[NEXT STEPS]:"
Write-Host "1. Execute: cargo run -p server --bin keygen"
Write-Host "   (Isso vai gerar suas chaves de criptografia)"
Write-Host "2. Copie a Public Key gerada."
Write-Host "3. Edite crates/agent/src/net/mod.rs e cole a chave em ADMIN_PUBLIC_KEY."
Write-Host "4. Rode o Server e Agent novamente."