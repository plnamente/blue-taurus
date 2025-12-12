use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use crate::models::{HostInfo, SoftwareInfo};
use crate::models::sca::ComplianceReport;

#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum Message {
    Handshake {
        agent_id: Uuid,
        host_info: HostInfo,
        token: String,
    },
    HandshakeAck {
        status: String,
        server_time: DateTime<Utc>,
    },
    Heartbeat {
        agent_id: Uuid,
        timestamp: DateTime<Utc>,
    },
    InventoryReport {
        agent_id: Uuid,
        software: Vec<SoftwareInfo>,
    },
    ScaReport {
        agent_id: Uuid,
        report: ComplianceReport,
    },
    Command {
        id: Uuid,
        cmd_type: CommandType,
        args: Option<String>,
        signature: String,
    },
    CommandResult {
        cmd_id: Uuid,
        status: String,
        stdout: String,
        stderr: String,
    },
}

#[derive(Debug, Serialize, Deserialize)]
pub enum CommandType {
    RunScript,
    UpdateConfig,
    RestartAgent,
}
