use axum::{
    extract::{ws::{Message as WsMessage, WebSocket, WebSocketUpgrade}, State},
    response::IntoResponse,
};
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
                        // FIX: Usando sqlx::query() (funcao) em vez de sqlx::query!() (macro)
                        let _ = sqlx::query("INSERT INTO agents (id, hostname, os_name, status, last_seen_at) VALUES ($1, $2, $3, 'ONLINE', NOW()) ON CONFLICT(id) DO UPDATE SET last_seen_at = NOW(), status='ONLINE'")
                            .bind(agent_id)
                            .bind(host_info.hostname)
                            .bind(host_info.os_name)
                            .execute(&state.pg_pool).await;
                    },
                    Message::ScaReport { agent_id, report } => {
                        tracing::info!("ðŸ›¡ï¸ SCA Report recebido de {}: Score {}%", agent_id, report.score);

                        let details_json = serde_json::to_value(&report.results).unwrap_or_default();

                        let q = r#"INSERT INTO compliance_scores (agent_id, policy_id, score, total_checks, passed_checks, details, last_scan_at)
                               VALUES ($1, $2, $3, $4, $5, $6, NOW())
                               ON CONFLICT (agent_id) DO UPDATE SET 
                               score = EXCLUDED.score, passed_checks = EXCLUDED.passed_checks, details = EXCLUDED.details, last_scan_at = NOW()"#;
                        
                        // FIX: Runtime Query
                        let _ = sqlx::query(q)
                            .bind(agent_id)
                            .bind(&report.policy_id)
                            .bind(report.score as i32)
                            .bind(report.total_checks as i32)
                            .bind(report.passed_checks as i32)
                            .bind(details_json)
                            .execute(&state.pg_pool).await
                            .map_err(|e| tracing::error!("Erro Postgres SCA: {}", e));

                        // Elastic Indexing (Mantido igual)
                        let mut doc = serde_json::to_value(&report).unwrap();
                        if let Some(obj) = doc.as_object_mut() {
                            obj.insert("@timestamp".to_string(), serde_json::json!(chrono::Utc::now()));
                            obj.insert("event_type".to_string(), serde_json::json!("sca_report"));
                            obj.insert("agent_id".to_string(), serde_json::json!(agent_id));
                        }
                        let _ = state.elastic_client.index(elasticsearch::IndexParts::Index("bt-logs-v1")).body(doc).send().await;
                    },
                    _ => {}
                }
            }
        }
    }
}
