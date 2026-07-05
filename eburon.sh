#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# Eburon Codebox — One-Click Installer
# ═══════════════════════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

step()    { echo -e "${CYAN}→${NC} $1"; }
success() { echo -e "${GREEN}  ✓${NC} $1"; }
warn()    { echo -e "${YELLOW}  ⚠${NC} $1"; }
fail()    { echo -e "${RED}  ✗${NC} $1"; exit 1; }

banner() {
  echo -e "${CYAN}${BOLD}"
  echo "  ╔═══════════════════════════════════════════╗"
  echo "  ║   ⚡ Eburon Codebox — One-Click Install  ║"
  echo "  ╚═══════════════════════════════════════════╝"
  echo -e "${NC}"
}

detect_macos() {
  if [ "$(uname -s)" != "Darwin" ]; then
    fail "This installer is for macOS only."
  fi
  echo -e "  macOS $(sw_vers -productVersion) — ${BOLD}$(uname -m)${NC}"
}

install_ollama() {
  if command -v ollama &>/dev/null; then
    success "Ollama already installed"
    return
  fi
  step "Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
  success "Ollama installed"
}

start_ollama() {
  if curl -s --max-time 2 http://localhost:11434/api/tags >/dev/null 2>&1; then
    success "Ollama is running"
    return
  fi
  step "Starting Ollama..."
  ollama serve >/dev/null 2>&1 &
  sleep 3
  success "Ollama started"
}

pull_model() {
  local model="eburon-pro/autonomous"
  if ollama list 2>/dev/null | grep -q "$model"; then
    success "Model $model already pulled"
    return
  fi
  step "Pulling $model (this may take a few minutes)..."
  ollama pull "$model"
  success "Model $model pulled"
}

install_engine() {
  if [ -d "/Applications/Eburon Codebox.app" ]; then
    success "Eburon Codebox.app already installed"
    return
  fi
  step "Downloading Eburon Codebox engine..."
  npx codex app >/dev/null 2>&1 || true
  if [ ! -d "/Applications/Codex.app" ]; then
    echo -e "  ${YELLOW}Please install the app from the link that opened in your browser,${NC}"
    echo -e "  ${YELLOW}then press Enter to continue...${NC}"
    read -p ""
    if [ ! -d "/Applications/Codex.app" ]; then
      fail "App not found. Please install from the link and re-run this script."
    fi
  fi
  success "Engine downloaded"
}

rebrand() {
  if [ -d "/Applications/Eburon Codebox.app" ]; then
    return
  fi
  step "Configuring Eburon Codebox..."
  cp -R "/Applications/Codex.app" "/Applications/Eburon Codebox.app"
  plutil -replace CFBundleDisplayName -string "Eburon Codebox" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -replace CFBundleName -string "Eburon Codebox" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -replace CFBundleIdentifier -string "dev.eburon.codebox" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -replace CFBundleShortVersionString -string "1.0.0" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "1.0.0" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -remove ElectronAsarIntegrity "/Applications/Eburon Codebox.app/Contents/Info.plist" 2>/dev/null || true
  python3 << 'PYEOF'
import os
asar = "/Applications/Eburon Codebox.app/Contents/Resources/app.asar"
with open(asar, 'rb') as f:
    data = f.read()
repls = [(b'Codex', b'Eburon Codebox'), (b'codex', b'eburon-codebox'), (b'OpenAI', b'Eburon AI'), (b'openai', b'eburon'), (b'com.openai.codex', b'dev.eburon.codebox')]
c = 0
for o, n in repls:
    cnt = data.count(o)
    if cnt: data = data.replace(o, n); c += cnt
if c:
    with open(asar, 'wb') as f: f.write(data)
PYEOF
  find "/Applications/Eburon Codebox.app/Contents/Resources" -name "*.json" -path "*/lproj/*" 2>/dev/null | while read f; do
    sed -i '' 's/Codex/Eburon Codebox/g; s/codex/eburon-codebox/g; s/OpenAI/Eburon AI/g' "$f" 2>/dev/null || true
  done
  codesign --force --deep --sign - "/Applications/Eburon Codebox.app" 2>/dev/null
  success "Eburon Codebox.app configured"
}

install_eburon_command() {
  local dest="$HOME/.local/bin/eburon"
  mkdir -p "$HOME/.local/bin"
  if [ -f "$dest" ]; then
    success "eburon command already installed"
    return
  fi
  step "Installing eburon command..."
  cat > "$dest" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
M="${EBURON_MODEL:-eburon-pro/autonomous}"
echo -e "\033[0;36m\033[1m  ╔═══════════════════════════════════════════╗"
echo "  ║     ⚡ Eburon Codebox — Eburon AI      ║"
echo -e "  ╚═══════════════════════════════════════════╝\033[0m"
echo "  Model: $M"
echo ""
ollama launch codex-app --model "$M"
EOF
  chmod +x "$dest"
  success "eburon command installed"
}

verify() {
  echo ""
  echo -e "${CYAN}${BOLD}  ─── Verification ───────────────────────────${NC}"
  local ok=true
  [ -d "/Applications/Eburon Codebox.app" ] && success "Eburon Codebox.app: installed" || { warn "Eburon Codebox.app: missing"; ok=false; }
  command -v ollama &>/dev/null && success "Ollama: installed" || { warn "Ollama: missing"; ok=false; }
  ollama list 2>/dev/null | grep -q "eburon-pro/autonomous" && success "Model eburon-pro/autonomous: pulled" || { warn "Model eburon-pro/autonomous: not pulled"; ok=false; }
  echo ""
  if $ok; then
    echo -e "${GREEN}${BOLD}  ✅ Installation complete!${NC}"
    echo ""
    echo -e "  ${CYAN}Open a new terminal and run:${NC}"
    echo -e "  ${BOLD}    eburon${NC}"
  else
    echo -e "${YELLOW}${BOLD}  ⚠ Installation incomplete — see warnings above${NC}"
  fi
  echo ""
}

main() {
  banner
  detect_macos
  echo ""
  install_ollama
  start_ollama
  pull_model
  echo ""
  install_engine
  rebrand
  echo ""
  install_eburon_command
  echo ""
  verify
}

main
