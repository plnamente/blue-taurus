# ==============================================================================
# BLUE-TAURUS: FASE 7 - WEB DASHBOARD (UI)
# Descrição: Cria uma interface web moderna e expõe API REST no Server.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 7] Construindo Interface Grafica e API..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# ==============================================================================
# 1. DEPENDENCIAS DO SERVER (Tower-HTTP para servir arquivos)
# ==============================================================================
Write-Host "[FIX] Adicionando tower-http ao Server..." -ForegroundColor Green
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

# Fase 7: Servir Arquivos Estaticos
tower = { version = "0.4", features = ["util"] }
tower-http = { version = "0.4", features = ["fs", "trace"] }
'@
$serverCargoContent | Out-File -FilePath "crates/server/Cargo.toml" -Encoding utf8

# ==============================================================================
# 2. CRIAR O FRONT-END (HTML + JS + TAILWIND)
# ==============================================================================
Write-Host "[UI] Criando assets/index.html..." -ForegroundColor Green
New-Item -Path "assets" -ItemType Directory -Force | Out-Null

$htmlContent = @'
<!DOCTYPE html>
<html lang="pt-BR" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Blue-Taurus | Command Center</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    colors: {
                        taurus: {
                            500: '#3b82f6', // Blue-500
                            900: '#1e3a8a', // Blue-900
                        }
                    }
                }
            }
        }
    </script>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap');
        body { font-family: 'JetBrains Mono', monospace; }
        .glass { background: rgba(30, 41, 59, 0.7); backdrop-filter: blur(10px); border: 1px solid rgba(255, 255, 255, 0.1); }
    </style>
</head>
<body class="bg-slate-900 text-slate-100 min-h-screen p-6">

    <!-- Header -->
    <header class="flex justify-between items-center mb-10">
        <div class="flex items-center gap-3">
            <div class="w-3 h-3 rounded-full bg-blue-500 animate-pulse"></div>
            <h1 class="text-3xl font-bold tracking-tighter text-blue-400">BLUE-TAURUS <span class="text-xs text-slate-500 align-top">v1.0</span></h1>
        </div>
        <div class="text-right">
            <p class="text-xs text-slate-400">STATUS DO SISTEMA</p>
            <p class="text-green-400 font-bold">OPERACIONAL</p>
        </div>
    </header>

    <!-- Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-10">
        <div class="glass rounded-xl p-6">
            <h3 class="text-slate-400 text-sm mb-1">AGENTES ONLINE</h3>
            <p id="total-agents" class="text-4xl font-bold text-white">--</p>
        </div>
        <div class="glass rounded-xl p-6">
            <h3 class="text-slate-400 text-sm mb-1">ÚLTIMO EVENTO</h3>
            <p id="last-event" class="text-sm font-bold text-blue-300">Aguardando...</p>
        </div>
        <div class="glass rounded-xl p-6 flex flex-col justify-center">
            <button onclick="alert('Feature na v2.0!')" class="bg-blue-600 hover:bg-blue-500 text-white font-bold py-2 px-4 rounded transition-all">
                + Novo Script
            </button>
        </div>
    </div>

    <!-- Agents Table -->
    <div class="glass rounded-xl overflow-hidden">
        <div class="p-4 border-b border-slate-700 flex justify-between items-center">
            <h2 class="text-xl font-bold">Inventário de Ativos</h2>
            <span class="text-xs bg-slate-800 px-2 py-1 rounded text-slate-400" id="last-update">Atualizado: --</span>
        </div>
        <div class="overflow-x-auto">
            <table class="w-full text-left text-sm">
                <thead class="bg-slate-800 text-slate-400 uppercase">
                    <tr>
                        <th class="p-4">Hostname</th>
                        <th class="p-4">IP</th>
                        <th class="p-4">OS / Kernel</th>
                        <th class="p-4">Arquitetura</th>
                        <th class="p-4">Status</th>
                        <th class="p-4 text-right">Ações</th>
                    </tr>
                </thead>
                <tbody id="agents-table-body" class="divide-y divide-slate-700">
                    <!-- Rows inseridas via JS -->
                    <tr><td colspan="6" class="p-4 text-center text-slate-500">Carregando dados...</td></tr>
                </tbody>
            </table>
        </div>
    </div>

    <script>
        const API_URL = '/api/agents';

        async function fetchAgents() {
            try {
                const response = await fetch(API_URL);
                const agents = await response.json();
                renderTable(agents);
                updateStats(agents);
            } catch (error) {
                console.error('Falha ao buscar agentes:', error);
            }
        }

        function updateStats(agents) {
            document.getElementById('total-agents').innerText = agents.length;
            const now = new Date();
            document.getElementById('last-update').innerText = `Atualizado: ${now.toLocaleTimeString()}`;
            if(agents.length > 0) {
                 document.getElementById('last-event').innerText = `Handshake: ${agents[0].hostname}`;
            }
        }

        function renderTable(agents) {
            const tbody = document.getElementById('agents-table-body');
            tbody.innerHTML = '';

            agents.forEach(agent => {
                const row = document.createElement('tr');
                row.className = "hover:bg-slate-800 transition-colors";
                
                // Status Badge
                const statusColor = agent.status === 'ONLINE' ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400';

                row.innerHTML = `
                    <td class="p-4 font-bold text-white">${agent.hostname}</td>
                    <td class="p-4 text-slate-300">${agent.ip_address || 'N/A'}</td>
                    <td class="p-4 text-slate-400">${agent.os_name} <span class="text-xs text-slate-600">${agent.kernel_version || ''}</span></td>
                    <td class="p-4 text-slate-400">${agent.arch || '-'}</td>
                    <td class="p-4"><span class="px-2 py-1 rounded text-xs font-bold ${statusColor}">${agent.status}</span></td>
                    <td class="p-4 text-right">
                        <button class="text-blue-400 hover:text-white transition-colors" title="Ver Detalhes">
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5 ml-auto">
                              <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                              <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                            </svg>
                        </button>
                    </td>
                `;
                tbody.appendChild(row);
            });
        }

        // Auto-Refresh a cada 2s
        setInterval(fetchAgents, 2000);
        fetchAgents();
    </script>
