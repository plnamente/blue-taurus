use tokio_tungstenite::{connect_async, tungstenite::protocol::Message as WsMessage};
use futures::{SinkExt, StreamExt};
use url::Url;
use shared::protocol::{Message, CommandType};
use shared::models::HostInfo;
use shared::models::sca::ComplianceReport;
use shared::crypto;
use uuid::Uuid;
use std::time::Duration;
use tokio::time::sleep;
use std::process::Command;

const ADMIN_PUBLIC_KEY: &str = "4d6e4d06c24a64de1044ff65403bdbe4ff5cf70bc48c062117a90e47b9f03c7b"; 

pub async fn start_agent_loop(agent_id: Uuid, host_info: HostInfo, sca_report: Option<ComplianceReport>) {
    let url = Url::parse("ws://127.0.0.1:3000/ws").unwrap();
    loop {
        tracing::info!("Tentando conectar ao servidor...");
        match connect_async(url.clone()).await {
            Ok((ws_stream, _)) => {
                tracing::info!("âœ… Conectado!");
                let (mut write, mut read) = ws_stream.split();

                let handshake = Message::Handshake { agent_id, host_info: host_info.clone(), token: "dev".to_string() };
                let _ = write.send(WsMessage::Text(serde_json::to_string(&handshake).unwrap())).await;

                if let Some(report) = &sca_report {
                    tracing::info!("ðŸ“¤ Enviando Relatorio de Compliance...");
                    let msg = Message::ScaReport { agent_id, report: report.clone() };
                    let _ = write.send(WsMessage::Text(serde_json::to_string(&msg).unwrap())).await;
                }

                loop {
                    tokio::select! {
                        _ = sleep(Duration::from_secs(10)) => {
                            let hb = Message::Heartbeat { agent_id, timestamp: chrono::Utc::now() };
                            if let Err(_) = write.send(WsMessage::Text(serde_json::to_string(&hb).unwrap())).await { break; }
                        }
                        msg = read.next() => {
                            if let Some(Ok(WsMessage::Text(text))) = msg {
                                if let Ok(Message::Command { .. }) = serde_json::from_str(&text) {
                                    tracing::info!("Comando recebido");
                                }
                            } else if msg.is_none() { break; }
                        }
                    }
                }
            }
            Err(e) => { tracing::error!("Falha: {}. Retry 5s...", e); sleep(Duration::from_secs(5)).await; }
        }
    }
}
