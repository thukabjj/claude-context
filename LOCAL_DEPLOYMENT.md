# Local Deployment Guide for Claude Context

This guide explains how to deploy Claude Context locally with different privacy and cost requirements.

## 🎯 Overview

Claude Context now supports three main deployment options:

1. **Fully Local (Ollama + ChromaDB)** - Complete privacy, no external API calls
2. **Open Source Models via OpenRouter** - High-quality open source models with API access
3. **Cloud Deployment (OpenAI + Zilliz Cloud)** - Easiest setup with managed services

## 🏠 Option 1: Fully Local Deployment

### What it provides:
- ✅ Complete privacy - no data leaves your machine
- ✅ No API costs - everything runs locally
- ✅ Full control over your infrastructure
- ✅ Works offline

### Requirements:
- Docker and Docker Compose
- Sufficient RAM (4GB+ recommended)
- Storage space for models and vector database

### Quick Setup:

```bash
# Run the automated setup script
./scripts/setup-local.sh
```

This script will:
1. Check for Docker installation
2. Start ChromaDB and Ollama containers
3. Pull the required embedding model
4. Provide configuration instructions

### Manual Setup:

```bash
# Start the required services
docker-compose -f docker-compose.local.yml up -d

# Pull the embedding model
curl -X POST http://localhost:11434/api/pull -d '{"name": "nomic-embed-text"}'
```

### Configuration:

**For Claude Code:**
```bash
claude mcp add claude-context \
  -e EMBEDDING_PROVIDER=Ollama \
  -e OLLAMA_HOST=http://localhost:11434 \
  -e EMBEDDING_MODEL=nomic-embed-text \
  -e VECTOR_DATABASE_PROVIDER=ChromaDB \
  -e CHROMA_HOST=localhost \
  -e CHROMA_PORT=8000 \
  -- npx @zilliz/claude-context-mcp@latest
```

**For other MCP clients:**
```json
{
  "mcpServers": {
    "claude-context": {
      "command": "npx",
      "args": ["@zilliz/claude-context-mcp@latest"],
      "env": {
        "EMBEDDING_PROVIDER": "Ollama",
        "OLLAMA_HOST": "http://localhost:11434",
        "EMBEDDING_MODEL": "nomic-embed-text",
        "VECTOR_DATABASE_PROVIDER": "ChromaDB",
        "CHROMA_HOST": "localhost",
        "CHROMA_PORT": "8000"
      }
    }
  }
}
```

## 🌐 Option 2: Open Source Models via OpenRouter

### What it provides:
- ✅ Access to high-quality open source embedding models
- ✅ Lower costs compared to OpenAI
- ✅ Local vector database for privacy
- ✅ No need to run embedding models locally

### Requirements:
- OpenRouter API key
- Docker for ChromaDB
- Internet connection for API calls

### Setup:

