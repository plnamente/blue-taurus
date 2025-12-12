# --- ESTAGIO 1: BUILDER (Compilacao) ---
# Base estavel que sabemos que existe
FROM rust:1.83-slim-bookworm AS builder

# Instalar dependencias de sistema
RUN apt-get update && apt-get install -y pkg-config libssl-dev curl && rm -rf /var/lib/apt/lists/*

# Instalar Nightly manualmente (para suportar crates recentes 'edition2024')
RUN rustup toolchain install nightly && rustup default nightly

WORKDIR /app

# Copiar todo o codigo fonte (incluindo a pasta .sqlx gerada)
COPY . .

# CRITICO: Habilita modo offline do SQLx para nao tentar conectar no banco durante o build
ENV SQLX_OFFLINE=true

# Compilar o binario do SERVIDOR em modo release
RUN cargo build --release --bin server

# --- ESTAGIO 2: RUNTIME (Execucao Leve) ---
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y libssl-dev ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/server /app/server
COPY --from=builder /app/assets /app/assets
COPY --from=builder /app/crates/server/migrations /app/migrations

EXPOSE 3000

ENV RUST_LOG=info
ENV APP_ENVIRONMENT=production

CMD ["./server"]
