# Frequently Asked Questions (FAQ)

## Q: What files does Claude Context decide to embed?

**A:** Claude Context uses a comprehensive rule system to determine which files to include in indexing:

**Simple Rule:**
```
Final Files = (All Supported Extensions) - (All Ignore Patterns)
```

- **Extensions are additive**: Default extensions + MCP custom + Environment variables
- **Ignore patterns are additive**: Default patterns + MCP custom + Environment variables + .gitignore + .xxxignore files + global .contextignore

**For detailed explanation see:** [File Inclusion Rules](../dive-deep/file-inclusion-rules.md)

## Q: Can I use a fully local deployment setup?

**A:** Yes, you can deploy Claude Context entirely on your local infrastructure with multiple options for both embedding providers and vector databases.

### Option 1: Fully Local (Ollama + ChromaDB)
This is the most private setup with everything running locally:

1. **Vector Database (ChromaDB)**: Use ChromaDB as a lightweight, local vector database:
   - `VECTOR_DATABASE_PROVIDER=ChromaDB`
   - `CHROMA_HOST=localhost`
   - `CHROMA_PORT=8000`

2. **Embedding Service (Ollama)**: Run [Ollama](https://ollama.com/) locally for embedding generation:
   - `EMBEDDING_PROVIDER=Ollama`
   - `OLLAMA_HOST=http://127.0.0.1:11434`
   - `EMBEDDING_MODEL=nomic-embed-text`

### Option 2: Open Source Models via OpenRouter + ChromaDB
Use open source models through OpenRouter API with local ChromaDB:

1. **Vector Database (ChromaDB)**: Same as above
2. **Embedding Service (OpenRouter)**: Access open source models via OpenRouter API:
   - `EMBEDDING_PROVIDER=OpenRouter`
   - `OPENROUTER_API_KEY=your-openrouter-api-key`
   - `EMBEDDING_MODEL=nomic-ai/nomic-embed-text-v1.5` (or other open source models)

### Option 3: Traditional Local (Ollama + Milvus)
Use Ollama with local Milvus deployment:

1. **Vector Database (Milvus)**: Deploy Milvus locally using Docker Compose by following the [official Milvus installation guide](https://milvus.io/docs/install_standalone-docker-compose.md):
   - `VECTOR_DATABASE_PROVIDER=Milvus`
   - `MILVUS_ADDRESS=127.0.0.1:19530`
   - `MILVUS_TOKEN=your-optional-token` (if authentication is enabled)

2. **Embedding Service (Ollama)**: Same as Option 1

### Quick Setup
We provide a setup script for the easiest local deployment (Option 1):
```bash
# Run the local setup script
./scripts/setup-local.sh
```

This will automatically start ChromaDB and Ollama containers and provide you with the exact configuration needed.

See our [environment variables guide](../getting-started/environment-variables.md) for detailed configuration options for all deployment scenarios.

## Q: Does it support multiple projects / codebases?

**A:** Yes, Claude Context fully supports multiple projects and codebases. In MCP mode, it automatically leverages the MCP client's AI Agent to detect and obtain the current codebase path where you're working.

You can seamlessly use queries like `index this codebase` or `search the main function` without specifying explicit paths. When you switch between different codebase working directories, Claude Context automatically discovers the change and adapts accordingly - no need to manually input specific codebase paths.

**Key features for multi-project support:**
- **Automatic Path Detection**: Leverages MCP client's workspace awareness to identify current working directory
- **Seamless Project Switching**: Automatically detects when you switch between different codebases
- **Background Code Synchronization**: Continuously monitors for changes and automatically re-indexes modified parts
- **Context-Aware Operations**: All indexing and search operations are scoped to the current project context

This makes it effortless to work across multiple projects while maintaining isolated, up-to-date indexes for each codebase.

## Q: How does Claude Context compare to other coding tools like Serena, Context7, or DeepWiki?

**A:** Claude Context is specifically focused on **codebase indexing and semantic search**. Here's how we compare:

- **[Serena](https://github.com/oraios/serena)**: A comprehensive coding agent toolkit with language server integration and symbolic code understanding. Provides broader AI coding capabilities.

- **[Context7](https://github.com/upstash/context7)**: Focuses on providing up-to-date documentation and code examples to prevent "code hallucination" in LLMs. Targets documentation accuracy.

- **[DeepWiki](https://docs.devin.ai/work-with-devin/deepwiki-mcp)**: Generates interactive documentation from GitHub repositories. Creates documentation from code.

**Our focus**: Making your entire codebase searchable and contextually available to AI assistants through efficient vector-based indexing and hybrid search.

