#!/bin/bash
# Starts the backend API (port 8081) and admin dashboard (port 3001) if not already running,
# waits until the admin dashboard responds, then opens it in the default browser.
set -e
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

is_up() { curl -s -o /dev/null -w "%{http_code}" "$1" | grep -q "^[23]"; }

if ! is_up "http://127.0.0.1:8081/api/v1/mobile/rates"; then
  echo "Starting backend..."
  (cd "$ROOT/backend" && nohup npx tsx src/server.ts > /tmp/ur-backend.log 2>&1 &)
  sleep 3
fi

if ! is_up "http://127.0.0.1:3001/login"; then
  echo "Starting admin dashboard..."
  (cd "$ROOT/admin" && UR_BACKEND_URL=http://127.0.0.1:8081 nohup npx next dev --hostname 127.0.0.1 --port 3001 > /tmp/ur-admin.log 2>&1 &)
fi

for _ in $(seq 1 20); do
  is_up "http://127.0.0.1:3001/login" && break
  sleep 1
done

open "http://127.0.0.1:3001/login"
