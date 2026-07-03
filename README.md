# Infraestrutura Multi-Projeto RAG

Base genérica para rodar múltiplos agentes RAG com **PostgreSQL + pgvector** e **n8n**.

## Arquitetura

```
┌───────────────────┐
│   n8n (cloud)     │
│                   │
│  Workflow Proj 1 ─┼──▶ n8n_vectors_projeto_1 + n8n_chat_histories_projeto_1
│  Workflow Proj 2 ─┼──▶ n8n_vectors_projeto_2 + n8n_chat_histories_projeto_2
│  Workflow Proj 3 ─┼──▶ n8n_vectors_projeto_3 + n8n_chat_histories_projeto_3
│                   │
└───────┬───────────┘
        │
        ▼
┌──────────────────────────┐
│  PostgreSQL 16 + pgvector│
│  (Supabase / Docker)     │
│  Porta: 5432             │
└──────────────────────────┘
```

## Estrutura de tabelas

| Projeto   | Tabela de Vetores             | Tabela de Chat Memory              |
|-----------|-------------------------------|------------------------------------|
| Projeto 1 | `n8n_vectors_projeto_1`      | `n8n_chat_histories_projeto_1`     |
| Projeto 2 | `n8n_vectors_projeto_2`      | `n8n_chat_histories_projeto_2`     |
| Projeto 3 | `n8n_vectors_projeto_3`      | `n8n_chat_histories_projeto_3`     |

## Pré-requisitos

- Docker e Docker Compose
- Conta n8n (cloud ou self-hosted)
- Chave API OpenAI (para embeddings)

## Setup

```bash
# 1. Configure variáveis
cp .env.example .env

# 2. Suba o banco
docker compose up -d

# 3. Verifique
docker compose ps
```

> Se estiver usando Supabase, rode o conteúdo do `init-db.sql` no SQL Editor.

## Configuração dos Workflows no n8n

Cada projeto é um workflow independente com a mesma estrutura:

```
Upload file → PGVector Store (Insert) → Default Data Loader → Embeddings OpenAI
Chat Trigger → AI Agent → PGVector Store (Retrieve/Tool) → Embeddings OpenAI
                       → Postgres Chat Memory
                       → OpenAI Chat Model
```

### Credenciais Postgres (compartilhada entre projetos)

| Campo    | Docker local | Supabase (pooler gratuito)              |
|----------|--------------|------------------------------------------|
| Host     | `postgres`   | `aws-0-REGIAO.pooler.supabase.com`       |
| Port     | `5432`       | `6543`                                   |
| Database | `postgres`   | `postgres`                               |
| User     | `postgres`   | `postgres.SEU_PROJECT_ID`                |
| Password | do .env      | senha do projeto                         |
| SSL      | Não          | ✅ Sim                                   |

### Configuração por projeto

#### Workflow Projeto 1

| Nó                      | Table Name                        |
|-------------------------|-----------------------------------|
| PGVector Store (Insert) | `n8n_vectors_projeto_1`           |
| PGVector Store (Tool)   | `n8n_vectors_projeto_1`           |
| Postgres Chat Memory    | `n8n_chat_histories_projeto_1`    |

#### Workflow Projeto 2

| Nó                      | Table Name                        |
|-------------------------|-----------------------------------|
| PGVector Store (Insert) | `n8n_vectors_projeto_2`           |
| PGVector Store (Tool)   | `n8n_vectors_projeto_2`           |
| Postgres Chat Memory    | `n8n_chat_histories_projeto_2`    |

#### Workflow Projeto 3

| Nó                      | Table Name                        |
|-------------------------|-----------------------------------|
| PGVector Store (Insert) | `n8n_vectors_projeto_3`           |
| PGVector Store (Tool)   | `n8n_vectors_projeto_3`           |
| Postgres Chat Memory    | `n8n_chat_histories_projeto_3`    |

### Nó: PGVector Store (Tool do AI Agent)

| Parâmetro   | Valor |
|-------------|-------|
| Description | `Descreva aqui o tipo de dados do projeto. Ex: "Busca documentos sobre X. Sempre consulte antes de responder."` |
| Limit       | 4 |
| Include Metadata | ✅ |

### Nó: AI Agent

| Parâmetro      | Valor sugerido |
|----------------|----------------|
| System Message | `Você é um assistente especializado em [TEMA DO PROJETO]. SEMPRE consulte a ferramenta de busca vetorial antes de responder. Baseie suas respostas exclusivamente nos documentos encontrados. Se não encontrar informação relevante, diga que não possui essa informação.` |

## Adicionar um novo projeto

1. Crie as tabelas no banco:
```sql
CREATE TABLE IF NOT EXISTS n8n_vectors_projeto_N (
    id BIGSERIAL PRIMARY KEY,
    text TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    embedding vector(1536)
);

CREATE INDEX IF NOT EXISTS n8n_vectors_projeto_N_embedding_idx
    ON n8n_vectors_projeto_N
    USING hnsw (embedding vector_cosine_ops);

CREATE TABLE IF NOT EXISTS n8n_chat_histories_projeto_N (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(255) NOT NULL,
    message JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS n8n_chat_histories_projeto_N_session_idx
    ON n8n_chat_histories_projeto_N (session_id);
```

2. Duplique um workflow no n8n
3. Altere o Table Name dos nós para `n8n_vectors_projeto_N` e `n8n_chat_histories_projeto_N`
4. Ajuste Description e System Message para o novo tema

## Parar a infra

```bash
docker compose down        # para os containers
docker compose down -v     # para e apaga todos os dados
```

## Troubleshooting

| Erro | Solução |
|------|---------|
| `column "text" does not exist` | Tabela com coluna errada. Use `text`, não `content`. |
| `ENETUNREACH IPv6` | Use o pooler do Supabase (IPv4 gratuito). |
| `Host not found` | Remova `https://` do campo Host. Use apenas o hostname. |
| `None of your tools were used` | Preencha a Description do nó PGVector Store (Tool). |
| `relation "n8n_vectors_projeto_X" does not exist` | Rode o DDL no SQL Editor do Supabase. |
