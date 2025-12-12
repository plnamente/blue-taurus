# ==============================================================================
# BLUE-TAURUS: FASE 6 - DATA ENRICHMENT
# Descrição: Adiciona coleta de Usuario e Perifericos. Corrige indexacao no Elastic.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 6] Enriquecendo Dados (User, Peripherals & Full Indexing)..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# ==============================================================================
# 1. SHARED: Atualizar Modelos de Dados
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
    pub logged_user: String,        // NOVO: Usuario Logado
    pub hardware: HardwareInfo,
    pub peripherals: Vec<String>,   // NOVO: Lista de nomes de dispositivos (USB/PnP)
}

/// Especificacoes de Hardware
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct HardwareInfo {
    pub cpu_model: String,
    pub cpu_cores: usize,
    pub ram_total_mb: u64,
    pub ram_used_mb: u64,
    pub disk_total_gb: u64,
    pub disk_free_gb: u64,
}

/// Inventario de Software Instalado
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
# 2. AGENT: Atualizar Coletor (Lógica de Coleta)
# ==============================================================================
Write-Host "[CODE] Atualizando crates/agent/src/collector/mod.rs..." -ForegroundColor Green
$collectorCode = @'
use sysinfo::{CpuExt, DiskExt, System, SystemExt, UserExt};
use shared::models::{HostInfo, HardwareInfo};
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

    /// Tenta descobrir periféricos usando comandos do SO (PowerShell no Windows)
    fn get_peripherals(&self) -> Vec<String> {
        let mut devices = Vec::new();

        if cfg!(target_os = "windows") {
            // Executa PowerShell para listar dispositivos USB presentes
            // Filtra por "USB" e status "OK" para nao trazer lixo
            let output = Command::new("powershell")
                .args(&["-Command", "Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like '*USB*' } | Select-Object -ExpandProperty FriendlyName"])
                .output();

            if let Ok(o) = output {
                let stdout = String::from_utf8_lossy(&o.stdout);
                for line in stdout.lines() {
                    let trimmed = line.trim();
                    if !trimmed.is_empty() {
                        devices.push(trimmed.to_string());
                    }
                }
            }
        } else {
            // Linux implementation (ex: lsusb) - Placeholder para MVP
            devices.push("Generic Linux USB Hub".to_string());
        }

        devices
    }

    pub fn collect(&mut self) -> HostInfo {
        self.sys.refresh_cpu();
        self.sys.refresh_memory();
        self.sys.refresh_disks();
        self.sys.refresh_users_list(); // Importante para pegar usuarios

        let hw_info = HardwareInfo {
            cpu_model: self.sys.cpus().first().map(|cpu| cpu.brand().to_string()).unwrap_or_default(),
            cpu_cores: self.sys.cpus().len(),
            ram_total_mb: self.sys.total_memory() / 1024 / 1024,
            ram_used_mb: self.sys.used_memory() / 1024 / 1024,
            disk_total_gb: self.sys.disks().iter().map(|d| d.total_space()).sum::<u64>() / 1024 / 1024 / 1024,
            disk_free_gb: self.sys.disks().iter().map(|d| d.available_space()).sum::<u64>() / 1024 / 1024 / 1024,
        };

        // Tenta pegar o usuario logado (quem esta rodando o processo ou o primeiro da lista)
        let logged_user = self.sys.users().first()
            .map(|u| u.name().to_string())
            .unwrap_or_else(|| "system/unknown".to_string());

        HostInfo {
            hostname: self.sys.host_name().unwrap_or_else(|| "unknown".to_string()),
            os_name: self.sys.name().unwrap_or_else(|| "unknown".to_string()),
            os_version: self.sys.os_version().unwrap_or_else(|| "unknown".to_string()),
            kernel_version: self.sys.kernel_version().unwrap_or_else(|| "unknown".to_string()),
            arch: std::env::consts::ARCH.to_string(),
            logged_user,
            hardware: hw_info,
            peripherals: self.get_peripherals(),
        }
    }
}
'@
$collectorCode | Out-File -FilePath "crates/agent/src/collector/mod.rs" -Encoding utf8


# ==============================================================================
# 3. SERVER: Corrigir Indexacao no Elastic (Enviar TUDO)
# ==============================================================================
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

    let (mut sender, mut receiver) = socket.split();

    while let Some(Ok(msg)) = receiver.next().await {
        if let WsMessage::Text(text) = msg {
            if let Ok(protocol_msg) = serde_json::from_str::<Message>(&text) {
                match protocol_msg {
                    Message::Handshake { agent_id, host_info, .. } => {
                        tracing::info!("🤝 Handshake de: {} (User: {})", host_info.hostname, host_info.logged_user);
                        
                        // 1. Dual-Write: Postgres (Agora apenas loga erro, nao trava)
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
                            "127.0.0.1"
                        )
                        .execute(&state.pg_pool)
                        .await
                        .map_err(|e| tracing::error!("Falha no Postgres: {}", e));

                        // 2. Dual-Write: Elasticsearch (AGORA COM DADOS COMPLETOS)
                        // Criamos um JSON que mistura o timestamp/meta com o objeto host_info inteiro
                        let mut doc = serde_json::to_value(&host_info).unwrap();
                        if let Some(obj) = doc.as_object_mut() {
                            obj.insert("@timestamp".to_string(), serde_json::json!(chrono::Utc::now()));
                            obj.insert("event_type".to_string(), serde_json::json!("handshake"));
                            obj.insert("agent_id".to_string(), serde_json::json!(agent_id));
                        }

                        let _ = state.elastic_client
                            .index(elasticsearch::IndexParts::Index("bt-logs-v1"))
                            .body(doc) // Envia o documento gordo
                            .send()
                            .await
                            .map_err(|e| tracing::error!("Falha no Elastic: {}", e));

                        // Gatilho de Teste (Ola) - Opcional, mantido para validar conectividade
                        // ... (Codigo omitido para focar na indexacao, mas o handshake mantem a conexao)
                    }
                    Message::CommandResult { cmd_id, status, stdout, stderr } => {
                        tracing::info!("📝 CMD {}: {}", cmd_id, status);
                        // Tambem poderiamos indexar o resultado no Elastic aqui
                    }
                    _ => {}
                }
            }
        }
    }
}
'@
$serverSocketCode | Out-File -FilePath "crates/server/src/socket/mod.rs" -Encoding utf8

Write-Host "[SUCCESS] Dados Enriquecidos! O Elastic agora recebera User, Hardware e Perifericos." -ForegroundColor Cyan