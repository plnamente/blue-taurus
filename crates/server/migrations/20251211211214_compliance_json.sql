CREATE TABLE IF NOT EXISTS compliance_scores (
    agent_id UUID PRIMARY KEY REFERENCES agents(id),
    policy_id VARCHAR(100),
    score INT,
    total_checks INT,
    passed_checks INT,
    details JSONB,  -- NOVO: Armazena o array de regras (CheckResult)
    last_scan_at TIMESTAMPTZ DEFAULT NOW()
);