</body>
</html>
'@
$htmlContent | Out-File -FilePath "assets/index.html" -Encoding utf8


# ==============================================================================
# 3. SERVER: Implementar API e Servir Estaticos
# ==============================================================================
Write-Host "[CODE] Criando API REST e Static File Server em crates/server/src/main.rs..." -ForegroundColor Green
$serverMainCode = @'
mod socket;

use axum::{
    routing::get,
    Router,
    extract::State,
    response::Json,
};
use tower_http::services::ServeDir;
use sqlx::postgres::{PgPool, PgPoolOptions};
use elasticsearch::Elasticsearch;
use elasticsearch::http::transport::Transport;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use dotenvy::dotenv;
use serde::{Serialize, Deserialize};

// Estado compartilhado
pub struct AppState {
    pub pg_pool: PgPool,
    pub elastic_client: Elasticsearch,
}

// Modelo para a API JSON
#[derive(Serialize, sqlx::FromRow)]
pub struct AgentRow {
    id: uuid::Uuid,
    hostname: String,
    os_name: String,
    kernel_version: Option<String>,
    arch: Option<String>,
    ip_address: Option<String>,
    status: Option<String>,
    // last_seen_at omitido por simplicidade do MVP JSON
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenv().ok();
    tracing_subscriber::fmt::init();
    tracing::info!("🚀 Blue-Taurus Server v1.0 Iniciando...");

    // 1. Postgres
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL faltando");
    let pg_pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&db_url).await.expect("Falha Postgres");

    // 2. Elasticsearch
    let es_url = std::env::var("ELASTIC_URL").expect("ELASTIC_URL faltando");
    let transport = Transport::single_node(&es_url)?;
    let elastic_client = Elasticsearch::new(transport);

    // 3. Estado
    let state = Arc::new(AppState { pg_pool, elastic_client });

    // 4. Rotas (API + Static + WebSocket)
    let app = Router::new()
        // API Endpoint
        .route("/api/agents", get(list_agents))
        // WebSocket
        .route("/ws", get(socket::ws_handler))
        // Front-end (Serve a pasta assets como root)
        .nest_service("/", ServeDir::new("assets"))
        .with_state(state);

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    tracing::info!("🌍 Interface Web disponivel em: http://{}", addr);
    
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();

    Ok(())
}

// Handler da API: Lista agentes do Postgres
async fn list_agents(State(state): State<Arc<AppState>>) -> Json<Vec<AgentRow>> {
    let agents = sqlx::query_as::<_, AgentRow>(
        "SELECT id, hostname, os_name, kernel_version, arch, ip_address, status FROM agents ORDER BY last_seen_at DESC"
    )
    .fetch_all(&state.pg_pool)
    .await
    .unwrap_or_else(|e| {
        tracing::error!("Erro SQL: {}", e);
        vec![]
    });

    Json(agents)
}
'@
$serverMainCode | Out-File -FilePath "crates/server/src/main.rs" -Encoding utf8

Write-Host "[SUCCESS] Fase 7 Concluida! Dashboard pronto." -ForegroundColor Cyan
Write-Host "[INSTRUCAO]: Rode 'cargo run -p server' e acesse http://127.0.0.1:3000"