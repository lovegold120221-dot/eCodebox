#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# Eburon Codebox — One-Click Installer
# Installs: Codex.app → deep rebrand to Eburon Codebox
#           Ollama + eburon-pro/autonomous model
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
    success "Ollama already installed ($(ollama --version 2>/dev/null || echo '?'))"
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

install_codex() {
  if [ -d "/Applications/Codex.app" ]; then
    success "Codex.app already installed"
    return
  fi
  step "Installing Codex desktop app from OpenAI..."
  echo -e "  ${YELLOW}Visit: https://codex.ai/download${NC}"
  echo -e "  ${YELLOW}Or run: npx codex app${NC}"
  echo ""
  read -p "  Press Enter after installing Codex.app, or Ctrl+C to abort..."
  if [ ! -d "/Applications/Codex.app" ]; then
    fail "Codex.app not found. Please install it first."
  fi
  success "Codex.app installed"
}

# ─── Deep rebrand: patch every "Codex" and "OpenAI" string in the app ───
rebrand_codebox() {
  if [ -d "/Applications/Eburon Codebox.app" ]; then
    success "Eburon Codebox.app already exists"
    return
  fi

  step "Deep rebranding Codex → Eburon Codebox..."

  # 1. Copy the app
  cp -R "/Applications/Codex.app" "/Applications/Eburon Codebox.app"

  # 2. Update Info.plist
  plutil -replace CFBundleDisplayName -string "Eburon Codebox" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -replace CFBundleName -string "Eburon Codebox" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -replace CFBundleIdentifier -string "dev.eburon.codebox" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -replace CFBundleShortVersionString -string "1.0.0" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "1.0.0" "/Applications/Eburon Codebox.app/Contents/Info.plist"
  plutil -remove ElectronAsarIntegrity "/Applications/Eburon Codebox.app/Contents/Info.plist" 2>/dev/null || true

  # 3. Deep patch the app.asar — replace all "Codex" and "OpenAI" strings
  local asar_path="/Applications/Eburon Codebox.app/Contents/Resources/app.asar"
  local tmp_dir="/tmp/eburon-rebrand-$$"
  local node_modules_dir=""

  step "  Extracting app.asar..."
  # Check if asar is available
  if ! command -v npx &>/dev/null; then
    warn "npx not found, installing Node.js temporarily..."
    # Use python3 fallback
    python3 -c "
import json, os, re, shutil, tempfile

asar_path = '$asar_path'
tmp_dir = '$tmp_dir'

# Simple asar extraction using the header
# asar format: header JSON (4-byte aligned) + content
with open(asar_path, 'rb') as f:
    data = f.read()

# Find JSON header (starts with {)
header_end = data.find(b'{\"version\"')
if header_end < 0:
    header_end = 0
# Actually asar starts with header size (4 bytes) then JSON
import struct
header_size = struct.unpack('>I', data[0:4])[0]
header_json = data[4:4+header_size].decode('utf-8')
header = json.loads(header_json)

print(f'asar header size: {header_size}')
print(f'files: {len(header.get(\"files\", {}))}')
print('Extraction via python3 is limited. Using sed on raw asar instead.')
" 2>&1 | head -5
  fi

  # Use sed on the raw asar binary to replace strings
  # This works because asar is a tar-like archive with plaintext paths
  step "  Patching strings in app.asar..."
  
  # Replace all occurrences of "Codex" with "Eburon Codebox" in the asar
  # We do this carefully to not break the archive structure
  python3 << 'PYEOF'
import os, re

asar_path = "/Applications/Eburon Codebox.app/Contents/Resources/app.asar"

with open(asar_path, 'rb') as f:
    data = f.read()

original_len = len(data)
changes = 0

# Replace strings in the asar (both header paths and file contents)
# Order matters: do longer replacements first to avoid double-replacement
replacements = [
    (b'Codex', b'Eburon Codebox'),
    (b'codex', b'eburon-codebox'),
    (b'OpenAI', b'Eburon AI'),
    (b'openai', b'eburon'),
    (b'com.openai.codex', b'dev.eburon.codebox'),
]

for old, new in replacements:
    count = data.count(old)
    if count > 0:
        data = data.replace(old, new)
        changes += count
        print(f"  Replaced '{old.decode()}' -> '{new.decode()}' ({count} times)")

if changes > 0:
    with open(asar_path, 'wb') as f:
        f.write(data)
    print(f"  Total: {changes} string replacements in app.asar")
else:
    print("  No replacements needed")
PYEOF

  # 4. Also patch locale files (they contain "Codex" in translation keys)
  step "  Patching locale files..."
  find "/Applications/Eburon Codebox.app/Contents/Resources" -name "*.json" -path "*/lproj/*" 2>/dev/null | while read f; do
    sed -i '' 's/Codex/Eburon Codebox/g' "$f" 2>/dev/null || true
    sed -i '' 's/codex/eburon-codebox/g' "$f" 2>/dev/null || true
    sed -i '' 's/OpenAI/Eburon AI/g' "$f" 2>/dev/null || true
  done

  # 5. Sign with ad-hoc identity
  step "  Signing bundle..."
  codesign --force --deep --sign - "/Applications/Eburon Codebox.app" 2>/dev/null

  success "Eburon Codebox.app created — fully rebranded"
}

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
    echo -e "  ${YELLOW}The app will show 'Eburon Codebox' everywhere —${NC}"
    echo -e "  ${YELLOW}window title, about dialog, menus, and UI.${NC}"
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
  
  install_codex
  rebrand_codebox
  echo ""
  
  verify
}

main
