# Milvus Local Deployment Options for Claude Context

This guide provides multiple ways to run Milvus locally in your current setup, from simple standalone to full cluster deployment.

## 🎯 Milvus Local Deployment Options

### **Option 1: Milvus Standalone (Recommended for Development)**

**Best for:** Development, testing, small to medium datasets
**Resource Requirements:** 4GB RAM, 2GB disk space
**Setup Time:** 5-10 minutes

#### **Quick Setup with Docker Compose**

```bash
# Create Milvus standalone configuration
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
docker-compose -f docker-compose.milvus-standalone.yml up -d
```

#### **Configuration for Claude Context**

```bash
# For Claude Code
claude mcp add claude-context \
  -e EMBEDDING_PROVIDER=OpenRouter \
  -e OPENROUTER_API_KEY=sk-or-your-openrouter-api-key \
  -e EMBEDDING_MODEL=nomic-ai/nomic-embed-text-v1.5 \
  -e VECTOR_DATABASE_PROVIDER=Milvus \
  -e MILVUS_ADDRESS=localhost:19530 \
  -- npx @zilliz/claude-context-mcp@latest
```

### **Option 2: Milvus with Lite Mode (Lightweight)**

**Best for:** Resource-constrained environments
**Resource Requirements:** 2GB RAM, 1GB disk space
**Setup Time:** 3-5 minutes

#### **Lite Mode Setup**

```bash
# Create Milvus lite configuration
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
docker-compose -f docker-compose.milvus-lite.yml up -d
```

### **Option 3: Milvus with External Dependencies (Production-like)**

**Best for:** Production testing, larger datasets
**Resource Requirements:** 8GB RAM, 5GB disk space
**Setup Time:** 10-15 minutes

#### **Full Milvus Setup**

```bash
# Create full Milvus configuration
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
      MILVUS_CONFIG_PATH: /milvus/configs/milvus.yaml
    volumes:
      - milvus_data:/var/lib/milvus
      - ./milvus-config.yaml:/milvus/configs/milvus.yaml
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

# Start full Milvus
docker-compose -f docker-compose.milvus-full.yml up -d
```

### **Option 4: Milvus with Custom Configuration**

**Best for:** Advanced users who need specific configurations
**Resource Requirements:** Variable
**Setup Time:** 15-30 minutes

#### **Custom Configuration Setup**

```bash
# Create custom Milvus configuration
cat > milvus-config.yaml << 'EOF'
# Milvus Configuration for Claude Context

# Server configuration
server:
  address: 0.0.0.0
  port: 19530

# Log configuration
log:
  level: info
  file:
    rootPath: /var/lib/milvus/logs

# Storage configuration
storage:
  path: /var/lib/milvus/data

# Index configuration
index:
  type: IVF_FLAT
  metric_type: L2
  params:
    nlist: 1024

# Query configuration
query:
  node:
    loadMemoryUsageFactor: 1
    enableDisk: true
    diskCapacityLimit: 2147483648  # 2GB

# Data node configuration
dataNode:
  enableDisk: true
  diskCapacityLimit: 2147483648  # 2GB
EOF

# Start with custom configuration
docker-compose -f docker-compose.milvus-full.yml up -d
```

## 🚀 Quick Start Script

I've created an interactive script to help you choose the best Milvus option:

```bash
# Run the interactive Milvus setup
./scripts/switch-vector-db.sh

# Or use the dedicated Milvus setup script
./scripts/setup-milvus.sh
```

## 📊 Comparison of Milvus Options

| Option | RAM Usage | Disk Usage | Setup Time | Best For |
|--------|-----------|------------|------------|----------|
| **Standalone** | 4GB | 2GB | 5-10 min | Development |
| **Lite Mode** | 2GB | 1GB | 3-5 min | Resource-constrained |
| **Full Setup** | 8GB | 5GB | 10-15 min | Production testing |
| **Custom Config** | Variable | Variable | 15-30 min | Advanced users |

## 🔧 Environment Variables for Milvus

