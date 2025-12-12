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
