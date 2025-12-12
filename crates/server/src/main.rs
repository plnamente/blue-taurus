mod socket;
use axum::{routing::{get, delete}, Router, extract::{State, Path}, response::{Json}, http};
use tower_http::services::ServeDir;
use sqlx::postgres::{PgPool, PgPoolOptions};
use elasticsearch::Elasticsearch;
use elasticsearch::http::transport::Transport;
use std::net::SocketAddr;
use std::sync::Arc;
use dotenvy::dotenv;
use serde::{Serialize, Deserialize};
use uuid::Uuid;

pub struct AppState { pub pg_pool: PgPool, pub elastic_client: Elasticsearch }

#[derive(Serialize, sqlx::FromRow)]
pub struct AgentRow {
    id: Uuid, hostname: String, os_name: String, status: Option<String>,
    last_seen_at: Option<chrono::DateTime<chrono::Utc>>,
    compliance_score: Option<i32>
}

#[derive(Serialize)]
pub struct AgentDetails {
    agent: AgentRow,
    hardware: Option<HardwareRow>,
    software: Vec<SoftwareRow>,
    compliance: Option<ComplianceDetails>,
}

// FIX: Adicionado cpu_cores
#[derive(Serialize, sqlx::FromRow)]
pub struct HardwareRow { 
    cpu_model: Option<String>, 
    cpu_cores: Option<i32>, 
    ram_total_mb: Option<i64>, 
    disk_total_gb: Option<i64> 
}

#[derive(Serialize, sqlx::FromRow)]
pub struct SoftwareRow { name: String, version: Option<String>, vendor: Option<String>, install_date: Option<String> }

#[derive(Serialize, sqlx::FromRow)]
pub struct ComplianceDetails { policy_id: Option<String>, score: Option<i32>, total_checks: Option<i32>, passed_checks: Option<i32>, details: Option<serde_json::Value> }

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenv().ok();
    tracing_subscriber::fmt::init();
    tracing::info!("ðŸš€ Blue-Taurus Server v1.5");

    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL");
    let pg_pool = PgPoolOptions::new().max_connections(5).connect(&db_url).await.expect("PG Fail");
    sqlx::migrate!("./migrations").run(&pg_pool).await.ok(); 

    let es_url = std::env::var("ELASTIC_URL").expect("ELASTIC_URL");
    let transport = Transport::single_node(&es_url)?;
    let elastic_client = Elasticsearch::new(transport);

    let state = Arc::new(AppState { pg_pool, elastic_client });

    let app = Router::new()
        .route("/api/agents", get(list_agents))
        .route("/api/agents/:id", delete(delete_agent))
        .route("/api/agents/:id/details", get(get_agent_details))
        .route("/ws", get(socket::ws_handler))
        .nest_service("/", ServeDir::new("assets"))
        .with_state(state);

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    axum::Server::bind(&addr).serve(app.into_make_service()).await.unwrap();
    Ok(())
}

async fn list_agents(State(state): State<Arc<AppState>>) -> Json<Vec<AgentRow>> {
    let sql = r#"SELECT a.id, a.hostname, a.os_name, a.status, a.last_seen_at, c.score as compliance_score FROM agents a LEFT JOIN compliance_scores c ON a.id = c.agent_id ORDER BY a.last_seen_at DESC"#;
    let agents = sqlx::query_as::<_, AgentRow>(sql).fetch_all(&state.pg_pool).await.unwrap_or_default();
    Json(agents)
}

async fn delete_agent(Path(id): Path<Uuid>, State(state): State<Arc<AppState>>) -> http::StatusCode {
    let _ = sqlx::query!("DELETE FROM compliance_scores WHERE agent_id = $1", id).execute(&state.pg_pool).await;
    let _ = sqlx::query!("DELETE FROM agents WHERE id = $1", id).execute(&state.pg_pool).await;
    http::StatusCode::NO_CONTENT
}

async fn get_agent_details(Path(id): Path<Uuid>, State(state): State<Arc<AppState>>) -> Json<Option<AgentDetails>> {
    let agent = sqlx::query_as::<_, AgentRow>("SELECT id, hostname, os_name, status, last_seen_at, NULL::int as compliance_score FROM agents WHERE id = $1").bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);

    if let Some(ag) = agent {
        // FIX: Buscando cpu_cores
        let hw = sqlx::query_as::<_, HardwareRow>("SELECT cpu_model, cpu_cores, ram_total_mb, disk_total_gb FROM hardware_specs WHERE agent_id = $1").bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);
        let sw = sqlx::query_as::<_, SoftwareRow>("SELECT name, version, vendor, install_date FROM software_inventory WHERE agent_id = $1 ORDER BY name ASC").bind(id).fetch_all(&state.pg_pool).await.unwrap_or_default();
        let comp = sqlx::query_as::<_, ComplianceDetails>("SELECT policy_id, score, total_checks, passed_checks, details FROM compliance_scores WHERE agent_id = $1").bind(id).fetch_optional(&state.pg_pool).await.unwrap_or(None);
        return Json(Some(AgentDetails { agent: ag, hardware: hw, software: sw, compliance: comp }));
    }
    Json(None)
}
