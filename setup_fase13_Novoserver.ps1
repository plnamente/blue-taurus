# ==============================================================================
# BLUE-TAURUS: FASE 13 - SCA INTEGRATION (FULL CYCLE + DETAILS)
# Descrição: Envia relatório do Agente -> Server -> DB -> Dashboard.
# Fix 2.0: Atualiza URL do Agente para o servidor de Producao (Coolify).
# Fix 2.2: Implementa a nova interface "Vulnerabilidades (CVE)" baseada no design do Paulo.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 13] Atualizando Interface para Design System v3.0..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# ==============================================================================
# 1. SHARED: Protocolo (MANTIDO)
# ==============================================================================
Write-Host "[CODE] Verificando Protocolo..." -ForegroundColor Green
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
Write-Host "[SQL] Verificando Migrations..." -ForegroundColor Green
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
# 3. AGENT: Net Loop (MANTIDO)
# ==============================================================================
Write-Host "[CODE] Verificando Agente..." -ForegroundColor Green
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
    // URL DE PRODUCAO (Coolify)
    let url = Url::parse("ws://uk4gco4wgco84s0gco0w4co8.72.60.141.205.sslip.io/ws").unwrap();

    loop {
        tracing::info!("Tentando conectar ao servidor em {}...", url);
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
                        tracing::error!("Erro ao enviar: {}", e);
                    }
                }

                loop {
                    tokio::select! {
                        _ = sleep(Duration::from_secs(10)) => {
                            let hb = Message::Heartbeat { agent_id, timestamp: chrono::Utc::now() };
                            if let Err(_) = write.send(WsMessage::Text(serde_json::to_string(&hb).unwrap())).await { break; }
                        }
                        msg = read.next() => {
                           if let Some(Ok(WsMessage::Text(_))) = msg { } else if msg.is_none() { break; }
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
# 4. SERVER: Gravar Detalhes (MANTIDO)
# ==============================================================================
Write-Host "[CODE] Verificando Servidor..." -ForegroundColor Green
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
                        let _ = sqlx::query("INSERT INTO agents (id, hostname, os_name, status, last_seen_at) VALUES ($1, $2, $3, 'ONLINE', NOW()) ON CONFLICT(id) DO UPDATE SET last_seen_at = NOW(), status='ONLINE'").bind(agent_id).bind(&host_info.hostname).bind(&host_info.os_name).execute(&state.pg_pool).await;
                        let temp = host_info.hardware.cpu_temp_c;
                        let _ = sqlx::query("INSERT INTO hardware_specs (agent_id, cpu_model, cpu_cores, ram_total_mb, disk_total_gb, cpu_temp_c) VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (agent_id) DO UPDATE SET cpu_model=EXCLUDED.cpu_model, ram_total_mb=EXCLUDED.ram_total_mb, cpu_temp_c=EXCLUDED.cpu_temp_c").bind(agent_id).bind(&host_info.hardware.cpu_model).bind(host_info.hardware.cpu_cores as i32).bind(host_info.hardware.ram_total_mb as i64).bind(host_info.hardware.disk_total_gb as i64).bind(temp).execute(&state.pg_pool).await;
                        let _ = sqlx::query("DELETE FROM software_inventory WHERE agent_id = $1").bind(agent_id).execute(&state.pg_pool).await;
                        for sw in &host_info.software { let _ = sqlx::query("INSERT INTO software_inventory (agent_id, name, version, vendor, install_date) VALUES ($1, $2, $3, $4, $5)").bind(agent_id).bind(&sw.name).bind(&sw.version).bind(&sw.vendor).bind(&sw.install_date).execute(&state.pg_pool).await; }
                    },
                    Message::ScaReport { agent_id, report } => {
                        let details_json = serde_json::to_value(&report.results).unwrap_or_default();
                        let q = "INSERT INTO compliance_scores (agent_id, policy_id, score, total_checks, passed_checks, details, last_scan_at) VALUES ($1, $2, $3, $4, $5, $6, NOW()) ON CONFLICT (agent_id) DO UPDATE SET score = EXCLUDED.score, passed_checks = EXCLUDED.passed_checks, details = EXCLUDED.details, last_scan_at = NOW()";
                        let _ = sqlx::query(q).bind(agent_id).bind(&report.policy_id).bind(report.score as i32).bind(report.total_checks as i32).bind(report.passed_checks as i32).bind(details_json).execute(&state.pg_pool).await;
                    },
                    _ => {}
                }
            }
        }
    }
}
'@
$serverSocketCode | Out-File -FilePath "crates/server/src/socket/mod.rs" -Encoding utf8

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
#[derive(Serialize, sqlx::FromRow)] pub struct AgentRow { id: Uuid, hostname: String, os_name: String, status: Option<String>, last_seen_at: Option<chrono::DateTime<chrono::Utc>>, compliance_score: Option<i32> }
#[derive(Serialize)] pub struct AgentDetails { agent: AgentRow, hardware: Option<HardwareRow>, software: Vec<SoftwareRow>, compliance: Option<ComplianceDetails> }
#[derive(Serialize, sqlx::FromRow)] pub struct HardwareRow { cpu_model: Option<String>, cpu_cores: Option<i32>, cpu_temp_c: Option<f32>, ram_total_mb: Option<i64>, disk_total_gb: Option<i64> }
#[derive(Serialize, sqlx::FromRow)] pub struct SoftwareRow { name: String, version: Option<String>, vendor: Option<String>, install_date: Option<String> }
#[derive(Serialize, sqlx::FromRow)] pub struct ComplianceDetails { policy_id: Option<String>, score: Option<i32>, details: Option<serde_json::Value> }

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    if std::env::var("RUST_LOG").is_err() { std::env::set_var("RUST_LOG", "info"); }
    tracing_subscriber::fmt::init();
    dotenv().ok();
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL");
    let pg_pool = PgPoolOptions::new().max_connections(5).connect(&db_url).await.expect("PG Fail");
    sqlx::migrate!("./migrations").run(&pg_pool).await.ok(); 
    let es_url = std::env::var("ELASTIC_URL").expect("ELASTIC_URL");
    let transport = Transport::single_node(&es_url)?;
    let elastic_client = Elasticsearch::new(transport);
    let state = Arc::new(AppState { pg_pool, elastic_client });
    let app = Router::new().route("/api/agents", get(list_agents)).route("/api/agents/:id", delete(delete_agent)).route("/api/agents/:id/details", get(get_agent_details)).route("/ws", get(socket::ws_handler)).nest_service("/", ServeDir::new("assets")).with_state(state);
    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    axum::Server::bind(&addr).serve(app.into_make_service()).await.unwrap();
    Ok(())
}

