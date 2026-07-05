#!/bin/bash
APP="$1"
PLUGIN_DIR="$APP/Contents/Resources/plugins/openai-bundled"

# plugin.json files
find "$PLUGIN_DIR" -name "plugin.json" -exec sed -i '' \
  -e 's/Codex/Eburon Codebox/g' \
  -e 's/OpenAI/Eburon AI/g' \
  -e 's/ChatGPT/Chatbox/g' \
  -e 's/chatgpt/chatbox/g' {} +

# .mcp.json files (only visible strings, not paths)
find "$PLUGIN_DIR" -name ".mcp.json" -exec sed -i '' 's/Codex/Eburon Codebox/g' {} +

# All .md files
find "$PLUGIN_DIR" -name "*.md" -exec sed -i '' \
  -e 's/Codex/Eburon Codebox/g' \
  -e 's/OpenAI/Eburon AI/g' \
  -e 's/ChatGPT/Chatbox/g' \
  -e 's/chatgpt/chatbox/g' {} +

# .js files (scripts, not node_modules)
find "$PLUGIN_DIR" -name "*.js" -not -path "*/node_modules/*" -exec sed -i '' \
  -e 's/Codex/Eburon Codebox/g' \
  -e 's/OpenAI/Eburon AI/g' \
  -e 's/ChatGPT/Chatbox/g' \
  -e 's/chatgpt/chatbox/g' {} +

# marketplace.json
sed -i '' \
  -e 's/Codex/Eburon Codebox/g' \
  -e 's/OpenAI/Eburon AI/g' \
  -e 's/ChatGPT/Chatbox/g' \
  -e 's/chatgpt/chatbox/g' "$PLUGIN_DIR/.agents/plugins/marketplace.json"

# owl-electron-app.json
sed -i '' \
  -e 's/Codex/Eburon Codebox/g' \
  -e 's/OpenAI/Eburon AI/g' \
  "$APP/Contents/Resources/owl-electron-app.json"

echo "Done rebranding plugin files"
