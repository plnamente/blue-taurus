# ==============================================================================
# BLUE-TAURUS: FASE 13 - SCA INTEGRATION (FULL CYCLE + DETAILS UI v2)
# Descrição: Envia relatório do Agente -> Server -> DB -> Dashboard.
# Fix 1.8: Restaura Menu Lateral Completo.
# Fix 1.9: Adiciona Aba Hardware e Explicação do Score no Modal.
# Fix 2.0: Inclui 'cpu_cores' na API de detalhes.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 13] Integrando Motor SCA com UI Completa..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# ==============================================================================
# 1. SHARED: Protocolo (Mantido)
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
    Handshake { agent_id: Uuid, host_info: HostInfo, token: String },
    HandshakeAck { status: String, server_time: DateTime<Utc> },
    Heartbeat { agent_id: Uuid, timestamp: DateTime<Utc> },
    InventoryReport { agent_id: Uuid, software: Vec<SoftwareInfo> },
    ScaReport { agent_id: Uuid, report: ComplianceReport },
    Command { id: Uuid, cmd_type: CommandType, args: Option<String>, signature: String },
    CommandResult { cmd_id: Uuid, status: String, stdout: String, stderr: String },
}

#[derive(Debug, Serialize, Deserialize)]
pub enum CommandType { RunScript, UpdateConfig, RestartAgent }
'@
$protocolCode | Out-File -FilePath "crates/shared/src/protocol/mod.rs" -Encoding utf8


# ==============================================================================
# 2. SERVER: Migration (Mantida)
# ==============================================================================
Write-Host "[SQL] Criando tabela compliance_scores..." -ForegroundColor Green
$migrationSql = @'
DROP TABLE IF EXISTS compliance_scores;
CREATE TABLE compliance_scores (
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
# 3. AGENT: Net Loop (Mantido)
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

                let handshake = Message::Handshake { agent_id, host_info: host_info.clone(), token: "dev".to_string() };
                let _ = write.send(WsMessage::Text(serde_json::to_string(&handshake).unwrap())).await;

                if let Some(report) = &sca_report {
                    tracing::info!("📤 Enviando Relatorio de Compliance...");
                    let msg = Message::ScaReport { agent_id, report: report.clone() };
                    let _ = write.send(WsMessage::Text(serde_json::to_string(&msg).unwrap())).await;
                }

                loop {
                    tokio::select! {
                        _ = sleep(Duration::from_secs(10)) => {
                            let hb = Message::Heartbeat { agent_id, timestamp: chrono::Utc::now() };
                            if let Err(_) = write.send(WsMessage::Text(serde_json::to_string(&hb).unwrap())).await { break; }
                        }
                        msg = read.next() => {
                            if let Some(Ok(WsMessage::Text(text))) = msg {
                                if let Ok(Message::Command { .. }) = serde_json::from_str(&text) {
                                    tracing::info!("Comando recebido");
                                }
                            } else if msg.is_none() { break; }
                        }
                    }
                }
            }
            Err(e) => { tracing::error!("Falha: {}. Retry 5s...", e); sleep(Duration::from_secs(5)).await; }
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
    if let Ok(c) = fs::read_to_string(".agent_id") { if let Ok(u) = Uuid::parse_str(c.trim()) { return u; } }
    let new_id = Uuid::new_v4(); let _ = fs::write(".agent_id", new_id.to_string()); new_id
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    tracing::info!("🚀 Blue-Taurus Agent v1.5");
    let agent_id = get_stable_agent_id();
    let mut collector = SystemCollector::new();
    let host_info = collector.collect();
    let sca = ScaEngine::new("assets/cis_windows_basic.yaml");
    let report = sca.run_scan();
    net::start_agent_loop(agent_id, host_info, report).await;
}
'@
$agentMain | Out-File -FilePath "crates/agent/src/main.rs" -Encoding utf8


