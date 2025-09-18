import { ChromaClient, Collection, IncludeEnum } from 'chromadb';
import { HybridSearchOptions, HybridSearchRequest, HybridSearchResult, SearchOptions, VectorDatabase, VectorDocument, VectorSearchResult } from './types';

export interface ChromaDBConfig {
    host?: string;
    port?: number;
    path?: string;
    ssl?: boolean;
}

export class ChromaDBVectorDatabase implements VectorDatabase {
    private client: ChromaClient;
    private collections: Map<string, Collection> = new Map();

    constructor(config: ChromaDBConfig = {}) {
        const { host = 'localhost', port = 8000, path = '', ssl = false } = config;

        this.client = new ChromaClient({
            path: ssl ? `https://${host}:${port}${path}` : `http://${host}:${port}${path}`
        });
    }

    async createCollection(collectionName: string, dimension: number, description?: string): Promise<void> {
        try {
            const collection = await this.client.createCollection({
                name: collectionName,
                metadata: {
                    description: description || `Collection for ${collectionName}`,
                    dimension: dimension.toString()
                }
            });
            this.collections.set(collectionName, collection);
        } catch (error: any) {
            if (error.message?.includes('already exists')) {
                // Collection already exists, get it using getOrCreateCollection
                const collection = await this.client.getOrCreateCollection({ name: collectionName });
                this.collections.set(collectionName, collection);
            } else {
                throw error;
            }
        }
    }

    async createHybridCollection(collectionName: string, dimension: number, description?: string): Promise<void> {
        await this.createCollection(collectionName, dimension, description);
    }

    async dropCollection(collectionName: string): Promise<void> {
        try {
            await this.client.deleteCollection({ name: collectionName });
            this.collections.delete(collectionName);
        } catch (error: any) {
            if (!error.message?.includes('not found')) {
                throw error;
            }
        }
    }

    async hasCollection(collectionName: string): Promise<boolean> {
        try {
            await this.client.getOrCreateCollection({ name: collectionName });
            return true;
        } catch {
            return false;
        }
    }

    async listCollections(): Promise<string[]> {
        const collections = await this.client.listCollections();
        return collections.map(col => (col as any).name || col);
    }

    async insert(collectionName: string, documents: VectorDocument[]): Promise<void> {
        const collection = await this.getOrCreateCollection(collectionName);

        const ids = documents.map(doc => doc.id);
        const embeddings = documents.map(doc => doc.vector);
        const metadatas = documents.map(doc => ({
            content: doc.content,
            relativePath: doc.relativePath,
            startLine: doc.startLine.toString(),
            endLine: doc.endLine.toString(),
            fileExtension: doc.fileExtension,
            ...doc.metadata
        }));
        const documents_text = documents.map(doc => doc.content);

        await collection.add({
            ids,
            embeddings,
            metadatas,
            documents: documents_text
        });
    }

    async insertHybrid(collectionName: string, documents: VectorDocument[]): Promise<void> {
        await this.insert(collectionName, documents);
    }

    async search(collectionName: string, queryVector: number[], options: SearchOptions = {}): Promise<VectorSearchResult[]> {
        const collection = await this.getOrCreateCollection(collectionName);

        const results = await collection.query({
            queryEmbeddings: [queryVector],
            nResults: options.topK || 10,
            where: this.buildWhereClause(options.filter),
            include: [IncludeEnum.Metadatas, IncludeEnum.Documents, IncludeEnum.Distances]
        });

        if (!results.metadatas || !results.documents || !results.distances) {
            return [];
        }

        return results.metadatas[0].map((metadata: any, index: number) => ({
            document: {
                id: results.ids?.[0]?.[index] || '',
                vector: queryVector,
                content: results.documents?.[0]?.[index] || '',
                relativePath: metadata.relativePath || '',
                startLine: parseInt(metadata.startLine) || 0,
                endLine: parseInt(metadata.endLine) || 0,
                fileExtension: metadata.fileExtension || '',
                metadata: { ...metadata }
            },
            score: 1 - (results.distances?.[0]?.[index] || 0)
        }));
    }

    async hybridSearch(collectionName: string, searchRequests: HybridSearchRequest[], options: HybridSearchOptions = {}): Promise<HybridSearchResult[]> {
        const denseRequest = searchRequests.find(req => req.anns_field === 'vector');
        if (!denseRequest) {
            throw new Error('Dense vector search request is required for hybrid search');
        }

        const denseResults = await this.search(collectionName, denseRequest.data as number[], {
            topK: options.limit || denseRequest.limit,
            filter: undefined
        });

        return denseResults.map(result => ({
            document: result.document,
            score: result.score
        }));
    }

    async delete(collectionName: string, ids: string[]): Promise<void> {
        const collection = await this.getOrCreateCollection(collectionName);
        await collection.delete({ ids });
    }

    async query(collectionName: string, filter: string, outputFields: string[], limit?: number): Promise<Record<string, any>[]> {
        const collection = await this.getOrCreateCollection(collectionName);

        const results = await collection.get({
            where: this.parseFilterExpression(filter),
            limit: limit || 100,
            include: [IncludeEnum.Metadatas, IncludeEnum.Documents]
        });

        if (!results.metadatas || !results.documents) {
            return [];
        }

        return results.metadatas.map((metadata: any, index: number) => ({
            id: results.ids?.[index] || '',
            content: results.documents?.[index] || '',
            ...metadata
        }));
    }

    async checkCollectionLimit(): Promise<boolean> {
        return true;
    }

    private async getOrCreateCollection(collectionName: string): Promise<Collection> {
        if (this.collections.has(collectionName)) {
            return this.collections.get(collectionName)!;
        }

        try {
            const collection = await this.client.getOrCreateCollection({ name: collectionName });
            this.collections.set(collectionName, collection);
            return collection;
        } catch {
            await this.createCollection(collectionName, 1536);
            return this.collections.get(collectionName)!;
        }
    }

    private buildWhereClause(filter?: Record<string, any>): Record<string, any> | undefined {
        if (!filter) return undefined;

        const whereClause: Record<string, any> = {};
        for (const [key, value] of Object.entries(filter)) {
            whereClause[key] = { $eq: value };
        }
        return whereClause;
    }

    private parseFilterExpression(filter: string): Record<string, any> | undefined {
        try {
            return JSON.parse(filter);
        } catch {
            const parts = filter.split('=');
            if (parts.length === 2) {
                return { [parts[0].trim()]: { $eq: parts[1].trim() } };
            }
            return undefined;
        }
    }
}
