# ==============================================================================
# BLUE-TAURUS: FASE 10 - FULL ASSET DETAILS & DRILL-DOWN UI
# Descrição: Coleta software via Registro, grava no Postgres e cria Modal na UI.
# Fix 1.1: Corrige import do StatusCode (Erro E0432) e limpa warnings.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 10] Implementando Coleta Profunda e Visualizacao de Detalhes..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# ==============================================================================
# 1. SHARED: Adicionar Software ao HostInfo
# ==============================================================================
Write-Host "[CODE] Atualizando crates/shared/src/models/mod.rs..." -ForegroundColor Green
$modelsContent = @'
use serde::{Deserialize, Serialize};

/// Informacoes completas do Host (Agente)
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct HostInfo {
    pub hostname: String,
    pub os_name: String,
    pub os_version: String,
    pub kernel_version: String,
    pub arch: String,
    pub logged_user: String,
    pub hardware: HardwareInfo,
    pub peripherals: Vec<String>,
    pub software: Vec<SoftwareInfo>, // ADICIONADO: Lista completa no Handshake
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct HardwareInfo {
    pub cpu_model: String,
    pub cpu_cores: usize,
    pub ram_total_mb: u64,
    pub ram_used_mb: u64,
    pub disk_total_gb: u64,
    pub disk_free_gb: u64,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SoftwareInfo {
    pub name: String,
    pub version: String,
    pub vendor: Option<String>,
    pub install_date: Option<String>,
}
'@
$modelsContent | Out-File -FilePath "crates/shared/src/models/mod.rs" -Encoding utf8


# ==============================================================================
# 2. AGENT: Coleta de Software via PowerShell (Registry)
# ==============================================================================
Write-Host "[CODE] Atualizando crates/agent/src/collector/mod.rs..." -ForegroundColor Green
$collectorCode = @'
use sysinfo::{CpuExt, DiskExt, System, SystemExt, UserExt};
use shared::models::{HostInfo, HardwareInfo, SoftwareInfo};
use std::process::Command;

pub struct SystemCollector {
    sys: System,
}

impl SystemCollector {
    pub fn new() -> Self {
        let mut sys = System::new_all();
        sys.refresh_all();
        Self { sys }
    }

    fn get_peripherals(&self) -> Vec<String> {
        let mut devices = Vec::new();
        if cfg!(target_os = "windows") {
            // Usa PowerShell para listar USBs
            let output = Command::new("powershell")
                .args(&["-Command", "Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like '*USB*' } | Select-Object -ExpandProperty FriendlyName"])
                .output();
            if let Ok(o) = output {
                for line in String::from_utf8_lossy(&o.stdout).lines() {
                    let t = line.trim(); 
                    if !t.is_empty() { devices.push(t.to_string()); }
                }
            }
        } else {
            devices.push("Generic Linux Device".to_string());
        }
        devices
    }

    fn get_software(&self) -> Vec<SoftwareInfo> {
        let mut software_list = Vec::new();

        if cfg!(target_os = "windows") {
            // Script PowerShell robusto para ler Uninstall Keys do Registro (32 e 64 bits)
            let ps_script = r#"
            $keys = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            Get-ItemProperty $keys -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName -ne $null } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | 
            ConvertTo-Json -Compress
            "#;

            let output = Command::new("powershell")
                .args(&["-Command", ps_script])
                .output();

            if let Ok(o) = output {
                let json_str = String::from_utf8_lossy(&o.stdout);
                
                // Estrutura temporaria para desserializar o JSON do PowerShell
                #[derive(serde::Deserialize)]
                struct PsSoftware {
                    DisplayName: Option<String>,
                    DisplayVersion: Option<String>,
                    Publisher: Option<String>,
                    InstallDate: Option<String>
                }

                if let Ok(items) = serde_json::from_str::<Vec<PsSoftware>>(&json_str) {
                    for item in items {
                        software_list.push(SoftwareInfo {
                            name: item.DisplayName.unwrap_or_default(),
                            version: item.DisplayVersion.unwrap_or_else(|| "N/A".to_string()),
                            vendor: item.Publisher,
                            install_date: item.InstallDate,
                        });
                    }
                }
            }
        } else {
            // Mock Linux
            software_list.push(SoftwareInfo { name: "Vim".into(), version: "8.2".into(), vendor: None, install_date: None });
        }
        
        software_list
    }

    pub fn collect(&mut self) -> HostInfo {
        self.sys.refresh_cpu();
        self.sys.refresh_memory();
        self.sys.refresh_disks();
        self.sys.refresh_users_list();

        let hw_info = HardwareInfo {
            cpu_model: self.sys.cpus().first().map(|c| c.brand().to_string()).unwrap_or_default(),
            cpu_cores: self.sys.cpus().len(),
            ram_total_mb: self.sys.total_memory() / 1024 / 1024,
            ram_used_mb: self.sys.used_memory() / 1024 / 1024,
            disk_total_gb: self.sys.disks().iter().map(|d| d.total_space()).sum::<u64>() / 1024 / 1024 / 1024,
            disk_free_gb: self.sys.disks().iter().map(|d| d.available_space()).sum::<u64>() / 1024 / 1024 / 1024,
        };

        let logged_user = self.sys.users().first().map(|u| u.name().to_string()).unwrap_or_else(|| "unknown".to_string());

        HostInfo {
            hostname: self.sys.host_name().unwrap_or_default(),
            os_name: self.sys.name().unwrap_or_default(),
            os_version: self.sys.os_version().unwrap_or_default(),
            kernel_version: self.sys.kernel_version().unwrap_or_default(),
            arch: std::env::consts::ARCH.to_string(),
            logged_user,
            hardware: hw_info,
            peripherals: self.get_peripherals(),
            software: self.get_software(),
        }
    }
}
'@
$collectorCode | Out-File -FilePath "crates/agent/src/collector/mod.rs" -Encoding utf8


# ==============================================================================
# 3. SERVER: Persistir Dados Detalhados (Hardware & Software)
# ==============================================================================
Write-Host "[CODE] Atualizando crates/server/src/socket/mod.rs (Gravacao no Banco)..." -ForegroundColor Green
$serverSocketCode = @'
use axum::{
    extract::{ws::{Message as WsMessage, WebSocket, WebSocketUpgrade}, State},
    response::IntoResponse,
};
use futures::{stream::StreamExt, SinkExt};
use std::sync::Arc;
use shared::protocol::Message;
use crate::AppState;

pub async fn ws_handler(ws: WebSocketUpgrade, State(state): State<Arc<AppState>>) -> impl IntoResponse {
    ws.on_upgrade(|socket| handle_socket(socket, state))
}

async fn handle_socket(socket: WebSocket, state: Arc<AppState>) {
    // Dividir socket em sender/receiver para full duplex
    let (mut _sender, mut receiver) = socket.split();

    while let Some(Ok(msg)) = receiver.next().await {
        if let WsMessage::Text(text) = msg {
            if let Ok(protocol_msg) = serde_json::from_str::<Message>(&text) {
                match protocol_msg {
                    Message::Handshake { agent_id, host_info, .. } => {
                        tracing::info!("🤝 Handshake: {} ({} Softwares)", host_info.hostname, host_info.software.len());
                        
                        // 1. Tabela AGENTS
                        let _ = sqlx::query!(
                            r#"INSERT INTO agents (id, hostname, os_name, os_version, kernel_version, arch, ip_address, status)
                               VALUES ($1, $2, $3, $4, $5, $6, $7, 'ONLINE')
                               ON CONFLICT (id) DO UPDATE SET hostname = EXCLUDED.hostname, last_seen_at = NOW(), status = 'ONLINE'"#,
                            agent_id, host_info.hostname, host_info.os_name, host_info.os_version, host_info.kernel_version, host_info.arch, "127.0.0.1"
                        ).execute(&state.pg_pool).await;

                        // 2. Tabela HARDWARE_SPECS
                        let _ = sqlx::query!(
                            r#"INSERT INTO hardware_specs (agent_id, cpu_model, cpu_cores, ram_total_mb, disk_total_gb)
                               VALUES ($1, $2, $3, $4, $5)
                               ON CONFLICT (agent_id) DO UPDATE SET 
                               cpu_model = EXCLUDED.cpu_model, ram_total_mb = EXCLUDED.ram_total_mb, updated_at = NOW()"#,
                            agent_id, host_info.hardware.cpu_model, host_info.hardware.cpu_cores as i32, host_info.hardware.ram_total_mb as i64, host_info.hardware.disk_total_gb as i64
                        ).execute(&state.pg_pool).await;

                        // 3. Tabela SOFTWARE_INVENTORY
                        let _ = sqlx::query!("DELETE FROM software_inventory WHERE agent_id = $1", agent_id).execute(&state.pg_pool).await;
                        
                        for sw in &host_info.software {
                            let _ = sqlx::query!(
                                "INSERT INTO software_inventory (agent_id, name, version, vendor, install_date) VALUES ($1, $2, $3, $4, $5)",
                                agent_id, sw.name, sw.version, sw.vendor, sw.install_date
                            ).execute(&state.pg_pool).await;
                        }

                        // 4. Elastic Indexing
                        let mut doc = serde_json::to_value(&host_info).unwrap();
                        if let Some(obj) = doc.as_object_mut() {
                            obj.insert("@timestamp".to_string(), serde_json::json!(chrono::Utc::now()));
                            obj.insert("agent_id".to_string(), serde_json::json!(agent_id));
                        }
                        let _ = state.elastic_client.index(elasticsearch::IndexParts::Index("bt-logs-v1")).body(doc).send().await;
                    },
                    Message::CommandResult { cmd_id, status, .. } => {
                        // Loga apenas o status para evitar warning de variaveis nao usadas
                        tracing::info!("📝 CMD {}: {}", cmd_id, status);
                    }
                    _ => {}
                }
            }
        }
    }
}
'@
$serverSocketCode | Out-File -FilePath "crates/server/src/socket/mod.rs" -Encoding utf8


# ==============================================================================
# 4. SERVER: Nova API de Detalhes (CORRIGIDO)
# ==============================================================================
Write-Host "[CODE] Atualizando crates/server/src/main.rs (API Details)..." -ForegroundColor Green
$serverMainCode = @'
mod socket;

use axum::{
    routing::{get, delete},
    Router,
    extract::{State, Path},
    response::Json,
    http, // Importa o modulo http inteiro para usar http::StatusCode
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

pub struct AppState { pub pg_pool: PgPool, pub elastic_client: Elasticsearch }

#[derive(Serialize, sqlx::FromRow)]
pub struct AgentRow {
    id: Uuid, hostname: String, os_name: String, kernel_version: Option<String>,
    arch: Option<String>, ip_address: Option<String>, status: Option<String>,
    last_seen_at: Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Serialize)]
pub struct AgentDetails {
    agent: AgentRow,
    hardware: Option<HardwareRow>,
    software: Vec<SoftwareRow>,
}

#[derive(Serialize, sqlx::FromRow)]
pub struct HardwareRow { cpu_model: Option<String>, ram_total_mb: Option<i64>, disk_total_gb: Option<i64> }

#[derive(Serialize, sqlx::FromRow)]
pub struct SoftwareRow { name: String, version: Option<String>, vendor: Option<String>, install_date: Option<String> }

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenv().ok();
    tracing_subscriber::fmt::init();
    tracing::info!("🚀 Blue-Taurus Server v1.2 (Full Details) Iniciando...");

    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL faltando");
    let pg_pool = PgPoolOptions::new().max_connections(5).connect(&db_url).await.expect("Falha Postgres");

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

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    axum::Server::bind(&addr).serve(app.into_make_service()).await.unwrap();
    Ok(())
}

