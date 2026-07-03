# Infraestrutura Multi-Projeto RAG + WhatsApp

Base reutilizável para agentes RAG com **PostgreSQL + pgvector**, **Evolution API** (WhatsApp) e workflows **n8n**.

## Arquitetura

```
┌──────────────┐                    ┌─────────────────┐
│  WhatsApp    │◀──── webhook ─────▶│      n8n        │
│  (usuário)   │                    │                 │
└──────────────┘                    │  AI Agent + RAG │
       ▲                            └───────┬─────────┘
       │                                    │
       │ mensagem                           │ busca vetorial
       │                                    ▼
┌──────────────┐                    ┌──────────────────┐
│ Evolution API│                    │ PostgreSQL 16    │
│ (Docker)     │                    │ + pgvector       │
│ :8080        │                    │ :5432            │
└──────────────┘                    └──────────────────┘
       │
┌──────────────┐
│    Redis     │
│ (cache)      │
│ :6379        │
└──────────────┘
```

## Estrutura do Projeto

```
RAG_n8n/
├── docker-compose.yml                      # Postgres + Redis + Evolution API
├── init-db.sql                             # DDL multi-projeto (vetores + chat)
├── .env.example                            # Template de variáveis
├── .gitignore
├── README.md
└── workflows/
    ├── workflow_projeto_1.json             # RAG via chat web (n8n)
    ├── workflow_projeto_2.json
    ├── workflow_projeto_3.json
    ├── workflow_projeto_1_whatsapp.json    # RAG via WhatsApp
    ├── workflow_projeto_2_whatsapp.json
    └── workflow_projeto_3_whatsapp.json
```

## Tabelas no Banco

| Projeto   | Vetores                       | Chat Memory                        |
|-----------|-------------------------------|------------------------------------|
| Projeto 1 | `n8n_vectors_projeto_1`      | `n8n_chat_histories_projeto_1`     |
| Projeto 2 | `n8n_vectors_projeto_2`      | `n8n_chat_histories_projeto_2`     |
| Projeto 3 | `n8n_vectors_projeto_3`      | `n8n_chat_histories_projeto_3`     |

## Pré-requisitos

- Docker e Docker Compose
- Conta n8n (cloud ou self-hosted)
- Chave API OpenAI
- Número de WhatsApp para conectar

## Setup Rápido

```bash
# 1. Clone o repositório
git clone git@github.com:genildoburgos/RAG_n8n.git
cd RAG_n8n

# 2. Configure variáveis
cp .env.example .env
# Edite o .env com suas credenciais

# 3. Suba tudo
docker compose up -d

# 4. Verifique
docker compose ps
```

## Configuração da Evolution API

### 1. Acesse o painel

Após subir o Docker, acesse: `http://localhost:8080`

### 2. Crie uma instância WhatsApp

```bash
curl -X POST http://localhost:8080/instance/create \
  -H "apikey: your-evolution-api-key-here" \
  -H "Content-Type: application/json" \
  -d '{
    "instanceName": "projeto-1",
    "integration": "WHATSAPP-BAILEYS",
    "qrcode": true
  }'
```

### 3. Conecte via QR Code

```bash
curl -X GET http://localhost:8080/instance/connect/projeto-1 \
  -H "apikey: your-evolution-api-key-here"
```

Escaneie o QR Code com seu WhatsApp.

### 4. Configure o Webhook na Evolution API

Aponte o webhook da instância para o n8n:

```bash
curl -X POST http://localhost:8080/webhook/set/projeto-1 \
  -H "apikey: your-evolution-api-key-here" \
  -H "Content-Type: application/json" \
  -d '{
    "webhook": {
      "url": "https://SEU-N8N.app.n8n.cloud/webhook/webhook-whatsapp-projeto-1",
      "webhookByEvents": false,
      "webhookBase64": false,
      "events": ["MESSAGES_UPSERT"]
    }
  }'
```

> Substitua a URL pelo webhook real do seu n8n cloud.

## Workflows n8n

### Workflows Chat (web)

Usam o Chat Trigger nativo do n8n. Bom para testar o RAG via interface web.

| Workflow | Arquivo |
|----------|---------|
| Projeto 1 | `workflow_projeto_1.json` |
| Projeto 2 | `workflow_projeto_2.json` |
| Projeto 3 | `workflow_projeto_3.json` |

### Workflows WhatsApp

Recebem mensagens via Evolution API webhook e respondem automaticamente.

| Workflow | Arquivo | Webhook Path |
|----------|---------|--------------|
| Projeto 1 | `workflow_projeto_1_whatsapp.json` | `/webhook/webhook-whatsapp-projeto-1` |
| Projeto 2 | `workflow_projeto_2_whatsapp.json` | `/webhook/webhook-whatsapp-projeto-2` |
| Projeto 3 | `workflow_projeto_3_whatsapp.json` | `/webhook/webhook-whatsapp-projeto-3` |

### Fluxo do Workflow WhatsApp

```
WhatsApp Webhook → Filtra tipo → Extrai dados → AI Agent (RAG) → Responde via Evolution API
                                                      │
                                          ┌───────────┼───────────┐
                                          ▼           ▼           ▼
                                    Chat Model   PGVector    Chat Memory
                                    (OpenAI)     (busca)    (histórico)
```

### Como importar

1. No n8n → **Import workflow** → cole o JSON
2. Substitua `SUBSTITUIR_CREDENTIAL_ID` pelas suas credenciais
3. Ative o workflow

## Credenciais necessárias no n8n

| Credencial | Tipo | Uso |
|------------|------|-----|
| OpenAI API | OpenAI | Chat Model + Embeddings |
| Postgres (vector) | Postgres | PGVector Store + Chat Memory |

### Configuração Postgres no n8n

| Campo    | Docker local         | Supabase (pooler)                     |
|----------|----------------------|---------------------------------------|
| Host     | `postgres`           | `aws-0-REGIAO.pooler.supabase.com`    |
| Port     | `5432`               | `6543`                                |
| Database | `postgres`           | `postgres`                            |
| User     | `postgres`           | `postgres.SEU_PROJECT_ID`             |
| Password | do .env              | senha do projeto                      |
| SSL      | Não                  | Sim                                   |

## Adicionar novo projeto

1. Crie as tabelas:
```sql
CREATE TABLE IF NOT EXISTS n8n_vectors_projeto_N (
    id BIGSERIAL PRIMARY KEY,
    text TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    embedding vector(1536)
);
CREATE INDEX IF NOT EXISTS n8n_vectors_projeto_N_embedding_idx
    ON n8n_vectors_projeto_N USING hnsw (embedding vector_cosine_ops);

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
3. Altere Table Names e webhook path
4. Crie nova instância na Evolution API
5. Configure o webhook da instância para o novo workflow

## Comandos úteis

```bash
# Ver logs da Evolution API
docker compose logs -f evolution-api

# Reiniciar Evolution API
docker compose restart evolution-api

# Parar tudo
docker compose down

# Apagar dados
docker compose down -v
```

## Troubleshooting

| Erro | Solução |
|------|---------|
| `column "text" does not exist` | Use `text`, não `content` na tabela |
| `ENETUNREACH IPv6` | Use pooler do Supabase (IPv4) |
| `None of your tools were used` | Preencha Description do PGVector Store Tool |
| QR Code não aparece | Verifique logs: `docker compose logs evolution-api` |
| Webhook não chega no n8n | Confira URL do webhook e se o workflow está ativo |
| `relation does not exist` | Rode o `init-db.sql` no banco |
