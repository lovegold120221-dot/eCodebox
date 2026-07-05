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

clone_repo() {
  local repo_dir="$HOME/eCodebox"
  if [ -d "$repo_dir" ]; then
    success "eCodebox repo already cloned"
    return
  fi
  step "Cloning Eburon Codebox..."
  git clone --depth 1 https://github.com/lovegold120221-dot/eCodebox.git "$repo_dir"
  cd "$repo_dir" && git lfs pull 2>/dev/null
  success "eCodebox repo cloned to $repo_dir"
}

install_engine() {
  if [ -d "/codebox" ]; then
    success "Eburon Codebox already installed at /codebox"
    return
  fi
  step "Installing Eburon Codebox engine..."
  local dmg_url="https://github.com/lovegold120221-dot/eCodebox/raw/main/EburonCodebox.dmg"
  local dmg_path="/tmp/EburonCodebox.dmg"
  curl -fsSL -o "$dmg_path" "$dmg_url" --progress-bar 2>&1 | tail -1
  if [ ! -f "$dmg_path" ] || [ "$(stat -f%z "$dmg_path" 2>/dev/null)" -lt 100000000 ]; then
    fail "Download failed. Check your internet connection."
  fi
  hdiutil attach "$dmg_path" -quiet -nobrowse -mountpoint /tmp/eburon-install 2>/dev/null
  cp -R "/tmp/eburon-install/Codex.app" /Applications/Codex.app
  hdiutil detach /tmp/eburon-install -quiet 2>/dev/null
  rm -f "$dmg_path"
  if [ ! -d "/Applications/Codex.app" ]; then
    fail "Installation failed."
  fi
  success "Engine installed"
}

rebrand() {
  if [ -d "/codebox" ]; then
    return
  fi
  step "Configuring Eburon Codebox at /codebox..."
  cp -R "/Applications/Codex.app" "/codebox"
  plutil -replace CFBundleDisplayName -string "Eburon Codebox" "/codebox/Contents/Info.plist"
  plutil -replace CFBundleName -string "Eburon Codebox" "/codebox/Contents/Info.plist"
  plutil -replace CFBundleIdentifier -string "dev.eburon.codebox" "/codebox/Contents/Info.plist"
  plutil -replace CFBundleShortVersionString -string "1.0.0" "/codebox/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "1.0.0" "/codebox/Contents/Info.plist"
  plutil -remove ElectronAsarIntegrity "/codebox/Contents/Info.plist" 2>/dev/null || true
  codesign --force --deep --sign - "/codebox" 2>/dev/null
  rm -rf "/Applications/Codex.app"
  ln -s "/codebox" "/Applications/Codex.app"
  success "Eburon Codebox configured at /codebox"
}

install_eburon_command() {
  local dest="$HOME/.local/bin/eburon"
  mkdir -p "$HOME/.local/bin"
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
  [ -d "/codebox" ] && success "Eburon Codebox at /codebox: installed" || { warn "/codebox: missing"; ok=false; }
  [ -L "/Applications/Codex.app" ] && [ "$(readlink /Applications/Codex.app)" = "/codebox" ] && success "Symlink /Applications/Codex.app → /codebox: ok" || { warn "Symlink missing"; ok=false; }
  command -v ollama &>/dev/null && success "Ollama: installed" || { warn "Ollama: missing"; ok=false; }
  ollama list 2>/dev/null | grep -q "eburon-pro/autonomous" && success "Model eburon-pro/autonomous: pulled" || { warn "Model eburon-pro/autonomous: not pulled"; ok=false; }
  command -v eburon &>/dev/null && success "eburon command: installed" || warn "eburon command: not in PATH"
  echo ""
  if $ok; then
    echo -e "${GREEN}${BOLD}  ✅ Installation complete!${NC}"
    echo ""
    echo -e "  ${CYAN}Run:${NC} ${BOLD}eburon${NC}"
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
  clone_repo
  install_engine
  rebrand
  echo ""
  install_eburon_command
  echo ""
  verify
}

main