async fn list_agents(State(state): State<Arc<AppState>>) -> Json<Vec<AgentRow>> {
    let agents = sqlx::query_as::<_, AgentRow>("SELECT id, hostname, os_name, kernel_version, arch, ip_address, status, last_seen_at FROM agents ORDER BY last_seen_at DESC")
        .fetch_all(&state.pg_pool).await.unwrap_or_default();
    Json(agents)
}

async fn delete_agent(Path(id): Path<Uuid>, State(state): State<Arc<AppState>>) -> http::StatusCode {
    let _ = sqlx::query!("DELETE FROM software_inventory WHERE agent_id = $1", id).execute(&state.pg_pool).await;
    let _ = sqlx::query!("DELETE FROM hardware_specs WHERE agent_id = $1", id).execute(&state.pg_pool).await;
    let _ = sqlx::query!("DELETE FROM agents WHERE id = $1", id).execute(&state.pg_pool).await;
    http::StatusCode::NO_CONTENT
}

async fn get_agent_details(Path(id): Path<Uuid>, State(state): State<Arc<AppState>>) -> Json<Option<AgentDetails>> {
    let agent = sqlx::query_as::<_, AgentRow>("SELECT id, hostname, os_name, kernel_version, arch, ip_address, status, last_seen_at FROM agents WHERE id = $1")
        .bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);

    if let Some(ag) = agent {
        let hw = sqlx::query_as::<_, HardwareRow>("SELECT cpu_model, ram_total_mb, disk_total_gb FROM hardware_specs WHERE agent_id = $1")
            .bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);
        
        let sw = sqlx::query_as::<_, SoftwareRow>("SELECT name, version, vendor, install_date FROM software_inventory WHERE agent_id = $1 ORDER BY name ASC")
            .bind(id).fetch_all(&state.pg_pool).await.unwrap_or_default();

        return Json(Some(AgentDetails { agent: ag, hardware: hw, software: sw }));
    }
    Json(None)
}
'@
$serverMainCode | Out-File -FilePath "crates/server/src/main.rs" -Encoding utf8


