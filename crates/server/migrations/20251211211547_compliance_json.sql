-- Drop para garantir que a tabela seja recriada com a coluna details se ja existir versao antiga
DROP TABLE IF EXISTS compliance_scores;

CREATE TABLE compliance_scores (
    agent_id UUID PRIMARY KEY REFERENCES agents(id),
    policy_id VARCHAR(100),
    score INT,
    total_checks INT,
    passed_checks INT,
    details JSONB,  -- NOVO: Armazena o array de regras (CheckResult)
    last_scan_at TIMESTAMPTZ DEFAULT NOW()
);
