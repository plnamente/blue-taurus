# ==============================================================================
# BLUE-TAURUS: FIX 1.5 - AGENT IDENTITY (HARDWARE BINDING)
# Descrição: Amarra o Agent ID ao UUID da Placa-Mãe (Hardware) para evitar duplicatas.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[FIX] Implementando Identidade baseada em Hardware..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/agent") { Set-Location $ProjectName }

# Atualizar crates/agent/src/main.rs
Write-Host "[CODE] Atualizando crates/agent/src/main.rs..." -ForegroundColor Green

$agentMainCode = @'
mod collector;
mod net;

use uuid::Uuid;
use collector::SystemCollector;
use std::process::Command;
use std::fs;

/// Tenta obter um ID estavel baseado no Hardware (Motherboard UUID)
fn get_stable_agent_id() -> Uuid {
    tracing::info!("🔍 Buscando identidade de hardware...");

    // ESTRATEGIA 1: Hardware UUID (Windows)
    if cfg!(target_os = "windows") {
        // Executa: wmic csproduct get uuid
        let output = Command::new("cmd")
            .args(&["/C", "wmic csproduct get uuid"])
            .output();

        if let Ok(o) = output {
            let stdout = String::from_utf8_lossy(&o.stdout);
            // O output costuma ser:
            // UUID
            // XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
            //
            for line in stdout.lines() {
                let trimmed = line.trim();
                // Tenta fazer parse de qualquer linha que pareca um UUID
                if let Ok(uuid) = Uuid::parse_str(trimmed) {
                    tracing::info!("✅ Identidade de Hardware Encontrada (BIOS UUID): {}", uuid);
                    return uuid;
                }
            }
        }
    }

    // ESTRATEGIA 2: Arquivo de Persistencia Local (.agent_id)
    // Caso nao consiga ler o hardware (ex: Linux/Mac sem root ou VM generica)
    let id_file = ".agent_id";
    if let Ok(content) = fs::read_to_string(id_file) {
        if let Ok(uuid) = Uuid::parse_str(content.trim()) {
            tracing::info!("📂 Identidade carregada do arquivo local.");
            return uuid;
        }
    }

    // ESTRATEGIA 3: Geracao Aleatoria (Ultimo recurso)
    let new_id = Uuid::new_v4();
    tracing::warn!("⚠️  Hardware ID nao encontrado. Gerando novo ID aleatorio.");
    
    // Salva para tentar manter persistencia no proximo boot
    let _ = fs::write(id_file, new_id.to_string());
    
    new_id
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    tracing::info!("🚀 Blue-Taurus Agent v1.0");

    // 1. Obtem ID Unico (Hardware Bound)
    let agent_id = get_stable_agent_id();
    tracing::info!("🆔 Agent ID Definitivo: {}", agent_id);

    // 2. Coleta Inicial
    let mut collector = SystemCollector::new();
    let host_info = collector.collect();
    tracing::info!("💻 Inventario: {} (User: {})", host_info.hostname, host_info.logged_user);

    // 3. Inicia Loop de Rede
    net::start_agent_loop(agent_id, host_info).await;
}
'@
$agentMainCode | Out-File -FilePath "crates/agent/src/main.rs" -Encoding utf8

Write-Host "[SUCCESS] Logica de Identidade aplicada!" -ForegroundColor Cyan
Write-Host "Ao reiniciar o agente, ele deve manter o mesmo ID sempre."