#!/bin/bash

# Claude Context Local Deployment Setup Script
# This script sets up a fully local deployment using ChromaDB and Ollama

set -e

echo "🚀 Setting up Claude Context for local deployment..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if pnpm is installed
if ! command -v pnpm &> /dev/null; then
    echo "❌ pnpm is not installed. Please install pnpm first: npm install -g pnpm"
    exit 1
fi

# Build the project
echo "🔨 Building the project..."
pnpm install
pnpm build
echo "✅ Project built successfully"

# Create .env file for local configuration
echo "📝 Creating local configuration file..."
cat > .env.local << 'EOF'
# Claude Context Local Deployment Configuration

# Embedding Provider (Choose one)
EMBEDDING_PROVIDER=Ollama
# EMBEDDING_PROVIDER=OpenRouter

# For Ollama (fully local)
OLLAMA_HOST=http://localhost:11434
EMBEDDING_MODEL=nomic-embed-text

# For OpenRouter (open source models via API)
# OPENROUTER_API_KEY=your-openrouter-api-key
# EMBEDDING_MODEL=nomic-ai/nomic-embed-text-v1.5

# Vector Database (local ChromaDB)
VECTOR_DATABASE_PROVIDER=ChromaDB
CHROMA_HOST=localhost
CHROMA_PORT=8002

# Optional: Custom file extensions and ignore patterns
# CUSTOM_EXTENSIONS=.vue,.svelte,.astro
# CUSTOM_IGNORE_PATTERNS=temp/**,*.backup,private/**
EOF

echo "✅ Created .env.local configuration file"

# Start Docker services
echo "🐳 Starting Docker services..."
docker-compose -f docker-compose.local.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check if ChromaDB is running
echo "🔍 Checking ChromaDB status..."
if curl -f http://localhost:8002/api/v2/heartbeat > /dev/null 2>&1; then
    echo "✅ ChromaDB is running"
else
    echo "❌ ChromaDB is not responding. Please check the logs:"
    echo "   docker-compose -f docker-compose.local.yml logs chromadb"
    exit 1
fi

# Check if Ollama is running
echo "🔍 Checking Ollama status..."
if curl -f http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "✅ Ollama is running"
else
    echo "❌ Ollama is not responding. Please check the logs:"
    echo "   docker-compose -f docker-compose.local.yml logs ollama"
    exit 1
fi

# Pull the embedding model for Ollama
echo "📥 Pulling embedding model for Ollama..."
curl -X POST http://localhost:11434/api/pull -d '{"name": "nomic-embed-text"}'

echo ""
echo "🎉 Local deployment setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Configure your MCP client with the following settings:"
echo ""
echo "   For Claude Code:"
echo "   claude mcp add claude-context \\"
echo "     -e EMBEDDING_PROVIDER=Ollama \\"
echo "     -e OLLAMA_HOST=http://localhost:11434 \\"
echo "     -e EMBEDDING_MODEL=nomic-embed-text \\"
echo "     -e VECTOR_DATABASE_PROVIDER=ChromaDB \\"
echo "     -e CHROMA_HOST=localhost \\"
echo "     -e CHROMA_PORT=8002 \\"
echo "     -- node $(pwd)/packages/mcp/dist/index.js"
echo ""
echo "   For other MCP clients, add to your configuration:"
echo "   {"
echo "     \"mcpServers\": {"
echo "       \"claude-context\": {"
echo "         \"command\": \"node\","
echo "         \"args\": [\"$(pwd)/packages/mcp/dist/index.js\"],"
echo "         \"env\": {"
echo "           \"EMBEDDING_PROVIDER\": \"Ollama\","
echo "           \"OLLAMA_HOST\": \"http://localhost:11434\","
echo "           \"EMBEDDING_MODEL\": \"nomic-embed-text\","
echo "           \"VECTOR_DATABASE_PROVIDER\": \"ChromaDB\","
echo "           \"CHROMA_HOST\": \"localhost\","
echo "           \"CHROMA_PORT\": \"8002\""
echo "         }"
echo "       }"
echo "     }"
echo "   }"
echo ""
echo "2. Start using Claude Context with:"
echo "   - Index your codebase: 'Index this codebase'"
echo "   - Search for code: 'Find functions that handle user authentication'"
echo ""
echo "🔧 Useful commands:"
echo "   - View logs: docker-compose -f docker-compose.local.yml logs -f"
echo "   - Stop services: docker-compose -f docker-compose.local.yml down"
echo "   - Restart services: docker-compose -f docker-compose.local.yml restart"
echo ""
echo "📚 For more information, see the README.md file"
