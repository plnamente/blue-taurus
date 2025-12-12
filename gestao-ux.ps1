# ==============================================================================
# BLUE-TAURUS: FASE 8 - ASSET MANAGEMENT & UX PRO
# Descrição: Adiciona API de exclusão e interface avançada com detecção de duplicatas.
# Fix 1.1: Corrige import do StatusCode (axum::http::StatusCode)
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 8] Implementando UX de Gestao e Limpeza..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# ==============================================================================
# 1. SERVER: Adicionar Rota de Delete
# ==============================================================================
Write-Host "[CODE] Atualizando crates/server/src/main.rs (API Delete)..." -ForegroundColor Green

$serverMainCode = @'
mod socket;

use axum::{
    routing::{get, delete},
    Router,
    extract::{State, Path},
    response::Json,
    http::StatusCode,
};
use tower_http::services::ServeDir;
use sqlx::postgres::{PgPool, PgPoolOptions};
use elasticsearch::Elasticsearch;
use elasticsearch::http::transport::Transport;
use std::net::SocketAddr;
use std::sync::Arc;
use dotenvy::dotenv;
use serde::Serialize;
use uuid::Uuid;

// Estado compartilhado
pub struct AppState {
    pub pg_pool: PgPool,
    pub elastic_client: Elasticsearch,
}

// Modelo para a API JSON
#[derive(Serialize, sqlx::FromRow)]
pub struct AgentRow {
    id: Uuid,
    hostname: String,
    os_name: String,
    kernel_version: Option<String>,
    arch: Option<String>,
    ip_address: Option<String>,
    status: Option<String>,
    logged_user: Option<String>, 
    last_seen_at: Option<chrono::DateTime<chrono::Utc>>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenv().ok();
    tracing_subscriber::fmt::init();
    tracing::info!("🚀 Blue-Taurus Server v1.1 (Management) Iniciando...");

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

