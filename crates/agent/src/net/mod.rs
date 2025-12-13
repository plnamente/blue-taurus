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
    // URL DE PRODUCAO (Coolify)
    // Nota: Se configurar SSL no Coolify depois, mude para wss://
    let url = Url::parse("ws://uk4gco4wgco84s0gco0w4co8.72.60.141.205.sslip.io/ws").unwrap();

    loop {
        tracing::info!("Tentando conectar ao servidor em {}...", url);
        
        match connect_async(url.clone()).await {
            Ok((ws_stream, _)) => {
                tracing::info!("âœ… Conectado!");
                let (mut write, mut read) = ws_stream.split();

                let handshake = Message::Handshake {
                    agent_id,
                    host_info: host_info.clone(),
                    token: "dev-token".to_string(),
                };
                let _ = write.send(WsMessage::Text(serde_json::to_string(&handshake).unwrap())).await;

                if let Some(report) = &sca_report {
                    tracing::info!("ðŸ“¤ Enviando Relatorio de Compliance...");
                    let msg = Message::ScaReport {
                        agent_id,
                        report: report.clone(),
                    };
                    if let Err(e) = write.send(WsMessage::Text(serde_json::to_string(&msg).unwrap())).await {
                        tracing::error!("Erro ao enviar SCA report: {}", e);
                    }
                }

                loop {
                    tokio::select! {
                        _ = sleep(Duration::from_secs(10)) => {
                            let hb = Message::Heartbeat { agent_id, timestamp: chrono::Utc::now() };
                            if let Err(_) = write.send(WsMessage::Text(serde_json::to_string(&hb).unwrap())).await { break; }
                        }
                        msg = read.next() => {
                            match msg {
                                Some(Ok(WsMessage::Text(text))) => {
                                    if let Ok(Message::Command { id, cmd_type, args, signature }) = serde_json::from_str(&text) {
                                        tracing::info!("Comando recebido (Logica completa no script Fase 5)");
                                    }
                                }
                                Some(Err(_)) | None => break, 
                                _ => {}
                            }
                        }
                    }
                }
            }
            Err(e) => {
                tracing::error!("Falha conexao: {}. Retry 5s...", e);
                sleep(Duration::from_secs(5)).await;
            }
        }
    }
}
