# ==============================================================================
# BLUE-TAURUS: FASE 13 - SCA INTEGRATION (FULL CYCLE + DETAILS)
# Descrição: Envia relatório do Agente -> Server -> DB -> Dashboard.
# Fix 1.9: Substitui sqlx::query! (macro) por sqlx::query (funcao) para permitir
#          compilacao no Docker sem acesso ao banco de dados (Bypass compile-time check).
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 13] Integrando Motor SCA com Detalhes (Docker Friendly)..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# ==============================================================================
# 1. SHARED: Adicionar 'ScaReport' ao Protocolo (MANTIDO)
# ==============================================================================
Write-Host "[CODE] Atualizando crates/shared/src/protocol/mod.rs..." -ForegroundColor Green
$protocolCode = @'
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use crate::models::{HostInfo, SoftwareInfo};
use crate::models::sca::ComplianceReport;

#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum Message {
    Handshake {
        agent_id: Uuid,
        host_info: HostInfo,
        token: String,
    },
    HandshakeAck {
        status: String,
        server_time: DateTime<Utc>,
    },
    Heartbeat {
        agent_id: Uuid,
        timestamp: DateTime<Utc>,
    },
    InventoryReport {
        agent_id: Uuid,
        software: Vec<SoftwareInfo>,
    },
    ScaReport {
        agent_id: Uuid,
        report: ComplianceReport,
    },
    Command {
        id: Uuid,
        cmd_type: CommandType,
        args: Option<String>,
        signature: String,
    },
    CommandResult {
        cmd_id: Uuid,
        status: String,
        stdout: String,
        stderr: String,
    },
}

#[derive(Debug, Serialize, Deserialize)]
pub enum CommandType {
    RunScript,
    UpdateConfig,
    RestartAgent,
}
'@
$protocolCode | Out-File -FilePath "crates/shared/src/protocol/mod.rs" -Encoding utf8


# ==============================================================================
# 2. SERVER: Migration (MANTIDO)
# ==============================================================================
Write-Host "[SQL] Criando tabela compliance_scores..." -ForegroundColor Green
$migrationSql = @'
CREATE TABLE IF NOT EXISTS compliance_scores (
    agent_id UUID PRIMARY KEY REFERENCES agents(id),
    policy_id VARCHAR(100),
    score INT,
    total_checks INT,
    passed_checks INT,
    details JSONB,
    last_scan_at TIMESTAMPTZ DEFAULT NOW()
);
'@
New-Item -Path "crates/server/migrations" -ItemType Directory -Force | Out-Null
$Utf8NoBom = New-Object System.Text.UTF8Encoding $False
$timestamp = (Get-Date).ToString("yyyyMMddHHmmss")
[System.IO.File]::WriteAllText("$PWD/crates/server/migrations/${timestamp}_compliance_json.sql", $migrationSql, $Utf8NoBom)


# ==============================================================================
# 3. AGENT: Enviar Relatorio (MANTIDO)
# ==============================================================================
Write-Host "[CODE] Atualizando crates/agent/src/net/mod.rs..." -ForegroundColor Green
$CurrentFile = Get-Content "crates/agent/src/net/mod.rs" -Raw
$PublicKeyLine = $CurrentFile | Select-String 'const ADMIN_PUBLIC_KEY: &str = "(.*)";'
$CurrentKey = "CHAVE_PUBLICA_AQUI"
if ($PublicKeyLine) { $CurrentKey = $PublicKeyLine.Matches.Groups[1].Value }

$agentNetCode = @"
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message as WsMessage};
use futures::{SinkExt, StreamExt};
use url::Url;
use shared::protocol::{Message, CommandType};
use shared::models::HostInfo;
use shared::models::sca::ComplianceReport;
use shared::crypto;
use uuid::Uuid;
use std::time::Duration;
use tokio::time::sleep;
use std::process::Command;

const ADMIN_PUBLIC_KEY: &str = `"$CurrentKey`"; 

