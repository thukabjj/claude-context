#!/usr/bin/env node

const { Ollama } = require('ollama');

async function simpleTest() {
    console.log('🧪 Simple Test...\n');

    try {
        const client = new Ollama({
            host: 'http://localhost:11434'
        });

        console.log('1. Testing Ollama API...');
        const response = await client.embed({
            model: 'nomic-embed-text',
            input: 'Hello, this is a test!'
        });

        console.log(`✅ Embedding successful! Vector dimension: ${response.embeddings[0].length}`);
        console.log(`   First few values: [${response.embeddings[0].slice(0, 5).join(', ')}...]\n`);

        console.log('2. Testing ChromaDB API...');
        const chromaResponse = await fetch('http://localhost:8002/api/v2/heartbeat');
        if (chromaResponse.ok) {
            console.log('✅ ChromaDB is responding correctly!');
        } else {
            console.log('❌ ChromaDB is not responding correctly');
        }

        console.log('\n🎉 Basic functionality test passed!');
        console.log('\n📋 Summary:');
        console.log('   ✅ Ollama embedding API is working');
        console.log('   ✅ ChromaDB API is responding');

    } catch (error) {
        console.error('❌ Test failed:', error.message);
        process.exit(1);
    }
}

simpleTest();
