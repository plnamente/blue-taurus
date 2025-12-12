use axum::{extract::{ws::{Message as WsMessage, WebSocket, WebSocketUpgrade}, State}, response::IntoResponse};
use futures::stream::StreamExt; 
use std::sync::Arc;
use shared::protocol::Message;
use crate::AppState;

pub async fn ws_handler(ws: WebSocketUpgrade, State(state): State<Arc<AppState>>) -> impl IntoResponse {
    ws.on_upgrade(|socket| handle_socket(socket, state))
}

async fn handle_socket(socket: WebSocket, state: Arc<AppState>) {
    let (mut _sender, mut receiver) = socket.split();
    while let Some(Ok(msg)) = receiver.next().await {
        if let WsMessage::Text(text) = msg {
            if let Ok(protocol_msg) = serde_json::from_str::<Message>(&text) {
                match protocol_msg {
                    Message::Handshake { agent_id, host_info, .. } => {
                        tracing::info!("ðŸ¤ Handshake: {}", host_info.hostname);
                        let _ = sqlx::query!("INSERT INTO agents (id, hostname, os_name, status, last_seen_at) VALUES ($1, $2, $3, 'ONLINE', NOW()) ON CONFLICT(id) DO UPDATE SET last_seen_at = NOW(), status='ONLINE'", agent_id, host_info.hostname, host_info.os_name).execute(&state.pg_pool).await;
                        
                        let _ = sqlx::query!(
                            r#"INSERT INTO hardware_specs (agent_id, cpu_model, cpu_cores, ram_total_mb, disk_total_gb)
                               VALUES ($1, $2, $3, $4, $5)
                               ON CONFLICT (agent_id) DO UPDATE SET cpu_model=EXCLUDED.cpu_model, ram_total_mb=EXCLUDED.ram_total_mb"#,
                            agent_id, host_info.hardware.cpu_model, host_info.hardware.cpu_cores as i32, host_info.hardware.ram_total_mb as i64, host_info.hardware.disk_total_gb as i64
                        ).execute(&state.pg_pool).await;
                    },
                    Message::ScaReport { agent_id, report } => {
                        tracing::info!("ðŸ›¡ï¸ SCA Report: {}%", report.score);
                        let details_json = serde_json::to_value(&report.results).unwrap_or_default();
                        let _ = sqlx::query(r#"INSERT INTO compliance_scores (agent_id, policy_id, score, total_checks, passed_checks, details, last_scan_at) VALUES ($1, $2, $3, $4, $5, $6, NOW()) ON CONFLICT (agent_id) DO UPDATE SET score=EXCLUDED.score, details=EXCLUDED.details"#)
                            .bind(agent_id).bind(&report.policy_id).bind(report.score as i32).bind(report.total_checks as i32).bind(report.passed_checks as i32).bind(details_json).execute(&state.pg_pool).await;
                    },
                    _ => {}
                }
            }
        }
    }
}
