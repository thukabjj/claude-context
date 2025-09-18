#!/usr/bin/env node

const { ChromaDBVectorDatabase } = require('./packages/core/dist/vectordb/chromadb-vectordb');
const { OllamaEmbedding } = require('./packages/core/dist/embedding/ollama-embedding');

async function testLocalDeployment() {
    console.log('🧪 Testing Local Deployment (Fixed)...\n');

    try {
        // Test embedding with dimension provided
        console.log('1. Testing Ollama Embedding...');
        const embedding = new OllamaEmbedding({
            baseUrl: 'http://localhost:11434',
            model: 'nomic-embed-text',
            dimension: 768  // Provide dimension directly
        });

        const testText = 'Hello, this is a test of the local deployment!';
        const embeddingResult = await embedding.embed(testText);
        console.log(`✅ Embedding successful! Vector dimension: ${embeddingResult.vector.length}`);
        console.log(`   First few values: [${embeddingResult.vector.slice(0, 5).join(', ')}...]\n`);

        // Test vector database
        console.log('2. Testing ChromaDB Vector Database...');
        const vectorDb = new ChromaDBVectorDatabase({
            host: 'localhost',
            port: 8002,
            path: '/chroma/chroma',
            ssl: false
        });

        // Create a test collection
        const collectionName = 'test-collection';
        await vectorDb.createCollection(collectionName);
        console.log(`✅ Collection '${collectionName}' created successfully!`);

        // Insert a test document
        const testDocument = {
            id: 'test-1',
            content: testText,
            metadata: { source: 'test', timestamp: new Date().toISOString() },
            vector: embeddingResult.vector
        };

        await vectorDb.insert(collectionName, [testDocument]);
        console.log('✅ Document inserted successfully!');

        // Search for the document
        const searchResults = await vectorDb.search(collectionName, embeddingResult.vector, {
            limit: 5,
            includeMetadata: true,
            includeDocuments: true
        });

        console.log(`✅ Search successful! Found ${searchResults.length} results`);
        if (searchResults.length > 0) {
            console.log(`   Top result score: ${searchResults[0].score}`);
            console.log(`   Top result content: "${searchResults[0].document?.content}"`);
        }

        // Clean up
        await vectorDb.delete(collectionName, ['test-1']);
        console.log('✅ Test document deleted successfully!');

        console.log('\n🎉 All tests passed! Local deployment is working correctly.');
        console.log('\n📋 Summary:');
        console.log('   ✅ Ollama embedding service is working');
        console.log('   ✅ ChromaDB vector database is working');
        console.log('   ✅ Document insertion and retrieval is working');
        console.log('   ✅ Vector similarity search is working');

    } catch (error) {
        console.error('❌ Test failed:', error.message);
        console.error('Stack trace:', error.stack);
        process.exit(1);
    }
}

testLocalDeployment();
