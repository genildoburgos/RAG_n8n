-- =============================================================
-- DDL - Infraestrutura Multi-Projeto RAG
-- Compatível com n8n PGVector Store + Postgres Chat Memory
-- Embeddings: 1536 dimensões (text-embedding-ada-002 / 3-small)
-- =============================================================

-- 1. Habilita extensão pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- =============================================================
-- 2. Tabelas de vetores (uma por projeto/RAG)
--    Cada workflow n8n aponta para sua respectiva tabela
-- =============================================================

-- Projeto 1
CREATE TABLE IF NOT EXISTS n8n_vectors_projeto_1 (
    id BIGSERIAL PRIMARY KEY,
    text TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    embedding vector(1536)
);

CREATE INDEX IF NOT EXISTS n8n_vectors_projeto_1_embedding_idx
    ON n8n_vectors_projeto_1
    USING hnsw (embedding vector_cosine_ops);

-- Projeto 2
CREATE TABLE IF NOT EXISTS n8n_vectors_projeto_2 (
    id BIGSERIAL PRIMARY KEY,
    text TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    embedding vector(1536)
);

CREATE INDEX IF NOT EXISTS n8n_vectors_projeto_2_embedding_idx
    ON n8n_vectors_projeto_2
    USING hnsw (embedding vector_cosine_ops);

-- Projeto 3
CREATE TABLE IF NOT EXISTS n8n_vectors_projeto_3 (
    id BIGSERIAL PRIMARY KEY,
    text TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    embedding vector(1536)
);

CREATE INDEX IF NOT EXISTS n8n_vectors_projeto_3_embedding_idx
    ON n8n_vectors_projeto_3
    USING hnsw (embedding vector_cosine_ops);

-- =============================================================
-- 3. Tabelas de memória de chat (uma por projeto)
--    Cada workflow mantém seu próprio histórico isolado
-- =============================================================

-- Projeto 1
CREATE TABLE IF NOT EXISTS n8n_chat_histories_projeto_1 (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(255) NOT NULL,
    message JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS n8n_chat_histories_projeto_1_session_idx
    ON n8n_chat_histories_projeto_1 (session_id);

-- Projeto 2
CREATE TABLE IF NOT EXISTS n8n_chat_histories_projeto_2 (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(255) NOT NULL,
    message JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS n8n_chat_histories_projeto_2_session_idx
    ON n8n_chat_histories_projeto_2 (session_id);

-- Projeto 3
CREATE TABLE IF NOT EXISTS n8n_chat_histories_projeto_3 (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(255) NOT NULL,
    message JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS n8n_chat_histories_projeto_3_session_idx
    ON n8n_chat_histories_projeto_3 (session_id);
