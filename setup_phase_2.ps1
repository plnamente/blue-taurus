# ==============================================================================
# BLUE-TAURUS: FASE 2 - AGENT COLLECTOR SETUP
# Descrição: Implementa a logica de coleta de hardware (sysinfo) no Agente.
# Fix 1.1: Adiciona serde e serde_json ao Cargo.toml do agente.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 2] Implementando Inteligencia de Coleta no Agente..." -ForegroundColor Cyan

# Navegacao segura para garantir que estamos na pasta correta
if (Test-Path "crates/agent") {
    # Ja estamos na raiz do projeto (blue-taurus/blue-taurus)
} elseif (Test-Path "$ProjectName/crates/agent") {
    # Estamos um nivel acima
    Set-Location $ProjectName
} else {
    Write-Host "[ERROR] Raiz do projeto nao encontrada." -ForegroundColor Red
    Write-Host "Certifique-se de rodar este script dentro da pasta do projeto."
    exit 1
}

# 1. Atualizar dependencias do AGENT (Adicionar serde_json)
Write-Host "[FIX] Atualizando crates/agent/Cargo.toml..." -ForegroundColor Green
$agentCargoContent = @'
[package]
name = "agent"
version = "0.1.0"
edition = "2021"

[dependencies]
shared = { path = "../shared" }

# Runtime & Async
tokio = { version = "1", features = ["full"] }

# System Info
sysinfo = "0.29"

# Networking
reqwest = { version = "0.11", features = ["json"] }
tokio-tungstenite = { version = "0.20", features = ["native-tls"] }
url = "2.4"
futures-util = "0.3"

# Serialization (Adicionado para corrigir erro de compilacao)
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

# Logging & Utils
anyhow = "1.0"
tracing = "0.1"
tracing-subscriber = "0.3"
'@
$agentCargoContent | Out-File -FilePath "crates/agent/Cargo.toml" -Encoding utf8


# 2. Criar pasta do modulo collector (se nao existir)
New-Item -Path "crates/agent/src/collector" -ItemType Directory -Force | Out-Null

# 3. Criar o codigo do Coletor (sysinfo -> shared structs)
Write-Host "[CODE] Criando crates/agent/src/collector/mod.rs..." -ForegroundColor Green
$collectorCode = @'
use sysinfo::{CpuExt, DiskExt, System, SystemExt};
use shared::models::{HostInfo, HardwareInfo};

pub struct SystemCollector {
    sys: System,
}

impl SystemCollector {
    pub fn new() -> Self {
        let mut sys = System::new_all();
        sys.refresh_all();
        Self { sys }
    }

    pub fn collect(&mut self) -> HostInfo {
        // Atualiza dados dinamicos (CPU, RAM)
        self.sys.refresh_cpu();
        self.sys.refresh_memory();
        self.sys.refresh_disks();

        let hw_info = HardwareInfo {
            cpu_model: self.sys.cpus().first().map(|cpu| cpu.brand().to_string()).unwrap_or_default(),
            cpu_cores: self.sys.cpus().len(),
            ram_total_mb: self.sys.total_memory() / 1024 / 1024,
            ram_used_mb: self.sys.used_memory() / 1024 / 1024,
            disk_total_gb: self.sys.disks().iter().map(|d| d.total_space()).sum::<u64>() / 1024 / 1024 / 1024,
            disk_free_gb: self.sys.disks().iter().map(|d| d.available_space()).sum::<u64>() / 1024 / 1024 / 1024,
        };

        HostInfo {
            hostname: self.sys.host_name().unwrap_or_else(|| "unknown".to_string()),
            os_name: self.sys.name().unwrap_or_else(|| "unknown".to_string()),
            os_version: self.sys.os_version().unwrap_or_else(|| "unknown".to_string()),
            kernel_version: self.sys.kernel_version().unwrap_or_else(|| "unknown".to_string()),
            arch: std::env::consts::ARCH.to_string(),
            hardware: hw_info,
        }
    }
}
'@
$collectorCode | Out-File -FilePath "crates/agent/src/collector/mod.rs" -Encoding utf8

# 4. Atualizar main.rs do Agente para usar o Coletor
Write-Host "[CODE] Atualizando crates/agent/src/main.rs..." -ForegroundColor Green
$agentMainCode = @'
mod collector;

use std::time::Duration;
use tokio::time::sleep;
use collector::SystemCollector;

#[tokio::main]
async fn main() {
    // Inicializa sistema de logs
    tracing_subscriber::fmt::init();
    tracing::info!("Blue-Taurus Agent Iniciando...");

    // Inicializa o coletor
    let mut collector = SystemCollector::new();
    tracing::info!("Coletor de Sistema inicializado.");

    // Loop Infinito de Coleta (Simulacao)
    loop {
        tracing::info!("Coletando dados do host...");
        
        let host_info = collector.collect();
        
        // Imprime como JSON bonito para validarmos
        match serde_json::to_string_pretty(&host_info) {
            Ok(json) => println!("{}", json),
            Err(e) => tracing::error!("Erro ao serializar dados: {}", e),
        }

        tracing::info!("Dormindo por 5 segundos...");
        sleep(Duration::from_secs(5)).await;
    }
}
'@
$agentMainCode | Out-File -FilePath "crates/agent/src/main.rs" -Encoding utf8

Write-Host "[SUCCESS] Fase 2 Concluida!" -ForegroundColor Cyan
Write-Host "[NEXT] Para testar o Agente rodando:"
Write-Host "   cargo run -p agent"