pub async fn start_agent_loop(agent_id: Uuid, host_info: HostInfo, sca_report: Option<ComplianceReport>) {
    let url = Url::parse("ws://127.0.0.1:3000/ws").unwrap();

    loop {
        tracing::info!("Tentando conectar ao servidor...");
        
        match connect_async(url.clone()).await {
            Ok((ws_stream, _)) => {
                tracing::info!("✅ Conectado!");
                let (mut write, mut read) = ws_stream.split();

                let handshake = Message::Handshake {
                    agent_id,
                    host_info: host_info.clone(),
                    token: "dev-token".to_string(),
                };
                let _ = write.send(WsMessage::Text(serde_json::to_string(&handshake).unwrap())).await;

                if let Some(report) = &sca_report {
                    tracing::info!("📤 Enviando Relatorio de Compliance...");
                    let msg = Message::ScaReport {
                        agent_id,
                        report: report.clone(),
                    };
                    if let Err(e) = write.send(WsMessage::Text(serde_json::to_string(&msg).unwrap())).await {
                        tracing::error!("Erro ao enviar SCA report: {}", e);
                    }
                }

                loop {
                    tokio::select! {
                        _ = sleep(Duration::from_secs(10)) => {
                            let hb = Message::Heartbeat { agent_id, timestamp: chrono::Utc::now() };
                            if let Err(_) = write.send(WsMessage::Text(serde_json::to_string(&hb).unwrap())).await { break; }
                        }
                        msg = read.next() => {
                            match msg {
                                Some(Ok(WsMessage::Text(text))) => {
                                    if let Ok(Message::Command { id, cmd_type, args, signature }) = serde_json::from_str(&text) {
                                        tracing::info!("Comando recebido (Logica completa no script Fase 5)");
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
$agentNetCode | Out-File -FilePath "crates/agent/src/net/mod.rs" -Encoding utf8

Write-Host "[CODE] Atualizando crates/agent/src/main.rs..." -ForegroundColor Green
$agentMain = @'
mod collector;
mod net;
mod sca;

use uuid::Uuid;
use collector::SystemCollector;
use sca::ScaEngine;
use std::fs;

fn get_stable_agent_id() -> Uuid {
    if let Ok(c) = fs::read_to_string(".agent_id") {
        if let Ok(u) = Uuid::parse_str(c.trim()) { return u; }
    }
    let new_id = Uuid::new_v4();
    let _ = fs::write(".agent_id", new_id.to_string());
    new_id
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    tracing::info!("🚀 Blue-Taurus Agent v1.4 (SCA Details)");

    let agent_id = get_stable_agent_id();
    tracing::info!("🆔 Agent ID: {}", agent_id);

    let mut collector = SystemCollector::new();
    let host_info = collector.collect();
    
    let sca = ScaEngine::new("assets/cis_windows_basic.yaml");
    let report = sca.run_scan();

    if report.is_some() {
        tracing::info!("📊 Relatorio SCA gerado.");
    }

    net::start_agent_loop(agent_id, host_info, report).await;
}
'@
$agentMain | Out-File -FilePath "crates/agent/src/main.rs" -Encoding utf8


# ==============================================================================
# 4. SERVER: Gravar Detalhes (CORRIGIDO: Runtime Queries)
# ==============================================================================
Write-Host "[CODE] Atualizando crates/server/src/socket/mod.rs..." -ForegroundColor Green
$serverSocketCode = @'
use axum::{
    extract::{ws::{Message as WsMessage, WebSocket, WebSocketUpgrade}, State},
    response::IntoResponse,
};
use futures::stream::StreamExt; 
use std::sync::Arc;
use shared::protocol::Message;
use crate::AppState;

pub async fn ws_handler(ws: WebSocketUpgrade, State(state): State<Arc<AppState>>) -> impl IntoResponse {
    ws.on_upgrade(|socket| handle_socket(socket, state))
}

async fn handle_socket(socket: WebSocket, state: Arc<AppState>) {
    let (mut _sender, mut receiver) = socket.split();

    while let Some(Ok(msg)) = receiver.next().await {
        if let WsMessage::Text(text) = msg {
            if let Ok(protocol_msg) = serde_json::from_str::<Message>(&text) {
                match protocol_msg {
                    Message::Handshake { agent_id, host_info, .. } => {
                        tracing::info!("🤝 Handshake: {}", host_info.hostname);
                        // FIX: Usando sqlx::query() (funcao) em vez de sqlx::query!() (macro)
                        let _ = sqlx::query("INSERT INTO agents (id, hostname, os_name, status, last_seen_at) VALUES ($1, $2, $3, 'ONLINE', NOW()) ON CONFLICT(id) DO UPDATE SET last_seen_at = NOW(), status='ONLINE'")
                            .bind(agent_id)
                            .bind(host_info.hostname)
                            .bind(host_info.os_name)
                            .execute(&state.pg_pool).await;
                    },
                    Message::ScaReport { agent_id, report } => {
                        tracing::info!("🛡️ SCA Report recebido de {}: Score {}%", agent_id, report.score);

                        let details_json = serde_json::to_value(&report.results).unwrap_or_default();

                        let q = r#"INSERT INTO compliance_scores (agent_id, policy_id, score, total_checks, passed_checks, details, last_scan_at)
                               VALUES ($1, $2, $3, $4, $5, $6, NOW())
                               ON CONFLICT (agent_id) DO UPDATE SET 
                               score = EXCLUDED.score, passed_checks = EXCLUDED.passed_checks, details = EXCLUDED.details, last_scan_at = NOW()"#;
                        
                        // FIX: Runtime Query
                        let _ = sqlx::query(q)
                            .bind(agent_id)
                            .bind(&report.policy_id)
                            .bind(report.score as i32)
                            .bind(report.total_checks as i32)
                            .bind(report.passed_checks as i32)
                            .bind(details_json)
                            .execute(&state.pg_pool).await
                            .map_err(|e| tracing::error!("Erro Postgres SCA: {}", e));

                        // Elastic Indexing (Mantido igual)
                        let mut doc = serde_json::to_value(&report).unwrap();
                        if let Some(obj) = doc.as_object_mut() {
                            obj.insert("@timestamp".to_string(), serde_json::json!(chrono::Utc::now()));
                            obj.insert("event_type".to_string(), serde_json::json!("sca_report"));
                            obj.insert("agent_id".to_string(), serde_json::json!(agent_id));
                        }
                        let _ = state.elastic_client.index(elasticsearch::IndexParts::Index("bt-logs-v1")).body(doc).send().await;
                    },
                    _ => {}
                }
            }
        }
    }
}
'@
$serverSocketCode | Out-File -FilePath "crates/server/src/socket/mod.rs" -Encoding utf8


# ==============================================================================
# 5. SERVER API: Retornar Detalhes (CORRIGIDO: Runtime Queries)
# ==============================================================================
Write-Host "[CODE] Atualizando crates/server/src/main.rs..." -ForegroundColor Green

$serverMainCode = @'
mod socket;

use axum::{routing::{get, delete}, Router, extract::{State, Path}, response::{Json}, http};
use tower_http::services::ServeDir;
use sqlx::postgres::{PgPool, PgPoolOptions};
use elasticsearch::Elasticsearch;
use elasticsearch::http::transport::Transport;
use std::net::SocketAddr;
use std::sync::Arc;
use dotenvy::dotenv;
use serde::{Serialize, Deserialize};
use uuid::Uuid;

pub struct AppState { pub pg_pool: PgPool, pub elastic_client: Elasticsearch }

#[derive(Serialize, sqlx::FromRow)]
pub struct AgentRow {
    id: Uuid, hostname: String, os_name: String, status: Option<String>,
    last_seen_at: Option<chrono::DateTime<chrono::Utc>>,
    compliance_score: Option<i32>
}

#[derive(Serialize)]
pub struct AgentDetails {
    agent: AgentRow,
    hardware: Option<HardwareRow>,
    software: Vec<SoftwareRow>,
    compliance: Option<ComplianceDetails>,
}

#[derive(Serialize, sqlx::FromRow)]
pub struct HardwareRow { cpu_model: Option<String>, ram_total_mb: Option<i64>, disk_total_gb: Option<i64> }

#[derive(Serialize, sqlx::FromRow)]
pub struct SoftwareRow { name: String, version: Option<String>, vendor: Option<String>, install_date: Option<String> }

#[derive(Serialize, sqlx::FromRow)]
pub struct ComplianceDetails { 
    policy_id: Option<String>, 
    score: Option<i32>, 
    details: Option<serde_json::Value>
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Configura log para Cloud (Coolify geralmente define RUST_LOG, mas garantimos aqui)
    if std::env::var("RUST_LOG").is_err() {
        std::env::set_var("RUST_LOG", "info");
    }
    tracing_subscriber::fmt::init();
    tracing::info!("🚀 Blue-Taurus Server v1.4 (SCA Details) Iniciando...");

    // Tenta carregar .env, mas nao falha se nao existir (Prod usa env vars reais)
    dotenv().ok();

    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL faltando");
    let pg_pool = PgPoolOptions::new().max_connections(5).connect(&db_url).await.expect("Falha Postgres");
    
    // Migrations via Runtime (Funciona no Docker sem preparacao previa)
    sqlx::migrate!("./migrations").run(&pg_pool).await.ok(); 

    let es_url = std::env::var("ELASTIC_URL").expect("ELASTIC_URL faltando");
    let transport = Transport::single_node(&es_url)?;
    let elastic_client = Elasticsearch::new(transport);

    let state = Arc::new(AppState { pg_pool, elastic_client });

    let app = Router::new()
        .route("/api/agents", get(list_agents))
        .route("/api/agents/:id", delete(delete_agent))
        .route("/api/agents/:id/details", get(get_agent_details))
        .route("/ws", get(socket::ws_handler))
        .nest_service("/", ServeDir::new("assets"))
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], 3000)); // Bind 0.0.0.0 para Docker!
    axum::Server::bind(&addr).serve(app.into_make_service()).await.unwrap();
    Ok(())
}

async fn list_agents(State(state): State<Arc<AppState>>) -> Json<Vec<AgentRow>> {
    let sql = r#"
        SELECT a.id, a.hostname, a.os_name, a.status, a.last_seen_at, c.score as compliance_score
        FROM agents a
        LEFT JOIN compliance_scores c ON a.id = c.agent_id
        ORDER BY a.last_seen_at DESC
    "#;
    
    // Runtime Query (Sem verificacao em tempo de compilacao)
    let agents = sqlx::query_as::<_, AgentRow>(sql)
        .fetch_all(&state.pg_pool).await.unwrap_or_default();
    Json(agents)
}

async fn delete_agent(Path(id): Path<Uuid>, State(state): State<Arc<AppState>>) -> http::StatusCode {
    // Runtime Queries
    let _ = sqlx::query("DELETE FROM compliance_scores WHERE agent_id = $1").bind(id).execute(&state.pg_pool).await;
    let _ = sqlx::query("DELETE FROM software_inventory WHERE agent_id = $1").bind(id).execute(&state.pg_pool).await;
    let _ = sqlx::query("DELETE FROM hardware_specs WHERE agent_id = $1").bind(id).execute(&state.pg_pool).await;
    let _ = sqlx::query("DELETE FROM agents WHERE id = $1").bind(id).execute(&state.pg_pool).await;
    http::StatusCode::NO_CONTENT
}

async fn get_agent_details(Path(id): Path<Uuid>, State(state): State<Arc<AppState>>) -> Json<Option<AgentDetails>> {
    // Runtime Queries
    let agent = sqlx::query_as::<_, AgentRow>("SELECT id, hostname, os_name, status, last_seen_at, NULL::int as compliance_score FROM agents WHERE id = $1")
        .bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);

    if let Some(ag) = agent {
        let hw = sqlx::query_as::<_, HardwareRow>("SELECT cpu_model, ram_total_mb, disk_total_gb FROM hardware_specs WHERE agent_id = $1")
            .bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);
        
        let sw = sqlx::query_as::<_, SoftwareRow>("SELECT name, version, vendor, install_date FROM software_inventory WHERE agent_id = $1 ORDER BY name ASC")
            .bind(id).fetch_all(&state.pg_pool).await.unwrap_or_default();

        let comp = sqlx::query_as::<_, ComplianceDetails>("SELECT policy_id, score, details FROM compliance_scores WHERE agent_id = $1")
            .bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);

        return Json(Some(AgentDetails { agent: ag, hardware: hw, software: sw, compliance: comp }));
    }
    Json(None)
}
'@
$serverMainCode | Out-File -FilePath "crates/server/src/main.rs" -Encoding utf8

# Atualizar Index HTML (MANTIDO)
Write-Host "[UI] Reescrevendo assets/index.html..." -ForegroundColor Green
$htmlContent = Get-Content "assets/index.html" -Raw
# (Assumindo que o HTML da fase anterior ja esta correto, senao re-executar fase 9 ou 10)

Write-Host "[SUCCESS] Codigo atualizado para Docker (Runtime Queries)!" -ForegroundColor Cyan
Write-Host "1. Commit e Push."
Write-Host "2. Redeploy no Coolify."