#!/usr/bin/env bash
# =============================================================================
# GitHub Backlink Kit — deploy script
# Run this with YOUR OWN GitHub account (gh auth login), not a bot token.
# Creates: (1) profile README, (2) GitHub Pages landing page, (3) repo About.
# =============================================================================
set -euo pipefail

USER="WilliamAyad"
SITE="https://www.triggerworkflow.com"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v gh >/dev/null 2>&1 || { echo "❌ gh CLI not found. Install: https://cli.github.com"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "❌ Not logged in. Run: gh auth login"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> 1/3 Profile README (${USER}/${USER})"
gh repo create "${USER}/${USER}" --public \
  --description "William Ayadi — n8n workflow automation expert. Founder of TriggerWorkflow.com." \
  --homepage "${SITE}" --add-readme 2>/dev/null \
  || echo "   ⚠️ repo already exists — continuing"
if gh repo clone "${USER}/${USER}" "$TMP/profile" >/dev/null 2>&1; then
  cp "$KIT_DIR/profile-README.md" "$TMP/profile/README.md"
  git -C "$TMP/profile" add README.md
  git -C "$TMP/profile" -c user.name="$USER" -c user.email="${USER}@users.noreply.github.com" \
    commit -m "Add profile README with backlink to ${SITE}" >/dev/null 2>&1 || true
  git -C "$TMP/profile" push origin HEAD >/dev/null 2>&1
  echo "   ✅ Profile README deployed"
fi

echo "==> 2/3 GitHub Pages landing page (${USER}.github.io)"
gh repo create "${USER}/williamayad.github.io" --public \
  --description "William Ayadi — n8n automation expert. Home of TriggerWorkflow.com." \
  --homepage "${SITE}" 2>/dev/null \
  || echo "   ⚠️ repo already exists — continuing"
if gh repo clone "${USER}/williamayad.github.io" "$TMP/pages" >/dev/null 2>&1; then
  cp "$KIT_DIR/pages/index.html" "$TMP/pages/index.html"
  git -C "$TMP/pages" add index.html
  git -C "$TMP/pages" -c user.name="$USER" -c user.email="${USER}@users.noreply.github.com" \
    commit -m "Add landing page with backlink to ${SITE}" >/dev/null 2>&1 || true
  git -C "$TMP/pages" push origin HEAD >/dev/null 2>&1
  echo "   ✅ index.html deployed"
fi
if gh api -X POST "repos/${USER}/williamayad.github.io/pages" \
     -F "source[branch]=main" -F "source[path]=/" >/dev/null 2>&1; then
  echo "   ✅ GitHub Pages enabled"
else
  echo "   ⚠️ Enable Pages manually: Settings → Pages → Source: main / (root)"
fi

echo "==> 3/3 Repo About settings (${USER}/n8n-workflow-blueprints)"
gh repo edit "${USER}/n8n-workflow-blueprints" \
  --homepage "${SITE}" \
  --description "Production-ready n8n workflow templates you can import and run today. Tutorials at TriggerWorkflow.com"
for t in n8n workflow-automation ai-automation mcp no-code templates blueprints; do
  gh repo edit "${USER}/n8n-workflow-blueprints" --add-topic "$t" >/dev/null 2>&1 || true
done
echo "   ✅ Homepage + topics set"

echo ""
echo "=============================================="
echo "✅ All done!"
echo "   Profile:    https://github.com/${USER}"
echo "   Pages:      https://${USER,,}.github.io"
echo "   Repo about: https://github.com/${USER}/n8n-workflow-blueprints"
echo "=============================================="
