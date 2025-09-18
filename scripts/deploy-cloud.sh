#!/bin/bash

# Claude Context Cloud Deployment Script
# This script helps you deploy Claude Context to your cloud infrastructure

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to test connection
test_connection() {
    local host=$1
    local port=$2
    local timeout=${3:-10}

    if timeout $timeout bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Main deployment function
deploy_cloud() {
    print_status "Starting Claude Context Cloud Deployment"

    # Get user input
    echo
    read -p "Enter your cloud server IP address: " CLOUD_HOST
    if ! validate_ip "$CLOUD_HOST"; then
        print_error "Invalid IP address format"
        exit 1
    fi

    read -p "Enter your cloud server username (default: root): " CLOUD_USER
    CLOUD_USER=${CLOUD_USER:-root}

    read -p "Enter your OpenRouter API key: " OPENROUTER_API_KEY
    if [[ -z "$OPENROUTER_API_KEY" ]]; then
        print_error "OpenRouter API key is required"
        exit 1
    fi

    read -p "Enter ChromaDB port (default: 8000): " CHROMA_PORT
    CHROMA_PORT=${CHROMA_PORT:-8000}

    # Test connection to cloud server
    print_status "Testing connection to cloud server..."
    if ! test_connection "$CLOUD_HOST" 22; then
        print_error "Cannot connect to $CLOUD_HOST on port 22"
        print_warning "Make sure SSH is enabled and firewall allows connections"
        exit 1
    fi
    print_success "Connection to cloud server successful"

    # Check if Docker is installed on remote server
    print_status "Checking Docker installation on remote server..."
    if ! ssh "$CLOUD_USER@$CLOUD_HOST" "command -v docker" >/dev/null 2>&1; then
        print_warning "Docker not found on remote server"
        print_status "Installing Docker..."
        ssh "$CLOUD_USER@$CLOUD_HOST" << 'EOF'
            # Install Docker
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            systemctl start docker
            systemctl enable docker
            usermod -aG docker $USER
EOF
        print_success "Docker installed successfully"
    else
        print_success "Docker is already installed"
    fi

    # Deploy ChromaDB
    print_status "Deploying ChromaDB on cloud server..."
    ssh "$CLOUD_USER@$CLOUD_HOST" << EOF
        # Stop existing ChromaDB container if running
        docker stop claude-context-chromadb-cloud 2>/dev/null || true
        docker rm claude-context-chromadb-cloud 2>/dev/null || true

        # Start ChromaDB container
        docker run -d \
            --name claude-context-chromadb-cloud \
            --restart unless-stopped \
            -p $CHROMA_PORT:8000 \
            -v chromadb_data:/chroma/chroma \
            -e CHROMA_SERVER_HOST=0.0.0.0 \
            -e CHROMA_SERVER_HTTP_PORT=8000 \
            -e CHROMA_SERVER_CORS_ALLOW_ORIGINS='["*"]' \
            chromadb/chroma:latest
EOF

    # Wait for ChromaDB to be ready
    print_status "Waiting for ChromaDB to start..."
    sleep 30

    # Test ChromaDB connection
    print_status "Testing ChromaDB connection..."
    if test_connection "$CLOUD_HOST" "$CHROMA_PORT" 30; then
        print_success "ChromaDB is running and accessible"
    else
        print_error "ChromaDB is not responding"
        print_warning "Check the logs: ssh $CLOUD_USER@$CLOUD_HOST 'docker logs claude-context-chromadb-cloud'"
        exit 1
    fi

    # Test OpenRouter API
    print_status "Testing OpenRouter API connection..."
    if curl -s -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        "https://openrouter.ai/api/v1/models" >/dev/null; then
        print_success "OpenRouter API is accessible"
    else
        print_warning "OpenRouter API test failed - please verify your API key"
    fi

    # Generate configuration
    print_success "Deployment completed successfully!"
    echo
    print_status "Your Claude Context cloud configuration:"
    echo
    echo "=== For Claude Code ==="
    echo "claude mcp add claude-context \\"
    echo "  -e EMBEDDING_PROVIDER=OpenRouter \\"
    echo "  -e OPENROUTER_API_KEY=$OPENROUTER_API_KEY \\"
    echo "  -e EMBEDDING_MODEL=nomic-ai/nomic-embed-text-v1.5 \\"
    echo "  -e VECTOR_DATABASE_PROVIDER=ChromaDB \\"
    echo "  -e CHROMA_HOST=$CLOUD_HOST \\"
    echo "  -e CHROMA_PORT=$CHROMA_PORT \\"
    echo "  -- npx @zilliz/claude-context-mcp@latest"
    echo
    echo "=== For Cursor ==="
    echo '{'
    echo '  "mcpServers": {'
    echo '    "claude-context": {'
    echo '      "command": "npx",'
    echo '      "args": ["-y", "@zilliz/claude-context-mcp@latest"],'
    echo '      "env": {'
    echo '        "EMBEDDING_PROVIDER": "OpenRouter",'
    echo '        "OPENROUTER_API_KEY": "'$OPENROUTER_API_KEY'",'
    echo '        "EMBEDDING_MODEL": "nomic-ai/nomic-embed-text-v1.5",'
    echo '        "VECTOR_DATABASE_PROVIDER": "ChromaDB",'
    echo '        "CHROMA_HOST": "'$CLOUD_HOST'",'
    echo '        "CHROMA_PORT": "'$CHROMA_PORT'"'
    echo '      }'
    echo '    }'
    echo '  }'
    echo '}'
    echo
    print_status "Next steps:"
    echo "1. Copy the configuration above to your MCP client"
    echo "2. Test the integration by indexing a codebase"
    echo "3. Monitor your OpenRouter usage and costs"
    echo
    print_warning "Security reminder:"
    echo "- Ensure your cloud server has proper firewall rules"
    echo "- Consider using HTTPS for production deployments"
    echo "- Regularly backup your ChromaDB data"
}

# Help function
show_help() {
    echo "Claude Context Cloud Deployment Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo
    echo "This script will:"
    echo "1. Connect to your cloud server"
    echo "2. Install Docker if needed"
    echo "3. Deploy ChromaDB container"
    echo "4. Test the connection"
    echo "5. Generate MCP configuration"
    echo
    echo "Prerequisites:"
    echo "- SSH access to your cloud server"
    echo "- OpenRouter API key"
    echo "- Cloud server with at least 2GB RAM"
}

# Version function
show_version() {
    echo "Claude Context Cloud Deployment Script v1.0.0"
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
        deploy_cloud
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
