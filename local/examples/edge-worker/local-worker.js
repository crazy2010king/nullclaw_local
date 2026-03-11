const Fastify = require('fastify')({ logger: true });
const fs = require('fs');
const { WASI } = require('wasi');
const path = require('path');
const sqlite3 = require('better-sqlite3');

// Initialize SQLite KV store (replaces Cloudflare KV)
const db = sqlite3('./data/kv.db');
db.exec(`
  CREATE TABLE IF NOT EXISTS kv (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    expires_at INTEGER
  )
`);

// Load WASM core
let wasmInstance;
async function loadWasm() {
  const wasmBuffer = fs.readFileSync('./agent_core.wasm');
  const wasi = new WASI({
    args: process.argv,
    env: process.env,
    preopens: {
      '/tmp': '/tmp'
    }
  });

  const { instance } = await WebAssembly.instantiate(wasmBuffer, {
    wasi_snapshot_preview1: wasi.wasiImport
  });

  wasi.start(instance);
  wasmInstance = instance.exports;
  Fastify.log.info('WASM core loaded successfully');
}

// Text feature extraction (runs on host, sends features to WASM)
function extractFeatures(text) {
  return {
    text_len: text.length,
    has_question: text.includes('?') ? 1 : 0,
    has_urgent_keyword: /紧急|urgent|asap|立刻|马上/i.test(text) ? 1 : 0,
    has_code_hint: /```|`|code|代码|错误|error/i.test(text) ? 1 : 0
  };
}

// Policy engine
function getResponsePolicy(text) {
  const features = extractFeatures(text);
  const policyCode = wasmInstance.choose_policy(
    features.text_len,
    features.has_question,
    features.has_urgent_keyword,
    features.has_code_hint
  );

  const policies = ['concise', 'detailed', 'urgent'];
  return policies[policyCode];
}

// KV API
Fastify.get('/kv/:key', async (request, reply) => {
  const { key } = request.params;
  const row = db.prepare('SELECT value FROM kv WHERE key = ? AND (expires_at IS NULL OR expires_at > ?)').get(key, Date.now());
  if (!row) return reply.status(404).send({ error: 'Key not found' });
  return { key, value: row.value };
});

Fastify.put('/kv/:key', async (request, reply) => {
  const { key } = request.params;
  const { value, ttl } = request.body;
  const expires_at = ttl ? Date.now() + (ttl * 1000) : null;

  db.prepare('REPLACE INTO kv (key, value, expires_at) VALUES (?, ?, ?)').run(key, JSON.stringify(value), expires_at);
  return { success: true, key };
});

Fastify.delete('/kv/:key', async (request, reply) => {
  const { key } = request.params;
  db.prepare('DELETE FROM kv WHERE key = ?').run(key);
  return { success: true };
});

// Inference API
Fastify.post('/api/infer', async (request, reply) => {
  const { text, context = {} } = request.body;

  if (!text) {
    return reply.status(400).send({ error: 'text is required' });
  }

  // Get policy from WASM core
  const policy = getResponsePolicy(text);

  // Store request in KV
  const requestId = `req_${Date.now()}_${Math.random().toString(36).slice(2)}`;
  db.prepare('REPLACE INTO kv (key, value, expires_at) VALUES (?, ?, ?)')
    .run(requestId, JSON.stringify({ text, policy, timestamp: Date.now() }), Date.now() + 86400000);

  return {
    request_id: requestId,
    policy,
    features: extractFeatures(text),
    response: {
      concise: policy === 'concise' ? '好的，已收到你的请求。' : null,
      detailed: policy === 'detailed' ? '我将详细分析你的问题，以下是详细解答：\n...' : null,
      urgent: policy === 'urgent' ? '⚠️ 紧急请求已收到，优先处理中！' : null
    }[policy]
  };
});

// Health check
Fastify.get('/health', async () => {
  return {
    status: 'ok',
    wasm_loaded: !!wasmInstance,
    timestamp: Date.now()
  };
});

// Start server
const start = async () => {
  try {
    await loadWasm();
    await Fastify.listen({ port: 8787, host: '0.0.0.0' });
    console.log('🚀 Edge worker running on http://localhost:8787');
    console.log('📦 WASM core loaded, SQLite KV initialized');
  } catch (err) {
    Fastify.log.error(err);
    process.exit(1);
  }
};

start();