    // 4. Rotas
    let app = Router::new()
        .route("/api/agents", get(list_agents))
        .route("/api/agents/:id", delete(delete_agent)) // NOVO: Rota de Exclusao
        .route("/ws", get(socket::ws_handler))
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

// Handler: Listar
async fn list_agents(State(state): State<Arc<AppState>>) -> Json<Vec<AgentRow>> {
    // Adicionei logged_user e last_seen_at na query
    let agents = sqlx::query_as::<_, AgentRow>(
        "SELECT id, hostname, os_name, kernel_version, arch, ip_address, status, NULL as logged_user, last_seen_at FROM agents ORDER BY last_seen_at DESC"
    )
    .fetch_all(&state.pg_pool)
    .await
    .unwrap_or_else(|e| {
        tracing::error!("Erro SQL: {}", e);
        vec![]
    });

    Json(agents)
}

// Handler: Deletar
async fn delete_agent(
    Path(id): Path<Uuid>,
    State(state): State<Arc<AppState>>,
) -> StatusCode {
    tracing::info!("🗑️ Solicitacao de exclusao para agente: {}", id);

    let result = sqlx::query!("DELETE FROM agents WHERE id = $1", id)
        .execute(&state.pg_pool)
        .await;

    match result {
        Ok(_) => StatusCode::NO_CONTENT, // 204 No Content (Sucesso)
        Err(e) => {
            tracing::error!("Erro ao deletar agente: {}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        }
    }
}
'@
$serverMainCode | Out-File -FilePath "crates/server/src/main.rs" -Encoding utf8


# ==============================================================================
# 2. FRONTEND: Interface UX Pro (Alertas, Checkboxes, Floating Actions)
# ==============================================================================
Write-Host "[UI] Atualizando assets/index.html..." -ForegroundColor Green

$htmlContent = @'
<!DOCTYPE html>
<html lang="pt-BR" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Blue-Taurus | Command Center</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <!-- SweetAlert2 para Modais Bonitos -->
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    colors: {
                        taurus: { 500: '#3b82f6', 900: '#1e3a8a' }
                    }
                }
            }
        }
    </script>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap');
        body { font-family: 'JetBrains Mono', monospace; }
        .glass { background: rgba(30, 41, 59, 0.7); backdrop-filter: blur(10px); border: 1px solid rgba(255, 255, 255, 0.1); }
        .checkbox-custom { accent-color: #3b82f6; cursor: pointer; transform: scale(1.2); }
        /* Animacao para o alerta */
        @keyframes slideDown { from { transform: translateY(-20px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
        .animate-slide-down { animation: slideDown 0.3s ease-out forwards; }
    </style>
</head>
<body class="bg-slate-900 text-slate-100 min-h-screen p-6 relative">

    <!-- Duplicate Warning Banner (Hidden by default) -->
    <div id="duplicate-warning" class="hidden fixed top-4 left-1/2 transform -translate-x-1/2 z-50 bg-orange-500/90 text-white px-6 py-3 rounded-full shadow-lg border border-orange-400 backdrop-blur-md flex items-center gap-3 animate-slide-down">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 animate-pulse" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
        <span class="font-bold">ATENÇÃO: Ativos duplicados detectados!</span>
        <button onclick="document.getElementById('duplicate-warning').classList.add('hidden')" class="ml-2 hover:text-orange-200">✕</button>
    </div>

    <!-- Header -->
    <header class="flex justify-between items-center mb-8">
        <div class="flex items-center gap-3">
            <div class="w-3 h-3 rounded-full bg-blue-500 animate-pulse"></div>
            <h1 class="text-3xl font-bold tracking-tighter text-blue-400">BLUE-TAURUS <span class="text-xs text-slate-500 align-top">v1.1</span></h1>
        </div>
        <div class="flex gap-4 items-center">
            <div class="text-right hidden md:block">
                <p class="text-xs text-slate-400">AMBIENTE</p>
                <p class="text-white font-bold">PRODUÇÃO</p>
            </div>
            <!-- Delete Action Button (Hidden until selection) -->
            <button id="btn-delete-selected" onclick="confirmDelete()" class="hidden bg-red-600 hover:bg-red-500 text-white px-4 py-2 rounded shadow-lg flex items-center gap-2 transition-all">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
                Excluir Selecionados (<span id="selected-count">0</span>)
            </button>
        </div>
    </header>

    <!-- Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div class="glass rounded-xl p-6 border-l-4 border-blue-500">
            <h3 class="text-slate-400 text-sm mb-1 uppercase tracking-wider">Total de Ativos</h3>
            <p id="total-agents" class="text-4xl font-bold text-white">--</p>
        </div>
        <div class="glass rounded-xl p-6 border-l-4 border-green-500">
            <h3 class="text-slate-400 text-sm mb-1 uppercase tracking-wider">Status da Rede</h3>
            <p class="text-sm font-bold text-green-400">SAUDÁVEL</p>
        </div>
        <div class="glass rounded-xl p-6 border-l-4 border-purple-500 flex flex-col justify-center">
             <button onclick="Swal.fire('Feature em breve!', 'O editor de scripts está em desenvolvimento.', 'info')" class="w-full bg-slate-700 hover:bg-slate-600 text-white font-bold py-2 px-4 rounded transition-all border border-slate-600">
                + Novo Script Python
            </button>
        </div>
    </div>

    <!-- Agents Table -->
    <div class="glass rounded-xl overflow-hidden shadow-2xl">
        <div class="p-4 border-b border-slate-700 flex justify-between items-center bg-slate-800/50">
            <div class="flex items-center gap-2">
                <h2 class="text-xl font-bold">Inventário de Ativos</h2>
                <span id="loader" class="hidden"><svg class="animate-spin h-4 w-4 text-blue-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg></span>
            </div>
            <span class="text-xs bg-slate-900 px-3 py-1 rounded-full text-slate-400 border border-slate-700" id="last-update">Sincronizando...</span>
        </div>
        <div class="overflow-x-auto">
            <table class="w-full text-left text-sm">
                <thead class="bg-slate-800 text-slate-400 uppercase font-semibold tracking-wider">
                    <tr>
                        <th class="p-4 w-10 text-center">
                            <input type="checkbox" id="select-all" onclick="toggleSelectAll()" class="checkbox-custom">
                        </th>
                        <th class="p-4">Hostname</th>
                        <th class="p-4">IP / ID</th>
                        <th class="p-4">OS / Kernel</th>
                        <th class="p-4">Visto por último</th>
                        <th class="p-4">Status</th>
                    </tr>
                </thead>
                <tbody id="agents-table-body" class="divide-y divide-slate-700">
                    <!-- Rows inseridas via JS -->
                </tbody>
            </table>
        </div>
    </div>

    <script>
        const API_URL = '/api/agents';
        let currentAgents = [];
        let selectedIds = new Set();

        // --- CORE FUNCTIONS ---

        async function fetchAgents() {
            document.getElementById('loader').classList.remove('hidden');
            try {
                const response = await fetch(API_URL);
                currentAgents = await response.json();
                renderTable(currentAgents);
                updateStats(currentAgents);
                checkDuplicates(currentAgents);
            } catch (error) {
                console.error('Falha ao buscar agentes:', error);
            } finally {
                document.getElementById('loader').classList.add('hidden');
            }
        }

        function renderTable(agents) {
            const tbody = document.getElementById('agents-table-body');
            tbody.innerHTML = '';

            // Detectar duplicatas para highlight
            const hostnameCounts = {};
            agents.forEach(a => { hostnameCounts[a.hostname] = (hostnameCounts[a.hostname] || 0) + 1; });

            agents.forEach(agent => {
                const isDuplicate = hostnameCounts[agent.hostname] > 1;
                const isSelected = selectedIds.has(agent.id);
                
                const row = document.createElement('tr');
                // Highlight duplicates with a subtle warning background
                row.className = `transition-colors ${isDuplicate ? 'bg-orange-900/10 hover:bg-orange-900/20' : 'hover:bg-slate-800'}`;
                if(isSelected) row.classList.add('bg-blue-900/20');

                // Warning Icon logic
                const warnIcon = isDuplicate 
                    ? '<span class="text-orange-500 ml-2" title="Duplicata Detectada">⚠️</span>' 
                    : '';

                // Format Last Seen
                const lastSeen = agent.last_seen_at ? new Date(agent.last_seen_at).toLocaleString() : 'N/A';
                const statusColor = agent.status === 'ONLINE' ? 'bg-green-500/20 text-green-400 border border-green-500/30' : 'bg-red-500/20 text-red-400 border border-red-500/30';

                row.innerHTML = `
                    <td class="p-4 text-center">
                        <input type="checkbox" class="checkbox-custom agent-checkbox" 
                               value="${agent.id}" 
                               ${isSelected ? 'checked' : ''}
                               onchange="toggleSelection('${agent.id}')">
                    </td>
                    <td class="p-4 font-bold text-white flex items-center">
                        ${agent.hostname} ${warnIcon}
                    </td>
                    <td class="p-4">
                        <div class="text-slate-300">${agent.ip_address || '127.0.0.1'}</div>
                        <div class="text-[10px] text-slate-500 font-mono">${agent.id.substring(0,8)}...</div>
                    </td>
                    <td class="p-4 text-slate-400">
                        <div>${agent.os_name}</div>
                        <div class="text-xs text-slate-600">${agent.kernel_version || ''}</div>
                    </td>
                    <td class="p-4 text-slate-400 text-xs">${lastSeen}</td>
                    <td class="p-4"><span class="px-2 py-1 rounded text-[10px] font-bold uppercase ${statusColor}">${agent.status || 'UNKNOWN'}</span></td>
                `;
                tbody.appendChild(row);
            });
            
            updateDeleteButton();
        }

        // --- UX LOGIC: DUPLICATES ---
        function checkDuplicates(agents) {
            const hostnames = agents.map(a => a.hostname);
            const hasDuplicates = hostnames.some((val, i) => hostnames.indexOf(val) !== i);
            const banner = document.getElementById('duplicate-warning');
            
            if (hasDuplicates) {
                banner.classList.remove('hidden');
            } else {
                banner.classList.add('hidden');
            }
        }

        // --- UX LOGIC: SELECTION ---
        function toggleSelection(id) {
            if (selectedIds.has(id)) {
                selectedIds.delete(id);
            } else {
                selectedIds.add(id);
            }
            renderTable(currentAgents); // Re-render to update styles
        }

        function toggleSelectAll() {
            const selectAll = document.getElementById('select-all').checked;
            if (selectAll) {
                currentAgents.forEach(a => selectedIds.add(a.id));
            } else {
                selectedIds.clear();
            }
            renderTable(currentAgents);
        }

        function updateDeleteButton() {
            const btn = document.getElementById('btn-delete-selected');
            const countSpan = document.getElementById('selected-count');
            
            if (selectedIds.size > 0) {
                btn.classList.remove('hidden');
                countSpan.innerText = selectedIds.size;
            } else {
                btn.classList.add('hidden');
            }
        }

        // --- API ACTIONS ---
        function confirmDelete() {
            Swal.fire({
                title: 'Tem certeza?',
                text: `Você está prestes a excluir ${selectedIds.size} ativo(s). Essa ação não pode ser desfeita.`,
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#d33',
                cancelButtonColor: '#3085d6',
                confirmButtonText: 'Sim, excluir!',
                cancelButtonText: 'Cancelar',
                background: '#1e293b',
                color: '#fff'
            }).then((result) => {
                if (result.isConfirmed) {
                    deleteSelectedAgents();
                }
            })
        }

        async function deleteSelectedAgents() {
            const idsToDelete = Array.from(selectedIds);
            let successCount = 0;

            // Delete one by one (Simpler API for MVP)
            for (const id of idsToDelete) {
                try {
                    const res = await fetch(`${API_URL}/${id}`, { method: 'DELETE' });
                    if (res.ok) successCount++;
                } catch (e) {
                    console.error(e);
                }
            }

            selectedIds.clear();
            await fetchAgents();

            Swal.fire({
                title: 'Limpeza Concluída!',
                text: `${successCount} ativo(s) foram removidos do sistema.`,
                icon: 'success',
                background: '#1e293b',
                color: '#fff',
                timer: 2000,
                showConfirmButton: false
            });
        }

        function updateStats(agents) {
            document.getElementById('total-agents').innerText = agents.length;
            const now = new Date();
            document.getElementById('last-update').innerText = `Sync: ${now.toLocaleTimeString()}`;
        }

        // Loop principal
        setInterval(fetchAgents, 3000); // Relaxei para 3s para dar tempo de interagir
        fetchAgents();

    </script>
</body>
</html>
'@
$htmlContent | Out-File -FilePath "assets/index.html" -Encoding utf8

Write-Host "[SUCCESS] UX Upgrade Concluido!" -ForegroundColor Cyan
Write-Host "Reinicie o servidor para ver a nova interface de gestao."