#!/bin/bash

# Claude Context Vector Database Switcher
# This script helps you switch between different local vector databases

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

# Function to stop all vector database containers
stop_all_containers() {
    print_status "Stopping all vector database containers..."

    # Stop ChromaDB
    docker stop claude-context-chromadb 2>/dev/null || true
    docker stop claude-context-chromadb-cloud 2>/dev/null || true

    # Stop Qdrant
    docker stop claude-context-qdrant 2>/dev/null || true

    # Stop Milvus
    docker stop claude-context-milvus 2>/dev/null || true

    print_success "All containers stopped"
}

# Function to start ChromaDB
start_chromadb() {
    print_status "Starting ChromaDB..."

    docker run -d \
        --name claude-context-chromadb \
        --restart unless-stopped \
        -p 8002:8000 \
        -v chromadb_data:/chroma/chroma \
        -e CHROMA_SERVER_HOST=0.0.0.0 \
        -e CHROMA_SERVER_HTTP_PORT=8000 \
        -e CHROMA_SERVER_CORS_ALLOW_ORIGINS='["*"]' \
        chromadb/chroma:latest

    # Wait for ChromaDB to be ready
    print_status "Waiting for ChromaDB to start..."
    sleep 10

    # Test connection
    if curl -f http://localhost:8002/api/v1/heartbeat >/dev/null 2>&1; then
        print_success "ChromaDB is running on port 8002"
        return 0
    else
        print_error "ChromaDB failed to start"
        return 1
    fi
}

# Function to start Qdrant
start_qdrant() {
    print_status "Starting Qdrant..."

    docker run -d \
        --name claude-context-qdrant \
        --restart unless-stopped \
        -p 6333:6333 \
        -p 6334:6334 \
        -v qdrant_data:/qdrant/storage \
        qdrant/qdrant:latest

    # Wait for Qdrant to be ready
    print_status "Waiting for Qdrant to start..."
    sleep 10

    # Test connection
    if curl -f http://localhost:6333/collections >/dev/null 2>&1; then
        print_success "Qdrant is running on port 6333"
        return 0
    else
        print_error "Qdrant failed to start"
        return 1
    fi
}

# Function to start Milvus
start_milvus() {
    print_status "Starting Milvus..."

    # Create Milvus docker-compose file
    cat > docker-compose.milvus.yml << 'EOF'
version: '3.5'

services:
  etcd:
    container_name: milvus-etcd
    image: quay.io/coreos/etcd:v3.5.5
    environment:
      - ETCD_AUTO_COMPACTION_MODE=revision
      - ETCD_AUTO_COMPACTION_RETENTION=1000
      - ETCD_QUOTA_BACKEND_BYTES=4294967296
      - ETCD_SNAPSHOT_COUNT=50000
    command: etcd -advertise-client-urls=http://127.0.0.1:2379 -listen-client-urls http://0.0.0.0:2379 --data-dir /etcd
    healthcheck:
      test: ["CMD", "etcdctl", "endpoint", "health"]
      interval: 30s
      timeout: 20s
      retries: 3
    volumes:
      - milvus_etcd_data:/etcd

  minio:
    container_name: milvus-minio
    image: minio/minio:RELEASE.2023-03-20T20-16-18Z
    environment:
      MINIO_ACCESS_KEY: minioadmin
      MINIO_SECRET_KEY: minioadmin
    command: minio server /minio_data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
    volumes:
      - milvus_minio_data:/minio_data

  milvus:
    container_name: claude-context-milvus
    image: milvusdb/milvus:v2.3.0
    command: ["milvus", "run", "standalone"]
    environment:
      ETCD_ENDPOINTS: etcd:2379
      MINIO_ADDRESS: minio:9000
    volumes:
      - milvus_data:/var/lib/milvus
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9091/healthz"]
      interval: 30s
      start_period: 90s
      timeout: 20s
      retries: 3
    ports:
      - "19530:19530"
      - "9091:9091"
    depends_on:
      - "etcd"
      - "minio"

volumes:
  milvus_etcd_data:
  milvus_minio_data:
  milvus_data:
EOF

    # Start Milvus
    docker-compose -f docker-compose.milvus.yml up -d

    # Wait for Milvus to be ready
    print_status "Waiting for Milvus to start (this may take a few minutes)..."
    sleep 60

    # Test connection
    if curl -f http://localhost:9091/healthz >/dev/null 2>&1; then
        print_success "Milvus is running on port 19530"
        return 0
    else
        print_error "Milvus failed to start"
        return 1
    fi
}

