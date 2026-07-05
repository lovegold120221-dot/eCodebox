let editor = null;
let openFiles = {};
let activeFilePath = null;
let fileTreeData = null;
let currentDialogResolve = null;

require.config({ paths: { vs: 'https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/min/vs' } });

require(['vs/editor/editor.main'], function () {
  monaco.editor.defineTheme('eburon-dark', {
    base: 'vs-dark',
    inherit: true,
    rules: [
      { token: 'comment', foreground: '6A9955', fontStyle: 'italic' },
      { token: 'keyword', foreground: '569CD6' },
      { token: 'string', foreground: 'CE9178' },
      { token: 'number', foreground: 'B5CEA8' },
      { token: 'function', foreground: 'DCDCAA' },
    ],
    colors: {
      'editor.background': '#1e1e1e',
      'editor.foreground': '#d4d4d4',
      'editor.lineHighlightBackground': '#2a2d2e',
      'editor.selectionBackground': '#264f78',
      'editorCursor.foreground': '#aeafad',
      'editorLineNumber.foreground': '#858585',
      'editorLineNumber.activeForeground': '#c6c6c6',
    }
  });

  editor = monaco.editor.create(document.getElementById('editor-container'), {
    value: '// Welcome to Eburon Codebox\n// Open a file or start a new project\n',
    language: 'javascript',
    theme: 'eburon-dark',
    fontSize: 14,
    fontFamily: "'Cascadia Code', 'Fira Code', 'JetBrains Mono', monospace",
    minimap: { enabled: true, scale: 1 },
    scrollBeyondLastLine: false,
    automaticLayout: true,
    tabSize: 2,
    renderWhitespace: 'selection',
    bracketPairColorization: { enabled: true },
    padding: { top: 8 },
  });

  editor.onDidChangeModelContent(() => {
    if (activeFilePath && openFiles[activeFilePath]) {
      openFiles[activeFilePath].dirty = true;
      updateTab(activeFilePath);
    }
  });

  init();
});

async function init() {
  await loadFileTree();
  await loadModels();
  setupEventListeners();
}

async function loadFileTree() {
  const res = await fetch('/api/fs/list');
  const data = await res.json();
  fileTreeData = data;
  renderFileTree(data.entries, document.getElementById('file-tree'), data.root);
}

function renderFileTree(entries, container, parentPath) {
  container.innerHTML = '';
  for (const entry of entries) {
    const div = document.createElement('div');
    div.className = 'tree-item';
    div.dataset.path = entry.path;

    if (entry.isDirectory) {
      const chevron = document.createElement('span');
      chevron.className = 'chevron';
      chevron.textContent = '>';
      div.appendChild(chevron);

      const icon = document.createElement('span');
      icon.className = 'icon';
      icon.textContent = '📁';
      div.appendChild(icon);
    } else {
      const icon = document.createElement('span');
      icon.className = 'icon';
      icon.textContent = getFileIcon(entry.name);
      div.appendChild(icon);
    }

    const name = document.createElement('span');
    name.className = 'name';
    name.textContent = entry.name;
    div.appendChild(name);

    div.addEventListener('click', (e) => {
      e.stopPropagation();
      if (entry.isDirectory) {
        toggleDirectory(entry.path, div);
      } else {
        openFile(entry.path);
      }
    });

    container.appendChild(div);
  }
}

