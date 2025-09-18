#!/bin/bash

# Claude Context Complete Setup Script
# This script starts everything you need for Claude Context with OpenRouter + ChromaDB

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -i :$port >/dev/null 2>&1; then
        print_warning "Port $port is already in use. Please stop the service using this port."
        return 1
    fi
    return 0
}

# Function to start Docker services
start_docker_services() {
    print_status "Starting Docker services..."

    # Start ChromaDB and Ollama
    docker-compose -f docker-compose.local.yml up -d

    # Wait for services to be ready
    print_status "Waiting for services to start..."
    sleep 10

    # Check ChromaDB
    if curl -f http://localhost:8002/api/v1/heartbeat >/dev/null 2>&1; then
        print_success "ChromaDB is running on port 8002"
    else
        print_warning "ChromaDB may still be starting up..."
    fi

    # Check Ollama
    if curl -f http://localhost:11434/api/tags >/dev/null 2>&1; then
        print_success "Ollama is running on port 11434"
    else
        print_warning "Ollama may still be starting up..."
    fi
}

# Function to get OpenRouter API key
get_openrouter_key() {
    echo
    print_status "OpenRouter API Key Setup"
    echo "=============================="
    echo
    echo "To use OpenRouter with open source models, you need an API key."
    echo "1. Visit: https://openrouter.ai/"
    echo "2. Sign up for an account"
    echo "3. Get your API key (starts with 'sk-or-')"
    echo "4. Add credits to your account"
    echo

    read -p "Enter your OpenRouter API key: " OPENROUTER_KEY

    if [[ -z "$OPENROUTER_KEY" ]]; then
        print_error "OpenRouter API key is required"
        exit 1
    fi

    if [[ ! "$OPENROUTER_KEY" =~ ^sk-or- ]]; then
        print_warning "OpenRouter API keys usually start with 'sk-or-'. Please verify your key."
    fi
}

# Function to generate MCP configuration
generate_mcp_config() {
    local openrouter_key=$1

    print_status "Generating MCP configuration..."

    # Create MCP configuration file
    cat > mcp-config.json << EOF
{
  "mcpServers": {
    "claude-context": {
      "command": "npx",
      "args": ["-y", "@zilliz/claude-context-mcp@latest"],
      "env": {
        "EMBEDDING_PROVIDER": "OpenRouter",
        "OPENROUTER_API_KEY": "$openrouter_key",
        "EMBEDDING_MODEL": "nomic-ai/nomic-embed-text-v1.5",
        "VECTOR_DATABASE_PROVIDER": "ChromaDB",
        "CHROMA_HOST": "localhost",
        "CHROMA_PORT": "8002",
        "HYBRID_MODE": "true",
        "EMBEDDING_BATCH_SIZE": "100",
        "SPLITTER_TYPE": "ast"
      }
    }
  }
}
EOF

    print_success "MCP configuration saved to mcp-config.json"
}

# Function to show usage instructions
show_usage_instructions() {
    echo
    print_success "Claude Context is ready to use!"
    echo
    echo "=== Configuration Summary ==="
    echo "✅ Embedding Provider: OpenRouter (open source models)"
    echo "✅ Embedding Model: nomic-ai/nomic-embed-text-v1.5 (768 dimensions)"
    echo "✅ Vector Database: ChromaDB (localhost:8002)"
    echo "✅ Hybrid Search: Enabled (BM25 + dense vector)"
    echo "✅ Code Splitter: AST-based (syntax-aware)"
    echo
    echo "=== MCP Configuration ==="
    echo "Copy the following configuration to your MCP client:"
    echo
    cat mcp-config.json
    echo
    echo "=== Usage Instructions ==="
    echo "1. Copy the JSON configuration above to your MCP client"
    echo "2. For Claude Code: Use the command line interface"
    echo "3. For Cursor: Paste into ~/.cursor/mcp.json"
    echo "4. For other MCP clients: Use the JSON configuration"
    echo
    echo "=== Testing ==="
    echo "1. Open your project directory"
    echo "2. Start your MCP client (Claude Code, Cursor, etc.)"
    echo "3. Type: 'Index this codebase'"
    echo "4. Wait for indexing to complete"
    echo "5. Try: 'Find functions that handle user authentication'"
    echo
    echo "=== Available Open Source Models ==="
    echo "• nomic-ai/nomic-embed-text-v1.5 (768 dims, latest, recommended)"
    echo "• bge-large-en-v1.5 (1024 dims, best quality)"
    echo "• bge-base-en-v1.5 (768 dims, balanced)"
    echo "• bge-small-en-v1.5 (384 dims, fastest)"
    echo "• voyage-code-3 (1536 dims, code-optimized)"
    echo
    print_status "Next steps:"
    echo "1. Configure your MCP client with the JSON above"
    echo "2. Test the integration by indexing a codebase"
    echo "3. Start using semantic code search!"
}

# Function to test OpenRouter API
test_openrouter_api() {
    local api_key=$1

    print_status "Testing OpenRouter API connection..."

    if curl -s -H "Authorization: Bearer $api_key" \
        "https://openrouter.ai/api/v1/models" >/dev/null; then
        print_success "OpenRouter API is accessible"
    else
        print_warning "OpenRouter API test failed - please verify your API key"
    fi
}

# Main function
main() {
    echo "Claude Context Complete Setup"
    echo "============================="
    echo
    echo "This script will set up Claude Context with:"
    echo "• OpenRouter for open source embedding models"
    echo "• ChromaDB for local vector database"
    echo "• Hybrid search (BM25 + dense vector)"
    echo "• AST-based code splitting"
    echo

    # Check Docker
    check_docker

    # Get OpenRouter API key
    get_openrouter_key

    # Start Docker services
    start_docker_services

    # Test OpenRouter API
    test_openrouter_api "$OPENROUTER_KEY"

    # Generate MCP configuration
    generate_mcp_config "$OPENROUTER_KEY"

    # Show usage instructions
    show_usage_instructions
}

# Help function
show_help() {
    echo "Claude Context Complete Setup Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo
    echo "This script will:"
    echo "1. Start ChromaDB and Ollama Docker containers"
    echo "2. Get your OpenRouter API key"
    echo "3. Generate MCP configuration"
    echo "4. Provide setup instructions"
}

# Version function
show_version() {
    echo "Claude Context Complete Setup Script v1.0.0"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--version)
        show_version
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
