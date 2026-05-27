#!/bin/sh
set -eu

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is required."
  exit 1
fi

case "${DATABASE_URL}" in
  *pgbouncer=true*|*:6543/*)
    echo "DATABASE_URL must use the Supabase session/direct-style URL for Nakama."
    echo "Do not use the transaction pooler URL with pgbouncer=true on port 6543; Nakama uses prepared statements."
    exit 1
    ;;
esac

RAW_DB_URL="${DATABASE_URL#postgresql://}"
RAW_DB_URL="${RAW_DB_URL#postgres://}"
RAW_DB_URL="${RAW_DB_URL%%\?*}"

DB_CREDENTIALS="${RAW_DB_URL%%@*}"
DB_HOST_AND_NAME="${RAW_DB_URL#*@}"
DB_HOST_PORT="${DB_HOST_AND_NAME%%/*}"
DB_NAME="${DB_HOST_AND_NAME#*/}"

: "${PORT:=10000}"
: "${NAKAMA_CONSOLE_PORT:=10001}"
: "${NAKAMA_DB_SCHEMA:=nakama}"
: "${NAKAMA_SERVER_KEY:=defaultkey}"
: "${NAKAMA_RUNTIME_HTTP_KEY:=replace-me-http-key}"
: "${NAKAMA_SESSION_ENCRYPTION_KEY:=replace-me-session-key}"
: "${NAKAMA_REFRESH_ENCRYPTION_KEY:=replace-me-refresh-key}"
: "${NAKAMA_CONSOLE_USERNAME:=admin}"
: "${NAKAMA_CONSOLE_PASSWORD:=password}"
: "${NAKAMA_CONSOLE_SIGNING_KEY:=replace-me-console-signing-key}"

NAKAMA_DB_ADDRESS="${DB_CREDENTIALS}@${DB_HOST_PORT}/${DB_NAME}?sslmode=require&search_path=${NAKAMA_DB_SCHEMA}"

echo "Starting Nakama with PostgreSQL host=${DB_HOST_PORT} database=${DB_NAME} schema=${NAKAMA_DB_SCHEMA}"

attempt=1
until /nakama/nakama migrate up --database.address "${NAKAMA_DB_ADDRESS}"; do
  if [ "$attempt" -ge 12 ]; then
    echo "Nakama migration failed after ${attempt} attempts."
    exit 1
  fi
  echo "Nakama migration failed on attempt ${attempt}; retrying in 5 seconds..."
  attempt=$((attempt + 1))
  sleep 5
done

exec /nakama/nakama \
  --name nakama1 \
  --database.address "${NAKAMA_DB_ADDRESS}" \
  --runtime.path=/nakama/data/modules \
  --runtime.js_entrypoint=match.js \
  --logger.level INFO \
  --socket.port "${PORT}" \
  --console.port "${NAKAMA_CONSOLE_PORT}" \
  --socket.server_key "${NAKAMA_SERVER_KEY}" \
  --runtime.http_key "${NAKAMA_RUNTIME_HTTP_KEY}" \
  --session.encryption_key "${NAKAMA_SESSION_ENCRYPTION_KEY}" \
  --session.refresh_encryption_key "${NAKAMA_REFRESH_ENCRYPTION_KEY}" \
  --session.token_expiry_sec 7200 \
  --session.refresh_token_expiry_sec 604800 \
  --console.username "${NAKAMA_CONSOLE_USERNAME}" \
  --console.password "${NAKAMA_CONSOLE_PASSWORD}" \
  --console.signing_key "${NAKAMA_CONSOLE_SIGNING_KEY}"
