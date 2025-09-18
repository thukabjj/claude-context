import { Embedding, EmbeddingVector } from './base-embedding';

export interface OpenRouterEmbeddingConfig {
    apiKey: string;
    baseUrl?: string;
    model: string;
}

export class OpenRouterEmbedding extends Embedding {
    private config: OpenRouterEmbeddingConfig;
    protected maxTokens = 8192; // OpenRouter models typically support 8k tokens

    constructor(config: OpenRouterEmbeddingConfig) {
        super();
        this.config = config;
    }

    async embed(text: string): Promise<EmbeddingVector> {
        const embeddings = await this.embedBatch([text]);
        return embeddings[0];
    }

    async embedBatch(texts: string[]): Promise<EmbeddingVector[]> {
        const processedTexts = this.preprocessTexts(texts);
        const baseUrl = this.config.baseUrl || 'https://openrouter.ai/api/v1';
        
        const response = await fetch(`${baseUrl}/embeddings`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${this.config.apiKey}`,
                'Content-Type': 'application/json',
                'HTTP-Referer': 'https://github.com/zilliztech/claude-context',
                'X-Title': 'Claude Context'
            },
            body: JSON.stringify({
                model: this.config.model,
                input: processedTexts
            })
        });

        if (!response.ok) {
            throw new Error(`OpenRouter API error: ${response.status} ${response.statusText}`);
        }

        const data = await response.json() as any;
        return data.data.map((item: any) => ({
            vector: item.embedding,
            dimension: item.embedding.length
        }));
    }

    async detectDimension(testText?: string): Promise<number> {
        return this.getDimension();
    }

    getDimension(): number {
        // Common dimensions for popular embedding models
        const modelDimensions: Record<string, number> = {
            'nomic-ai/nomic-embed-text-v1.5': 768,
            'nomic-ai/nomic-embed-text-v1': 768,
            'text-embedding-3-small': 1536,
            'text-embedding-3-large': 3072,
            'text-embedding-ada-002': 1536,
            'voyage-01': 1024,
            'voyage-code-2': 1536,
            'voyage-code-3': 1536,
            'gte-large': 1024,
            'gte-base': 768,
            'gte-small': 384,
            'bge-large-en-v1.5': 1024,
            'bge-base-en-v1.5': 768,
            'bge-small-en-v1.5': 384,
            'mxbai-embed-large': 1024,
            'mxbai-embed-base': 768
        };

        return modelDimensions[this.config.model] || 1536; // Default to 1536
    }

    getProvider(): string {
        return 'OpenRouter';
    }

    static getSupportedModels(): string[] {
        return [
            'nomic-ai/nomic-embed-text-v1.5',
            'nomic-ai/nomic-embed-text-v1',
            'text-embedding-3-small',
            'text-embedding-3-large',
            'text-embedding-ada-002',
            'voyage-01',
            'voyage-code-2',
            'voyage-code-3',
            'gte-large',
            'gte-base',
            'gte-small',
            'bge-large-en-v1.5',
            'bge-base-en-v1.5',
            'bge-small-en-v1.5',
            'mxbai-embed-large',
            'mxbai-embed-base'
        ];
    }
}
