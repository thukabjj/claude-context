#!/usr/bin/env node

const { Ollama } = require('ollama');

async function testSimple() {
    console.log('🧪 Testing Simple Ollama API...\n');

    try {
        const client = new Ollama({
            host: 'http://localhost:11434'
        });

        console.log('1. Testing direct Ollama API...');
        const response = await client.embed({
            model: 'nomic-embed-text',
            input: 'Hello, this is a test!'
        });

        console.log(`✅ Embedding successful! Vector dimension: ${response.embeddings[0].length}`);
        console.log(`   First few values: [${response.embeddings[0].slice(0, 5).join(', ')}...]\n`);

        console.log('🎉 Simple test passed! Ollama API is working correctly.');

    } catch (error) {
        console.error('❌ Test failed:', error.message);
        console.error('Stack trace:', error.stack);
        process.exit(1);
    }
}

testSimple();
