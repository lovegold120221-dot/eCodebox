#!/bin/bash
set -euo pipefail

SRC="/tmp/original-codex-extracted"
DEST="/tmp/codex-rebrand"

# Phase 1: Copy original
rm -rf "$DEST"
cp -a "$SRC" "$DEST"

echo "=== Phase 1: JS-safe replacements (ALL files) ==="
# Safe replacements — no spaces, no hyphens, valid identifiers everywhere
find "$DEST" -type f \( -name '*.js' -o -name '*.html' -o -name '*.css' -o -name '*.json' -o -name '*.md' -o -name '*.yml' -o -name '*.yaml' \) -not -path '*/node_modules/*' | while read -r f; do
  sed -i '' \
    -e 's/Codex/EburonCodebox/g' \
    -e 's/CODEX/EBURON_CODEBOX/g' \
    -e 's/codex/eburonCodebox/g' \
    -e 's/OpenAI/EburonAI/g' \
    -e 's/openai/eburonAI/g' \
    -e 's/ChatGPT/Chatbox/g' \
    -e 's/chatgpt/chatbox/g' \
    -e 's/Chatgpt/Chatbox/g' \
    -e 's/chatGpt/chatbox/g' \
    "$f"
done

echo "=== Phase 2: Check for bad strings in JS files ==="
# Check no JS files have spaces in identifiers
BAD=$(grep -rnP 'Eburon\s+Codebox' "$DEST" --include='*.js' -l 2>/dev/null || true)
if [ -n "$BAD" ]; then
  echo "WARNING: Files with 'Eburon Codebox' (space) found:"
  echo "$BAD"
fi

echo "=== Phase 3: Validate all JS files with node -c ==="
FAILED=0
find "$DEST" -name '*.js' -not -path '*/node_modules/*' | while read -r f; do
  # Skip files that need DOM/browser APIs
  if echo "$f" | grep -qE '(preload|sandbox|comment-preload|avatar-overlay)'; then
    continue
  fi
  if node -c "$f" 2>/dev/null; then
    : # ok
  else
    echo "SYNTAX ERROR: $f"
    FAILED=$((FAILED + 1))
  fi
done
echo "Validation complete. Failed: $FAILED"

echo "=== Done ==="
