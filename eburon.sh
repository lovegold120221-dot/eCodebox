#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# Eburon Codebox — One-Click Installer
# Installs: Codex.app → rebrands to Eburon Codebox
#           Ollama + eburon-pro/autonomous model
#           eburon CLI launcher
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

# ─── Detect macOS ───
detect_macos() {
  if [ "$(uname -s)" != "Darwin" ]; then
    fail "This installer is for macOS only."
  fi
  echo -e "  macOS $(sw_vers -productVersion) — ${BOLD}$(uname -m)${NC}"
}

# ─── Install Ollama ───
install_ollama() {
  if command -v ollama &>/dev/null; then
    success "Ollama already installed ($(ollama --version 2>/dev/null || echo '?'))"
    return
  fi
  step "Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
  success "Ollama installed"
}

# ─── Start Ollama ───
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

# ─── Pull Eburon model ───
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

# ─── Install Codex.app ───
install_codex() {
  if [ -d "/Applications/Codex.app" ]; then
    success "Codex.app already installed"
    return
  fi
  step "Installing Codex.app from OpenAI..."
  echo -e "  ${YELLOW}Downloading Codex desktop app...${NC}"
  echo -e "  ${YELLOW}Visit: https://codex.ai/download${NC}"
  echo -e "  ${YELLOW}Or install via:${NC}"
  echo -e "  ${YELLOW}  npx codex app${NC}"
  echo ""
  echo -e "  ${YELLOW}After installing, re-run this script to complete setup.${NC}"
  echo ""
  read -p "  Press Enter after installing Codex.app, or Ctrl+C to abort..."
  if [ ! -d "/Applications/Codex.app" ]; then
    fail "Codex.app not found at /Applications/Codex.app. Please install it first."
  fi
  success "Codex.app installed"
}

# ─── Rebrand to Eburon Codebox ───
rebrand_codebox() {
  if [ -d "/Applications/Eburon Codebox.app" ]; then
    success "Eburon Codebox.app already exists"
    return
  fi
  step "Rebranding to Eburon Codebox..."
  
  cp -R "/Applications/Codex.app" "/Applications/Eburon Codebox.app"
  
  # Update Info.plist
  plutil -replace CFBundleDisplayName -string "Eburon Codebox" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -replace CFBundleName -string "Eburon Codebox" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -replace CFBundleIdentifier -string "dev.eburon.codebox" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -replace CFBundleShortVersionString -string "1.0.0" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "1.0.0" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -remove ElectronAsarIntegrity "/Applications/Eburon Codebox.app/Contents/Info.plist" 2>/dev/null || true
  
  # Sign with ad-hoc identity
  codesign --force --deep --sign - "/Applications/Eburon Codebox.app" 2>/dev/null
  
  success "Eburon Codebox.app created"
}

# ─── Verify ───
verify() {
  echo ""
  echo -e "${CYAN}${BOLD}  ─── Verification ───────────────────────────${NC}"
  
  local ok=true
  
  if [ -d "/Applications/Eburon Codebox.app" ]; then
    success "Eburon Codebox.app: installed"
  else
    warn "Eburon Codebox.app: missing"
    ok=false
  fi
  
  if command -v ollama &>/dev/null; then
    success "Ollama: installed ($(ollama --version 2>/dev/null || echo '?'))"
  else
    warn "Ollama: missing"
    ok=false
  fi
  
  if ollama list 2>/dev/null | grep -q "eburon-pro/autonomous"; then
    success "Model eburon-pro/autonomous: pulled"
  else
    warn "Model eburon-pro/autonomous: not pulled"
    ok=false
  fi
  
  echo ""
  if $ok; then
    echo -e "${GREEN}${BOLD}  ✅ Installation complete!${NC}"
    echo ""
    echo -e "  ${CYAN}Open a new terminal and run:${NC}"
    echo -e "  ${BOLD}    ollama launch codex-app --model eburon-pro/autonomous${NC}"
    echo ""
    echo -e "  ${YELLOW}Or install the eburon launcher separately:${NC}"
    echo -e "  ${YELLOW}    curl -fsSL https://raw.githubusercontent.com/lovegold120221-dot/eCodebox/main/bin/eburon > ~/.local/bin/eburon${NC}"
    echo -e "  ${YELLOW}    chmod +x ~/.local/bin/eburon${NC}"
    echo -e "  ${YELLOW}    export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo -e "  ${YELLOW}    eburon${NC}"
  else
    echo -e "${YELLOW}${BOLD}  ⚠ Installation incomplete — see warnings above${NC}"
  fi
  echo ""
}

# ─── Main ───
main() {
  banner
  detect_macos
  echo ""
  
  install_ollama
  start_ollama
  pull_model
  echo ""
  
  install_codex
  rebrand_codebox
  echo ""
  
  verify
}

main
