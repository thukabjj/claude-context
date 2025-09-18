#!/bin/bash

# Claude Context Milvus Local Setup Script
# This script helps you set up Milvus locally with different deployment options

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

# Function to stop existing Milvus containers
stop_existing_milvus() {
    print_status "Stopping existing Milvus containers..."

    # Stop all Milvus-related containers
    docker stop claude-context-milvus-standalone 2>/dev/null || true
    docker stop claude-context-milvus-lite 2>/dev/null || true
    docker stop claude-context-milvus-full 2>/dev/null || true
    docker stop milvus-etcd 2>/dev/null || true
    docker stop milvus-minio 2>/dev/null || true

    # Remove containers
    docker rm claude-context-milvus-standalone 2>/dev/null || true
    docker rm claude-context-milvus-lite 2>/dev/null || true
    docker rm claude-context-milvus-full 2>/dev/null || true
    docker rm milvus-etcd 2>/dev/null || true
    docker rm milvus-minio 2>/dev/null || true

    print_success "Existing containers stopped"
}

# Function to setup Milvus Standalone
setup_milvus_standalone() {
    print_status "Setting up Milvus Standalone..."

    # Check ports
    if ! check_port 19530; then
        print_error "Port 19530 is in use. Please stop the service using this port."
        exit 1
    fi

    if ! check_port 9091; then
        print_error "Port 9091 is in use. Please stop the service using this port."
        exit 1
    fi

    # Create standalone configuration
    cat > docker-compose.milvus-standalone.yml << 'EOF'
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
    container_name: claude-context-milvus-standalone
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

    # Start Milvus standalone
    print_status "Starting Milvus Standalone..."
    docker-compose -f docker-compose.milvus-standalone.yml up -d

    # Wait for Milvus to be ready
    print_status "Waiting for Milvus to start (this may take a few minutes)..."
    sleep 60

    # Test connection
    if curl -f http://localhost:9091/healthz >/dev/null 2>&1; then
        print_success "Milvus Standalone is running on port 19530"
        return 0
    else
        print_error "Milvus Standalone failed to start"
        return 1
    fi
}

# Function to setup Milvus Lite
setup_milvus_lite() {
    print_status "Setting up Milvus Lite Mode..."

    # Check ports
    if ! check_port 19530; then
        print_error "Port 19530 is in use. Please stop the service using this port."
        exit 1
    fi

    if ! check_port 9091; then
        print_error "Port 9091 is in use. Please stop the service using this port."
        exit 1
    fi

    # Create lite configuration
    cat > docker-compose.milvus-lite.yml << 'EOF'
version: '3.8'

services:
  milvus-lite:
    container_name: claude-context-milvus-lite
    image: milvusdb/milvus:v2.3.0
    command: ["milvus", "run", "standalone", "--lite"]
    ports:
      - "19530:19530"
      - "9091:9091"
    volumes:
      - milvus_lite_data:/var/lib/milvus
    environment:
      - MILVUS_LITE=true
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9091/healthz"]
      interval: 30s
      start_period: 30s
      timeout: 20s
      retries: 3

volumes:
  milvus_lite_data:
EOF

    # Start Milvus lite
    print_status "Starting Milvus Lite Mode..."
    docker-compose -f docker-compose.milvus-lite.yml up -d

    # Wait for Milvus to be ready
    print_status "Waiting for Milvus Lite to start..."
    sleep 30

    # Test connection
    if curl -f http://localhost:9091/healthz >/dev/null 2>&1; then
        print_success "Milvus Lite is running on port 19530"
        return 0
    else
        print_error "Milvus Lite failed to start"
        return 1
    fi
}

