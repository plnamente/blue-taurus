# ==============================================================================
# BLUE-TAURUS: FIX AGENT EXECUTION (WINDOWS)
# Descrição: Ajusta o Agente para tentar multiplos interpretadores (py, python, python3).
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[FIX] Aplicando correcao robusta de Python para Windows..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/agent") { Set-Location $ProjectName }

# 1. Reescrever crates/agent/src/net/mod.rs com deteccao de OS
Write-Host "[CODE] Atualizando crates/agent/src/net/mod.rs..." -ForegroundColor Green

# Nota: Precisamos ler a chave publica atual para nao perde-la
$CurrentFile = Get-Content "crates/agent/src/net/mod.rs" -Raw
$PublicKeyLine = $CurrentFile | Select-String 'const ADMIN_PUBLIC_KEY: &str = "(.*)";'
$CurrentKey = "CHAVE_PUBLICA_AQUI"

if ($PublicKeyLine) {
    $CurrentKey = $PublicKeyLine.Matches.Groups[1].Value
    Write-Host " -> Chave Publica preservada: $CurrentKey" -ForegroundColor Yellow
} else {
    Write-Host " -> AVISO: Chave publica nao encontrada, usando placeholder." -ForegroundColor Red
}

$agentNetUpdate = @"
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

// CHAVE PUBLICA DO ADMIN
const ADMIN_PUBLIC_KEY: &str = "$CurrentKey"; 

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

                // 2. Loop Principal
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
                                        
                                        let script_content = args.unwrap_or_default();
                                        
                                        // A. VERIFICACAO DE SEGURANCA
                                        let is_valid = if ADMIN_PUBLIC_KEY == "CHAVE_PUBLICA_AQUI" {
                                            tracing::warn!("⚠️  MODO DEV: Validacao de assinatura ignorada");
                                            true 
                                        } else {
                                            match crypto::verify_signature(ADMIN_PUBLIC_KEY, &script_content, &signature) {
                                                Ok(true) => true,
                                                Ok(false) | Err(_) => false,
                                            }
                                        };

                                        if is_valid {
                                            tracing::info!("🔒 Assinatura VALIDA. Executando...");
                                            
                                            // B. EXECUCAO (ROBUSTA)
                                            // Tenta varios comandos ate um funcionar
                                            let candidates = if cfg!(target_os = "windows") {
                                                vec!["py", "python", "python3"]
                                            } else {
                                                vec!["python3", "python"]
                                            };

                                            let mut status = "FAILED".to_string();
                                            let mut stdout = String::new();
                                            let mut stderr = String::new();

                                            for cmd in candidates {
                                                // Tenta executar
                                                match Command::new(cmd).arg("-c").arg(&script_content).output() {
                                                    Ok(o) => {
                                                        if o.status.success() {
                                                            // SUCESSO! Paramos de tentar.
                                                            status = "SUCCESS".to_string();
                                                            stdout = String::from_utf8_lossy(&o.stdout).to_string();
                                                            stderr = String::from_utf8_lossy(&o.stderr).to_string();
                                                            break;
                                                        } else {
                                                            // Falhou (ex: erro da loja). Guardamos o erro mas tentamos o proximo.
                                                            stderr = String::from_utf8_lossy(&o.stderr).to_string();
                                                        }
                                                    },
                                                    Err(_) => continue, // Binario nao encontrado, tenta proximo
                                                }
                                            }
                                            
                                            if status == "FAILED" && stderr.is_empty() {
                                                stderr = "Nenhum interpretador Python valido encontrado no PATH.".to_string();
                                            }

                                            if status == "SUCCESS" {
                                                tracing::info!("✅ Sucesso: {}", stdout.trim());
                                            } else {
                                                tracing::error!("❌ Falha: {}", stderr.trim());
                                            }
                                            
                                            // C. RETORNO
                                            let result = Message::CommandResult {
                                                cmd_id: id,
                                                status: status,
                                                stdout,
                                                stderr,
                                            };
                                            let _ = write.send(WsMessage::Text(serde_json::to_string(&result).unwrap())).await;

                                        } else {
                                            tracing::error!("⛔ ALERTA DE SEGURANCA: Assinatura INVALIDA!");
                                        }
                                    }
                                }
                                Some(Err(_)) | None => break, 
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
"@
$agentNetUpdate | Out-File -FilePath "crates/agent/src/net/mod.rs" -Encoding utf8

Write-Host "[SUCCESS] Agente atualizado com logica de tentativa multipla." -ForegroundColor Cyan