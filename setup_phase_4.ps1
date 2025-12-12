# ==============================================================================
# BLUE-TAURUS: FASE 4 - NETWORKING & INGESTION
# Descrição: Implementa WebSocket (Server/Agent) e Ingestão Dual-Write (PG+Elastic).
# Fix 1.2: Adiciona dependencias 'futures' e 'chrono' explicitamente no Server e Agent.
# Fix 1.3: Adiciona dependencia 'uuid' no Agent (faltou na versao anterior).
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 4] Conectando Agente ao Servidor (WebSocket + Dual Write)..." -ForegroundColor Cyan

# Garante que estamos na raiz ou entra nela
if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# ==============================================================================
# 0. DEPENDENCIAS (Correção de Build)
# ==============================================================================

# 0.1 Atualizar Cargo.toml do SERVER (Adicionar futures e chrono)
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

# Adicionado na Fase 4
futures = "0.3"
chrono = { version = "0.4", features = ["serde"] }
'@
$serverCargoContent | Out-File -FilePath "crates/server/Cargo.toml" -Encoding utf8

# 0.2 Atualizar Cargo.toml do AGENT (Adicionar futures, chrono e UUID)
Write-Host "[FIX] Atualizando crates/agent/Cargo.toml..." -ForegroundColor Green
$agentCargoContent = @'
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

# Adicionado na Fase 4
futures = "0.3"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1.0", features = ["v4", "serde"] }
'@
$agentCargoContent | Out-File -FilePath "crates/agent/Cargo.toml" -Encoding utf8


# ==============================================================================
# 1. SERVER SIDE: Lógica de Ingestão
# ==============================================================================

# 1.1 Modulo de WebSocket (Recebe dados e processa)
Write-Host "[CODE] Criando crates/server/src/socket/mod.rs..." -ForegroundColor Green
New-Item -Path "crates/server/src/socket" -ItemType Directory -Force | Out-Null

$serverSocketCode = @'
use axum::{
    extract::{ws::{Message as WsMessage, WebSocket, WebSocketUpgrade}, State},
    response::IntoResponse,
};
use futures::{sink::SinkExt, stream::StreamExt};
use std::sync::Arc;
use shared::protocol::Message;
use crate::AppState;

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    ws.on_upgrade(|socket| handle_socket(socket, state))
}

async fn handle_socket(mut socket: WebSocket, state: Arc<AppState>) {
    tracing::info!("Nova conexao WebSocket recebida!");

    while let Some(Ok(msg)) = socket.recv().await {
        if let WsMessage::Text(text) = msg {
            // Deserializa mensagem do Agente
            if let Ok(protocol_msg) = serde_json::from_str::<Message>(&text) {
                match protocol_msg {
                    Message::Handshake { agent_id, host_info, .. } => {
                        tracing::info!("Handshake recebido de: {}", host_info.hostname);
                        
                        // 1. Dual-Write: Postgres (Update/Insert Agent)
                        let _ = sqlx::query!(
                            r#"
                            INSERT INTO agents (id, hostname, os_name, os_version, kernel_version, arch, ip_address, status)
                            VALUES ($1, $2, $3, $4, $5, $6, $7, 'ONLINE')
                            ON CONFLICT (id) DO UPDATE SET 
                                hostname = EXCLUDED.hostname,
                                last_seen_at = NOW(),
                                status = 'ONLINE'
                            "#,
                            agent_id,
                            host_info.hostname,
                            host_info.os_name,
                            host_info.os_version,
                            host_info.kernel_version,
                            host_info.arch,
                            "127.0.0.1" // Placeholder para IP real
                        )
                        .execute(&state.pg_pool)
                        .await
                        .map_err(|e| tracing::error!("Falha no Postgres: {}", e));

                        // 2. Dual-Write: Elasticsearch (Indexa evento de conexao)
                        let _ = state.elastic_client
                            .index(elasticsearch::IndexParts::Index("bt-logs-v1"))
                            .body(serde_json::json!({
                                "@timestamp": chrono::Utc::now(),
                                "event_type": "handshake",
                                "agent_id": agent_id,
                                "hostname": host_info.hostname
                            }))
                            .send()
                            .await
                            .map_err(|e| tracing::error!("Falha no Elastic: {}", e));
                    }
                    Message::InventoryReport { agent_id, software } => {
                        tracing::info!("Inventario recebido de {} ({} itens)", agent_id, software.len());
                        // Aqui implementariamos a gravacao do software...
                    }
                    Message::Heartbeat { agent_id, .. } => {
                        tracing::debug!("Heartbeat de {}", agent_id);
                    }
                    _ => {}
                }
            }
        }
    }
    tracing::info!("Conexao WebSocket encerrada.");
}
'@
$serverSocketCode | Out-File -FilePath "crates/server/src/socket/mod.rs" -Encoding utf8

# 1.2 Atualizar Main do Server (Conectar Elastic + Rotas WS)
Write-Host "[CODE] Atualizando crates/server/src/main.rs..." -ForegroundColor Green
$serverMainCode = @'
mod socket;

use axum::{routing::get, Router};
use sqlx::postgres::{PgPool, PgPoolOptions};
use elasticsearch::Elasticsearch;
use elasticsearch::http::transport::Transport;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use dotenvy::dotenv;