async fn list_agents(State(state): State<Arc<AppState>>) -> Json<Vec<AgentRow>> {
    let sql = "SELECT a.id, a.hostname, a.os_name, a.status, a.last_seen_at, c.score as compliance_score FROM agents a LEFT JOIN compliance_scores c ON a.id = c.agent_id ORDER BY a.last_seen_at DESC";
    let agents = sqlx::query_as::<_, AgentRow>(sql).fetch_all(&state.pg_pool).await.unwrap_or_default();
    Json(agents)
}
async fn delete_agent(Path(id): Path<Uuid>, State(state): State<Arc<AppState>>) -> http::StatusCode {
    let _ = sqlx::query("DELETE FROM compliance_scores WHERE agent_id = $1").bind(id).execute(&state.pg_pool).await;
    let _ = sqlx::query("DELETE FROM software_inventory WHERE agent_id = $1").bind(id).execute(&state.pg_pool).await;
    let _ = sqlx::query("DELETE FROM hardware_specs WHERE agent_id = $1").bind(id).execute(&state.pg_pool).await;
    let _ = sqlx::query("DELETE FROM agents WHERE id = $1").bind(id).execute(&state.pg_pool).await;
    http::StatusCode::NO_CONTENT
}
async fn get_agent_details(Path(id): Path<Uuid>, State(state): State<Arc<AppState>>) -> Json<Option<AgentDetails>> {
    let agent = sqlx::query_as::<_, AgentRow>("SELECT id, hostname, os_name, status, last_seen_at, NULL::int as compliance_score FROM agents WHERE id = $1").bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);
    if let Some(ag) = agent {
        let hw = sqlx::query_as::<_, HardwareRow>("SELECT cpu_model, cpu_cores, cpu_temp_c, ram_total_mb, disk_total_gb FROM hardware_specs WHERE agent_id = $1").bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);
        let sw = sqlx::query_as::<_, SoftwareRow>("SELECT name, version, vendor, install_date FROM software_inventory WHERE agent_id = $1 ORDER BY name ASC").bind(id).fetch_all(&state.pg_pool).await.unwrap_or_default();
        let comp = sqlx::query_as::<_, ComplianceDetails>("SELECT policy_id, score, details FROM compliance_scores WHERE agent_id = $1").bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);
        return Json(Some(AgentDetails { agent: ag, hardware: hw, software: sw, compliance: comp }));
    }
    Json(None)
}
'@
$serverMainCode | Out-File -FilePath "crates/server/src/main.rs" -Encoding utf8

