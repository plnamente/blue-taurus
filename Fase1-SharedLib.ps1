# ==============================================================================
# BLUE-TAURUS: FASE 1 - SHARED LIB SETUP
# Descrição: Define os Modelos de Dados e Protocolo na lib 'shared'.
#            Atualiza Agent e Server para usar a nova definicao.
# ==============================================================================

$ProjectName = "blue-taurus"

# Garantir UTF-8 no output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 1] Iniciando configuracao da Biblioteca Compartilhada..." -ForegroundColor Cyan

# Verifica se estamos na pasta certa (dentro de blue-taurus ou na raiz com a pasta blue-taurus)
if (Test-Path "crates/shared") {
    # Estamos dentro da raiz do projeto
} elseif (Test-Path "$ProjectName/crates/shared") {
    Set-Location $ProjectName
} else {
    Write-Host "[ERROR] Pasta do projeto nao encontrada. Execute este script na raiz onde rodou o setup anterior." -ForegroundColor Red
    exit 1
}

# 1. Definir Modelos (Inventory, Hardware, Software)
Write-Host "[CODE] Escrevendo models/mod.rs..." -ForegroundColor Green
$modelsContent = @'
use serde::{Deserialize, Serialize};

/// Informacoes completas do Host (Agente)
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct HostInfo {
    pub hostname: String,
    pub os_name: String,      // Ex: Windows
    pub os_version: String,   // Ex: 11 (22H2)
    pub kernel_version: String,
    pub arch: String,         // Ex: x86_64
    pub hardware: HardwareInfo,
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

# 2. Definir Protocolo (Mensagens WebSocket)
Write-Host "[CODE] Escrevendo protocol/mod.rs..." -ForegroundColor Green
$protocolContent = @'
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use crate::models::{HostInfo, SoftwareInfo};

/// Enum principal que envelopa todas as mensagens trocadas via WebSocket
#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum Message {
    /// [Agente -> Server] Handshake inicial ao conectar
    Handshake {
        agent_id: Uuid,
        host_info: HostInfo,
        token: String, // Token de autenticacao (futuro)
    },
    
    /// [Server -> Agente] Resposta do Handshake
    HandshakeAck {
        status: String, // "OK" ou "DENIED"
        server_time: DateTime<Utc>,
    },
    
    /// [Agente -> Server] Sinal de vida periodico
    Heartbeat {
        agent_id: Uuid,
        timestamp: DateTime<Utc>,
    },
    
    /// [Agente -> Server] Relatorio completo de inventario
    InventoryReport {
        agent_id: Uuid,
        software: Vec<SoftwareInfo>,
    },
    
    /// [Server -> Agente] Comando para execucao (Push)
    Command {
        id: Uuid,
        cmd_type: CommandType,
        args: Option<String>, // Argumentos ou Payload (ex: script python)
        signature: String,    // Assinatura digital Ed25519
    },
    
    /// [Agente -> Server] Resultado da execucao de comando
    CommandResult {
        cmd_id: Uuid,
        status: String,       // "SUCCESS", "FAILED"
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
$protocolContent | Out-File -FilePath "crates/shared/src/protocol/mod.rs" -Encoding utf8

# 3. Atualizar lib.rs para expor os modulos
Write-Host "[CODE] Atualizando lib.rs..." -ForegroundColor Green
$libContent = @'
pub mod models;
pub mod protocol;

pub fn version() -> &'static str {
    "0.1.0"
}
'@
$libContent | Out-File -FilePath "crates/shared/src/lib.rs" -Encoding utf8

# 4. Atualizar AGENT para remover dependencia quebrada (hello_shared)
Write-Host "[FIX] Atualizando Agent main.rs..." -ForegroundColor Green
$agentMainFix = @'
use shared::protocol::Message; // Importando para validar compilacao

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    tracing::info!("Blue-Taurus Agent Iniciando...");
    
    // Valida se conseguimos acessar a versao da lib
    tracing::info!("Carregando Shared Lib v{}", shared::version());
}
'@
$agentMainFix | Out-File -FilePath "crates/agent/src/main.rs" -Encoding utf8

# 5. Atualizar SERVER para remover dependencia quebrada (hello_shared)
Write-Host "[FIX] Atualizando Server main.rs..." -ForegroundColor Green
$serverMainFix = @'
use axum::{routing::get, Router};
use std::net::SocketAddr;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    tracing::info!("Blue-Taurus Server Iniciando...");
    
    tracing::info!("Carregando Shared Lib v{}", shared::version());

    let app = Router::new().route("/", get(health_check));

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    tracing::info!("Escutando em {}", addr);
    
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn health_check() -> &'static str {
    "Blue-Taurus Server: ONLINE"
}
'@
$serverMainFix | Out-File -FilePath "crates/server/src/main.rs" -Encoding utf8


Write-Host "[SUCCESS] Fase 1 concluida! Codigos atualizados." -ForegroundColor Cyan
Write-Host "[NEXT] Execute 'cargo build' para validar as novas definicoes."