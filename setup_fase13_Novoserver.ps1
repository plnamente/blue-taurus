# ==============================================================================
# BLUE-TAURUS: FASE 13 - SCA INTEGRATION (FULL CYCLE + DETAILS)
# Descrição: Envia relatório do Agente -> Server -> DB -> Dashboard.
# Fix 1.9: Substitui sqlx::query! (macro) por sqlx::query (funcao) para permitir
#          compilacao no Docker sem acesso ao banco de dados (Bypass compile-time check).
# Fix 2.0: Atualiza URL do Agente para o servidor de Producao (Coolify).
# Fix 2.1: Incorpora UI Sci-Fi completa no script (para garantir update visual).
# Fix 2.2: Atualiza UI para o novo layout "Security Operations Center".
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
    <title>Blue-Taurus | Security Operations Center</title>
    
    <!-- Bibliotecas Externas para Prototipagem Rápida -->
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/lucide@latest"></script>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    
    <!-- Fontes Técnicas -->
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap');
        
        :root {
            --bg-deep: #0B1120;
            --bg-surface: #151E32;
            --accent-cyan: #06B6D4;
            --accent-danger: #EF4444;
            --accent-success: #10B981;
        }

        body { 
            font-family: 'Inter', sans-serif; 
            background-color: var(--bg-deep);
            color: #E2E8F0;
        }
        
        .mono-font { font-family: 'JetBrains Mono', monospace; }
        
        /* Glassmorphism Sutil para Paineis */
        .glass-panel {
            background: rgba(21, 30, 50, 0.7);
            backdrop-filter: blur(12px);
            border: 1px solid rgba(255, 255, 255, 0.08);
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.3);
        }

        /* Scrollbar estilo "Hacker" */
        ::-webkit-scrollbar { width: 6px; height: 6px; }
        ::-webkit-scrollbar-track { background: #0B1120; }
        ::-webkit-scrollbar-thumb { background: #334155; border-radius: 3px; }
        ::-webkit-scrollbar-thumb:hover { background: #475569; }

        /* Animações e Transições */
        .fade-in { animation: fadeIn 0.3s ease-in-out; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(5px); } to { opacity: 1; transform: translateY(0); } }

        .nav-item.active {
            background: linear-gradient(90deg, rgba(6,182,212,0.15) 0%, rgba(0,0,0,0) 100%);
            border-left: 3px solid var(--accent-cyan);
            color: var(--accent-cyan);
        }

        /* SQL Universal Syntax Highlighting (Postgres & Elastic Compatible) */
        .sql-keyword { color: #F472B6; font-weight: bold; } /* Pink: SELECT, FROM, WHERE */
        .sql-function { color: #60A5FA; } /* Blue: COUNT, NOW, AVG */
        .sql-string { color: #A78BFA; } /* Purple: 'tables', 'values' */
        .sql-number { color: #FCD34D; } /* Yellow */
        .sql-comment { color: #64748B; font-style: italic; } /* Slate */
        .sql-operator { color: #E2E8F0; } /* White/Gray: =, >, < */
        
        /* Status Badges */
        .badge-success { background: rgba(16, 185, 129, 0.2); color: #34D399; border: 1px solid rgba(16, 185, 129, 0.3); }
        .badge-fail { background: rgba(239, 68, 68, 0.2); color: #F87171; border: 1px solid rgba(239, 68, 68, 0.3); }
        .badge-online { color: #34D399; font-weight: bold; text-shadow: 0 0 5px rgba(16, 185, 129, 0.5); }
        .badge-offline { color: #64748b; font-weight: bold; }

        /* --- ANIMAÇÃO CYBER GLITCH (LOGO) --- */
        .cyber-glitch {
            position: relative;
            display: inline-block;
        }

        .cyber-glitch::before,
        .cyber-glitch::after {
            content: attr(data-text);
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: #111827; /* Mesma cor do background da sidebar */
        }

        .cyber-glitch::before {
            left: 2px;
            text-shadow: -1px 0 #EF4444; /* Vermelho falha */
            clip: rect(24px, 550px, 90px, 0);
            animation: glitch-anim-2 3s infinite linear alternate-reverse;
        }

        .cyber-glitch::after {
            left: -2px;
            text-shadow: -1px 0 #06B6D4; /* Ciano falha */
            clip: rect(85px, 550px, 140px, 0);
            animation: glitch-anim 2.5s infinite linear alternate-reverse;
        }

        @keyframes glitch-anim {
            0% { clip: rect(14px, 9999px, 127px, 0); }
            20% { clip: rect(66px, 9999px, 88px, 0); }
            40% { clip: rect(130px, 9999px, 136px, 0); }
            60% { clip: rect(29px, 9999px, 86px, 0); }
            80% { clip: rect(98px, 9999px, 126px, 0); }
            100% { clip: rect(113px, 9999px, 49px, 0); }
        }

        @keyframes glitch-anim-2 {
            0% { clip: rect(122px, 9999px, 63px, 0); }
            20% { clip: rect(96px, 9999px, 137px, 0); }
            40% { clip: rect(74px, 9999px, 59px, 0); }
            60% { clip: rect(27px, 9999px, 20px, 0); }
            80% { clip: rect(54px, 9999px, 32px, 0); }
            100% { clip: rect(15px, 9999px, 78px, 0); }
        }

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
                        primary: '#3B82F6',
                        cyan: '#06B6D4'
                    }
                }
            }
        }
    </script>
</head>
<body class="h-screen flex overflow-hidden selection:bg-cyan-500/30 selection:text-cyan-200">

    <!-- ================= SIDEBAR (Navegação Principal) ================= -->
    <aside class="w-72 bg-[#111827] border-r border-slate-800 flex flex-col justify-between z-20 shadow-xl">
        <div>
            <!-- Header do Projeto -->
            <div class="h-16 flex items-center px-6 border-b border-slate-800 bg-[#0f172a]">
                <div class="w-8 h-8 bg-cyan-600 rounded flex items-center justify-center mr-3 shadow-[0_0_10px_rgba(8,145,178,0.5)]">
                    <i data-lucide="shield-check" class="text-white w-5 h-5"></i>
                </div>
                <div>
                    <h1 class="font-bold text-lg tracking-wider text-white">
                        BLUE<span class="text-cyan-500 cyber-glitch" data-text="TAURUS">TAURUS</span>
                    </h1>
                    <p class="text-[10px] text-slate-500 uppercase tracking-widest">Cyber Defense Platform</p>
                </div>
            </div>

            <!-- Links de Navegação -->
            <nav class="mt-6 space-y-1 px-2">
                <a href="#" onclick="navigate('dashboard', this)" id="nav-dashboard" class="nav-item active flex items-center px-4 py-3 text-sm font-medium rounded-md transition-all text-slate-300 hover:text-white hover:bg-slate-800/50 group">
                    <i data-lucide="layout-grid" class="w-5 h-5 mr-3 group-hover:text-cyan-400 transition-colors"></i>
                    Dashboard Tático
                </a>
                
                <div class="pt-4 pb-2 px-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest">Operações</div>
                
                 <a href="#" onclick="navigate('inventory', this)" id="nav-inventory" class="nav-item flex items-center px-4 py-3 text-sm font-medium rounded-md transition-all text-slate-300 hover:text-white hover:bg-slate-800/50 group">
                    <i data-lucide="server" class="w-5 h-5 mr-3 group-hover:text-cyan-400 transition-colors"></i>
                    Inventário de Ativos (EDR)
                </a>
                
                <a href="#" onclick="navigate('analytics', this)" id="nav-analytics" class="nav-item flex items-center px-4 py-3 text-sm font-medium rounded-md transition-all text-slate-300 hover:text-white hover:bg-slate-800/50 group">
                    <i data-lucide="terminal" class="w-5 h-5 mr-3 group-hover:text-cyan-400 transition-colors"></i>
                    Data Analytics (SQL)
                </a>
                <a href="#" onclick="navigate('threat-hunting', this)" id="nav-threat-hunting" class="nav-item flex items-center px-4 py-3 text-sm font-medium rounded-md transition-all text-slate-300 hover:text-white hover:bg-slate-800/50 group">
                    <i data-lucide="crosshair" class="w-5 h-5 mr-3 group-hover:text-cyan-400 transition-colors"></i>
                    Threat Hunting
                </a>

                <div class="pt-4 pb-2 px-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest">Governança (GRC)</div>

                <a href="#" onclick="navigate('compliance', this)" id="nav-compliance" class="nav-item flex items-center px-4 py-3 text-sm font-medium rounded-md transition-all text-slate-300 hover:text-white hover:bg-slate-800/50 group">
                    <i data-lucide="list-todo" class="w-5 h-5 mr-3 group-hover:text-emerald-400 transition-colors"></i>
                    CIS Controls v8
                </a>
                
                <div class="pt-4 pb-2 px-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest">Sistema</div>
                
                <a href="#" onclick="navigate('config', this)" id="nav-config" class="nav-item flex items-center px-4 py-3 text-sm font-medium rounded-md transition-all text-slate-300 hover:text-white hover:bg-slate-800/50 group">
                    <i data-lucide="settings-2" class="w-5 h-5 mr-3 group-hover:text-cyan-400 transition-colors"></i>
                    Configurações
                </a>
            </nav>
        </div>

        <!-- Footer do Usuário -->
        <div class="p-4 border-t border-slate-800 bg-[#0f172a]">
            <div class="flex items-center gap-3">
                <div class="relative">
                    <div class="w-10 h-10 rounded-full bg-slate-700 flex items-center justify-center border border-slate-600">
                        <span class="font-bold text-cyan-400">KO</span>
                    </div>
                    <div class="absolute bottom-0 right-0 w-3 h-3 bg-emerald-500 rounded-full border-2 border-[#0f172a]"></div>
                </div>
                <div>
                    <p class="text-sm text-white font-medium">Kortana AI</p>
                    <p class="text-xs text-slate-400">Senior SecOps Architect</p>
                </div>
            </div>
        </div>
    </aside>

    <!-- ================= MAIN CONTENT ================= -->
    <main class="flex-1 flex flex-col relative bg-[#0B1120]">
        
        <!-- Topbar Global -->
        <header class="h-16 border-b border-slate-800 bg-[#0B1120]/80 backdrop-blur-md flex items-center justify-between px-8 z-10">
            <!-- Barra de Busca Global -->
            <div class="flex items-center w-96 relative">
                <i data-lucide="search" class="absolute left-3 w-4 h-4 text-slate-500"></i>
                <input type="text" placeholder="Buscar IPs, CVEs, Users ou Assets..." class="w-full bg-[#151E32] border border-slate-700 rounded-lg pl-10 pr-4 py-2 text-sm focus:outline-none focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 transition-all placeholder:text-slate-600 text-slate-200">
                <div class="absolute right-2 px-2 py-0.5 bg-slate-800 rounded text-[10px] text-slate-400 font-mono border border-slate-700">CTRL+K</div>
            </div>

            <!-- Status do Sistema -->
            <div class="flex items-center gap-6">
                <div class="flex items-center gap-2 px-3 py-1.5 bg-red-500/10 border border-red-500/20 rounded-full">
                    <span class="relative flex h-2 w-2">
                        <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
                        <span class="relative inline-flex rounded-full h-2 w-2 bg-red-500"></span>
                    </span>
                    <span class="text-xs font-bold text-red-400 tracking-wider">DEFCON 4</span>
                </div>
                
                <div class="h-6 w-px bg-slate-700"></div>
                
                <button class="text-slate-400 hover:text-white transition-colors relative">
                    <i data-lucide="bell" class="w-5 h-5"></i>
                    <span class="absolute -top-1 -right-1 w-2 h-2 bg-cyan-500 rounded-full"></span>
                </button>
            </div>
        </header>

        <!-- Container de Conteúdo -->
        <div class="flex-1 overflow-y-auto p-8 relative scroll-smooth" id="content-area">
            
            <!-- TELA 1: DASHBOARD -->
            <section id="view-dashboard" class="space-y-6 fade-in">
                <div class="flex justify-between items-end">
                    <div>
                        <h2 class="text-2xl font-bold text-white">Security Posture Overview</h2>
                        <p class="text-slate-400 text-sm mt-1">Monitoramento em tempo real de ativos e ameaças.</p>
                    </div>
                </div>

                <!-- KPI Cards -->
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    <!-- Card 1 -->
                    <div class="glass-panel p-5 rounded-xl border-l-4 border-cyan-500 relative overflow-hidden group">
                        <div class="absolute right-0 top-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
                            <i data-lucide="monitor-smartphone" class="w-16 h-16 text-cyan-500"></i>
                        </div>
                        <p class="text-slate-500 text-xs font-mono uppercase tracking-wider">Ativos Monitorados</p>
                        <h3 id="kpi-total" class="text-3xl font-bold text-white mt-1">--</h3>
                    </div>

                    <!-- Card 2 -->
                    <div class="glass-panel p-5 rounded-xl border-l-4 border-emerald-500 relative overflow-hidden group">
                        <div class="absolute right-0 top-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
                            <i data-lucide="shield-check" class="w-16 h-16 text-emerald-500"></i>
                        </div>
                        <p class="text-slate-500 text-xs font-mono uppercase tracking-wider">Compliance Score</p>
                        <h3 id="kpi-score" class="text-3xl font-bold text-white mt-1">--%</h3>
                        <p class="text-xs text-slate-500 mt-1">Média CIS v8</p>
                    </div>
                </div>
            </section>

             <!-- TELA 2: INVENTORY -->
            <section id="view-inventory" class="hidden space-y-6 fade-in">
                <div class="glass-panel rounded-lg border border-slate-700 overflow-hidden">
                    <div class="px-4 py-3 bg-slate-800/80 border-b border-slate-700 flex justify-between items-center">
                        <h3 class="text-sm font-bold text-white flex items-center gap-2">
                            <i data-lucide="server" class="w-4 h-4 text-cyan-500"></i> Inventário de Máquinas
                        </h3>
                        <button onclick="fetchAgents()" class="text-slate-400 hover:text-white transition-transform hover:rotate-180"><i data-lucide="refresh-cw" class="w-4 h-4"></i></button>
                    </div>
                    <table class="w-full text-left text-xs">
                        <thead class="bg-slate-900 text-slate-500 font-mono uppercase">
                            <tr>
                                <th class="px-4 py-3">Hostname</th>
                                <th class="px-4 py-3">Status</th>
                                <th class="px-4 py-3">OS</th>
                                <th class="px-4 py-3 text-center">Score CIS</th>
                                <th class="px-4 py-3">Last Seen</th>
                                <th class="px-4 py-3 text-right">Action</th>
                            </tr>
                        </thead>
                        <tbody id="inventory-body" class="divide-y divide-slate-800 text-slate-300">
                        </tbody>
                    </table>
                </div>
            </section>

             <!-- TELA 3: COMPLIANCE (CIS v8) -->
            <section id="view-compliance" class="hidden space-y-6 fade-in">
                <div class="flex justify-between items-end border-b border-slate-800 pb-6">
                    <div>
                        <h3 class="text-2xl font-bold text-white tracking-tight">SHIELD INTEGRITY PROTOCOLS</h3>
                        <p class="text-slate-500 text-xs mt-1 font-mono uppercase">Standard: CIS Critical Security Controls v8.1</p>
                    </div>
                </div>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4" id="cis-grid">
                    <!-- Cards de Compliance Mockados -->
                    <div class="glass-panel p-4 border border-slate-700 bg-slate-800/50 flex justify-between items-center"><div><p class="text-[10px] text-slate-500 uppercase font-bold">Control 01</p><h4 class="text-sm font-bold text-white">Inventory of Assets</h4></div><div class="text-xl font-mono font-bold text-emerald-400">100%</div></div>
                     <div class="glass-panel p-4 border border-slate-700 bg-slate-800/50 flex justify-between items-center"><div><p class="text-[10px] text-slate-500 uppercase font-bold">Control 02</p><h4 class="text-sm font-bold text-white">Inventory of Software</h4></div><div class="text-xl font-mono font-bold text-emerald-400">100%</div></div>
                      <div class="glass-panel p-4 border border-slate-700 bg-slate-800/50 flex justify-between items-center"><div><p class="text-[10px] text-slate-500 uppercase font-bold">Control 08</p><h4 class="text-sm font-bold text-white">Audit Log Management</h4></div><div class="text-xl font-mono font-bold text-emerald-400">100%</div></div>
                </div>
            </section>
        </div>
    </main>

    <!-- MODAL DETALHES -->
    <div id="details-modal" class="modal opacity-0 pointer-events-none fixed w-full h-full top-0 left-0 flex items-center justify-center z-50">
        <div class="modal-overlay absolute w-full h-full bg-black/80 backdrop-blur-sm"></div>
        <div class="modal-container bg-[#0f172a] w-11/12 md:max-w-5xl mx-auto border border-cyan-500/30 shadow-[0_0_50px_rgba(59,130,246,0.15)] flex flex-col max-h-[90vh]">
            <!-- Modal Header -->
            <div class="p-6 border-b border-slate-800 flex justify-between items-center bg-black/40">
                <div class="flex items-center gap-4">
                    <div class="w-10 h-10 rounded border border-slate-700 bg-slate-800 flex items-center justify-center text-cyan-500"><i data-lucide="monitor" class="w-6 h-6"></i></div>
                    <div>
                        <h3 class="text-xl font-bold text-white tracking-wide" id="modal-hostname">HOST</h3>
                        <p class="text-[10px] text-slate-500 font-mono mt-0.5 uppercase tracking-wider" id="modal-id">UUID</p>
                    </div>
                </div>
                <button onclick="closeModal()" class="text-slate-400 hover:text-red-400 transition-colors"><i data-lucide="x" class="w-6 h-6"></i></button>
            </div>
            
            <div class="flex-1 flex overflow-hidden">
                <!-- Modal Sidebar -->
                <div class="w-48 bg-black/20 border-r border-slate-800 p-4 space-y-2">
                    <button id="tab-hw" onclick="switchTabModal('hw')" class="tab-btn w-full text-left px-4 py-3 rounded text-xs font-bold uppercase tracking-wider text-slate-400 hover:bg-slate-800 hover:text-white transition-all border-l-2 border-transparent active">HARDWARE</button>
                    <button id="tab-sw" onclick="switchTabModal('sw')" class="tab-btn w-full text-left px-4 py-3 rounded text-xs font-bold uppercase tracking-wider text-slate-400 hover:bg-slate-800 hover:text-white transition-all border-l-2 border-transparent">SOFTWARE</button>
                    <button id="tab-cis" onclick="switchTabModal('cis')" class="tab-btn w-full text-left px-4 py-3 rounded text-xs font-bold uppercase tracking-wider text-slate-400 hover:bg-slate-800 hover:text-white transition-all border-l-2 border-transparent">SECURITY</button>
                </div>

                <!-- Modal Content -->
                <div class="flex-1 p-8 overflow-y-auto bg-slate-900/50">
                    <!-- HW TAB -->
                    <div id="content-hw" class="space-y-6 block">
                        <div class="grid grid-cols-4 gap-4">
                            <div class="glass-panel p-4 text-center"><p class="text-[10px] text-slate-500 uppercase">CPU Core</p><p class="text-white font-bold font-mono text-sm mt-1" id="modal-cpu">-</p></div>
                            <div class="glass-panel p-4 text-center"><p class="text-[10px] text-slate-500 uppercase">Threads</p><p class="text-white font-bold font-mono text-sm mt-1" id="modal-cores">-</p></div>
                            <div class="glass-panel p-4 text-center"><p class="text-[10px] text-slate-500 uppercase">Memory</p><p class="text-white font-bold font-mono text-sm mt-1" id="modal-ram">-</p></div>
                            <div class="glass-panel p-4 text-center"><p class="text-[10px] text-slate-500 uppercase">Storage</p><p class="text-white font-bold font-mono text-sm mt-1" id="modal-disk">-</p></div>
                        </div>
                         <!-- Thermal -->
                        <div class="glass-panel p-4 border-l-4 border-l-orange-500 bg-orange-500/5 mt-4" id="thermal-card">
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

    <!-- Script de Funcionalidade -->
    <script>
        // Inicializa Icones Lucide
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
                    ? '<span class="badge-online">● ON</span>' 
                    : '<span class="badge-offline">● OFF</span>';
                
                let score = '<span class="text-slate-700">-</span>';
                if(a.compliance_score !== null) {
                    let c = 'text-accent-danger border-accent-danger bg-red-500/10';
                    if(a.compliance_score >= 80) c = 'text-accent-success border-accent-success bg-emerald-500/10';
                    else if(a.compliance_score >= 50) c = 'text-yellow-400 border-yellow-500/30 bg-yellow-500/10';
                    score = `<span class="px-2 py-0.5 rounded border ${c} font-bold text-[10px]">${a.compliance_score}%</span>`;
                }

                tbody.innerHTML += `
                    <tr class="hover:bg-white/5 transition-colors border-b border-slate-800/50">
                        <td class="p-4 font-bold text-white">${a.hostname}<div class="text-[10px] text-slate-600 font-normal">${a.id.substring(0,8)}</div></td>
                        <td class="p-4 text-xs">${status}</td>
                        <td class="p-4 text-slate-400">${a.os_name}</td>
                        <td class="p-4 text-center">${score}</td>
                        <td class="p-4 text-slate-500 text-[10px]">${new Date(a.last_seen_at).toLocaleTimeString()}</td>
                        <td class="p-4 text-right"><button onclick="openDetails('${a.id}')" class="text-cyan-400 hover:text-white text-xs font-bold border border-cyan-500/30 hover:bg-cyan-500 hover:border-cyan-500 px-3 py-1 rounded transition-all shadow-[0_0_10px_rgba(6,182,212,0.3)]">ACCESS</button></td>
                    </tr>`;
            });
        }

        function navigate(view, element) {
            document.querySelectorAll('section[id^="view-"]').forEach(e => e.classList.add('hidden'));
            document.getElementById('view-' + view).classList.remove('hidden');
            
            // Remove active de todos
            document.querySelectorAll('.nav-item').forEach(e => {
                e.classList.remove('active');
                e.classList.remove('text-cyan-400');
                e.classList.add('text-slate-300');
            });

            // Adiciona active ao atual
            if(element) {
                element.classList.add('active');
                element.classList.remove('text-slate-300');
            }
        }

        // --- Modal Logic ---
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
                            const badge = r.status === 'PASS' ? '<span class="badge-success px-2 py-0.5 rounded text-[10px] font-bold">PASS</span>' : '<span class="badge-fail px-2 py-0.5 rounded text-[10px] font-bold">FAIL</span>';
                            cisBody.innerHTML += `<tr class="border-b border-slate-800/50"><td class="py-2 text-xs">${badge}</td><td class="py-2 text-white">${r.title}</td><td class="py-2 text-slate-500 font-mono text-[10px]">${r.output}</td></tr>`;
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

Write-Host "[SUCCESS] Codigo atualizado para Docker (Runtime Queries) e UI v2.0 aplicada!" -ForegroundColor Cyan
Write-Host "1. Commit e Push."
Write-Host "2. Redeploy no Coolify."