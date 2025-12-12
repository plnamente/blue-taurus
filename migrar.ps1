# ==============================================================================
# BLUE-TAURUS: DOCKER DEPLOYMENT KIT
# Descrição: Cria Dockerfile Otimizado (Multi-stage) para deploy no Coolify.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[DEPLOY] Gerando configuracao Docker para Coolify..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# 1. CRIAR DOCKERFILE (Multi-stage Build)
# Este arquivo ensina o Coolify a:
# Estagio 1: Baixar Rust, Compilar o projeto em modo Release (Otimizado)
# Estagio 2: Criar uma imagem Linux leve, copiar o executavel e os Assets (HTML)
Write-Host "[FILE] Criando Dockerfile..." -ForegroundColor Green
$dockerfileContent = @'
# --- ESTAGIO 1: BUILDER (Compilacao) ---
FROM rust:1.81-slim-bookworm as builder

# Instalar dependencias de sistema necessarias para compilar (OpenSSL, pkg-config)
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

# Criar diretorio de trabalho
WORKDIR /app

# Copiar todo o codigo fonte
COPY . .

# Compilar o binario do SERVIDOR em modo release
# O binario do agente nao precisa ser compilado aqui, pois roda no cliente Windows
RUN cargo build --release --bin server

# --- ESTAGIO 2: RUNTIME (Execucao Leve) ---
FROM debian:bookworm-slim

# Instalar dependencias de runtime (OpenSSL, Certificados CA para HTTPS)
RUN apt-get update && apt-get install -y libssl-dev ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copiar o binario compilado do estagio anterior
COPY --from=builder /app/target/release/server /app/server

# Copiar pastas essenciais (HTML/CSS/JS e Migrations)
# O Coolify precisa disso para servir a pagina e criar as tabelas no banco
COPY --from=builder /app/assets /app/assets
COPY --from=builder /app/crates/server/migrations /app/migrations

# Expor a porta 3000
EXPOSE 3000

# Definir variaveis de ambiente padrao (Serao sobrescritas pelo Coolify)
ENV RUST_LOG=info
ENV APP_ENVIRONMENT=production

# Comando para iniciar
CMD ["./server"]
'@
$dockerfileContent | Out-File -FilePath "Dockerfile" -Encoding utf8

# 2. CRIAR .DOCKERIGNORE
# Evita enviar arquivos pesados ou inuteis para o servidor
Write-Host "[FILE] Criando .dockerignore..." -ForegroundColor Green
$dockerIgnoreContent = @'
target/
.git/
.env
*.md
docker/
scripts/
fix_*.ps1
setup_*.ps1
testes/
'@
$dockerIgnoreContent | Out-File -FilePath ".dockerignore" -Encoding utf8

Write-Host "[SUCCESS] Arquivos Docker criados!" -ForegroundColor Cyan
Write-Host "Proximo passo: Subir o codigo para o GitHub e configurar no Coolify."