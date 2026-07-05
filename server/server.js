const express = require('express');
const path = require('path');
const fs = require('fs');
const http = require('http');

const app = express();
const PORT = process.env.PORT || 4096;
const OLLAMA_BASE = process.env.OLLAMA_HOST || 'http://127.0.0.1:11434';

app.use(express.json({ limit: '50mb' }));

app.use(express.static(path.join(__dirname, 'public')));

async function ollamaFetch(method, endpoint, body) {
  const url = `${OLLAMA_BASE}${endpoint}`;
  const opts = { method, headers: {} };
  if (body) {
    opts.headers['Content-Type'] = 'application/json';
    opts.body = JSON.stringify(body);
  }
  const res = await fetch(url, opts);
  return res;
}

app.post('/api/ollama/proxy/:endpoint(*)', async (req, res) => {
  try {
    const endpoint = '/' + req.params.endpoint;
    const ollamaRes = await ollamaFetch('POST', endpoint, req.body);
    const contentType = ollamaRes.headers.get('content-type') || '';

    if (contentType.includes('text/event-stream') || endpoint === '/api/chat' || endpoint === '/v1/chat/completions') {
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');
      const reader = ollamaRes.body.getReader();
      const decoder = new TextDecoder();
      while (true) {
        const { done, value } = await reader.read();
        if (done) { res.end(); break; }
        res.write(decoder.decode(value));
      }
    } else {
      const data = await ollamaRes.json();
      res.json(data);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/ollama/tags', async (req, res) => {
  try {
    const r = await ollamaFetch('GET', '/api/tags');
    const data = await r.json();
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const FS_BASE = process.env.EBURON_PROJECTS_DIR || path.join(process.env.HOME || __dirname, 'EburonProjects');

if (!fs.existsSync(FS_BASE)) {
  fs.mkdirSync(FS_BASE, { recursive: true });
}

app.get('/api/fs/list', (req, res) => {
  const dir = req.query.dir || FS_BASE;
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true }).map(e => ({
      name: e.name,
      isDirectory: e.isDirectory(),
      path: path.join(dir, e.name)
    }));
    entries.sort((a, b) => {
      if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.localeCompare(b.name);
    });
    res.json({ entries, cwd: dir, root: FS_BASE });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/fs/read', (req, res) => {
  try {
    const content = fs.readFileSync(req.query.path, 'utf-8');
    res.json({ content });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/fs/write', (req, res) => {
  try {
    const filePath = req.body.path;
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, req.body.content, 'utf-8');
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/fs/mkdir', (req, res) => {
  try {
    fs.mkdirSync(req.body.path, { recursive: true });
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/fs/delete', (req, res) => {
  try {
    const p = req.body.path;
    if (fs.statSync(p).isDirectory()) {
      fs.rmSync(p, { recursive: true });
    } else {
      fs.unlinkSync(p);
    }
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Eburon Codebox server running on http://localhost:${PORT}`);
});