# Function to setup Milvus Full
setup_milvus_full() {
    print_status "Setting up Milvus Full Mode..."

    # Check ports
    if ! check_port 19530; then
        print_error "Port 19530 is in use. Please stop the service using this port."
        exit 1
    fi

    if ! check_port 9091; then
        print_error "Port 9091 is in use. Please stop the service using this port."
        exit 1
    fi

    if ! check_port 2379; then
        print_error "Port 2379 is in use. Please stop the service using this port."
        exit 1
    fi

    if ! check_port 9000; then
        print_error "Port 9000 is in use. Please stop the service using this port."
        exit 1
    fi

    # Create full configuration
    cat > docker-compose.milvus-full.yml << 'EOF'
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
    container_name: claude-context-milvus-full
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

    # Start Milvus full
    print_status "Starting Milvus Full Mode..."
    docker-compose -f docker-compose.milvus-full.yml up -d

    # Wait for Milvus to be ready
    print_status "Waiting for Milvus Full to start (this may take a few minutes)..."
    sleep 90

    # Test connection
    if curl -f http://localhost:9091/healthz >/dev/null 2>&1; then
        print_success "Milvus Full is running on port 19530"
        return 0
    else
        print_error "Milvus Full failed to start"
        return 1
    fi
}

# Function to generate MCP configuration
generate_mcp_config() {
    local milvus_type=$1
    local embedding_model=$2
    local openrouter_key=$3

    print_status "Generating MCP configuration for Milvus $milvus_type..."

    echo "=== Milvus $milvus_type Configuration ==="
    echo "claude mcp add claude-context \\"
    echo "  -e EMBEDDING_PROVIDER=OpenRouter \\"
    echo "  -e OPENROUTER_API_KEY=$openrouter_key \\"
    echo "  -e EMBEDDING_MODEL=$embedding_model \\"
    echo "  -e VECTOR_DATABASE_PROVIDER=Milvus \\"
    echo "  -e MILVUS_ADDRESS=localhost:19530 \\"
    echo "  -- npx @zilliz/claude-context-mcp@latest"

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
    echo '        "VECTOR_DATABASE_PROVIDER": "Milvus",'
    echo '        "MILVUS_ADDRESS": "localhost:19530"'
    echo '      }'
    echo '    }'
    echo '  }'
    echo '}'
}

# Main function
main() {
    echo "Claude Context Milvus Local Setup"
    echo "=================================="
    echo

    # Check Docker
    check_docker

    # Get user input
    echo "Available Milvus deployment options:"
    echo "1. Milvus Standalone (recommended for development)"
    echo "2. Milvus Lite Mode (lightweight, resource-constrained)"
    echo "3. Milvus Full Mode (production-like with dependencies)"
    echo

    read -p "Choose Milvus deployment (1-3): " choice

    case $choice in
        1)
            MILVUS_TYPE="Standalone"
            ;;
        2)
            MILVUS_TYPE="Lite"
            ;;
        3)
            MILVUS_TYPE="Full"
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

    # Stop existing containers
    stop_existing_milvus

    # Setup selected Milvus type
    case $choice in
        1)
            if setup_milvus_standalone; then
                print_success "Milvus Standalone started successfully"
            else
                exit 1
            fi
            ;;
        2)
            if setup_milvus_lite; then
                print_success "Milvus Lite started successfully"
            else
                exit 1
            fi
            ;;
        3)
            if setup_milvus_full; then
                print_success "Milvus Full started successfully"
            else
                exit 1
            fi
            ;;
    esac

    # Generate configuration
    echo
    print_success "Milvus setup completed!"
    echo
    generate_mcp_config "$MILVUS_TYPE" "$EMBEDDING_MODEL" "$OPENROUTER_KEY"

    echo
    print_status "Next steps:"
    echo "1. Copy the configuration above to your MCP client"
    echo "2. Test the integration by indexing a codebase"
    echo "3. Monitor performance and adjust as needed"
    echo
    print_warning "Note: Milvus may take a few minutes to fully initialize"
    echo "Check status with: curl -f http://localhost:9091/healthz"
}

# Help function
show_help() {
    echo "Claude Context Milvus Local Setup Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo
    echo "This script will:"
    echo "1. Stop existing Milvus containers"
    echo "2. Start your selected Milvus deployment"
    echo "3. Generate MCP configuration"
    echo "4. Provide setup instructions"
}

# Version function
show_version() {
    echo "Claude Context Milvus Local Setup Script v1.0.0"
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