1. **Get OpenRouter API Key:**
   - Sign up at [OpenRouter](https://openrouter.ai/)
   - Get your API key (starts with `sk-or-`)

2. **Start ChromaDB:**
```bash
docker-compose -f docker-compose.local.yml up chromadb -d
```

3. **Configure MCP:**

**For Claude Code:**
```bash
claude mcp add claude-context \
  -e EMBEDDING_PROVIDER=OpenRouter \
  -e OPENROUTER_API_KEY=sk-or-your-openrouter-api-key \
  -e EMBEDDING_MODEL=nomic-ai/nomic-embed-text-v1.5 \
  -e VECTOR_DATABASE_PROVIDER=ChromaDB \
  -e CHROMA_HOST=localhost \
  -e CHROMA_PORT=8000 \
  -- npx @zilliz/claude-context-mcp@latest
```

**For other MCP clients:**
```json
{
  "mcpServers": {
    "claude-context": {
      "command": "npx",
      "args": ["@zilliz/claude-context-mcp@latest"],
      "env": {
        "EMBEDDING_PROVIDER": "OpenRouter",
        "OPENROUTER_API_KEY": "sk-or-your-openrouter-api-key",
        "EMBEDDING_MODEL": "nomic-ai/nomic-embed-text-v1.5",
        "VECTOR_DATABASE_PROVIDER": "ChromaDB",
        "CHROMA_HOST": "localhost",
        "CHROMA_PORT": "8000"
      }
    }
  }
}
```

### Available Open Source Models:

- `nomic-ai/nomic-embed-text-v1.5` (768 dimensions)
- `nomic-ai/nomic-embed-text-v1` (768 dimensions)
- `bge-large-en-v1.5` (1024 dimensions)
- `bge-base-en-v1.5` (768 dimensions)
- `bge-small-en-v1.5` (384 dimensions)
- `gte-large` (1024 dimensions)
- `gte-base` (768 dimensions)
- `gte-small` (384 dimensions)
- `mxbai-embed-large` (1024 dimensions)
- `mxbai-embed-base` (768 dimensions)

## ☁️ Option 3: Cloud Deployment

### What it provides:
- ✅ Easiest setup
- ✅ Managed infrastructure
- ✅ High availability
- ✅ No local resource requirements

### Setup:

Follow the standard setup instructions in the main README for OpenAI + Zilliz Cloud deployment.

## 🔧 Environment Variables Reference

### Embedding Providers

| Variable | Description | Default |
|----------|-------------|---------|
| `EMBEDDING_PROVIDER` | Provider: `OpenAI`, `VoyageAI`, `Gemini`, `Ollama`, `OpenRouter` | `OpenAI` |
| `EMBEDDING_MODEL` | Embedding model name | Provider-specific default |

### Ollama Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `OLLAMA_HOST` | Ollama server URL | `http://127.0.0.1:11434` |
| `OLLAMA_MODEL` | Model name (alternative to `EMBEDDING_MODEL`) | None |

### OpenRouter Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `OPENROUTER_API_KEY` | OpenRouter API key | Required |
| `OPENROUTER_BASE_URL` | OpenRouter API base URL | `https://openrouter.ai/api/v1` |

### Vector Database Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `VECTOR_DATABASE_PROVIDER` | Provider: `Milvus`, `ChromaDB` | `Milvus` |
| `CHROMA_HOST` | ChromaDB host | `localhost` |
| `CHROMA_PORT` | ChromaDB port | `8000` |
| `CHROMA_PATH` | ChromaDB path | None |
| `CHROMA_SSL` | ChromaDB SSL (true/false) | `false` |

## 🐳 Docker Services

### ChromaDB
- **Image**: `chromadb/chroma:latest`
- **Port**: 8000
- **Volume**: `chromadb_data:/chroma/chroma`
- **Health Check**: `http://localhost:8000/api/v1/heartbeat`

### Ollama
- **Image**: `ollama/ollama:latest`
- **Port**: 11434
- **Volume**: `ollama_data:/root/.ollama`
- **Health Check**: `http://localhost:11434/api/tags`

## 🚀 Usage Examples

### Index your codebase:
```
Index this codebase
```

### Search for code:
```
Find functions that handle user authentication
```

### Check indexing status:
```
Check the indexing status
```

## 🔍 Troubleshooting

### ChromaDB Issues:
```bash
# Check if ChromaDB is running
curl -f http://localhost:8000/api/v1/heartbeat

# View logs
docker-compose -f docker-compose.local.yml logs chromadb
```

### Ollama Issues:
```bash
# Check if Ollama is running
curl -f http://localhost:11434/api/tags

# View logs
docker-compose -f docker-compose.local.yml logs ollama

# Pull model manually
curl -X POST http://localhost:11434/api/pull -d '{"name": "nomic-embed-text"}'
```

### OpenRouter Issues:
```bash
# Test API key
curl -H "Authorization: Bearer sk-or-your-openrouter-api-key" \
     -H "Content-Type: application/json" \
     -d '{"model": "nomic-ai/nomic-embed-text-v1.5", "input": "test"}' \
     https://openrouter.ai/api/v1/embeddings
```

## 📊 Performance Comparison

| Deployment | Privacy | Cost | Setup Complexity | Performance |
|------------|---------|------|------------------|-------------|
| Fully Local | 🔒 High | 💰 Free | ⚠️ Medium | 🐌 Slower |
| OpenRouter + ChromaDB | 🔐 Medium | 💵 Low | ✅ Easy | ⚡ Fast |
| Cloud | 🌐 Low | 💸 Higher | ✅ Easiest | ⚡ Fastest |

## 🔗 Useful Commands

```bash
# Start all services
docker-compose -f docker-compose.local.yml up -d

# Stop all services
docker-compose -f docker-compose.local.yml down

# View logs
docker-compose -f docker-compose.local.yml logs -f

# Restart services
docker-compose -f docker-compose.local.yml restart

# Clean up volumes
docker-compose -f docker-compose.local.yml down -v
```

## 📚 Additional Resources

- [ChromaDB Documentation](https://docs.trychroma.com/)
- [Ollama Documentation](https://ollama.ai/docs)
- [OpenRouter Documentation](https://openrouter.ai/docs)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