// Estado compartilhado entre as rotas
pub struct AppState {
    pub pg_pool: PgPool,
    pub elastic_client: Elasticsearch,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenv().ok();
    tracing_subscriber::fmt::init();
    tracing::info!("🚀 Blue-Taurus Server Iniciando...");

    // 1. Postgres
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL faltando");
    let pg_pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&db_url).await.expect("Falha Postgres");
    
    // Migrations
    // sqlx::migrate!("./migrations").run(&pg_pool).await.expect("Migrations falharam");

    // 2. Elasticsearch
    let es_url = std::env::var("ELASTIC_URL").expect("ELASTIC_URL faltando");
    let transport = Transport::single_node(&es_url)?;
    let elastic_client = Elasticsearch::new(transport);

    // Verificacao basica do Elastic
    let _ = elastic_client.ping().send().await.map(|_| tracing::info!("✅ Elastic Connected"));

    // 3. Estado Global
    let state = Arc::new(AppState { pg_pool, elastic_client });

    // 4. Rotas
    let app = Router::new()
        .route("/", get(health_check))
        .route("/ws", get(socket::ws_handler)) // Rota WebSocket
        .with_state(state);

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    tracing::info!("👂 Servidor escutando em {}", addr);
    
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();

    Ok(())
}

async fn health_check() -> &'static str { "Blue-Taurus Server: ONLINE 🐂" }
'@
$serverMainCode | Out-File -FilePath "crates/server/src/main.rs" -Encoding utf8


# ==============================================================================
# 2. AGENT SIDE: Networking
# ==============================================================================

# 2.1 Modulo de Rede do Agente
Write-Host "[CODE] Criando crates/agent/src/net/mod.rs..." -ForegroundColor Green
New-Item -Path "crates/agent/src/net" -ItemType Directory -Force | Out-Null

$agentNetCode = @'
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message as WsMessage};
use futures::{SinkExt, StreamExt};
use url::Url;
use shared::protocol::Message;
use shared::models::HostInfo;
use uuid::Uuid;
use std::time::Duration;
use tokio::time::sleep;

pub async fn start_agent_loop(agent_id: Uuid, host_info: HostInfo) {
    let url = Url::parse("ws://127.0.0.1:3000/ws").unwrap();

    loop {
        tracing::info!("Tentando conectar ao servidor...");
        
        match connect_async(url.clone()).await {
            Ok((ws_stream, _)) => {
                tracing::info!("✅ Conectado! Enviando Handshake...");
                let (mut write, _read) = ws_stream.split();

                // 1. Enviar Handshake
                let handshake = Message::Handshake {
                    agent_id,
                    host_info: host_info.clone(),
                    token: "dev-token".to_string(),
                };
                
                let json = serde_json::to_string(&handshake).unwrap();
                if let Err(e) = write.send(WsMessage::Text(json)).await {
                    tracing::error!("Erro ao enviar handshake: {}", e);
                    continue;
                }

                // 2. Loop de Heartbeat (Mantem conexao viva)
                loop {
                    sleep(Duration::from_secs(10)).await;
                    let heartbeat = Message::Heartbeat { 
                        agent_id, 
                        timestamp: chrono::Utc::now() 
                    };
                    let json = serde_json::to_string(&heartbeat).unwrap();
                    
                    if let Err(e) = write.send(WsMessage::Text(json)).await {
                        tracing::error!("Conexao perdida: {}", e);
                        break; // Sai do loop interno para reconectar
                    }
                    tracing::info!("💓 Heartbeat enviado");
                }
            }
            Err(e) => {
                tracing::error!("Falha na conexao: {}. Retentando em 5s...", e);
                sleep(Duration::from_secs(5)).await;
            }
        }
    }
}
'@
$agentNetCode | Out-File -FilePath "crates/agent/src/net/mod.rs" -Encoding utf8

# 2.2 Atualizar Main do Agente
Write-Host "[CODE] Atualizando crates/agent/src/main.rs..." -ForegroundColor Green
$agentMainCode = @'
mod collector;
mod net;

use uuid::Uuid;
use collector::SystemCollector;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    tracing::info!("🚀 Blue-Taurus Agent v0.1");

    // Identidade do Agente (Gera um UUID novo a cada restart por enquanto)
    let agent_id = Uuid::new_v4();
    tracing::info!("Agent ID: {}", agent_id);

    // Coleta Inicial
    let mut collector = SystemCollector::new();
    let host_info = collector.collect();
    tracing::info!("Inventario inicial coletado: {} ({})", host_info.hostname, host_info.os_name);

    // Inicia Loop de Rede (Conecta e mantem vivo)
    net::start_agent_loop(agent_id, host_info).await;
}
'@
$agentMainCode | Out-File -FilePath "crates/agent/src/main.rs" -Encoding utf8

Write-Host "[SUCCESS] Fase 4 Concluida! Agora eles conversam." -ForegroundColor Cyan
Write-Host "[INSTRUCOES DE TESTE]:"
Write-Host "1. Terminal A: cargo run -p server"
Write-Host "2. Terminal B: cargo run -p agent"
Write-Host "3. Veja o LOG do servidor confirmar o Handshake e o Dual-Write!"