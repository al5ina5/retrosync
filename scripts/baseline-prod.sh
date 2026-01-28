#!/bin/bash
# One-time baseline for production DB that was created outside migrate deploy
# (e.g. via db push or manual SQL). Run with production DATABASE_URL.
#
# Usage:
#   DATABASE_URL="postgresql://..." ./scripts/baseline-prod.sh
#   # or from Vercel: vercel env pull .env.production && export $(grep -v '^#' .env.production | xargs) && ./scripts/baseline-prod.sh

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/dashboard"

if [ -z "${DATABASE_URL}" ]; then
  echo "Error: DATABASE_URL is required (use production connection string)"
  exit 1
fi

echo "Baseline: marking init migration as applied (no SQL executed)..."
npx prisma migrate resolve --applied "20260128104253_init"

echo "Deploy: applying pending migrations..."
npx prisma migrate deploy

echo "Done. DB is baselined and up to date."
