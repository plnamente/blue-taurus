# ==============================================================================
# BLUE-TAURUS: FASE 13 - SCA INTEGRATION (FULL CYCLE + DETAILS)
# Descrição: Envia relatório do Agente -> Server -> DB -> Dashboard.
# Fix 1.9: Substitui sqlx::query! (macro) por sqlx::query (funcao) para permitir
#          compilacao no Docker sem acesso ao banco de dados (Bypass compile-time check).
# Fix 2.0: Atualiza URL do Agente para o servidor de Producao (Coolify).
# Fix 2.1: Incorpora UI Sci-Fi completa no script (para garantir update visual).
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
    // URL DE PRODUCAO (Coolify)
    // Nota: Se configurar SSL no Coolify depois, mude para wss://
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

# ==============================================================================
# 6. UI: Reescrever Index HTML (TEMA SCI-FI + REAL DATA)
# ==============================================================================
Write-Host "[UI] Reescrevendo assets/index.html (Sci-Fi Theme + Modal Completo)..." -ForegroundColor Green
$htmlContent = @'
<!DOCTYPE html>
<html lang="pt-BR" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Blue-Taurus | Command Bridge</title>
    
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    
    <!-- Fonte Tática: JetBrains Mono -->
    <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap" rel="stylesheet">
    <script src="https://unpkg.com/@phosphor-icons/web"></script>

    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                fontFamily: { sans: ['"JetBrains Mono"', 'monospace'] },
                extend: {
                    colors: {
                        void: '#0b1120',      // Void Black
                        nebula: '#3b82f6',    // Nebula Blue
                        starlight: '#f8fafc', // Starlight White
                        alert: '#ef4444',     // Alert Red
                        success: '#10b981',   // Success Emerald
                        glass: 'rgba(30, 41, 59, 0.6)'
                    },
                    boxShadow: {
                        'neon': '0 0 10px rgba(59, 130, 246, 0.5)',
                        'neon-red': '0 0 10px rgba(239, 68, 68, 0.5)',
                    }
                }
            }
        }
    </script>
    <style>
        body { background-color: #0b1120; color: #f8fafc; background-image: radial-gradient(circle at 50% 0%, #1e293b 0%, #0b1120 60%); }
        
        /* Glassmorphism Cards */
        .card { 
            background: rgba(30, 41, 59, 0.4); 
            border: 1px solid rgba(59, 130, 246, 0.2); 
            backdrop-filter: blur(12px);
            border-radius: 0.5rem; 
            transition: all 0.3s ease;
        }
        .card:hover { border-color: rgba(59, 130, 246, 0.5); box-shadow: 0 0 15px rgba(59, 130, 246, 0.1); }

        /* Scrollbar Cyberpunk */
        ::-webkit-scrollbar { width: 6px; height: 6px; }
        ::-webkit-scrollbar-track { background: #020617; }
        ::-webkit-scrollbar-thumb { background: #334155; border-radius: 3px; }
        ::-webkit-scrollbar-thumb:hover { background: #3b82f6; }
        
        .nav-item.active { 
            background: linear-gradient(90deg, rgba(59,130,246,0.15) 0%, transparent 100%); 
            color: #60a5fa; 
            border-left: 2px solid #60a5fa; 
        }
    </style>
</head>
<body class="flex h-screen overflow-hidden selection:bg-nebula selection:text-white">

    <!-- SIDEBAR -->
    <aside class="w-64 border-r border-slate-800 bg-slate-900/50 backdrop-blur-md flex flex-col z-30">
        <div class="h-20 flex items-center px-6 border-b border-slate-800">
            <i class="ph-fill ph-shield-star text-nebula text-3xl mr-3 animate-pulse"></i>
            <div>
                <h1 class="font-bold text-lg tracking-widest text-white">BLUE<span class="text-nebula">TAURUS</span></h1>
                <p class="text-[10px] text-slate-500 tracking-widest uppercase">Defense System v1.5</p>
            </div>
        </div>

        <nav class="flex-1 p-4 space-y-2 overflow-y-auto">
            <p class="px-3 text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-2 mt-4">Operations</p>
            
            <a href="#" onclick="navigate('dashboard')" id="nav-dashboard" class="nav-item active flex items-center gap-3 px-3 py-3 text-xs font-bold uppercase tracking-wider text-slate-400 hover:text-white transition-all">
                <i class="ph-bold ph-squares-four text-lg"></i> Command Bridge
            </a>
            
            <a href="#" onclick="navigate('inventory')" id="nav-inventory" class="nav-item flex items-center gap-3 px-3 py-3 text-xs font-bold uppercase tracking-wider text-slate-400 hover:text-white transition-all">
                <i class="ph-bold ph-hard-drives text-lg"></i> Sentinel Nodes
            </a>

            <p class="px-3 text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-2 mt-8">Defense Grid</p>

            <a href="#" onclick="navigate('compliance')" id="nav-compliance" class="nav-item flex items-center gap-3 px-3 py-3 text-xs font-bold uppercase tracking-wider text-slate-400 hover:text-white transition-all">
                <i class="ph-bold ph-shield-check text-lg"></i> Shield Integrity
            </a>
            
            <a href="#" onclick="Swal.fire('Modulo Off-line', 'Radar de longo alcance inativo.', 'warning')" class="nav-item flex items-center gap-3 px-3 py-3 text-xs font-bold uppercase tracking-wider text-slate-400 hover:text-white transition-all">
                <i class="ph-bold ph-skull text-lg"></i> Hull Breaches
            </a>
        </nav>

        <div class="p-4 border-t border-slate-800 bg-black/20">
            <div class="flex items-center gap-3">
                <div class="w-8 h-8 rounded border border-nebula bg-nebula/20 flex items-center justify-center text-xs font-bold text-nebula shadow-neon">CMDR</div>
                <div>
                    <p class="text-xs font-bold text-white uppercase">Commander</p>
                    <p class="text-[10px] text-emerald-500">SECURE LINK</p>
                </div>
            </div>
        </div>
    </aside>

    <!-- MAIN AREA -->
    <main class="flex-1 flex flex-col overflow-hidden relative">
        
        <header class="h-20 flex items-center justify-between px-8 border-b border-slate-800 bg-slate-900/30 backdrop-blur-md">
            <div>
                <h2 id="page-title" class="text-xl font-bold text-white tracking-wide">COMMAND BRIDGE</h2>
                <p class="text-[10px] text-slate-500 uppercase tracking-widest">Sector Alpha // Monitoring</p>
            </div>
            <div class="flex items-center gap-4">
                <div class="px-4 py-1.5 rounded border border-emerald-500/30 bg-emerald-500/10 text-emerald-400 text-xs font-bold uppercase tracking-wider flex items-center gap-2 shadow-neon">
                    <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span> Systems Nominal
                </div>
            </div>
        </header>

        <div class="flex-1 overflow-y-auto p-8 scroll-smooth" id="content-area">
            
            <!-- VIEW: DASHBOARD -->
            <div id="view-dashboard" class="space-y-6 fade-in">
                <!-- KPIs -->
                <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
                    <div class="card p-6 border-t-2 border-nebula">
                        <p class="text-slate-400 text-[10px] uppercase font-bold tracking-widest">Active Sentinels</p>
                        <h3 id="kpi-total" class="text-4xl font-bold text-white mt-2 font-mono">--</h3>
                    </div>
                    <div class="card p-6 border-t-2 border-emerald-500">
                        <p class="text-slate-400 text-[10px] uppercase font-bold tracking-widest">Shield Integrity</p>
                        <h3 id="kpi-score" class="text-4xl font-bold text-emerald-400 mt-2 font-mono">--%</h3>
                        <p class="text-[10px] text-slate-500 mt-1 uppercase">CIS Level 1</p>
                    </div>
                    <div class="card p-6 border-t-2 border-alert">
                        <p class="text-slate-400 text-[10px] uppercase font-bold tracking-widest">Critical Breaches</p>
                        <h3 class="text-4xl font-bold text-alert mt-2 font-mono">0</h3>
                    </div>
                    <div class="card p-6 border-t-2 border-purple-500">
                        <p class="text-slate-400 text-[10px] uppercase font-bold tracking-widest">Ops Rate (24h)</p>
                        <h3 class="text-4xl font-bold text-white mt-2 font-mono">--</h3>
                    </div>
                </div>

                <!-- Charts -->
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div class="card p-6">
                        <h4 class="text-white font-bold text-xs uppercase tracking-widest mb-6 border-b border-slate-700 pb-2">Compliance Vectors</h4>
                        <div class="h-64"><canvas id="cisChart"></canvas></div>
                    </div>
                    <div class="card p-6">
                        <h4 class="text-white font-bold text-xs uppercase tracking-widest mb-6 border-b border-slate-700 pb-2">OS Distribution</h4>
                        <div class="h-64 flex justify-center"><canvas id="osChart"></canvas></div>
                    </div>
                </div>
            </div>

            <!-- VIEW: INVENTORY -->
            <div id="view-inventory" class="hidden space-y-6 fade-in">
                <div class="card overflow-hidden">
                    <div class="p-4 border-b border-slate-700/50 flex justify-between items-center bg-black/20">
                        <h2 class="text-xs font-bold text-nebula uppercase tracking-widest flex items-center gap-2">
                            <i class="ph-bold ph-list-dashes text-lg"></i> Fleet Manifest
                        </h2>
                        <button onclick="fetchAgents()" class="text-slate-400 hover:text-white transition-transform hover:rotate-180"><i class="ph-bold ph-arrows-clockwise text-xl"></i></button>
                    </div>
                    <table class="w-full text-left text-xs font-mono">
                        <thead class="bg-slate-900/80 text-slate-500 font-bold uppercase tracking-wider">
                            <tr><th class="p-4">Node ID / Host</th><th class="p-4">Status</th><th class="p-4">OS Core</th><th class="p-4 text-center">Shield Score</th><th class="p-4">Last Signal</th><th class="p-4 text-right">Access</th></tr>
                        </thead>
                        <tbody id="inventory-body" class="divide-y divide-slate-800 text-slate-300"></tbody>
                    </table>
                </div>
            </div>

            <!-- VIEW: COMPLIANCE -->
            <div id="view-compliance" class="hidden space-y-6 fade-in">
                <div class="flex justify-between items-end border-b border-slate-800 pb-6">
                    <div>
                        <h3 class="text-2xl font-bold text-white tracking-tight">SHIELD INTEGRITY PROTOCOLS</h3>
                        <p class="text-slate-500 text-xs mt-1 font-mono uppercase">Standard: CIS Critical Security Controls v8.1</p>
                    </div>
                    <div class="text-right">
                        <p class="text-[10px] text-slate-500 uppercase tracking-widest">Global Integrity</p>
                        <p class="text-5xl font-bold text-nebula font-mono">--%</p>
                    </div>
                </div>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4" id="cis-grid"></div>
            </div>

        </div>
    </main>

    <!-- MODAL DETALHES -->
    <div id="details-modal" class="modal opacity-0 pointer-events-none fixed w-full h-full top-0 left-0 flex items-center justify-center z-50">
        <div class="modal-overlay absolute w-full h-full bg-black/80 backdrop-blur-sm"></div>
        <div class="modal-container bg-[#0f172a] w-11/12 md:max-w-5xl mx-auto border border-nebula/30 shadow-[0_0_50px_rgba(59,130,246,0.15)] flex flex-col max-h-[90vh]">
            <!-- Modal Header -->
            <div class="p-6 border-b border-slate-800 flex justify-between items-center bg-black/40">
                <div class="flex items-center gap-4">
                    <div class="w-10 h-10 rounded border border-slate-700 bg-slate-800 flex items-center justify-center text-nebula"><i class="ph-fill ph-desktop text-2xl"></i></div>
                    <div>
                        <h3 class="text-xl font-bold text-white tracking-wide" id="modal-hostname">HOST</h3>
                        <p class="text-[10px] text-slate-500 font-mono mt-0.5 uppercase tracking-wider" id="modal-id">UUID</p>
                    </div>
                </div>
                <button onclick="closeModal()" class="text-slate-400 hover:text-alert transition-colors"><i class="ph-bold ph-x text-2xl"></i></button>
            </div>
            
            <div class="flex-1 flex overflow-hidden">
                <!-- Modal Sidebar -->
                <div class="w-48 bg-black/20 border-r border-slate-800 p-4 space-y-2">
                    <button id="tab-hw" onclick="switchTab('hw')" class="tab-btn w-full text-left px-4 py-3 rounded text-xs font-bold uppercase tracking-wider text-slate-400 hover:bg-slate-800 hover:text-white transition-all border-l-2 border-transparent">HARDWARE</button>
                    <button id="tab-sw" onclick="switchTab('sw')" class="tab-btn w-full text-left px-4 py-3 rounded text-xs font-bold uppercase tracking-wider text-slate-400 hover:bg-slate-800 hover:text-white transition-all border-l-2 border-transparent">SOFTWARE</button>
                    <button id="tab-cis" onclick="switchTab('cis')" class="tab-btn w-full text-left px-4 py-3 rounded text-xs font-bold uppercase tracking-wider text-slate-400 hover:bg-slate-800 hover:text-white transition-all border-l-2 border-transparent">SECURITY</button>
                </div>

                <!-- Modal Content -->
                <div class="flex-1 p-8 overflow-y-auto bg-slate-900/50">
                    <!-- HW TAB -->
                    <div id="content-hw" class="space-y-6">
                        <div class="grid grid-cols-4 gap-4">
                            <div class="card p-4 text-center"><p class="text-[10px] text-slate-500 uppercase">CPU Core</p><p class="text-white font-bold font-mono text-sm mt-1" id="modal-cpu">-</p></div>
                            <div class="card p-4 text-center"><p class="text-[10px] text-slate-500 uppercase">Threads</p><p class="text-white font-bold font-mono text-sm mt-1" id="modal-cores">-</p></div>
                            <div class="card p-4 text-center"><p class="text-[10px] text-slate-500 uppercase">Memory</p><p class="text-white font-bold font-mono text-sm mt-1" id="modal-ram">-</p></div>
                            <div class="card p-4 text-center"><p class="text-[10px] text-slate-500 uppercase">Storage</p><p class="text-white font-bold font-mono text-sm mt-1" id="modal-disk">-</p></div>
                        </div>
                        
                        <!-- Thermal -->
                        <div class="card p-4 border-l-4 border-l-orange-500 bg-orange-500/5" id="thermal-card">
                             <div class="flex justify-between items-center">
                                <span class="text-xs font-bold text-orange-400 uppercase tracking-widest">Thermal Sensor</span>
                                <span class="text-xl font-bold text-white font-mono" id="modal-temp">--</span>
                             </div>
                        </div>
                    </div>

                    <!-- SW TAB -->
                    <div id="content-sw" class="hidden">
                        <table class="w-full text-left text-xs font-mono">
                            <thead class="text-slate-500 border-b border-slate-700"><tr><th class="pb-2">PACKAGE</th><th class="pb-2">VERSION</th><th class="pb-2">VENDOR</th></tr></thead>
                            <tbody id="modal-sw-body" class="divide-y divide-slate-800 text-slate-300"></tbody>
                        </table>
                    </div>

                    <!-- CIS TAB -->
                    <div id="content-cis" class="hidden">
                        <div class="mb-6 flex justify-between items-center pb-4 border-b border-slate-800">
                            <div><span class="text-xs text-slate-500 uppercase">Audit Status</span><div class="text-lg font-bold text-white mt-1" id="modal-score-explain">--</div></div>
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

    <!-- JS LOGIC (Mantida e Adaptada) -->
    <script>
        const API_URL = '/api/agents';
        let uniqueAgents = [];
        let osChartInstance = null;
        let cisChartInstance = null;

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
                renderCharts(uniqueAgents);
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
                    ? '<span class="text-emerald-400 font-bold drop-shadow-[0_0_5px_rgba(16,185,129,0.5)]">● ON</span>' 
                    : '<span class="text-slate-600 font-bold">● OFF</span>';
                
                let score = '<span class="text-slate-700">-</span>';
                if(a.compliance_score !== null) {
                    let c = 'text-alert border-alert/30 bg-alert/10';
                    if(a.compliance_score >= 80) c = 'text-emerald-400 border-emerald-500/30 bg-emerald-500/10';
                    else if(a.compliance_score >= 50) c = 'text-amber-400 border-amber-500/30 bg-amber-500/10';
                    score = `<span class="px-2 py-0.5 rounded border ${c} font-bold text-[10px]">${a.compliance_score}%</span>`;
                }

                tbody.innerHTML += `
                    <tr class="hover:bg-white/5 transition-colors border-b border-slate-800/50">
                        <td class="p-4 font-bold text-white">${a.hostname}<div class="text-[10px] text-slate-600 font-normal">${a.id.substring(0,8)}</div></td>
                        <td class="p-4 text-xs">${status}</td>
                        <td class="p-4 text-slate-400">${a.os_name}</td>
                        <td class="p-4 text-center">${score}</td>
                        <td class="p-4 text-slate-500 text-[10px]">${new Date(a.last_seen_at).toLocaleTimeString()}</td>
                        <td class="p-4 text-right"><button onclick="openDetails('${a.id}')" class="text-nebula hover:text-white text-xs font-bold border border-nebula/30 hover:bg-nebula hover:border-nebula px-3 py-1 rounded transition-all shadow-neon">ACCESS</button></td>
                    </tr>`;
            });
        }

        // Mock CIS Controls for Chart
        const cisControls = [
            { id: 1, name: "Asset Inv", score: 100 }, { id: 2, name: "Soft Inv", score: 100 },
            { id: 3, name: "Data Prot", score: 33 }, { id: 4, name: "Secure Config", score: 50 },
            { id: 8, name: "Logs", score: 100 }
        ];

        function renderCIS() {
            const grid = document.getElementById('cis-grid');
            grid.innerHTML = '';
            cisControls.forEach(c => {
               let color = c.score == 100 ? 'border-emerald-500/30 bg-emerald-500/5' : 'border-slate-700 bg-slate-800/50';
               let text = c.score == 100 ? 'text-emerald-400' : 'text-slate-400';
               grid.innerHTML += `
                <div class="card p-4 ${color} border flex justify-between items-center">
                    <div><p class="text-[10px] text-slate-500 uppercase font-bold">Control 0${c.id}</p><h4 class="text-sm font-bold text-white">${c.name}</h4></div>
                    <div class="text-xl font-mono font-bold ${text}">${c.score}%</div>
                </div>`; 
            });
        }
        
        function renderCharts(agents) {
            const osCounts = {};
            agents.forEach(a => { osCounts[a.os_name] = (osCounts[a.os_name] || 0) + 1 });
            const ctxOs = document.getElementById('osChart').getContext('2d');
            if (osChartInstance) osChartInstance.destroy();
            osChartInstance = new Chart(ctxOs, {
                type: 'doughnut',
                data: {
                    labels: Object.keys(osCounts),
                    datasets: [{ data: Object.values(osCounts), backgroundColor: ['#3b82f6', '#10b981', '#f59e0b'], borderColor: '#1e293b', borderWidth: 0 }]
                },
                options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'right', labels: { color: '#94a3b8', font: {family: '"JetBrains Mono"'} } } } }
            });

            // Mock Chart for CIS Progress
            const ctxCis = document.getElementById('cisChart').getContext('2d');
            if(cisChartInstance) cisChartInstance.destroy();
            cisChartInstance = new Chart(ctxCis, {
                type: 'radar',
                data: {
                    labels: ['IG1', 'IG2', 'IG3', 'Vuln', 'Threats'],
                    datasets: [{
                        label: 'Current Posture',
                        data: [85, 59, 20, 45, 60],
                        backgroundColor: 'rgba(59, 130, 246, 0.2)',
                        borderColor: '#3b82f6',
                        pointBackgroundColor: '#fff'
                    }]
                },
                options: { 
                    responsive: true, maintainAspectRatio: false,
                    scales: { r: { grid: { color: '#334155' }, ticks: { display: false, backdropColor: 'transparent' } } },
                    plugins: { legend: { display: false } }
                }
            });
        }

        // Navigation
        function navigate(view) {
            document.querySelectorAll('[id^="view-"]').forEach(e => e.classList.add('hidden'));
            document.getElementById('view-' + view).classList.remove('hidden');
            document.querySelectorAll('.nav-item').forEach(e => e.classList.remove('active', 'text-nebula'));
            document.getElementById('nav-' + view).classList.add('active', 'text-nebula');
            
            const titles = {'dashboard': 'COMMAND BRIDGE', 'inventory': 'SENTINEL NODES', 'compliance': 'SHIELD INTEGRITY'};
            document.getElementById('page-title').innerText = titles[view];
        }

        // Modal Logic
        async function openDetails(id) {
            document.getElementById('details-modal').classList.remove('opacity-0', 'pointer-events-none');
            // (Logica de fetch mantida igual, apenas renderizando nos novos IDs)
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
                    
                    // Temp
                    if(hw.cpu_temp_c) {
                        document.getElementById('modal-temp').innerHTML = `${Math.round(hw.cpu_temp_c)}&deg;C`;
                        if(hw.cpu_temp_c > 75) document.getElementById('thermal-card').classList.add('animate-pulse');
                    } else { document.getElementById('modal-temp').innerText = "N/A"; }

                    // Software
                    const swBody = document.getElementById('modal-sw-body'); swBody.innerHTML = '';
                    data.software.forEach(s => swBody.innerHTML += `<tr class="border-b border-slate-800/50"><td class="py-2 text-white">${s.name}</td><td class="py-2 text-slate-500">${s.version||'-'}</td><td class="py-2 text-slate-600">${s.vendor||'-'}</td></tr>`);

                    // CIS
                    const cisBody = document.getElementById('modal-cis-body'); cisBody.innerHTML = '';
                    if(data.compliance && data.compliance.details) {
                        data.compliance.details.forEach(r => {
                            const badge = r.status === 'PASS' ? '<span class="text-emerald-400 font-bold">PASS</span>' : '<span class="text-alert font-bold">FAIL</span>';
                            cisBody.innerHTML += `<tr class="border-b border-slate-800/50"><td class="py-2 text-xs">${badge}</td><td class="py-2 text-white">${r.title}</td><td class="py-2 text-slate-500 font-mono text-[10px]">${r.output}</td></tr>`;
                        });
                        document.getElementById('modal-score-explain').innerText = data.compliance.score + '% Secure';
                    }
                }
            } catch(e){}
        }

        function switchTab(t) {
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('text-nebula', 'border-nebula'));
            document.getElementById('tab-'+t).classList.add('text-nebula', 'border-nebula');
            document.querySelectorAll('[id^="content-"]').forEach(c => c.classList.add('hidden'));
            document.getElementById('content-'+t).classList.remove('hidden');
        }

        function closeModal() { document.getElementById('details-modal').classList.add('opacity-0', 'pointer-events-none'); }
        
        renderCIS();
        fetchAgents();
        setInterval(fetchAgents, 5000);
    </script>
</body>
</html>
'@
$Utf8NoBom = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllText("$PWD/assets/index.html", $htmlContent, $Utf8NoBom)

Write-Host "[SUCCESS] Codigo atualizado para Docker (Runtime Queries)!" -ForegroundColor Cyan
Write-Host "1. Commit e Push."
Write-Host "2. Redeploy no Coolify."