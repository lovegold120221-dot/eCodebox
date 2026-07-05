# Eburon Codebox

> Autonomous AI Coding Agent — powered by Eburon AI

## Install

```bash
git clone https://github.com/lovegold120221-dot/eCodebox.git
cd eCodebox
chmod +x eburon.sh
./eburon.sh
```

This installs:
1. **Ollama** + **eburon-pro/autonomous** model
2. **Eburon Codebox** from the DMG in the repo
3. Rebrands to `/codebox` with symlink `/Applications/Codex.app` → `/codebox`
4. **`eburon` command** at `~/.local/bin/eburon`

## Usage

```bash
eburon
```

Or with a custom model:

```bash
EBURON_MODEL="deepseek-v4-flash" eburon
```

## What It Does

The installer clones the repo, installs Codex.app from the bundled DMG, rebrands it to `/codebox`, creates a symlink so `ollama launch codex-app` finds it, and installs the `eburon` launcher. The `eburon` command runs `ollama launch codex-app --model eburon-pro/autonomous`.

## Structure

```
eCodebox/
├── eburon.sh                # Installer
├── bin/eburon               # Terminal launcher
├── EburonCodebox.dmg        # App installer (530MB, Git LFS)
├── package.json             # Electron app config
├── webview/                 # Frontend (React SPA)
├── native-menu-locales/     # Localization
└── skills/                  # Built-in skills
```

## License

MIT — Based on Codex by OpenAI
