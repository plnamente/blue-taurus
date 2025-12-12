# ==============================================================================
# BLUE-TAURUS: FASE 12 - SCA COMPLIANCE ENGINE
# Descrição: Implementa motor de auditoria baseado em políticas YAML (Wazuh-style).
# Fix 1.1: Salva YAML sem BOM para evitar erro de parse no serde_yaml.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 12] Construindo Motor de Compliance (SCA)..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# ==============================================================================
# 1. DEPENDENCIAS (SHARED & AGENT) - Adicionar serde_yaml
# ==============================================================================
Write-Host "[FIX] Adicionando serde_yaml as dependencias..." -ForegroundColor Green

# Shared Cargo.toml
$sharedCargo = @'
[package]
name = "shared"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
serde_yaml = "0.9"  # NOVO: Para ler as politicas
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1.0", features = ["v4", "serde"] }
thiserror = "1.0"
ed25519-dalek = { version = "2.0", features = ["rand_core"] }
hex = "0.4"
rand = "0.8"
base64 = "0.21"
'@
$sharedCargo | Out-File -FilePath "crates/shared/Cargo.toml" -Encoding utf8

# Agent Cargo.toml
$agentCargo = @'
[package]
name = "agent"
version = "0.1.0"
edition = "2021"

[dependencies]
shared = { path = "../shared" }
tokio = { version = "1", features = ["full"] }
sysinfo = "0.29"
reqwest = { version = "0.11", features = ["json"] }
tokio-tungstenite = { version = "0.20", features = ["native-tls"] }
url = "2.4"
futures-util = "0.3"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
serde_yaml = "0.9" # NOVO
anyhow = "1.0"
tracing = "0.1"
tracing-subscriber = "0.3"
futures = "0.3"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1.0", features = ["v4", "serde"] }
base64 = "0.21"
'@
$agentCargo | Out-File -FilePath "crates/agent/Cargo.toml" -Encoding utf8


# ==============================================================================
# 2. MODELOS SCA (SHARED)
# ==============================================================================
Write-Host "[CODE] Criando crates/shared/src/models/sca.rs..." -ForegroundColor Green
New-Item -Path "crates/shared/src/models" -ItemType Directory -Force | Out-Null

$scaModelCode = @'
use serde::{Deserialize, Serialize};

/// Define uma Politica de Seguranca (Lida do YAML)
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Policy {
    pub id: String,
    pub name: String,
    pub description: String,
    pub rules: Vec<Rule>,
}

/// Define uma Regra especifica (ex: Verificar Firewall)
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Rule {
    pub id: u32,
    pub title: String,
    pub description: Option<String>,
    pub command: String,      // Comando PowerShell a executar
    pub expect: String,       // O que esperamos ver na saida (Regex simples ou String)
    pub remediation: Option<String>,
}

