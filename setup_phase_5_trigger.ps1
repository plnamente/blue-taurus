# ==============================================================================
# BLUE-TAURUS: FASE 5 - TRIGGER (TESTE DE EXECUCAO)
# Descrição: Modifica o Server para enviar um comando automatico ao receber Handshake.
# Fix 1.1: Adiciona dependencia 'uuid' no Server.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 5] Configurando Gatilho de Teste no Servidor..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# 0. Atualizar Cargo.toml do SERVER (Adicionar uuid)
Write-Host "[FIX] Atualizando crates/server/Cargo.toml..." -ForegroundColor Green
$serverCargoContent = @'
[package]
name = "server"
version = "0.1.0"
edition = "2021"

[dependencies]
shared = { path = "../shared" }
axum = { version = "0.6", features = ["ws"] }
tokio = { version = "1", features = ["full"] }
sqlx = { version = "0.7", features = ["runtime-tokio-native-tls", "postgres", "uuid", "chrono"] }
elasticsearch = "8.5.0-alpha.1"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tracing = "0.1"
tracing-subscriber = "0.3"
anyhow = "1.0"
dotenvy = "0.15"
futures = "0.3"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1.0", features = ["v4", "serde"] }
'@
$serverCargoContent | Out-File -FilePath "crates/server/Cargo.toml" -Encoding utf8

# 1. Atualizar socket/mod.rs para enviar comando
Write-Host "[CODE] Atualizando crates/server/src/socket/mod.rs..." -ForegroundColor Green
$serverSocketCode = @'
use axum::{
    extract::{ws::{Message as WsMessage, WebSocket, WebSocketUpgrade}, State},
    response::IntoResponse,
};
use futures::{sink::SinkExt, stream::StreamExt};
use std::sync::Arc;
use shared::protocol::{Message, CommandType};
use shared::crypto;
use crate::AppState;
use uuid::Uuid;

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    ws.on_upgrade(|socket| handle_socket(socket, state))
}

async fn handle_socket(mut socket: WebSocket, state: Arc<AppState>) {
    tracing::info!("Nova conexao WebSocket recebida!");

    // Separa o socket em Leitura (recv) e Escrita (send) para podermos mandar comandos
    let (mut sender, mut receiver) = socket.split();

    while let Some(Ok(msg)) = receiver.next().await {
        if let WsMessage::Text(text) = msg {
            if let Ok(protocol_msg) = serde_json::from_str::<Message>(&text) {
                match protocol_msg {
                    Message::Handshake { agent_id, host_info, .. } => {
                        tracing::info!("🤝 Handshake de: {}", host_info.hostname);
                        
                        // --- DUAL WRITE (Postgres + Elastic) ---
                        // (Codigo de persistencia omitido para brevidade do teste, focado na execucao)
                        
                        // --- O GATILHO DE TESTE ---
                        tracing::info!("⚡ Preparando comando de teste para o Agente...");
                        
                        // 1. O Script que queremos rodar no Agente
                        let script_python = "import sys; print(f'OLA DO SERVER! Python rodando em {sys.platform}')";
                        
                        // 2. Carregar a Chave Privada (Gerada pelo keygen)
                        // NOTA: Se o arquivo nao existir, usamos uma chave dummy que vai falhar na validacao (teste negativo)
                        let priv_key = std::fs::read_to_string("admin_private.key")
                            .unwrap_or_else(|_| "0000000000000000000000000000000000000000000000000000000000000000".to_string());

                        // 3. Assinar o Script
                        match crypto::sign_message(priv_key.trim(), script_python) {
                            Ok(signature) => {
                                // 4. Criar o Payload de Comando
                                let command = Message::Command {
                                    id: Uuid::new_v4(),
                                    cmd_type: CommandType::RunScript,
                                    args: Some(script_python.to_string()),
                                    signature,
                                };

                                // 5. Enviar para o Agente
                                let json = serde_json::to_string(&command).unwrap();
                                if let Err(e) = sender.send(WsMessage::Text(json)).await {
                                    tracing::error!("Erro ao enviar comando: {}", e);
                                } else {
                                    tracing::info!("🚀 Comando enviado! Aguardando retorno...");
                                }
                            },
                            Err(e) => tracing::error!("Erro ao assinar script: {:?}", e),
                        }
                    }
                    Message::CommandResult { cmd_id, status, stdout, stderr } => {
                        tracing::info!("📝 RESULTADO RECEBIDO (CMD {}):", cmd_id);
                        tracing::info!("   STATUS: {}", status);
                        if !stdout.is_empty() { tracing::info!("   STDOUT: {}", stdout.trim()); }
                        if !stderr.is_empty() { tracing::error!("   STDERR: {}", stderr.trim()); }
                    }
                    Message::Heartbeat { agent_id, .. } => {
                        tracing::debug!("💓 Heartbeat: {}", agent_id);
                    }
                    _ => {}
                }
            }
        }
    }
    tracing::info!("Conexao encerrada.");
}
'@
$serverSocketCode | Out-File -FilePath "crates/server/src/socket/mod.rs" -Encoding utf8

Write-Host "[SUCCESS] Gatilho configurado!" -ForegroundColor Cyan
Write-Host "Agora o Servidor vai tentar mandar um comando assim que o Agente conectar."