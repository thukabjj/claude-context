# Cloud Integration Guide for Claude Context

This guide explains how to integrate Claude Context with your cloud infrastructure for production deployments.

## 🎯 Cloud Integration Options

### Option 1: Hybrid Cloud (Recommended)
- **Embedding**: OpenRouter API (cloud)
- **Vector DB**: ChromaDB (your cloud infrastructure)
- **Benefits**: Cost-effective, scalable, good performance

### Option 2: Fully Managed Cloud
- **Embedding**: OpenAI API (cloud)
- **Vector DB**: Zilliz Cloud (managed)
- **Benefits**: Easiest setup, fully managed, high availability

### Option 3: Self-Hosted Cloud
- **Embedding**: Ollama (your cloud infrastructure)
- **Vector DB**: ChromaDB (your cloud infrastructure)
- **Benefits**: Complete control, no external dependencies

## 🚀 Quick Start: Hybrid Cloud Setup

### 1. Deploy ChromaDB on Your Cloud

**Using Docker Compose:**
```bash
# Deploy ChromaDB to your cloud server
docker-compose -f docker-compose.cloud.yml up -d chromadb
```

**Using Kubernetes:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chromadb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chromadb
  template:
    metadata:
      labels:
        app: chromadb
    spec:
      containers:
      - name: chromadb
        image: chromadb/chroma:latest
        ports:
        - containerPort: 8000
        env:
        - name: CHROMA_SERVER_HOST
          value: "0.0.0.0"
        - name: CHROMA_SERVER_HTTP_PORT
          value: "8000"
        volumeMounts:
        - name: chromadb-data
          mountPath: /chroma/chroma
      volumes:
      - name: chromadb-data
        persistentVolumeClaim:
          claimName: chromadb-pvc
```

### 2. Get OpenRouter API Key

1. Visit [OpenRouter](https://openrouter.ai/)
2. Sign up and get your API key
3. Add credits to your account

### 3. Configure MCP Client

**For Claude Code:**
```bash
claude mcp add claude-context \
  -e EMBEDDING_PROVIDER=OpenRouter \
  -e OPENROUTER_API_KEY=sk-or-your-openrouter-api-key \
  -e EMBEDDING_MODEL=nomic-ai/nomic-embed-text-v1.5 \
  -e VECTOR_DATABASE_PROVIDER=ChromaDB \
  -e CHROMA_HOST=your-cloud-server-ip \
  -e CHROMA_PORT=8000 \
  -- npx @zilliz/claude-context-mcp@latest
```

**For Cursor:**
```json
{
  "mcpServers": {
    "claude-context": {
      "command": "npx",
      "args": ["-y", "@zilliz/claude-context-mcp@latest"],
      "env": {
        "EMBEDDING_PROVIDER": "OpenRouter",
        "OPENROUTER_API_KEY": "sk-or-your-openrouter-api-key",
        "EMBEDDING_MODEL": "nomic-ai/nomic-embed-text-v1.5",
        "VECTOR_DATABASE_PROVIDER": "ChromaDB",
        "CHROMA_HOST": "your-cloud-server-ip",
        "CHROMA_PORT": "8000"
      }
    }
  }
}
```

## ☁️ Cloud Provider Specific Guides

### AWS Integration

**Using ECS:**
```bash
# Deploy ChromaDB on ECS
aws ecs create-cluster --cluster-name claude-context
aws ecs register-task-definition --cli-input-json file://chromadb-task-definition.json
aws ecs create-service --cluster claude-context --service-name chromadb --task-definition chromadb
```

**Using EC2:**
```bash
# Launch EC2 instance
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --instance-type t3.medium \
  --key-name your-key-pair \
  --security-group-ids sg-12345678

# Install Docker and deploy
ssh -i your-key.pem ec2-user@your-instance-ip
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user
```

### Azure Integration

**Using Azure Container Instances:**
```bash
# Deploy ChromaDB on Azure
az container create \
  --resource-group myResourceGroup \
  --name chromadb \
  --image chromadb/chroma:latest \
  --ports 8000 \
  --environment-variables CHROMA_SERVER_HOST=0.0.0.0 CHROMA_SERVER_HTTP_PORT=8000
```

### Google Cloud Integration

**Using Cloud Run:**
```bash
# Deploy ChromaDB on Cloud Run
gcloud run deploy chromadb \
  --image chromadb/chroma:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --port 8000
```

## 🔧 Production Considerations

### Security
- Use HTTPS for all communications
- Implement authentication for ChromaDB
- Use environment variables for secrets
- Set up proper firewall rules

### Scaling
- Use load balancers for multiple ChromaDB instances
- Implement connection pooling
- Monitor resource usage
- Set up auto-scaling

### Monitoring
- Set up health checks
- Monitor API usage and costs
- Log all operations
- Set up alerts for failures

### Backup
- Regular ChromaDB data backups
- Version control for configurations
- Disaster recovery plans

## 📊 Cost Optimization

### OpenRouter vs OpenAI
- OpenRouter: ~$0.0001 per 1K tokens
- OpenAI: ~$0.0001 per 1K tokens (text-embedding-3-small)
- **Savings**: OpenRouter often 50-70% cheaper

### ChromaDB vs Zilliz Cloud
- ChromaDB (self-hosted): Infrastructure costs only
- Zilliz Cloud: $0.10 per 1M vectors/month
- **Break-even**: ~1M vectors for self-hosted to be cheaper

## 🚀 Deployment Scripts

### Automated Cloud Deployment
```bash
#!/bin/bash
# deploy-cloud.sh

# Set your cloud server details
CLOUD_HOST="your-cloud-server-ip"
CLOUD_USER="your-username"
OPENROUTER_API_KEY="sk-or-your-openrouter-api-key"

# Deploy ChromaDB
ssh $CLOUD_USER@$CLOUD_HOST "docker run -d --name chromadb -p 8000:8000 chromadb/chroma:latest"

# Wait for ChromaDB to be ready
sleep 30

# Test connection
curl -f http://$CLOUD_HOST:8000/api/v1/heartbeat || exit 1

echo "✅ ChromaDB deployed successfully!"
echo "Configure your MCP client with:"
echo "CHROMA_HOST=$CLOUD_HOST"
echo "CHROMA_PORT=8000"
echo "OPENROUTER_API_KEY=$OPENROUTER_API_KEY"
```

## 🔍 Troubleshooting

### Common Issues
1. **Connection refused**: Check firewall rules and port accessibility
2. **Authentication errors**: Verify API keys and permissions
3. **Performance issues**: Monitor resource usage and scale accordingly
4. **Data persistence**: Ensure proper volume mounts for ChromaDB

### Health Checks
```bash
# Check ChromaDB health
curl -f http://your-cloud-server:8000/api/v1/heartbeat

# Check OpenRouter API
curl -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  https://openrouter.ai/api/v1/models
```

## 📚 Next Steps

1. Choose your preferred cloud integration option
2. Deploy the necessary infrastructure
3. Configure your MCP client
4. Test the integration
5. Set up monitoring and backup procedures

For more detailed information, see the [main documentation](../README.md) and [environment variables guide](docs/getting-started/environment-variables.md).
