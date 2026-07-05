# Eburon Codebox

> Autonomous AI Coding Agent — powered by Eburon AI

## Quick Install

Choose your platform:

| Platform | Command |
|---|---|
| **macOS** | `git clone https://github.com/lovegold120221-dot/eCodebox.git && cd eCodebox && ./eburon.sh` |
| **Ubuntu/Debian** | `git clone https://github.com/lovegold120221-dot/eCodebox.git && cd eCodebox && ./server/eburon-linux.sh` |
| **Windows** | `git clone https://github.com/lovegold120221-dot/eCodebox.git` then right-click `server/eburon.ps1` → Run with PowerShell (Admin) |

## What It Installs

1. **Ollama** + **eburon-pro/autonomous** model
2. **Webapp** (Monaco Editor + AI Chat) at `http://localhost:4096`
3. On macOS only: the native **Eburon Codebox** desktop app with rebranded UI
4. **`eburon` command** in your PATH

## Usage

```bash
eburon
```

Opens the Eburon Codebox IDE in your browser at `http://localhost:4096`.

### Features

- **Monaco Editor** — VS Code's editor in your browser with syntax highlighting for 30+ languages
- **AI Chat** — Powered by Ollama with streaming responses, Markdown rendering, and code blocks
- **File Explorer** — Create, edit, delete files and folders in your project directory
- **Context-Aware** — The current editor tab's content is automatically included as context for AI prompts

## Structure

```
eCodebox/
├── eburon.sh                  # macOS installer
├── server/
│   ├── server.js              # Webapp server (Node.js + Express)
│   ├── eburon-linux.sh        # Ubuntu/Debian installer
│   ├── eburon.ps1             # Windows PowerShell installer
│   ├── package.json
│   └── public/
│       ├── index.html         # Monaco Editor IDE
│       ├── app.js             # Frontend logic
│       └── styles.css         # Dark theme
├── app/
│   └── EburonCodebox.asar     # macOS app UI (Git LFS)
├── scripts/
│   ├── rebrand-plugins.sh     # Rebrand plugin files
│   └── rebrand-asar.sh        # Rebuild EburonCodebox.asar from Codex original
└── webview/                   # macOS desktop app frontend
```

## Architecture

The webapp runs a Node.js server that provides:
- **Ollama API proxy** — `/api/ollama/proxy/*` forwards to Ollama's OpenAI-compatible API
- **File system API** — `/api/fs/*` for reading/writing project files
- **Monaco Editor** — loaded from CDN, edited files are saved back to disk

All AI requests go through Ollama running locally at `http://localhost:11434`. No data leaves your machine.

## Custom Model

Override the default model:

```bash
EBURON_MODEL="codellama" eburon
```

## License

MIT — Based on Codex by OpenAI
