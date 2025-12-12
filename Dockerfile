# --- ESTAGIO 1: BUILDER (Compilacao) ---
# Comecamos com uma imagem que SABEMOS que existe (1.83-slim)
FROM rust:1.83-slim-bookworm AS builder

# Instalar dependencias de sistema
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

# INSTALACAO MANUAL DO NIGHTLY
# Como as tags 'rust:nightly' estao falhando no pull, instalamos manualmente.
# Isso garante suporte a 'edition2024' exigido pelas dependencias.
RUN rustup toolchain install nightly && rustup default nightly

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