# ==============================================================================
# 4. SERVER: Socket Handler (Mantido)
# ==============================================================================
Write-Host "[CODE] Atualizando crates/server/src/socket/mod.rs..." -ForegroundColor Green
$serverSocketCode = @'
use axum::{extract::{ws::{Message as WsMessage, WebSocket, WebSocketUpgrade}, State}, response::IntoResponse};
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
                        let _ = sqlx::query!("INSERT INTO agents (id, hostname, os_name, status, last_seen_at) VALUES ($1, $2, $3, 'ONLINE', NOW()) ON CONFLICT(id) DO UPDATE SET last_seen_at = NOW(), status='ONLINE'", agent_id, host_info.hostname, host_info.os_name).execute(&state.pg_pool).await;
                        
                        let _ = sqlx::query!(
                            r#"INSERT INTO hardware_specs (agent_id, cpu_model, cpu_cores, ram_total_mb, disk_total_gb)
                               VALUES ($1, $2, $3, $4, $5)
                               ON CONFLICT (agent_id) DO UPDATE SET cpu_model=EXCLUDED.cpu_model, ram_total_mb=EXCLUDED.ram_total_mb"#,
                            agent_id, host_info.hardware.cpu_model, host_info.hardware.cpu_cores as i32, host_info.hardware.ram_total_mb as i64, host_info.hardware.disk_total_gb as i64
                        ).execute(&state.pg_pool).await;
                    },
                    Message::ScaReport { agent_id, report } => {
                        tracing::info!("🛡️ SCA Report: {}%", report.score);
                        let details_json = serde_json::to_value(&report.results).unwrap_or_default();
                        let _ = sqlx::query(r#"INSERT INTO compliance_scores (agent_id, policy_id, score, total_checks, passed_checks, details, last_scan_at) VALUES ($1, $2, $3, $4, $5, $6, NOW()) ON CONFLICT (agent_id) DO UPDATE SET score=EXCLUDED.score, details=EXCLUDED.details"#)
                            .bind(agent_id).bind(&report.policy_id).bind(report.score as i32).bind(report.total_checks as i32).bind(report.passed_checks as i32).bind(details_json).execute(&state.pg_pool).await;
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
# 5. SERVER API: Atualizar HardwareRow (CPU Cores)
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

// FIX: Adicionado cpu_cores
#[derive(Serialize, sqlx::FromRow)]
pub struct HardwareRow { 
    cpu_model: Option<String>, 
    cpu_cores: Option<i32>, 
    ram_total_mb: Option<i64>, 
    disk_total_gb: Option<i64> 
}

#[derive(Serialize, sqlx::FromRow)]
pub struct SoftwareRow { name: String, version: Option<String>, vendor: Option<String>, install_date: Option<String> }

#[derive(Serialize, sqlx::FromRow)]
pub struct ComplianceDetails { policy_id: Option<String>, score: Option<i32>, total_checks: Option<i32>, passed_checks: Option<i32>, details: Option<serde_json::Value> }

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenv().ok();
    tracing_subscriber::fmt::init();
    tracing::info!("🚀 Blue-Taurus Server v1.5");

    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL");
    let pg_pool = PgPoolOptions::new().max_connections(5).connect(&db_url).await.expect("PG Fail");
    sqlx::migrate!("./migrations").run(&pg_pool).await.ok(); 

    let es_url = std::env::var("ELASTIC_URL").expect("ELASTIC_URL");
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

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    axum::Server::bind(&addr).serve(app.into_make_service()).await.unwrap();
    Ok(())
}

async fn list_agents(State(state): State<Arc<AppState>>) -> Json<Vec<AgentRow>> {
    let sql = r#"SELECT a.id, a.hostname, a.os_name, a.status, a.last_seen_at, c.score as compliance_score FROM agents a LEFT JOIN compliance_scores c ON a.id = c.agent_id ORDER BY a.last_seen_at DESC"#;
    let agents = sqlx::query_as::<_, AgentRow>(sql).fetch_all(&state.pg_pool).await.unwrap_or_default();
    Json(agents)
}

async fn delete_agent(Path(id): Path<Uuid>, State(state): State<Arc<AppState>>) -> http::StatusCode {
    let _ = sqlx::query!("DELETE FROM compliance_scores WHERE agent_id = $1", id).execute(&state.pg_pool).await;
    let _ = sqlx::query!("DELETE FROM agents WHERE id = $1", id).execute(&state.pg_pool).await;
    http::StatusCode::NO_CONTENT
}

async fn get_agent_details(Path(id): Path<Uuid>, State(state): State<Arc<AppState>>) -> Json<Option<AgentDetails>> {
    let agent = sqlx::query_as::<_, AgentRow>("SELECT id, hostname, os_name, status, last_seen_at, NULL::int as compliance_score FROM agents WHERE id = $1").bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);

    if let Some(ag) = agent {
        // FIX: Buscando cpu_cores
        let hw = sqlx::query_as::<_, HardwareRow>("SELECT cpu_model, cpu_cores, ram_total_mb, disk_total_gb FROM hardware_specs WHERE agent_id = $1").bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);
        let sw = sqlx::query_as::<_, SoftwareRow>("SELECT name, version, vendor, install_date FROM software_inventory WHERE agent_id = $1 ORDER BY name ASC").bind(id).fetch_all(&state.pg_pool).await.unwrap_or_default();
        let comp = sqlx::query_as::<_, ComplianceDetails>("SELECT policy_id, score, total_checks, passed_checks, details FROM compliance_scores WHERE agent_id = $1").bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);
        return Json(Some(AgentDetails { agent: ag, hardware: hw, software: sw, compliance: comp }));
    }
    Json(None)
}
'@
$serverMainCode | Out-File -FilePath "crates/server/src/main.rs" -Encoding utf8