### **Basic Configuration**
```bash
VECTOR_DATABASE_PROVIDER=Milvus
MILVUS_ADDRESS=localhost:19530
```

### **With Authentication**
```bash
VECTOR_DATABASE_PROVIDER=Milvus
MILVUS_ADDRESS=localhost:19530
MILVUS_TOKEN=your-milvus-token
```

### **With Custom Settings**
```bash
VECTOR_DATABASE_PROVIDER=Milvus
MILVUS_ADDRESS=localhost:19530
MILVUS_DB_NAME=claude_context
MILVUS_COLLECTION_NAME=codebase_vectors
```

## 🐳 Docker Commands

### **Start Milvus**
```bash
# Standalone
docker-compose -f docker-compose.milvus-standalone.yml up -d

# Lite mode
docker-compose -f docker-compose.milvus-lite.yml up -d

# Full setup
docker-compose -f docker-compose.milvus-full.yml up -d
```

### **Stop Milvus**
```bash
# Stop all Milvus containers
docker-compose -f docker-compose.milvus-standalone.yml down
docker-compose -f docker-compose.milvus-lite.yml down
docker-compose -f docker-compose.milvus-full.yml down
```

### **Check Status**
```bash
# Check if Milvus is running
curl -f http://localhost:9091/healthz

# Check logs
docker logs claude-context-milvus-standalone
```

## 🔍 Health Checks

### **Milvus Health Check**
```bash
# Check Milvus health
curl -f http://localhost:9091/healthz

# Check Milvus metrics
curl http://localhost:9091/metrics
```

### **Dependencies Health Check**
```bash
# Check etcd (for full setup)
docker exec milvus-etcd etcdctl endpoint health

# Check MinIO (for full setup)
curl -f http://localhost:9000/minio/health/live
```

## 🛠️ Troubleshooting

### **Common Issues**

1. **Port conflicts**
   ```bash
   # Check if ports are in use
   lsof -i :19530
   lsof -i :9091
   ```

2. **Memory issues**
   ```bash
   # Check Docker memory usage
   docker stats
   ```

3. **Storage issues**
   ```bash
   # Check Docker volumes
   docker volume ls
   docker volume inspect milvus_data
   ```

### **Reset Milvus**
```bash
# Stop and remove all containers
docker-compose -f docker-compose.milvus-standalone.yml down -v

# Remove volumes
docker volume rm milvus_etcd_data milvus_minio_data milvus_data

# Start fresh
docker-compose -f docker-compose.milvus-standalone.yml up -d
```

## 🎯 Recommendations

### **For Development:**
- **Use Milvus Standalone** - Best balance of features and simplicity
- **Resource Requirements:** 4GB RAM, 2GB disk
- **Setup Time:** 5-10 minutes

### **For Resource-Constrained Environments:**
- **Use Milvus Lite Mode** - Minimal resource usage
- **Resource Requirements:** 2GB RAM, 1GB disk
- **Setup Time:** 3-5 minutes

### **For Production Testing:**
- **Use Full Milvus Setup** - Production-like environment
- **Resource Requirements:** 8GB RAM, 5GB disk
- **Setup Time:** 10-15 minutes

### **For Advanced Users:**
- **Use Custom Configuration** - Full control over settings
- **Resource Requirements:** Variable
- **Setup Time:** 15-30 minutes

## 🚀 Next Steps

1. **Choose your Milvus option** based on your needs
2. **Run the setup script** or use Docker Compose directly
3. **Configure Claude Context** with Milvus settings
4. **Test the integration** by indexing a codebase
5. **Monitor performance** and adjust as needed

## 📚 Additional Resources

- [Milvus Documentation](https://milvus.io/docs)
- [Milvus Docker Guide](https://milvus.io/docs/install_standalone-docker-compose.md)
- [Milvus Configuration Reference](https://milvus.io/docs/configure-docker.md)
- [Milvus Troubleshooting](https://milvus.io/docs/troubleshoot.md)
