# --- ESTAGIO 1: BUILDER (Compilacao) ---
# Usando 'rust:nightly' (Imagem completa) para garantir que a tag existe e suporta edition2024
FROM rust:nightly AS builder

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