async function toggleDirectory(dirPath, treeItemEl) {
  const chevron = treeItemEl.querySelector('.chevron');
  const existingSub = treeItemEl.nextElementSibling;

  if (existingSub && existingSub.classList.contains('tree-children')) {
    existingSub.remove();
    chevron.classList.remove('open');
    return;
  }

  chevron.classList.add('open');
  const res = await fetch(`/api/fs/list?dir=${encodeURIComponent(dirPath)}`);
  const data = await res.json();

  const subContainer = document.createElement('div');
  subContainer.className = 'tree-children';
  subContainer.style.paddingLeft = '16px';
  treeItemEl.parentNode.insertBefore(subContainer, treeItemEl.nextSibling);

  for (const entry of data.entries) {
    const div = document.createElement('div');
    div.className = 'tree-item';
    div.dataset.path = entry.path;

    if (entry.isDirectory) {
      const chevron = document.createElement('span');
      chevron.className = 'chevron';
      chevron.textContent = '>';
      div.appendChild(chevron);

      const icon = document.createElement('span');
      icon.className = 'icon';
      icon.textContent = '📁';
      div.appendChild(icon);

      div.addEventListener('click', (e) => {
        e.stopPropagation();
        toggleDirectory(entry.path, div);
      });
    } else {
      const icon = document.createElement('span');
      icon.className = 'icon';
      icon.textContent = getFileIcon(entry.name);
      div.appendChild(icon);

      div.addEventListener('click', (e) => {
        e.stopPropagation();
        openFile(entry.path);
      });
    }

    const name = document.createElement('span');
    name.className = 'name';
    name.textContent = entry.name;
    div.appendChild(name);

    subContainer.appendChild(div);
  }
}

function getFileIcon(name) {
  const ext = name.split('.').pop().toLowerCase();
  const icons = {
    js: '📜', ts: '📘', jsx: '⚛️', tsx: '⚛️',
    html: '🌐', css: '🎨', json: '📋', md: '📝',
    py: '🐍', rs: '🦀', go: '🔵', rb: '💎',
    java: '☕', cpp: '⚡', c: '⚡', h: '📐',
    yml: '⚙️', yaml: '⚙️', toml: '⚙️',
    sh: '💻', bash: '💻', zsh: '💻',
    txt: '📄', log: '📄', gitignore: '🔒',
    vue: '💚', svelte: '🧡', astro: '🟣',
    sql: '🗄️', db: '🗄️', svg: '🖼️', png: '🖼️',
    jpg: '🖼️', jpeg: '🖼️', gif: '🖼️', ico: '🖼️',
    exe: '▶️', dmg: '💿', app: '💿',
  };
  return icons[ext] || '📄';
}

async function openFile(filePath) {
  if (openFiles[filePath]) {
    activeFilePath = filePath;
    editor.setModel(openFiles[filePath].model);
    updateTabs();
    return;
  }

  try {
    const res = await fetch(`/api/fs/read?path=${encodeURIComponent(filePath)}`);
    const data = await res.json();
    const lang = guessLanguage(filePath);
    const model = monaco.editor.createModel(data.content, lang);

    openFiles[filePath] = { model, dirty: false, path: filePath };
    activeFilePath = filePath;
    editor.setModel(model);
    updateTabs();
    highlightFileInTree(filePath);
  } catch (err) {
    console.error('Failed to open file:', err);
  }
}

function guessLanguage(filePath) {
  const ext = filePath.split('.').pop().toLowerCase();
  const map = {
    js: 'javascript', jsx: 'javascript', ts: 'typescript', tsx: 'typescript',
    html: 'html', css: 'css', scss: 'scss', less: 'less',
    json: 'json', md: 'markdown', xml: 'xml', yml: 'yaml', yaml: 'yaml',
    py: 'python', rb: 'ruby', rs: 'rust', go: 'go',
    java: 'java', cpp: 'cpp', c: 'c', h: 'c',
    sh: 'shell', bash: 'shell', zsh: 'shell', sql: 'sql',
    vue: 'html', svelte: 'html', astro: 'typescript',
    toml: 'ini', env: 'dotenv', gitignore: 'ignore',
  };
  return map[ext] || 'plaintext';
}

