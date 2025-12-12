# ==============================================================================
# BLUE-TAURUS: FASE 3 - SERVER & DATABASE SETUP
# Descrição: Configura Docker (Postgres/Elastic), Migrations e Conexão SQLx.
# Fix 1.1: Move migrations para crates/server/migrations (caminho esperado pelo sqlx)
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 3] Iniciando configuracao do Servidor e Banco de Dados..." -ForegroundColor Cyan

# Navegacao segura
if (Test-Path "crates/server") {
    # Ja estamos na raiz
} elseif (Test-Path "$ProjectName/crates/server") {
    Set-Location $ProjectName
} else {
    Write-Host "[ERROR] Raiz do projeto nao encontrada." -ForegroundColor Red
    exit 1
}

# 1. Criar docker-compose.yml (Infraestrutura)
Write-Host "[INFRA] Criando docker/docker-compose.yml..." -ForegroundColor Green
$dockerComposeContent = @'
version: '3.8'

services:
  # --- Banco Relacional (Fonte da Verdade) ---
  postgres:
    image: postgres:15-alpine
    container_name: bt_postgres
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: password123
      POSTGRES_DB: blue_taurus
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  # --- Motor de Busca (Logs & Analytics) ---
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.5.0
    container_name: bt_elastic
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false    # Desativado para facilitar DEV local
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
    volumes:
      - elastic_data:/usr/share/elasticsearch/data
    restart: unless-stopped

  # --- Interface Visual (Opcional - para debug) ---
  kibana:
    image: docker.elastic.co/kibana/kibana:8.5.0
    container_name: bt_kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

volumes:
  postgres_data:
  elastic_data:
'@
$dockerComposeContent | Out-File -FilePath "docker/docker-compose.yml" -Encoding utf8

# 2. Criar arquivo .env (Segredos)
Write-Host "[CONF] Criando arquivo .env..." -ForegroundColor Green
$envContent = @'
# Configuracoes do Servidor
RUST_LOG=info
SERVER_HOST=127.0.0.1
SERVER_PORT=3000

# Banco de Dados (PostgreSQL)
DATABASE_URL=postgres://admin:password123@localhost:5432/blue_taurus

# Elastic Search
ELASTIC_URL=http://localhost:9200
'@
$envContent | Out-File -FilePath ".env" -Encoding utf8

# 3. Criar Migrations SQL (Estrutura do Banco)
# FIX: Cria o diretorio dentro de crates/server para a macro encontrar
Write-Host "[SQL] Criando migrations em crates/server/migrations..." -ForegroundColor Green
New-Item -Path "crates/server/migrations" -ItemType Directory -Force | Out-Null

$migrationSql = @'
-- Tabela de Agentes (Identidade)
CREATE TABLE IF NOT EXISTS agents (
    id UUID PRIMARY KEY,
    hostname VARCHAR(255) NOT NULL,
    os_name VARCHAR(100) NOT NULL,
    os_version VARCHAR(100),
    kernel_version VARCHAR(100),
    arch VARCHAR(50),
    ip_address VARCHAR(45),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'ONLINE'
);

-- Tabela de Hardware (1:1 com Agents)
CREATE TABLE IF NOT EXISTS hardware_specs (
    agent_id UUID PRIMARY KEY REFERENCES agents(id),
    cpu_model VARCHAR(255),
    cpu_cores INT,
    ram_total_mb BIGINT,
    disk_total_gb BIGINT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de Softwares (1:N com Agents)
CREATE TABLE IF NOT EXISTS software_inventory (
    id SERIAL PRIMARY KEY,
    agent_id UUID REFERENCES agents(id),
    name VARCHAR(255) NOT NULL,
    version VARCHAR(100),
    vendor VARCHAR(255),
    install_date VARCHAR(50),
    last_scanned_at TIMESTAMPTZ DEFAULT NOW()
);
'@
# Nome do arquivo deve seguir padrao timestamp_nome
$migrationName = (Get-Date).ToString("yyyyMMddHHmmss") + "_init_schema.sql"
$migrationSql | Out-File -FilePath "crates/server/migrations/$migrationName" -Encoding utf8


# 4. Atualizar SERVER main.rs (Conexão e Inicialização)
Write-Host "[CODE] Atualizando crates/server/src/main.rs..." -ForegroundColor Green
$serverMainCode = @'
use axum::{routing::get, Router};
use sqlx::postgres::PgPoolOptions;
use std::net::SocketAddr;
use std::time::Duration;
use dotenvy::dotenv;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // 1. Carrega variaveis de ambiente (.env)
    dotenv().ok();
    
    // 2. Inicializa Logs
    tracing_subscriber::fmt::init();
    tracing::info!("🚀 Blue-Taurus Server Iniciando...");

    // 3. Conexao com Banco de Dados (Postgres)
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL nao configurada");
    tracing::info!("Conectando ao PostgreSQL...");
    
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .acquire_timeout(Duration::from_secs(5))
        .connect(&db_url)
        .await
        .expect("Falha ao conectar no Postgres");

    tracing::info!("✅ Conexao com Banco de Dados estabelecida!");

    // 4. Rodar Migrations Automaticamente (Cria tabelas se nao existirem)
    // A macro migrate! procura a pasta migrations relativa a este arquivo ou crate root
    tracing::info!("Rodando migrations...");
    sqlx::migrate!()
        .run(&pool)
        .await
        .expect("Falha ao rodar migrations");
    
    // 5. Configurar Rotas
    let app = Router::new()
        .route("/", get(health_check))
        .with_state(pool); // Passa o pool de conexao para as rotas (futuro)

    // 6. Iniciar Servidor
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    tracing::info!("👂 Servidor escutando em {}", addr);
    
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();

    Ok(())
}

async fn health_check() -> &'static str {
    "Blue-Taurus Server: ONLINE & DB CONNECTED 🐂"
}
'@
$serverMainCode | Out-File -FilePath "crates/server/src/main.rs" -Encoding utf8

Write-Host "[SUCCESS] Fase 3 - Configuração Concluída!" -ForegroundColor Cyan
Write-Host "[NEXT STEPS]:"
Write-Host "1. Inicie o Docker Desktop."
Write-Host "2. Suba os bancos de dados:"
Write-Host "   docker compose -f docker/docker-compose.yml up -d"
Write-Host "3. Rode o servidor:"
Write-Host "   cargo run -p server"