# ==============================================================================
# 5. UI: Adicionar Modal de Detalhes
# ==============================================================================
Write-Host "[UI] Adicionando Modal de Detalhes ao index.html..." -ForegroundColor Green
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
        /* Modal Animation */
        .modal { transition: opacity 0.25s ease; }
        body.modal-active { overflow-x: hidden; overflow-y: visible !important; }
    </style>
</head>
<body class="flex flex-col h-screen overflow-hidden">

    <!-- Header -->
    <header class="h-16 border-b border-slate-700 bg-slate-900/80 backdrop-blur-md flex items-center justify-between px-6 z-20">
        <div class="flex items-center gap-3"><i class="ph-fill ph-shield-check text-blue-500 text-3xl"></i><h1 class="font-bold text-xl text-white">BLUE-TAURUS</h1></div>
    </header>

    <div class="flex flex-1 overflow-hidden">
        <!-- Main Content -->
        <main class="flex-1 overflow-y-auto p-6 bg-[#0b1120]">
            <!-- Table -->
            <div class="card overflow-hidden">
                <div class="p-4 border-b border-slate-700 bg-slate-800/50"><h2 class="text-sm font-bold text-white">Inventário de Ativos</h2></div>
                <div class="overflow-x-auto">
                    <table class="w-full text-left text-xs">
                        <thead class="bg-slate-800/80 text-slate-400 font-semibold uppercase">
                            <tr><th class="p-3">Hostname</th><th class="p-3">Status</th><th class="p-3">OS</th><th class="p-3">IP</th><th class="p-3 text-right">Detalhes</th></tr>
                        </thead>
                        <tbody id="table-body" class="divide-y divide-slate-700/50 text-slate-300"></tbody>
                    </table>
                </div>
            </div>
        </main>
    </div>

    <!-- MODAL DETALHES -->
    <div id="details-modal" class="modal opacity-0 pointer-events-none fixed w-full h-full top-0 left-0 flex items-center justify-center z-50">
        <div class="modal-overlay absolute w-full h-full bg-black opacity-50"></div>
        <div class="modal-container bg-slate-800 w-11/12 md:max-w-4xl mx-auto rounded-xl shadow-2xl z-50 overflow-y-auto max-h-[90vh]">
            
            <!-- Modal Header -->
            <div class="modal-close absolute top-0 right-0 cursor-pointer flex flex-col items-center mt-4 mr-4 text-white text-sm z-50">
                <svg class="fill-current text-white" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18" onclick="closeModal()"><path d="M14.53 4.53l-1.06-1.06L9 7.94 4.53 3.47 3.47 4.53 7.94 9l-4.47 4.47 1.06 1.06L9 10.06l4.47 4.47 1.06-1.06L10.06 9z"></path></svg>
            </div>
            <div class="p-6 border-b border-slate-700 flex justify-between items-center">
                <h3 class="text-2xl font-bold text-white" id="modal-hostname">Carregando...</h3>
                <span class="text-xs text-slate-400 font-mono" id="modal-id">UUID</span>
            </div>

            <!-- Modal Content -->
            <div class="p-6">
                <!-- Hardware Summary -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                    <div class="bg-slate-700/50 p-4 rounded-lg border border-slate-600">
                        <p class="text-xs text-slate-400 uppercase">CPU</p>
                        <p class="font-bold text-white text-sm" id="modal-cpu">--</p>
                    </div>
                    <div class="bg-slate-700/50 p-4 rounded-lg border border-slate-600">
                        <p class="text-xs text-slate-400 uppercase">Memória</p>
                        <p class="font-bold text-white text-sm" id="modal-ram">--</p>
                    </div>
                    <div class="bg-slate-700/50 p-4 rounded-lg border border-slate-600">
                        <p class="text-xs text-slate-400 uppercase">Disco</p>
                        <p class="font-bold text-white text-sm" id="modal-disk">--</p>
                    </div>
                </div>

                <!-- Software List -->
                <h4 class="text-sm font-bold text-blue-400 mb-3 uppercase tracking-wider">Softwares Instalados (<span id="sw-count">0</span>)</h4>
                <div class="bg-slate-900 rounded-lg border border-slate-700 overflow-hidden max-h-64 overflow-y-auto">
                    <table class="w-full text-left text-xs">
                        <thead class="bg-slate-800 text-slate-400 sticky top-0"><tr><th class="p-2">Nome</th><th class="p-2">Versão</th><th class="p-2">Vendor</th></tr></thead>
                        <tbody id="modal-sw-body" class="divide-y divide-slate-800 text-slate-300"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <script>
        const API_URL = '/api/agents';

        // --- Fetch & Render Main Table ---
        async function fetchAgents() {
            try {
                const res = await fetch(API_URL);
                const agents = await res.json();
                renderTable(agents);
            } catch(e) { console.error(e); }
        }

        function renderTable(agents) {
            const tbody = document.getElementById('table-body');
            tbody.innerHTML = '';
            
            // Deduplicate (Simple version)
            const unique = [];
            const seen = new Set();
            agents.forEach(a => { if(!seen.has(a.hostname)){ seen.add(a.hostname); unique.push(a); } });

            unique.forEach(agent => {
                const statusBadge = agent.status === 'ONLINE' 
                    ? '<span class="text-emerald-400 font-bold text-[10px]">● ONLINE</span>' 
                    : '<span class="text-slate-500 font-bold text-[10px]">● OFFLINE</span>';
                
                const row = document.createElement('tr');
                row.className = "hover:bg-slate-800/50 transition-colors border-b border-slate-800";
                row.innerHTML = `
                    <td class="p-3 font-bold text-white">${agent.hostname}</td>
                    <td class="p-3">${statusBadge}</td>
                    <td class="p-3 text-slate-400">${agent.os_name}</td>
                    <td class="p-3 font-mono text-slate-500">${agent.ip_address || '--'}</td>
                    <td class="p-3 text-right">
                        <button onclick="openDetails('${agent.id}')" class="bg-blue-600/20 text-blue-400 hover:bg-blue-600 hover:text-white px-3 py-1 rounded text-xs font-bold transition-all">Ver Detalhes</button>
                    </td>
                `;
                tbody.appendChild(row);
            });
        }

        // --- Details Logic ---
        async function openDetails(id) {
            // Show Modal (Loading state)
            toggleModal(true);
            document.getElementById('modal-hostname').innerText = "Carregando...";
            
            try {
                const res = await fetch(API_URL + '/' + id + '/details');
                const data = await res.json();
                
                if(data) {
                    document.getElementById('modal-hostname').innerText = data.agent.hostname;
                    document.getElementById('modal-id').innerText = data.agent.id;
                    
                    // Hardware
                    const hw = data.hardware || {};
                    document.getElementById('modal-cpu').innerText = hw.cpu_model || 'N/A';
                    document.getElementById('modal-ram').innerText = (hw.ram_total_mb ? (hw.ram_total_mb/1024).toFixed(1) + ' GB' : 'N/A');
                    document.getElementById('modal-disk').innerText = (hw.disk_total_gb ? hw.disk_total_gb + ' GB' : 'N/A');

                    // Software
                    const swBody = document.getElementById('modal-sw-body');
                    swBody.innerHTML = '';
                    document.getElementById('sw-count').innerText = data.software.length;
                    
                    data.software.forEach(s => {
                        const r = document.createElement('tr');
                        r.innerHTML = `<td class="p-2 font-medium text-white">${s.name}</td><td class="p-2 text-slate-400">${s.version || '-'}</td><td class="p-2 text-slate-500">${s.vendor || '-'}</td>`;
                        swBody.appendChild(r);
                    });
                }
            } catch(e) {
                console.error(e);
                document.getElementById('modal-hostname').innerText = "Erro ao carregar";
            }
        }

        function toggleModal(show) {
            const modal = document.getElementById('details-modal');
            if(show) {
                modal.classList.remove('opacity-0', 'pointer-events-none');
                document.body.classList.add('modal-active');
            } else {
                modal.classList.add('opacity-0', 'pointer-events-none');
                document.body.classList.remove('modal-active');
            }
        }
        
        function closeModal() { toggleModal(false); }
        
        // Close on overlay click
        document.querySelector('.modal-overlay').addEventListener('click', closeModal);

        setInterval(fetchAgents, 5000);
        fetchAgents();
    </script>
</body>
</html>
'@
$htmlContent | Out-File -FilePath "assets/index.html" -Encoding utf8

Write-Host "[SUCCESS] Upgrade: Coleta de Software e Modal de Detalhes!" -ForegroundColor Cyan
Write-Host "1. Reinicie o Server e o Agent."
Write-Host "2. O Agent vai demorar uns segundos para coletar todo o software."
Write-Host "3. Acesse o Dashboard e clique em 'Ver Detalhes'."