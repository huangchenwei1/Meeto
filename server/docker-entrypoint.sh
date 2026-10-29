#!/bin/sh
set -e

# Test environments push the schema directly; production should move to
# `prisma migrate deploy` once a migration history is established.
npx prisma db push --skip-generate

# Optional demo data for test environments (SEED_ON_BOOT=true).
if [ "$SEED_ON_BOOT" = "true" ]; then
  node prisma/seed.mjs
fi

exec node dist/main.js
