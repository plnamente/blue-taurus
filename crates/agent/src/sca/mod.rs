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
        tracing::info!("ðŸ›¡ï¸  Iniciando varredura de Compliance SCA...");

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

        tracing::info!("ðŸ“‹ Politica carregada: {}", policy.name);

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

        tracing::info!("ðŸ Varredura concluida. Score: {}% ({}/{} checks)", score, passed_count, total);

        Some(ComplianceReport {
            policy_id: policy.id,
            score,
            total_checks: total,
            passed_checks: passed_count as u32,
            results,
        })
    }
}
