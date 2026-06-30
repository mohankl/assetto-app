#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_DIR="$ROOT_DIR/deployment"

cd "$ROOT_DIR"

echo "Building Flutter web release..."
flutter pub get
flutter build web --release --no-wasm-dry-run

echo "Preparing deployment folder..."
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"
rsync -a --delete build/web/ "$DEPLOY_DIR/"

cat > "$DEPLOY_DIR/_redirects" <<'EOF'
/*    /index.html   200
EOF

cat > "$DEPLOY_DIR/_headers" <<'EOF'
/*
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin

/assets/*
  Cache-Control: public, max-age=31536000, immutable

/main.dart.js
  Cache-Control: public, max-age=0, must-revalidate
EOF

echo ""
echo "Deployment folder ready: $DEPLOY_DIR"
echo "Upload the contents of 'deployment/' to Netlify (drag & drop or CLI)."