# ==============================================================================
# 6. UI: Reescrever Index HTML (LAYOUT DEFINITIVO PAULO)
# ==============================================================================
Write-Host "[UI] Reescrevendo assets/index.html (Layout Design Paulo)..." -ForegroundColor Green
$htmlContent = @'
<!DOCTYPE html>
<html lang="pt-BR" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Blue-Taurus | Cyber Defense Platform</title>
    
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/lucide@latest"></script>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap');
        
        :root {
            --bg-deep: #0B1120;
            --bg-surface: #151E32;
            --accent-cyan: #06B6D4;
            --accent-danger: #EF4444;
            --accent-success: #10B981;
            --accent-warn: #F59E0B;
        }

        body { font-family: 'Inter', sans-serif; background-color: var(--bg-deep); color: #E2E8F0; }
        .mono-font { font-family: 'JetBrains Mono', monospace; }
        .glass-panel { background: rgba(21, 30, 50, 0.7); backdrop-filter: blur(12px); border: 1px solid rgba(255, 255, 255, 0.08); box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.3); }
        .nav-item.active { background: linear-gradient(90deg, rgba(6,182,212,0.15) 0%, rgba(0,0,0,0) 100%); border-left: 3px solid var(--accent-cyan); color: var(--accent-cyan); }
        .fade-in { animation: fadeIn 0.3s ease-in-out; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(5px); } to { opacity: 1; transform: translateY(0); } }
        /* Badge Pulse */
        .defcon-pulse { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); animation: pulse-green 2s infinite; }
        @keyframes pulse-green { 0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); } 70% { transform: scale(1); box-shadow: 0 0 0 10px rgba(16, 185, 129, 0); } 100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); } }
        
        /* Modal Transitions */
        .modal { transition: opacity 0.25s ease; }
        body.modal-active { overflow: hidden; }
        .tab-btn.active { border-bottom: 2px solid var(--accent-cyan); color: var(--accent-cyan); }
    </style>

    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    colors: {
                        navy: '#0B1120',
                        surface: '#151E32',
                        cyan: '#06B6D4'
                    }
                }
            }
        }
    </script>