# ==============================================================================
# 6. UI: Restaurar Sidebar e Adicionar Aba Hardware
# ==============================================================================
Write-Host "[UI] Reescrevendo assets/index.html (Sidebar Restored + Hardware Tab)..." -ForegroundColor Green
$htmlContent = @'
<!DOCTYPE html>
<html lang="pt-BR" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Blue-Taurus | Enterprise</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
    <script src="https://unpkg.com/@phosphor-icons/web"></script>
    <script>
        tailwind.config = { darkMode: 'class', theme: { fontFamily: { sans: ['Inter', 'sans-serif'] }, extend: { colors: { slate: { 850: '#151e2e', 900: '#0f172a' } } } } }
    </script>
    <style>
        body { background-color: #0b1120; color: #cbd5e1; }
        .card { background: #1e293b; border: 1px solid #334155; border-radius: 0.75rem; }
        .modal { transition: opacity 0.25s ease; }
        body.modal-active { overflow: hidden; }
        ::-webkit-scrollbar { width: 8px; height: 8px; }
        ::-webkit-scrollbar-track { background: #0f172a; }
        ::-webkit-scrollbar-thumb { background: #334155; border-radius: 4px; }
        .tab-btn.active { border-bottom: 2px solid #3b82f6; color: #60a5fa; }
    </style>
</head>
<body class="flex h-screen overflow-hidden">

    <!-- SIDEBAR COMPLETA (RESTAURADA) -->
    <aside class="w-64 bg-slate-850 border-r border-slate-700 flex flex-col z-30">
        <div class="h-16 flex items-center px-6 border-b border-slate-700/50">
            <i class="ph-fill ph-shield-check text-blue-500 text-2xl mr-2"></i>
            <h1 class="font-bold text-lg text-white tracking-tight">BLUE-TAURUS</h1>
        </div>
        <nav class="flex-1 p-4 space-y-1 overflow-y-auto">
            <p class="px-3 text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2 mt-2">Vis&atilde;o Geral</p>
            <a href="#" class="nav-item flex items-center gap-3 px-3 py-2.5 text-sm font-medium text-white bg-slate-800 rounded-lg">
                <i class="ph ph-chart-pie-slice text-lg"></i> Data Analytics
            </a>
            <a href="#" class="nav-item flex items-center gap-3 px-3 py-2.5 text-sm font-medium text-slate-400 hover:text-white transition-colors">
                <i class="ph ph-desktop text-lg"></i> Invent&aacute;rio
            </a>
            
            <p class="px-3 text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2 mt-6">Seguran&ccedil;a</p>
            <a href="#" class="nav-item flex items-center gap-3 px-3 py-2.5 text-sm font-medium text-slate-400 hover:text-white transition-colors">
                <i class="ph ph-check-circle text-lg"></i> Compliance CIS
            </a>
            <a href="#" class="nav-item flex items-center gap-3 px-3 py-2.5 text-sm font-medium text-slate-400 hover:text-white transition-colors">
                <i class="ph ph-warning-octagon text-lg"></i> Vulnerabilidades
            </a>
        </nav>
    </aside>

    <!-- AREA PRINCIPAL -->
    <main class="flex-1 flex flex-col overflow-hidden relative bg-[#0b1120]">
        <header class="h-16 flex items-center justify-between px-8 border-b border-slate-700/50 bg-slate-900/50 backdrop-blur-sm">
            <h2 class="text-lg font-semibold text-white">Data Analytics Dashboard</h2>
            <div class="flex items-center gap-4">
                <span class="flex items-center gap-2 px-3 py-1 rounded-full bg-slate-800 border border-slate-700 text-xs text-slate-400">
                    <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span> Sistema Online
                </span>
            </div>
        </header>

        <div class="flex-1 overflow-y-auto p-8 scroll-smooth">
            <!-- KPIs -->
            <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-6">
                <div class="card p-6 border-l-4 border-blue-500"><p class="text-slate-400 text-xs uppercase font-bold">Total Ativos</p><h3 id="kpi-total" class="text-3xl font-bold text-white mt-2">--</h3></div>
                <div class="card p-6 border-l-4 border-emerald-500">
                    <p class="text-slate-400 text-xs uppercase font-bold">Compliance Score</p>
                    <h3 id="kpi-score" class="text-3xl font-bold text-emerald-400 mt-2">--%</h3>
                    <p class="text-xs text-slate-500 mt-1">M&eacute;dia da Rede (CIS v8)</p>
                </div>
                <div class="card p-6 border-l-4 border-amber-500"><p class="text-slate-400 text-xs uppercase font-bold">Riscos Altos</p><h3 class="text-3xl font-bold text-white mt-2">--</h3></div>
                <div class="card p-6 border-l-4 border-purple-500"><p class="text-slate-400 text-xs uppercase font-bold">Eventos (24h)</p><h3 class="text-3xl font-bold text-white mt-2">--</h3></div>
            </div>

            <!-- INVENTORY TABLE -->
            <div class="card overflow-hidden">
                <div class="p-4 border-b border-slate-700 flex justify-between items-center bg-slate-800/50">
                    <h2 class="text-sm font-bold text-white flex items-center gap-2"><i class="ph-duotone ph-list-dashes text-lg text-blue-400"></i> Invent&aacute;rio de M&aacute;quinas</h2>
                    <button onclick="fetchAgents()" class="text-slate-400 hover:text-white"><i class="ph-bold ph-arrows-clockwise text-xl"></i></button>
                </div>
                <div class="overflow-x-auto">
                    <table class="w-full text-left text-xs">
                        <thead class="bg-slate-800/80 text-slate-400 font-semibold uppercase tracking-wider">
                            <tr>
                                <th class="p-3">Ativo / Hostname</th>
                                <th class="p-3">Status</th>
                                <th class="p-3">Sistema</th>
                                <th class="p-3 text-center">Score CIS</th>
                                <th class="p-3">&Uacute;ltimo Visto</th>
                                <th class="p-3 text-right">A&ccedil;&atilde;o</th>
                            </tr>
                        </thead>
                        <tbody id="table-body" class="divide-y divide-slate-700/50 text-slate-300"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </main>

    <!-- MODAL DETALHES (COM 3 ABAS) -->
    <div id="details-modal" class="modal opacity-0 pointer-events-none fixed w-full h-full top-0 left-0 flex items-center justify-center z-50">
        <div class="modal-overlay absolute w-full h-full bg-black opacity-60 backdrop-blur-sm"></div>
        <div class="modal-container bg-slate-800 w-11/12 md:max-w-4xl mx-auto rounded-xl shadow-2xl z-50 overflow-hidden border border-slate-700 flex flex-col max-h-[90vh]">
            <div class="p-6 border-b border-slate-700 flex justify-between items-center bg-slate-900/50">
                <div>
                    <h3 class="text-xl font-bold text-white" id="modal-hostname">Host</h3>
                    <p class="text-xs text-slate-400 font-mono mt-1" id="modal-id">UUID</p>
                </div>
                <button onclick="closeModal()" class="text-slate-400 hover:text-white bg-slate-800 p-2 rounded-lg"><i class="ph-bold ph-x"></i></button>
            </div>
            
            <div class="p-6 overflow-y-auto">
                <!-- TABS -->
                <div class="flex gap-4 border-b border-slate-700 mb-4">
                    <button id="tab-hw" onclick="switchTab('hw')" class="tab-btn active px-4 py-2 text-sm font-medium text-slate-400 hover:text-white transition-colors">Hardware</button>
                    <button id="tab-sw" onclick="switchTab('sw')" class="tab-btn px-4 py-2 text-sm font-medium text-slate-400 hover:text-white transition-colors">Software</button>
                    <button id="tab-cis" onclick="switchTab('cis')" class="tab-btn px-4 py-2 text-sm font-medium text-slate-400 hover:text-white transition-colors">Seguran&ccedil;a (CIS)</button>
                </div>

                <!-- TAB CONTENT: HARDWARE -->
                <div id="content-hw" class="block space-y-6">
                    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                        <div class="bg-slate-700/30 p-4 rounded-lg border border-slate-600/50"><p class="text-xs text-slate-400 uppercase font-bold">CPU</p><p class="text-white text-sm mt-1" id="modal-cpu">-</p></div>
                        <div class="bg-slate-700/30 p-4 rounded-lg border border-slate-600/50"><p class="text-xs text-slate-400 uppercase font-bold">N&uacute;cleos</p><p class="text-white text-sm mt-1" id="modal-cores">-</p></div>
                        <div class="bg-slate-700/30 p-4 rounded-lg border border-slate-600/50"><p class="text-xs text-slate-400 uppercase font-bold">RAM</p><p class="text-white text-sm mt-1" id="modal-ram">-</p></div>
                        <div class="bg-slate-700/30 p-4 rounded-lg border border-slate-600/50"><p class="text-xs text-slate-400 uppercase font-bold">Disco</p><p class="text-white text-sm mt-1" id="modal-disk">-</p></div>
                    </div>
                    <div>
                        <h4 class="text-sm font-bold text-slate-300 mb-2">Perif&eacute;ricos USB Detectados (Via PowerShell)</h4>
                        <div class="bg-slate-900 rounded p-3 text-xs font-mono text-slate-400 border border-slate-700" id="modal-usb-list">
                            Nenhum perif&eacute;rico listado no banco.
                        </div>
                    </div>
                </div>

                <!-- TAB CONTENT: SOFTWARE -->
                <div id="content-sw" class="hidden">
                    <div class="overflow-x-auto">
                        <table class="w-full text-left text-xs">
                            <thead class="bg-slate-900 text-slate-400"><tr><th class="p-2">Nome</th><th class="p-2">Vers&atilde;o</th><th class="p-2">Vendor</th></tr></thead>
                            <tbody id="modal-sw-body" class="divide-y divide-slate-700 text-slate-300"></tbody>
                        </table>
                    </div>
                </div>

                <!-- TAB CONTENT: COMPLIANCE -->
                <div id="content-cis" class="hidden">
                    <div class="mb-4 p-4 bg-slate-900 rounded-lg border border-slate-700 flex justify-between items-center">
                        <div>
                            <span class="text-sm text-slate-400 block">Status da Auditoria</span>
                            <span class="font-bold text-lg text-white" id="modal-score-explain">--</span>
                        </div>
                        <span class="font-mono text-xs text-blue-400 bg-blue-500/10 px-2 py-1 rounded" id="modal-policy-name">--</span>
                    </div>
                    <div class="overflow-x-auto">
                        <table class="w-full text-left text-xs">
                            <thead class="bg-slate-900 text-slate-400"><tr><th class="p-2 w-10">Status</th><th class="p-2">Regra</th><th class="p-2">Output</th></tr></thead>
                            <tbody id="modal-cis-body" class="divide-y divide-slate-700 text-slate-300"></tbody>
                        </table>
                    </div>
                </div>

            </div>
        </div>
    </div>

    <script>
        const API_URL = '/api/agents';
        let uniqueAgents = [];

        async function fetchAgents() {
            try {
                const res = await fetch(API_URL);
                const agents = await res.json();
                const map = new Map();
                agents.forEach(a => {
                    const exist = map.get(a.hostname);
                    const curr = new Date(a.last_seen_at || 0);
                    if(!exist || curr > new Date(exist.last_seen_at || 0)) map.set(a.hostname, a);
                });
                uniqueAgents = Array.from(map.values());
                renderTable();
                renderKPIs();
            } catch(e) { console.error(e); }
        }

        function renderKPIs() {
            document.getElementById('kpi-total').innerText = uniqueAgents.length;
            let totalScore = 0, scoredAgents = 0;
            uniqueAgents.forEach(a => {
                if (a.compliance_score !== null && a.compliance_score !== undefined) {
                    totalScore += a.compliance_score;
                    scoredAgents++;
                }
            });
            const avgScore = scoredAgents > 0 ? Math.round(totalScore / scoredAgents) : 0;
            document.getElementById('kpi-score').innerText = avgScore + '%';
        }

        function renderTable() {
            const tbody = document.getElementById('table-body');
            tbody.innerHTML = '';
            uniqueAgents.forEach(agent => {
                const lastSeen = agent.last_seen_at ? new Date(agent.last_seen_at).toLocaleString() : 'N/A';
                const statusBadge = agent.status === 'ONLINE' ? '<span class="text-emerald-400 font-bold">&#9679; ON</span>' : '<span class="text-slate-500 font-bold">&#9679; OFF</span>';
                const iconClass = agent.os_name.toLowerCase().includes('windows') ? 'ph-windows-logo' : 'ph-linux-logo';
                
                let scoreHtml = '<span class="text-slate-600">-</span>';
                if(agent.compliance_score !== null) {
                    let color = 'text-red-400 border-red-500/30 bg-red-500/10';
                    if(agent.compliance_score >= 80) color = 'text-emerald-400 border-emerald-500/30 bg-emerald-500/10';
                    else if(agent.compliance_score >= 50) color = 'text-amber-400 border-amber-500/30 bg-amber-500/10';
                    scoreHtml = `<span class="px-2 py-1 rounded border ${color} font-bold text-xs">${agent.compliance_score}%</span>`;
                }

                const row = document.createElement('tr');
                row.className = 'hover:bg-slate-800/50 transition-colors border-b border-slate-700/50';
                row.innerHTML = `
                    <td class="p-3 font-medium text-white flex items-center gap-2">
                        <div class="w-8 h-8 rounded bg-slate-700 flex items-center justify-center text-slate-300"><i class="ph-fill ${iconClass} text-lg"></i></div>
                        <div><div>${agent.hostname}</div><div class="text-[10px] text-slate-500 font-mono">${agent.id.substring(0,8)}...</div></div>
                    </td>
                    <td class="p-3 text-[10px]">${statusBadge}</td>
                    <td class="p-3 text-slate-400">${agent.os_name}</td>
                    <td class="p-3 text-center">${scoreHtml}</td>
                    <td class="p-3 text-slate-500">${lastSeen}</td>
                    <td class="p-3 text-right"><button onclick="openDetails('${agent.id}')" class="text-blue-400 hover:text-white text-xs font-bold border border-blue-500/30 px-3 py-1 rounded">Ver</button></td>
                `;
                tbody.appendChild(row);
            });
        }

        async function openDetails(id) {
            const modal = document.getElementById('details-modal');
            modal.classList.remove('opacity-0', 'pointer-events-none');
            document.getElementById('modal-hostname').innerText = "Carregando...";
            
            try {
                const res = await fetch('/api/agents/' + id + '/details');
                const data = await res.json();
                if(data) {
                    document.getElementById('modal-hostname').innerText = data.agent.hostname;
                    document.getElementById('modal-id').innerText = data.agent.id;
                    
                    // Hardware Tab
                    const hw = data.hardware || {};
                    document.getElementById('modal-cpu').innerText = hw.cpu_model || 'N/A';
                    document.getElementById('modal-cores').innerText = hw.cpu_cores || '-';
                    document.getElementById('modal-ram').innerText = (hw.ram_total_mb ? (hw.ram_total_mb/1024).toFixed(1) + ' GB' : 'N/A');
                    document.getElementById('modal-disk').innerText = (hw.disk_total_gb ? hw.disk_total_gb + ' GB' : 'N/A');
                    
                    // Software Tab
                    const swBody = document.getElementById('modal-sw-body');
                    swBody.innerHTML = '';
                    data.software.forEach(s => {
                        swBody.innerHTML += `<tr class="border-b border-slate-700/50"><td class="p-2 text-white">${s.name}</td><td class="p-2 text-slate-400">${s.version||'-'}</td><td class="p-2 text-slate-500">${s.vendor||'-'}</td></tr>`;
                    });

                    // Compliance Tab
                    const cisBody = document.getElementById('modal-cis-body');
                    cisBody.innerHTML = '';
                    if(data.compliance && data.compliance.details) {
                        document.getElementById('modal-policy-name').innerText = data.compliance.policy_id || 'Unknown Policy';
                        
                        // Score Explanation
                        const passed = data.compliance.passed_checks || 0;
                        const total = data.compliance.total_checks || 0;
                        const pct = data.compliance.score || 0;
                        let colorText = 'text-red-400';
                        if(pct >= 50) colorText = 'text-amber-400';
                        if(pct >= 80) colorText = 'text-emerald-400';
                        
                        document.getElementById('modal-score-explain').innerHTML = `<span class="${colorText}">${pct}% Aprovado</span> <span class="text-xs text-slate-500 font-normal ml-2">(${passed} de ${total} regras)</span>`;

                        data.compliance.details.forEach(rule => {
                            const statusBadge = rule.status === 'PASS' 
                                ? '<span class="bg-emerald-500/20 text-emerald-400 px-2 py-0.5 rounded text-[10px] font-bold border border-emerald-500/30">PASS</span>'
                                : '<span class="bg-red-500/20 text-red-400 px-2 py-0.5 rounded text-[10px] font-bold border border-red-500/30">FAIL</span>';
                            
                            cisBody.innerHTML += `
                                <tr class="border-b border-slate-700/50 hover:bg-slate-800/30">
                                    <td class="p-3">${statusBadge}</td>
                                    <td class="p-3 text-white font-medium text-xs">
                                        ${rule.title}
                                        <div class="text-[10px] text-slate-500 font-mono mt-0.5">ID: ${rule.rule_id}</div>
                                    </td>
                                    <td class="p-3 text-[10px] text-slate-400 font-mono break-all max-w-xs">${rule.output}</td>
                                </tr>`;
                        });
                    } else {
                        cisBody.innerHTML = '<tr><td colspan="3" class="p-4 text-center text-slate-500">Nenhum dado de auditoria dispon&iacute;vel.</td></tr>';
                    }
                }
            } catch(e) {}
        }

        function switchTab(tab) {
            document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
            document.getElementById('tab-' + tab).classList.add('active');
            
            document.getElementById('content-hw').classList.add('hidden');
            document.getElementById('content-sw').classList.add('hidden');
            document.getElementById('content-cis').classList.add('hidden');
            document.getElementById('content-' + tab).classList.remove('hidden');
        }

        function closeModal() { document.getElementById('details-modal').classList.add('opacity-0', 'pointer-events-none'); }
        document.querySelector('.modal-overlay').addEventListener('click', closeModal);

        fetchAgents();
        setInterval(fetchAgents, 5000);
    </script>
</body>
</html>
'@
$Utf8NoBom = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllText("$PWD/assets/index.html", $htmlContent, $Utf8NoBom)

Write-Host "[SUCCESS] UI Restaurada e Melhorada (v2.0)!" -ForegroundColor Cyan