# Function to generate MCP configuration
generate_mcp_config() {
    local db_type=$1
    local embedding_model=$2
    local openrouter_key=$3

    print_status "Generating MCP configuration for $db_type..."

    case $db_type in
        "chromadb")
            echo "=== ChromaDB Configuration ==="
            echo "claude mcp add claude-context \\"
            echo "  -e EMBEDDING_PROVIDER=OpenRouter \\"
            echo "  -e OPENROUTER_API_KEY=$openrouter_key \\"
            echo "  -e EMBEDDING_MODEL=$embedding_model \\"
            echo "  -e VECTOR_DATABASE_PROVIDER=ChromaDB \\"
            echo "  -e CHROMA_HOST=localhost \\"
            echo "  -e CHROMA_PORT=8002 \\"
            echo "  -- npx @zilliz/claude-context-mcp@latest"
            ;;
        "qdrant")
            echo "=== Qdrant Configuration ==="
            echo "claude mcp add claude-context \\"
            echo "  -e EMBEDDING_PROVIDER=OpenRouter \\"
            echo "  -e OPENROUTER_API_KEY=$openrouter_key \\"
            echo "  -e EMBEDDING_MODEL=$embedding_model \\"
            echo "  -e VECTOR_DATABASE_PROVIDER=Qdrant \\"
            echo "  -e QDRANT_HOST=localhost \\"
            echo "  -e QDRANT_PORT=6333 \\"
            echo "  -- npx @zilliz/claude-context-mcp@latest"
            ;;
        "milvus")
            echo "=== Milvus Configuration ==="
            echo "claude mcp add claude-context \\"
            echo "  -e EMBEDDING_PROVIDER=OpenRouter \\"
            echo "  -e OPENROUTER_API_KEY=$openrouter_key \\"
            echo "  -e EMBEDDING_MODEL=$embedding_model \\"
            echo "  -e VECTOR_DATABASE_PROVIDER=Milvus \\"
            echo "  -e MILVUS_ADDRESS=localhost:19530 \\"
            echo "  -- npx @zilliz/claude-context-mcp@latest"
            ;;
    esac

    echo
    echo "=== Cursor Configuration ==="
    echo '{'
    echo '  "mcpServers": {'
    echo '    "claude-context": {'
    echo '      "command": "npx",'
    echo '      "args": ["-y", "@zilliz/claude-context-mcp@latest"],'
    echo '      "env": {'
    echo '        "EMBEDDING_PROVIDER": "OpenRouter",'
    echo '        "OPENROUTER_API_KEY": "'$openrouter_key'",'
    echo '        "EMBEDDING_MODEL": "'$embedding_model'",'
    echo '        "VECTOR_DATABASE_PROVIDER": "'$(echo $db_type | tr '[:lower:]' '[:upper:]')'",'

    case $db_type in
        "chromadb")
            echo '        "CHROMA_HOST": "localhost",'
            echo '        "CHROMA_PORT": "8002"'
            ;;
        "qdrant")
            echo '        "QDRANT_HOST": "localhost",'
            echo '        "QDRANT_PORT": "6333"'
            ;;
        "milvus")
            echo '        "MILVUS_ADDRESS": "localhost:19530"'
            ;;
    esac

    echo '      }'
    echo '    }'
    echo '  }'
    echo '}'
}

# Main function
main() {
    echo "Claude Context Vector Database Switcher"
    echo "======================================"
    echo

    # Check Docker
    check_docker

    # Get user input
    echo "Available vector databases:"
    echo "1. ChromaDB (lightweight, good for development)"
    echo "2. Qdrant (high performance, good for production)"
    echo "3. Milvus (enterprise grade, maximum scalability)"
    echo

    read -p "Choose vector database (1-3): " choice

    case $choice in
        1)
            DB_TYPE="chromadb"
            ;;
        2)
            DB_TYPE="qdrant"
            ;;
        3)
            DB_TYPE="milvus"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac

    # Get embedding model
    echo
    echo "Available embedding models:"
    echo "1. nomic-ai/nomic-embed-text-v1.5 (768 dims, latest)"
    echo "2. bge-large-en-v1.5 (1024 dims, best quality)"
    echo "3. bge-base-en-v1.5 (768 dims, balanced)"
    echo "4. bge-small-en-v1.5 (384 dims, fastest)"
    echo "5. voyage-code-3 (1536 dims, code-optimized)"
    echo

    read -p "Choose embedding model (1-5): " model_choice

    case $model_choice in
        1)
            EMBEDDING_MODEL="nomic-ai/nomic-embed-text-v1.5"
            ;;
        2)
            EMBEDDING_MODEL="bge-large-en-v1.5"
            ;;
        3)
            EMBEDDING_MODEL="bge-base-en-v1.5"
            ;;
        4)
            EMBEDDING_MODEL="bge-small-en-v1.5"
            ;;
        5)
            EMBEDDING_MODEL="voyage-code-3"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac

    # Get OpenRouter API key
    echo
    read -p "Enter your OpenRouter API key: " OPENROUTER_KEY

    if [[ -z "$OPENROUTER_KEY" ]]; then
        print_error "OpenRouter API key is required"
        exit 1
    fi

    # Stop all containers
    stop_all_containers

    # Start selected database
    case $DB_TYPE in
        "chromadb")
            if start_chromadb; then
                print_success "ChromaDB started successfully"
            else
                exit 1
            fi
            ;;
        "qdrant")
            if start_qdrant; then
                print_success "Qdrant started successfully"
            else
                exit 1
            fi
            ;;
        "milvus")
            if start_milvus; then
                print_success "Milvus started successfully"
            else
                exit 1
            fi
            ;;
    esac

    # Generate configuration
    echo
    print_success "Vector database setup completed!"
    echo
    generate_mcp_config "$DB_TYPE" "$EMBEDDING_MODEL" "$OPENROUTER_KEY"

    echo
    print_status "Next steps:"
    echo "1. Copy the configuration above to your MCP client"
    echo "2. Test the integration by indexing a codebase"
    echo "3. Monitor performance and adjust as needed"
}

# Help function
show_help() {
    echo "Claude Context Vector Database Switcher"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo
    echo "This script will:"
    echo "1. Stop all running vector database containers"
    echo "2. Start your selected vector database"
    echo "3. Generate MCP configuration"
    echo "4. Provide setup instructions"
}

# Version function
show_version() {
    echo "Claude Context Vector Database Switcher v1.0.0"
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
