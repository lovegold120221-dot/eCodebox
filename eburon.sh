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
  # Wait to ensure model is fully pulled before proceeding
  for i in {1..30}; do
    if ollama list 2>/dev/null | grep -q "$model"; then
      success "Model $model pulled"
      return
    fi
    sleep 2
  done
  fail "Failed to pull model $model."
}

install_git_lfs() {
  if command -v git-lfs &>/dev/null; then
    return 0
  fi
  step "Installing Git LFS..."
  if command -v brew &>/dev/null; then
    brew install git-lfs 2>/dev/null
  else
    curl -fsSL https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash 2>/dev/null || \
    curl -fsSL https://github.com/git-lfs/git-lfs/releases/download/v3.6.1/git-lfs-darwin-arm64-v3.6.1.tar.gz -o /tmp/git-lfs.tar.gz 2>/dev/null && \
    tar xzf /tmp/git-lfs.tar.gz -C /tmp && /tmp/git-lfs-3.6.1/install.sh 2>/dev/null
  fi
  git lfs install 2>/dev/null
  command -v git-lfs &>/dev/null
}

clone_repo() {
  local repo_dir="$HOME/eCodebox"
  if [ -d "$repo_dir" ]; then
    success "eCodebox repo already cloned"
    return
  fi
  step "Cloning Eburon Codebox..."
  git clone --depth 1 https://github.com/lovegold120221-dot/eCodebox.git "$repo_dir"
  install_git_lfs || warn "Git LFS not available — will download asar from Releases instead"
  (cd "$repo_dir" && git lfs pull 2>/dev/null) || true
  success "eCodebox repo cloned to $repo_dir"
}

install_and_rebrand() {
  local app_dir="$HOME/Applications/Eburon Codebox.app"
  local repo_dir="$HOME/eCodebox"

  if [ ! -d "$app_dir" ]; then
    step "Installing Eburon Codebox (admin access required)..."

    local dmg_url="https://github.com/lovegold120221-dot/eCodebox/releases/download/v1.0.0/Codex.dmg"
    local dmg_path="/tmp/EburonCodebox.dmg"
    local asar_src="$repo_dir/app/EburonCodebox.asar"
    local asar_url="https://github.com/lovegold120221-dot/eCodebox/releases/download/v1.0.0/EburonCodebox.asar"

    curl -fsSL -o "$dmg_path" "$dmg_url" --progress-bar 2>&1 | tail -1
    if [ ! -f "$dmg_path" ] || [ "$(stat -f%z "$dmg_path" 2>/dev/null)" -lt 100000000 ]; then
      fail "Download failed. Check your internet connection."
    fi

    local asar_size
    asar_size=$(stat -f%z "$asar_src" 2>/dev/null || echo "0")
    if [ ! -f "$asar_src" ] || [ "$asar_size" -lt 1000000 ]; then
      step "  Downloading rebranded app UI (166MB)..."
      asar_src=""
    fi

    osascript -e "
      set dmgPath to \"$dmg_path\"
      set appDir to \"$app_dir\"
      set homeApps to \"$HOME/Applications\"
      set asarFile to \"${asar_src:-}\"
      set asarUrl to \"$asar_url\"

      do shell script \"mkdir -p '\" & homeApps & \"'\" with administrator privileges
      do shell script \"hdiutil attach '\" & dmgPath & \"' -quiet -nobrowse -mountpoint /tmp/eburon-install 2>/dev/null\" with administrator privileges
      do shell script \"cp -R /tmp/eburon-install/Codex.app '\" & appDir & \"'\" with administrator privileges
      do shell script \"hdiutil detach /tmp/eburon-install -quiet 2>/dev/null\" with administrator privileges

      do shell script \"plutil -replace CFBundleDisplayName -string 'Eburon Codebox' '\" & appDir & \"/Contents/Info.plist'\" with administrator privileges
      do shell script \"plutil -replace CFBundleName -string 'Eburon Codebox' '\" & appDir & \"/Contents/Info.plist'\" with administrator privileges
      do shell script \"plutil -replace CFBundleIdentifier -string 'dev.eburon.codebox' '\" & appDir & \"/Contents/Info.plist'\" with administrator privileges
      do shell script \"plutil -replace CFBundleShortVersionString -string '1.0.0' '\" & appDir & \"/Contents/Info.plist'\" with administrator privileges
      do shell script \"plutil -replace CFBundleVersion -string '1.0.0' '\" & appDir & \"/Contents/Info.plist'\" with administrator privileges
      do shell script \"plutil -remove ElectronAsarIntegrity '\" & appDir & \"/Contents/Info.plist' 2>/dev/null; exit 0\" with administrator privileges

      if asarFile is not \"\" then
        do shell script \"cp '\" & asarFile & \"' '\" & appDir & \"/Contents/Resources/app.asar'\" with administrator privileges
      else
        do shell script \"curl -fsSL -o '\" & appDir & \"/Contents/Resources/app.asar' '\" & asarUrl & \"' --progress-bar 2>&1 | tail -1\" with administrator privileges
      end if

      do shell script \"codesign --force --deep --sign - '\" & appDir & \"' 2>/dev/null\" with administrator privileges

      return \"App installed\"
    " 2>&1

    rm -f "$dmg_path"
    [ -d "$app_dir" ] && success "Eburon Codebox installed at $app_dir" || fail "Installation failed."
  else
    success "Eburon Codebox already installed"
  fi

  # Always rebrand plugin files and re-sign
  local repo_dir="$HOME/eCodebox"
  step "  Rebranding plugin files..."
  osascript -e "do shell script \"'$repo_dir/scripts/rebrand-plugins.sh' '$app_dir'\" with administrator privileges" 2>&1
  success "Plugin files rebranded"

  step "  Re-signing application..."
  osascript -e "do shell script \"codesign --force --deep --sign - '$app_dir' 2>/dev/null\" with administrator privileges" 2>&1
  success "Application re-signed"

  # Always ensure symlinks exist
  step "  Creating application symlinks..."
  osascript -e "
    set appDir to \"$app_dir\"
    do shell script \"rm -rf /Applications/Eburon\\ Codebox.app 2>/dev/null; ln -s '\" & appDir & \"' '/Applications/Eburon Codebox.app'\" with administrator privileges
    do shell script \"rm -rf /Applications/Codex.app 2>/dev/null; ln -s '\" & appDir & \"' /Applications/Codex.app\" with administrator privileges
    return \"Symlinks created\"
  " 2>&1
  success "Application symlinks created"
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
ollama launch codex-app --model "$M" --yes
EOF
  chmod +x "$dest"
  success "eburon command installed"
}

verify() {
  echo ""
  echo -e "${CYAN}${BOLD}  ─── Verification ───────────────────────────${NC}"
  local app_dir="$HOME/Applications/Eburon Codebox.app"
  local ok=true
  [ -d "$app_dir" ] && success "Eburon Codebox at $app_dir: installed" || { warn "$app_dir: missing"; ok=false; }
  [ -L "/Applications/Eburon Codebox.app" ] && success "Symlink /Applications/Eburon Codebox.app: ok" || { warn "/Applications/Eburon Codebox.app: missing"; ok=false; }
  [ -L "/Applications/Codex.app" ] && [ "$(readlink /Applications/Codex.app)" = "$app_dir" ] && success "Symlink /Applications/Codex.app → Eburon Codebox: ok" || { warn "/Applications/Codex.app symlink: missing"; ok=false; }
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
  echo ""
  install_and_rebrand
  echo ""
  install_eburon_command
  echo ""
  verify
}

main
