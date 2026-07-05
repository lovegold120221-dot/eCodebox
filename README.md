# Eburon Codebox

> Autonomous AI Coding Agent — powered by Eburon AI

Rebranded from Codex (OpenAI). Eburon Codebox is an Electron-based desktop AI coding agent that connects to Ollama models.

## Quick Start

```bash
# Launch with default model (eburon-pro/autonomous)
eburon

# Launch with custom model
EBURON_MODEL="deepseek-v4-flash" eburon
```

## Prerequisites

- [Ollama](https://ollama.com) installed and running
- macOS 12+

## Installation

```bash
# Clone the repo
git clone https://github.com/emilalvaroserrano-collab/eCodebox.git
cd eCodebox

# Install the eburon launcher
cp bin/eburon ~/.local/bin/
chmod +x ~/.local/bin/eburon

# Launch
eburon
```

## Structure

```
eCodebox/
├── bin/eburon              # Terminal launcher
├── package.json            # Electron app config
├── webview/                # Frontend (React SPA)
│   ├── index.html
│   └── assets/             # Bundled JS/CSS
├── native-menu-locales/    # Localization
└── skills/                 # Built-in skills
```

## Configuration

The launcher auto-configures:
- Ollama host: `http://localhost:11434`
- Model: `eburon-pro/autonomous` (configurable via `EBURON_MODEL` env var)
- OpenAI-compatible API at `http://localhost:11434/v1`

## License

MIT — Based on Codex by OpenAI