/// Relatorio de Execucao da Politica
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ComplianceReport {
    pub policy_id: String,
    pub score: u32,           // Porcentagem de aprovacao
    pub total_checks: u32,
    pub passed_checks: u32,
    pub results: Vec<CheckResult>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct CheckResult {
    pub rule_id: u32,
    pub title: String,
    pub status: String,       // "PASS" ou "FAIL"
    pub output: String,       // O que o comando retornou
}
'@
$scaModelCode | Out-File -FilePath "crates/shared/src/models/sca.rs" -Encoding utf8

# Atualizar models/mod.rs para incluir sca
$modRs = @'
pub mod sca;
use serde::{Deserialize, Serialize};

// --- MANTENDO MODELS ANTIGOS ---
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
    pub software: Vec<SoftwareInfo>,
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
$modRs | Out-File -FilePath "crates/shared/src/models/mod.rs" -Encoding utf8


# ==============================================================================
# 3. CRIAR POLITICA EXEMPLO (CIS BASIC) - SEM BOM
# ==============================================================================
Write-Host "[DATA] Criando assets/cis_windows_basic.yaml (No BOM)..." -ForegroundColor Green
New-Item -Path "assets" -ItemType Directory -Force | Out-Null

$yamlPolicy = @'
id: "cis_win11_basic"
name: "CIS Microsoft Windows 11 Benchmark (Basic)"
description: "Verificacoes essenciais de higiene cibernetica."
rules:
  - id: 1001
    title: "Garantir que o Firewall do Windows esta Ativo (Domain)"
    description: "O Firewall protege contra acesso nao autorizado de rede."
    command: "Get-NetFirewallProfile -Profile Domain | Select-Object -ExpandProperty Enabled"
    expect: "True"
    remediation: "Set-NetFirewallProfile -Profile Domain -Enabled True"

  - id: 1002
    title: "Garantir que o Windows Update Service esta rodando"
    description: "Atualizacoes sao criticas para seguranca."
    command: "Get-Service wuauserv | Select-Object -ExpandProperty Status"
    expect: "Running"
    remediation: "Start-Service wuauserv"

  - id: 1003
    title: "Verificar se o usuario 'Guest' esta desativado"
    description: "Contas de convidado sao vetores de ataque comuns."
    command: "Get-LocalUser -Name Guest | Select-Object -ExpandProperty Enabled"
    expect: "False"
    remediation: "Disable-LocalUser -Name Guest"
'@

# FIX: Usar .NET para escrever UTF8 SEM BOM explicitamente
$Utf8NoBom = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllText("$PWD/assets/cis_windows_basic.yaml", $yamlPolicy, $Utf8NoBom)


# ==============================================================================
# 4. AGENT: IMPLEMENTAR MOTOR SCA
# ==============================================================================
Write-Host "[CODE] Criando crates/agent/src/sca/mod.rs..." -ForegroundColor Green
New-Item -Path "crates/agent/src/sca" -ItemType Directory -Force | Out-Null

$engineCode = @'
use shared::models::sca::{Policy, ComplianceReport, CheckResult};
use std::process::Command;
use std::fs;

pub struct ScaEngine {
    policy_path: String,
}

impl ScaEngine {
    pub fn new(path: &str) -> Self {
        Self { policy_path: path.to_string() }
    }

    pub fn run_scan(&self) -> Option<ComplianceReport> {
        tracing::info!("🛡️  Iniciando varredura de Compliance SCA...");

        // 1. Carregar Politica
        let content = match fs::read_to_string(&self.policy_path) {
            Ok(c) => c,
            Err(e) => {
                tracing::error!("Falha ao ler politica YAML: {}", e);
                return None;
            }
        };

        let policy: Policy = match serde_yaml::from_str(&content) {
            Ok(p) => p,
            Err(e) => {
                tracing::error!("Erro de parse no YAML: {}", e);
                return None;
            }
        };

        tracing::info!("📋 Politica carregada: {}", policy.name);

        let mut results = Vec::new();
        let mut passed_count = 0;

        // 2. Executar Regras
        for rule in &policy.rules {
            tracing::info!("   Verificando Regra {}: {}", rule.id, rule.title);
            
            // Executa comando (PowerShell no Windows, sh no Linux)
            let output = if cfg!(target_os = "windows") {
                // Fix: Usar 'powershell' explicitamente e garantir UTF8 no output
                Command::new("powershell")
                    .args(&["-NoProfile", "-Command", &format!("[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; {}", rule.command)])
                    .output()
            } else {
                Command::new("sh")
                    .arg("-c")
                    .arg(&rule.command)
                    .output()
            };

            let (status, output_str) = match output {
                Ok(o) => {
                    let out_txt = String::from_utf8_lossy(&o.stdout).trim().to_string();
                    // Logica simples de "Contains" (Pode evoluir para Regex)
                    if out_txt.contains(&rule.expect) {
                        passed_count += 1;
                        ("PASS", out_txt)
                    } else {
                        ("FAIL", out_txt)
                    }
                },
                Err(e) => ("ERROR", e.to_string())
            };

            results.push(CheckResult {
                rule_id: rule.id,
                title: rule.title.clone(),
                status: status.to_string(),
                output: output_str,
            });
        }

        let total = policy.rules.len() as u32;
        let score = if total > 0 { (passed_count as f32 / total as f32 * 100.0) as u32 } else { 0 };

        tracing::info!("🏁 Varredura concluida. Score: {}% ({}/{} checks)", score, passed_count, total);

        Some(ComplianceReport {
            policy_id: policy.id,
            score,
            total_checks: total,
            passed_checks: passed_count as u32,
            results,
        })
    }
}
'@
$engineCode | Out-File -FilePath "crates/agent/src/sca/mod.rs" -Encoding utf8


# ==============================================================================
# 5. AGENT: INTEGRAR NO MAIN LOOP
# ==============================================================================
Write-Host "[CODE] Atualizando crates/agent/src/main.rs..." -ForegroundColor Green

$agentMain = @'
mod collector;
mod net;
mod sca;

use uuid::Uuid;
use collector::SystemCollector;
use sca::ScaEngine;
use std::process::Command;
use std::fs;

// (Funcao get_stable_agent_id omitida para brevidade, mas deve ser mantida se nao for sobrescrita inteira)
// Para garantir que o script funcione, vou re-incluir a logica de ID simplificada.
fn get_stable_agent_id() -> Uuid {
    // Tenta ler local primeiro
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
    tracing::info!("🚀 Blue-Taurus Agent v1.2 (SCA Engine)");

    let agent_id = get_stable_agent_id();
    tracing::info!("🆔 Agent ID: {}", agent_id);

    // 1. Coleta Inventario Basico
    let mut collector = SystemCollector::new();
    let host_info = collector.collect();
    
    // 2. Executa Varredura de Compliance (SCA)
    // Nota: Em prod, isso baixaria do servidor. Aqui lemos do arquivo local para teste.
    // O arquivo assets/cis_windows_basic.yaml deve estar na mesma pasta do executavel ou na raiz do projeto.
    // Tentamos ler da raiz do projeto para facilitar 'cargo run'
    let sca = ScaEngine::new("assets/cis_windows_basic.yaml");
    if let Some(report) = sca.run_scan() {
        tracing::info!("📊 Relatorio de Compliance gerado com sucesso.");
        // TODO: Enviar este relatorio via WebSocket na proxima versao do protocolo
    } else {
        tracing::warn!("⚠️  Nao foi possivel rodar o SCA (Arquivo YAML nao encontrado?)");
    }

    // 3. Conecta
    net::start_agent_loop(agent_id, host_info).await;
}
'@
$agentMain | Out-File -FilePath "crates/agent/src/main.rs" -Encoding utf8

Write-Host "[SUCCESS] Motor SCA Instalado!" -ForegroundColor Cyan
Write-Host "1. O arquivo de politica esta em 'assets/cis_windows_basic.yaml'."
Write-Host "2. Rode 'cargo run -p agent' e veja ele auditando seu Windows."