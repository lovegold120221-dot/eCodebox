#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

step()    { echo -e "${CYAN}→${NC} $1"; }
success() { echo -e "${GREEN}  ✓${NC} $1"; }
warn()    { echo -e "${YELLOW}  ⚠${NC} $1"; }
fail()    { echo -e "${RED}  ✗${NC} $1"; exit 1; }

banner() {
  echo -e "${CYAN}${BOLD}"
  echo "  ╔═══════════════════════════════════════════╗"
  echo "  ║  ⚡ Eburon Codebox — Linux Installer     ║"
  echo "  ╚═══════════════════════════════════════════╝"
  echo -e "${NC}"
}

detect_linux() {
  if [ "$(uname -s)" != "Linux" ]; then
    fail "This installer is for Linux only."
  fi
  if ! command -v apt-get &>/dev/null; then
    fail "This installer requires apt (Debian/Ubuntu)."
  fi
  echo -e "  $(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"' || echo 'Linux') — ${BOLD}$(uname -m)${NC}"
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
  if systemctl list-units --type=service 2>/dev/null | grep -q ollama; then
    sudo systemctl start ollama
  else
    ollama serve >/dev/null 2>&1 &
  fi
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
  for i in {1..30}; do
    if ollama list 2>/dev/null | grep -q "$model"; then
      success "Model $model pulled"
      return
    fi
    sleep 2
  done
  fail "Failed to pull model $model."
}

install_nodejs() {
  if command -v node &>/dev/null && node -e "process.exit(Number(process.version.slice(1).split('.')[0] < 18))"; then
    success "Node.js $(node -v) already installed"
    return
  fi
  step "Installing Node.js 18+..."
  if command -v npm &>/dev/null; then
    sudo npm install -g n 2>/dev/null
    sudo n 18 2>/dev/null
  else
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs 2>/dev/null
  fi
  command -v node &>/dev/null && success "Node.js $(node -v) installed" || fail "Node.js installation failed"
}

clone_repo() {
  local repo_dir="$HOME/eCodebox"
  if [ -d "$repo_dir" ]; then
    success "eCodebox repo already cloned"
    return
  fi
  step "Cloning Eburon Codebox..."
  git clone --depth 1 https://github.com/lovegold120221-dot/eCodebox.git "$repo_dir"
  success "eCodebox repo cloned to $repo_dir"
}

install_desktop_entry() {
  local repo_dir="$HOME/eCodebox"
  local entry="$HOME/.local/share/applications/eburon-codebox.desktop"

  mkdir -p "$HOME/.local/share/applications"

  cat > "$entry" << EOF
[Desktop Entry]
Name=Eburon Codebox
Comment=Eburon Codebox — AI-powered IDE
Exec=$repo_dir/server/eburon-linux.sh start
Icon=$repo_dir/server/public/icon.png
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=EburonCodebox
EOF

  chmod +x "$entry"
  success "Desktop entry created"
}

install_server_deps() {
  local repo_dir="$HOME/eCodebox"
  step "Installing server dependencies..."
  cd "$repo_dir/server" && npm install --production 2>/dev/null
  success "Server dependencies installed"
}

start_server() {
  local repo_dir="$HOME/eCodebox"
  local pid_file="/tmp/eburon-codebox.pid"

  if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    success "Eburon Codebox server already running (pid $(cat "$pid_file"))"
    echo -e "  ${CYAN}Open:${NC} ${BOLD}http://localhost:4096${NC}"
    return
  fi

  step "Starting Eburon Codebox server..."
  nohup node "$repo_dir/server/server.js" > "$repo_dir/server/server.log" 2>&1 &
  echo $! > "$pid_file"

  for i in {1..10}; do
    if curl -s http://localhost:4096 >/dev/null 2>&1; then
      success "Server started on http://localhost:4096"
      xdg-open "http://localhost:4096" 2>/dev/null || true
      return
    fi
    sleep 1
  done
  warn "Server may not have started. Check $repo_dir/server/server.log"
}

install_eburon_command() {
  local dest="$HOME/.local/bin/eburon"
  mkdir -p "$HOME/.local/bin"
  cat > "$dest" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
M="${EBURON_MODEL:-eburon-pro/autonomous}"
echo -e "\033[0;36m\033[1m  ╔═══════════════════════════════════════════╗"
echo "  ║     ⚡ Eburon Codebox — Eburon AI      ║"
echo -e "  ╚═══════════════════════════════════════════╝\033[0m"
echo "  Model: $M"
echo ""
REPO_DIR="$HOME/eCodebox"
PID_FILE="/tmp/eburon-codebox.pid"
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "  Server running at http://localhost:4096"
  xdg-open "http://localhost:4096" 2>/dev/null || true
else
  echo "  Starting server..."
  nohup node "$REPO_DIR/server/server.js" > "$REPO_DIR/server/server.log" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 3
  echo "  Server started at http://localhost:4096"
  xdg-open "http://localhost:4096" 2>/dev/null || true
fi
SCRIPT
  chmod +x "$dest"
  success "eburon command installed to $dest"
}

verify() {
  echo ""
  echo -e "${CYAN}${BOLD}  ─── Verification ───────────────────────────${NC}"
  local ok=true
  command -v ollama &>/dev/null && success "Ollama: installed" || { warn "Ollama: missing"; ok=false; }
  ollama list 2>/dev/null | grep -q "eburon-pro/autonomous" && success "Model: pulled" || { warn "Model not pulled"; ok=false; }
  command -v node &>/dev/null && success "Node.js: $(node -v)" || { warn "Node.js: missing"; ok=false; }
  [ -f "$HOME/eCodebox/server/server.js" ] && success "Webapp: installed" || { warn "Webapp: missing"; ok=false; }
  curl -s http://localhost:4096 >/dev/null 2>&1 && success "Server: running" || warn "Server: not running"
  echo ""
  if $ok; then
    echo -e "${GREEN}${BOLD}  ✅ Installation complete!${NC}"
    echo ""
    echo -e "  ${CYAN}Open:${NC} ${BOLD}http://localhost:4096${NC}"
    echo -e "  ${CYAN}Run:${NC}  ${BOLD}eburon${NC}"
  else
    echo -e "${YELLOW}${BOLD}  ⚠ Installation incomplete — see warnings above${NC}"
  fi
  echo ""
}

main() {
  banner
  detect_linux
  echo ""
  install_ollama
  start_ollama
  pull_model
  echo ""
  install_nodejs
  echo ""
  clone_repo
  install_server_deps
  install_desktop_entry
  echo ""
  start_server
  install_eburon_command
  echo ""
  verify
}

if [ "${1:-}" = "start" ]; then
  install_server_deps 2>/dev/null
  start_server
else
  main
fi
