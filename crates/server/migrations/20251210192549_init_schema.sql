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
