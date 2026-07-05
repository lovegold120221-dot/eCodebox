# Eburon Codebox

> Autonomous AI Coding Agent — powered by Eburon AI

One command to install everything: **Codex.app → rebranded to Eburon Codebox**, **Ollama**, **eburon-pro/autonomous model**, and the **eburon** launcher.

## One-Click Install

```bash
curl -fsSL https://raw.githubusercontent.com/lovegold120221-dot/eCodebox/main/eburon.sh | bash
```

This installs:
1. **Ollama** — local LLM runner
2. **eburon-pro/autonomous** model — pulled from Ollama
3. **Codex.app** — prompts you to install from OpenAI if missing
4. **Eburon Codebox.app** — rebranded copy at `/Applications/Eburon Codebox.app`
5. **`eburon` command** — installed to `/usr/local/bin/eburon`

## Usage

```bash
# Launch Eburon Codebox
eburon

# Launch with custom model
EBURON_MODEL="deepseek-v4-flash" eburon
```

## What It Does

The installer:
- Detects macOS, installs Ollama if missing
- Pulls `eburon-pro/autonomous` from Ollama
- Copies `/Applications/Codex.app` → `/Applications/Eburon Codebox.app`
- Rebrands Info.plist (name, bundle ID, version)
- Removes ElectronAsarIntegrity (hash mismatch from rebrand)
- Ad-hoc signs the bundle
- Installs the `eburon` launcher to `/usr/local/bin`

The `eburon` command:
- Starts Ollama if not running
- Pulls the model if not downloaded
- Sets `OPENAI_BASE_URL=http://localhost:11434/v1`
- Opens Eburon Codebox.app

## Prerequisites

- macOS 12+
- Internet connection

## Manual Install

```bash
git clone https://github.com/lovegold120221-dot/eCodebox.git
cd eCodebox
chmod +x eburon.sh
./eburon.sh
```

## Structure

```
eCodebox/
├── eburon.sh                # One-click installer
├── bin/eburon               # Terminal launcher
├── package.json             # Electron app config
├── webview/                 # Frontend (React SPA)
│   ├── index.html
│   └── assets/              # Bundled JS/CSS
├── native-menu-locales/     # Localization
└── skills/                  # Built-in skills
```

## License

MIT — Based on Codex by OpenAI
