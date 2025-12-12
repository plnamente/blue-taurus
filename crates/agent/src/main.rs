mod collector;
mod net;
mod sca;

use uuid::Uuid;
use collector::SystemCollector;
use sca::ScaEngine;
use std::fs;

fn get_stable_agent_id() -> Uuid {
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
    tracing::info!("ðŸš€ Blue-Taurus Agent v1.4 (SCA Details)");

    let agent_id = get_stable_agent_id();
    tracing::info!("ðŸ†” Agent ID: {}", agent_id);

    let mut collector = SystemCollector::new();
    let host_info = collector.collect();
    
    let sca = ScaEngine::new("assets/cis_windows_basic.yaml");
    let report = sca.run_scan();

    if report.is_some() {
        tracing::info!("ðŸ“Š Relatorio SCA gerado.");
    }

    net::start_agent_loop(agent_id, host_info, report).await;
}