function updateTabs() {
  const container = document.getElementById('editor-tabs');
  container.innerHTML = '';
  const paths = Object.keys(openFiles);
  if (paths.length === 0) {
    container.innerHTML = '<div style="padding: 0 12px; font-size: 13px; color: #666;">No files open</div>';
    return;
  }
  for (const fp of paths) {
    const tab = document.createElement('div');
    tab.className = 'tab' + (fp === activeFilePath ? ' active' : '');
    tab.textContent = fp.split('/').pop() || fp.split('\\').pop();
    if (openFiles[fp].dirty) tab.textContent += ' ●';

    tab.addEventListener('click', () => {
      activeFilePath = fp;
      editor.setModel(openFiles[fp].model);
      updateTabs();
      highlightFileInTree(fp);
    });

    const close = document.createElement('span');
    close.className = 'close';
    close.textContent = '×';
    close.addEventListener('click', (e) => {
      e.stopPropagation();
      closeFile(fp);
    });
    tab.appendChild(close);
    container.appendChild(tab);
  }
}

function updateTab(filePath) {
  const container = document.getElementById('editor-tabs');
  const tabs = container.querySelectorAll('.tab');
  const idx = Object.keys(openFiles).indexOf(filePath);
  if (idx >= 0 && tabs[idx]) {
    let text = filePath.split('/').pop();
    if (openFiles[filePath].dirty) text += ' ●';
    tabs[idx].textContent = text;
    if (openFiles[filePath].dirty) {
      const close = document.createElement('span');
      close.className = 'close';
      close.textContent = '×';
      close.addEventListener('click', (e) => {
        e.stopPropagation();
        closeFile(filePath);
      });
      tabs[idx].appendChild(close);
    }
  }
}

function closeFile(filePath) {
  const model = openFiles[filePath]?.model;
  if (model) model.dispose();
  delete openFiles[filePath];

  if (activeFilePath === filePath) {
    const remaining = Object.keys(openFiles);
    activeFilePath = remaining.length > 0 ? remaining[remaining.length - 1] : null;
    if (activeFilePath) {
      editor.setModel(openFiles[activeFilePath].model);
    } else {
      editor.setModel(monaco.editor.createModel('// Welcome to Eburon Codebox\n// Open a file or start a new project\n', 'javascript'));
    }
  }
  updateTabs();
}

function highlightFileInTree(filePath) {
  document.querySelectorAll('.tree-item.active').forEach(el => el.classList.remove('active'));
  document.querySelectorAll(`.tree-item[data-path="${CSS.escape(filePath)}"]`).forEach(el => el.classList.add('active'));
}

async function loadModels() {
  try {
    const res = await fetch('/api/ollama/tags');
    const data = await res.json();
    const select = document.getElementById('model-select');
    select.innerHTML = '';
    if (data.models) {
      for (const m of data.models) {
        const opt = document.createElement('option');
        opt.value = m.name;
        opt.textContent = m.name;
        select.appendChild(opt);
      }
    }
    if (select.options.length === 0) {
      const opt = document.createElement('option');
      opt.value = 'eburon-pro/autonomous';
      opt.textContent = 'eburon-pro/autonomous';
      select.appendChild(opt);
    }
  } catch {
    const select = document.getElementById('model-select');
    select.innerHTML = '<option value="eburon-pro/autonomous">eburon-pro/autonomous (offline)</option>';
  }
}

function setupEventListeners() {
  document.getElementById('chat-send').addEventListener('click', sendMessage);
  document.getElementById('chat-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  });

  document.getElementById('new-file-btn').addEventListener('click', async () => {
    const name = await showDialog('New File', 'filename.ts');
    if (!name) return;
    const base = fileTreeData?.root || '';
    const filePath = base + '/' + name;
    await fetch('/api/fs/write', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ path: filePath, content: '' })
    });
    await loadFileTree();
    await openFile(filePath);
  });

  document.getElementById('new-folder-btn').addEventListener('click', async () => {
    const name = await showDialog('New Folder', 'my-folder');
    if (!name) return;
    const base = fileTreeData?.root || '';
    await fetch('/api/fs/mkdir', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ path: base + '/' + name })
    });
    await loadFileTree();
  });
}