</head>
<body class="h-screen flex overflow-hidden selection:bg-cyan-500/30 selection:text-cyan-200">

    <!-- SIDEBAR -->
    <aside class="w-64 bg-[#111827] border-r border-slate-800 flex flex-col justify-between z-20 shadow-xl">
        <div>
            <!-- Logo -->
            <div class="h-20 flex items-center px-6 border-b border-slate-800 bg-[#0f172a]">
                <i data-lucide="shield-check" class="text-white w-6 h-6 mr-3"></i>
                <div>
                    <h1 class="font-bold text-lg tracking-wider text-white">BLUETAURUS</h1>
                    <p class="text-[10px] text-slate-500 uppercase tracking-widest">Cyber Defense Platform</p>
                </div>
            </div>

            <!-- Menu -->
            <nav class="mt-8 space-y-1 px-3">
                <a href="#" onclick="switchTab('dashboard', this)" class="nav-item active flex items-center px-3 py-3 text-sm font-medium rounded-md text-slate-400 hover:text-white hover:bg-slate-800/50 transition-all">
                    <i data-lucide="layout-grid" class="w-5 h-5 mr-3"></i> Dashboard Tático
                </a>
                
                <div class="pt-6 pb-2 px-3 text-[10px] font-bold text-slate-600 uppercase tracking-widest">Operações</div>
                
                 <a href="#" onclick="switchTab('inventory', this)" class="nav-item flex items-center px-3 py-3 text-sm font-medium rounded-md text-slate-400 hover:text-white hover:bg-slate-800/50 transition-all">
                    <i data-lucide="server" class="w-5 h-5 mr-3"></i> Inventário de Ativos (EDR)
                </a>
                
                <a href="#" onclick="switchTab('analytics', this)" class="nav-item flex items-center px-3 py-3 text-sm font-medium rounded-md text-slate-400 hover:text-white hover:bg-slate-800/50 transition-all">
                    <i data-lucide="terminal" class="w-5 h-5 mr-3"></i> Data Analytics (SQL)
                </a>
                
                <a href="#" onclick="switchTab('threat-hunting', this)" class="nav-item flex items-center px-3 py-3 text-sm font-medium rounded-md text-slate-400 hover:text-white hover:bg-slate-800/50 transition-all">
                    <i data-lucide="crosshair" class="w-5 h-5 mr-3"></i> Threat Hunting
                </a>

                <a href="#" onclick="switchTab('vulnerabilities', this)" class="nav-item flex items-center px-3 py-3 text-sm font-medium rounded-md text-slate-400 hover:text-white hover:bg-slate-800/50 transition-all border-l-2 border-transparent">
                    <i data-lucide="shield-alert" class="w-5 h-5 mr-3"></i> Vulnerabilidades (CVE)
                </a>

                <div class="pt-6 pb-2 px-3 text-[10px] font-bold text-slate-600 uppercase tracking-widest">Governança (GRC)</div>

                <a href="#" onclick="switchTab('compliance', this)" class="nav-item flex items-center px-3 py-3 text-sm font-medium rounded-md text-slate-400 hover:text-white hover:bg-slate-800/50 transition-all">
                    <i data-lucide="list-todo" class="w-5 h-5 mr-3"></i> CIS Controls v8
                </a>
                
                <div class="pt-6 pb-2 px-3 text-[10px] font-bold text-slate-600 uppercase tracking-widest">Sistema</div>
                
                <a href="#" onclick="switchTab('config', this)" class="nav-item flex items-center px-3 py-3 text-sm font-medium rounded-md text-slate-400 hover:text-white hover:bg-slate-800/50 transition-all">
                    <i data-lucide="settings-2" class="w-5 h-5 mr-3"></i> Configurações
                </a>
            </nav>
        </div>

        <div class="p-4 border-t border-slate-800 bg-[#0f172a]">
            <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-slate-700 flex items-center justify-center font-bold text-white">AD</div>
                <div>
                    <p class="text-sm text-white font-medium">Admin</p>
                    <p class="text-[10px] text-slate-500">SecOps Analyst</p>
                </div>
            </div>
        </div>
    </aside>

    <!-- MAIN AREA -->
    <main class="flex-1 flex flex-col relative bg-[#0B1120]">
        <!-- Topbar -->
        <header class="h-20 border-b border-slate-800 bg-[#0B1120] flex items-center justify-between px-8 z-10">
            <div class="relative w-96">
                <i data-lucide="search" class="absolute left-3 top-3 w-4 h-4 text-slate-500"></i>
                <input type="text" placeholder="Buscar IPs, CVEs, Users ou Assets..." class="w-full bg-[#151E32] border border-slate-700 rounded-lg pl-10 pr-16 py-2.5 text-sm focus:outline-none focus:border-cyan-500 text-slate-200">
                <span class="absolute right-2 top-2.5 px-2 py-0.5 bg-slate-800 rounded text-[10px] text-slate-500 font-bold border border-slate-700">CTRL+K</span>
            </div>

            <div class="flex items-center gap-6">
                <div class="flex items-center gap-2 px-4 py-1.5 bg-[#0f172a] border border-emerald-900 rounded-full">
                    <div class="w-2 h-2 bg-emerald-500 rounded-full defcon-pulse"></div>
                    <span class="text-xs font-bold text-emerald-500 tracking-wider">DEFCON 5</span>
                </div>
                <button class="text-slate-400 hover:text-white"><i data-lucide="bell" class="w-5 h-5"></i></button>
                <button class="text-slate-400 hover:text-white"><i data-lucide="help-circle" class="w-5 h-5"></i></button>
            </div>
        </header>

        <!-- Content -->
        <div class="flex-1 overflow-y-auto p-8 relative scroll-smooth" id="content-area">
            
            <!-- DASHBOARD -->
            <section id="view-dashboard" class="space-y-6 fade-in">
                <h2 class="text-xl font-bold text-white mb-6">Data Analytics Dashboard</h2>
                <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
                    <div class="glass-panel p-6 rounded-lg border-l-4 border-blue-500">
                        <p class="text-[10px] font-bold text-slate-400 uppercase">Total Ativos</p>
                        <h3 class="text-3xl font-bold text-white mt-2" id="kpi-total">--</h3>
                    </div>
                    <div class="glass-panel p-6 rounded-lg border-l-4 border-emerald-500">
                        <p class="text-[10px] font-bold text-slate-400 uppercase">Compliance Score</p>
                        <h3 class="text-3xl font-bold text-emerald-400 mt-2" id="kpi-score">--%</h3>
                        <p class="text-xs text-slate-500 mt-1">Média da Rede (CIS v8)</p>
                    </div>
                    <div class="glass-panel p-6 rounded-lg border-l-4 border-amber-500">
                        <p class="text-[10px] font-bold text-slate-400 uppercase">Riscos Altos</p>
                        <h3 class="text-3xl font-bold text-white mt-2">--</h3>
                    </div>
                    <div class="glass-panel p-6 rounded-lg border-l-4 border-purple-500">
                        <p class="text-[10px] font-bold text-slate-400 uppercase">Eventos (24h)</p>
                        <h3 class="text-3xl font-bold text-white mt-2">--</h3>
                    </div>
                </div>
                
                <!-- Inventory Table Preview -->
                <div class="glass-panel rounded-lg border border-slate-700 overflow-hidden mt-8">
                    <div class="px-6 py-4 border-b border-slate-700 flex justify-between items-center bg-[#151E32]/50">
                        <h3 class="text-sm font-bold text-white flex items-center gap-2"><i data-lucide="list" class="w-4 h-4 text-cyan-500"></i> Inventário de Máquinas</h3>
                        <button onclick="fetchAgents()" class="text-slate-400 hover:text-white"><i data-lucide="refresh-cw" class="w-4 h-4"></i></button>
                    </div>
                    <table class="w-full text-left text-xs">
                        <thead class="bg-[#111827] text-slate-500 font-bold uppercase tracking-wider">
                            <tr>
                                <th class="px-6 py-4">Ativo / Hostname</th>
                                <th class="px-6 py-4">Status</th>
                                <th class="px-6 py-4">Sistema</th>
                                <th class="px-6 py-4 text-center">Score CIS</th>
                                <th class="px-6 py-4">Último Visto</th>
                                <th class="px-6 py-4 text-right">Ação</th>
                            </tr>
                        </thead>
                        <tbody id="inventory-body" class="divide-y divide-slate-800 text-slate-300 font-medium"></tbody>
                    </table>
                </div>
            </section>
            
            <!-- VULNERABILIDADES (NOVO) -->
            <section id="view-vulnerabilities" class="hidden space-y-6 fade-in">
                <div class="flex items-center gap-3 mb-6">
                    <i data-lucide="shield-alert" class="w-6 h-6 text-red-500"></i>
                    <h2 class="text-2xl font-bold text-white">Vulnerabilidades (CVE)</h2>
                </div>

                <!-- Sync Bar -->
                <div class="glass-panel p-6 rounded-lg flex justify-between items-center border border-slate-700">
                    <div class="flex gap-12">
                        <div>
                            <p class="text-[10px] text-slate-500 uppercase font-bold tracking-wider">Última sincronização</p>
                            <p class="text-white font-mono mt-1 text-sm">--</p>
                        </div>
                        <div>
                            <p class="text-[10px] text-slate-500 uppercase font-bold tracking-wider">CVEs</p>
                            <p class="text-white font-mono mt-1 text-sm font-bold">0</p>
                        </div>
                    </div>
                    <button class="flex items-center gap-2 px-4 py-2 bg-slate-800 hover:bg-slate-700 text-white rounded transition-colors text-xs font-bold uppercase tracking-wider border border-slate-600">
                        <i data-lucide="refresh-cw" class="w-3 h-3"></i> Sincronizar
                    </button>
                </div>

                <!-- Severity Cards -->
                <div class="grid grid-cols-4 gap-6">
                    <div class="glass-panel p-6 rounded-lg border-l-4 border-red-600 bg-red-900/10">
                        <p class="text-[10px] text-slate-400 uppercase font-bold tracking-widest">CRITICAL</p>
                        <h3 class="text-4xl font-bold text-red-500 mt-2">0</h3>
                    </div>
                    <div class="glass-panel p-6 rounded-lg border-l-4 border-orange-500 bg-orange-900/10">
                        <p class="text-[10px] text-slate-400 uppercase font-bold tracking-widest">HIGH</p>
                        <h3 class="text-4xl font-bold text-orange-500 mt-2">0</h3>
                    </div>
                    <div class="glass-panel p-6 rounded-lg border-l-4 border-yellow-500 bg-yellow-900/10">
                        <p class="text-[10px] text-slate-400 uppercase font-bold tracking-widest">MEDIUM</p>
                        <h3 class="text-4xl font-bold text-yellow-500 mt-2">0</h3>
                    </div>
                    <div class="glass-panel p-6 rounded-lg border-l-4 border-blue-500 bg-blue-900/10">
                        <p class="text-[10px] text-slate-400 uppercase font-bold tracking-widest">LOW</p>
                        <h3 class="text-4xl font-bold text-blue-500 mt-2">0</h3>
                    </div>
                </div>

                <!-- CVE Table -->
                <div class="glass-panel rounded-lg border border-slate-700 overflow-hidden min-h-[300px] flex flex-col">
                    <div class="grid grid-cols-12 gap-4 px-6 py-3 border-b border-slate-700 bg-slate-900/50 text-[10px] text-slate-500 font-bold uppercase tracking-wider">
                        <div class="col-span-2">CVE ID</div>
                        <div class="col-span-2">Severity</div>
                        <div class="col-span-1">CVSS</div>
                        <div class="col-span-7">Description</div>
                    </div>
                    <div class="flex-1 flex flex-col items-center justify-center text-slate-600 p-8">
                        <p class="text-sm">Nenhuma vulnerabilidade encontrada. Execute a sincronização.</p>
                    </div>
                </div>
            </section>
            
            <!-- Placeholder para outras telas -->
            <section id="view-inventory" class="hidden fade-in"><h2 class="text-white text-xl">Inventário Completo (Em breve)</h2></section>
            <section id="view-analytics" class="hidden fade-in"><h2 class="text-white text-xl">SQL Analytics (Em breve)</h2></section>
            <section id="view-threat-hunting" class="hidden fade-in"><h2 class="text-white text-xl">Threat Hunting (Em breve)</h2></section>
            <section id="view-compliance" class="hidden fade-in"><h2 class="text-white text-xl">CIS Controls (Em breve)</h2></section>
            <section id="view-config" class="hidden fade-in"><h2 class="text-white text-xl">Configurações (Em breve)</h2></section>

        </div>
    </main>

    <!-- MODAL DETALHES -->
    <div id="details-modal" class="modal opacity-0 pointer-events-none fixed w-full h-full top-0 left-0 flex items-center justify-center z-50">
        <div class="modal-overlay absolute w-full h-full bg-black/80 backdrop-blur-sm"></div>
        <div class="modal-container bg-[#0f172a] w-11/12 md:max-w-5xl mx-auto border border-cyan-500/30 shadow-[0_0_50px_rgba(59,130,246,0.15)] flex flex-col max-h-[90vh] rounded-lg">
            <div class="p-6 border-b border-slate-800 flex justify-between items-center bg-black/40">
                <div class="flex items-center gap-4">
                    <div class="w-10 h-10 rounded border border-slate-700 bg-slate-800 flex items-center justify-center text-cyan-500"><i data-lucide="monitor" class="w-6 h-6"></i></div>
                    <div>
                        <h3 class="text-xl font-bold text-white tracking-wide" id="modal-hostname">HOST</h3>
                        <p class="text-[10px] text-slate-500 font-mono mt-0.5 uppercase tracking-wider" id="modal-id">UUID</p>
                    </div>
                </div>
                <button onclick="closeModal()" class="text-slate-400 hover:text-white transition-colors"><i data-lucide="x" class="w-6 h-6"></i></button>
            </div>
            
            <div class="flex-1 flex overflow-hidden">
                <div class="w-48 bg-black/20 border-r border-slate-800 p-4 space-y-2">
                    <button id="tab-hw" onclick="switchTabModal('hw')" class="tab-btn w-full text-left px-4 py-3 rounded text-xs font-bold uppercase tracking-wider text-slate-400 hover:bg-slate-800 hover:text-white transition-all border-l-2 border-transparent active">HARDWARE</button>
                    <button id="tab-sw" onclick="switchTabModal('sw')" class="tab-btn w-full text-left px-4 py-3 rounded text-xs font-bold uppercase tracking-wider text-slate-400 hover:bg-slate-800 hover:text-white transition-all border-l-2 border-transparent">SOFTWARE</button>
                    <button id="tab-cis" onclick="switchTabModal('cis')" class="tab-btn w-full text-left px-4 py-3 rounded text-xs font-bold uppercase tracking-wider text-slate-400 hover:bg-slate-800 hover:text-white transition-all border-l-2 border-transparent">SECURITY</button>
                </div>
                <div class="flex-1 p-8 overflow-y-auto bg-slate-900/50">
                    <div id="content-hw" class="space-y-6 block">
                        <div class="grid grid-cols-4 gap-4">
                            <div class="glass-panel p-4 text-center rounded"><p class="text-[10px] text-slate-500 uppercase font-bold">CPU</p><p class="text-white font-mono text-sm mt-1" id="modal-cpu">-</p></div>
                            <div class="glass-panel p-4 text-center rounded"><p class="text-[10px] text-slate-500 uppercase font-bold">Cores</p><p class="text-white font-mono text-sm mt-1" id="modal-cores">-</p></div>
                            <div class="glass-panel p-4 text-center rounded"><p class="text-[10px] text-slate-500 uppercase font-bold">RAM</p><p class="text-white font-mono text-sm mt-1" id="modal-ram">-</p></div>
                            <div class="glass-panel p-4 text-center rounded"><p class="text-[10px] text-slate-500 uppercase font-bold">Disk</p><p class="text-white font-mono text-sm mt-1" id="modal-disk">-</p></div>
                        </div>
                        <div class="glass-panel p-4 border-l-4 border-l-orange-500 bg-orange-500/5 mt-4 rounded" id="thermal-card">
                             <div class="flex justify-between items-center">
                                <span class="text-xs font-bold text-orange-400 uppercase tracking-widest">Thermal Sensor</span>
                                <span class="text-xl font-bold text-white font-mono" id="modal-temp">--</span>
                             </div>
                        </div>
                    </div>
                    <div id="content-sw" class="hidden">
                        <table class="w-full text-left text-xs font-mono">
                            <thead class="text-slate-500 border-b border-slate-700"><tr><th class="pb-2">PACKAGE</th><th class="pb-2">VERSION</th><th class="pb-2">VENDOR</th></tr></thead>
                            <tbody id="modal-sw-body" class="divide-y divide-slate-800 text-slate-300"></tbody>
                        </table>
                    </div>
                    <div id="content-cis" class="hidden">
                         <div class="mb-6 flex justify-between items-center pb-4 border-b border-slate-800">
                            <div><span class="text-xs text-slate-500 uppercase font-bold">Audit Status</span><div class="text-lg font-bold text-white mt-1" id="modal-score-explain">--</div></div>
                            <div class="px-3 py-1 rounded bg-blue-500/10 text-blue-400 text-xs font-mono border border-blue-500/20" id="modal-policy-name">--</div>
                        </div>
                        <table class="w-full text-left text-xs font-mono">
                            <thead class="text-slate-500"><tr><th class="pb-2 w-16">RESULT</th><th class="pb-2">RULE</th><th class="pb-2">OUTPUT</th></tr></thead>
                            <tbody id="modal-cis-body" class="divide-y divide-slate-800 text-slate-300"></tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        lucide.createIcons();
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
            uniqueAgents.forEach(a => { if (a.compliance_score != null) { totalScore += a.compliance_score; scoredAgents++; } });
            const avg = scoredAgents > 0 ? Math.round(totalScore / scoredAgents) : 0;
            document.getElementById('kpi-score').innerText = avg + '%';
        }

        function renderTable() {
            const tbody = document.getElementById('inventory-body');
            tbody.innerHTML = '';
            uniqueAgents.forEach(a => {
                 const status = a.status === 'ONLINE' 
                    ? '<span class="text-emerald-400 font-bold text-[10px] tracking-wide">● ON</span>' 
                    : '<span class="text-slate-600 font-bold text-[10px] tracking-wide">● OFF</span>';
                
                let score = '<span class="text-slate-700">-</span>';
                if(a.compliance_score !== null) {
                    let c = 'text-red-400 border-red-900/50 bg-red-900/20';
                    if(a.compliance_score >= 80) c = 'text-emerald-400 border-emerald-900/50 bg-emerald-900/20';
                    else if(a.compliance_score >= 50) c = 'text-yellow-400 border-yellow-900/50 bg-yellow-900/20';
                    score = `<span class="px-2 py-0.5 rounded border ${c} font-bold text-[10px]">${a.compliance_score}%</span>`;
                }

                // Icon logic
                let icon = 'monitor';
                if(a.os_name.toLowerCase().includes('windows')) icon = 'layout-grid'; // Placeholder for win
                
                tbody.innerHTML += `
                    <tr class="hover:bg-white/5 transition-colors border-b border-slate-800/50">
                        <td class="px-6 py-4">
                            <div class="flex items-center">
                                <div class="w-8 h-8 rounded bg-slate-800 flex items-center justify-center text-cyan-600 mr-3"><i data-lucide="${icon}" class="w-4 h-4"></i></div>
                                <div>
                                    <div class="font-bold text-white text-xs">${a.hostname}</div>
                                    <div class="text-[10px] text-slate-500 font-mono mt-0.5">${a.id.substring(0,8)}...</div>
                                </div>
                            </div>
                        </td>
                        <td class="px-6 py-4">${status}</td>
                        <td class="px-6 py-4 text-xs text-slate-400">${a.os_name}</td>
                        <td class="px-6 py-4 text-center">${score}</td>
                        <td class="px-6 py-4 text-xs text-slate-500">${new Date(a.last_seen_at).toLocaleTimeString()}</td>
                        <td class="px-6 py-4 text-right">
                            <button onclick="openDetails('${a.id}')" class="text-xs font-bold text-slate-300 hover:text-white bg-slate-800 hover:bg-cyan-600 px-3 py-1.5 rounded transition-colors border border-slate-700 hover:border-cyan-500">Ver</button>
                        </td>
                    </tr>`;
            });
            lucide.createIcons();
        }

        function switchTab(screenId, element) {
            document.querySelectorAll('section[id^="view-"]').forEach(e => e.classList.add('hidden'));
            document.getElementById('view-' + screenId).classList.remove('hidden');
            
            document.querySelectorAll('.nav-item').forEach(e => {
                e.classList.remove('active');
                e.classList.remove('text-cyan-400');
                e.classList.add('text-slate-400');
            });

            if (element) {
                element.classList.add('active');
                element.classList.remove('text-slate-400');
            }
        }

        async function openDetails(id) {
            document.getElementById('details-modal').classList.remove('opacity-0', 'pointer-events-none');
            document.body.classList.add('modal-active');
            
            try {
                const res = await fetch('/api/agents/' + id + '/details');
                const data = await res.json();
                if(data) {
                    document.getElementById('modal-hostname').innerText = data.agent.hostname;
                    document.getElementById('modal-id').innerText = data.agent.id;
                    const hw = data.hardware || {};
                    document.getElementById('modal-cpu').innerText = hw.cpu_model || 'Unknown';
                    document.getElementById('modal-cores').innerText = hw.cpu_cores || '-';
                    document.getElementById('modal-ram').innerText = (hw.ram_total_mb/1024).toFixed(1) + ' GB';
                    document.getElementById('modal-disk').innerText = hw.disk_total_gb + ' GB';
                    
                    if(hw.cpu_temp_c) {
                        document.getElementById('modal-temp').innerHTML = `${Math.round(hw.cpu_temp_c)}&deg;C`;
                        if(hw.cpu_temp_c > 75) document.getElementById('thermal-card').classList.add('animate-pulse');
                    } else { document.getElementById('modal-temp').innerText = "N/A"; }

                    const swBody = document.getElementById('modal-sw-body'); swBody.innerHTML = '';
                    data.software.forEach(s => swBody.innerHTML += `<tr class="border-b border-slate-800/50"><td class="py-2 text-white">${s.name}</td><td class="py-2 text-slate-500">${s.version||'-'}</td><td class="py-2 text-slate-600">${s.vendor||'-'}</td></tr>`);

                    const cisBody = document.getElementById('modal-cis-body'); cisBody.innerHTML = '';
                    if(data.compliance && data.compliance.details) {
                        data.compliance.details.forEach(r => {
                            const badge = r.status === 'PASS' ? '<span class="text-emerald-400 font-bold text-[10px]">PASS</span>' : '<span class="text-red-400 font-bold text-[10px]">FAIL</span>';
                            cisBody.innerHTML += `<tr class="border-b border-slate-800/50"><td class="py-2">${badge}</td><td class="py-2 text-white">${r.title}</td><td class="py-2 text-slate-500 font-mono text-[10px]">${r.output}</td></tr>`;
                        });
                        document.getElementById('modal-score-explain').innerText = data.compliance.score + '% Secure';
                    }
                }
            } catch(e){}
        }

        function switchTabModal(t) {
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            document.getElementById('tab-'+t).classList.add('active');
            document.querySelectorAll('[id^="content-"]').forEach(c => c.classList.add('hidden'));
            document.getElementById('content-'+t).classList.remove('hidden');
        }

        function closeModal() { 
            document.getElementById('details-modal').classList.add('opacity-0', 'pointer-events-none'); 
            document.body.classList.remove('modal-active');
        }
        
        fetchAgents();
        setInterval(fetchAgents, 5000);
    </script>
</body>
</html>
'@
$Utf8NoBom = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllText("$PWD/assets/index.html", $htmlContent, $Utf8NoBom)

Write-Host "[SUCCESS] UI V3.0 (Security Ops Center) aplicada!" -ForegroundColor Cyan
Write-Host "1. Execute 'git add .', 'git commit' e 'git push'."
Write-Host "2. Facça Redeploy no Coolify."