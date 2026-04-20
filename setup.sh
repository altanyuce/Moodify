#!/bin/bash
# ============================================================
# Moodify — Project Setup Script
# Run this once after unzipping the project
# ============================================================

set -e

echo ""
echo "🎵  Moodify Setup"
echo "================================"

# 1. Check Flutter
if ! command -v flutter &> /dev/null; then
  echo "❌  Flutter not found. Install from https://flutter.dev/docs/get-started/install"
  exit 1
fi

echo "✅  Flutter found: $(flutter --version | head -1)"

# 2. Run flutter create to fill missing scaffold (preserves lib/ and pubspec.yaml)
echo ""
echo "📁  Scaffolding Android + iOS native files..."
flutter create --org com.example --project-name moodify . 2>&1 | grep -v "^$" | head -30

# 3. Set up .env
if [ ! -f ".env" ]; then
  cp .env.example .env
  echo ""
  echo "📋  Created .env from .env.example"
  echo "    ⚠️  Edit .env and add your API keys to enable AI + Spotify"
  echo "    ℹ️  App works without keys (fallback mode)"
else
  echo "✅  .env already exists"
fi

# 4. Get packages
echo ""
echo "📦  Running flutter pub get..."
flutter pub get

# 5. Done
echo ""
echo "================================"
echo "✅  Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Edit .env with your API keys (optional — app works without them)"
echo "  2. Connect a device or start an emulator"
echo "  3. Run:  flutter run"
echo ""
echo "  OpenAI key:  https://platform.openai.com/api-keys"
echo "  Spotify keys: https://developer.spotify.com/dashboard"
echo ""