async function sendMessage() {
  const input = document.getElementById('chat-input');
  const text = input.value.trim();
  if (!text) return;

  input.value = '';
  addMessage('user', text);
  document.getElementById('chat-send').disabled = true;

  const model = document.getElementById('model-select').value;

  const context = getCurrentContext();

  const messages = [{ role: 'user', content: context + text }];

  try {
    const res = await fetch('/api/ollama/proxy/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model, messages, stream: true })
    });

    if (!res.ok) {
      addMessage('assistant', 'Error: ' + res.statusText);
      document.getElementById('chat-send').disabled = false;
      return;
    }

    const assistantMsg = addMessage('assistant', '', true);
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let content = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const chunk = decoder.decode(value);
      const lines = chunk.split('\n').filter(l => l.startsWith('data: '));

      for (const line of lines) {
        try {
          const json = JSON.parse(line.slice(6));
          if (json.choices?.[0]?.delta?.content) {
            content += json.choices[0].delta.content;
            assistantMsg.querySelector('.message-content').textContent = content;
            assistantMsg.scrollIntoView({ behavior: 'smooth', block: 'end' });
          }
        } catch {}
      }
    }

    renderMarkdown(assistantMsg.querySelector('.message-content'), content);
  } catch (err) {
    addMessage('assistant', 'Error: ' + err.message);
  }

  document.getElementById('chat-send').disabled = false;
}

function getCurrentContext() {
  let context = '';
  if (activeFilePath && openFiles[activeFilePath]) {
    const model = openFiles[activeFilePath].model;
    const code = model.getValue();
    const fileName = activeFilePath.split('/').pop();
    context = `Current file: ${fileName}\n\`\`\`\n${code.slice(0, 4000)}\n\`\`\`\n\n---\n\n`;
  }
  return context;
}

function addMessage(role, content, isStreaming) {
  const container = document.getElementById('chat-messages');
  const div = document.createElement('div');
  div.className = `message ${role}`;

  if (isStreaming) {
    const contentDiv = document.createElement('div');
    contentDiv.className = 'message-content';
    contentDiv.textContent = content;
    div.appendChild(contentDiv);
  } else {
    const contentDiv = document.createElement('div');
    contentDiv.className = 'message-content';
    if (role === 'assistant') {
      renderMarkdown(contentDiv, content);
    } else {
      contentDiv.textContent = content;
    }
    div.appendChild(contentDiv);
  }

  container.appendChild(div);
  container.scrollTop = container.scrollHeight;
  return div;
}

function renderMarkdown(el, md) {
  const html = md
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/```(\w*)\n([\s\S]*?)```/g, (_, lang, code) => {
      return `<pre><code>${code.trim()}</code></pre>`;
    })
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\*([^*]+)\*/g, '<em>$1</em>')
    .replace(/^### (.+)$/gm, '<h3>$1</h3>')
    .replace(/^## (.+)$/gm, '<h2>$1</h2>')
    .replace(/^# (.+)$/gm, '<h1>$1</h1>')
    .replace(/^- (.+)$/gm, '<li>$1</li>')
    .replace(/^(\d+)\. (.+)$/gm, '<li>$2</li>')
    .replace(/\n\n/g, '</p><p>')
    .replace(/\n/g, '<br>');

  el.innerHTML = `<p>${html}</p>`;
}

function showDialog(title, placeholder) {
  return new Promise((resolve) => {
    document.getElementById('dialog-overlay').classList.remove('hidden');
    document.getElementById('dialog-title').textContent = title;
    const input = document.getElementById('dialog-input');
    input.value = '';
    input.placeholder = placeholder;
    input.focus();

    currentDialogResolve = resolve;

    document.getElementById('dialog-confirm').onclick = () => {
      document.getElementById('dialog-overlay').classList.add('hidden');
      resolve(input.value);
    };

    document.getElementById('dialog-cancel').onclick = () => {
      document.getElementById('dialog-overlay').classList.add('hidden');
      resolve(null);
    };

    input.onkeydown = (e) => {
      if (e.key === 'Enter') {
        document.getElementById('dialog-confirm').click();
      }
    };
  });
}
