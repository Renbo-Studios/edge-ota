#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# sync-from-monorepo.sh
#
# Syncs the edge-ota CLI from the monorepo (apps/cli + packages/core),
# patches imports so the core is bundled inline, rebuilds, and publishes.
#
# Usage:
#   cd /Users/macbookair/Documents/GitHub/edge-ota-cli
#   bash sync-from-monorepo.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e

MONOREPO="/Users/macbookair/Documents/GitHub/edge-ota"
CLI_SRC="$MONOREPO/apps/cli"
CORE_SRC="$MONOREPO/packages/core/src"

echo "🔄  Syncing CLI source from monorepo..."

# 1. Wipe old source and dist
rm -rf src dist

# 2. Copy apps/cli source
cp -R "$CLI_SRC/src/" ./src/
cp "$CLI_SRC/tsconfig.json" ./tsconfig.json
cp "$CLI_SRC/README.md" ./README.md

# 3. Inline the core package (copy core src into src/core/)
mkdir -p src/core
cp "$CORE_SRC"/* src/core/

# 4. Patch the import path from the workspace dep to the inline core
sed -i '' 's|from "@renbostudios/edge-ota-core"|from "./core/index.js"|g' src/index.ts

# 5. Sync package.json from monorepo but strip the workspace dependency
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('$CLI_SRC/package.json', 'utf8'));
// Remove workspace dep — core is now inlined
delete pkg.dependencies['@renbostudios/edge-ota-core'];
// Keep directory out of the published repo field
delete pkg.repository.directory;
fs.writeFileSync('./package.json', JSON.stringify(pkg, null, 2) + '\n');
console.log('✔  package.json patched — version:', pkg.version);
"

# 6. Clean install, build, and publish
rm -rf node_modules package-lock.json
npm install
npm run build
echo ""
echo "✔  Build complete. Publishing @renbostudios/edge-ota@$(node -p "require('./package.json').version")..."
npm publish --access public

# 7. Commit and push sync to edge-ota-cli repo
git add .
git commit -m "sync: v$(node -p "require('./package.json').version") from monorepo"
git push --force

echo ""
echo "✅  Sync complete and published!"
